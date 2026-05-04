-- LastMenu Example: Complete Shop
--
-- Demonstrates:
--   accordion     — collapsible categories
--   stepper       — quantity selection
--   list          — stock variants/colors
--   color_picker  — custom color for clothing
--   input_inline  — promo code inside the menu
--   input_async   — delivery form
--   alert_async   — purchase confirmation
--   notify()      — order result
--   target_add_box() — shop interaction zone

local LM = exports.LastMenu

-- ─── Fictional Catalog ────────────────────────────────────────────────────────

local catalog = {
    {
        category = "Food & Drink",
        icon     = "utensils",
        items = {
            { label = "Burger",         price = 5,   icon = "beef",       variants = { "Normal", "Double", "Veggie" } },
            { label = "Mineral Water",  price = 2,   icon = "droplets",   variants = { "50 cl", "1 L" } },
            { label = "Coffee",         price = 3,   icon = "coffee",     variants = { "Espresso", "Americano", "Latte" } },
            { label = "Pizza",          price = 12,  icon = "pizza",      variants = { "Margherita", "Pepperoni", "4 Cheese" } },
        },
    },
    {
        category = "Equipment",
        icon     = "backpack",
        items = {
            { label = "Body Armor",     price = 500,  icon = "shield",      variants = { "Standard", "Heavy", "Military" } },
            { label = "Medical Kit",    price = 150,  icon = "heart-pulse", variants = { "Small", "Standard", "Large" } },
            { label = "Flashlight",     price = 40,   icon = "flashlight",  variants = { "Compact", "Long Range" } },
        },
    },
    {
        category = "Clothing",
        icon     = "shirt",
        items = {
            { label = "T-shirt",  price = 30, icon = "shirt",      useColorPicker = true },
            { label = "Cap",      price = 20, icon = "hat",        useColorPicker = true },
            { label = "Sneakers", price = 80, icon = "footprints", variants = { "White", "Black", "Red", "Blue" } },
        },
    },
}

-- ─── Shopping Cart ───────────────────────────────────────────────────────────

local cart = {}     -- { label, price, qty, variant, color }

local function cartTotal()
    local total = 0
    for _, item in ipairs(cart) do total = total + item.price * item.qty end
    return total
end

-- ─── Opening the Shop ────────────────────────────────────────────────────────

local function openShop()
    LM:context(function(menu)
        menu:title("LS SuperShop")
        menu:description("Welcome to our store!")
        menu:animation("fade")

        -- Promo code at the top of the menu (always visible)
        menu:input_inline("Promo Code", {
            type         = "text",
            placeholder  = "ex: LASTMENU10",
            icon         = "tag",
            maxlen       = 16,
            cb = function(val)
                if val == "LASTMENU10" then
                    LM:notify(function(n)
                        n:message("Promo code applied: -10%!")
                        n:type("success")
                    end)
                elseif val ~= "" then
                    LM:notify(function(n)
                        n:message("Invalid promo code.")
                        n:type("error")
                        n:duration(2500)
                    end)
                end
            end,
        })

        menu:separator()

        -- Accordions per category
        for _, cat in ipairs(catalog) do
            local c = cat
            menu:accordion(c.category, function(acc)
                for _, item in ipairs(c.items) do
                    local it = item

                    if it.useColorPicker then
                        -- ─ Clothing with color picker ─────────────────────
                        local chosenColor = "#e94560"
                        local chosenQty   = 1

                        acc:color_picker(it.label .. " — Color", {
                            icon    = it.icon,
                            default = chosenColor,
                            cb = function(hex) chosenColor = hex end,
                        })
                        acc:stepper("Quantity", {
                            min     = 1,
                            max     = 5,
                            step    = 1,
                            default = 1,
                            cb = function(val) chosenQty = val end,
                        })
                        acc:button("Add to Cart — " .. it.label, {
                            icon      = "shopping-cart",
                            hint      = string.format("$%d", it.price),
                            keep_open = true,
                            cb = function()
                                table.insert(cart, {
                                    label   = it.label,
                                    price   = it.price,
                                    qty     = chosenQty,
                                    variant = nil,
                                    color   = chosenColor,
                                })
                                LM:notify(function(n)
                                    n:message(it.label .. " added to cart.")
                                    n:type("info")
                                    n:duration(2000)
                                end)
                            end,
                        })

                    elseif it.variants then
                        -- ─ Item with variants ──────────────────────────
                        local chosenIdx = 1
                        local chosenQty = 1

                        acc:list(it.label .. " — Variant", {
                            icon    = it.icon,
                            items   = it.variants,
                            default = 1,
                            cb = function(idx) chosenIdx = idx end,
                        })
                        acc:stepper("Quantity", {
                            min     = 1,
                            max     = 10,
                            step    = 1,
                            default = 1,
                            cb = function(val) chosenQty = val end,
                        })
                        acc:button("Add to Cart — " .. it.label, {
                            icon      = "shopping-cart",
                            hint      = string.format("$%d", it.price),
                            keep_open = true,
                            cb = function()
                                table.insert(cart, {
                                    label   = it.label,
                                    price   = it.price,
                                    qty     = chosenQty,
                                    variant = it.variants[chosenIdx],
                                    color   = nil,
                                })
                                LM:notify(function(n)
                                    n:message(it.label .. " (" .. it.variants[chosenIdx] .. ") added.")
                                    n:type("info")
                                    n:duration(2000)
                                end)
                            end,
                        })
                    end
                end
            end, { icon = c.icon })
        end

        menu:separator()

        -- Cart summary + Checkout
        menu:button("View Cart", {
            icon  = "shopping-bag",
            arrow = true,
            badge = function() return #cart > 0 and tostring(#cart) .. " item(s)" or "Empty" end,
            hint  = function() return cartTotal() > 0 and cartTotal() .. " $" or "" end,
            refresh = 500,
            cb = function()
                if #cart == 0 then
                    LM:notify(function(n)
                        n:message("Your cart is empty.")
                        n:type("warning")
                        n:duration(2500)
                    end)
                    return
                end

                -- Summary in sub-menu
                LM:context(function(sub)
                    sub:title("My Cart")
                    sub:animation("slideRight")

                    for _, cartItem in ipairs(cart) do
                        local ci = cartItem
                        local detail = ci.variant or (ci.color and "Color: " .. ci.color) or ""
                        sub:button(ci.label, {
                            icon  = "package",
                            badge = string.format("x%d  $%d", ci.qty, ci.price * ci.qty),
                            hint  = detail,
                        })
                    end

                    sub:separator()
                    sub:stat("Total", {
                        value   = function() return cartTotal() end,
                        max     = 10000,
                        suffix  = " $",
                        color   = "#60a5fa",
                        refresh = 300,
                    })

                    sub:button("Checkout", {
                        icon         = "check-circle",
                        confirm_hold = 1500,
                        cb = function()
                            -- Ask for a delivery address
                            Citizen.CreateThread(function()
                                local values = LM:input_async(function(form)
                                    form:title("Delivery")
                                    form:field("Name", {
                                        type        = "text",
                                        placeholder = "Your name",
                                        maxlen      = 30,
                                    })
                                    form:field("Phone", {
                                        type    = "number",
                                        min     = 10000000,
                                        max     = 99999999,
                                        placeholder = "8 digits",
                                    })
                                    form:confirm("Confirm Order")
                                    form:cancel("Cancel")
                                end)

                                if not values then return end

                                -- In production: TriggerServerEvent("shop:order", cart, values)
                                cart = {}
                                LM:notify(function(n)
                                    n:message(string.format(
                                        "Order confirmed for %s! Delivery in progress.",
                                        values[1]
                                    ))
                                    n:type("success")
                                    n:duration(6000)
                                end)
                            end)
                        end,
                    })

                    sub:button("Clear Cart", {
                        icon  = "trash-2",
                        confirm_hold = true,
                        cb = function()
                            cart = {}
                            LM:notify(function(n)
                                n:message("Cart cleared.")
                                n:type("info")
                                n:duration(2000)
                            end)
                        end,
                    })

                    sub:back("Back to Shop")
                end)
            end,
        })
    end)
end

-- ─── Target Zone in front of the shop ────────────────────────────────────────

Citizen.CreateThread(function()
    LM:target_add_box(vector3(-707.0, -905.0, 19.0), {
        width   = 4.0,
        length  = 2.0,
        heading = 0.0,
        label   = "SuperShop",
        icon    = "store",
        actions = {
            {
                label = "Open Shop",
                icon  = "shopping-bag",
                cb    = function() openShop() end,
            },
        },
    })
end)

local showCoords = false

RegisterCommand('coords', function()
    showCoords = not showCoords
    
    if showCoords then
        local coords = GetEntityCoords(PlayerPedId())
        local heading = GetEntityHeading(PlayerPedId())
        
        -- Clean formatting for easy copy-pasting into your scripts
        local coordsText = string.format("vector3(%.2f, %.2f, %.2f)", coords.x, coords.y, coords.z)
        
        -- Send coords to clipboard (requires NUI)
        SendNUIMessage({
            type = 'copy',
            text = coordsText
        })
        
        print("Coordinates copied: " .. coordsText)
    end
end, false)

-- HUD Display (DrawText)
Citizen.CreateThread(function()
    while true do
        local wait = 500
        if showCoords then
            wait = 0
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            local heading = GetEntityHeading(playerPed)

            DrawGenericText(string.format("~r~X~s~: %.2f  ~g~Y~s~: %.2f  ~b~Z~s~: %.2f  ~y~H~s~: %.2f", coords.x, coords.y, coords.z, heading))
        end
        Citizen.Wait(wait)
    end
end)

-- Utility function to draw text on screen
function DrawGenericText(text)
    SetTextFont(4)
    SetTextScale(0.45, 0.45)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.45, 0.85) -- Position bottom center
end