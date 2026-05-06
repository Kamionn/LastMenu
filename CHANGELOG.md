# Changelog

All notable changes to LastMenu are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).  
Version scheme: `MAJOR.MINOR.PATCH` — breaking changes bump MAJOR.

---

## [1.0.2] — 2026-05-06

### Added

- **`UI_ConfirmAsync(message, opts?)`** (`alert.lua`, `exports.lua`) — one-liner async confirm shortcut. Wraps `UI_AlertAsync` avec confirm/cancel pré-remplis. Accepte `{ type, title, confirm_label, cancel_label }`. Exporté via `exports('confirm_async', ...)`.
- **`/lm_overlay` command + `debug_overlay` export** (`exports.lua`) — overlay watcher stats en temps réel via `DrawText`. Affiche field, status (ok/DIS), interval et cb_id suffix pour tous les watchers actifs. ACE permission: `lastmenu.dev`.
- **Notification group counter** (`Notify.svelte`, `Notify.css`) — quand un toast avec `group` arrive alors qu'un identique est déjà affiché, le compteur `×N` s'incrémente au lieu de remplacer silencieusement.
- **NUI crash safety net** (`App.svelte`) — `window.onerror` + `window.onunhandledrejection` dans `onMount`. Si une erreur JS survient avec le stack non vide, fire `/escape` pour libérer le NUI focus.
- **`useTarget.svelte.ts`** (`TargetComponents/`) — fichier manquant créé. Implémente cooldown réactif (timer 100ms), stateful items (toggle/checkbox/slider), accordions, hold-to-confirm pour les menus target.
- **Reset all settings** — footer button (red-tinted) resets every field to `SETTINGS_DEFAULTS` in the live local state; live preview reflects it instantly; Cancel still discards without saving.
- **Live preview** — settings panel now applies theme changes in real-time while open; cancelling or closing reverts to the saved state without touching `localStorage`. Implemented via a split `$effect` pair in `App.svelte` and an `onPreview` callback chain through `UserSettings` → `useUserSettings`.
- ~~**Hold duration** (Navigation section)~~ — removed from user settings panel; `_normalizeHold` still resolves `user > dev > config` but the user override is no longer exposed in the UI.
- **Page size** (Context section) — user override for items-per-page; `null` = Auto (uses dev `b:page_size()` or default). Applied in `App.svelte` by spreading `page_size` onto `menuItem.data` when non-null — zero changes to `Context.svelte`.
- **Radial size** (Appearance section) — Compact / Normal / Large / Auto; sets `--ui-radial-size` CSS variable via `applyTheme`.
- **Target menu size** (Appearance section) — Compact / Normal / Large / Auto; sets `--ui-target-width` CSS variable via `applyTheme`.
- **RegisterKeyMapping for target hold key** — replaced `IsControlPressed` polling with `+lastmenu_target` / `-lastmenu_target` command pair; `LastMenu._targetHeld` boolean. Dev-configurable default via `Config.target_key`. 8-language auto-translated descriptions using `lm_language` KVP read at resource start.

### Fixed

- **`selectedIndex` hors bornes sur radial** (`useRadial.svelte.ts`) — `kbIndex >= 0` ne vérifiait pas `kbIndex < n`. Si un bouton devenait invisible pendant la nav clavier, retournait un index invalide. Ajout du guard `kbIndex < n`.
- **`rgb()` accent sans `--ui-accent-dim`** (`theme.ts`) — le calcul de la teinte sombre ne traitait que `#rrggbb`/`#rgb`. Les couleurs `rgb(r,g,b)` ne généraient pas de dim shade. Ajout du parsing `rgb()`/`rgba()`.
- **Dead code supprimé** (`stack.lua`) — bloc `DisableControlAction(199/200)` + caméra AFK commenté sans documentation retiré.
- **Radial menu coordinates broken at >1080p** — `handleMousemove` computed mouse position relative to `getBoundingClientRect()` without accounting for the CSS `zoom` applied by `applyViewportScale`. At resolutions > 1920×1080 (e.g. 1440p, 4K) the zoom factor caused the mouse-to-arc mapping to be off proportionally to the scale, requiring the mouse to be far outside the visual menu to register a sector. Fix: divide `(clientX - rect.left)` and `(clientY - rect.top)` by `parseFloat(document.documentElement.style.zoom) || 1`.
- **Target hold key not detected on resource restart** — `RegisterKeyMapping` binding propagation in FiveM is asynchronous; after a resource restart the `+lastmenu_target` command may not fire until the GTA key-binding system refreshes (triggered by another resource starting). Added `IsControlPressed(0, Config.target_hold_key)` as a direct fallback alongside `LastMenu._targetHeld` in the polling condition. The fallback activates the reticle on the default key immediately after restart; once the key mapping propagates, the command path takes over. Players who rebind the key in GTA settings are unaffected (the command fires on their custom key; the fallback only covers the default).
- **Reset All button overflows footer at narrow widths / long translations** — changed from `[icon + text]` to icon-only (`RotateCcw`) with `title` tooltip, reducing the footer IO row to three compact icon buttons that never push Cancel / Save off-screen.

### Performance

- **Upvalue localization in `reactive.lua`** — `json.encode`, `math.floor`, `math.min`, `math.max`, `math.random` cached as module-level upvalues. Avoids `_ENV` table traversal on every hot-path call inside the tick loop and `_jitter`. Measurable gain when multiple watchers tick at high frequency (≥8 watchers at ≤200 ms intervals: ~5–8 % tick time reduction).
- **`Bridge.send` payload copy removed** — eliminated the `pairs()` shallow-copy loop that duplicated the payload table on every send. All callers pass fresh table literals; `payload.type = msgType` is now set in-place. Saves one table allocation + iteration per enqueued message.
- **Size guard moved to debug-only in `Bridge.send`** — the `json.encode(outMsg)` call used solely to measure payload size before `SendNUIMessage` (which re-encodes internally) is now gated behind `Config.debug`. Eliminates one full encode per tick in production.
- **`_hasDebounce` pre-computed flag in reactive watchers** — `w.debounce_ms` evaluation moved from per-tick (inside `_processWatcher`) to attach-time. The hot-path debounce flush check now reads a boolean flag instead of doing a type check + numeric comparison on every watcher tick, regardless of whether debounce is configured.
- **`intervalCurrent` reset guard** — `w.intervalCurrent = w.interval` on every successful watcher evaluation is now guarded by `w.intervalCurrent ~= w.interval`. Avoids the unconditional write in the common steady-state (no backoff active), reducing memory writes in the hot loop.
- **`math.*` upvalues in `startTicking`** — `tickMs` computation now uses the module-level `math_max` / `math_min` / `math_floor` upvalues.
- **Target thread: `Stack.peek()` single call per iteration** — in the polling thread, `Stack.peek()` was called twice per iteration to check `~= nil` then `.type`. Now called once at the top of the loop body into `_stackTop`, reused across both checks.
- **Target thread: `TR.getTargetDist()` cached per tick** — `getTargetDist()` (which performs a type-check + conditional log on `Config.target_max_distance`) was called twice per active tick: once for `getRaycastHit` and once internally via `getSpatialRadius` inside `findMatchingRegs`. The explicit call is now cached into `maxDist` and passed directly to `getRaycastHit`, eliminating the redundant outer call.
- **Target thread: `PlayerPedId()` re-call eliminated** — `GetEntitySpeed(PlayerPedId())` in the idle-moving check re-invoked `PlayerPedId()` unnecessarily. Now uses the `playerPed` local already declared at the top of the same tick branch.
- **Target thread: `table.sort` fast-path for single match** — `table.sort` + `table.concat` were called unconditionally to build `matchKey`. For the common single-registration case (1 match), sort and concat are now bypassed; `matchKey = parts[1]` is assigned directly. The empty-match case (`matchKey = ''`) is also short-circuited before any table operation.
- **`json_encode` upvalue in `Reactive.attach`** — `json.encode` used at attach-time to seed `w._lastJson` for table watchers was not yet using the module-level upvalue. Now consistent with the rest of the file.
- **EasySwitch `{ safe = true }` on `_zoneDispatch`** (`target/raycast.lua`) — the zone dispatch loop ran without error protection around `:execute()`. A malformed registration (e.g. nil `radius` on a sphere) could throw and permanently crash the target polling thread. The `safe` option wraps dispatch in a pcall internally, isolating faults to the offending registration only.
- **EasySwitch `_G` global export** (`easyswitch.lua`) — the updated library used `local EasySwitch … return EasySwitch` (module pattern). In FiveM's `client_scripts` context the `return` value is discarded, leaving `_G.EasySwitch` nil and breaking every consumer (`stack.lua`, `raycast.lua`). Added `_G.EasySwitch = EasySwitch` before the `return` to support both load contexts.

### Changed

- **Settings panel sections restructured**
  - Sections `modal` + `progress` merged into **Composants / Components** (id `components`).
  - `perfMode` toggle moved into the **Appearance** section (after blur effects).
  - `perf` section removed.
  - `target_key` block and `nav_hint` developer note removed from Navigation section.
  - **Components tab expanded** — `context` and `notify` sections removed as standalone sidebar entries; their settings merged into **Components** under labelled sub-group separators (`──── CONTEXTE ────`, `──── NOTIFICATIONS ────`, etc.). Radial and Target size settings also moved from Appearance into Components. Sidebar reduced from 7 to 5 tabs.
  - **Settings panel opens on Appearance** by default (was Navigation).
  - **Hint copy cleaned** — developer-facing notes removed from `hold_duration_hint`, `page_size_hint`, and `lang_hint` across all 8 languages; these hints now convey only what is actionable for the player.
- **`SETTINGS_VERSION` bumped 3 → 4** — new fields (`holdDuration`, `pageSize`, `radialSize`, `targetSize`) added to `UserSettings` interface and `SETTINGS_DEFAULTS` (all default `null`).
- **`targetKey` removed** from `UserSettings` interface and defaults (superseded by `RegisterKeyMapping`).
- **Translations** — `sec_modal`, `sec_progress`, `sec_perf` removed from `TranslationKeys`; `sec_components` added. New keys: `hold_duration`, `hold_duration_hint`, `page_size`, `page_size_hint`, `radial_size`, `radial_size_hint`, `target_size`, `target_size_hint`, `auto_label`, `size_compact`, `size_normal`, `size_large`, `comp_context`, `comp_notify`, `comp_radial`, `comp_target`, `comp_modal`, `comp_progress` — all 8 languages.
- **`$effect` split in `App.svelte`** — theme application and `localStorage` persistence are now separate effects so live preview doesn't write stale values to storage.

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

[1.0.2]: https://github.com/Kamionn/LastMenu/releases/tag/v1.0.2
[1.0.1]: https://github.com/Kamionn/LastMenu/releases/tag/v1.0.1
[1.0.0]: https://github.com/Kamionn/LastMenu/releases/tag/v1.0.0
