-- sound.lua
-- Native GTA V UI sounds for LastMenu interactions.
-- Respects Config.sound_fn for custom override.

local Config = LastMenu.Config

local _SOUNDS = {
    open       = { 'SELECT',         'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    close      = { 'BACK',           'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    nav        = { 'NAV_UP_DOWN',    'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    nav_lr     = { 'NAV_LEFT_RIGHT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    select     = { 'SELECT',         'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    error      = { 'ERROR',          'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    toggle_on  = { 'TOGGLE_ON',      'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    toggle_off = { 'TOGGLE_OFF',     'HUD_FRONTEND_DEFAULT_SOUNDSET' },
}

local Sound = {}

---@param event string  'open'|'close'|'nav'|'nav_lr'|'select'|'error'|'toggle_on'|'toggle_off'
function Sound.play(event)
    if Config.sound_fn then
        Config.sound_fn(event)
        return
    end
    local s = _SOUNDS[event]
    if s then
        PlaySoundFrontend(-1, s[1], s[2], true)
    end
end

rawset(LastMenu, 'Sound', Sound)
