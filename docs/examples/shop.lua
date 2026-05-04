-- examples/shop.lua
-- A full shop menu with reactive stock/funds display, tabs for categories,
-- an accordion for bulk buy, and an async confirmation before purchase.
--
-- Demonstrates:
--   • context_build — persistent handle (open / close / update)
--   • stat() with reactive value
--   • button() with reactive disabled + stable opts.id
--   • tab() — multi-category layout
--   • accordion() — collapsible bulk-buy section
--   • slider() for quantity selection
--   • alert_async — coroutine-blocking confirmation
--   • notify for feedback toasts

local LastMenu = exports['LastMenu']

-- ── Simulated state (replace with your framework data source) ─────────────────
local playerFunds = 1500
local playerLevel = 5

local inventory = {}   -- itemId → quantity owned

local items = {
    { id = 'burger', name = 'Burger',     price = 200,  icon = 'utensils',    cat = 'Food',    stock = 5  },
    { id = 'soda',   name = 'Soda',       price = 50,   icon = 'coffee',      cat = 'Food',    stock = 12 },
    { id = 'medkit', name = 'Med Kit',    price = 350,  icon = 'plus-circle', cat = 'Medical', stock = 3  },
    { id = 'armor',  name = 'Body Armor', price = 500,  icon = 'shield',      cat = 'Medical', stock = 2  },
    { id = 'pistol', name = 'Pistol',     price = 1200, icon = 'crosshair',   cat = 'Weapons', stock = 4, level = 3 },
    { id = 'rifle',  name = 'Rifle',      price = 3500, icon = 'crosshair',   cat = 'Weapons', stock = 1, level = 5 },
}

local categories = {}
local catOrder   = {}
for _, item in ipairs(items) do
    if not categories[item.cat] then
        categories[item.cat] = {}
        catOrder[#catOrder + 1] = item.cat
    end
    categories[item.cat][#categories[item.cat] + 1] = item
end

-- ── Async purchase flow ───────────────────────────────────────────────────────
local function purchaseItem(item, qty)
    Citizen.CreateThread(function()
        local total = item.price * qty

        local confirmed = LastMenu:alert_async(function(a)
            a:title('Confirm Purchase')
            a:message(string.format(
                'Buy %d× %s for %d€?\n(Balance: %d€  →  %d€)',
                qty, item.name, total, playerFunds, playerFunds - total
            ))
            a:confirm_label('Buy')
            a:cancel_label('Cancel')
        end)

        if not confirmed then return end

        playerFunds        = playerFunds - total
        item.stock         = item.stock - qty
        inventory[item.id] = (inventory[item.id] or 0) + qty

        LastMenu:notify(function(n)
            n:message(string.format('Bought %d× %s for %d€.', qty, item.name, total))
            n:type('success')
            n:icon('shopping-cart')
            n:duration(3500)
        end)

        TriggerServerEvent('shop:purchase', item.id, qty, total)
    end)
end

-- ── Tab icon helper ───────────────────────────────────────────────────────────
local catIcons = { Food = 'utensils', Medical = 'plus-circle', Weapons = 'crosshair' }

-- ── Build the shop handle ─────────────────────────────────────────────────────
local shopHandle = LastMenu:context_build(function(menu)
    menu:title('General Store')
    menu:banner('nui://lastmenu/assets/shop_banner.png')
    menu:description('Quality goods at fair prices.')
    menu:nav('both')

    -- Reactive funds stat — updates live without closing the menu
    menu:stat('Funds', {
        icon    = 'wallet',
        value   = function() return playerFunds end,
        max     = 5000,
        suffix  = '€',
        color   = 'auto',
        refresh = 500,
    })

    menu:stat('Level', {
        icon    = 'star',
        value   = function() return playerLevel end,
        max     = 10,
        refresh = 5000,
    })

    menu:separator()

    -- One tab per category
    for _, cat in ipairs(catOrder) do
        local catItems = categories[cat]

        menu:tab(cat, function(t)
            menu:header(cat)

            for _, item in ipairs(catItems) do
                local itm = item  -- capture for closure

                t:button(itm.name, {
                    id       = 'buy_' .. itm.id,  -- stable ID (not positional)
                    icon     = itm.icon,
                    badge    = itm.price .. '€',
                    hint     = function() return 'Stock: ' .. itm.stock end,
                    disabled = function()
                        if playerFunds < itm.price               then return true end
                        if itm.stock <= 0                        then return true end
                        if itm.level and playerLevel < itm.level then return true end
                        return false
                    end,
                    refresh   = 500,
                    keep_open = true,
                    preview   = {
                        title = itm.name,
                        desc  = string.format('Price: %d€ | In stock: %d', itm.price, itm.stock),
                        stats = {
                            { label = 'Owned', value = inventory[itm.id] or 0, max = 10 },
                            { label = 'Stock', value = itm.stock,              max = 20 },
                        },
                    },
                    cb = function()
                        purchaseItem(itm, 1)
                    end,
                })
            end

            -- Bulk buy — slider selects quantity, cb triggers the async purchase flow
            t:accordion('Bulk Buy', function(acc)
                for _, item in ipairs(catItems) do
                    local itm = item
                    acc:slider(itm.name, {
                        id      = 'bulk_' .. itm.id,
                        icon    = itm.icon,
                        min     = 1,
                        max     = math.min(itm.stock, 10),
                        step    = 1,
                        default = 1,
                        suffix  = ' × ' .. itm.price .. '€',
                        cb      = function(qty)
                            purchaseItem(itm, qty)
                        end,
                    })
                end
            end, { icon = 'package' })

        end, { icon = catIcons[cat] or 'box' })
    end

    menu:separator()
    menu:back('Leave Store')
end)

-- ── Open on command / key ─────────────────────────────────────────────────────
RegisterCommand('shop', function()
    shopHandle.open()
end, false)

RegisterKeyMapping('shop', 'Open General Store', 'keyboard', 'F5')
