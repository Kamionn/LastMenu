# LastMenu — Internal Architecture

Onboarding guide. Read this before touching the code.

---

## System layers

```
┌──────────────────────────────────────────────────────┐
│  Client resource (your script)                       │
│  exports.LastMenu:context(fn) / :notify(fn) / …     │
└────────────────────────┬─────────────────────────────┘
                         │ calls builders
┌────────────────────────▼─────────────────────────────┐
│  client/exports.lua — public exports                 │
│  client/builders/*.lua — payload constructors        │
└────────────────────────┬─────────────────────────────┘
                         │ sends payload via Bridge
┌────────────────────────▼─────────────────────────────┐
│  client/bridge.lua — bidirectional NUI layer         │
│  Batching: merges rapid messages into one            │
└────────────────────────┬─────────────────────────────┘
                         │ postMessage / NUI callback
┌────────────────────────▼─────────────────────────────┐
│  ui/src/App.svelte — Svelte 5 orchestrator           │
│  Menu stack ($state), dispatch by type               │
└────────────────────────┬─────────────────────────────┘
                         │ props
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
    Context.svelte   Radial.svelte   Input.svelte …
```

**Rule:** each layer depends only on layers below it.  
The two intentional exceptions are documented in the [Dependencies](#intentional-dependencies) section.

---

## Lua files — load order

| # | File | Role |
|---|---|---|
| 1 | `config.lua` | Debug flag, global tunables |
| 2 | `bridge.lua` | NUI layer — send/receive, `onClose` hook |
| 3 | `stack.lua` | Navigation stack + NUI focus + wires `Bridge.onClose` |
| 4 | `reactive.lua` | Polling diff/patch engine, registers into `Stack._reactive` |
| 5 | `core.lua` | `GenerateMenuId()`, `_stableId()`, gamepad B handler |
| 6 | `builders/*.lua` | One builder per menu type |
| 7 | `exports.lua` | Public API exposed to third-party resources |
| 8 | `settings.lua` | F12 panel — always available, independent of the stack |

Order is declared in `fxmanifest.lua` and must be respected.

---

## Lua modules — detailed description

### `bridge.lua`

Responsibilities:
- `Bridge.send(type, payload)` — enqueues a NUI message, flushes as a batch on the next tick
- `Bridge.onCallback(cb_id, fn, menu_id)` — registers a NUI callback scoped to a menu
- `Bridge.removeCallbacks(menu_id)` — purges all callbacks for a menu (called by Stack.pop)
- `Bridge.onClose` — **hook** wired by `stack.lua`; called on `escape` and `__cancel__` NUI events

**No direct reference to Stack.** The `escape` and `__cancel__` NUI callbacks only call `Bridge.onClose` — if it is nil, nothing happens. Stack wires the hook itself after loading.

### `stack.lua`

Responsibilities:
- Maintains `Stack._entries[]` — active menu stack
- `Stack.push(entry)` — acquires NUI focus on first push, pauses reactive for the previous top
- `Stack.pop()` — releases focus on last pop, sends `close` via Bridge, stops Reactive
- `Stack.peek()` — top entry without popping
- `Stack.clear()` — pops everything (used on `onResourceStop`)
- Disables GTA5 map controls while the stack is non-empty
- Auto-closes when the player walks away (`Config.close_on_distance`)
- **Wires `Bridge.onClose`** at the end of the file (after `rawset`)

**Depends on Bridge** (Stack.pop calls `Bridge.send` and `Bridge.removeCallbacks`) — intentional dependency.

### `reactive.lua`

Responsibilities:
- `Reactive.attach(menu_id, watchers)` — registers watchers for a menu
- `Reactive.startTicking(menu_id)` — Citizen thread: polls at an adaptive interval
- `Reactive._processWatcher(w, now, batch)` — **pure, testable function**: evaluates one watcher, accumulates changes
- `Reactive.pause/resume` — called by Stack on push/pop to avoid patches on hidden menus
- `Reactive.stopTicking` — called via `Stack._reactive` inside Stack.pop

**Adaptive backoff**: a stable watcher is polled less and less frequently (up to `interval × 8`). An error triggers exponential backoff, then disables the watcher after 5 consecutive errors (auto-retry after 30 s).

---

## Intentional dependencies

| Dependency | Direction | Rationale |
|---|---|---|
| Stack → Bridge | ↑ | Stack.pop must send `close` to the NUI. Unavoidable. |
| Reactive → Bridge | ↑ | Patches are sent via `Bridge.send`. |
| `Bridge.onClose` ← Stack | ↓ hook | Bridge does not reference Stack. Stack wires the hook after loading, eliminating the Bridge→Stack circular dependency. |
| `Stack._reactive` ← Reactive | ↓ hook | Stack does not reference Reactive. Reactive registers itself via `rawset`. |

---

## NUI event flow

### Opening a menu

```
UI_Context(fn)                    ← your script
  └─ builders/context.lua
       └─ Bridge.send('open', payload)   ← batched
            └─ SendNUIMessage({ type='batch', … })
                 └─ App.svelte handleMessage()
                      └─ stack = [...stack, entry]
                           └─ <Context data={entry.data} />
```

### Button click

```
[click in the UI]
  └─ Context.svelte onCallback(cb_id, extra)
       └─ fetch POST https://LastMenu/callback
            └─ bridge.lua RegisterNUICallback('callback')
                 └─ Bridge._callbacks[cb_id](data)
                      └─ [your Lua callback]
```

### Close (Escape / B button / __cancel__)

```
[keyboard Escape or gamepad B or × click]
  └─ two possible paths:

  A. App.svelte handleKeydown → fetch POST /escape
       └─ bridge.lua 'escape' callback
            └─ Bridge.onClose()

  B. Context.svelte sendCallback('__cancel__')
       └─ bridge.lua 'callback' cb_id == '__cancel__'
            └─ Bridge.onClose()

  └─ (in both cases)
  └─ stack.lua Bridge.onClose = function()
       local top = Stack.peek()
       if top and top.cancelable ~= false then Stack.pop() end
     end
       └─ Stack.pop()
            └─ Bridge.send('close', { id })
                 └─ App.svelte : marking closing=true → CSS exit animation (~180ms) → filtered
```

### Reactive patch (Lua → NUI)

```
[Reactive tick]
  └─ Reactive._processWatcher(w, now)
       → pcall(w.fn) → compare with w.last
       → if changed: batch[#batch+1] = { id, field, value }

  └─ Bridge.send('patch', { id, changes = batch })
       └─ App.svelte (non-context menus): stack.map items remap
          Context.svelte (context menus): onPatch() → liveOverrides[id] = change
            → Svelte 5 fine-grained: only changed items re-render
```

---

## NUI architecture (Svelte)

```
App.svelte
├── utils/theme.ts                   (loadSettings + applyTheme — no component)
├── Notify.svelte                    (toasts — outside NUI stack, persistent)
├── Context.svelte ×N                (one per stack entry, active or not)
│   ├── ContextItemList.svelte         (virtual scroll item list)
│   ├── ContextContent.svelte          (item renderers)
│   ├── ContextTabs.svelte             (tab bar + scroll into view)
│   └── ContextSearch.svelte           (search bar + onEscape)
├── Alert.svelte                     (top menu only)
├── Progress.svelte                  (top menu only)
├── Radial.svelte                    (top menu only)
├── Input.svelte                     (top menu only)
├── Target.svelte                    (top menu only)
└── UserSettings.svelte              (F12 overlay, outside stack)
```

**Why Context is persistent but others are not:**  
Context keeps its components alive (`{#each stack}`) to prevent banner GIFs from restarting when opening/closing submenus. Other types don't have this requirement — only `topMenu` is rendered.

### Two-phase close (closing animation)

```
Bridge.send('close', { id })
  └─ App.svelte : stack entry → { ...m, closing: true }
       └─ component receives closing=true → CSS out animation (~180ms)
  └─ setTimeout(200ms)
       └─ stack = stack.filter(m => m.id !== id)
```

---

## Menu lifecycle — condensed view

```
push → [open NUI] → [active] → [user interacts] → [callbacks]
                                                         │
                                          ┌──────────────┘
                                          ▼
                                    Stack.pop()
                                      │
                                      ├─ Bridge.send('close')    → NUI animation
                                      ├─ Bridge.removeCallbacks  → memory cleanup
                                      └─ Reactive.stopTicking    → stop poll thread
```

---

## Main CSS variables

Defined in `ui/theme/default.css`. See `docs/theming.md` for the full list.

| Variable | Effect | Configured via |
|---|---|---|
| `--ui-accent` | Primary color | Settings → accentColor |
| `--ui-ctx-bg` | Menu background (rgba) | Settings → menuOpacity |
| `--ui-ctx-width` | Menu width | Settings → menuWidth |
| `--ui-ctx-item-height` | Item height | Settings → compactMode |
| `--ui-blur` | backdrop-filter | Settings → blurEffects |
| `--ui-font-scale` | Font multiplier | Settings → fontSize |
