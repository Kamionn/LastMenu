# Changelog

All notable changes to LastMenu are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).  
Version scheme: `MAJOR.MINOR.PATCH` — breaking changes bump MAJOR.

---

## [1.0.1] — 2026-05-04

### Performance

- **Removed redundant `Reactive.evaluate` after `Reactive.attach`** in context and radial builders. `attach` already initialises `nextAt = 0` on all watchers; the subsequent `evaluate` call was iterating the full watcher list a second time for no effect. Eliminates one full watcher loop on every menu open (`context`, `context_build`, `context_update`, `radial`, `radial_build`).
- **`_stableId` fast path** — labels containing only alphanumeric characters and spaces (the vast majority of real labels) now execute a single `gsub` instead of five chained passes, reducing temporary string allocations by ~80 % per item during menu build.
- **`isCallable` hoisted to module level** in `core.lua`. Previously re-created as a closure on each `_makeResolver` call (once per menu build); now a shared module-level function with zero per-build allocation cost.

### Fixed

- **Watcher thread crash on un-encodable table** — `json.encode(value)` inside `Reactive._processWatcher` was not protected by `pcall`. A watcher returning a table that cannot be JSON-encoded (circular reference, unserializable userdata, etc.) would throw an unhandled error that propagated out of the tick loop and killed the entire reactive thread, stopping all watchers for that menu permanently. The encode call is now wrapped in `pcall`; failures are treated as watcher errors and enter the existing backoff/DEAD cycle, isolating the fault to the offending field only.
- **Tick loop safety net** — each `_processWatcher` call in `Reactive.startTicking` is now individually guarded by an outer `pcall`. Any unhandled error path in future watcher logic will be caught and logged per-watcher rather than crashing the thread.

---

## [1.0.0] — 2026-05-03

First public release of LastMenu.

### Architecture

- Global namespace `LastMenu` created in `config.lua`, locked via `__newindex` after load (`exports.lua`) — any external write raises an error
- Strict load order: `config → bridge → stack → reactive → core → builders → exports → settings`
- Bridge layer with automatic NUI batching (`Citizen.SetTimeout(0)`) — single message sent directly, multiple messages grouped into a `batch`; payload > 1 MB guard
- Stack engine: navigation pile with NUI focus management per mode (`both` / `mouse` / `keyboard`), Map key suppression (199/200), configurable distance-based auto-close
- Reactive engine: adaptive polling with exponential backoff (`×1.5`, max `×8`), table change detection via `json.encode`, ±10% jitter on all retry delays, automatic recovery after errors (`MAX_ERRORS = 5`, `RETRY_DELAY_MS = 30 000`)
- Events: `LastMenu:menuOpened(id, type)` / `LastMenu:menuClosed(id, type)`
- Automatic cleanup on `onResourceStop`: NUI focus released, stack cleared, dismiss callbacks purged

### Builders

#### Context Menu
- Full fluent builder: `title`, `banner`, `description`, `nav`, `animation`, `search`, `page_size`, `cancelable`, `scroll`
- Items: `button`, `slider`, `stepper`, `checkbox`, `toggle`, `list`, `stat`, `input_inline`, `color_picker`, `date_picker`, `separator`, `header`, `accordion`, `tab`, `submenu`, `back`
- Reactive fields per item: `label`, `visible`, `disabled`, `color`, `badge`, `preview` (button); `value`, `max`, `color` (stat)
- `opts.confirm_hold` — per-item hold-to-confirm (ms or `true` for global value)
- `opts.cooldown` + `opts.persist_key` — inter-click cooldown with KVP persistence (survives NUI reload)
- `opts.preview` — hover preview card `{ image, title, desc, stats[] }` on buttons
- `opts.timeout` — auto-click after delay
- Stable slugified IDs (`_stableId`) with automatic deduplication (`_2`, `_3`) for conditional items
- `UI_Context(fn)` — immediate open
- `UI_Context_Build(fn)` → handle (`open`, `close`, `update`) — persistent reloadable menu, double-open guard
- `UI_Context_Update(handle, fn)` — alias for update
- O(m) NUI patch via `liveOverrides` — only modified fields are updated, no full list recompute

#### Alert
- Builder: `title`, `message`, `type` (`info` / `confirm` / `warn` / `error`), `confirm(label, cb)`, `cancel(label, cb)`
- `UI_Alert(fn)` — standard open
- `UI_Alert_Build(fn)` → handle
- `UI_AlertAsync(fn)` → `bool` — blocking coroutine, returns `true` (confirm) or `false` (cancel / Escape)

#### Input
- Builder: `title`, `field(label, opts)` — `type='text'|'number'`, `default`, `placeholder`, `maxlen`, `min`, `max`, `pattern`, `pattern_error`
- `confirm(label, cb)` — `cb(values[])`, `cancel(label, cb)`
- `UI_Input(fn)` — standard open
- `UI_Input_Build(fn)` → handle
- `UI_InputAsync(fn)` → `values[]|false` — blocking coroutine

#### Notify
- Builder: `message`, `type` (`info` / `success` / `warn` / `error`), `duration`, `persistent` (duration=0), `icon`, `title`, `group`, `on_dismiss(cb)`
- `group` — deduplication: replaces the active toast with the same group key
- `on_dismiss` — callback on × click (persistent only), purged on `notify_expired` and `onResourceStop`
- Direct Bridge send, no Stack push

#### Progress
- Builder: `label`, `duration`, `anim(dict, clip, flag?)`, `prop(model, bone, pos, rot?)`, `cancelable`
- Deduplication: only one active bar at a time (`_openProgressInstance`)
- `UI_Progress(fn)` — standard open
- `UI_Progress_Build(fn)` → handle

#### Radial
- Builder: `center_label`, `button(label, opts)` — `icon`, `visible (fn)`, `disabled (fn)`, `refresh`, `confirm_hold`, `keep_open`, `submenu(fn)` (pushes nested radial)
- Gamepad thread: reads left stick → NUI messages when radial is active (magnitude > 0)
- `UI_Radial(fn)` — standard open
- `UI_Radial_Build(fn)` → handle

#### Target System
- `UI_Target_AddEntity(entity, fn)`
- `UI_Target_AddModel(model_hash, fn)`
- `UI_Target_AddSphere(coords, radius, fn)`
- `UI_Target_AddBox(coords, size, fn)`
- `UI_Target_AddPoly(vertices[], fn)`
- `UI_Target_Update(target_id, fn)` / `UI_Target_Remove(target_id)` / `UI_Target_Clear()`
- Zone builder: `label`, `icon`, `distance`, `banner`, `on_enter(fn)`, `on_leave(fn)`
- Items: `button`, `toggle`, `checkbox`, `slider`, `separator`, `group(label, opts, fn)`
- Adaptive raycast with `target_max_distance` and configurable hold key (`target_hold_key`, default Left Ctrl)
- Debug zone drawing with `Config.debugTarget = true`

### KVP Cooldown System

- Key format: `lm_cd_<resName>_<key>` — capped at 1 year, survives NUI reload and reconnect
- NUI → Lua via `cooldown:set` / `cooldown:clear` callbacks
- Validation: key ≤ 64 chars, pattern `^[%w%-_]+$`

### Settings Panel (F12)

- Command `lastmenu_settings` (F12 keybind by default via `RegisterKeyMapping`)
- Preferences: navigation mode (`both` / `mouse` / `keyboard`), target key
- localStorage persistence → restored on `Bridge.onReady` at NUI startup
- Exports: `settings_open()`, `settings_close()`

### NUI / Svelte

- Svelte 5 Runes app — NUI stack mirroring the Lua stack
- Menus: `context`, `alert`, `input`, `notify`, `progress`, `radial`, `target`
- Incoming messages: `open`, `close`, `patch`, `batch`, `reset`, `settings`, `cooldown:set`
- Enter/exit animations (200 ms exit before remove)
- Theming: `default.css` with 50+ CSS variables; preset themes (Military, Luxury, Neon/Cyberpunk)
- Dynamic Lucide icons

### Public Exports

```
context, context_build, context_update
alert, alert_build, alert_async
notify
progress, progress_build
radial, radial_build
input, input_build, input_async
target_add_entity, target_add_model, target_add_sphere, target_add_box, target_add_poly
target_update, target_remove, target_clear
lastmenu_back, debug_stats, version
settings_open, settings_close
```

### Dev Commands

- `/lm_test` (ACE `lastmenu.dev`) — runs the test/showcase suite
- `/lm_debug` (ACE `lastmenu.dev`) — JSON snapshot of the Reactive watcher state

---

[1.0.0]: https://github.com/Kamionn/LastMenu/releases/tag/v1.0.0
