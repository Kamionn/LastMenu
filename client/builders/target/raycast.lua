-- target/raycast.lua
-- Geometry and detection helpers: raycast, spatial filtering, zone matching, label priority.
-- Exposes LastMenu._targetRaycast for use by ui.lua.

local Target = LastMenu.Target
local Config = LastMenu.Config

-- ── Raycast distance ───────────────────────────────────────────────────────

---@return number
local function getTargetDist()
    local d = Config.target_max_distance
    if type(d) ~= 'number' or d <= 0 then
        if Config.debug then
            print('[LastMenu] target_max_distance invalid (' .. tostring(d) .. ') — using 10.0')
        end
        return 10.0
    end
    if d > 50 and Config.debug then
        print('[LastMenu] target_max_distance > 50m — expect raycast performance degradation under heavy entity load')
    end
    return d
end

-- ── Raycast helper ─────────────────────────────────────────────────────────

---@param  maxDist number
---@return integer|nil
local function getRaycastHit(maxDist)
    local playerPed = PlayerPedId()
    local camPos    = GetFinalRenderedCamCoord()
    local camRot    = GetFinalRenderedCamRot(0)

    local pitch = math.rad(camRot.x)
    local yaw   = math.rad(camRot.z)
    local dir   = vector3(
        math.cos(pitch) * math.sin(-yaw),
        math.cos(pitch) * math.cos(-yaw),
        math.sin(pitch)
    )
    local endPos = camPos + dir * maxDist

    local handle = StartShapeTestLosProbe(
        camPos.x, camPos.y, camPos.z,
        endPos.x, endPos.y, endPos.z,
        -1, playerPed, 7
    )

    local status, hit, _, _, entity = GetShapeTestResult(handle)

    local timeout = 0
    while status == 1 and timeout < 10 do
        Citizen.Wait(0)
        status, hit, _, _, entity = GetShapeTestResult(handle)
        timeout = timeout + 1
    end

    if status == 2 and hit == 1 and entity ~= 0 and DoesEntityExist(entity) then
        return entity
    end

    return nil
end

-- ── Spatial pre-filter radius ──────────────────────────────────────────────

---@return number
local function getSpatialRadius()
    return getTargetDist() + 5.0
end

-- ── Zone match dispatch ─────────────────────────────────────────────────────

local _ctx = {}

local _zoneDispatch = EasySwitch.new({ safe = true })
    :when('sphere', function()
        if #(_ctx.playerCoords - _ctx.reg.coords) <= _ctx.reg.radius then
            _ctx.matched[#_ctx.matched + 1] = { id = _ctx.id, reg = _ctx.reg, entity = nil }
        end
    end)
    :when('box', function()  -- OBB test
        local reg = _ctx.reg
        local pc  = _ctx.playerCoords
        local dx  = pc.x - reg.coords.x
        local dy  = pc.y - reg.coords.y
        local rad = math.rad(-reg.heading)
        local lx  =  dx * math.cos(rad) + dy * math.sin(rad)
        local ly  = -dx * math.sin(rad) + dy * math.cos(rad)
        if math.abs(lx) <= reg.width / 2 and math.abs(ly) <= reg.length / 2 then
            _ctx.matched[#_ctx.matched + 1] = { id = _ctx.id, reg = reg, entity = nil }
        end
    end)
    :when('poly', function()  -- 2D polygon with Z bounds
        local reg = _ctx.reg
        local pc  = _ctx.playerCoords
        local pz  = pc.z
        if pz >= reg.minZ and pz <= reg.maxZ then
            local px, py = pc.x, pc.y
            local pts    = reg.points
            local inside = false
            local j      = #pts
            for i2 = 1, #pts do
                local xi, yi = pts[i2].x, pts[i2].y
                local xj, yj = pts[j].x,  pts[j].y
                if ((yi > py) ~= (yj > py)) and
                   (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
                    inside = not inside
                end
                j = i2
            end
            if inside then
                _ctx.matched[#_ctx.matched + 1] = { id = _ctx.id, reg = reg, entity = nil }
            end
        end
    end)
    :when('entity', function()
        if not _ctx.entityExists then return end
        local reg  = _ctx.reg
        local dist = #(_ctx.playerCoords - _ctx.entityPos)
        if reg.entity == _ctx.entity and dist <= reg.distance then
            _ctx.matched[#_ctx.matched + 1] = { id = _ctx.id, reg = reg, entity = _ctx.entity }
        end
    end)
    :when('model', function()
        if not _ctx.entityExists then return end
        local reg  = _ctx.reg
        local dist = #(_ctx.playerCoords - _ctx.entityPos)
        if (reg.model == nil or reg.model == _ctx.entityModel) and dist <= reg.distance then
            _ctx.matched[#_ctx.matched + 1] = { id = _ctx.id, reg = reg, entity = _ctx.entity }
        end
    end)

-- ── Match resolution ────────────────────────────────────────────────────────

---@param  entity       integer|nil
---@param  playerCoords vector3
---@return table[]
local function findMatchingRegs(entity, playerCoords)
    local matched = {}

    -- Guard against gta-streaming-five.dll crash on partially loaded entities.
    -- GetEntityType is the safest initial check (0=invalid, 1=ped, 2=vehicle, 3=object).
    -- Wrap coord/model fetches in pcall — they can throw on entities mid-streaming.
    local entityExists = entity and entity ~= 0 and DoesEntityExist(entity)
    local entityPos    = nil
    local entityModel  = nil

    if entityExists then
        local eType = GetEntityType(entity)

        if eType > 0 then
            local okPos, pos = pcall(GetEntityCoords, entity)
            if okPos then entityPos = pos end

            local okModel, model = pcall(GetEntityModel, entity)
            if okModel then entityModel = model end

            if not okPos or not okModel then entityExists = false end
        else
            entityExists = false
        end
    end

    local spatialRadius = getSpatialRadius()
    for id, reg in pairs(Target._registrations) do

        if reg.coords then
            if #(playerCoords - reg.coords) > spatialRadius then
                goto continueReg
            end
        elseif entityExists and entityPos then
            if #(playerCoords - entityPos) > spatialRadius then
                goto continueReg
            end
        end

        _ctx.id           = id
        _ctx.reg          = reg
        _ctx.matched      = matched
        _ctx.playerCoords = playerCoords
        _ctx.entityExists = entityExists
        _ctx.entityPos    = entityPos
        _ctx.entityModel  = entityModel
        _ctx.entity       = entity
        _zoneDispatch:execute(reg.type)

        ::continueReg::
    end

    return matched
end

-- ── Label priority ──────────────────────────────────────────────────────────

-- entity (exact hit) > model > zone (sphere/box/poly).
---@param  allMatched table[]
---@return string
local function pickLabel(allMatched)
    for _, m in ipairs(allMatched) do
        if m.reg.type == 'entity' then return m.reg.label end
    end
    for _, m in ipairs(allMatched) do
        if m.reg.type == 'model'  then return m.reg.label end
    end
    return (allMatched[1] and allMatched[1].reg.label) or 'Interact'
end

rawset(LastMenu, '_targetRaycast', {
    getRaycastHit    = getRaycastHit,
    findMatchingRegs = findMatchingRegs,
    pickLabel        = pickLabel,
    getTargetDist    = getTargetDist,
})
