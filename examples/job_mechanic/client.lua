-- Example LastMenu: Mechanic Job
--
-- Demonstrates:
--   radial()           — main radial menu + sub-menu
--   input_async()      — quote/invoice form
--   progress()         — repair with animation + prop
--   notify()           — results with grouping
--   target_add_model() — targeting vehicles (builder API)
--                        banner, accordion, toggle, slider, checkbox,
--                        separator, gradient, confirm_hold, cooldown, submenu
--   context_build()    — reusable handle for the job status panel
--   date_picker        — appointment date

local LM = exports.LastMenu

-- ─── Job State ─────────────────────────────────────────────────────────────

local isOnDuty   = false
local jobsDone   = 0
local currentVeh = 0

-- ─── Status Panel (Reusable handle) ────────────────────────────────────────
-- Opened/Closed via F5; updates in real-time without closing.

local statusPanel = LM:context_build(function(menu)
    menu:title("Mechanic Dashboard")
    menu:animation("fade")
    menu:cancelable(true)

    menu:toggle("On Duty", {
        icon    = "hard-hat",
        default = isOnDuty,
        cb = function(val)
            isOnDuty = val
            LM:notify(function(n)
                n:message("You are now " .. (val and "on duty" or "off duty") .. ".")
                n:type(val and "success" or "warning")
                n:group("duty_status")
            end)
        end,
    })

    menu:stat("Jobs Completed", {
        value   = function() return jobsDone end,
        max     = 50,
        suffix  = " jobs",
        color   = "#60a5fa",
        refresh = 1000,
    })

    menu:separator()

    menu:date_picker("Next Appointment", {
        icon    = "calendar",
        format  = "dmy",
        default = "",
        cb = function(iso)
            LM:notify(function(n)
                n:message("Appointment registered for " .. iso)
                n:type("info")
                n:duration(4000)
            end)
        end,
    })

    menu:separator()

    menu:button("Close", {
        icon = "x-circle",
        cb   = function() statusPanel.close() end,
    })
end)

RegisterCommand("mechanic_panel", function()
    statusPanel.open()
end, false)
RegisterKeyMapping("mechanic_panel", "Mechanic Panel", "keyboard", "F5")

-- ─── Repairing a Vehicle ─────────────────────────────────────────────────────

local function repairVehicle(entity)
    LM:progress(function(p)
        p:label("Repair in progress…")
        p:duration(7000)
        p:cancel(true)
        p:icon("wrench")
        p:anim({
            dict  = "amb@world_human_welding@male@base",
            clip  = "base",
            flag  = 1,
        })
        p:prop({
            model    = "prop_tool_torch",
            bone     = 57005,
            offset   = vector3(0.12, 0.0, 0.05),
            rotation = vector3(0.0, 0.0, 0.0),
        })
        p:cb_tick(function(pct)
            if DoesEntityExist(entity) then
                local current = GetVehicleBodyHealth(entity)
                if current < 1000 then
                    SetVehicleBodyHealth(entity, current + (1000 - current) * (pct / 100))
                end
            end
        end)
        p:onComplete(function()
            if DoesEntityExist(entity) then
                SetVehicleBodyHealth(entity, 1000.0)
                SetVehicleEngineHealth(entity, 1000.0)
                SetVehicleFixed(entity)
            end
            jobsDone = jobsDone + 1
            LM:notify(function(n)
                n:message("Repair complete! Vehicle restored to mint condition.")
                n:type("success")
                n:duration(5000)
            end)
        end)
        p:onCancel(function()
            LM:notify(function(n)
                n:message("Repair interrupted.")
                n:type("warning")
                n:duration(3000)
            end)
        end)
    end)
end

-- ─── Diagnostic & Quote ──────────────────────────────────────────────────────

local function openDiagnostic(entity)
    Citizen.CreateThread(function()
        local body   = DoesEntityExist(entity) and GetVehicleBodyHealth(entity)   or 0
        local engine = DoesEntityExist(entity) and GetVehicleEngineHealth(entity) or 0

        local values = LM:input_async(function(form)
            form:title("Diagnostic Form")
            form:field("Customer Name", {
                type        = "text",
                placeholder = "e.g., John Doe",
                maxlen      = 40,
            })
            form:field("Damage Description", {
                type        = "text",
                placeholder = "e.g., Engine damage, scratched bodywork…",
                maxlen      = 80,
            })
            form:field("Estimated Cost ($)", {
                type    = "number",
                min     = 0,
                max     = 50000,
                default = math.floor((2000 - body + (1000 - engine)) * 0.5),
            })
            form:confirm("Save Quote")
            form:cancel("Cancel")
        end)

        if not values then return end

        LM:notify(function(n)
            n:message(string.format("Quote saved for %s — $%d", values[1], tonumber(values[3]) or 0))
            n:type("success")
            n:duration(6000)
            n:group("quote")
        end)
    end)
end

-- ─── Cleaning ────────────────────────────────────────────────────────────────

local function cleanVehicle(entity)
    LM:progress(function(p)
        p:label("Washing in progress…")
        p:duration(4000)
        p:icon("droplets")
        p:anim({
            dict  = "amb@world_human_car_park_attendant@male@idle_a",
            clip  = "idle_a",
            flag  = 1,
        })
        p:onComplete(function()
            if DoesEntityExist(entity) then
                WashDecalsFromVehicle(entity, 1.0)
                SetVehicleDirtLevel(entity, 0.0)
            end
            LM:notify(function(n)
                n:message("Vehicle cleaned!")
                n:type("success")
                n:duration(3000)
            end)
        end)
    end)
end

-- ─── Quick Inspection (context menu) ────────────────────────────────────────

local function openInspection(entity)
    if not DoesEntityExist(entity) then return end
    local body   = math.floor(GetVehicleBodyHealth(entity))
    local engine = math.floor(GetVehicleEngineHealth(entity))
    LM:context(function(menu)
        menu:title("Inspection")
        menu:animation("scale")
        menu:stat("Bodywork", { value = body,   max = 1000, color = "auto" })
        menu:stat("Engine",   { value = engine, max = 1000, color = "auto" })
        menu:back("Back")
    end)
end

-- ─── Main Radial Menu ────────────────────────────────────────────────────────

local function openMechanicRadial(entity)
    currentVeh = entity

    LM:radial(function(r)
        r:center_label("Mechanic")

        r:button("Repair", {
            icon     = "wrench",
            disabled = function() return not isOnDuty end,
            cb       = function() repairVehicle(currentVeh) end,
        })

        r:button("Diagnostic", {
            icon = "clipboard-list",
            cb   = function() openDiagnostic(currentVeh) end,
        })

        r:button("Clean", {
            icon     = "droplets",
            disabled = function() return not isOnDuty end,
            cb       = function() cleanVehicle(currentVeh) end,
        })

        r:button("Advanced", {
            icon    = "settings-2",
            submenu = function(sub)
                sub:center_label("Advanced Options")

                sub:button("Inflate Tires", {
                    icon = "circle-dot",
                    cb   = function()
                        LM:progress(function(p)
                            p:label("Inflating tires…")
                            p:duration(3000)
                            p:icon("circle-dot")
                            p:onComplete(function()
                                if DoesEntityExist(currentVeh) then
                                    for i = 0, 3 do
                                        SetVehicleTyreBurst(currentVeh, i, false, 1000.0)
                                    end
                                end
                                LM:notify(function(n)
                                    n:message("Tires inflated!")
                                    n:type("success")
                                    n:duration(3000)
                                end)
                            end)
                        end)
                    end,
                })

                sub:button("Battery Charge", {
                    icon = "battery-charging",
                    cb   = function()
                        LM:progress(function(p)
                            p:label("Charging battery…")
                            p:duration(5000)
                            p:icon("battery-charging")
                            p:onComplete(function()
                                if DoesEntityExist(currentVeh) then
                                    SetVehicleEngineHealth(currentVeh, 1000.0)
                                end
                                LM:notify(function(n)
                                    n:message("Battery charged!")
                                    n:type("success")
                                end)
                            end)
                        end)
                    end,
                })

                sub:button("Inspect", {
                    icon = "search",
                    cb   = function() openInspection(currentVeh) end,
                })
            end,
        })
    end)
end

-- ─── Target on Vehicles ──────────────────────────────────────────────────────

Citizen.CreateThread(function()
    LM:target_add_model(nil, function(t)
        t:label("Vehicle")
        t:icon("car")
        t:distance(4.0)
        -- t:banner("nui://job_mechanic/img/vehicle_banner.gif")

        -- ── Root Actions ───────────────────────────────────────────────────────

        -- Repair: gradient + 2s hold + 60s cooldown, only visible when on duty
        t:button("Repair", {
            icon         = "wrench",
            gradient     = true,
            confirm_hold = 2000,
            cooldown     = 60000,
            condition    = function() return isOnDuty end,
            cb           = function(entity) repairVehicle(entity) end,
        })

        -- Diagnostic always available
        t:button("Inspect / Quote", {
            icon = "clipboard-list",
            cb   = function(entity) openDiagnostic(entity) end,
        })

        t:separator()

        -- ── "Services" Group (accordion) ───────────────────────────────────────

        t:group("Services", { icon = "tool" }, function(g)
            g:button("Clean", {
                icon      = "droplets",
                condition = function() return isOnDuty end,
                cb        = function(entity) cleanVehicle(entity) end,
            })
            g:button("Inflate Tires", {
                icon = "circle-dot",
                cb   = function(entity)
                    LM:progress(function(p)
                        p:label("Inflating tires…")
                        p:duration(3000)
                        p:icon("circle-dot")
                        p:onComplete(function()
                            if DoesEntityExist(entity) then
                                for i = 0, 3 do SetVehicleTyreBurst(entity, i, false, 1000.0) end
                            end
                            LM:notify(function(n)
                                n:message("Tires inflated!")
                                n:type("success")
                                n:duration(3000)
                            end)
                        end)
                    end)
                end,
            })
            g:button("Battery Charge", {
                icon = "battery-charging",
                cb   = function(entity)
                    LM:progress(function(p)
                        p:label("Charging battery…")
                        p:duration(5000)
                        p:icon("battery-charging")
                        p:onComplete(function()
                            if DoesEntityExist(entity) then
                                SetVehicleEngineHealth(entity, 1000.0)
                            end
                            LM:notify(function(n)
                                n:message("Battery charged!")
                                n:type("success")
                            end)
                        end)
                    end)
                end,
            })
        end)

        -- ── "Options" Group (accordion) ────────────────────────────────────────

        t:group("Options", { icon = "settings-2" }, function(g)
            -- Toggle: vehicle locking
            g:toggle("Lock", {
                icon    = "lock",
                default = false,
                cb      = function(entity, val)
                    if DoesEntityExist(entity) then
                        SetVehicleDoorsLocked(entity, val and 2 or 1)
                    end
                    LM:notify(function(n)
                        n:message("Vehicle " .. (val and "locked" or "unlocked"))
                        n:type(val and "warning" or "success")
                        n:duration(2000)
                        n:group("veh_lock")
                    end)
                end,
            })
            -- Slider: fuel level
            g:slider("Fuel", {
                icon    = "fuel",
                min     = 0,
                max     = 100,
                step    = 5,
                default = 20,
                suffix  = "%",
                cb      = function(entity, val)
                    -- SetVehicleFuelLevel(entity, val * 0.65)
                end,
            })
            -- Checkbox: mark invoice as generated
            g:checkbox("Invoice Generated", {
                icon    = "receipt",
                default = false,
                cb      = function(entity, val)
                    if val then
                        LM:notify(function(n)
                            n:message("Invoice generated and sent to customer.")
                            n:type("info")
                            n:duration(3000)
                        end)
                    end
                end,
            })
        end)

        t:separator()

        -- ── Submenu (opens full mechanic radial) ───────────────────────────────

        t:submenu("Mechanic Menu", {
            icon = "hard-hat",
            cb   = function(entity) openMechanicRadial(entity) end,
        })
    end)
end)