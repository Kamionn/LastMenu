-- examples/notifications.lua
-- All notification patterns in one file.
--
-- Demonstrates:
--   • All types: info, success, warn, error
--   • n:icon() — custom icon override
--   • n:title() — optional header above the message
--   • n:duration() — auto-dismiss delay
--   • n:persistent() — never auto-dismisses
--   • n:group(key) — deduplication: replaces the existing toast with the same key
--   • n:on_dismiss(cb) — callback when user clicks × (not fired on auto-expiry)
--   • Multiple independent group keys coexisting

local LastMenu = exports['LastMenu']

local function notify(msg, t, dur, icon)
    LastMenu:notify(function(n)
        n:message(msg)
        n:type(t or 'info')
        if dur  then n:duration(dur) end
        if icon then n:icon(icon) end
    end)
end

-- ── 1. All types ──────────────────────────────────────────────────────────────
RegisterCommand('notify_types', function()
    LastMenu:notify(function(n) n:message('Information message.');     n:type('info');    n:duration(3000) end)
    LastMenu:notify(function(n) n:message('Action completed!');        n:type('success'); n:duration(3000) end)
    LastMenu:notify(function(n) n:message('Caution: dangerous zone.'); n:type('warn');    n:duration(4000) end)
    LastMenu:notify(function(n) n:message('Critical error occurred.'); n:type('error');   n:duration(5000) end)
end, false)

-- ── 2. Custom icon + title ────────────────────────────────────────────────────
RegisterCommand('notify_icon', function()
    LastMenu:notify(function(n)
        n:title('New Mission')
        n:message('Deliver the package to the docks.')
        n:type('info')
        n:icon('map-pin')
        n:duration(5000)
    end)

    LastMenu:notify(function(n)
        n:title('Reward')
        n:message('You earned 500€ for completing the job.')
        n:type('success')
        n:icon('coins')
        n:duration(4000)
    end)
end, false)

-- ── 3. Persistent toast (never auto-dismisses) ────────────────────────────────
RegisterCommand('notify_persistent', function()
    LastMenu:notify(function(n)
        n:message('Server maintenance in 5 minutes — save your progress.')
        n:type('warn')
        n:persistent()
        n:on_dismiss(function()
            notify('Maintenance notice acknowledged.', 'info', 2000)
        end)
    end)
end, false)

-- ── 4. Group deduplication ────────────────────────────────────────────────────
-- Sending a toast with the same group key immediately replaces the previous one.
-- The timer restarts from the new toast's duration.
RegisterCommand('notify_zone', function()
    local zones = { 'Red Zone — Danger', 'Blue Zone — Restricted', 'Green Zone — Safe' }
    local idx   = math.random(#zones)

    LastMenu:notify(function(n)
        n:message(zones[idx])
        n:type(idx == 1 and 'error' or idx == 2 and 'warn' or 'success')
        n:duration(6000)
        n:group('zone_status')  -- replaces any existing 'zone_status' toast
    end)
end, false)

-- ── 5. Multiple independent group keys ───────────────────────────────────────
-- Different keys never interfere with each other.
RegisterCommand('notify_hud', function()
    LastMenu:notify(function(n)
        n:message('Coins: 1 250')
        n:type('info')
        n:icon('coins')
        n:duration(4000)
        n:group('hud_coins')
    end)

    LastMenu:notify(function(n)
        n:message('HP: 43 / 100')
        n:type('warn')
        n:icon('heart')
        n:duration(4000)
        n:group('hud_health')
    end)
end, false)

-- ── 6. Group + persistent — connection status ─────────────────────────────────
local connectionLost = false

RegisterCommand('notify_disconnect', function()
    connectionLost = true
    LastMenu:notify(function(n)
        n:message('Connection lost — reconnecting…')
        n:type('error')
        n:icon('wifi-off')
        n:persistent()
        n:group('connection')
        n:on_dismiss(function()
            notify('Connection alert dismissed.', 'info', 2000)
        end)
    end)
end, false)

RegisterCommand('notify_reconnect', function()
    if not connectionLost then return end
    connectionLost = false
    LastMenu:notify(function(n)
        n:message('Connection restored.')
        n:type('success')
        n:icon('wifi')
        n:duration(3000)
        n:group('connection')   -- replaces the persistent "connection lost" toast
    end)
end, false)

-- ── 7. Rapid-fire notifications — all stack independently ────────────────────
RegisterCommand('notify_spam', function()
    local types = { 'info', 'success', 'warn', 'error' }
    for i = 1, 5 do
        LastMenu:notify(function(n)
            n:message('Notification #' .. i)
            n:type(types[math.random(#types)])
            n:duration(2000 + i * 500)
        end)
    end
end, false)

-- ── 8. Framework-style shorthand wrapper ──────────────────────────────────────
-- Drop this in your shared utilities to avoid writing the builder everywhere.
local LMNotify = {}

function LMNotify.success(msg, dur)
    LastMenu:notify(function(n) n:message(msg); n:type('success'); n:duration(dur or 3000) end)
end
function LMNotify.error(msg, dur)
    LastMenu:notify(function(n) n:message(msg); n:type('error');   n:duration(dur or 4000) end)
end
function LMNotify.warn(msg, dur)
    LastMenu:notify(function(n) n:message(msg); n:type('warn');    n:duration(dur or 4000) end)
end
function LMNotify.info(msg, dur)
    LastMenu:notify(function(n) n:message(msg); n:type('info');    n:duration(dur or 3000) end)
end

-- Usage:
-- LMNotify.success('Vehicle repaired.')
-- LMNotify.error('Not enough money.', 5000)
