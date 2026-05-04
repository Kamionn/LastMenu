# Input Form

Multi-field form modal. Values are collected on confirm — no real-time reactivity inside the form.

---

## One-shot

```lua
exports.LastMenu:input(function(form)
    form:title('Create Character')    -- optional header
    form:field('First Name', { default = 'John' })
    form:field('Age', {
        type = 'number',
        min  = 18,
        max  = 99,
    })
    form:confirm('Submit', function(values)
        print('Name:', values[1], 'Age:', values[2])
    end)
    form:cancel('Cancel')
end)
```

## Reusable handle

```lua
local loginForm = exports.LastMenu:input_build(function(form)
    form:title('Login')
    form:field('Username', { maxlen = 24 })
    form:field('Password', { type = 'password' })
    form:confirm('Sign In', function(v) login(v[1], v[2]) end)
    form:cancel('Cancel')
end)

-- Later:
loginForm.open()
loginForm.close()
```

Fields are reset to their `default` values on each `open()`.

---

## Builder methods

| Method | Args | Description |
|---|---|---|
| `form:title(str)` | `string` | Optional header shown above the fields |
| `form:field(label, opts)` | `string, table` | Add an input field |
| `form:confirm(label, cb)` | `string, function(values)` | Primary button — `values` is a 1-based array |
| `form:cancel(label, cb?)` | `string, function?` | Secondary button — callback is optional |

---

## Field options

| Option | Type | Default | Description |
|---|---|---|---|
| `type` | `string` | `'text'` | HTML input type: `'text'` `'number'` `'password'` `'email'` |
| `default` | `string\|number` | `""` | Pre-filled value shown when the form opens |
| `placeholder` | `string` | `nil` | Ghost text shown when the field is empty |
| `maxlen` | `number` | `nil` | `maxlength` attribute (text fields) |
| `min` | `number` | `nil` | Minimum value (number fields) |
| `max` | `number` | `nil` | Maximum value (number fields) |
| `pattern` | `string` | `nil` | JavaScript regex — validated on confirm |
| `pattern_error` | `string` | `'Invalid format'` | Error message shown when pattern fails |

> **Lua string note:** Use `\\d`, `\\.`, `\\s` etc. in Lua strings to produce `\d`, `\.`, `\s` in the JavaScript regex (`\\` in Lua → `\` in the string → interpreted as regex escape by JS).

---

## Validation

Fields are validated on confirm before firing the callback. If any field fails, an inline error message is shown and the callback is **not** called.

Built-in validation:
- `type = 'number'` — must be a valid number; `min` / `max` enforced
- `pattern` — regex applied via `new RegExp(pattern).test(value)`

```lua
-- License plate format: AA-123-BB
form:field('License Plate', {
    maxlen        = 9,
    pattern       = '^[A-Z]{2}-\\d{3}-[A-Z]{2}$',
    pattern_error = 'Expected format: AB-123-CD',
})

-- Basic email check
form:field('Email', {
    type          = 'email',
    pattern       = '^[^@]+@[^@]+\\.[^@]+$',
    pattern_error = 'Invalid email address.',
})
```

---

## Async variant

`UI_InputAsync` blocks the current coroutine and returns the values array or `nil` (cancelled / Escape). Must be called from inside a `Citizen.CreateThread`.

```lua
Citizen.CreateThread(function()
    local values = exports.LastMenu:input_async(function(b)
        b:title('Bank Transfer')
        b:field('Recipient', { type = 'text',   placeholder = 'Player name', maxlen = 20 })
        b:field('Amount',    { type = 'number', min = 1, max = 100000, default = 100 })
        b:field('Note',      { type = 'text',   placeholder = 'Optional…',   maxlen = 60 })
        b:confirm_label('Send')      -- async-only method
        b:cancel_label('Cancel')
    end)

    if not values then return end   -- user cancelled

    local recipient = values[1]     -- string
    local amount    = values[2]     -- number (auto-cast because type = 'number')
    local note      = values[3] or ''

    TriggerServerEvent('bank:transfer', recipient, amount, note)
end)
```

### `UI_InputAsync` builder methods

| Method | Description |
|---|---|
| `b:title(str)` | Optional header |
| `b:field(label, opts)` | Add a field (same options as above) |
| `b:confirm_label(str)` | Label for the confirm button (default: `'Confirm'`) |
| `b:cancel_label(str)` | Label for the cancel button (default: `'Cancel'`) |

> `confirm_label` / `cancel_label` are **only** available in the async variant. In the regular `input` and `input_build`, use `form:confirm(label, cb)` and `form:cancel(label)`.

---

## Return values

The `confirm` callback (and `input_async` return) is a **1-based array** of field values:

- `type = 'number'` fields → Lua `number` (or the raw string if `tonumber()` fails)
- All other types → Lua `string`

```lua
form:confirm('OK', function(values)
    local name   = values[1]   -- string
    local age    = values[2]   -- number
    local note   = values[3]   -- string
end)
```

---

## Keyboard navigation

| Key | Action |
|---|---|
| `Tab` / `Enter` | Move to the next field |
| `Enter` on last field | Trigger confirm |
| `Escape` | Trigger cancel (if defined) |

---

## Notes

- The modal blocks the menu stack while open.
- Pressing `Escape` fires the cancel callback if one is defined, otherwise closes silently.
- Fields are always reset to their `default` value when the form opens — the user cannot carry over values from a previous session.
