# Notifications

Non-blocking toast notifications. Displayed outside the menu stack — they never steal focus or block interaction.

---

## Usage

```lua
exports.LastMenu:notify(function(n)
    n:message('Action successful!')
    n:type('success')       -- 'success' | 'error' | 'warn' | 'info'
    n:duration(3000)        -- milliseconds (default: 3000)
    n:icon('check')         -- Lucide icon (optional, overrides the type icon)
end)
```

### Shorthand pattern

Wrap in a helper to avoid writing the builder everywhere:

```lua
local UI = exports['LastMenu']

local function notify(msg, t, dur)
    UI:notify(function(n)
        n:message(msg)
        n:type(t or 'success')
        n:duration(dur or 2500)
    end)
end

notify('Vehicle repaired!')
notify('Not enough money.', 'error')
notify('Danger zone ahead.', 'warn', 5000)
notify('3 players nearby.', 'info', 4000)
```

---

## Builder methods

| Method | Type | Default | Description |
|---|---|---|---|
| `n:message(str)` | `string` | `""` | Toast body text |
| `n:type(str)` | `string` | `'info'` | Visual style: `'success'` `'error'` `'warn'` `'info'` |
| `n:duration(ms)` | `number` | `3000` | Auto-dismiss delay in milliseconds |
| `n:icon(str)` | `string` | *(type default)* | Custom Lucide icon — overrides the type icon |
| `n:title(str)` | `string` | `nil` | Optional header shown above the message |
| `n:group(key)` | `string` | `nil` | Deduplication key — replaces any existing toast with the same key |
| `n:persistent()` | — | — | Toast never auto-dismisses (`duration = 0`); must be closed by the player |
| `n:on_dismiss(cb)` | `function` | `nil` | Called when the player clicks × to close. **Not** called on auto-expiry or group replacement |

---

## Position

Configured in **User Settings** (F12 panel):

- X axis: `left` / `right`
- Y axis: `top` / `bottom`

Defaults to `bottom-right`.

---

## Custom icon and title

```lua
exports.LastMenu:notify(function(n)
    n:title('New Mission')
    n:message('Deliver the package to the docks.')
    n:type('info')
    n:icon('map-pin')   -- any Lucide icon name
    n:duration(5000)
end)
```

---

## Persistent toast

A persistent toast never auto-dismisses. The player must click × to close it.

```lua
exports.LastMenu:notify(function(n)
    n:message('Server maintenance in 5 minutes — save your progress.')
    n:type('warn')
    n:persistent()      -- equivalent to n:duration(0)
    n:on_dismiss(function()
        print('Player acknowledged the maintenance notice.')
    end)
end)
```

> `on_dismiss` fires **only** when the user explicitly clicks ×.  
> It is **not** called when the toast expires by timeout or is replaced by a group update.

---

## Group deduplication

`n:group(key)` associates the toast with an arbitrary string key. When a new toast arrives with the **same key**:

1. The existing toast is **removed immediately** (no exit animation).
2. The new toast is added with its own duration, type, and `on_dismiss`.
3. If no toast with that key is currently visible, the new toast appears normally.

The replacement is synchronous — no delay. The previous `on_dismiss` is silently cancelled.

### Scenario 1 — No group (independent toasts stack)

```lua
-- Three independent toasts — each expires on its own timer
exports.LastMenu:notify(function(n) n:message('Toast A'); n:type('info') end)
exports.LastMenu:notify(function(n) n:message('Toast B'); n:type('success') end)
exports.LastMenu:notify(function(n) n:message('Toast C'); n:type('warn') end)
-- Result: A + B + C visible simultaneously
```

### Scenario 2 — Zone status (same key replaces)

```lua
local function notifyZone(msg)
    exports.LastMenu:notify(function(n)
        n:message(msg)
        n:type('warn')
        n:duration(4000)
        n:group('zone_status')
    end)
end

notifyZone('Entering Red Zone')        -- toast shown
Wait(2000)
notifyZone('Entering Blue Zone')
-- → 'Red Zone' toast removed immediately
-- → 'Blue Zone' toast shown with a fresh 4 000 ms timer
```

### Scenario 3 — Multiple independent group keys

Different group keys never interfere with each other:

```lua
-- 'coins' and 'health' coexist as separate toasts
exports.LastMenu:notify(function(n) n:message('Coins: 500');   n:group('coins')  end)
exports.LastMenu:notify(function(n) n:message('HP: 80/100');   n:group('health') end)

-- Replaces only the 'coins' toast; 'health' toast is untouched
exports.LastMenu:notify(function(n) n:message('Coins: 501');   n:group('coins')  end)
```

### Scenario 4 — Group + persistent

```lua
-- Show a persistent 'connection lost' toast
exports.LastMenu:notify(function(n)
    n:message('Connection lost — reconnecting…')
    n:type('error')
    n:persistent()
    n:group('connection')
end)

-- Later: replace it with a timed 'connected' toast (even though the first was persistent)
exports.LastMenu:notify(function(n)
    n:message('Connection restored.')
    n:type('success')
    n:duration(3000)
    n:group('connection')
    -- The previous on_dismiss is NOT called (toast was replaced, not user-dismissed)
end)
```

### Group edge cases

| Scenario | Behaviour |
|---|---|
| `n:group(nil)` | Same as no group — no deduplication |
| `n:group('')` | Creates a group with key `""` — toasts with `n:group('')` replace each other |
| Group + `on_dismiss` replaced by new group toast | Previous `on_dismiss` silently cancelled |
| Multiple resources using the same group key | They share the same slot — intentional |

---

## Multiple notifications

Toasts stack vertically. Each dismisses independently after its `duration`. There is no hard limit on simultaneous toasts (configurable in User Settings).
