-- settings.lua

local Bridge = LastMenu.Bridge
local Stack  = LastMenu.Stack

-- User preferences stored on the LastMenu namespace so other modules can read them.
-- stack.lua reads LastMenu._userNav; target.lua reads LastMenu._userTargetKey.
rawset(LastMenu, '_userNav',       'both')
rawset(LastMenu, '_userTargetKey', 36)
rawset(LastMenu, '_userSounds',    true)

local _settingsOpen = false

local function openSettings()
    if _settingsOpen then return end
    _settingsOpen = true
    Stack.overlayOpen()
    Bridge.send('settings', { show = true })
end

local function closeSettings()
    if not _settingsOpen then return end
    _settingsOpen = false
    Stack.overlayClose()
    Bridge.send('settings', { show = false })
end

local _VALID_NAV   = { both = true, mouse = true, keyboard = true }
local _VALID_TKEYS = { [36] = true, [38] = true, [47] = true, [20] = true }

-- Restore persisted user preferences when the NUI page loads.
-- The NUI sends its localStorage values in the 'ready' payload so Lua
-- reflects them immediately, without waiting for the user to open settings.
Bridge.onReady = function(data)
    if not data then return end
    if _VALID_NAV[data.navMode] then
        rawset(LastMenu, '_userNav', data.navMode)
    end
    if type(data.targetKey) == 'number' and _VALID_TKEYS[data.targetKey] then
        rawset(LastMenu, '_userTargetKey', data.targetKey)
    end
    if type(data.uiSounds) == 'boolean' then
        rawset(LastMenu, '_userSounds', data.uiSounds)
    end
    -- NUI page reloaded (resource restart): reset target state so the polling
    -- thread re-sends 'open' now that the NUI is actually ready to receive it.
    if LastMenu._targetUi then
        LastMenu._targetUi.resetMatchKey()
    end
end

RegisterNUICallback('settings:update', function(data, cb)
    if data and _VALID_NAV[data.navMode] then
        rawset(LastMenu, '_userNav', data.navMode)
    end
    if data and type(data.targetKey) == 'number' and _VALID_TKEYS[data.targetKey] then
        rawset(LastMenu, '_userTargetKey', data.targetKey)
    end
    if data and type(data.uiSounds) == 'boolean' then
        rawset(LastMenu, '_userSounds', data.uiSounds)
    end
    cb('ok')
end)

RegisterNUICallback('settings:close', function(_, cb)
    closeSettings()
    cb('ok')
end)

RegisterCommand('lastmenu_settings', function()
    if _settingsOpen then
        closeSettings()
    else
        openSettings()
    end
end, false)

RegisterKeyMapping('lastmenu_settings', 'Open/Close LastMenu Settings', 'keyboard', 'F12')

exports('settings_open',  openSettings)
exports('settings_close', closeSettings)
