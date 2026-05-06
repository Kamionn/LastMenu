-- builders/alert.lua
local Bridge         = LastMenu.Bridge
local Stack          = LastMenu.Stack
local GenerateMenuId = LastMenu._genId

---@class LM.AlertBuilder
---@field title   fun(self: LM.AlertBuilder, str: string)
---@field message fun(self: LM.AlertBuilder, str: string)
---@field type    fun(self: LM.AlertBuilder, str: 'info'|'confirm'|'warn'|'error')
---@field confirm fun(self: LM.AlertBuilder, label?: string, cb?: fun())
---@field cancel  fun(self: LM.AlertBuilder, label?: string, cb?: fun())

---@class LM.AlertHandle
---@field open  fun()
---@field close fun()

---@param  id string
---@param  fn fun(b: LM.AlertBuilder)
---@return string, string, string, table|nil, table|nil
local function _buildAlert(id, fn)
    local title       = ''
    local message     = ''
    local alertType   = 'info'
    local confirmData = nil
    local cancelData  = nil
    local b           = {}

    function b:title(str)   title     = str end
    function b:message(str) message   = str end
    function b:type(str)    alertType = str end

    function b:confirm(label, cb)
        local cb_id = 'cb_' .. id .. '_confirm'
        Bridge.onCallback(cb_id, function()
            if cb then cb() end
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

    LastMenu._safeBuilder('alert', fn, b, id)
    return title, message, alertType, confirmData, cancelData
end

---@param fn fun(b: LM.AlertBuilder)
function UI_Alert(fn)
    local id = GenerateMenuId()
    local title, message, alertType, confirmData, cancelData = _buildAlert(id, fn)
    Stack.push({ id = id, type = 'alert' })
    Bridge.send('open', {
        menu = 'alert', id = id,
        data = { title = title, message = message, type = alertType, confirm = confirmData, cancel = cancelData }
    })
end

local _alertBuildCleanup = {}

AddEventHandler('LastMenu:menuClosed', function(closedId)
    local cb = _alertBuildCleanup[closedId]
    if cb then cb(); _alertBuildCleanup[closedId] = nil end
end)

---@param fn fun(b: LM.AlertBuilder)
---@return LM.AlertHandle
function UI_Alert_Build(fn)
    local _activeId = nil
    return {
        open = function()
            if _activeId then return end
            local id = GenerateMenuId()
            _activeId = id
            _alertBuildCleanup[id] = function() _activeId = nil end
            local title, message, alertType, confirmData, cancelData = _buildAlert(id, fn)
            Stack.push({ id = id, type = 'alert' })
            Bridge.send('open', {
                menu = 'alert', id = id,
                data = { title = title, message = message, type = alertType, confirm = confirmData, cancel = cancelData }
            })
        end,
        close = function()
            if not _activeId then return end
            _alertBuildCleanup[_activeId] = nil
            _activeId = nil
            Stack.pop()
        end
    }
end

-- One-liner async confirm. Wraps UI_AlertAsync with pre-filled confirm/cancel buttons.
---@param message string
---@param opts?   { type?: string, confirm_label?: string, cancel_label?: string, title?: string }
---@return boolean
function UI_ConfirmAsync(message, opts)
    opts = opts or {}
    return UI_AlertAsync(function(b)
        if opts.title then b:title(opts.title) end
        b:message(message)
        b:type(opts.type or 'confirm')
        if opts.confirm_label then b:confirm_label(opts.confirm_label) end
        if opts.cancel_label  then b:cancel_label(opts.cancel_label)  end
    end)
end

-- Async variant — blocks the current coroutine until confirmed or cancelled.
-- Must be called from a Citizen.CreateThread.
---@param fn fun(b: table)
---@return boolean
function UI_AlertAsync(fn)
    local co = coroutine.running()
    if not co then
        print('[LastMenu] alert_async must be called from a Citizen.CreateThread coroutine.')
        return false
    end

    local id           = GenerateMenuId()
    local title        = ''
    local message      = ''
    local alertType    = 'confirm'
    local confirmLabel = 'Confirm'
    local cancelLabel  = 'Cancel'
    local b            = {}

    function b:title(str)         title        = str end
    function b:message(str)       message      = str end
    function b:type(str)          alertType    = str end
    function b:confirm_label(str) confirmLabel = str end
    function b:cancel_label(str)  cancelLabel  = str end

    LastMenu._safeBuilder('alert_async', fn, b, id)

    local confirmCbId = 'cb_' .. id .. '_confirm'
    local cancelCbId  = 'cb_' .. id .. '_cancel'
    local resolved    = false

    local evHandle
    evHandle = AddEventHandler('LastMenu:menuClosed', function(menuId)
        if menuId ~= id or resolved then return end
        resolved = true
        RemoveEventHandler(evHandle)
        coroutine.resume(co, false)
    end)

    Bridge.onCallback(confirmCbId, function()
        if resolved then return end
        resolved = true
        RemoveEventHandler(evHandle)
        Stack.pop()
        coroutine.resume(co, true)
    end, id)

    Bridge.onCallback(cancelCbId, function()
        if resolved then return end
        resolved = true
        RemoveEventHandler(evHandle)
        Stack.pop()
        coroutine.resume(co, false)
    end, id)

    Stack.push({ id = id, type = 'alert' })
    Bridge.send('open', {
        menu = 'alert', id = id,
        data = {
            title   = title,   message = message,   type = alertType,
            confirm = { id = confirmCbId, label = confirmLabel },
            cancel  = { id = cancelCbId,  label = cancelLabel  },
        }
    })

    return coroutine.yield()
end
