-- examples/reactive_status.lua
-- A live status panel that updates in real time without close/reopen.
-- The reactive engine polls watcher functions at configurable intervals
-- and sends only the changed fields to the NUI — no full rebuild needed.
--
-- Demonstrates:
--   • b:stat() with reactive value and color functions
--   • b:button() with reactive badge and color
--   • UI_Context_Build — persistent handle
--   • handle.update(newFn?) — full structural rebuild while the menu is open
--   • When to use reactive watchers vs. handle.update()
--
-- Key rule:
--   Use watcher functions (visible/disabled/value as fn) when only VALUES change.
--   Use handle.update() when the item COUNT or STRUCTURE changes (adds/removes rows).

-- ── Simulated vitals (replace with your framework's data source) ──────────────
local vitals = { health = 200, armour = 50, hunger = 85, thirst = 60 }

-- Simulate vitals degrading over time
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3000)
        vitals.hunger = math.max(0, vitals.hunger - math.random(1, 3))
        vitals.thirst = math.max(0, vitals.thirst - math.random(2, 5))
        vitals.health = math.max(0, math.min(200, vitals.health + math.random(-5, 5)))
    end
end)

-- ── Wanted system state (changes structure: adds/removes the Wanted row) ───────
local wantedStars = 0   -- 0 = clean, 1–5 = wanted

-- ── Base builder — no wanted row ──────────────────────────────────────────────
local function buildBaseStatus(b)
    b:title('Player Status')
    b:nav('keyboard')
    b:cancelable(true)

    -- Reactive stats: polled every 500 ms by the watcher engine.
    -- Only changed values generate a NUI patch — no frame budget wasted.
    b:stat('Health', {
        icon    = 'heart',
        value   = function() return vitals.health end,
        max     = 200,
        suffix  = ' hp',
        color   = 'auto',   -- green/orange/red based on value/max ratio
        refresh = 500,
    })

    b:stat('Armour', {
        icon    = 'shield',
        value   = function() return vitals.armour end,
        max     = 100,
        suffix  = '%',
        color   = '#60a5fa',
        refresh = 500,
    })

    b:separator()

    b:stat('Hunger', {
        icon    = 'utensils',
        value   = function() return vitals.hunger end,
        max     = 100,
        suffix  = '%',
        color   = 'auto',
        refresh = 500,
    })

    b:stat('Thirst', {
        icon    = 'droplets',
        value   = function() return vitals.thirst end,
        max     = 100,
        suffix  = '%',
        color   = 'auto',
        refresh = 500,
    })

    b:separator()

    -- Reactive badge shows current level without closing the menu
    b:button('XP', {
        id        = 'btn_xp',
        icon      = 'star',
        badge     = function() return string.format('%d / %d', vitals.hunger * 10, 1000) end,
        keep_open = true,
        refresh   = 1000,
        cb        = function() end,
    })
end

-- ── Extended builder — adds a wanted row ──────────────────────────────────────
local function buildStatusWithWanted(b)
    buildBaseStatus(b)
    b:separator()
    b:header('WANTED', { color = '#f87171' })
    b:stat('Wanted Level', {
        icon    = 'star',
        value   = wantedStars,   -- static snapshot is fine when update() is called on change
        max     = 5,
        color   = '#f87171',
    })
end

-- ── Handle ────────────────────────────────────────────────────────────────────
-- statusHandle is used inside the builder callbacks, so declare it before using local.
-- Safe because handle.open() runs the builder lazily — only when open() is called.
local statusHandle

statusHandle = UI_Context_Build(buildBaseStatus)

-- ── Refresh button — force structural rebuild while open ──────────────────────
-- Structural rebuilds (handle.update) are more expensive than watcher patches.
-- Use them only when item count or order changes (e.g., adding/removing the Wanted row).
local function addRefreshButton(b)
    b:separator()
    b:button('Refresh', {
        icon      = 'refresh-cw',
        keep_open = true,
        cb        = function()
            -- Rebuilds all items in-place, restarts watchers.
            -- No flicker — NUI receives a full 'open' with the same menu ID.
            statusHandle.update()
        end,
    })
    b:back('Close')
end

-- Re-build base with the refresh button at the bottom
statusHandle = UI_Context_Build(function(b)
    buildBaseStatus(b)
    addRefreshButton(b)
end)

-- ── External update — called when the player gets a wanted star ───────────────
-- This adds a row that doesn't exist in buildBaseStatus,
-- so a structural rebuild (handle.update) is needed.
local function onWantedLevelChanged(stars)
    wantedStars = stars

    if not statusHandle then return end

    if stars > 0 then
        statusHandle.update(function(b)
            buildStatusWithWanted(b)
            addRefreshButton(b)
        end)
    else
        -- Back to base layout (no wanted row)
        statusHandle.update(function(b)
            buildBaseStatus(b)
            addRefreshButton(b)
        end)
    end
end

-- Simulate a wanted level event (e.g. from a server event)
AddEventHandler('status:setWanted', function(stars)
    onWantedLevelChanged(stars)
end)

-- ── Open on command ───────────────────────────────────────────────────────────
RegisterCommand('status', function()
    statusHandle.open()
end, false)

-- ── Debug helpers ─────────────────────────────────────────────────────────────
RegisterCommand('status_wanted', function(src, args)
    local stars = tonumber(args[1]) or 3
    onWantedLevelChanged(math.max(0, math.min(5, stars)))
end, false)

RegisterCommand('status_clear', function()
    onWantedLevelChanged(0)
end, false)
