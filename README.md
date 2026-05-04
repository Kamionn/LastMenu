# LastMenu

**Universal standalone menu system for FiveM.**  
One API. All menu types. Real-time reactivity.

> **Zero runtime dependencies** — works without `ox_lib`, `qbx_core`, or any other framework.  
> The Svelte 5 UI is pre-compiled in `ui/assets/` — no `npm install` required to run the server.

**Current version: [1.0.1](CHANGELOG.md)**

---

## Installation

1. Copy the `LastMenu` folder into your server's `resources/` directory.
2. In `server.cfg`, **before** any resource that depends on it:

```
ensure LastMenu
```

3. In the `fxmanifest.lua` of each client resource:

```lua
client_scripts { '@LastMenu/client/exports.lua' }
```

---

## Quick start

```lua
local UI = exports['LastMenu']

-- Context menu
UI:context(function(menu)
    menu:title("My menu")
    menu:button("Say hello", { icon = "hand", cb = function() print("Hello!") end })
end)

-- Notification
UI:notify(function(n)
    n:message("Action successful.")
    n:type("success")
end)

-- Blocking input (inside a Citizen.CreateThread)
local values = UI:input_async(function(b)
    b:title("Purchase")
    b:field("Quantity", { type = "number", min = 1, max = 10 })
end)
```

---

## Documentation

| Topic | File |
|---|---|
| Context menu (items, tabs, accordions, submenus, reactivity) | [docs/context-menu.md](docs/context-menu.md) |
| Radial menu | [docs/radial.md](docs/radial.md) |
| Input form | [docs/input.md](docs/input.md) |
| Alert / confirmation | [docs/modal.md](docs/modal.md) |
| Toast notifications | [docs/notify.md](docs/notify.md) |
| Progress bar | [docs/progress.md](docs/progress.md) |
| Target system | [docs/target.md](docs/target.md) |
| Migration from ox_lib / RageUI / qb-menu | [docs/migration.md](docs/migration.md) |
| Theming (CSS custom properties) | [docs/theming.md](docs/theming.md) |
| Internal architecture | [docs/architecture.md](docs/architecture.md) |
| Changelog | [CHANGELOG.md](CHANGELOG.md) |

---

## What LastMenu solves

| Common problem | Solution |
|---|---|
| Dependency on `ox_lib` or a framework | Zero runtime dependencies |
| Different API per menu type | One pattern for everything |
| No reactivity — close/reopen to refresh | Built-in reactive polling engine |
| Locked to a framework (ESX / QBCore) | Works in any environment |
| Buggy watchers crash the whole menu | Safe Mode automatically disables faulty watchers |
| Back button returns to the wrong level | Navigation stack preserves full depth |

---

## Quick theming

```css
/* ui/theme/default.css — override variables to customize */
:root {
    --ui-accent:        #e94560;
    --ui-ctx-width:     320px;
    --ui-font-scale:    1;
}
```

---

## Building the UI

The UI is pre-compiled. To modify the Svelte components:

```bash
cd ui
npm install       # once
npm run build     # outputs to ui/assets/
```

---

## License

[MIT](LICENSE) — Kamion
