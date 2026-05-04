fx_version 'cerulean'
game 'gta5'

name        'LastMenu'
description 'Universal menu system for FiveM'
author    '𝖪𝖺𝗆𝗂𝗈𝗇'
version     '1.0.0'

server_scripts {
    'server/version.lua',
}

client_scripts {
    'client/librairie/easyswitch.lua',           -- 0. EasySwitchLua — structural dispatch library
    'client/config.lua',                        -- 1. Global config (debug flag, tunables)
    'client/sound.lua',                         -- 2. Native GTA V UI sounds
    'client/bridge.lua',                        -- 3. NUI communication layer
    'client/stack.lua',                         -- 3. Navigation stack + cursor management
    'client/reactive.lua',                      -- 4. Reactive diff/patch engine
    'client/core.lua',                          -- 5. GenerateMenuId + Escape handler
    'client/builders/target/zones.lua',         -- 6a. Target: registration API
    'client/builders/target/raycast.lua',       -- 6b. Target: geometry + detection
    'client/builders/target/ui.lua',            -- 6c. Target: polling thread + debug draw
    'client/builders/*.lua',                    -- 7. Other menu builders (alert, context, input, notify, progress, radial)
    'client/exports.lua',                       -- 8. Public exports
    'client/settings.lua',                      -- 9. User settings panel (F12, always available)
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/assets/**',
    'ui/theme/**',
}
