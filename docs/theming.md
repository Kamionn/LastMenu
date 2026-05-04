# LastMenu — Theming

LastMenu uses exclusively **CSS custom properties** for theming. No values are hard-coded in components.

---

## How to customize

1. Create a CSS file (e.g. `ui/theme/mytheme.css`).
2. Add it to `fxmanifest.lua` **after** `ui/theme/**`:

```lua
files {
    'ui/index.html',
    'ui/assets/**',
    'ui/theme/**',
    'ui/theme/mytheme.css',   -- your theme, loaded last
}
```

3. Load it in `ui/index.html` after the default link:

```html
<link rel="stylesheet" href="./theme/default.css">
<link rel="stylesheet" href="./theme/mytheme.css">
```

4. In `mytheme.css`, override only the variables you need:

```css
:root {
    --ui-accent:     #00ffcc;
    --ui-ctx-bg:     rgba(5, 5, 10, 0.97);
    --ui-ctx-radius: 2px;
}
```

---

## Reference variables

All variables are declared and documented in [ui/theme/default.css](../ui/theme/default.css).

### Global colors

| Variable | Default | Purpose |
|---|---|---|
| `--ui-accent` | `#e94560` | Primary color (active buttons, badges, ON toggles) |
| `--ui-accent-dim` | `#c73652` | Darker variant (hover states) |
| `--ui-accent-text` | `#ffffff` | Text on accent background |
| `--ui-success` | `#4ade80` | Success notifications, high stat bar |
| `--ui-warning` | `#fb923c` | Warning notifications |
| `--ui-error` | `#f87171` | Error notifications, low stat bar |
| `--ui-info` | `#60a5fa` | Info notifications |

### Typography

| Variable | Default | Purpose |
|---|---|---|
| `--ui-font-body` | Inter | Main font |
| `--ui-font-heading` | Rajdhani | Menu titles |
| `--ui-font-scale` | `1` | Global scale multiplier (modified by the F12 panel) |
| `--ui-font-size-base` | `13px × scale` | Base item font size |

### Context menu — layout

| Variable | Default | Purpose |
|---|---|---|
| `--ui-ctx-top` | `72px` | Distance from the top |
| `--ui-ctx-left` | `16px` | Distance from the left |
| `--ui-ctx-width` | `320px` | Panel width |
| `--ui-ctx-item-height` | `40px` | Minimum item height |
| `--ui-ctx-radius` | `8px` | Panel corner radius |

### Context menu — colors

| Variable | Default |
|---|---|
| `--ui-ctx-bg` | `rgba(12, 12, 22, 0.97)` |
| `--ui-ctx-bg-hover` | `rgba(255,255,255,0.08)` |
| `--ui-ctx-text` | `rgba(255,255,255,0.82)` |
| `--ui-ctx-text-dim` | `rgba(255,255,255,0.45)` |
| `--ui-ctx-border` | `rgba(255,255,255,0.07)` |

---

## Ready-to-use theme presets

Three example themes are commented out in `ui/theme/default.css`:

| Theme | Style |
|---|---|
| **Military / Survival** | Dark green, monospace font |
| **Luxury / Light RP** | White background, dark tones |
| **Neon / Cyberpunk** | Electric cyan, very dark background |

Uncomment and copy into your theme file to activate.

---

## Dynamic accent (via User Settings)

Players can set a custom accent color from the Settings panel (F12).
`--ui-accent` and `--ui-accent-dim` are then recalculated dynamically by `App.svelte`.

To disable this feature, remove the `accentColor` field from `loadSettings()` in `ui/src/App.svelte`.

---

## Custom fonts

1. Place font files in `ui/theme/fonts/`.
2. Declare them in your CSS:

```css
@font-face {
    font-family: 'MyFont';
    src: url('./fonts/myfont.woff2') format('woff2');
}

:root {
    --ui-font-body: 'MyFont', sans-serif;
}
```

3. Add to `fxmanifest.lua`:

```lua
files {
    'ui/theme/fonts/**',
}
```
