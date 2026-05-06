# LastMenu — Context Menu API

The context menu is the main vertical menu type. It supports a rich set of interactive items, real-time reactive updates, accordion sections, tabs, pagination, search, keyboard navigation, drag positioning, and a hover preview panel.

---

## Table of contents

1. [Opening a menu](#1-opening-a-menu)
2. [Meta options](#2-meta-options)
3. [Item types](#3-item-types)
   - [button](#button)
   - [slider](#slider)
   - [stepper](#stepper)
   - [checkbox](#checkbox)
   - [toggle](#toggle)
   - [list](#list)
   - [stat](#stat)
   - [input_inline](#input_inline)
   - [color_picker](#color_picker)
   - [date_picker](#date_picker)
   - [separator](#separator)
   - [header](#header)
   - [accordion](#accordion)
   - [tab](#tab)
4. [Real-time reactive items](#4-real-time-reactive-items)
5. [Reusable menus](#5-reusable-menus)
6. [Sub-menus](#6-sub-menus)
7. [Live rebuild (`context_update`)](#7-live-rebuild-context_update)
8. [User settings](#8-user-settings)
9. [Security notes](#9-security-notes)

---

## 1. Opening a menu

```lua
local UI = exports['LastMenu']

-- One-shot: opens immediately, closed on callback or Escape
UI:context(function(menu)
    menu:title("My Menu")
    menu:button("Click me", { cb = function() print("clicked") end })
end)
```

---

## 2. Meta options

Call these at the top of your builder function, before adding items.

| Method | Type | Default | Description |
|---|---|---|---|
| `menu:title(str)` | string | `''` | Title displayed in the header |
| `menu:banner(url)` | string | nil | Image URL shown above the title (https:// or nui://) |
| `menu:description(txt)` | string | nil | Subtitle shown below the title |
| `menu:animation(anim)` | string | `'slideLeft'` | Open animation: `'slideLeft'` `'slideRight'` `'fade'` `'scale'` |
| `menu:nav(mode)` | string | `'both'` | Force nav mode: `'mouse'` `'keyboard'` `'both'` |
| `menu:search()` | — | — | Force-show the search bar (auto-shown when items exceed `page_size`) |
| `menu:page_size(n)` | number | 20 | Items per page (pagination auto-activates above this). Ignored when `scroll()` is set. |
| `menu:scroll()` | — | — | **1.0.0** Disable pagination — render all items with native scroll. Mutually exclusive with `page_size()`. |
| `menu:cancelable(v)` | bool | `true` | Set to `false` to prevent Escape / B-button from closing this menu. |

```lua
UI:context(function(menu)
    menu:title("Garage")
    menu:banner("https://i.imgur.com/example.jpeg")
    menu:description("Repair and customize your vehicle.")
    menu:animation("slideRight")
    menu:nav("both")        -- respect user setting
    menu:page_size(10)
end)
```

### Scroll mode (1.0.0)

Call `menu:scroll()` to disable pagination and render all items in a scrollable container instead. Useful for long lists where pagination adds friction.

```lua
UI:context(function(menu)
    menu:title("Inventaire")
    menu:scroll()           -- all items visible at once, container scrolls

    for i = 1, 50 do
        menu:button("Item #" .. i, { cb = function() end })
    end
end)
```

> Keyboard navigation (`↑` / `↓`) scrolls the container automatically to keep the focused item visible.

---

## 3. Item types

### button

The most common item. Supports icons, badges, hotkeys, gradient backgrounds, hold-to-confirm, cooldown, and a hover preview panel.

```lua
menu:button(label, opts)
```

| Option | Type | Description |
|---|---|---|
| `icon` | string | Lucide icon name (e.g. `"wrench"`, `"car"`, `"zap"`) |
| `color` | string | Accent color for the icon and gradient (hex) |
| `gradient` | bool | Show a gradient background using `color` |
| `badge` | string | Small badge on the right (e.g. `"NEW"`, `"500€"`) |
| `hint` | string | Dim text on the right (e.g. `"E"`, `"500€"`) |
| `hotkey` | string | Keyboard shortcut label shown as `<kbd>` |
| `arrow` | bool | Show a `›` arrow (indicates a sub-menu) |
| `confirm_hold` | bool \| number | `true` = hold 1.5s to confirm; a number specifies a custom duration in ms (e.g. `3000`) |
| `cooldown` | number | Milliseconds before button can be clicked again |
| `persist_key` | string | Stable localStorage key for cooldown persistence. Use when `label` is dynamic (e.g. contains a player name or a variable) — without this, the default key is derived from `label+cooldown` and breaks if the label changes |
| `keep_open` | bool | Default: `true`. Set to `false` to close the menu on click. |
| `timeout` | number | **1.0.0** Auto-disable the item after N ms from menu open. Applies to all interactive types (button, slider, toggle, checkbox, list…). |
| `preview` | table | Hover preview panel — see below |
| `visible` | bool/fn | Hide the item (supports reactive function) |
| `disabled` | bool/fn | Disable the item (supports reactive function) |
| `refresh` | number | Polling interval in ms for reactive `visible`/`disabled` |
| `cb` | function | Called when clicked: `function() end` |

**Preview panel** — shown to the right of the menu on hover or keyboard focus:

```lua
preview = {
    image = "https://...",       -- optional image
    title = "Engine Repair",
    desc  = "Restores engine to 100%.",
    stats = {
        { label = "Before", value = 20,  max = 100 },
        { label = "After",  value = 100, max = 100, color = "#4ade80" },
    },
}
```

**Examples:**

```lua
-- Simple button
menu:button("Repair Engine", {
    icon = "wrench",
    cb   = function() print("repaired") end,
})

-- Badge + gradient
menu:button("Buy Item", {
    icon     = "shopping-cart",
    color    = "#4ade80",
    gradient = true,
    badge    = "500€",
    cb       = function() end,
})

-- Hold-to-confirm (1.5s)
menu:button("Delete Save", {
    icon         = "trash",
    confirm_hold = true,
    cb           = function() print("deleted") end,
})

-- Cooldown (5 seconds)
menu:button("Use Ability", {
    icon     = "zap",
    cooldown = 5000,
    cb       = function() print("ability used") end,
})

-- Auto-disable after 8 seconds (1.0.0)
menu:button("Offre limitée (8s)", {
    icon    = "clock",
    badge   = "EXPIRATION",
    timeout = 8000,
    cb      = function() print("accepted in time!") end,
})

-- With hotkey display
menu:button("Interact", {
    icon   = "mouse-pointer",
    hotkey = "E",
    cb     = function() end,
})

-- Sub-menu arrow (keep_open so parent stays open)
menu:button("More Options", {
    icon      = "settings",
    arrow     = true,
    keep_open = true,
    cb        = function()
        UI:context(function(sub)
            sub:title("More Options")
            sub:button("Option A", { cb = function() end })
        end)
    end,
})
```

> **Note:** The label can be a **function** for real-time updates — see [section 4](#4-real-time-reactive-items).

---

### slider

A horizontal slider with min/max/step.

```lua
menu:slider("Volume", {
    icon    = "volume-2",
    min     = 0,
    max     = 100,
    step    = 5,
    default = 80,
    suffix  = "%",
    cb      = function(value) print("Volume:", value) end,
})
```

Keyboard: `←` `→` to step. Mouse: drag the track.

---

### stepper

A `−` / value / `+` control for integer values.

```lua
menu:stepper("Repair Kits", {
    icon    = "package",
    min     = 0,
    max     = 10,
    step    = 1,
    default = 2,
    suffix  = " kits",
    cb      = function(value) print("Kits:", value) end,
})
```

| Option | Type | Description |
|---|---|---|
| `icon` | string | Lucide icon name |
| `min` | number | Minimum value (default: `0`) |
| `max` | number | Maximum value (default: `99`) |
| `step` | number | Increment per step (default: `1`) |
| `default` | number | Initial value |
| `suffix` | string | Unit label appended to the value (e.g. `" kits"`, `" m"`) |
| `id` | string | Stable callback ID |
| `cb` | function | Called on change: `function(value) end` |

Keyboard: `←` `→` to step.

---

### checkbox

A square checkbox that toggles a boolean.

```lua
menu:checkbox("Enable Turbo", {
    icon    = "zap",
    default = false,
    cb      = function(checked) print("Turbo:", checked) end,
})
```

Keyboard: `Enter` or `Space` to toggle.

---

### toggle

An animated pill switch (ON/OFF).

```lua
menu:toggle("Stealth Mode", {
    icon    = "eye-off",
    default = true,
    cb      = function(enabled) print("Stealth:", enabled) end,
})
```

Keyboard: `Enter` or `Space` to toggle.

---

### list

A `‹ value ›` carousel for a list of string options.

```lua
menu:list("Fuel Type", {
    icon    = "fuel",
    items   = { "Gasoline", "Diesel", "Electric", "Hybrid" },
    default = 1,   -- 1-based index
    cb      = function(index, value) print("Fuel:", value) end,
})
```

Keyboard: `←` `→` to cycle.

---

### stat

A read-only progress bar. Default color is the player's accent color (chosen in F12 settings). Pass `color` to override, or `color = "auto"` for the legacy green/orange/red percentage-based coloring.

```lua
-- New signature (1.0.0) — value and max in opts:
menu:stat("Engine", {
    value  = 78,
    max    = 100,
    icon   = "activity",
    suffix = "%",
    -- color = "#60a5fa",  -- explicit hex override
    -- color = "auto",     -- green/orange/red based on value/max ratio
})

-- Legacy signature (still supported):
menu:stat("Engine", 78, 100, { icon = "activity", suffix = "%" })
```

`value` and `max` both support **reactive functions** (see [section 4](#4-real-time-reactive-items)):

```lua
menu:stat("Health", {
    value  = function() return GetEntityHealth(PlayerPedId()) - 100 end,
    max    = 100,
    icon   = "heart",
    suffix = "hp",
    refresh = 500,
})
```

---

### input_inline

A text or number input field embedded in the menu row.

```lua
menu:input_inline("Vehicle Name", {
    icon        = "edit",
    type        = "text",      -- "text" | "number"
    placeholder = "My ride...",
    default     = "",
    maxlen      = 24,
    cb          = function(value) print("Name:", value) end,
})

-- Number input with clamped range
menu:input_inline("Speed Limit", {
    icon    = "gauge",
    type    = "number",
    default = 80,
    min     = 0,
    max     = 300,
    cb      = function(value) print("Speed:", value) end,
})
```

| Option | Type | Description |
|---|---|---|
| `type` | string | `"text"` (default) or `"number"` |
| `placeholder` | string | Placeholder text |
| `default` | string\|number | Initial value |
| `maxlen` | integer | Max character length (text) |
| `min` | number | Minimum value — HTML native constraint, applies to `type = "number"` |
| `max` | number | Maximum value — HTML native constraint, applies to `type = "number"` |
| `cb` | function | Called on confirm (`Enter` or blur): `function(value) end` |

Keyboard: `Enter` while the row is focused → focuses the input. `Enter` inside the input → confirms. `Escape` → blurs.

---

### color_picker

A color swatch with a preset grid and a custom color input.

```lua
menu:color_picker("Body Color", {
    icon    = "palette",
    default = "#e94560",
    presets = { "#e94560", "#60a5fa", "#4ade80" },  -- optional custom presets
    cb      = function(hex) print("Color:", hex) end,
})
```

Keyboard: `Enter` on the row opens the popover. `←` `→` `↑` `↓` navigate presets. `Enter`/`Space` selects. `Escape` closes.

---

### date_picker

Three number inputs for day/month/year. Returns an ISO date string (`"YYYY-MM-DD"`).

```lua
menu:date_picker("Review Date", {
    icon    = "calendar",
    default = "2025-06-15",   -- optional, defaults to today
    min     = "2024-01-01",   -- optional lower bound
    max     = "2030-12-31",   -- optional upper bound
    format  = "dmy",          -- 'dmy' (default) | 'mdy' | 'ymd'
    cb      = function(date) print("Date:", date) end,
})
```

| Option | Type | Description |
|---|---|---|
| `icon` | string | Lucide icon name |
| `default` | string | Pre-filled date in `"YYYY-MM-DD"` format (defaults to today) |
| `min` | string | Minimum selectable date (`"YYYY-MM-DD"`) |
| `max` | string | Maximum selectable date (`"YYYY-MM-DD"`) |
| `format` | string | Display order for the three inputs: `'dmy'` (DD/MM/YYYY, default), `'mdy'` (MM/DD/YYYY), `'ymd'` (YYYY/MM/DD) |
| `id` | string | Stable callback ID |
| `cb` | function | Called on confirm: `function(date) end` — returns `"YYYY-MM-DD"` |

---

### separator

A thin horizontal line.

```lua
menu:separator()
```

---

### header

A section label (all-caps, dimmed).

```lua
menu:header("Vehicle Stats", { color = "#60a5fa", align = "left" })
```

| Option | Type | Description |
|---|---|---|
| `color` | string | Text color override (hex) |
| `align` | string | Text alignment: `'left'` (default), `'center'`, `'right'` |
| `id` | string | Stable item ID |

---

### accordion

A collapsible section. Any item type can be placed inside.

> **Note:** All buttons default to `keep_open = true` — clicking them does not close the menu. Set `keep_open = false` explicitly to close on click.

```lua
menu:accordion("Player Info", function(acc)
    acc:stat("Health", 85, 100, { icon = "heart", suffix = "%" })
    acc:stat("Armor",  60, 100, { icon = "shield", suffix = "%" })
    acc:button("Heal", {
        icon = "plus-circle",
        cb   = function() print("healed") end,
        -- keep_open = false,  -- uncomment to close menu on click
    })
end, {
    icon = "user",
    open = true,    -- open by default (default: false)
})
```

Keyboard: `Enter` on the accordion header toggles it.

---

### tab

Organizes items into named tabs. A tab bar is automatically shown at the top of the menu when at least one tab is defined.

```lua
menu:tab("Weapons", function(t)
    t:button("Pistol",  { icon = "crosshair", badge = "500€", cb = function() end })
    t:button("Rifle",   { icon = "crosshair", badge = "1200€", cb = function() end })
end, { icon = "crosshair" })

menu:tab("Ammo", function(t)
    t:button("9mm x50",   { icon = "package", badge = "80€", cb = function() end })
    t:button("Rifle x30", { icon = "package", badge = "120€", cb = function() end })
end, { icon = "package" })
```

> Items placed **outside** any tab block are always visible (above the tab bar content area).

---

## 4. Real-time reactive items

Pass a **function** as the `label` to a button for dynamic text that auto-updates.

Use `visible` or `disabled` as functions for items that show/hide or enable/disable based on game state.

```lua
local startTime = GetGameTimer()

UI:context(function(menu)
    menu:title("Live Info")

    -- Dynamic label (updates every 1s)
    menu:button(function()
        local elapsed = math.floor((GetGameTimer() - startTime) / 1000)
        return string.format("Open for: %ds", elapsed)
    end, { refresh = 1000 })

    -- Conditional visibility (checks every 500ms)
    menu:button("Low Health Warning", {
        icon    = "heart",
        color   = "#e94560",
        visible = function() return GetEntityHealth(PlayerPedId()) < 150 end,
        refresh = 500,
    })
end)
```

**`refresh`** (ms) controls how often the watcher function is called. Default: `500ms` for all reactive fields (label, visible, disabled, color, badge). Minimum recommended: `100ms`.

---

## 5. Reusable menus

Build once, open multiple times without re-running the builder.

```lua
local shopMenu = UI:context_build(function(menu)
    menu:title("Shop")
    menu:button("Buy Item — 50€", {
        icon = "shopping-cart",
        cb   = function() print("purchased") end,
    })
    menu:button("Close", { icon = "x", cb = function() end })
end)

-- Later, open it:
RegisterCommand('openshop', function()
    shopMenu:open()
end, false)
```

> Note: callbacks are registered once. Reactive watchers start fresh on each `open()`.

---

## 6. Sub-menus

Open a second context menu from within a callback. The parent stays in the stack.

```lua
menu:button("Advanced Options", {
    icon      = "settings",
    arrow     = true,
    keep_open = true,   -- required: keeps parent menu open
    cb        = function()
        UI:context(function(sub)
            sub:title("Advanced Options")
            sub:animation("slideRight")
            sub:button("Option A", { cb = function() end })
            sub:button("Back",     { icon = "arrow-left", cb = function() end })
        end)
    end,
})
```

### Helpers: `b:submenu()` and `b:back()` (1.0.0)

Use the builder shorthand methods to reduce boilerplate when nesting menus:

```lua
UI:context(function(menu)
    menu:title("Main Menu")

    -- b:submenu(label, builderFn, opts) — equivalent to keep_open button that opens a sub-context
    menu:submenu("Paramètres", function(sub)
        sub:title("Paramètres")
        sub:button("Audio",  { icon = "volume-2", cb = function() end })
        sub:button("Vidéo",  { icon = "monitor",  cb = function() end })
        -- b:back() — closes this sub-menu and returns to the parent
        sub:back("Retour",   { icon = "arrow-left" })
    end, { icon = "settings" })
end)
```

`menu:back(label, opts)` is equivalent to a button whose callback calls `Stack.pop()`. Pass `opts.cb` to run cleanup logic **before** popping:

```lua
sub:back("Retour", {
    icon = "arrow-left",
    cb   = function() cleanup() end   -- optional, runs before pop
})
```

Pressing `Escape` closes the top menu and returns to the parent.

---

## 7. Live rebuild (`context_update`)

`context_update` rebuilds the currently visible context menu **without closing and reopening it**. Use it to refresh item lists that aren't covered by individual watchers (e.g., the list changed entirely — new items added/removed, not just field values).

```lua
local UI = exports['LastMenu']

-- Rebuild the top context menu with a new builder function
UI:context_update(function(menu)
    menu:title("Shop")
    for _, item in ipairs(getUpdatedInventory()) do
        menu:button(item.name, { badge = item.price .. "€", cb = function() buy(item) end })
    end
end)
```

> Only works when the top of the stack is a context menu. If the stack is empty or the top is a different type, the call is silently ignored.

**When to use `context_update` vs reactive watchers:**

| Situation | Recommended |
|---|---|
| A button label/badge/color/visible changes | Watcher (`visible = function()`, `badge = function()`) |
| The item list itself changes (add/remove items) | `context_update` |
| Switching "tabs" by reloading the entire menu | `context_update` |

**Handle variant** — `context_build` handles expose the same method scoped to that specific menu (even if it's not on top):

```lua
local shopHandle = UI:context_build(function(menu)
    -- ...
end)

-- Later, rebuild without closing/reopening:
shopHandle.update(function(menu)
    menu:title("Shop (refreshed)")
    -- ...
end)

-- Or re-run the original builder:
shopHandle.update()
```

---

## 8. User settings

Players can open the **user configurator** at any time by pressing **F12** (default keybind, rebindable in GTA5 controls).

| Setting | Options | Effect |
|---|---|---|
| **Navigation mode** | Mouse only / Keyboard only / Both | Controls how the menu responds to input |
| **Target key** | Left Ctrl / E / G / Alt | Key used to open target action menus |
| **Accent color** | 10 presets + custom picker | Changes `--ui-accent` globally |
| **Menu opacity** | Slider | Changes `--ui-ctx-bg` alpha |
| **Menu width** | Slider | Changes `--ui-ctx-width` |
| **Compact mode** | Toggle | Reduces item height (`--ui-ctx-item-height`) |
| **Blur effect** | Toggle | Enables/disables backdrop-filter |
| **Font size** | 80% to 130% | Changes `--ui-font-scale` |
| **UI sounds** | Toggle | Enables/disables click/hover sounds |
| **Notification position** | 4 quadrants | Toast placement |
| **Reset position** | Button | Returns menu to default screen position |

Settings are saved to `localStorage` and persist between sessions. The developer's `menu:nav('mouse')` / `menu:nav('keyboard')` always takes priority over the user's global navigation setting.

> Open or close the settings panel programmatically:
> ```lua
> exports.LastMenu:settings_open()
> exports.LastMenu:settings_close()
> ```

---

## 9. Security notes

**Callbacks are client-side only.** LastMenu emits no network events. Every `cb` function runs in the client Lua context — there is no server-side interaction unless your callback explicitly triggers one (e.g. via `TriggerServerEvent`). This means:
- No event spoofing risk from LastMenu itself.
- Server-side validation is the developer's responsibility when callbacks trigger server events.

**Banner and image URLs** are validated by the NUI layer: only `https://` and `nui://` schemes are accepted. Any other URL is silently discarded before rendering.

**CSS injection** is prevented on all color and style fields — values are stripped to safe characters before being applied to inline styles.
