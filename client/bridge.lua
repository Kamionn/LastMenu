-- bridge.lua
-- Centralised NUI communication: batched send + scoped callbacks.
-- Registered in the LastMenu namespace as LastMenu.Bridge.

---@class LM.Bridge
---@field _callbacks  table<string, fun(data: table)>
---@field _menuCbIds  table<string, string[]>
---@field _queue      table[]|nil
---@field onClose     fun()|nil

local Config = LastMenu.Config

local Bridge = {}
Bridge._callbacks = {}
Bridge._menuCbIds = {}
Bridge._queue     = nil
-- Hook called when the NUI triggers escape or __cancel__.
-- Set by stack.lua after it loads — avoids a Bridge → Stack reverse dependency.
Bridge.onClose    = nil
-- Hook called once when the NUI page sends 'ready', with the persisted user settings payload.
-- Set by settings.lua so Lua restores user preferences without waiting for the settings panel.
Bridge.onReady    = nil

-- Enqueues a NUI message. All messages accumulated in the same tick are sent
-- as a single batch to reduce CEF round-trips.
---@param msgType string
---@param payload  table
local _MAX_PAYLOAD_BYTES = 1048576   -- 1 MB — NUI messages above this may be silently truncated

function Bridge.send(msgType, payload)
    local msg = {}
    for k, v in pairs(payload) do msg[k] = v end
    msg.type = msgType

    if Bridge._queue == nil then
        Bridge._queue = {}
        Citizen.SetTimeout(0, function()
            local batch = Bridge._queue
            Bridge._queue = nil

            local outMsg = #batch == 1 and batch[1] or { type = 'batch', messages = batch }
            if Config.debug then
                local encoded = json.encode(outMsg)
                if #encoded > _MAX_PAYLOAD_BYTES then
                    print(('[LastMenu] Bridge.send: payload too large (%d bytes > 1 MB), dropped')
                        :format(#encoded))
                    return
                end
            end
            SendNUIMessage(outMsg)
        end)
    end

    Bridge._queue[#Bridge._queue + 1] = msg
end

-- Registers a NUI callback scoped to a menu. Bridge.removeCallbacks(menu_id)
-- clears all registered callbacks for that menu at once.
---@param cb_id   string
---@param fn      fun(data: table)
---@param menu_id string|nil
function Bridge.onCallback(cb_id, fn, menu_id)
    Bridge._callbacks[cb_id] = fn

    if menu_id then
        local list = Bridge._menuCbIds[menu_id]
        if not list then
            list = {}
            Bridge._menuCbIds[menu_id] = list
        end
        list[#list + 1] = cb_id
    end
end

-- Removes a single callback by ID.
---@param cb_id string
function Bridge.removeCallback(cb_id)
    Bridge._callbacks[cb_id] = nil
end

-- Removes all callbacks registered for a menu.
---@param menu_id string
function Bridge.removeCallbacks(menu_id)
    local ids = Bridge._menuCbIds[menu_id]

    if ids then
        for _, cb_id in ipairs(ids) do
            Bridge._callbacks[cb_id] = nil
        end
    end

    Bridge._menuCbIds[menu_id] = nil
end

-- ── NUI callbacks ─────────────────────────────────────────────────────────────

RegisterNUICallback('callback', function(data, cb)
    if data.cb_id == '__cancel__' then
        if Bridge.onClose then Bridge.onClose() end
        cb('ok')
        return
    end

    local fn = Bridge._callbacks[data.cb_id]
    if fn then
        local ok, err = pcall(fn, data)
        if not ok then
            print(('[LastMenu] callback error (%s): %s'):format(tostring(data.cb_id), tostring(err)))
        end
    end
    cb('ok')
end)

RegisterNUICallback('ready', function(data, cb)
    if Bridge.onReady and data then Bridge.onReady(data) end
    cb('ok')
end)

RegisterNUICallback('escape', function(_, cb)
    if Bridge.onClose then Bridge.onClose() end
    cb('ok')
end)

-- Cooldown persistence: store/clear expiry timestamps in ResourceKvp so they
-- survive NUI reloads without being accessible or modifiable from the browser.
-- Keys are scoped to the calling resource name to prevent cross-resource collision.
local _resName        = GetCurrentResourceName()
local _MAX_EXPIRY_MS  = 365 * 24 * 3600 * 1000   -- 1 year cap — guards against math.huge from buggy clients
RegisterNUICallback('cooldown:set', function(data, cb)
    if type(data.key) == 'string' and #data.key <= 64 and data.key:match('^[%w%-_]+$') and type(data.expiry) == 'number' then
        local expiry = math.floor(math.min(data.expiry, _MAX_EXPIRY_MS))
        SetResourceKvp('lm_cd_' .. _resName .. '_' .. data.key, tostring(expiry))
    end
    cb('ok')
end)

RegisterNUICallback('cooldown:clear', function(data, cb)
    if type(data.key) == 'string' and data.key:match('^[%w%-_]+$') then
        DeleteResourceKvp('lm_cd_' .. _resName .. '_' .. data.key)
    end
    cb('ok')
end)

RegisterNUICallback('sound', function(data, cb)
    if type(data.event) == 'string' then
        LastMenu.Sound.play(data.event)
    end
    cb('ok')
end)

-- ── Register in namespace ─────────────────────────────────────────────────────
rawset(LastMenu, 'Bridge', Bridge)
