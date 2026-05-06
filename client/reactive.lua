-- reactive.lua
-- Reactive polling engine: adaptive intervals, backoff, safe-mode retry, batched NUI patches.
-- Registered in the LastMenu namespace as LastMenu.Reactive.
--
-- ARCHITECTURE NOTE:
--   Per-watcher tick logic lives in Reactive._processWatcher(w, now, batch).
--   That function is pure (no Citizen calls, explicit `now` parameter) and is
--   the only thing unit tests need to exercise. startTicking is a thin loop that
--   calls _processWatcher and passes the result to Bridge.send.

local Bridge = LastMenu.Bridge
local Stack  = LastMenu.Stack
local Config = LastMenu.Config

local STABLE_THRESHOLD   = 5
local BACKOFF_FACTOR     = 1.5
local BACKOFF_MAX_MULT   = 8
local MAX_ERRORS         = 5       -- consecutive errors before disabling
local RETRY_DELAY_MS     = 30000   -- ms before a disabled watcher gets one recovery attempt
local MAX_ZOMBIE_RETRIES = 5       -- permanent death after this many failed recovery cycles
local DEBUG_PRINT_EVERY  = 60

-- Progressive error-delay steps (ms). Indexed by consecutive error count (1-based).
-- Error 1 → 1s, 2 → 2s, 3 → 4s, 4 → 8s, 5+ → disable.
local ERROR_BACKOFF_STEPS = { 1000, 2000, 4000, 8000 }

-- Upvalue cache: avoids _ENV table lookups on every hot-path call inside the tick loop.
local json_encode = json.encode
local math_floor  = math.floor
local math_min    = math.min
local math_max    = math.max
local math_random = math.random

-- Returns `ms` with ±10% uniform jitter so simultaneous watchers don't retry in lockstep.
local function _jitter(ms)
    return math_floor(ms * (0.9 + math_random() * 0.2))
end

---@class LM.Reactive
---@field _watchers table<string, table[]>
---@field _running  table<string, boolean>
---@field _paused   table<string, boolean>

local Reactive = {}
Reactive._watchers = {}
Reactive._running  = {}
Reactive._paused   = {}

-- ── Attach / lifecycle ────────────────────────────────────────────────────────

---@param menu_id  string
---@param watchers table[]
function Reactive.attach(menu_id, watchers)
    if not watchers or #watchers == 0 then return end

    for _, w in ipairs(watchers) do
        w.intervalCurrent  = w.interval
        w.stableCount      = 0
        w.nextAt           = 0
        w.errCount         = 0
        w.disabled         = false
        w.retryAt          = nil
        w.zombieRetries    = 0
        w._lastJson        = type(w.last) == 'table' and json_encode(w.last) or nil
        w._menuId          = menu_id   -- stored so _processWatcher can log with context
        w._debouncePending = nil
        w._debounceEmitAt  = nil
        w._hasDebounce     = type(w.debounce_ms) == 'number' and w.debounce_ms > 0
    end

    Reactive._watchers[menu_id] = watchers
end

---@param menu_id string
function Reactive.evaluate(menu_id)
    local watchers = Reactive._watchers[menu_id]
    if not watchers then return end
    for _, w in ipairs(watchers) do
        w.nextAt = 0
    end
end

---@param menu_id string
function Reactive.pause(menu_id)
    Reactive._paused[menu_id] = true
end

---@param menu_id string
function Reactive.resume(menu_id)
    Reactive._paused[menu_id] = false
    local watchers = Reactive._watchers[menu_id]
    if watchers then
        for _, w in ipairs(watchers) do
            if not w.disabled then w.nextAt = 0 end
        end
    end
end

-- ── Core per-watcher tick (pure — no Citizen calls) ──────────────────────────

--- Evaluates one watcher for the current tick.
--- Deterministic: takes explicit `now` so tests can pass any timestamp without
--- depending on GetGameTimer(). Mutates `w` in-place.
---
--- Returns the (possibly new) batch table. A new table is created on the first
--- detected change; subsequent changes append to the same table.
---
---@param w     table       Watcher state (mutated)
---@param now   number      Current timestamp in ms (GetGameTimer() or test value)
---@param batch table|nil   Accumulated NUI patch entries; nil until first change
---@return table|nil batch
function Reactive._processWatcher(w, now, batch)
    -- ── Safe-mode retry ───────────────────────────────────────────────────────
    if w.disabled then
        -- retryAt == nil means permanently dead (zombie retries exhausted).
        if w.retryAt and now >= w.retryAt then
            w.disabled = false
            w.errCount = 0
            w.retryAt  = nil
            if Config.debug then
                print(('[LastMenu] Watcher recovery attempt [%s:%s]')
                    :format(tostring(w._menuId), tostring(w.field)))
            end
            -- fall through: evaluate immediately on recovery tick
        else
            return batch
        end
    end

    if now < w.nextAt then return batch end

    local ok, value = pcall(w.fn)

    if not ok then
        w.errCount = w.errCount + 1

        if w.errCount >= MAX_ERRORS then
            w.zombieRetries = w.zombieRetries + 1
            w.disabled      = true
            if w.zombieRetries >= MAX_ZOMBIE_RETRIES then
                w.retryAt = nil   -- permanently dead — no further recovery
                print(('[LastMenu] Watcher DEAD [%s:%s] — %d recovery attempts exhausted. Error: %s')
                    :format(tostring(w._menuId), tostring(w.field),
                            MAX_ZOMBIE_RETRIES, tostring(value)))
            else
                w.retryAt = now + _jitter(RETRY_DELAY_MS)
                print(('[LastMenu] Watcher DISABLED [%s:%s] — will retry in ~%ds (attempt %d/%d). Error: %s')
                    :format(tostring(w._menuId), tostring(w.field),
                            RETRY_DELAY_MS / 1000, w.zombieRetries, MAX_ZOMBIE_RETRIES, tostring(value)))
            end
        else
            -- Progressive delay with jitter: 1s → 2s → 4s → 8s before hitting MAX_ERRORS.
            local step = ERROR_BACKOFF_STEPS[w.errCount] or ERROR_BACKOFF_STEPS[#ERROR_BACKOFF_STEPS]
            w.intervalCurrent = _jitter(step)
        end

        w.nextAt = now + w.intervalCurrent
        return batch
    end

    w.errCount = 0
    if w.intervalCurrent ~= w.interval then w.intervalCurrent = w.interval end

    -- ── Change detection ─────────────────────────────────────────────────────
    -- Tables: compare by JSON encoding (content equality), not reference.
    local changed
    if type(value) == 'table' then
        local encOk, enc = pcall(json_encode, value)
        if not encOk then
            -- Malformed table (circular ref, unencodable userdata, etc.).
            -- Treat as a watcher error so the element gets backoff, not a thread crash.
            w.errCount = w.errCount + 1
            local step = ERROR_BACKOFF_STEPS[math_min(w.errCount, #ERROR_BACKOFF_STEPS)]
            w.intervalCurrent = _jitter(step)
            w.nextAt = now + w.intervalCurrent
            if Config.debug then
                print(('[LastMenu] json.encode failed [%s:%s]: %s')
                    :format(tostring(w._menuId), tostring(w.field), tostring(enc)))
            end
            return batch
        end
        changed = enc ~= (w._lastJson or '')
        if changed then w._lastJson = enc end
    else
        changed = value ~= w.last
    end

    if changed then
        w.last        = value
        w.stableCount = 0
        w.intervalCurrent = w.interval  -- reset to base on change

        if w._hasDebounce then
            w._debouncePending = value
            w._debounceEmitAt  = now + w.debounce_ms
        else
            batch = batch or {}
            local change = { id = w.id }
            change[w.field] = value
            batch[#batch + 1] = change
        end
    else
        w.stableCount = (w.stableCount or 0) + 1
        if w.stableCount >= STABLE_THRESHOLD then
            w.stableCount     = 0
            w.intervalCurrent = math_min(
                math_floor(w.intervalCurrent * BACKOFF_FACTOR),
                w.interval * BACKOFF_MAX_MULT
            )
        end
    end

    -- Flush debounced value when the silence window has elapsed.
    if w._hasDebounce and w._debounceEmitAt and now >= w._debounceEmitAt then
        batch = batch or {}
        local change = { id = w.id }
        change[w.field] = w._debouncePending
        batch[#batch + 1] = change
        w._debouncePending = nil
        w._debounceEmitAt  = nil
    end

    w.nextAt = now + w.intervalCurrent
    return batch
end

-- ── Tick ─────────────────────────────────────────────────────────────────────

---@param menu_id string
function Reactive.startTicking(menu_id)
    if not Reactive._watchers[menu_id] or Reactive._running[menu_id] then return end
    Reactive._running[menu_id] = true

    Citizen.CreateThread(function()
        local watchers = Reactive._watchers[menu_id]

        local minInterval = 500
        for _, w in ipairs(watchers) do
            if w.interval < minInterval then minInterval = w.interval end
        end
        local tickMs = math_max(50, math_min(math_floor(minInterval / 2), 500))

        local dbgTick, dbgPatches
        if Config.debug then dbgTick, dbgPatches = 0, 0 end

        while Reactive._running[menu_id] do
            Citizen.Wait(tickMs)
            if Reactive._paused[menu_id] then goto nextTick end

            local now, batch = GetGameTimer(), nil

            for _, w in ipairs(watchers) do
                local ok, result = pcall(Reactive._processWatcher, w, now, batch)
                if ok then
                    batch = result
                else
                    print(('[LastMenu][reactive] uncaught error [%s:%s]: %s')
                        :format(menu_id, tostring(w.field), tostring(result)))
                end
            end

            if batch then
                Bridge.send('patch', { id = menu_id, changes = batch })
                if Config.debug then dbgPatches = dbgPatches + 1 end
            end

            if Config.debug then
                dbgTick = dbgTick + 1
                if dbgTick >= DEBUG_PRINT_EVERY then
                    print(('[LastMenu][debug] menu:%s patches:%d')
                        :format(menu_id, dbgPatches))
                    dbgTick, dbgPatches = 0, 0
                end
            end

            ::nextTick::
        end
    end)
end

---@param menu_id string
function Reactive.stopTicking(menu_id)
    Reactive._running[menu_id]  = nil
    Reactive._paused[menu_id]   = nil
    Reactive._watchers[menu_id] = nil
end

--- Returns a snapshot of all active watcher state, keyed by menu_id.
--- Used by debug_stats (exports.lua) and the lm_debug command.
---@return table<string, table[]>
function Reactive.getStats()
    local out = {}
    for menuId, watchers in pairs(Reactive._watchers) do
        local list = {}
        for _, w in ipairs(watchers) do
            list[#list + 1] = {
                id       = w.id,
                field    = w.field,
                interval = w.intervalCurrent or w.interval,
                errCount = w.errCount  or 0,
                disabled = w.disabled  or false,
                retryAt  = w.retryAt,
            }
        end
        out[menuId] = list
    end
    return out
end

-- ── Register in namespace ─────────────────────────────────────────────────────
rawset(LastMenu, 'Reactive', Reactive)

-- Link to Stack so Stack.pop() can call Reactive.stopTicking / Reactive.resume.
Stack._reactive = Reactive
