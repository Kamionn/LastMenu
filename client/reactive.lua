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

-- Returns `ms` with ±10% uniform jitter so simultaneous watchers don't retry in lockstep.
local function _jitter(ms)
    return math.floor(ms * (0.9 + math.random() * 0.2))
end

---@class LM.Reactive
---@field _watchers table<string, table[]>
---@field _running  table<string, boolean>
---@field _paused   table<string, boolean>

local Reactive = {}
Reactive._watchers = {}
Reactive._running  = {}
Reactive._paused   = {}

-- ── Watcher Initialization ───────────────────────────────────────────────────

--- Initializes the internal state of a watcher to prevent nil arithmetic errors
--- during the tick loop. Ensures all tracking fields exist and clones config.
--- @param w table The raw watcher object.
--- @param menu_id string The ID of the parent menu.
--- @return table|nil w The initialized watcher or nil if invalid.
function Reactive._initWatcher(w, menu_id)
    if type(w.interval) ~= 'number' or type(w.id) == 'nil' or type(w.fn) ~= 'function' then
        return nil
    end

    return {
        id              = w.id,
        field           = w.field or 'value',
        fn              = w.fn,
        interval        = w.interval,
        debounce_ms     = w.debounce_ms or 0,
        last            = w.last,
        -- Internal state
        intervalCurrent  = w.interval,
        stableCount      = 0,
        nextAt           = 0,
        errCount         = 0,
        disabled         = false,
        retryAt          = nil,
        zombieRetries    = 0,
        _lastJson        = type(w.last) == 'table' and json.encode(w.last) or nil,
        _lastRef         = type(w.last) == 'table' and w.last or nil,
        _tableWarned     = false,
        _menuId          = menu_id,
    }
end

-- ── Attach / lifecycle ────────────────────────────────────────────────────────

---@param menu_id  string
---@param watchers table[]
function Reactive.attach(menu_id, watchers)
    if not watchers or #watchers == 0 then return end

    local safeWatchers = {}
    for i = 1, #watchers do
        local safe = Reactive._initWatcher(watchers[i], menu_id)
        if safe then table.insert(safeWatchers, safe) end
    end

    Reactive._watchers[menu_id] = safeWatchers
end

--- Adds a new watcher to an existing menu session. 
--- Automatically initializes state so it can be safely processed in the next tick.
---@param menu_id string
---@param watcher table
function Reactive.addWatcher(menu_id, watcher)
    if not Reactive._watchers[menu_id] then
        return Reactive.attach(menu_id, { watcher })
    end

    local safe = Reactive._initWatcher(watcher, menu_id)
    if safe then table.insert(Reactive._watchers[menu_id], safe) end
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
    -- ── Integrity Guards ─────────────────────────────────────────────────────
    if type(w.fn) ~= 'function' then
        w.disabled, w.retryAt = true, nil
        return batch
    end

    -- Prevent "ghost freezes" if nextAt becomes corrupted or too far in the future.
    if not w.nextAt or (w.nextAt > now + 60000) then w.nextAt = now end

    -- ── Safe-mode retry ───────────────────────────────────────────────────────
    local wasRecovery = false
    if w.disabled then
        -- retryAt == nil means permanently dead (zombie retries exhausted).
        if w.retryAt and now >= w.retryAt then
            w.disabled   = false
            w.errCount   = 0
            w.retryAt    = nil
            wasRecovery  = true
            if Config.debug then
                print(('[LastMenu] Watcher recovery attempt [%s:%s]')
                    :format(tostring(w._menuId), tostring(w.field)))
            end
        else
            return batch
        end
    end

    if now < w.nextAt then return batch end

    local ok, value = pcall(w.fn)

    if not ok then
        -- Recovery tick gets a free attempt: a single failure on the re-enable tick
        -- does not open a new error cycle (errCount stays 0 from the reset above).
        if not wasRecovery then
            w.errCount = (w.errCount or 0) + 1
        end

        if w.errCount >= MAX_ERRORS then
            w.zombieRetries = (w.zombieRetries or 0) + 1
            w.disabled      = true
            if w.zombieRetries >= MAX_ZOMBIE_RETRIES then
                w.retryAt = nil   -- permanently dead — no further recovery
                print(('[LastMenu] Watcher DEAD [%s:%s] — %d recovery attempts exhausted. Error: %s')
                    :format(tostring(w._menuId), tostring(w.field),
                            MAX_ZOMBIE_RETRIES, tostring(value)))
            else
                -- Exponential retry delay: each zombie cycle increases the wait
                local backoff = RETRY_DELAY_MS * math.min(w.zombieRetries, 4)
                w.retryAt = now + _jitter(backoff)
                print(('[LastMenu] Watcher DISABLED [%s:%s] — will retry in ~%ds (attempt %d/%d). Error: %s')
                    :format(tostring(w._menuId), tostring(w.field),
                            backoff / 1000, w.zombieRetries, MAX_ZOMBIE_RETRIES, tostring(value)))
            end
        else
            -- Progressive delay with jitter: 1s → 2s → 4s → 8s before hitting MAX_ERRORS.
            local step = ERROR_BACKOFF_STEPS[math.max(1, w.errCount)] or ERROR_BACKOFF_STEPS[#ERROR_BACKOFF_STEPS]
            w.intervalCurrent = _jitter(step)
        end

        w.nextAt = now + w.intervalCurrent
        return batch
    end

    w.errCount = 0
    
    -- ── Change detection ─────────────────────────────────────────────────────
    local changed = false
    if type(value) == 'table' then
        if not w._tableWarned then w._tableWarned = true end
        local ok_json, enc = pcall(json.encode, value)
        if ok_json then
            changed = enc ~= (w._lastJson or '')
            if changed then
                w._lastJson = enc
                w._lastRef  = value
            end
        else
            print(('[LastMenu][ERROR] Table serialization failed [%s:%s]'):format(tostring(w._menuId), tostring(w.field)))
        end
    else
        changed = value ~= w.last
        if changed then w._lastJson, w._lastRef = nil, nil end
    end

    if changed then
        w.last            = value
        w.stableCount     = 0
        w.intervalCurrent = w.interval  -- reset to base on change

        if w.debounce_ms and w.debounce_ms > 0 then
            w._debouncePending = value
            w._debounceEmitAt  = now + w.debounce_ms
        else
            batch = batch or {}
            local entry
            for _, e in ipairs(batch) do
                if e.id == w.id then entry = e; break end
            end
            if not entry then
                entry = { id = w.id }
                batch[#batch + 1] = entry
            end
            entry[w.field] = value
        end
    else
        -- ── Adaptive Backoff ─────────────────────────────────────────────────
        w.stableCount = (w.stableCount or 0) + 1
        if w.stableCount >= STABLE_THRESHOLD then
            w.stableCount     = 0
            w.intervalCurrent = math.min(
                math.floor(w.intervalCurrent * BACKOFF_FACTOR),
                w.interval * BACKOFF_MAX_MULT
            )
        end
    end

    -- Flush debounced value when the silence window has elapsed.
    if w._debounceEmitAt and now >= w._debounceEmitAt then
        batch = batch or {}
        local entry
        for _, e in ipairs(batch) do
            if e.id == w.id then entry = e; break end
        end
        if not entry then
            entry = { id = w.id }
            batch[#batch + 1] = entry
        end
        entry[w.field] = w._debouncePending
        w._debouncePending, w._debounceEmitAt = nil, nil
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
        local dbgTick, dbgPatches
        if Config.debug then dbgTick, dbgPatches = 0, 0 end

        while Reactive._running[menu_id] do
            local watchers = Reactive._watchers[menu_id]
            if not watchers then break end

            if Reactive._paused[menu_id] then 
                Citizen.Wait(500)
                goto nextTick 
            end

            local now, rawBatch = GetGameTimer(), nil
            local nextClosestAt = now + 500 

            for i = 1, #watchers do
                local w = watchers[i]
                rawBatch = Reactive._processWatcher(w, now, rawBatch)
                
                if not w.disabled and w.nextAt < nextClosestAt then
                    nextClosestAt = w.nextAt
                end
            end

            if rawBatch then
                Bridge.send('patch', { id = menu_id, changes = rawBatch })
                if Config.debug then dbgPatches = dbgPatches + 1 end
            end

            if Config.debug then
                dbgTick = dbgTick + 1
                if dbgTick >= DEBUG_PRINT_EVERY then
                    print(('[LastMenu][debug] menu:%s patches:%d'):format(menu_id, dbgPatches))
                    dbgTick, dbgPatches = 0, 0
                end
            end

            -- Dynamic Sleep: Accurate timing by subtracting loop execution time.
            local remaining = nextClosestAt - now
            local sleepTime = math.max(10, math.min(remaining, 500))
            Citizen.Wait(sleepTime)

            ::nextTick::
        end
        Reactive._running[menu_id] = nil
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