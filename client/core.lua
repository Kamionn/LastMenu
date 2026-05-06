-- core.lua
-- Bootstrap: menu ID generator + controller cancel handler.

local Bridge = LastMenu.Bridge
local Stack  = LastMenu.Stack

-- Reset NUI state on load.
-- CEF persists across Lua restarts, so orphan menus from the previous session
-- must be cleared before any new menu can open.
Bridge.send('reset', {})

-- ── ID generator ──────────────────────────────────────────────────────────────

local _menuCounter = 0
local _menuSalt    = math.random(0, 0xFFFF)

-- Returns a unique menu ID combining game timer, a random salt, and a monotonic counter.
-- The salt prevents ID collisions across rapid resource restarts within the same timer tick.
---@return string
local function GenerateMenuId()
    _menuCounter = _menuCounter + 1
    return GetGameTimer() .. '_' .. _menuSalt .. '_' .. _menuCounter
end

rawset(LastMenu, '_genId', GenerateMenuId)

-- ── Stable item ID helper ──────────────────────────────────────────────────────
-- Shared by all builders (context, radial, target).
--
-- Generates a cb_id from the item label (slugified) instead of its insertion
-- position, making IDs resilient to conditional item insertion.
--
-- Rules (in priority order):
--   1. opts.id   — explicit override, always wins
--   2. kind:label — slugified label scoped to kind prefix, e.g. "btn:buy weapons" → "buy_weapons"
--   3. Collision  — same slug used twice in the same build → _2, _3 suffix
--
-- Usage:
--   local used = {}
--   local id = LastMenu._stableId(menuId, label, 'btn', used)
--
---@param menuId string   Unique menu ID (scopes the cb_id globally)
---@param label  any      Item label — string preferred; falls back to kind if not a string
---@param kind   string   Item kind prefix: 'btn', 'slider', 'radial', 'tgt', etc.
---@param used   table    Per-build dedup table { [slug] = count } — must be reset each build
---@return string
local function _stableId(menuId, label, kind, used)
    local raw = type(label) == 'string' and label ~= '' and label or kind
    local lower = raw:lower()
    local base
    if lower:find('[^%w%s]') then
        -- Slow path: strip special chars, dedup underscores, trim edges.
        base = lower:gsub('[^%w%s]', ''):gsub('%s+', '_'):gsub('_+', '_'):gsub('^_+', ''):gsub('_+$', '')
    else
        -- Fast path: only alphanumeric + spaces (covers ~99% of labels).
        base = lower:gsub('%s+', '_')
    end
    if base == '' then base = 'item' end
    local n = (used[base] or 0) + 1
    used[base] = n
    return 'cb_' .. tostring(menuId) .. '_' .. (n > 1 and (base .. '_' .. n) or base)
end

rawset(LastMenu, '_stableId', _stableId)

-- ── Shared builder utilities ─────────────────────────────────────────────────

-- Normalises opts.confirm_hold: true → global default, number → that value, else false.
-- User's _userHoldDuration (from settings) takes priority over all values when set.
-- Shared by context.lua and radial.lua.
---@param  v boolean|number|nil
---@return integer|false
local function _normalizeHold(v)
    local cfg   = LastMenu.Config
    local userMs = LastMenu._userHoldDuration  -- number or false
    if v == true then
        return (type(userMs) == 'number' and userMs) or cfg.hold_duration or 1500
    elseif type(v) == 'number' and v > 0 then
        return (type(userMs) == 'number' and userMs) or v
    end
    return false
end
rawset(LastMenu, '_normalizeHold', _normalizeHold)

-- Wraps a user builder fn in pcall; prints a uniform error on failure.
-- menuId (optional) is appended to the log to identify which menu triggered the error.
---@param  name   string
---@param  fn     fun(b: table)
---@param  b      table
---@param  menuId string?
---@return boolean
local function _safeBuilder(name, fn, b, menuId)
    local ok, err = pcall(fn, b)
    if not ok then
        local res = GetInvokingResource() or GetCurrentResourceName()
        local mid = menuId and (' [menu:' .. tostring(menuId) .. ']') or ''
        print(('[LastMenu][%s] %s builder error%s: %s'):format(res, name, mid, tostring(err)))
    end
    return ok
end
rawset(LastMenu, '_safeBuilder', _safeBuilder)

local function _isCallable(v)
    local t = type(v)
    if t == 'function' or t == 'funcref' then return true end
    local mt = t == 'table' and getmetatable(v)
    return mt and type(mt.__call) == 'function'
end

-- Returns a resolveField(cb_id, val, field, expectedType, default, interval) closure
-- bound to the given watchers array. Callable values register reactive watchers;
-- static values are returned directly.
---@param  watchers table[]
---@return fun(cb_id: string, val: any, field: string, expectedType: string, default: any, interval: integer): any
local function _makeResolver(watchers)
    return function(cb_id, val, field, expectedType, default, interval)
        if val == nil then return default end
        if _isCallable(val) then
            local ok, result = pcall(val)
            if ok and type(result) == expectedType then
                watchers[#watchers + 1] = { id = cb_id, field = field, fn = val,
                    interval = interval, last = result }
                return result
            end
            if not ok then
                print(('[LastMenu] %s "%s" error: %s'):format(cb_id, field, tostring(result)))
            else
                print(('[LastMenu] %s "%s" warning: returned %s, expected %s')
                    :format(cb_id, field, type(result), expectedType))
            end
            watchers[#watchers + 1] = { id = cb_id, field = field, fn = val,
                interval = interval, last = default }
            return default
        end
        return (type(val) == expectedType) and val or default
    end
end
rawset(LastMenu, '_makeResolver', _makeResolver)

-- ── Controller B button handler ───────────────────────────────────────────────

local _prevCancel = false

Citizen.CreateThread(function()
    while true do
        local top = Stack.peek()

        if top then
            if top.cancelable ~= false and not IsUsingKeyboard(0) then
                local pressed = IsControlPressed(0, 200)   -- INPUT_CANCEL / B

                if pressed and not _prevCancel then
                    Stack.pop()
                end

                _prevCancel = pressed
            else
                _prevCancel = false
            end

            Citizen.Wait(100)
        else
            _prevCancel = false
            Citizen.Wait(500)
        end
    end
end)
