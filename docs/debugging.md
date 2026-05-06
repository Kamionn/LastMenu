# Debugging Guide

How to diagnose problems with LastMenu in production and development.

---

## Enabling debug mode

In [client/config.lua](../client/config.lua), set:

```lua
Config.debug = true
```

With debug on, LastMenu prints to the resource console:

- Watcher eval/patch/error counts every 60 ticks per active menu
- Watcher recovery attempts (after Safe Mode disables a watcher)
- Type validation warnings from builders (wrong types passed to `field.min`, etc.)

To debug the **target system** specifically (draws zone outlines in-world):

```lua
Config.debugTarget = true
```

---

## Console commands

### `/lm_test`

Runs the regression test suite. Only works if `test/regression.lua` is loaded in
`fxmanifest.lua` (commented out by default to avoid shipping test code).

### `/lm_debug`

Prints a snapshot of all active watcher state to the **client console** (F8 in-game):

```
[LastMenu] ── Watcher stats ──────────────────────────
  Menu: 1735000000_1
    cb=cb_1735000000_1_shop_item_1     field=disabled    interval=500ms errors=0 status=ok
    cb=cb_1735000000_1_shop_item_2     field=visible     interval=500ms errors=2 status=ok
    cb=cb_1735000000_1_shop_item_3     field=disabled    interval=500ms errors=3 status=retry@1735015000
[LastMenu] ─────────────────────────────────────────
```

Status values:
- `ok` — watcher is healthy and polling
- `DISABLED` — Safe Mode active, no retryAt set (shouldn't happen, but indicates a bug in reactive.lua)
- `retry@<timestamp>` — Safe Mode active, will attempt recovery when `GetGameTimer()` reaches that value

### `exports.LastMenu:debug_stats()`

Calls the same logic as `/lm_debug` from another resource:

```lua
exports.LastMenu:debug_stats()
```

---

## Reading watcher errors

When a watcher function throws an error 5 times in a row, you'll see:

```
[LastMenu] Watcher DISABLED [1735000000_1:disabled] — will retry in 30s. Error: attempt to index a nil value (global 'playerData')
```

The error message is the Lua error thrown by the watcher function. Common causes:

| Error | Likely cause |
|-------|-------------|
| `attempt to index a nil value` | Accessing a variable that hasn't been set yet |
| `attempt to perform arithmetic on a nil value` | Using a number that's nil |
| `stack overflow` | Infinite recursion inside the watcher function |
| `bad argument #1 to 'X'` | Passing the wrong type to a native or function |

---

## Diagnosing NUI communication

If a menu opens but buttons don't respond:

1. Open the **Chromium devtools** for the NUI: in FiveM, enter `nui_devtools` in the
   F8 console (development builds only).
2. Check the **Console** tab for JavaScript errors.
3. Check the **Network** tab — NUI messages appear as `fetch` calls to `https://lastmenu/`.
4. Verify that `Bridge.onCallback` is registering the right `cb_id` — check the Lua
   console for `[LastMenu] ...` messages during the open sequence.

---

## Stack inspection

From another resource (or the Lua REPL in debug builds):

```lua
-- Peek at the current stack top
local top = exports.LastMenu:lastmenu_back  -- not directly accessible

-- Instead, check from within a watcher or callback:
-- LastMenu.Stack.peek() returns { id, type, level, nav } or nil
```

The stack type values are: `'context'`, `'alert'`, `'input'`, `'progress'`,
`'radial'`, `'target'`.

---

## Common symptoms

### Menu opens but immediately closes

- Check that `Stack.pop()` isn't being called twice (e.g., both `onComplete` and
  the default complete handler are registered — only register one).
- Check that another resource isn't calling `lastmenu_back` unexpectedly.

### NUI focus stays locked after resource restart

- The resource stopped while a menu was open, and `onResourceStop` didn't fire in
  time. Run `SetNuiFocus(false, false)` from the F8 console or restart the affected
  resource again.

### Watchers stop updating after a few seconds

- Safe Mode triggered. Run `/lm_debug` to see which watcher is disabled and what
  error it threw. Fix the watcher function and the menu will auto-recover within 30s.

### `UI_AlertAsync` returns `false` immediately

- It was called outside a coroutine. Wrap the call in `Citizen.CreateThread`. See
  [pitfalls.md](pitfalls.md#3-calling-_async-outside-a-coroutine).
