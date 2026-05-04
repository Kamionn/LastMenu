# Radial Menu

A circular quick-action wheel. Supports mouse hover, keyboard navigation, gamepad stick, and reactive buttons (`visible` / `disabled`).

---

## One-shot

Opens immediately and discards the instance on close.

```lua
exports.LastMenu:radial(function(r)
    r:center_label('Quick Actions')   -- text shown in center ring when nothing is hovered
    r:button('Garage',   { icon = 'car',        cb = openGarage   })
    r:button('Hospital', { icon = 'plus-circle', cb = openHospital })
    r:button('Missions', { icon = 'zap',         cb = openMissions })
end)
```

## Reusable handle

```lua
local wheel = exports.LastMenu:radial_build(function(r)
    r:button('Action A', { icon = 'check', cb = function() end })
    r:button('Action B', { icon = 'x',     cb = function() end })
end)

wheel.open()    -- open
wheel.close()   -- close programmatically
```

---

## Menu options

| Method | Description |
|---|---|
| `r:center_label(str)` | Text shown in the center ring when no sector is hovered |

## Button options

| Field | Type | Default | Description |
|---|---|---|---|
| `icon` | `string` | — | Lucide icon name |
| `cb` | `function()` | — | Called on selection |
| `keep_open` | `bool` | `false` | Do not close the radial after callback (useful for toggles) |
| `confirm_hold` | `bool\|number` | `nil` | Hold-to-confirm duration in ms (`true` = `Config.hold_duration`) |
| `submenu` | `function(r)` | `nil` | Builder function — opens a nested radial on click (see below) |
| `visible` | `bool\|function() → bool` | `true` | Hide the sector and redistribute arc geometry |
| `disabled` | `bool\|function() → bool` | `false` | Grey out without removing the sector (layout stays stable) |
| `refresh` | `number` | `500` | Watcher polling interval in ms for reactive `visible`/`disabled` |
| `id` | `string` | *(auto)* | Stable callback ID (useful when button count is dynamic) |

---

## Reactive example — button visible only when in a vehicle

```lua
r:button('Exit Vehicle', {
    icon    = 'log-out',
    visible = function()
        return GetVehiclePedIsIn(PlayerPedId(), false) ~= 0
    end,
    refresh = 500,
    cb      = function()
        TaskLeaveAnyVehicle(PlayerPedId(), 0, 16)
    end,
})
```

---

## Sub-radials

Use `button.submenu` to open a nested radial from a sector. The parent radial is pushed onto the navigation stack and restored when the player presses Escape:

```lua
exports.LastMenu:radial(function(r)
    r:center_label('Actions')

    r:button('Vehicle', {
        icon    = 'car',
        submenu = function(sub)
            sub:center_label('Vehicle')
            sub:button('Repair',  { icon = 'wrench',   cb = repairVehicle })
            sub:button('Clean',   { icon = 'droplets', cb = cleanVehicle  })
            sub:button('Lock',    { icon = 'lock',      keep_open = true,
                cb = function()
                    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                    SetVehicleDoorsLocked(veh, 2)
                end,
            })
        end,
    })

    r:button('Player', {
        icon    = 'user',
        submenu = function(sub)
            sub:center_label('Player')
            sub:button('Heal',       { icon = 'heart',  cb = function() SetEntityHealth(PlayerPedId(), 200) end })
            sub:button('Add Armor',  { icon = 'shield', cb = function() SetPedArmour(PlayerPedId(), 100)    end })
        end,
    })
end)
```

> With `submenu`, the button automatically sets `keep_open = true` — no need to specify it manually.

---

## Controls

| Input | Action |
|---|---|
| Mouse hover | Highlight sector |
| Left click | Confirm selection |
| Gamepad left stick | Navigate by direction |
| Gamepad A / Cross | Confirm selection |
| Escape | Close without action |

Gamepad support is built-in — no additional configuration required.

---

## Notes

- `visible = false` **removes** the sector and redistributes the arc geometry. Use `disabled = true` to keep the sector visible but inactive (stable layout — recommended for toggles).
- Reactive `visible`/`disabled` use the same adaptive-polling engine as context menus: backoff on stable values, reset on change.
- Up to ~12 buttons display cleanly. Beyond that the sectors become narrow — consider sub-radials or a context menu.
- The radial does not support pagination or search — it is designed for 4–8 quick actions.
