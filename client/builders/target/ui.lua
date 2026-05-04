-- target/ui.lua
-- NUI helpers, polling thread (10 Hz), and debug draw thread.
-- Reads from LastMenu.Target (zones) and LastMenu._targetRaycast (geometry).

local Target         = LastMenu.Target
local Bridge         = LastMenu.Bridge
local Stack          = LastMenu.Stack
local Config         = LastMenu.Config
local GenerateMenuId = LastMenu._genId
local _stableId      = LastMenu._stableId
local TR             = LastMenu._targetRaycast
local _resName       = GetCurrentResourceName()

-- Module-level state shared between the polling thread and NUI helpers.
---@type boolean
local _isReticleShown = false
---@type string
local _lastMatchKey   = ''
---@type boolean|nil
local _idleMoving     = nil
---@type boolean
local _prevE          = false
---@type table<string, boolean>
local _prevActiveIds  = {}
---@type string|nil
local _targetMenuId   = nil

-- Exposed so zones.lua can reset state when registrations change.
rawset(LastMenu, '_targetUi', {
    resetMatchKey = function() _lastMatchKey = '' end,
})

-- ── Hold key ────────────────────────────────────────────────────────────────

---@return integer
local function getHoldKey()
    local k = LastMenu._userTargetKey
    return (k and k ~= 0) and k or Config.target_hold_key or 36
end

-- ── Helpers ──────────────────────────────────────────────────────────────────

local normalizeConfirmHold = LastMenu._normalizeHold

-- Pick banner from most specific matched registration (entity > model > zone).
---@param  allMatched table[]
---@return string|nil
local function pickBanner(allMatched)
    for _, m in ipairs(allMatched) do
        if m.reg.type == 'entity' and m.reg.banner then return m.reg.banner end
    end
    for _, m in ipairs(allMatched) do
        if m.reg.type == 'model' and m.reg.banner then return m.reg.banner end
    end
    for _, m in ipairs(allMatched) do
        if m.reg.banner then return m.reg.banner end
    end
    return nil
end

-- ── NUI helpers ─────────────────────────────────────────────────────────────

---@param  a table
---@return table
local function _itemEntry(a)
    return {
        kind         = a.kind,
        id           = a.id,
        label        = a.label,
        icon         = a.icon,
        color        = a.color,
        disabled     = a.disabled,
        badge        = a.badge,
        gradient     = a.gradient,
        confirm_hold = a.confirm_hold,
        cooldown     = a.cooldown,
        cooldown_key = a.cooldown_key,
        cd_expiry    = a.cd_expiry,
        arrow        = a.arrow,
        min          = a.min,
        max          = a.max,
        step         = a.step,
        value        = a.value,
        suffix       = a.suffix,
    }
end

---@param label string
---@param icon  string|nil
local function openTargetReticle(label, icon)
    _targetMenuId = 'target_reticle'
    Bridge.send('open', {
        menu = 'target',
        id   = _targetMenuId,
        data = { label = label, icon = icon, actions = {} }
    })
end

---@param allMatched table[]
local function openTargetActions(allMatched)
    local menuId = GenerateMenuId()
    local label  = TR.pickLabel(allMatched)
    local banner = pickBanner(allMatched)
    local _used  = {}

    -- 1. Collect and process all visible actions from all matched registrations.
    local rawActions = {}
    for _, m in ipairs(allMatched) do
        for _, action in ipairs(m.reg.actions) do
            local hitEnt = m.entity
            local kind   = action.kind or 'button'

            -- Visibility
            local visibleFn = action.visible
            local isVisible = true
            if type(visibleFn) == 'function' then
                local ok, val = pcall(visibleFn, hitEnt)
                if ok then isVisible = val ~= false else isVisible = true end
            elseif visibleFn ~= nil then
                isVisible = visibleFn ~= false
            end
            if not isVisible then goto continueAction end

            -- Disabled
            local isDisabled = false
            if type(action.disabled) == 'function' then
                local ok, val = pcall(action.disabled, hitEnt)
                if ok then isDisabled = val == true end
            elseif action.disabled ~= nil then
                isDisabled = action.disabled == true
            end

            local isStateful  = kind == 'toggle' or kind == 'checkbox' or kind == 'slider'
            local isSubmenu   = type(action.submenu) == 'function'
            local hasCooldown = type(action.cooldown) == 'number' and action.cooldown > 0
            local keepOpen    = isStateful or isSubmenu or hasCooldown or action.keep_open == true

            local cb_id   = action.id or _stableId(menuId, action.label or kind, kind, _used)
            local actionCb = action.submenu or action.cb

            local cd_key    = nil
            local cd_expiry = nil
            if hasCooldown then
                cd_key = action.persist_key or cb_id
                local stored = GetResourceKvpString('lm_cd_' .. _resName .. '_' .. cd_key)
                if stored then
                    local expiry_ms = tonumber(stored)
                    if expiry_ms and expiry_ms > os.time() * 1000 then
                        cd_expiry = expiry_ms
                    end
                end
            end

            -- Register callback
            if actionCb and not isDisabled then
                Bridge.onCallback(cb_id, function(cbData)
                    if not keepOpen then Stack.pop() end
                    if isStateful then
                        actionCb(hitEnt, cbData and cbData.value)
                    elseif isSubmenu then
                        actionCb(hitEnt)
                    else
                        actionCb(hitEnt, cbData)
                    end
                end, menuId)
            end

            table.insert(rawActions, {
                kind         = kind,
                id           = cb_id,
                label        = action.label or '',
                icon         = action.icon,
                color        = action.color,
                disabled     = isDisabled,
                group        = action.group,
                group_icon   = action.group_icon,
                group_open   = action.group_open,
                badge        = action.badge,
                gradient     = action.gradient or false,
                confirm_hold = normalizeConfirmHold(action.confirm_hold),
                cooldown     = action.cooldown or nil,
                cooldown_key = cd_key,
                cd_expiry    = cd_expiry,
                arrow        = isSubmenu or action.arrow == true,
                min          = action.min,
                max          = action.max,
                step         = action.step,
                value        = action.default,
                suffix       = action.suffix,
            })

            ::continueAction::
        end
    end

    -- 2. Group actions into a rich items array.
    --    Actions with a `group` field are collected into an accordion that appears
    --    where the first item of that group is encountered, preserving insertion order.
    local items      = {}
    local seenGroups = {}  -- group name → accordion table ref

    for _, a in ipairs(rawActions) do
        if a.kind == 'separator' then
            table.insert(items, { kind = 'separator', id = a.id })
        elseif a.group then
            local g = a.group
            if not seenGroups[g] then
                local acc = {
                    kind  = 'accordion',
                    id    = 'acc_' .. g:lower():gsub('%W', '_'),
                    label = g,
                    icon  = a.group_icon,
                    open  = a.group_open == true,
                    items = {},
                }
                seenGroups[g] = acc
                table.insert(items, acc)
            end
            table.insert(seenGroups[g].items, _itemEntry(a))
        else
            table.insert(items, _itemEntry(a))
        end
    end

    _targetMenuId = menuId
    Stack.push({ id = _targetMenuId, type = 'target' })
    Bridge.send('open', {
        menu = 'target',
        id   = _targetMenuId,
        data = { label = label, banner = banner, items = items }
    })
end

local function closeTarget()
    if _targetMenuId then
        local id = _targetMenuId
        _targetMenuId = nil
        local top = Stack.peek()
        if top and top.type == 'target' then
            -- Stack.pop() already sends Bridge.send('close') for action menus
            Stack.pop()
        else
            -- Reticle and idle are not on the stack — close NUI manually
            Bridge.send('close', { id = id })
        end
    end
end

-- ── Polling thread ──────────────────────────────────────────────────────────

-- PERFORMANCE TIERS:
--   No registrations       → Wait(1000)  near-zero cost
--   Other menu owns stack  → Wait(200)   stay out of the way
--   Hold key not pressed   → Wait(50)    20 Hz key poll
--   Raycast active         → Wait(100)   10 Hz aim detection

Citizen.CreateThread(function()
    while true do
        if next(Target._registrations) == nil then
            if _isReticleShown then closeTarget(); _isReticleShown = false; _lastMatchKey = ''; _idleMoving = nil end
            _prevE = false
            Citizen.Wait(1000)

        elseif Stack.peek() ~= nil and Stack.peek().type ~= 'target' then
            if _isReticleShown then closeTarget(); _isReticleShown = false; _lastMatchKey = ''; _idleMoving = nil end
            _prevE = false
            Citizen.Wait(200)

        elseif not IsControlPressed(0, getHoldKey()) then
            if _isReticleShown then
                closeTarget()
                _isReticleShown = false
                _lastMatchKey   = ''
                _idleMoving     = nil
            end
            -- Fire on_leave for any zones the player was inside when releasing the key,
            -- then reset so re-pressing the key gets fresh on_enter events.
            if next(_prevActiveIds) then
                for regId in pairs(_prevActiveIds) do
                    local reg = Target._registrations[regId]
                    if reg and type(reg.on_leave) == 'function' then
                        local ok, err = pcall(reg.on_leave, nil)
                        if not ok then
                            print('[LastMenu] Target on_leave error (id=' .. regId .. '): ' .. tostring(err))
                        end
                    end
                end
                _prevActiveIds = {}
            end
            _prevE = false
            Citizen.Wait(50)

        else
            local playerPed    = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local entity       = TR.getRaycastHit(TR.getTargetDist())
            local matched      = TR.findMatchingRegs(entity, playerCoords)

            local parts = {}
            for _, m in ipairs(matched) do parts[#parts + 1] = m.id end
            table.sort(parts)
            local matchKey = table.concat(parts, '|')

            -- on_enter / on_leave
            local currentIds = {}
            for _, m in ipairs(matched) do currentIds[m.id] = true end

            for regId in pairs(_prevActiveIds) do
                if not currentIds[regId] then
                    local reg = Target._registrations[regId]
                    if reg and type(reg.on_leave) == 'function' then
                        local ok, err = pcall(reg.on_leave, entity)
                        if not ok then
                            print('[LastMenu] Target on_leave error (id=' .. regId .. '): ' .. tostring(err))
                        end
                    end
                end
            end

            for regId in pairs(currentIds) do
                if not _prevActiveIds[regId] then
                    local reg = Target._registrations[regId]
                    if reg and type(reg.on_enter) == 'function' then
                        local ok, err = pcall(reg.on_enter, entity)
                        if not ok then
                            print('[LastMenu] Target on_enter error (id=' .. regId .. '): ' .. tostring(err))
                        end
                    end
                end
            end

            _prevActiveIds = currentIds

            if #matched > 0 then
                if matchKey ~= _lastMatchKey then
                    closeTarget()
                    _lastMatchKey   = matchKey
                    _idleMoving     = nil
                    _isReticleShown = true
                    openTargetReticle(TR.pickLabel(matched), matched[1].reg.icon)
                end

                local eDown = IsControlPressed(0, 38)
                if eDown and not _prevE then
                    closeTarget()
                    _isReticleShown = false
                    _lastMatchKey   = ''
                    _idleMoving     = nil
                    openTargetActions(matched)
                end
                _prevE = eDown
            else
                local isMoving = GetEntitySpeed(PlayerPedId()) > 0.5

                if _lastMatchKey ~= 'idle' then
                    closeTarget()
                    _lastMatchKey   = 'idle'
                    _idleMoving     = isMoving
                    _isReticleShown = true
                    _targetMenuId   = 'target_idle'
                    Bridge.send('open', {
                        menu = 'target',
                        id   = 'target_idle',
                        data = { idle = true, actions = {}, moving = isMoving }
                    })
                elseif isMoving ~= _idleMoving then
                    _idleMoving = isMoving
                    Bridge.send('patch', {
                        id    = 'target_idle',
                        merge = { moving = isMoving }
                    })
                end
                _prevE = false
            end

            Citizen.Wait(100)
        end
    end
end)

-- ── Debug draw thread ──────────────────────────────────────────────────────

Citizen.CreateThread(function()
    while true do
        if Config.debugTarget then
            for _, reg in pairs(Target._registrations) do
                if reg.type == 'sphere' then
                    DrawSphere(reg.coords.x, reg.coords.y, reg.coords.z, reg.radius,
                        0, 200, 255, 60)

                elseif reg.type == 'box' then
                    DrawMarker(1,
                        reg.coords.x, reg.coords.y, reg.coords.z,
                        0, 0, 0, reg.heading, 0, 0,
                        reg.width, reg.length, 0.5,
                        255, 165, 0, 80,
                        false, true, 2, false, nil, nil, false)
                    local rad = math.rad(-reg.heading)
                    local hw, hl = reg.width / 2, reg.length / 2
                    local cx, cy, cz = reg.coords.x, reg.coords.y, reg.coords.z
                    local corners = {
                        { cx + hw*math.cos(rad) - hl*math.sin(rad), cy + hw*math.sin(rad) + hl*math.cos(rad) },
                        { cx - hw*math.cos(rad) - hl*math.sin(rad), cy - hw*math.sin(rad) + hl*math.cos(rad) },
                        { cx - hw*math.cos(rad) + hl*math.sin(rad), cy - hw*math.sin(rad) - hl*math.cos(rad) },
                        { cx + hw*math.cos(rad) + hl*math.sin(rad), cy + hw*math.sin(rad) - hl*math.cos(rad) },
                    }
                    local zlo, zhi = cz - 0.1, cz + 1.0
                    for i = 1, 4 do
                        local j = (i % 4) + 1
                        DrawLine(corners[i][1], corners[i][2], zlo, corners[j][1], corners[j][2], zlo, 255, 165, 0, 200)
                        DrawLine(corners[i][1], corners[i][2], zhi, corners[j][1], corners[j][2], zhi, 255, 165, 0, 200)
                        DrawLine(corners[i][1], corners[i][2], zlo, corners[i][1], corners[i][2], zhi, 255, 165, 0, 120)
                    end

                elseif reg.type == 'poly' then
                    local pts = reg.points
                    local zc  = (reg.minZ + reg.maxZ) / 2
                    if math.abs(zc) == math.huge or zc ~= zc then
                        zc = GetEntityCoords(PlayerPedId()).z
                    end
                    for i2 = 1, #pts do
                        local j = (i2 % #pts) + 1
                        DrawLine(pts[i2].x, pts[i2].y, zc, pts[j].x, pts[j].y, zc, 0, 255, 100, 200)
                        DrawMarker(25, pts[i2].x, pts[i2].y, zc,
                            0, 0, 0, 0, 0, 0, 0.3, 0.3, 0.3,
                            0, 255, 100, 180, false, true, 2, false, nil, nil, false)
                    end
                end
            end
            Citizen.Wait(0)
        else
            Citizen.Wait(500)
        end
    end
end)
