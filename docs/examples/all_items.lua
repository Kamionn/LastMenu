-- examples/all_items.lua
-- Exhaustive showcase of every context menu item type.
--
-- Demonstrates:
--   • All meta builders: title, banner, description, nav, animation, search, page_size, scroll
--   • button — icon, badge, gradient, hint, hotkey, arrow, confirm_hold, cooldown,
--              timeout, preview, reactive label/disabled/visible, keep_open
--   • slider, stepper, checkbox, toggle, list
--   • stat — static and reactive (value/max as functions)
--   • input_inline — text and number
--   • color_picker with presets
--   • date_picker with min/format
--   • separator, header
--   • accordion — collapsible section with inner items
--   • tab — tabbed layout
--   • submenu — shorthand push helper with b:back()
--   • handle pattern: open / close / update
--
-- Open with: /showcase
local UI = exports['LastMenu']

local isOnDuty  = false
local isInVeh   = function() return GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 end
local health    = function() return GetEntityHealth(PlayerPedId()) - 100 end
local armour    = function() return GetPedArmour(PlayerPedId()) end
local randomValue = 0
local randomWord = ""
local randomStatValue = 0
local words = {"Apple", "Kiwi", "Pizza", "Burger", "Banana", "Sushi"}
local icon = {"apple", "kiwi-bird", "pizza-slice", "hamburger", "lemon", "fish", "clock", "shield", "heart", "star", "zap", "map", "wrench", "briefcase", "log-out", "clipboard-check", "gift", "settings", "settings-2", "crosshair", "package", "shield", "check", "x", "plus-circle", "sun", "map-pin"}
local currentWord = "Apple"

Citizen.CreateThread(function()
    while true do
        randomValue = math.random(0, 90)
        currentWord = words[math.random(#words)]
        Citizen.Wait(1000) 
    end
end)



-- ── Settings state ────────────────────────────────────────────────────────────
local cfg = {
    volume   = 80,
    kits     = 2,
    fuelIdx  = 1,
    turbo    = false,
    stealth  = true,
    color    = '#e94560',
    deadline = '',
    speedCap = 120,
}


-- ── Build handle (build once, open many times) ────────────────────────────────
local showcaseHandle = UI:context(function(menu)

    -- ── Meta ─────────────────────────────────────────────────────────────────
    menu:title('Component Showcase')
    menu:description('Every LastMenu item type in one menu.')
    menu:nav('both')
    menu:animation('slideLeft')
    menu:search()   -- always show search bar
    menu:banner('https://media1.tenor.com/m/P17l4K3NHxYAAAAd/one-piece-egghead.gif')

    -- ─────────────────────────────────────────────────────────────────────────
    menu:header('Buttons')

    -- Basic button
    menu:button('Simple Button', {
        icon = 'mouse-pointer',
        hint = 'Feedback on click',
        cb   = function()
            UI_Notify(function(n)
                n:message('Button clicked!'); n:type('success'); n:duration(2000)
            end)
        end,
    })

    -- Badge + gradient background
    menu:button('Buy Item', {
        icon     = 'shopping-cart',
        color    = '#4ade80',
        gradient = true,
        badge    = '500€',
        cb       = function()
            UI_Notify(function(n) n:message('Purchased!'); n:type('success') end)
        end,
    })

    -- Hold-to-confirm (uses Config.hold_duration — default 1 500 ms)
    menu:button('Hold to Confirm', {
        icon         = 'shield',
        confirm_hold = true,
        cb           = function()
            UI_Notify(function(n) n:message('Hold confirmed!'); n:type('info') end)
        end,
    })

    -- Hold-to-confirm with custom duration (3 000 ms)
    menu:button('Delete Save (3 s hold)', {
        icon         = 'trash',
        color        = '#f87171',
        confirm_hold = 3000,
        cb           = function()
            UI_Notify(function(n) n:message('Deleted.'); n:type('error') end)
        end,
    })

    -- Cooldown 5 s — keep_open auto-set when cooldown is present
    menu:button('Ability (5 s cooldown)', {
        icon     = 'zap',
        cooldown = 5000,
        cb       = function()
            UI_Notify(function(n) n:message('Ability used!'); n:type('success') end)
        end,
    })

    -- Timeout — item auto-disables 8 s after the menu opens
    menu:button('Limited Offer (8 s)', {
        icon    = 'clock',
        badge   = 'EXPIRES',
        timeout = 8000,
        cb      = function()
            UI_Notify(function(n) n:message('Accepted in time!'); n:type('success') end)
        end,
    })

    -- Hotkey label shown as <kbd>
    menu:button('Open Map', {
        icon   = 'map',
        hotkey = 'M',
        cb     = function() end,
    })

    -- Preview panel on hover / keyboard focus
    menu:button('Engine Repair', {
        icon    = 'wrench',
        preview = {
            title = 'Engine Repair',
            desc  = 'Restores engine health to 100 %.',
            stats = {
                { label = 'Before', value = 20,  max = 100 },
                { label = 'After',  value = 100, max = 100, color = '#4ade80' },
            },
        },
        cb = function() end,
    })

    -- Reactive badge + color — re-evaluated every 500 ms without rebuilding the menu
    menu:button('Duty Toggle', {
        icon      = 'briefcase',
        badge     = function() return isOnDuty and 'ON' or 'OFF' end,
        color     = function() return isOnDuty and '#4ade80' or '#f87171' end,
        keep_open = true,
        refresh   = 500,
        cb        = function()
            isOnDuty = not isOnDuty
            UI_Notify(function(n)
                n:message(isOnDuty and 'On duty.' or 'Off duty.')
                n:type(isOnDuty and 'success' or 'warning')
            end)
        end,
    })

    -- Reactive visible — sector disappears when not in a vehicle
    menu:button('Exit Vehicle', {
        icon    = 'log-out',
        visible = isInVeh,
        refresh = 500,
        cb      = function() TaskLeaveAnyVehicle(PlayerPedId(), 0, 16) end,
    })

    -- Reactive disabled — grayed out, visible but not clickable when off duty
    menu:button('Duty Action', {
        icon     = 'clipboard-check',
        disabled = function() return not isOnDuty end,
        refresh  = 500,
        cb       = function()
            UI_Notify(function(n) n:message('Action done!'); n:type('success') end)
        end,
    })

    -- Persistent cooldown — survives NUI reload (stored in ResourceKvp)
    -- menu:button('Daily Bonus', {
    --     icon        = 'gift',
    --     cooldown    = 80,  -- 24 h
    --     persist_key = 'daily_bonus',
    --     cb          = function()
    --         UI_Notify(function(n) n:message('Daily bonus claimed!'); n:type('success') end)
    --     end,
    -- })

    -- Arrow button → opens a submenu (keep_open automatic with arrow=true)
    menu:button('More Options →', {
        icon      = 'settings',
        arrow     = true,
        keep_open = true,
        cb        = function()
            UI_Context(function(sub)
                sub:title('More Options')
                sub:animation('slideRight')
                sub:button('Option A', { icon = 'check', cb = function() end })
                sub:button('Option B', { icon = 'x',     cb = function() end })
                sub:back('Back')
            end)
        end,
    })

    -- b:submenu() shorthand — equivalent to the arrow button above
    menu:submenu('Settings (shorthand)', function(sub)
        sub:title('Settings')
        sub:toggle('God Mode', { icon = 'star',    default = false, cb = function(v) SetEntityInvincible(PlayerPedId(), v) end })
        sub:toggle('No Clip',  { icon = 'eye',     default = false, cb = function(v) end })
        sub:back()
    end, { icon = 'settings-2' })

    -- ─────────────────────────────────────────────────────────────────────────
    menu:separator()
    menu:header('Input Controls')

    -- Slider — drag or ← / →
    menu:slider('Volume', {
        icon    = 'volume-2',
        min     = 0,
        max     = 100,
        step    = 5,
        default = cfg.volume,
        suffix  = '%',
        cb      = function(value) cfg.volume = value end,
    })

    -- Stepper — − / value / +
    menu:stepper('Repair Kits', {
        icon    = 'package',
        min     = 0,
        max     = 10,
        step    = 1,
        default = cfg.kits,
        cb      = function(value) cfg.kits = value end,
    })

    -- Checkbox — square toggle boolean
    menu:checkbox('Enable Turbo', {
        icon    = 'zap',
        default = cfg.turbo,
        cb      = function(checked) cfg.turbo = checked end,
    })

    -- Toggle — animated pill switch ON/OFF
    menu:toggle('Stealth Mode', {
        icon    = 'eye-off',
        default = cfg.stealth,
        cb      = function(enabled) cfg.stealth = enabled end,
    })

    -- List — ‹ value › carousel
    menu:list('Fuel Type', {
        icon    = 'fuel',
        items   = { 'Gasoline', 'Diesel', 'Electric', 'Hybrid' },
        default = cfg.fuelIdx,
        cb      = function(index, value)
            cfg.fuelIdx = index
            UI_Notify(function(n) n:message('Fuel: ' .. value); n:type('info') end)
        end,
    })

    -- List with hold-to-confirm per selection
    menu:list('Transmission', {
        icon         = 'settings',
        items        = { 'Automatic', 'Manual', 'Sport' },
        confirm_hold = true,
        cb           = function(index, value)
            UI_Notify(function(n) n:message('Set: ' .. value); n:type('info') end)
        end,
    })

    -- Inline text input — confirms on Enter or blur
    menu:input_inline('Vehicle Name', {
        icon        = 'edit',
        type        = 'text',
        placeholder = 'My ride…',
        default     = '',
        maxlen      = 24,
        cb          = function(value)
            UI_Notify(function(n) n:message('Name: ' .. value); n:type('success') end)
        end,
    })

    -- Inline number input with range constraint
    menu:input_inline('Speed Cap', {
        icon    = 'gauge',
        type    = 'number',
        default = cfg.speedCap,
        min     = 0,
        max     = 300,
        cb      = function(value)
            cfg.speedCap = value
            UI_Notify(function(n) n:message('Cap: ' .. value .. ' km/h'); n:type('info') end)
        end,
    })

    -- Color picker with preset swatches
    menu:color_picker('Body Color', {
        icon    = 'palette',
        default = cfg.color,
        presets = { '#e94560', '#60a5fa', '#4ade80', '#fb923c', '#a78bfa', '#f9fafb' },
        cb      = function(hex)
            cfg.color = hex
            UI_Notify(function(n) n:message('Color: ' .. hex); n:type('info') end)
        end,
    })

    -- Date picker — returns ISO string "YYYY-MM-DD"
    menu:date_picker('Review Date', {
        icon    = 'calendar',
        default = cfg.deadline,
        min     = '2025-01-01',
        format  = 'dmy',   -- display format: DD/MM/YYYY
        cb      = function(date)
            cfg.deadline = date
            UI_Notify(function(n) n:message('Date: ' .. date); n:type('info') end)
        end,
    })

    -- ─────────────────────────────────────────────────────────────────────────
    menu:separator()
    menu:header('Stat Bars')

    -- Static values
    menu:stat('Engine', {
        icon   = 'activity',
        value  = 78,
        max    = 100,
        suffix = '%',
    })

    -- Reactive value — polled every 500 ms via the watcher engine
    menu:stat('Health', {
        icon    = 'heart',
        value   = health,       -- function() → number
        max     = 100,
        suffix  = 'hp',
        color   = 'auto',       -- green ≥70 %, orange ≥35 %, red <35 %
        refresh = 500,
    })

    menu:stat('Armour', {
        icon    = 'shield',
        value   = armour,
        max     = 100,
        suffix  = '%',
        color   = '#60a5fa',    -- explicit hex override
        refresh = 500,
    })

    -- Reactive max — useful for dynamic pool sizes
    menu:stat('XP', {
        icon    = 'star',
        value   = function() return 3200 end,
        max     = function() return 5000 end,   -- max can also be reactive
        suffix  = ' pts',
        refresh = 2000,
    })

    -- ─────────────────────────────────────────────────────────────────────────
    menu:separator()
    menu:header('Layout')

    -- Accordion — collapsible section; buttons inside default to keep_open=true
    menu:accordion('Player Info', function(acc)
        acc:stat('Health', { icon = 'heart',  value = health, max = 100, suffix = '%', refresh = 500 })
        acc:stat('Armour', { icon = 'shield', value = armour, max = 100, suffix = '%', refresh = 500 })
        acc:separator()
        acc:button('Heal to Full', {
            icon      = 'plus-circle',
            keep_open = false,   -- override: close menu on click
            cb        = function()
                SetEntityHealth(PlayerPedId(), 200)
                UI_Notify(function(n) n:message('Healed!'); n:type('success') end)
            end,
        })
    end, { icon = 'user', open = true })

    menu:accordion('Advanced Settings', function(acc)
        acc:toggle('God Mode', { icon = 'star',    default = false, cb = function(v) SetEntityInvincible(PlayerPedId(), v) end })
        acc:toggle('No Clip',  { icon = 'eye',     default = false, cb = function(v) end })
        acc:slider('Time',     { icon = 'sun',     min = 0, max = 23, step = 1, default = 12, cb = function(v) NetworkOverrideClockTime(v, 0, 0) end })
        acc:checkbox('Show on minimap', { icon = 'map-pin', default = true, cb = function(v) end })
    end, { icon = 'settings' })

    -- Tabs — tab bar appears automatically when at least one tab is defined
    menu:separator()
    menu:submenu("Tab", function(sub)
        sub:title("Tab")
        sub:tab('Weapons', function(t)
            t:button('Pistol',  { icon = 'crosshair', badge = '500€',  cb = function() end })
            t:button('Shotgun', { icon = 'crosshair', badge = '800€',  cb = function() end })
            t:button('Rifle',   { icon = 'crosshair', badge = '1 200€', confirm_hold = true, cb = function() end })
            t:button('RPG',     { icon = 'crosshair', badge = '5 000€', confirm_hold = 3000,  cb = function() end })
        end, { icon = 'crosshair' })

        sub:tab('Ammo', function(t)
            t:button('9 mm × 50',    { icon = 'package', badge = '80€',  cb = function() end })
            t:button('Shotgun × 20', { icon = 'package', badge = '120€', cb = function() end })
            t:button('Rifle × 30',   { icon = 'package', badge = '200€', cb = function() end })
        end, { icon = 'package' })

            sub:tab('Armor', function(t)
                t:button('Body Armor L1', { icon = 'shield', badge = '250€', cb = function() end })
                t:button('Body Armor L2', { icon = 'shield', badge = '500€', cb = function() end })
                t:checkbox('Auto-equip',  { icon = 'check', default = true, cb = function(v) end })
            end, { icon = 'shield' })
            sub:back()
        end, { icon = "chevron-right" })
        

    menu:submenu('Dynamic Components', function(sub)
        sub:banner('https://i.redd.it/fe54ohu28zsf1.gif')
        sub:title('Dynamic Components')
        sub:description('Every reactive field — live updates without rebuilding.')

        -- ── Stats ─────────────────────────────────────────────────────────────
        sub:header('Stats')
        sub:stat('Random Value', {
            icon    = 'dices',
            value   = function() return randomValue end,
            max     = 100,
            suffix  = ' %',
            color   = 'auto',
            refresh = 1000,
        })
        sub:stat('Health', {
            icon    = 'heart',
            value   = health,
            max     = 100,
            suffix  = 'hp',
            color   = 'auto',
            refresh = 500,
        })

        -- ── Button fields ─────────────────────────────────────────────────────
        sub:separator()
        sub:header('Button Fields')

        -- label
        sub:button(function() return 'Word: ' .. currentWord end, {
            icon    = 'type',
            refresh = 1000,
            cb      = function() end,
        })

        -- badge
        sub:button('Random Badge', {
            icon    = 'tag',
            badge   = function() return currentWord end,
            refresh = 1000,
            cb      = function() end,
        })

        -- color
        sub:button('Shifting Color', {
            icon      = 'palette',
            color     = function()
                if     randomValue >= 60 then return '#4ade80'
                elseif randomValue >= 30 then return '#fb923c'
                else                          return '#f87171' end
            end,
            keep_open = true,
            refresh   = 1000,
            cb        = function() end,
        })

        -- visible — disappears when not in a vehicle
        sub:button('Speed Boost', {
            icon    = 'gauge',
            visible = isInVeh,
            hint    = 'Only visible in a vehicle',
            refresh = 500,
            cb      = function() end,
        })

        -- disabled — grays out automatically when randomValue > 50
        sub:button('Duty Action', {
            icon     = 'briefcase',
            disabled = function() return randomValue > 50 end,
            hint     = 'Disabled when randomValue > 50',
            refresh  = 500,
            cb       = function() end,
        })

        -- preview — reactive table, updates live via JSON comparison
        sub:button('Live Preview', {
            icon    = 'eye',
            preview = function()
                return {
                    title = currentWord,
                    desc  = 'Snapshot at ' .. randomValue .. ' %',
                    stats = {
                        { label = 'Random', value = randomValue, max = 100 },
                        { label = 'Health', value = health(),    max = 100, color = '#f87171' },
                    },
                }
            end,
            refresh = 1000,
            cb      = function() end,
        })

        sub:back()
    end, { icon = 'activity' })
    menu:back('Close')
end)

RegisterCommand('showcase', function()
    showcaseHandle.open()
end, false)
