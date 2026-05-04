# Progress Bar

Timed progress bar with optional cancellation, ped animations, prop attachment, and a per-tick callback. The timer runs entirely in the NUI — no Lua polling needed.

---

## One-shot

```lua
exports.LastMenu:progress(function(p)
    p:label('Loading data…')
    p:duration(5000)          -- milliseconds
    p:cancelable(true)        -- show cancel button and allow Escape
    p:confirm(function()
        -- fires when the bar fills naturally (completion)
    end)
    p:cancel(function()
        -- fires when the player cancels (only if cancelable = true)
    end)
end)
```

## Reusable handle

```lua
local bar = exports.LastMenu:progress_build(function(p)
    p:label('Crafting…')
    p:duration(8000)
    p:cancelable(false)        -- mandatory action; player cannot cancel
    p:confirm(function() giveCraftedItem() end)
end)

bar.open()    -- start the bar
bar.close()   -- interrupt programmatically (does NOT fire confirm or cancel)
```

---

## Builder methods

| Method | Args | Description |
|---|---|---|
| `p:label(str)` | `string` | Text displayed above the bar |
| `p:duration(ms)` | `number` | Total duration in milliseconds |
| `p:cancelable(bool)` | `bool` | Allow cancel button + Escape (default: `false`) |
| `p:icon(str)` | `string` | Lucide icon shown next to the label |
| `p:confirm(cb)` | `function()` | Called when the bar fills naturally — **completion callback** |
| `p:cancel(cb)` | `function()` | Called when the player cancels — **cancellation callback** |
| `p:cb_tick(cb)` | `function(pct)` | Called every ~100 ms with current percentage `0–100` |
| `p:anim(opts)` | `table` | Play a ped animation for the full duration (see below) |
| `p:prop(opts)` | `table` | Attach a prop to the player ped for the full duration (see below) |

> **Naming note:** `p:confirm(cb)` is the **completion** callback (bar fills → complete), not a button click. `p:cancel(cb)` is called when the player **cancels** the action.

---

## Position

Configured in **User Settings** (F12):

| Preset | Location |
|---|---|
| `bottom-center` | Default — HUD bar style |
| `top-center` | Top of screen |
| `bottom-left` | Bottom-left corner |
| `bottom-right` | Bottom-right corner |

---

## Side effects

### `p:icon(str)` — label icon

Any Lucide icon shown inline with the label text:

```lua
p:label('Repairing engine…')
p:icon('wrench')
```

---

### `p:cb_tick` — per-frame progress callback

Called approximately every 100 ms with the current completion percentage. Use it for partial rewards, server sync, or dynamic HUD updates:

```lua
local halfway = false

p:cb_tick(function(pct)
    if pct >= 50 and not halfway then
        halfway = true
        TriggerServerEvent('craft:halfwayDone')
        PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
    end
end)
```

---

### `p:anim` — ped animation

Plays an animation for the full duration of the bar. Automatically cleared on complete, cancel, or programmatic close:

```lua
p:anim({
    dict  = 'amb@world_human_welding@male@base',
    clip  = 'base',
    flag  = 1,    -- AnimationFlag: 1 = loop, 49 = loop + upperbody only
})
```

| Field | Type | Description |
|---|---|---|
| `dict` | `string` | Animation dictionary name |
| `clip` | `string` | Clip name inside the dictionary |
| `flag` | `number` | `AnimationFlag` bitmask (default: `49`) |

The animation dict is requested asynchronously with a 3 s timeout. If the dict does not load in time, the bar opens anyway (no animation plays).

---

### `p:prop` — attached object

Attaches a prop to the player ped. Automatically detached and deleted on complete, cancel, or programmatic close:

```lua
p:prop({
    model  = 'prop_tool_torch',
    bone   = 57005,                    -- ped bone index (57005 = right hand)
    offset = vector3(0.12, 0.03, 0.0),
    rot    = vector3(0.0,  0.0,  0.0),
})
```

| Field | Type | Description |
|---|---|---|
| `model` | `string\|number` | Model name or hash |
| `bone` | `number\|string` | Bone index or bone name (resolved via `GetEntityBoneIndexByName`) |
| `offset` | `vector3` | Position offset relative to the bone |
| `rot` | `vector3` | Rotation offset (Euler angles) |

---

## Full example — welding

```lua
exports.LastMenu:progress(function(p)
    p:label('Welding…')
    p:icon('zap')
    p:duration(8000)
    p:cancelable(true)

    p:anim({
        dict = 'amb@world_human_welding@male@base',
        clip = 'base',
        flag = 1,
    })

    p:prop({
        model  = 'prop_tool_torch',
        bone   = 57005,
        offset = vector3(0.12, 0.03, 0.0),
        rot    = vector3(0.0,  0.0,  0.0),
    })

    p:cb_tick(function(pct)
        if pct % 25 < 1 then
            PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
        end
    end)

    p:confirm(function() giveCraftedItem() end)
    p:cancel(function()  notifyWarn('Welding cancelled.') end)
end)
```

---

## Notes

- While a progress bar is open it owns the stack — other menus cannot open until it finishes or is cancelled.
- Use `cancelable(false)` for mandatory actions (crafting, mission interactions). Use `cancelable(true)` for player-interruptible tasks (lockpicking, hacking).
- `bar.close()` interrupts the bar silently — neither `p:confirm()` nor `p:cancel()` fires.
- Both `anim` and `prop` side effects are cleaned up automatically regardless of how the bar closes (complete / cancel / programmatic close / Escape).
