-- builders/progress.lua
local Bridge         = LastMenu.Bridge
local Stack          = LastMenu.Stack
local GenerateMenuId = LastMenu._genId

---@class LM.ProgressBuilder
---@field label      fun(self: LM.ProgressBuilder, str: string)
---@field duration   fun(self: LM.ProgressBuilder, ms: integer)
---@field cancelable fun(self: LM.ProgressBuilder, bool: boolean)
---@field icon       fun(self: LM.ProgressBuilder, str: string)
---@field cb_tick    fun(self: LM.ProgressBuilder, cb: fun(pct: number))
---@field anim       fun(self: LM.ProgressBuilder, opts: table)
---@field prop       fun(self: LM.ProgressBuilder, opts: table)
---@field confirm    fun(self: LM.ProgressBuilder, cb?: fun())
---@field cancel     fun(self: LM.ProgressBuilder, cb?: fun())

---@class LM.ProgressHandle
---@field open  fun()
---@field close fun()

---@param t fun()[]
local function _runCleanup(t)
    for _, cfn in ipairs(t) do pcall(cfn) end
    for i = #t, 1, -1 do t[i] = nil end
end

---@param  id string
---@param  fn fun(b: LM.ProgressBuilder)
---@return string, integer, boolean, string|nil, string|nil, string|nil, fun(pct: number)|nil, table|nil, table|nil, fun()[]
local function _buildProgress(id, fn)
    local label      = ''
    local duration   = 5000
    local cancelable = false
    local cbComplete = nil
    local cbCancel   = nil
    local icon       = nil
    local cbTick     = nil
    local animData   = nil
    local propData   = nil
    local cleanup    = {}
    local b          = {}

    function b:label(str)   label      = str          end
    function b:duration(ms) duration   = ms           end
    function b:cancelable(bool) cancelable = bool == true end
    function b:icon(str)        icon       = str          end
    function b:cb_tick(cb)      cbTick     = cb           end
    function b:anim(opts)       animData   = opts         end
    function b:prop(opts)       propData   = opts         end

    function b:confirm(cb)
        local cb_id = 'cb_' .. id .. '_complete'
        Bridge.onCallback(cb_id, function()
            _runCleanup(cleanup)
            if cb then cb() end
            Stack.pop()
        end, id)
        cbComplete = cb_id
    end

    function b:cancel(cb)
        local cb_id = 'cb_' .. id .. '_cancel'
        Bridge.onCallback(cb_id, function()
            _runCleanup(cleanup)
            if cb then cb() end
            Stack.pop()
        end, id)
        cbCancel = cb_id
    end

    LastMenu._safeBuilder('progress', fn, b, id)
    return label, duration, cancelable, cbComplete, cbCancel, icon, cbTick, animData, propData, cleanup
end

---@param id       string
---@param duration integer
---@param animData table|nil
---@param propData table|nil
---@param cbTick   fun(pct: number)|nil
---@param cleanup  fun()[]
local function _startSideEffects(id, duration, animData, propData, cbTick, cleanup)
    local _alive = true
    local _cleanupEv
    _cleanupEv = AddEventHandler('LastMenu:menuClosed', function(menuId)
        if menuId == id then
            _alive = false
            for _, cfn in ipairs(cleanup) do pcall(cfn) end
            RemoveEventHandler(_cleanupEv)
        end
    end)

    if animData and animData.dict then
        local ped = PlayerPedId()
        Citizen.CreateThread(function()
            RequestAnimDict(animData.dict)
            local t = 0
            while not HasAnimDictLoaded(animData.dict) and t < 3000 do
                Citizen.Wait(50); t = t + 50
            end
            if HasAnimDictLoaded(animData.dict) then
                TaskPlayAnim(ped, animData.dict, animData.clip or '', 8.0, -8.0, -1,
                    animData.flag or 49, 0, false, false, false)
                cleanup[#cleanup + 1] = function()
                    if DoesEntityExist(ped) then ClearPedTasks(ped) end
                end
            end
        end)
    end

    if propData and propData.model then
        Citizen.CreateThread(function()
            local modelHash = type(propData.model) == 'string' and GetHashKey(propData.model) or propData.model
            RequestModel(modelHash)
            local t = 0
            while not HasModelLoaded(modelHash) and t < 3000 do
                Citizen.Wait(50); t = t + 50
            end
            if not HasModelLoaded(modelHash) then return end
            local ped  = PlayerPedId()
            local bone = propData.bone or 0
            if type(bone) == 'string' then
                local boneIdx = GetEntityBoneIndexByName(ped, bone)
                bone = boneIdx ~= -1 and GetPedBoneIndex(ped, boneIdx) or 0
            end
            local ox  = propData.offset and propData.offset.x or 0.0
            local oy  = propData.offset and propData.offset.y or 0.0
            local oz  = propData.offset and propData.offset.z or 0.0
            -- Accept both 'rot' (documented name) and 'rotation' (legacy alias).
            local rd  = propData.rot or propData.rotation
            local rx  = rd and rd.x or 0.0
            local ry  = rd and rd.y or 0.0
            local rz  = rd and rd.z or 0.0
            local propHandle = CreateObject(modelHash, 0.0, 0.0, 0.0, true, true, false)
            AttachEntityToEntity(propHandle, ped, bone, ox, oy, oz, rx, ry, rz,
                true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(modelHash)
            cleanup[#cleanup + 1] = function()
                if DoesEntityExist(propHandle) then
                    DetachEntity(propHandle, true, true)
                    DeleteObject(propHandle)
                end
            end
        end)
    end

    if cbTick then
        Citizen.CreateThread(function()
            local start = GetGameTimer()
            while _alive do
                local pct = math.min((GetGameTimer() - start) / duration * 100, 100)
                pcall(cbTick, pct)
                Citizen.Wait(100)
            end
        end)
    end
end

---@param id string
---@param fn fun(b: LM.ProgressBuilder)
local function _openProgressInstance(id, fn)
    local label, duration, cancelable, cbComplete, cbCancel, icon, cbTick, animData, propData, cleanup
        = _buildProgress(id, fn)

    if not cbComplete then
        local cb_id = 'cb_' .. id .. '_complete'
        Bridge.onCallback(cb_id, function()
            _runCleanup(cleanup)
            Stack.pop()
        end, id)
        cbComplete = cb_id
    end
    if not cbCancel and cancelable then
        local cb_id = 'cb_' .. id .. '_cancel'
        Bridge.onCallback(cb_id, function()
            _runCleanup(cleanup)
            Stack.pop()
        end, id)
        cbCancel = cb_id
    end

    Stack.push({ id = id, type = 'progress', cancelable = cancelable })
    Bridge.send('open', {
        menu = 'progress', id = id,
        data = {
            label       = label,
            duration    = duration,
            cancelable  = cancelable,
            icon        = icon,
            cb_complete = cbComplete,
            cb_cancel   = cbCancel,
        }
    })

    _startSideEffects(id, duration, animData, propData, cbTick, cleanup)
end

---@param fn fun(b: LM.ProgressBuilder)
function UI_Progress(fn)
    _openProgressInstance(GenerateMenuId(), fn)
end

local _progressBuildCleanup = {}

AddEventHandler('LastMenu:menuClosed', function(closedId)
    local cb = _progressBuildCleanup[closedId]
    if cb then cb(); _progressBuildCleanup[closedId] = nil end
end)

---@param fn fun(b: LM.ProgressBuilder)
---@return LM.ProgressHandle
function UI_Progress_Build(fn)
    local _activeId = nil
    return {
        open = function()
            if _activeId then return end
            local id = GenerateMenuId()
            _activeId = id
            _progressBuildCleanup[id] = function() _activeId = nil end
            _openProgressInstance(id, fn)
        end,
        close = function()
            if not _activeId then return end
            _progressBuildCleanup[_activeId] = nil
            _activeId = nil
            Stack.pop()
        end,
    }
end
