-- examples/radial_menu.lua
-- Radial menu (quick-action wheel) with submenus and reactive buttons.
--
-- Demonstrates:
--   • radial_build — persistent handle (open/close)
--   • radial       — immediate one-shot (used inside callbacks)
--   • r:center_label() — text shown in center ring when nothing is hovered
--   • r:button() — icon, cb, keep_open, confirm_hold
--   • opts.submenu — nested radial pushed onto the stack (Escape returns to parent)
--   • opts.visible  — reactive: sector removed when fn() returns false
--   • opts.disabled — reactive: sector grayed, geometry stable
--   • Gamepad support is built-in (left stick navigates, A/Cross confirms)

local LastMenu = exports['LastMenu']

-- ── Shared state ──────────────────────────────────────────────────────────────
local isOnDuty      = false
local vehicleLocked = false

local function inVehicle() return GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 end
local function notify(msg, t)
    LastMenu:notify(function(n) n:message(msg); n:type(t or 'info') end)
end

-- ── Quick wheel — persistent, opened by /wheel or a key binding ───────────────
local quickWheel = LastMenu:radial_build(function(r)
    r:center_label('Quick Actions')

    -- ── Garage sub-wheel ──────────────────────────────────────────────────────
    r:button('Garage', {
        icon    = 'car',
        submenu = function(sub)
            sub:center_label('Garage')

            sub:button('Repair', {
                icon = 'wrench',
                cb   = function()
                    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                    if veh == 0 then notify('Not in a vehicle.', 'error'); return end
                    SetVehicleEngineHealth(veh, 1000.0)
                    SetVehicleBodyHealth(veh, 1000.0)
                    notify('Vehicle repaired.', 'success')
                end,
            })

            sub:button('Clean', {
                icon = 'droplets',
                cb   = function()
                    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                    if veh == 0 then notify('Not in a vehicle.', 'error'); return end
                    WashDecalsFromVehicle(veh, 1.0)
                    notify('Vehicle cleaned.', 'success')
                end,
            })

            sub:button('Lock / Unlock', {
                icon      = 'lock',
                keep_open = true,
                cb        = function()
                    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                    if veh == 0 then return end
                    vehicleLocked = not vehicleLocked
                    SetVehicleDoorsLocked(veh, vehicleLocked and 2 or 1)
                    notify(vehicleLocked and 'Vehicle locked.' or 'Vehicle unlocked.')
                end,
            })

            sub:button('Inflate Tyres', {
                icon = 'circle-dot',
                cb   = function()
                    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                    if veh == 0 then return end
                    for i = 0, 3 do SetVehicleTyreFix(veh, i) end
                    notify('Tyres inflated.', 'success')
                end,
            })
        end,
    })

    -- Visible only when the player is inside a vehicle
    r:button('Exit Vehicle', {
        icon    = 'log-out',
        visible = inVehicle,
        refresh = 500,
        cb      = function()
            TaskLeaveAnyVehicle(PlayerPedId(), 0, 16)
        end,
    })

    -- ── Hospital sub-wheel ────────────────────────────────────────────────────
    r:button('Hospital', {
        icon    = 'plus-circle',
        submenu = function(sub)
            sub:center_label('Hospital')

            sub:button('Heal', {
                icon = 'heart',
                cb   = function()
                    SetEntityHealth(PlayerPedId(), 200)
                    notify('Healed to full.', 'success')
                end,
            })
            sub:button('Add Armor', {
                icon = 'shield',
                cb   = function()
                    SetPedArmour(PlayerPedId(), 100)
                    notify('Armor restored.', 'success')
                end,
            })
            sub:button('Revive (hold)', {
                icon         = 'activity',
                confirm_hold = true,
                cb           = function()
                    ClearPedTasksImmediately(PlayerPedId())
                    SetEntityHealth(PlayerPedId(), 200)
                    notify('Revived!', 'success')
                end,
            })
        end,
    })

    -- ── Duty sub-wheel ────────────────────────────────────────────────────────
    r:button('Duty', {
        icon    = 'briefcase',
        submenu = function(sub)
            sub:center_label('Duty')

            sub:button('Go On Duty', {
                icon    = 'check-circle',
                visible = function() return not isOnDuty end,
                refresh = 500,
                cb      = function()
                    isOnDuty = true
                    notify('You are now on duty.', 'success')
                end,
            })

            sub:button('Go Off Duty', {
                icon    = 'x-circle',
                visible = function() return isOnDuty end,
                refresh = 500,
                cb      = function()
                    isOnDuty = false
                    notify('You are now off duty.', 'warning')
                end,
            })
        end,
    })

    -- Disabled (grayed) when off duty — sector stays in place for layout stability
    r:button('Duty Action', {
        icon     = 'clipboard-check',
        disabled = function() return not isOnDuty end,
        refresh  = 500,
        cb       = function()
            notify('Action performed!', 'success')
        end,
    })

    -- ── Open the F12 settings overlay ─────────────────────────────────────────
    r:button('Settings', {
        icon = 'settings',
        cb   = function()
            LastMenu:settings_open()
        end,
    })

    -- ── Open a context menu from a radial sector ──────────────────────────────
    -- keep_open = true so the radial stays on the stack while the context is open.
    r:button('Phone', {
        icon      = 'phone',
        keep_open = true,
        cb        = function()
            LastMenu:context(function(menu)
                menu:title('Phone')
                menu:button('Contacts', {
                    icon      = 'users',
                    arrow     = true,
                    keep_open = true,
                    cb        = function()
                        LastMenu:context(function(contacts)
                            contacts:title('Contacts')
                            contacts:button('Alice',   { icon = 'user', cb = function() end })
                            contacts:button('Bob',     { icon = 'user', cb = function() end })
                            contacts:button('Charlie', { icon = 'user', cb = function() end })
                            contacts:back()
                        end)
                    end,
                })
                menu:button('Messages', { icon = 'message-square', cb = function() end })
                menu:back('Close Phone')
            end)
        end,
    })
end)

RegisterCommand('wheel', function()
    quickWheel.open()
end, false)

RegisterKeyMapping('wheel', 'Open Quick Wheel', 'keyboard', 'BACK')
