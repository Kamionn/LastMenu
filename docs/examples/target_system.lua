-- examples/target_system.lua
-- Full target system showcase using the builder API.
--
-- Demonstrates:
--   • target_add_entity  — specific entity handle
--   • target_add_model   — all entities matching a model (nil = all vehicles)
--   • target_add_sphere  — sphere zone with on_enter / on_leave
--   • target_add_box     — OBB box zone (table form — builder has no width/length/heading)
--   • target_add_poly    — polygon zone with minZ/maxZ (table form)
--   • Builder API: t:label, t:icon, t:distance, t:banner, t:on_enter, t:on_leave
--   • Actions:    t:button, t:toggle, t:checkbox, t:slider, t:separator
--   • t:group     — accordion inside the target menu
--   • t:submenu   — opens another menu on top WITHOUT closing the target menu
--   • opts.condition / opts.disabled — per-action visibility and graying
--   • Cleanup pattern via onResourceStop

local LastMenu  = exports['LastMenu']
local isOnDuty  = false

local function notify(msg, t)
    LastMenu:notify(function(n) n:message(msg); n:type(t or 'info') end)
end

-- ── 1. Entity target — register on a spawned prop ────────────────────────────
-- Call this after your entity exists. Returns an ID usable with target_remove.
local function registerPropTarget(obj)
    return LastMenu:target_add_entity(obj, function(t)
        t:label('Prop')
        t:icon('box')
        t:distance(2.0)

        t:button('Examine', {
            icon = 'search',
            cb   = function(entity)
                notify('Examining entity handle: ' .. entity)
            end,
        })

        t:button('Delete', {
            icon         = 'trash',
            color        = '#f87171',
            confirm_hold = 2000,
            condition    = function() return isOnDuty end,
            cb           = function(entity)
                DeleteObject(entity)
                notify('Object deleted.', 'success')
            end,
        })
    end)
end

-- ── 2. Model target — police peds ─────────────────────────────────────────────
local copId = LastMenu:target_add_model('s_m_y_cop_01', function(t)
    t:label('Officer')
    t:icon('user')
    t:distance(3.0)

    t:button('Talk', {
        icon = 'message-square',
        cb   = function(entity)
            LastMenu:context(function(menu)
                menu:title('Officer Dialogue')
                menu:button('Ask for directions', { icon = 'map-pin',     cb = function() notify('He points north.') end })
                menu:button('Request ID check',   { icon = 'credit-card', cb = function() notify('ID checked.') end })
                menu:button('Report crime',        { icon = 'alert-circle', cb = function() notify('Crime reported.', 'warning') end })
                menu:back('End Conversation')
            end)
        end,
    })

    t:button('Surrender Weapons', {
        icon      = 'package',
        condition = function(entity) return GetPedArmour(PlayerPedId()) > 0 end,
        cb        = function(entity)
            SetPedArmour(PlayerPedId(), 0)
            notify('Surrendered weapons.', 'success')
        end,
    })

    t:button('Check Warrant', {
        icon     = 'file-text',
        disabled = function() return not isOnDuty end,
        cb       = function(entity) notify('No active warrant.') end,
    })
end)

-- ── 3. Model target — all vehicles (nil model) — mechanic job ─────────────────
local vehicleId = LastMenu:target_add_model(nil, function(t)  -- nil = all vehicles
    t:label('Vehicle')
    t:icon('car')
    t:distance(4.0)

    t:button('Inspect', {
        icon = 'clipboard-list',
        cb   = function(entity)
            local eng  = GetVehicleEngineHealth(entity)
            local body = GetVehicleBodyHealth(entity)
            LastMenu:context(function(menu)
                menu:title('Vehicle Diagnostic')
                menu:stat('Engine', { value = math.floor(eng),  max = 1000, icon = 'activity', suffix = ' hp' })
                menu:stat('Body',   { value = math.floor(body), max = 1000, icon = 'shield',   suffix = ' hp' })
                menu:back('Close')
            end)
        end,
    })

    t:button('Repair', {
        icon         = 'wrench',
        gradient     = true,
        confirm_hold = 2000,
        cooldown     = 60000,
        condition    = function() return isOnDuty end,
        cb           = function(entity)
            SetVehicleEngineHealth(entity, 1000.0)
            SetVehicleBodyHealth(entity, 1000.0)
            notify('Vehicle repaired.', 'success')
        end,
    })

    t:separator()

    t:group('Services', { icon = 'tool' }, function(g)
        g:button('Clean', {
            icon = 'droplets',
            cb   = function(entity) WashDecalsFromVehicle(entity, 1.0); notify('Cleaned.', 'success') end,
        })
        g:button('Inflate Tyres', {
            icon = 'circle-dot',
            cb   = function(entity)
                for i = 0, 3 do SetVehicleTyreFix(entity, i) end
                notify('Tyres inflated.', 'success')
            end,
        })
        g:button('Charge Battery', {
            icon = 'battery-charging',
            cb   = function(entity)
                SetVehicleEngineHealth(entity, 1000.0)
                notify('Battery charged.', 'success')
            end,
        })
    end)

    t:group('Options', { icon = 'settings-2' }, function(g)
        g:toggle('Lock', {
            icon    = 'lock',
            default = false,
            cb      = function(entity, val)
                SetVehicleDoorsLocked(entity, val and 2 or 1)
                notify(val and 'Locked.' or 'Unlocked.')
            end,
        })
        g:slider('Fuel', {
            icon    = 'fuel',
            min     = 0,
            max     = 100,
            step    = 5,
            default = 50,
            suffix  = '%',
            cb      = function(entity, val)
                SetVehicleFuelLevel(entity, val * 0.65)
            end,
        })
        g:checkbox('Invoice sent', {
            icon    = 'receipt',
            default = false,
            cb      = function(entity, val)
                if val then notify('Invoice sent to owner.', 'success') end
            end,
        })
    end)

    -- Submenu: keep target panel open, open a context on top
    t:submenu('Advanced Options', {
        icon = 'settings-2',
        cb   = function(entity)
            LastMenu:context(function(menu)
                menu:title('Advanced Options')
                menu:button('Paint Shop',  { icon = 'paintbrush', cb = function() notify('Opening paint…') end })
                menu:button('Tuning Shop', { icon = 'gauge',       cb = function() notify('Opening tuning…') end })
                menu:back('Back')
            end)
        end,
    })
end)

-- ── 4. Sphere zone — warehouse entrance ───────────────────────────────────────
local warehouseId = LastMenu:target_add_sphere(
    vector3(-1037.5, -1714.7, 13.2),
    5.0,
    function(t)
        t:label('Warehouse')
        t:icon('warehouse')
        t:distance(5.0)
        t:on_enter(function() notify('You entered the warehouse zone.', 'info') end)
        t:on_leave(function() notify('You left the warehouse zone.', 'info')    end)

        t:button('Enter', {
            icon = 'door-open',
            cb   = function()
                SetEntityCoords(PlayerPedId(), -1037.5, -1714.7, 14.0, false, false, false, true)
                notify('Entered warehouse.', 'success')
            end,
        })
        t:button('Check Stock', {
            icon      = 'package',
            condition = function() return isOnDuty end,
            cb        = function() notify('Stock: 47 units.') end,
        })
    end
)

-- ── 5. Box zone — bank vault ──────────────────────────────────────────────────
-- width/length/heading are not available in the builder API; use the table form.
local vaultId = LastMenu:target_add_box(
    vector3(149.7, -1042.1, 29.3),
    {
        width    = 4.0,
        length   = 3.0,
        heading  = 0.0,
        label    = 'Vault',
        icon     = 'landmark',
        distance = 3.0,
        actions  = {
            {
                label        = 'Access Vault',
                icon         = 'key',
                confirm_hold = 3000,
                cb           = function()
                    notify('Vault accessed.', 'success')
                    TriggerServerEvent('bank:accessVault')
                end,
            },
            {
                label     = 'Security Check',
                icon      = 'shield-check',
                condition = function() return isOnDuty end,
                cb        = function() notify('Security check passed.') end,
            },
        },
    }
)

-- ── 6. Polygon zone — L-shaped store floor ────────────────────────────────────
-- minZ/maxZ are not available in the builder API; use the table form.
local storeFloor = {
    vector2(312.0, -780.0),
    vector2(320.0, -780.0),
    vector2(320.0, -795.0),
    vector2(328.0, -795.0),
    vector2(328.0, -808.0),
    vector2(312.0, -808.0),
}

local storeId = LastMenu:target_add_poly(storeFloor, {
    minZ     = 28.5,
    maxZ     = 32.0,
    label    = '24/7 Store',
    icon     = 'store',
    distance = 3.0,
    on_enter = function() notify('Welcome to the 24/7 Store!', 'info') end,
    on_leave = function() notify('Thanks for visiting.', 'info')        end,
    actions  = {
        {
            label = 'Shop',
            icon  = 'shopping-cart',
            cb    = function()
                LastMenu:context(function(menu)
                    menu:title('24/7 Shop')
                    menu:button('Snacks — 5€',   { icon = 'coffee',       badge = '5€',   cb = function() notify('Purchased snacks.',  'success') end })
                    menu:button('Water  — 3€',   { icon = 'droplets',     badge = '3€',   cb = function() notify('Purchased water.',   'success') end })
                    menu:button('Med Kit — 150€', { icon = 'plus-circle', badge = '150€', cb = function() notify('Purchased med kit.', 'success') end })
                    menu:back('Leave Store')
                end)
            end,
        },
        {
            label        = 'Rob the Cashier',
            icon         = 'alert-triangle',
            color        = '#f87171',
            confirm_hold = true,
            condition    = function() return IsPedArmed(PlayerPedId(), 6) end,
            cb           = function()
                notify('You robbed the store!', 'error')
                TriggerServerEvent('crime:robbery', GetCurrentResourceName())
            end,
        },
    },
})

-- ── Cleanup ───────────────────────────────────────────────────────────────────
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    LastMenu:target_remove(copId)
    LastMenu:target_remove(vehicleId)
    LastMenu:target_remove(warehouseId)
    LastMenu:target_remove(vaultId)
    LastMenu:target_remove(storeId)
end)
