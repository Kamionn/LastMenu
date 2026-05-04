-- builders/radial.lua
-- Builder for UI:radial() — circular action wheel.
-- visible  : static bool or callable → shows/hides (geometry redistributed on open).
-- disabled : static bool or callable → greys out without removing (geometry stable).
-- keep_open: bool — if true, does not call Stack.pop() after the callback.

local Bridge         = LastMenu.Bridge
local Stack          = LastMenu.Stack
local Reactive       = LastMenu.Reactive
local GenerateMenuId = LastMenu._genId
local _stableId      = LastMenu._stableId

local normalizeConfirmHold = LastMenu._normalizeHold

---@class LM.RadialBuilder
---@field center_label fun(self: LM.RadialBuilder, str: string)
---@field button       fun(self: LM.RadialBuilder, label: string, opts?: table)

---@class LM.RadialHandle
---@field open  fun()
---@field close fun()

---@param  id string
---@param  fn fun(b: LM.RadialBuilder)
---@return table, table[], table[]
local function _buildRadial(id, fn)
    local meta     = { center_label = nil }
    local buttons  = {}
    local watchers = {}
    local b        = {}
    local _used        = {}   -- per-build dedup table for stable IDs
    local resolveField = LastMenu._makeResolver(watchers)

    -- Text displayed at the center when no sector is hovered.
    ---@param str string
    function b:center_label(str)
        meta.center_label = str
    end

    function b:button(label, opts)
        opts = opts or {}
        local cb_id = opts.id or _stableId(id, label, 'radial', _used)

        -- ── visible ───────────────────────────────────────────────────────
        local resolvedVisible  = resolveField(cb_id, opts.visible,  'visible',  'boolean', true,  opts.refresh or 500)
        local resolvedDisabled = resolveField(cb_id, opts.disabled, 'disabled', 'boolean', false, opts.refresh or 500)

        -- ── submenu ───────────────────────────────────────────────────────
        -- opts.submenu: function(b) — opens a nested radial on the stack.
        -- Parent stays on the stack (keep_open = true); Escape from the sub-radial
        -- returns to the parent, matching context submenu behavior.
        if opts.submenu then
            local subFn    = opts.submenu
            local origCb   = opts.cb
            opts.keep_open = true
            opts.cb = function(data)
                if origCb then origCb(data) end
                UI_Radial(subFn)
            end
        end

        -- ── callback ──────────────────────────────────────────────────────
        if opts.cb then
            local userCb   = opts.cb
            local keepOpen = opts.keep_open == true
            Bridge.onCallback(cb_id, function(data)
                if not keepOpen then Stack.pop() end
                userCb(data)
            end, id)
        end

        table.insert(buttons, {
            id           = cb_id,
            label        = label,
            icon         = opts.icon or nil,
            visible      = resolvedVisible,
            disabled     = resolvedDisabled,
            confirm_hold = normalizeConfirmHold(opts.confirm_hold),
            has_submenu  = opts.submenu ~= nil,
        })
    end

    LastMenu._safeBuilder('radial', fn, b, id)
    return meta, buttons, watchers
end

-- ── Gamepad thread ────────────────────────────────────────────────────────────
-- Reads the left stick and sends NUI messages only when a radial is on top.
-- On PC without a gamepad, magnitude is always 0 — nothing is sent.
Citizen.CreateThread(function()
    local stickWasActive = false
    while true do
        local top = Stack.peek()
        if top and top.type == 'radial' then
            local x   = GetDisabledControlNormal(0, 218)  -- LeftStickX
            local y   = GetDisabledControlNormal(0, 219)  -- LeftStickY
            local mag = math.sqrt(x * x + y * y)

            if mag > 0.25 then
                SendNUIMessage({ type = 'radial_gamepad', dx = x / mag, dy = y / mag })
                stickWasActive = true
            elseif stickWasActive then
                -- Stick returned to centre: reset virtual selection.
                SendNUIMessage({ type = 'radial_gamepad', dx = 0, dy = 0 })
                stickWasActive = false
            end

            if IsDisabledControlJustPressed(0, 191) then  -- A / Cross
                SendNUIMessage({ type = 'radial_confirm' })
            end

            Citizen.Wait(33)
        else
            stickWasActive = false
            Citizen.Wait(200)
        end
    end
end)

--- Opens a radial menu immediately.
---@param fn fun(b: LM.RadialBuilder)
function UI_Radial(fn)
    local id = GenerateMenuId()
    local meta, buttons, watchers = _buildRadial(id, fn)

    if #watchers > 0 then Reactive.attach(id, watchers) end
    Stack.push({ id = id, type = 'radial' })
    Bridge.send('open', { menu = 'radial', id = id, data = { center_label = meta.center_label, buttons = buttons } })
    if #watchers > 0 then Reactive.startTicking(id) end
end

local _radialBuildCleanup = {}

AddEventHandler('LastMenu:menuClosed', function(closedId)
    local cb = _radialBuildCleanup[closedId]
    if cb then cb(); _radialBuildCleanup[closedId] = nil end
end)

--- Returns a reusable handle { open(), close() }.
---@param fn fun(b: LM.RadialBuilder)
---@return LM.RadialHandle
function UI_Radial_Build(fn)
    local _activeId = nil
    return {
        open = function()
            if _activeId then return end  -- guard: prevents double-open on lag/double-press
            local id = GenerateMenuId()
            _activeId = id
            _radialBuildCleanup[id] = function() _activeId = nil end
            local meta, buttons, watchers = _buildRadial(id, fn)

            if #watchers > 0 then Reactive.attach(id, watchers) end
            Stack.push({ id = id, type = 'radial' })
            Bridge.send('open', { menu = 'radial', id = id, data = { center_label = meta.center_label, buttons = buttons } })
            if #watchers > 0 then Reactive.startTicking(id) end
        end,
        close = function()
            if not _activeId then return end
            _radialBuildCleanup[_activeId] = nil
            _activeId = nil
            Stack.pop()
        end
    }
end

