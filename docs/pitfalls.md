# Pitfalls & Anti-patterns

Common mistakes when using LastMenu, with explanations and fixes.

---

## 1. Watcher returning a table

**Since 1.0.0** — tables returned by watcher functions are compared by content (JSON encoding),
not by reference. Returning a fresh table with the same data each tick does **not** trigger
a patch — the engine serializes both values and only fires if the JSON differs.

```lua
-- Fine: new table each tick, but content is the same → no patch sent
b:button('Status', {
    label = function()
        return { text = getStatusLabel() }
    end,
})
```

The old workaround of always returning a primitive is still the simplest approach for
`visible`/`disabled` (which expect booleans — see pitfall #4), but it is no longer
required to avoid constant patches for `label`, `badge`, or `color`.

---

## 2. Duplicate labels in the same menu

**Since 1.0.0** cb_ids are derived from the item label (slugified) instead of their
insertion position. `menu:button('Buy', ...)` always gets `cb_<menu_id>_buy` regardless
of how many items appear before it. This eliminates the old positional-shift bug.

The only case that still needs attention is **two items with the exact same label** in
the same menu. LastMenu appends `_2`, `_3`, … automatically, so the callbacks are still
correct — but if one of those items is reactive, the patch will only reach the right item
if the order of same-label items is stable across rebuilds.

```lua
-- Fine: labels are unique → stable slugs
b:button('Buy',  { cb = fn1 })
b:button('Sell', { cb = fn2 })
```

```lua
-- Works, but the second "Action" gets slug action_2 — keep the order stable
b:button('Action', { cb = fn1 })
b:button('Action', { cb = fn2, disabled = function() return onCooldown() end })
```

```lua
-- Best: use opts.id to pin an explicit key when in doubt
b:button('Action', { id = 'action_buy',  cb = fn1 })
b:button('Action', { id = 'action_sell', cb = fn2, disabled = function() return onCooldown() end })
```

---

## 3. Calling `*_async` outside a coroutine

`UI_AlertAsync` and `UI_InputAsync` call `coroutine.yield()` internally. They **must**
be called from within a `Citizen.CreateThread` coroutine. Calling them from a regular
event handler or a non-coroutine callback will print an error and return `nil`/`false`
immediately.

```lua
-- BAD: regular event handler (not a coroutine)
AddEventHandler('myEvent', function()
    local ok = UI_AlertAsync(function(b) ... end)  -- returns false, no UI shown
end)

-- GOOD: wrapped in a thread
AddEventHandler('myEvent', function()
    Citizen.CreateThread(function()
        local ok = UI_AlertAsync(function(b) ... end)
        if ok then ... end
    end)
end)
```

---

## 4. Table-valued watcher for `visible` or `disabled`

Same root cause as #1 but specific to `visible`/`disabled`. These fields expect
`boolean`. Returning anything else (including a table or `nil`) causes the watcher
to not be registered, and a warning is printed.

```lua
-- BAD: visible expects boolean, not a table
b:button('Buy', { visible = function() return getPlayerData() end })

-- GOOD
b:button('Buy', { visible = function() return getPlayerData() ~= nil end })
```

---

## 5. `default` vs `value` inconsistency in input fields

Input fields use `opts.default` (not `opts.value`) to set a pre-filled value.
This is consistent with HTML `<input defaultValue>` semantics — the user can
change it, and the original value is a hint, not a constraint.

```lua
b:field('Amount', { type = 'number', default = 100 })
--                              ↑ not "value"
```

---

## 6. Resource restart leaving NUI focus locked

If a resource stops while a menu is open, LastMenu clears the stack and releases
NUI focus synchronously in `onResourceStop`. However, if your code calls
`Stack.pop()` or `Stack.clear()` directly inside `onResourceStop` of an external
resource, the NUI focus may not be released because the Bridge's deferred close
message might not be processed.

**Fix**: Always stop menus before stopping dependent resources, or call
`exports.LastMenu:lastmenu_back()` to cleanly close the top menu.

---

## 7. Using `UI_Context_Update` when no context menu is open

`UI_Context_Update` reads `Stack.peek()`. If the top of the stack is not a context
menu (or the stack is empty), it silently does nothing. This is intentional —
calling update on a stale reference is safe. But if your update isn't applying,
check `Stack.peek().type` equals `'context'` first.

---

## 8. Watcher permanent disable (Safe Mode)

After 5 consecutive errors in a watcher function, LastMenu enters Safe Mode for
that watcher and disables it for 30 seconds. The watcher then gets one recovery
attempt. If the error persists, it is disabled again for another 30 seconds.

**Symptoms**: A button's `visible`/`disabled` state stops updating after a few
seconds, then briefly updates, then stops again.

**Fix**: Check the resource console for `[LastMenu] Watcher DISABLED` messages.
Inspect the watcher function for runtime errors (nil access, wrong types, etc.).
Enable `Config.debug = true` or run `/lm_debug` for detailed watcher stats.
