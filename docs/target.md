# Target System

Replacement for `ox_target` / `qtarget`. Detects the entity or zone the player is looking at and shows an interaction menu.

## How it works

A background thread runs at **10 Hz** (100 ms). When the player aims at a registered entity or enters a zone:

1. A **passive reticle** appears at the centre of the screen.
2. The player presses the **target key** (default: Left Ctrl / `INPUT_DUCK`) → the **action menu** opens.
3. Selecting an action fires the callback; pressing **Escape** or the ✕ button closes the menu.

When no registrations exist the thread sleeps at **1 Hz** (no CPU cost).

---

## Registration types

### Entity — specific handle

```lua
local id = exports.LastMenu:target_add_entity(entity, opts)
```

| Field | Type | Default | Description |
|---|---|---|---|
| `entity` | `number` | — | Entity handle |
| `opts.label` | `string` | `'Interact'` | Header label of the action menu |
| `opts.icon` | `string` | `'eye'` | Lucide icon shown in the reticle |
| `opts.distance` | `number` | `3.0` | Max distance in metres |
| `opts.actions` | `table` | `{}` | Array of action objects (or use the builder API) |
| `opts.on_enter` | `function()` | `nil` | Called once when the player enters the target zone |
| `opts.on_leave` | `function()` | `nil` | Called once when the player leaves the target zone |

---

### Model — all entities matching a model

```lua
local id = exports.LastMenu:target_add_model(model, opts)
```

| Field | Type | Default | Description |
|---|---|---|---|
| `model` | `string\|number\|nil` | — | Model name, hash, or `nil` for **all vehicles** |
| `opts.distance` | `number` | `3.0` | Max distance from the entity |

All other fields are identical to entity.

---

### Sphere zone

```lua
local id = exports.LastMenu:target_add_sphere(coords, radius, opts)
```

| Field | Type | Default |
|---|---|---|
| `coords` | `vector3` | — |
| `radius` | `number` | `2.0` |

---

### Box zone

Axis-aligned rectangular zone, rotatable by heading.

```lua
local id = exports.LastMenu:target_add_box(coords, opts)
```

| Field | Type | Default | Description |
|---|---|---|---|
| `opts.width` | `number` | `2.0` | Full width on local X axis (halved internally for OBB test) |
| `opts.length` | `number` | `2.0` | Full length on local Y axis |
| `opts.heading` | `number` | `0.0` | Rotation in degrees (GTA clockwise from North) |

> `width` and `length` are **not** available through the builder API (see [Target Builder](target-builder.md)). Use the table form when you need specific dimensions.

---

### Polygon zone

2D polygon with optional Z-bounds.

```lua
local id = exports.LastMenu:target_add_poly(points, opts)
```

| Field | Type | Default | Description |
|---|---|---|---|
| `points` | `vector2[]\|vector3[]` | — | Array of 2D or 3D vertices defining the polygon |
| `opts.minZ` | `number` | `-math.huge` | Lower Z bound (restrict to a vertical slice) |
| `opts.maxZ` | `number` | `math.huge` | Upper Z bound |

> `minZ` / `maxZ` are **not** available through the builder API. Use the table form when you need Z constraints.

**Example — L-shaped store floor:**

```lua
local storeFloor = {
    vector2(312.0, -780.0),
    vector2(320.0, -780.0),
    vector2(320.0, -795.0),
    vector2(328.0, -795.0),
    vector2(328.0, -808.0),
    vector2(312.0, -808.0),
}

local storeId = exports.LastMenu:target_add_poly(storeFloor, {
    minZ     = 28.5,
    maxZ     = 32.0,
    label    = '24/7 Store',
    icon     = 'store',
    on_enter = function()
        exports.LastMenu:notify(function(n) n:message('Welcome!'); n:type('info') end)
    end,
    on_leave = function()
        exports.LastMenu:notify(function(n) n:message('Thanks for visiting.'); n:type('info') end)
    end,
    actions  = {
        { label = 'Shop',          icon = 'shopping-cart', cb = function() end },
        { label = 'Rob cashier',   icon = 'alert-triangle',
          condition = function() return IsPedArmed(PlayerPedId(), 6) end,
          cb = function() TriggerServerEvent('crime:robbery') end },
    },
})

-- Cleanup
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    exports.LastMenu:target_remove(storeId)
end)
```

---

## Action object

Each entry in `opts.actions` supports:

| Field | Type | Description |
|---|---|---|
| `label` | `string` | Button text |
| `icon` | `string` | Lucide icon |
| `color` | `string` | Accent color (hex) applied to the icon and optional gradient |
| `cb` | `function(entity)` | Called on click. `entity` = entity handle (or `nil` for zones) |
| `condition` | `bool\|function(entity) → bool` | Hide the action when `false` (preferred alias for `visible`) |
| `visible` | `bool\|function(entity) → bool` | Hide the action when `false` |
| `disabled` | `bool\|function(entity) → bool` | Show grayed-out, no callback |
| `gradient` | `bool` | Gradient background on the action button (uses `color` if set) |
| `badge` | `string` | Small text badge on the right |
| `confirm_hold` | `number\|true` | Hold-to-confirm duration in ms |
| `cooldown` | `number` | Recharge delay in ms after click |
| `persist_key` | `string` | Stable localStorage key for cooldown persistence — use when the action label is dynamic |
| `keep_open` | `bool` | Keep the target menu open after the callback fires (auto-`true` for toggles, sliders, checkboxes, and when `cooldown` is set) |

`condition` takes priority over `visible` when both are set. Both accept static booleans or callables evaluated each time the action menu is opened.

```lua
actions = {
    {
        label   = 'Search body',
        icon    = 'search',
        -- Only visible if ped is dead
        visible = function(ent) return IsPedDeadOrDying(ent, true) end,
        cb      = function(ent) print('Searched ped ' .. ent) end,
    },
    {
        label    = 'Heal',
        icon     = 'plus-circle',
        -- Grayed out if already at full health
        disabled = function(ent) return GetEntityHealth(ent) >= 200 end,
        cb       = function(ent) print('Healed ped ' .. ent) end,
    },
}
```

---

## Debug visualization

Set `Config.debugTarget = true` in `client/config.lua` to visualize registered zones in-world during development:

| Zone type | Visualization |
|---|---|
| `sphere` | Translucent blue sphere |
| `box` | Marker + corner lines |
| `poly` | Outline connecting all vertices |

```lua
Config.debugTarget = true   -- in client/config.lua
```

The debug thread sleeps 500 ms when disabled — zero performance cost in production.

---

## Removal

```lua
-- Remove one registration
exports.LastMenu:target_remove(id)

-- Remove all registrations
exports.LastMenu:target_clear()
```

Registrations are also automatically removed when the resource that created them stops (tracked via `_resource` field on each registration).

---

## Multiple registrations on the same entity

When several registrations match simultaneously, their actions are **merged** into a single menu. The header label follows priority: `entity > model > zone`.

---

## Full example

```lua
local LM = exports['LastMenu']

-- Sphere zone around a point of interest
local poiId = LM:target_add_sphere(
    vector3(100.0, 200.0, 30.0), 4.0,
    function(t)
        t:label('Warehouse')
        t:icon('warehouse')
        t:distance(4.0)
        t:on_enter(function() print('Player entered zone') end)
        t:on_leave(function() print('Player left zone')    end)
        t:button('Enter', {
            icon = 'door-open',
            cb   = function() end,
        })
    end
)

-- All police peds
local copId = LM:target_add_model('s_m_y_cop_01', function(t)
    t:label('Officer')
    t:distance(3.0)
    t:button('Talk', {
        icon = 'message-square',
        cb   = function(ent) print('Talking to ped ' .. ent) end,
    })
    t:button('Surrender Weapons', {
        icon      = 'package',
        condition = function(ent) return GetPedArmour(PlayerPedId()) > 0 end,
        cb        = function(ent) SetPedArmour(PlayerPedId(), 0) end,
    })
end)

-- Cleanup
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    LM:target_remove(poiId)
    LM:target_remove(copId)
end)
```
