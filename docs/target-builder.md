# Target — Builder API

The target system accepts two forms for the `opts` parameter:

| Form | Syntax |
|---|---|
| Classic table | `{ label = "X", actions = { … } }` |
| **Builder (recommended)** | `function(t) t:label("X") … end` |

The builder is detected automatically — same pattern as `LM:context()`, `LM:radial()`, etc.

```lua
LM:target_add_model("mp_m_freemode_01", function(t)
    t:label("Player")
    t:icon("user")
    t:distance(3.0)
    t:button("Interact", { icon = "hand", cb = function(entity) … end })
end)
```

---

## Header methods

Define the metadata for the action menu shown when the player presses **E**.

| Method | Type | Default | Description |
|---|---|---|---|
| `t:label(str)` | `string` | `"Interact"` | Title of the action menu |
| `t:icon(str)` | `string` | `"eye"` | Lucide icon shown in the reticle |
| `t:distance(num)` | `number` | `3.0` | Max distance in metres |
| `t:banner(url)` | `string` | `nil` | Image/GIF URL displayed at the top of the menu |
| `t:on_enter(fn)` | `function()` | `nil` | Called once when the player enters the zone |
| `t:on_leave(fn)` | `function()` | `nil` | Called once when the player leaves the zone |

```lua
LM:target_add_sphere(coords, 5.0, function(t)
    t:label("Warehouse")
    t:icon("warehouse")
    t:banner("nui://my_resource/img/banner.gif")
    t:on_enter(function() showHUD(true)  end)
    t:on_leave(function() showHUD(false) end)
    -- … actions …
end)
```

---

## Actions

### `t:button(label, opts)`

Simple action. The callback receives `entity` (GTA handle, or `nil` for zone-based targets).

```lua
t:button("Repair", {
    icon         = "wrench",
    gradient     = true,    -- coloured gradient background
    confirm_hold = 2000,    -- hold 2 s before firing (ms)
    cooldown     = 60000,   -- recharge delay after click (ms)
    condition    = function() return isOnDuty end,  -- hidden when false
    disabled     = false,   -- greyed out but visible
    cb           = function(entity) repairVehicle(entity) end,
})
```

| Field | Type | Description |
|---|---|---|
| `icon` | `string` | Lucide icon |
| `color` | `string` | Accent color (hex) for the icon and optional gradient |
| `gradient` | `bool` | Gradient background using `color` (highlights the action) |
| `confirm_hold` | `number\|true` | Hold duration in ms (`true` = config value) |
| `cooldown` | `number` | Recharge in ms after click |
| `persist_key` | `string` | Stable localStorage key for cooldown persistence — use when the label is dynamic |
| `condition` | `bool\|function(entity)→bool` | Hidden when `false` |
| `disabled` | `bool\|function(entity)→bool` | Visible but not clickable |
| `badge` | `string` | Small text badge shown on the right |
| `keep_open` | `bool` | Keep the target menu open after callback fires (auto-`true` for toggles, sliders, checkboxes, and when `cooldown` is set) |
| `cb` | `function(entity)` | Click callback |

---

### `t:toggle(label, opts)`

Persistent on/off button. The callback receives `entity, boolean_value`.

```lua
t:toggle("Lock", {
    icon    = "lock",
    default = false,
    cb      = function(entity, val)
        SetVehicleDoorsLocked(entity, val and 2 or 1)
    end,
})
```

---

### `t:checkbox(label, opts)`

Checkbox. Same interface as `toggle` but different visual rendering.

```lua
t:checkbox("Invoice sent", {
    icon    = "receipt",
    default = false,
    cb      = function(entity, val)
        if val then sendInvoice(entity) end
    end,
})
```

---

### `t:slider(label, opts)`

Numeric slider. The callback receives `entity, numeric_value`.

```lua
t:slider("Fuel", {
    icon    = "fuel",
    min     = 0,
    max     = 100,
    step    = 5,
    default = 50,
    suffix  = "%",
    cb      = function(entity, val)
        SetVehicleFuelLevel(entity, val * 0.65)
    end,
})
```

---

### `t:separator()`

Visual divider between action groups.

```lua
t:button("Action A", { … })
t:separator()
t:button("Action B", { … })
```

---

### `t:group(label, opts, fn)`

Groups actions inside a collapsible **accordion**. Actions inside share the same group header.

```lua
t:group("Services", { icon = "tool" }, function(g)
    g:button("Clean",           { icon = "droplets",         cb = cleanVehicle  })
    g:button("Inflate tyres",   { icon = "circle-dot",       cb = inflateTyres  })
    g:button("Charge battery",  { icon = "battery-charging", cb = chargeBattery })
    -- g:toggle / g:checkbox / g:slider also available
end)
```

| Opt | Type | Description |
|---|---|---|
| `icon` | `string` | Icon for the group header |
| `open` | `bool` | Expanded by default (`false`) |

> A group is **not** a separate target zone — it is purely a visual layout within the same action menu.

---

### `t:submenu(label, opts)`

Arrow `→` button that calls a function **without closing** the target menu.

```lua
t:submenu("Mechanic menu", {
    icon = "hard-hat",
    cb   = function(entity) openMechanicRadial(entity) end,
})
```

**What actually happens:**

1. The player clicks "Mechanic menu" in the target panel.
2. The target menu **stays open** — it is not popped from the stack.
3. Your `cb(entity)` is called. You can open anything inside it:
   - `LM:radial(…)` → radial menu on top
   - `LM:context(…)` → context menu (ideal for a sub-level of actions)
   - `LM:input_async(…)` → input form
4. When that menu closes, the target panel is still underneath.

> **Opening a second target menu from a submenu is not possible.**
> Target menus only open via the polling thread (player aims + presses E).
> To present a sub-level of actions, use `LM:context()` inside the callback.

```lua
t:submenu("Advanced options", {
    icon = "settings-2",
    cb   = function(entity)
        LM:context(function(menu)
            menu:title("Advanced options")
            menu:button("Paint",  { icon = "paintbrush", cb = function() openPaint(entity)  end })
            menu:button("Tuning", { icon = "gauge",       cb = function() openTuning(entity) end })
            menu:back("Back")
        end)
    end,
})
```

> **Difference from `button`:** a `button` closes the target menu before firing its callback.
> A `submenu` keeps it open, enabling layered navigation.

---

## Full example — Vehicle (mechanic job)

```lua
local LM = exports.LastMenu

LM:target_add_model(nil, function(t)   -- nil = all vehicles
    t:label("Vehicle")
    t:icon("car")
    t:distance(4.0)
    t:banner("nui://job_mechanic/img/banner.gif")   -- optional

    -- Root actions
    t:button("Repair", {
        icon         = "wrench",
        gradient     = true,
        confirm_hold = 2000,
        cooldown     = 60000,
        condition    = function() return isOnDuty end,
        cb           = function(entity) repairVehicle(entity) end,
    })
    t:button("Inspect / Estimate", {
        icon = "clipboard-list",
        cb   = function(entity) openDiagnostic(entity) end,
    })

    t:separator()

    -- "Services" accordion group
    t:group("Services", { icon = "tool" }, function(g)
        g:button("Clean", {
            icon      = "droplets",
            condition = function() return isOnDuty end,
            cb        = function(entity) cleanVehicle(entity) end,
        })
        g:button("Inflate tyres", {
            icon = "circle-dot",
            cb   = function(entity) inflateAllTyres(entity) end,
        })
        g:button("Charge battery", {
            icon = "battery-charging",
            cb   = function(entity) chargeVehicleBattery(entity) end,
        })
    end)

    -- "Options" accordion group
    t:group("Options", { icon = "settings-2" }, function(g)
        g:toggle("Lock", {
            icon    = "lock",
            default = false,
            cb      = function(entity, val)
                SetVehicleDoorsLocked(entity, val and 2 or 1)
            end,
        })
        g:slider("Fuel", {
            icon = "fuel", min = 0, max = 100, step = 5, suffix = "%",
            cb   = function(entity, val)
                -- SetVehicleFuelLevel(entity, val * 0.65)
            end,
        })
        g:checkbox("Invoice sent", {
            icon    = "receipt",
            default = false,
            cb      = function(entity, val)
                if val then sendInvoice(entity) end
            end,
        })
    end)

    -- Submenu → opens the mechanic radial on top of the target menu
    t:submenu("Mechanic menu", {
        icon = "hard-hat",
        cb   = function(entity) openMechanicRadial(entity) end,
    })
end)
```

---

## Method availability summary

| Method | Available on `t:` | Available on `g:` (group) |
|---|---|---|
| `button` | ✓ | ✓ |
| `toggle` | ✓ | ✓ |
| `checkbox` | ✓ | ✓ |
| `slider` | ✓ | ✓ |
| `separator` | ✓ | — |
| `group` | ✓ | — |
| `submenu` | ✓ | — |
| `label` / `icon` / `distance` / `banner` | ✓ | — |
| `on_enter` / `on_leave` | ✓ | — |
