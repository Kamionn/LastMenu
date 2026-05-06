-- settings.lua

local Bridge = LastMenu.Bridge
local Stack  = LastMenu.Stack
local Config = LastMenu.Config

-- ── Keymapping descriptions per language ──────────────────────────────────────
-- Read at resource start from KVP so the correct language is used in the GTA
-- key-bindings menu even before the NUI loads.
local _KM_LABELS = {
    fr = { settings = 'Ouvrir/Fermer les paramètres',   target = 'Maintenir pour cibler' },
    en = { settings = 'Open/Close Settings',            target = 'Hold for target' },
    es = { settings = 'Abrir/Cerrar ajustes',           target = 'Mantener para apuntar' },
    de = { settings = 'Einstellungen öffnen/schließen', target = 'Halten zum Zielen' },
    pt = { settings = 'Abrir/Fechar configurações',     target = 'Segurar para mirar' },
    it = { settings = 'Apri/Chiudi impostazioni',       target = 'Tieni premuto per mirare' },
    ru = { settings = 'Открыть/Закрыть настройки',      target = 'Удерживать для прицела' },
    pl = { settings = 'Otwórz/zamknij ustawienia',      target = 'Przytrzymaj do celowania' },
}

local _startLang   = GetResourceKvpString('lm_language') or 'en'
local _startLabels = _KM_LABELS[_startLang] or _KM_LABELS['en']

-- ── User preferences ──────────────────────────────────────────────────────────
-- stack.lua reads _userNav; target/ui.lua reads _targetHeld; core.lua reads _userHoldDuration.
rawset(LastMenu, '_userNav',          'both')
rawset(LastMenu, '_targetHeld',       false)
rawset(LastMenu, '_userSounds',       true)
rawset(LastMenu, '_userHoldDuration', false)  -- false = not set → defer to dev/Config

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

local _VALID_NAV = { both = true, mouse = true, keyboard = true }

-- ── Target hold key (RegisterKeyMapping + command pair) ───────────────────────
-- +lastmenu_target / -lastmenu_target track whether the key is held.
-- The default binding comes from Config.target_key (set in config.lua).
-- Players can rebind it freely in GTA Pause → Settings → Key Bindings.
RegisterCommand('+lastmenu_target', function()
    rawset(LastMenu, '_targetHeld', true)
end, false)

RegisterCommand('-lastmenu_target', function()
    rawset(LastMenu, '_targetHeld', false)
end, false)

RegisterKeyMapping('+lastmenu_target', _startLabels.target, 'keyboard', Config.target_key or 'LMENU')

-- ── Settings panel command ────────────────────────────────────────────────────
RegisterCommand('lastmenu_settings', function()
    if _settingsOpen then closeSettings() else openSettings() end
end, false)

RegisterKeyMapping('lastmenu_settings', _startLabels.settings, 'keyboard', Config.settings_key or 'F12')

-- ── Restore persisted user preferences when the NUI page loads ───────────────
-- The NUI sends its localStorage values in the 'ready' payload so Lua
-- reflects them immediately, without waiting for the user to open settings.
local function _applyHoldDuration(ms)
    if type(ms) == 'number' and ms >= 500 and ms <= 3000 then
        rawset(LastMenu, '_userHoldDuration', ms)
    else
        rawset(LastMenu, '_userHoldDuration', false)
    end
end

Bridge.onReady = function(data)
    if not data then return end
    if _VALID_NAV[data.navMode] then
        rawset(LastMenu, '_userNav', data.navMode)
    end
    if type(data.uiSounds) == 'boolean' then
        rawset(LastMenu, '_userSounds', data.uiSounds)
    end
    -- Sync language KVP from NUI localStorage (source of truth for language).
    if type(data.language) == 'string' then
        SetResourceKvp('lm_language', data.language)
    end
    _applyHoldDuration(data.holdDuration)
    -- NUI page reloaded (resource restart): reset target state so the polling
    -- thread re-sends 'open' now that the NUI is actually ready to receive it.
    if LastMenu._targetUi then
        LastMenu._targetUi.resetMatchKey()
    end
end

RegisterNUICallback('settings:update', function(data, cb)
    if not data then cb('ok'); return end
    if _VALID_NAV[data.navMode] then
        rawset(LastMenu, '_userNav', data.navMode)
    end
    if type(data.uiSounds) == 'boolean' then
        rawset(LastMenu, '_userSounds', data.uiSounds)
    end
    -- Persist language so RegisterKeyMapping uses the right translation on next start.
    if type(data.language) == 'string' then
        SetResourceKvp('lm_language', data.language)
    end
    _applyHoldDuration(data.holdDuration)
    cb('ok')
end)

RegisterNUICallback('settings:close', function(_, cb)
    closeSettings()
    cb('ok')
end)

exports('settings_open',  openSettings)
exports('settings_close', closeSettings)
