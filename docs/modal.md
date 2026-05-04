# Alert / Modal

Blocking confirmation dialog with up to two buttons (confirm + cancel).

---

## One-shot

```lua
exports.LastMenu:alert(function(a)
    a:title('Confirm Purchase')
    a:message('Buy this item for 500€?')
    a:confirm('Yes, buy', function()
        -- confirmed — fires then closes the modal
    end)
    a:cancel('Cancel', function()
        -- optional: fires then closes the modal
    end)
end)
```

## Reusable handle

Use `alert_build` when you need to open the same dialog from multiple places without rebuilding it each time.

```lua
local deleteDialog = exports.LastMenu:alert_build(function(a)
    a:title('Delete Character')
    a:message('This action is irreversible.')
    a:confirm('Delete', function() deleteCharacter() end)
    a:cancel('Cancel')
end)

-- Later:
deleteDialog.open()
-- Close programmatically (e.g. from a server event):
deleteDialog.close()
```

---

## Builder methods

| Method | Args | Description |
|---|---|---|
| `a:title(str)` | `string` | Dialog header |
| `a:message(str)` | `string` | Body text (supports `\n` for line breaks) |
| `a:type(str)` | `string` | Visual style: `'info'` `'confirm'` `'warn'` `'error'` |
| `a:confirm(label, cb)` | `string, function` | Primary (accent-coloured) button |
| `a:cancel(label, cb?)` | `string, function?` | Secondary button — callback is optional |

Both buttons automatically close the modal after firing the callback.

---

## Async variant

`UI_AlertAsync` blocks the current coroutine and returns `true` (confirm) or `false` (cancel / Escape). Must be called from inside a `Citizen.CreateThread`.

```lua
Citizen.CreateThread(function()
    local confirmed = exports.LastMenu:alert_async(function(a)
        a:title('Reset Account?')
        a:message('All progress will be lost. This action is irreversible.')
        a:confirm_label('Reset')    -- async-only method (no callback needed)
        a:cancel_label('Cancel')
    end)

    if confirmed then
        TriggerServerEvent('account:reset')
    end
end)
```

### `UI_AlertAsync` builder methods

| Method | Description |
|---|---|
| `a:title(str)` | Dialog header |
| `a:message(str)` | Body text |
| `a:type(str)` | Visual style |
| `a:confirm_label(str)` | Label for the confirm button (default: `'Confirm'`) |
| `a:cancel_label(str)` | Label for the cancel button (default: `'Cancel'`) |

> **Note:** `confirm_label` / `cancel_label` are only available in the async variant. In the regular `alert` and `alert_build`, use `a:confirm(label, cb)` and `a:cancel(label, cb)`.

---

## Multi-step async example

Chaining an input form and an alert in sequence without nested callbacks:

```lua
Citizen.CreateThread(function()
    -- Step 1: collect data
    local values = exports.LastMenu:input_async(function(b)
        b:title('Create Character')
        b:field('First Name', { type = 'text', maxlen = 20 })
        b:field('Last Name',  { type = 'text', maxlen = 20 })
        b:confirm_label('Next')
        b:cancel_label('Cancel')
    end)
    if not values then return end

    -- Step 2: confirm before committing
    local ok = exports.LastMenu:alert_async(function(a)
        a:title('Confirm Creation')
        a:message(string.format('Create "%s %s"?', values[1], values[2]))
        a:confirm_label('Create')
        a:cancel_label('Go Back')
    end)
    if not ok then return end

    TriggerServerEvent('character:create', values[1], values[2])
end)
```

---

## Notes

- The modal blocks the stack — no other menu can open while it is visible.
- Pressing **Escape** is equivalent to clicking the cancel button.
- The `cb` on `a:cancel()` is optional — omitting it simply closes the dialog.
- Modal alignment (center / top-center / bottom-center) is a User Setting (F12 panel).
