-- builders/input.lua
local Bridge         = LastMenu.Bridge
local Stack          = LastMenu.Stack
local GenerateMenuId = LastMenu._genId
local assert_        = LastMenu._assert

---@class LM.InputBuilder
---@field title   fun(self: LM.InputBuilder, str: string)
---@field field   fun(self: LM.InputBuilder, label: string, opts?: table)
---@field confirm fun(self: LM.InputBuilder, label?: string, cb?: fun(values: table))
---@field cancel  fun(self: LM.InputBuilder, label?: string, cb?: fun())

---@class LM.InputHandle
---@field open  fun()
---@field close fun()

---@param fields table[]
---@param label  string
---@param opts   table?
local function _pushField(fields, label, opts)
    opts = opts or {}
    assert_(opts.min,    'number', 'field.min')
    assert_(opts.max,    'number', 'field.max')
    assert_(opts.maxlen, 'number', 'field.maxlen')
    table.insert(fields, {
        label         = label,
        type          = opts.type          or 'text',
        default       = opts.default ~= nil and tostring(opts.default) or '',
        placeholder   = opts.placeholder   or nil,
        maxlen        = opts.maxlen        or nil,
        min           = opts.min           or nil,
        max           = opts.max           or nil,
        pattern       = opts.pattern       or nil,
        pattern_error = opts.pattern_error or nil,
        index         = #fields + 1,
    })
end

---@param  id string
---@param  fn fun(b: LM.InputBuilder)
---@return table[], table|nil, table|nil, string|nil
local function _buildInput(id, fn)
    local fields      = {}
    local confirmData = nil
    local cancelData  = nil
    local title       = nil
    local b           = {}

    function b:title(str) title = str end

    function b:field(label, opts) _pushField(fields, label, opts) end

    function b:confirm(label, cb)
        local cb_id = 'cb_' .. id .. '_confirm'
        Bridge.onCallback(cb_id, function(data)
            if cb then
                local raw  = data and data.values or {}
                local cast = {}
                for i, f in ipairs(fields) do
                    local v = raw[i]
                    if f.type == 'number' then
                        cast[i] = tonumber(v)
                    else
                        cast[i] = v
                    end
                end
                cb(cast)
            end
            Stack.pop()
        end, id)
        confirmData = { id = cb_id, label = label or 'Confirm' }
    end

    function b:cancel(label, cb)
        local cb_id = 'cb_' .. id .. '_cancel'
        Bridge.onCallback(cb_id, function()
            if cb then cb() end
            Stack.pop()
        end, id)
        cancelData = { id = cb_id, label = label or 'Cancel' }
    end

    LastMenu._safeBuilder('input', fn, b, id)
    return fields, confirmData, cancelData, title
end

---@param fn fun(b: LM.InputBuilder)
function UI_Input(fn)
    local id = GenerateMenuId()
    local fields, confirmData, cancelData, title = _buildInput(id, fn)
    Stack.push({ id = id, type = 'input' })
    Bridge.send('open', {
        menu = 'input', id = id,
        data = { title = title, fields = fields, confirm = confirmData, cancel = cancelData }
    })
end

local _inputBuildCleanup = {}

AddEventHandler('LastMenu:menuClosed', function(closedId)
    local cb = _inputBuildCleanup[closedId]
    if cb then cb(); _inputBuildCleanup[closedId] = nil end
end)

---@param fn fun(b: LM.InputBuilder)
---@return LM.InputHandle
function UI_Input_Build(fn)
    local _activeId = nil
    return {
        open = function()
            if _activeId then return end
            local id = GenerateMenuId()
            _activeId = id
            _inputBuildCleanup[id] = function() _activeId = nil end
            local fields, confirmData, cancelData, title = _buildInput(id, fn)
            Stack.push({ id = id, type = 'input' })
            Bridge.send('open', {
                menu = 'input', id = id,
                data = { title = title, fields = fields, confirm = confirmData, cancel = cancelData }
            })
        end,
        close = function()
            if not _activeId then return end
            _inputBuildCleanup[_activeId] = nil
            _activeId = nil
            Stack.pop()
        end
    }
end

-- Async variant — blocks the coroutine. Must be called from Citizen.CreateThread.
---@param fn fun(b: table)
---@return table<integer, string|number>|nil
function UI_InputAsync(fn)
    local co = coroutine.running()
    if not co then
        print('[LastMenu] input_async must be called from a Citizen.CreateThread coroutine.')
        return nil
    end

    local id           = GenerateMenuId()
    local fields       = {}
    local title        = nil
    local confirmLabel = 'Confirm'
    local cancelLabel  = 'Cancel'
    local b            = {}

    function b:title(str)         title        = str end
    function b:confirm_label(str) confirmLabel = str end
    function b:cancel_label(str)  cancelLabel  = str end

    function b:field(label, opts) _pushField(fields, label, opts) end

    LastMenu._safeBuilder('input_async', fn, b, id)

    local confirmCbId = 'cb_' .. id .. '_confirm'
    local cancelCbId  = 'cb_' .. id .. '_cancel'
    local resolved    = false

    local evHandle
    evHandle = AddEventHandler('LastMenu:menuClosed', function(menuId)
        if menuId ~= id or resolved then return end
        resolved = true
        RemoveEventHandler(evHandle)
        coroutine.resume(co, nil)
    end)

    Bridge.onCallback(confirmCbId, function(data)
        if resolved then return end
        resolved = true
        RemoveEventHandler(evHandle)
        local raw  = data and data.values or {}
        local cast = {}
        for i, f in ipairs(fields) do
            local v = raw[i]
            cast[i] = (f.type == 'number' and v ~= nil) and (tonumber(v) or v) or v
        end
        Stack.pop()
        coroutine.resume(co, cast)
    end, id)

    Bridge.onCallback(cancelCbId, function()
        if resolved then return end
        resolved = true
        RemoveEventHandler(evHandle)
        Stack.pop()
        coroutine.resume(co, nil)
    end, id)

    Stack.push({ id = id, type = 'input' })
    Bridge.send('open', {
        menu = 'input', id = id,
        data = {
            title   = title, fields = fields,
            confirm = { id = confirmCbId, label = confirmLabel },
            cancel  = { id = cancelCbId,  label = cancelLabel  },
        }
    })

    return coroutine.yield()
end
