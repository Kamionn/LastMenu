-- config.lua
-- Creates the single LastMenu namespace and defines global configuration.
--
-- NAMESPACE USAGE (internal scripts):
--   All modules register themselves via rawset(LastMenu, 'Key', value).
--   After exports.lua loads, a __newindex metatable blocks external overwrites.
--
-- CONFIG USAGE (consumer resources):
--   LastMenu.Config.debug = true     -- enable reactive engine logging
--   LastMenu.Config.close_on_distance = 5.0

-- ── Namespace bootstrap ───────────────────────────────────────────────────────
-- rawset bypasses any future metatable so this always succeeds.
rawset(_G, 'LastMenu', {})
rawset(LastMenu, 'EasySwitch', EasySwitch)

-- ── Config ────────────────────────────────────────────────────────────────────

---@class LM.Config
---@field debug               boolean         Reactive engine stats every 60 ticks (F8 console).
---@field debugTarget         boolean         Draw target zones in-world.
---@field target_hold_key     integer         FiveM control ID for the targeting reticle.
---@field target_max_distance number          Maximum raycast distance for the target system (metres). Raise this if you register targets with distance > 10.
---@field close_on_distance   number|nil      Auto-close menu when player walks this many units away. nil = disabled.
---@field max_stack_depth     integer         Max simultaneously stacked menus (extra pushes are silently dropped).
---@field sound_fn            fun(name: string)|nil  Custom sound handler; nil = PlaySoundFrontend fallback.
---@field hold_duration       integer|nil     Global default hold-to-confirm duration (ms). nil = 1500ms. Overridden per-button via opts.confirm_hold = <number>.

local Config = {}
Config.debug               = false
Config.debugTarget         = false
Config.target_hold_key     = 36       -- INPUT_DUCK (Left Ctrl)
Config.target_max_distance = 10.0     -- metres; raise if registrations use distance > 10
Config.close_on_distance   = nil
Config.max_stack_depth     = 10
Config.sound_fn            = nil
Config.hold_duration       = nil      -- ms; nil = 1500ms default

rawset(LastMenu, 'Config', Config)

-- ── Validation helper ─────────────────────────────────────────────────────────
-- Used by builders in debug mode to surface wrong-type arguments early.
-- Zero overhead when Config.debug = false.

---@param val     any
---@param expected string   Lua type name
---@param context  string   Human-readable field path (e.g. "slider.min")
local function _LM_Assert(val, expected, context)
    if not Config.debug then return end     -- zero overhead in production
    if val == nil then return end           -- nil is always allowed (optional param)
    if type(val) ~= expected then
        print(string.format(
            '[LastMenu] Validation warning: %s — expected %s, got %s',
            context, expected, type(val)
        ))
    end
end

rawset(LastMenu, '_assert', _LM_Assert)
