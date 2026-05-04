# Changelog

All notable changes to LastMenu will be documented in this file.

---

## [1.0.0] — 2026-05-04

### Added

**Core**
- Universal menu API: one consistent pattern across all menu types
- Reactive polling engine with automatic diff/patch — menus update live without close/reopen
- Safe Mode: automatically disables faulty watchers to prevent full menu crashes
- Navigation stack with full depth preservation — back button always returns to the correct level
- Cursor management tied to the navigation stack
- Global Escape key handler

**Menu types**
- Context menu — items, tabs, accordions, submenus, reactive watchers
- Radial menu — sector-based wheel with keyboard navigation and hold-to-confirm support
- Input form — text, number, email fields with debounced validation, pattern matching, min/max
- Alert / confirmation modal — confirm and cancel callbacks, keyboard shortcuts (Enter / Escape / Backspace)
- Toast notifications — typed toasts (success / error / warning / info), auto-dismiss timer bar, group deduplication, dismiss callback
- Progress bar — animated fill, cancelable with Escape, completion callback
- Target system — zone registration API, geometry engine, raycast detection, polling thread, debug draw

**UI & theming**
- Svelte 5 UI, pre-compiled — no `npm install` required to run the resource
- CSS custom properties for full theming (`--ui-accent`, `--ui-ctx-width`, `--ui-font-scale`, …)
- Settings panel (F12) — accent color, font scale, high contrast, reduced motion, language, reticle position
- Localization: English, French, Spanish, German, Portuguese, Italian, Russian, Polish

**Infrastructure**
- Zero runtime dependencies — no `ox_lib`, `qbx_core`, or framework required
- `EasySwitchLua` structural dispatch library bundled
- Server-side version check
- Public `exports.lua` for external resources
- Fully typed public API (`types/`)

[1.0.0]: https://github.com/Kamionn/LastMenu/releases/tag/v1.0.0
