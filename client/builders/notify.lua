-- builders/notify.lua
local Bridge         = LastMenu.Bridge
local GenerateMenuId = LastMenu._genId

---@class LM.NotifyBuilder
---@field message    fun(self: LM.NotifyBuilder, str: string)
---@field type       fun(self: LM.NotifyBuilder, str: 'info'|'success'|'warn'|'error')
---@field duration   fun(self: LM.NotifyBuilder, ms: integer)
---@field icon       fun(self: LM.NotifyBuilder, str: string)
---@field title      fun(self: LM.NotifyBuilder, str: string)
---@field group      fun(self: LM.NotifyBuilder, str: string)
---@field persistent fun(self: LM.NotifyBuilder)
---@field on_dismiss fun(self: LM.NotifyBuilder, cb: fun())

-- Tracks active persistent-notification dismiss callbacks so they can be purged on resource stop.
local _activeDismissCbs = {}

-- Cleans up dismiss callbacks that expired by timeout (not × click).
RegisterNUICallback('notify_expired', function(data, cb)
    if data and data.dismiss_cb and _activeDismissCbs[data.dismiss_cb] then
        Bridge.removeCallback(data.dismiss_cb)
        _activeDismissCbs[data.dismiss_cb] = nil
    end
    cb('ok')
end)

-- Purge any remaining dismiss callbacks if the resource stops while a persistent toast is open.
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        for cbId in pairs(_activeDismissCbs) do
            Bridge.removeCallback(cbId)
        end
    end
end)

---@param fn fun(b: LM.NotifyBuilder)
function UI_Notify(fn)
    local id        = GenerateMenuId()
    local message   = ''
    local notifType = 'info'
    local duration  = 3000
    local icon      = nil
    local group     = nil
    local title     = nil
    local dismissCb = nil
    local b         = {}

    function b:message(str)    message   = str  end
    function b:type(str)       notifType = str  end
    function b:duration(ms)    duration  = ms   end
    function b:icon(str)       icon      = str  end
    function b:title(str)      title     = str  end
    function b:persistent()    duration  = 0    end
    function b:group(str)      group     = str  end
    function b:on_dismiss(cb)  dismissCb = cb   end

    local ok, err = pcall(fn, b)
    if not ok then print('[LastMenu] notify builder error: ' .. tostring(err)) end

    local dismissCbId = nil
    if type(dismissCb) == 'function' then
        dismissCbId = 'ndismiss_' .. id
        _activeDismissCbs[dismissCbId] = true
        Bridge.onCallback(dismissCbId, function(_)
            dismissCb()
            Bridge.removeCallback(dismissCbId)
            _activeDismissCbs[dismissCbId] = nil
        end)
    end

    Bridge.send('open', {
        menu = 'notify', id = id,
        data = {
            message    = message,
            type       = notifType,
            duration   = duration,
            icon       = icon,
            title      = title,
            group      = group,
            dismiss_cb = dismissCbId,
        }
    })
end
