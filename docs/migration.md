# LastMenu — Migration Guide

Reference for migrating from **ox_lib**, **RageUI / RageNativeUI**, **qb-menu**, and **esx_menu_default**.

---

## Table of contents

1. [Basic installation](#1-basic-installation)
2. [Migrating from ox_lib](#2-migrating-from-ox_lib)
3. [Migrating from RageUI / RageNativeUI](#3-migrating-from-rageui--ragenativeui)
4. [Migrating from qb-menu / esx_menu_default](#4-migrating-from-qb-menu--esx_menu_default)
5. [Conceptual differences](#5-conceptual-differences)
6. [Async API (coroutine-style)](#6-async-api-coroutine-style)
7. [Full equivalence table](#7-full-equivalence-table)

---

## 1. Basic installation

```lua
-- In the fxmanifest.lua of each client resource that uses LastMenu:
client_scripts { '@LastMenu/client/exports.lua' }

-- In server.cfg, BEFORE resources that depend on it:
ensure LastMenu
```

Shorthand reference in code:
```lua
local UI = exports['LastMenu']
```

---

## 2. Migrating from ox_lib

### Context menu

| ox_lib | LastMenu |
|---|---|
| `lib.registerContext({ id, title, options })` | builder `UI:context(fn)` |
| `lib.showContext('menu-id')` | open is part of the builder call |
| `{ title, description, icon, onSelect }` | `menu:button(label, { icon, hint, cb })` |
| `metadata = { { label, value } }` | `preview = { stats = { { label, value, max } } }` |
| `disabled = true` | `disabled = true` (or a reactive function) |
| `arrow = true` | `arrow = true` |

**ox_lib:**
```lua
lib.registerContext({
    id      = 'garage',
    title   = 'Garage',
    options = {
        {
            title       = 'Repair engine',
            description = 'Requires 500€',
            icon        = 'wrench',
            onSelect    = function() repairEngine() end,
        },
        {
            title    = 'Repaint',
            icon     = 'paintbrush',
            disabled = GetVehiclePedIsIn(PlayerPedId(), false) == 0,
            onSelect = function() end,
        },
    },
})
lib.showContext('garage')
```

**LastMenu equivalent:**
```lua
UI:context(function(menu)
    menu:title('Garage')

    menu:button('Repair engine', {
        icon = 'wrench',
        hint = '500€',
        cb   = function() repairEngine() end,
    })

    menu:button('Repaint', {
        icon     = 'paintbrush',
        disabled = GetVehiclePedIsIn(PlayerPedId(), false) == 0,
        cb       = function() end,
    })
end)
```

---

### Input dialog

| ox_lib | LastMenu |
|---|---|
| `lib.inputDialog(title, rows)` blocking | `UI:input_async(fn)` blocking (coroutine) |
| `{ type = 'input', label, default }` | `b:field(label, { type = 'text', default })` |
| `{ type = 'number', min, max }` | `b:field(label, { type = 'number', min, max })` |
| returns `nil` if cancelled | returns `nil` if cancelled |
| returns `{ [1] = value, ... }` | returns `{ [1] = value, ... }` |

**ox_lib:**
```lua
Citizen.CreateThread(function()
    local input = lib.inputDialog('Purchase', {
        { type = 'number', label = 'Quantity', min = 1, max = 10 },
        { type = 'input',  label = 'Note' },
    })
    if not input then return end
    print(input[1], input[2])
end)
```

**LastMenu equivalent:**
```lua
Citizen.CreateThread(function()
    local values = UI:input_async(function(b)
        b:title('Purchase')
        b:field('Quantity', { type = 'number', min = 1, max = 10 })
        b:field('Note',     { type = 'text' })
        b:confirm_label('OK')
        b:cancel_label('Cancel')
    end)
    if not values then return end
    print(values[1], values[2])
end)
```

---

### Alert dialog

| ox_lib | LastMenu |
|---|---|
| `lib.alertDialog({ header, content })` | `UI:alert_async(fn)` |
| returns `'confirm'` or `'cancel'` | returns `true` or `false` |

**ox_lib:**
```lua
Citizen.CreateThread(function()
    local result = lib.alertDialog({
        header  = 'Delete?',
        content = 'This action is irreversible.',
    })
    if result == 'confirm' then
        -- ...
    end
end)
```

**LastMenu equivalent:**
```lua
Citizen.CreateThread(function()
    local confirmed = UI:alert_async(function(b)
        b:title('Delete?')
        b:message('This action is irreversible.')
        b:confirm_label('Yes, delete')
        b:cancel_label('Cancel')
    end)
    if confirmed then
        -- ...
    end
end)
```

---

### Notifications

| ox_lib | LastMenu |
|---|---|
| `lib.notify({ title, description, type, duration })` | `UI:notify(fn)` |
| `type = 'success'` | `n:type('success')` |
| `type = 'error'` | `n:type('error')` |
| `type = 'warning'` | `n:type('warn')` |
| `type = 'inform'` | `n:type('info')` |

**ox_lib:**
```lua
lib.notify({ title = 'Done', description = 'Engine repaired.', type = 'success', duration = 3000 })
```

**LastMenu equivalent:**
```lua
UI:notify(function(n)
    n:message('Engine repaired.')
    n:type('success')
    n:duration(3000)
end)
```

---

### Target (ox_target → LastMenu target)

| ox_target | LastMenu |
|---|---|
| `exports.ox_target:addLocalEntity(entity, opts)` | `UI:target_add_entity(entity, opts)` |
| `exports.ox_target:addModel(models, opts)` | `UI:target_add_model(model, opts)` |
| `exports.ox_target:addSphereZone(opts)` | `UI:target_add_sphere(coords, radius, opts)` |
| `exports.ox_target:addBoxZone(opts)` | `UI:target_add_box(coords, opts)` |
| `exports.ox_target:addPolyZone(opts)` | `UI:target_add_poly(points, opts)` |
| `exports.ox_target:removeLocalEntity(entity)` | `UI:target_remove(id)` |
| `{ label, icon, onSelect = fn }` | `{ label, icon, cb = fn }` |
| `canInteract = function(entity, ...) end` | `condition = function(entity) return bool end` |

**ox_target:**
```lua
exports.ox_target:addSphereZone({
    coords  = vector3(100.0, 200.0, 30.0),
    radius  = 2.0,
    options = {
        {
            label       = 'Interact',
            icon        = 'fa-hand',
            canInteract = function(entity, distance, coords, name) return true end,
            onSelect    = function(data) print('Interacted') end,
        },
    },
})
```

**LastMenu equivalent:**
```lua
UI:target_add_sphere(vector3(100.0, 200.0, 30.0), 2.0, function(t)
    t:label('Zone')
    t:button('Interact', {
        icon      = 'hand',
        condition = function() return true end,
        cb        = function() print('Interacted') end,
    })
end)
```

---

### Progress bar

| ox_lib | LastMenu |
|---|---|
| `lib.progressBar({ duration, label, … })` | `UI:progress(fn)` |
| `anim = { dict, clip, flag }` | `p:anim({ dict, clip, flag })` |
| `prop = { model, bone, … }` | `p:prop({ model, bone, offset, rot })` |
| blocking (coroutine) | non-blocking (callbacks) |

**ox_lib:**
```lua
if lib.progressBar({ duration = 5000, label = 'Repairing…',
    anim = { dict = 'mini@repair', clip = 'fixing_a_ped' } }) then
    print('Done')
end
```

**LastMenu equivalent:**
```lua
UI:progress(function(p)
    p:label('Repairing…')
    p:duration(5000)
    p:icon('wrench')
    p:anim({ dict = 'mini@repair', clip = 'fixing_a_ped' })
    p:confirm(function() print('Done') end)
end)
```

---

## 3. Migrating from RageUI / RageNativeUI

### Main menu

| RageUI | LastMenu |
|---|---|
| `RageUI.Menu('title', 'subtitle', …)` | `UI:context(fn)` |
| `RageUI.Item('label', 'description')` | `menu:button(label, { hint = desc })` |
| `RageUI.CheckboxItem('label', state)` | `menu:checkbox(label, { default = state })` |
| `RageUI.ListItem('label', list, index)` | `menu:list(label, { items = list, default = index })` |
| `RageUI.SliderItem('label', min, max, val)` | `menu:slider(label, { min, max, default = val })` |
| menu pool + `RageUI.IsAnyMenuOpen()` | handled automatically by the stack |
| `RageUI.Render(fn)` — per-frame loop | no loop required |

**RageUI:**
```lua
local menuVisible = false
local menu = RageUI.Menu('Garage', 'Repair your vehicle')

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if menuVisible then
            RageUI.Render(function()
                RageUI.UseMenu(menu, function()
                    local repairItem = RageUI.Item('Repair', '500€')
                    if repairItem.Activated then
                        repairEngine()
                    end
                end)
            end)
        end
    end
end)

RegisterCommand('garage', function()
    menuVisible = not menuVisible
end, false)
```

**LastMenu equivalent:**
```lua
RegisterCommand('garage', function()
    UI:context(function(menu)
        menu:title('Garage')
        menu:description('Repair your vehicle.')
        menu:button('Repair', { hint = '500€', cb = function() repairEngine() end })
    end)
end, false)
```

> LastMenu has **no render loop** — no `Citizen.Wait(0)` needed.

---

### Sub-menus

**RageUI:**
```lua
local subMenu = RageUI.Menu('Sub-menu', '')
local item, activated, hovered = RageUI.SubMenu(subMenu, 'Go to sub-menu')
if activated then RageUI.OpenMenu(subMenu) end
```

**LastMenu equivalent:**
```lua
menu:submenu('Go to sub-menu', function(sub)
    sub:title('Sub-menu')
    sub:button('Action', { cb = function() end })
    sub:back()
end, { icon = 'chevron-right' })
```

---

## 4. Migrating from qb-menu / esx_menu_default

### qb-menu

| qb-menu | LastMenu |
|---|---|
| `exports['qb-menu']:openMenu(items)` | `UI:context(fn)` |
| `{ header, txt, isMenuHeader }` | `menu:header(label)` |
| `{ header, txt, params = { event, args } }` | `menu:button(label, { cb = function() TriggerEvent(…) end })` |
| `{ header, txt, disabled }` | `menu:button(label, { disabled = true })` |
| `exports['qb-menu']:closeMenu()` | `Stack.pop()` or Escape |

**qb-menu:**
```lua
exports['qb-menu']:openMenu({
    { header = 'Garage', isMenuHeader = true },
    {
        header = 'Repair engine',
        txt    = 'Cost: 500€',
        params = { event = 'garage:repairEngine', args = {} },
    },
    {
        header   = 'Disabled option',
        disabled = true,
    },
})
```

**LastMenu equivalent:**
```lua
UI:context(function(menu)
    menu:header('Garage')
    menu:button('Repair engine', {
        hint = '500€',
        cb   = function() TriggerEvent('garage:repairEngine') end,
    })
    menu:button('Disabled option', { disabled = true })
end)
```

---

### esx_menu_default

| esx_menu_default | LastMenu |
|---|---|
| `ESX.UI.Menu.Open('default', …, items, cb_select, cb_cancel)` | `UI:context(fn)` |
| `{ label, value }` | `menu:button(label, { cb = function() end })` |
| `cb_cancel = function() end` | handled by Escape / `menu:cancelable(false)` |

---

## 5. Conceptual differences

### No render loop

ox_lib, RageUI, and NativeUI require an active render loop to update state.
LastMenu uses a reactive polling engine — declare what is dynamic, the library handles the rest.

```lua
-- LastMenu: dynamic label with no loop
menu:button(function()
    return 'Money: ' .. GetPlayerMoney()
end, { refresh = 500 })
```

### No string menu IDs

ox_lib uses string IDs to reference and reopen menus (`lib.showContext('id')`).
LastMenu uses handles:

```lua
-- ox_lib
lib.registerContext({ id = 'shop', … })
lib.showContext('shop')

-- LastMenu
local shopMenu = UI:context_build(function(menu) … end)
shopMenu.open()
shopMenu.close()
```

### Stack navigation is automatic

In RageUI / ox_lib you manually manage which menu is open.
In LastMenu, every `UI:context(…)` call inside a callback pushes onto the stack — Escape pops automatically.

### `lastmenu_back` export

The navigation export is named `lastmenu_back` (to avoid collisions with other resources):
```lua
exports.LastMenu:lastmenu_back()   -- equivalent to pressing Escape
```
The builder method `menu:back()` is unchanged.

---

## 6. Async API (coroutine-style)

`input_async` and `alert_async` block the current coroutine, just like `lib.inputDialog` and `lib.alertDialog` in ox_lib.

> **Requirement:** must be called from a `Citizen.CreateThread`. If called from a `RegisterCommand` or `AddEventHandler`, wrap in `Citizen.CreateThread(function() … end)`.

### input_async

```lua
Citizen.CreateThread(function()
    local values = exports.LastMenu:input_async(function(b)
        b:title('Bank Transfer')
        b:field('Recipient', { type = 'text',   placeholder = 'Player name' })
        b:field('Amount',    { type = 'number', min = 1, max = 100000 })
        b:field('Note',      { type = 'text',   maxlen = 50 })
        b:confirm_label('Send')
        b:cancel_label('Cancel')
    end)

    if not values then
        print('Transfer cancelled.')
        return
    end

    local recipient = values[1]
    local amount    = values[2]   -- already cast to number
    local note      = values[3]

    TriggerServerEvent('bank:transfer', recipient, amount, note)
end)
```

### alert_async

```lua
Citizen.CreateThread(function()
    local confirmed = exports.LastMenu:alert_async(function(b)
        b:title('Reset account?')
        b:message('All progress will be lost. This action is irreversible.')
        b:confirm_label('Reset')
        b:cancel_label('Cancel')
    end)

    if confirmed then
        TriggerServerEvent('account:reset')
    end
end)
```

### Multi-step chaining

```lua
Citizen.CreateThread(function()
    -- Step 1: collect data
    local values = exports.LastMenu:input_async(function(b)
        b:title('Create Character')
        b:field('First Name', { type = 'text', maxlen = 20 })
        b:field('Last Name',  { type = 'text', maxlen = 20 })
        b:confirm_label('Next')
    end)
    if not values then return end

    -- Step 2: confirm
    local ok = exports.LastMenu:alert_async(function(b)
        b:title('Confirm creation')
        b:message(string.format('Create character %s %s?', values[1], values[2]))
        b:confirm_label('Create')
        b:cancel_label('Go back')
    end)
    if not ok then return end

    TriggerServerEvent('character:create', values[1], values[2])
end)
```

---

## 7. Full equivalence table

| Feature | ox_lib | RageUI | qb-menu | LastMenu |
|---|---|---|---|---|
| Context menu | `lib.registerContext` + `showContext` | `RageUI.Menu` + render loop | `openMenu(items)` | `UI:context(fn)` |
| Reusable menu | `lib.hideContext` + re-show | menu pool | — | `UI:context_build(fn)` |
| Input dialog (callback) | — | — | — | `UI:input(fn)` |
| Input dialog (blocking) | `lib.inputDialog` | — | — | `UI:input_async(fn)` |
| Alert dialog (callback) | — | — | — | `UI:alert(fn)` |
| Alert dialog (blocking) | `lib.alertDialog` | — | — | `UI:alert_async(fn)` |
| Notification toast | `lib.notify` | — | — | `UI:notify(fn)` |
| Radial menu | `lib.radialMenu` | — | — | `UI:radial(fn)` |
| Progress bar | `lib.progressBar` | — | — | `UI:progress(fn)` |
| Target entity | `ox_target:addLocalEntity` | — | — | `UI:target_add_entity` |
| Target model | `ox_target:addModel` | — | — | `UI:target_add_model` |
| Target sphere | `ox_target:addSphereZone` | — | — | `UI:target_add_sphere` |
| Target box | `ox_target:addBoxZone` | — | — | `UI:target_add_box` |
| Target polygon | `ox_target:addPolyZone` | — | — | `UI:target_add_poly` |
| Real-time reactivity | ❌ | ❌ | ❌ | ✅ (polling engine) |
| Zero framework dependency | ❌ | ✅ | ✅ | ✅ |
| Stack navigation | ⚠️ partial | ✅ manual | ❌ | ✅ automatic |
| Gamepad support | ⚠️ | ✅ | ❌ | ✅ |
| CSS variable theming | ⚠️ | ❌ | ❌ | ✅ |
