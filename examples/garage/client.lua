-- LastMenu Example: Complete Garage System
--
-- Demonstrates:
--   context()         — tabbed menu with sub-menus and reactive stats
--   alert()           — confirmation before destructive/costly actions
--   progress()        — progress bar with ped and prop animations
--   notify()          — result toasts
--   target_add_sphere() — interaction zone on the ground
--
-- FICTIONAL DATA — replace with your actual server-side logic.

local LM = exports.LastMenu

-- ─── Mock Data ───────────────────────────────────────────────────────────────

local playerVehicles = {
    { model = "adder",    label = "Adder",    fuel = 82, bodyHealth = 1000 },
    { model = "zentorno", label = "Zentorno", fuel = 41, bodyHealth = 740  },
    { model = "t20",      label = "T20",      fuel = 95, bodyHealth = 980  },
}

local vehiclesForSale = {
    { model = "sultan",   label = "Sultan RS",   price = 12000 },
    { model = "elegy2",   label = "Elegy RH8",   price = 95000 },
    { model = "banshee2", label = "Banshee 900R", price = 565000 },
}

local garageCoords = vector3(215.0, -810.0, 30.0)

-- ─── Utilities ───────────────────────────────────────────────────────────────

local function healthToColor(hp)
    local pct = hp / 1000
    if pct > 0.75 then return "#4ade80" end -- Green
    if pct > 0.40 then return "#facc15" end -- Yellow
    return "#f87171" -- Red
end

local function formatPrice(n)
    return string.format("$ %d", n)
end

-- ─── Owned Vehicle Sub-Menu ──────────────────────────────────────────────────

local function openVehicleMenu(vehicle)
    LM:context(function(menu)
        menu:title(vehicle.label)
        menu:description("Vehicle Options")
        menu:animation("slideRight")

        -- Reactive Stat: Fuel (simulated here)
        menu:stat("Fuel Level", {
            value  = function() return vehicle.fuel end,
            max    = 100,
            suffix = "%",
            color  = "auto",
            refresh = 1000,
        })

        -- Reactive Stat: Body Condition
        menu:stat("Body Health", {
            value  = function() return vehicle.bodyHealth end,
            max    = 1000,
            color  = function() return healthToColor(vehicle.bodyHealth) end,
            refresh = 800,
        })

        menu:separator()

        -- Retrieve Vehicle
        menu:button("Retrieve Vehicle", {
            icon = "car",
            arrow = true,
            cb = function()
                LM:alert(function(a)
                    a:title("Retrieve Vehicle")
                    a:message("Spawn the " .. vehicle.label .. " in front of the garage?")
                    a:confirm("Retrieve", function()
                        LM:progress(function(p)
                            p:label("Retrieving vehicle...")
                            p:duration(3000)
                            p:icon("car")
                            p:anim({
                                dict  = "anim@heists@ornate_bank@security_guard",
                                clip  = "stand_fire_loop_pistol",
                                flag  = 1,
                            })
                            p:onComplete(function()
                                -- In production: RequestModel() + CreateVehicle()
                                LM:notify(function(n)
                                    n:message(vehicle.label .. " retrieved successfully!")
                                    n:type("success")
                                    n:duration(4000)
                                end)
                            end)
                        end)
                    end)
                    a:cancel("Cancel")
                end)
            end,
        })

        -- Repair Vehicle
        menu:button("Repair", {
            icon     = "wrench",
            disabled = function() return vehicle.bodyHealth >= 1000 end,
            badge    = function()
                if vehicle.bodyHealth >= 1000 then return "OK" end
                return string.format("%d%%", math.floor(vehicle.bodyHealth / 10))
            end,
            refresh = 1000,
            cb = function()
                local cost = math.floor((1000 - vehicle.bodyHealth) * 0.8)
                LM:alert(function(a)
                    a:title("Repair Vehicle")
                    a:message(string.format(
                        "Repair the %s for %s?",
                        vehicle.label, formatPrice(cost)
                    ))
                    a:confirm("Pay & Repair", function()
                        LM:progress(function(p)
                            p:label("Repair in progress...")
                            p:duration(5000)
                            p:cancel(true)
                            p:icon("wrench")
                            p:anim({
                                dict = "amb@world_human_welding@male@base",
                                clip = "base",
                                flag = 1,
                            })
                            p:prop({
                                model    = "prop_tool_torch",
                                bone     = 57005,
                                offset   = vector3(0.0, 0.0, 0.0),
                                rotation = vector3(0.0, 0.0, 0.0),
                            })
                            p:onComplete(function()
                                vehicle.bodyHealth = 1000
                                LM:notify(function(n)
                                    n:message(vehicle.label .. " repaired!")
                                    n:type("success")
                                end)
                            end)
                            p:onCancel(function()
                                LM:notify(function(n)
                                    n:message("Repair cancelled.")
                                    n:type("warning")
                                    n:duration(2500)
                                end)
                            end)
                        end)
                    end)
                    a:cancel("Cancel")
                end)
            end,
        })

        -- Sell Vehicle (confirm_hold to prevent accidents)
        menu:button("Sell Vehicle", {
            icon         = "badge-dollar-sign",
            confirm_hold = 2000,
            hint         = formatPrice(math.floor(vehicle.price or 50000) / 2),
            cb = function()
                local idx = nil
                for i, v in ipairs(playerVehicles) do
                    if v.model == vehicle.model then idx = i break end
                end
                if idx then table.remove(playerVehicles, idx) end
                LM:notify(function(n)
                    n:message(vehicle.label .. " sold!")
                    n:type("success")
                    n:duration(5000)
                end)
            end,
        })

        menu:back("Back")
    end)
end

-- ─── Main Garage Menu ────────────────────────────────────────────────────────

local function openGarageMenu()
    LM:context(function(menu)
        menu:title("Los Santos Garage")
        menu:banner("https://i.imgur.com/placeholder.png") -- replace with actual URL
        menu:nav("both")

        -- ── Tab: My Garage ──────────────────────────────────────────────────
        menu:tab("My Garage", function(t)
            if #playerVehicles == 0 then
                t:header("No vehicles registered", { align = "center" })
                return
            end

            for _, vehicle in ipairs(playerVehicles) do
                local v = vehicle -- local capture for reactive closures
                t:button(v.label, {
                    icon   = "car",
                    arrow  = true,
                    badge  = function()
                        return string.format("%d%%", math.floor(v.bodyHealth / 10))
                    end,
                    color  = function() return healthToColor(v.bodyHealth) end,
                    refresh = 1000,
                    preview = {
                        title = v.label,
                        desc  = "Personal Vehicle",
                        stats = {
                            { label = "Fuel",   value = v.fuel,       max = 100,  color = "auto" },
                            { label = "Health", value = v.bodyHealth,  max = 1000, color = healthToColor(v.bodyHealth) },
                        },
                    },
                    cb = function() openVehicleMenu(v) end,
                })
            end
        end, { icon = "car-front" })

        -- ── Tab: Purchase ────────────────────────────────────────────────────
        menu:tab("Purchase", function(t)
            t:header("Available Vehicles", { align = "center" })

            for _, car in ipairs(vehiclesForSale) do
                local c = car
                t:button(c.label, {
                    icon  = "shopping-cart",
                    hint  = formatPrice(c.price),
                    arrow = true,
                    preview = {
                        title = c.label,
                        desc  = "Brand New — Immediate Delivery",
                        stats = {
                            { label = "Price", value = c.price, max = 1000000 },
                        },
                    },
                    cb = function()
                        LM:alert(function(a)
                            a:title("Buy " .. c.label)
                            a:message(string.format(
                                "Confirm purchase of %s for %s?",
                                c.label, formatPrice(c.price)
                            ))
                            a:confirm("Buy", function()
                                -- In production: TriggerServerEvent("garage:buyVehicle", c.model)
                                table.insert(playerVehicles, {
                                    model       = c.model,
                                    label       = c.label,
                                    fuel        = 100,
                                    bodyHealth  = 1000,
                                    price       = c.price,
                                })
                                LM:notify(function(n)
                                    n:message(c.label .. " purchased! Find it in 'My Garage'.")
                                    n:type("success")
                                    n:duration(5000)
                                end)
                            end)
                            a:cancel("Cancel")
                        end)
                    end,
                })
            end
        end, { icon = "store" })

        -- ── Tab: Settings ────────────────────────────────────────────────────
        menu:tab("Options", function(t)
            t:toggle("Garage Notifications", {
                default = true,
                icon    = "bell",
                cb = function(val)
                    LM:notify(function(n)
                        n:message("Notifications " .. (val and "enabled" or "disabled"))
                        n:type(val and "success" or "info")
                        n:duration(2000)
                    end)
                end,
            })

            t:slider("Alert Distance (m)", {
                min     = 50,
                max     = 500,
                step    = 50,
                default = 150,
                suffix  = " m",
                icon    = "radar",
            })
        end, { icon = "settings" })
    end)
end

-- ─── Garage Target Zone ──────────────────────────────────────────────────────

Citizen.CreateThread(function()
    LM:target_add_sphere(garageCoords, 3.0, {
        label   = "Garage",
        icon    = "car-front",
        actions = {
            {
                label = "Open Garage",
                icon  = "door-open",
                cb    = function() openGarageMenu() end,
            },
        },
    })
end)