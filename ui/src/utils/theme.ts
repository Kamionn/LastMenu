/**
 * theme.ts — User settings load/apply, extracted from App.svelte.
 *
 * Central place for:
 *  - UserSettings type definition
 *  - Loading / migrating settings from localStorage
 *  - Applying CSS custom properties to :root
 *  - Input validation (prevents CSS injection through developer-supplied colors)
 */

export interface UserSettings {
    fontSize:       number
    navMode:        'both' | 'mouse' | 'keyboard'
    animation:      string
    notifyX:        'left' | 'right'
    notifyY:        'top' | 'bottom'
    notifyDuration: number
    modalAlign:     'center' | 'top-center' | 'bottom-center'
    progressPos:    'bottom-center' | 'top-center' | 'bottom-left' | 'bottom-right'
    accentColor:    string | null
    menuOpacity:    number
    compactMode:    boolean
    menuWidth:      'compact' | 'default' | 'large'
    uiSounds:       boolean
    reticlePos:     string
    blurEffects:    boolean
    language:       string
    // v3 — accessibility & gameplay
    colorBlind:     'none' | 'deuteranopia' | 'protanopia' | 'tritanopia'
    highContrast:   boolean
    reduceMotion:   boolean
    lineSpacing:    number
    hoverDelay:     number
    perfMode:       boolean
    borderRadius:   number | null
    themePreset:    string
    // v4 — user-priority overrides (null = Auto = defer to dev/config)
    holdDuration:   number | null
    pageSize:       number | null
    radialSize:     'compact' | 'normal' | 'large' | null
    targetSize:     'compact' | 'normal' | 'large' | null
    _v:             number
}

const SETTINGS_VERSION = 4

export const SETTINGS_DEFAULTS: UserSettings = {
    fontSize:       100,
    navMode:        'both',
    animation:      'slideLeft',
    notifyX:        'right',
    notifyY:        'bottom',
    notifyDuration: 4000,
    modalAlign:     'center',
    progressPos:    'bottom-center',
    accentColor:    null,
    menuOpacity:    97,
    compactMode:    false,
    menuWidth:      'default',
    uiSounds:       true,
    reticlePos:     'center',
    blurEffects:    false,
    language:       'en',
    colorBlind:     'none',
    highContrast:   false,
    reduceMotion:   false,
    lineSpacing:    1.2,
    hoverDelay:     0,
    perfMode:       false,
    borderRadius:   null,
    themePreset:    'default',
    holdDuration:   null,
    pageSize:       null,
    radialSize:     null,
    targetSize:     null,
    _v:             SETTINGS_VERSION,
}

// ── Dynamic theme loading from ui/theme/*.css ─────────────────────────────────

const _rawThemes = import.meta.glob<string>('../../theme/*.css', { as: 'raw', eager: true })

function _parseCssRootVars(css: string): Record<string, string> {
    const noComments = css.replace(/\/\*[\s\S]*?\*\//g, '')
    const vars: Record<string, string> = {}
    const rootMatch = noComments.match(/:root\s*\{([\s\S]*?)\}/)
    if (!rootMatch) return vars
    const propRe = /(--[\w-]+)\s*:\s*([\s\S]*?);/g
    let pm: RegExpExecArray | null
    while ((pm = propRe.exec(rootMatch[1])) !== null) {
        vars[pm[1]] = pm[2].replace(/\s+/g, ' ').trim()
    }
    return vars
}

function _bgBase(vars: Record<string, string>): string {
    const bg = vars['--ui-ctx-bg']
    if (!bg) return '12,12,22'
    const m = bg.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/)
    return m ? `${m[1]},${m[2]},${m[3]}` : '12,12,22'
}

// ── Theme presets — JS fallbacks (backwards-compat for saved settings) ────────
// These are NOT shown as preset buttons; only CSS-file-derived themes appear in the UI.

const THEME_PRESETS: Record<string, Record<string, string>> = {
    default: {},
    light: {
        '--ui-ctx-bg':            'rgba(248,248,252,0.97)',
        '--ui-ctx-bg-title':      'rgba(0,0,0,0.03)',
        '--ui-ctx-bg-hover':      'rgba(0,0,0,0.06)',
        '--ui-ctx-bg-active':     'rgba(0,0,0,0.10)',
        '--ui-ctx-bg-focus':      'rgba(0,0,0,0.06)',
        '--ui-ctx-bg-search':     'rgba(0,0,0,0.04)',
        '--ui-ctx-bg-input':      'rgba(0,0,0,0.05)',
        '--ui-ctx-bg-step-btn':   'rgba(0,0,0,0.06)',
        '--ui-ctx-bg-preview':    'rgba(245,245,250,0.99)',
        '--ui-ctx-bg-popover':    'rgba(240,240,248,0.99)',
        '--ui-ctx-bg-pager':      'rgba(0,0,0,0.03)',
        '--ui-ctx-bg-accordion':  'rgba(0,0,0,0.02)',
        '--ui-ctx-border':        'rgba(0,0,0,0.08)',
        '--ui-ctx-border-item':   'rgba(0,0,0,0.12)',
        '--ui-ctx-border-focus':  'rgba(0,0,0,0.22)',
        '--ui-ctx-border-sep':    'rgba(0,0,0,0.06)',
        '--ui-ctx-text':          'rgba(20,20,30,0.90)',
        '--ui-ctx-text-dim':      'rgba(20,20,30,0.55)',
        '--ui-ctx-text-muted':    'rgba(20,20,30,0.35)',
        '--ui-ctx-text-disabled': 'rgba(20,20,30,0.25)',
        '--ui-ctx-text-title':    '#0a0a18',
        '--ui-ctx-icon-color':    'rgba(0,0,0,0.32)',
        '--ui-ctx-shadow':        '0 8px 32px rgba(0,0,0,0.15), 0 0 0 1px rgba(0,0,0,0.06)',
        '--ui-ctx-shadow-preview':'0 6px 20px rgba(0,0,0,0.12)',
        '--ui-toggle-off':        'rgba(0,0,0,0.15)',
        '--ui-radial-bg':         'rgba(248,248,252,0.95)',
        '--ui-scroll-thumb':      'rgba(0,0,0,0.14)',
    },
    neon: {
        '--ui-accent':            '#00ffcc',
        '--ui-accent-dim':        '#00ccaa',
        '--ui-accent-text':       '#000000',
        '--ui-ctx-bg':            'rgba(5,5,10,0.97)',
        '--ui-ctx-bg-hover':      'rgba(0,255,204,0.06)',
        '--ui-ctx-bg-focus':      'rgba(0,255,204,0.06)',
        '--ui-ctx-border':        'rgba(0,255,204,0.15)',
        '--ui-ctx-border-item':   'rgba(0,255,204,0.18)',
        '--ui-ctx-shadow':        '0 0 40px rgba(0,255,204,0.15), 0 20px 60px rgba(0,0,0,0.7)',
        '--ui-ctx-radius':        '2px',
        '--ui-ctx-radius-item':   '1px',
        '--ui-ctx-radius-xs':     '1px',
        '--ui-radial-bg':         'rgba(5,5,10,0.97)',
        '--ui-stat-high':         '#00ffcc',
        '--ui-stat-mid':          '#ffaa00',
        '--ui-stat-low':          '#ff4444',
    },
    minimal: {
        '--ui-ctx-radius':        '3px',
        '--ui-ctx-radius-item':   '2px',
        '--ui-ctx-radius-xs':     '2px',
        '--ui-ctx-shadow':        '0 4px 16px rgba(0,0,0,0.5)',
        '--ui-ctx-bg-hover':      'rgba(255,255,255,0.06)',
        '--ui-ctx-bg-title':      'transparent',
        '--ui-ctx-border':        'rgba(255,255,255,0.05)',
    },
}

const BG_BASES: Record<string, string> = {
    default: '12,12,22',
    light:   '248,248,252',
    neon:    '5,5,10',
    minimal: '12,12,22',
}

// ── Populate from CSS files ───────────────────────────────────────────────────

/** Available themes derived from ui/theme/*.css — used to render preset buttons. */
export const AVAILABLE_THEMES: { id: string; label: string }[] = [
    { id: 'default', label: 'Default' }
]

for (const [path, css] of Object.entries(_rawThemes)) {
    const id = path.split('/').pop()!.replace('.css', '')
    if (id === 'default') continue
    const vars = _parseCssRootVars(css)
    THEME_PRESETS[id] = vars
    BG_BASES[id] = _bgBase(vars)
    AVAILABLE_THEMES.push({ id, label: id.charAt(0).toUpperCase() + id.slice(1) })
}

// Sort: default first, then alphabetically
AVAILABLE_THEMES.sort((a, b) => {
    if (a.id === 'default') return -1
    if (b.id === 'default') return 1
    return a.label.localeCompare(b.label)
})

// ── Load settings ─────────────────────────────────────────────────────────────

export function loadSettings(): UserSettings {
    try {
        const raw: Record<string, unknown> = JSON.parse(localStorage.getItem('lm-settings') || 'null') ?? {}
        const s: UserSettings = (!raw._v || (raw._v as number) < SETTINGS_VERSION)
            ? { ...SETTINGS_DEFAULTS, ...raw, _v: SETTINGS_VERSION }
            : { ...SETTINGS_DEFAULTS, ...raw } as UserSettings
        if (!THEME_PRESETS[s.themePreset]) s.themePreset = 'default'
        return s
    } catch {
        return { ...SETTINGS_DEFAULTS }
    }
}

// ── Validation helpers ─────────────────────────────────────────────────────────

/** Strips anything outside the safe character set for CSS color values. */
function safeCssColor(raw: string | null | undefined): string {
    if (!raw || typeof raw !== 'string') return ''
    return raw.replace(/[^a-zA-Z0-9#(),.\s%+-]/g, '')
}

function clamp(v: number, min: number, max: number): number {
    return Math.min(max, Math.max(min, isNaN(v) ? min : v))
}

// ── applyTheme ─────────────────────────────────────────────────────────────────

export function applyTheme(s: UserSettings): void {
    const root = document.documentElement

    // Clear all previously set inline styles — applyTheme is the sole owner of root inline styles.
    // This ensures no stale values survive when settings change.
    root.style.cssText = ''

    // ── 1. Theme preset ──────────────────────────────────────────────────────
    const preset = THEME_PRESETS[s.themePreset ?? 'default'] ?? {}
    for (const [k, v] of Object.entries(preset)) root.style.setProperty(k, v)

    // ── 2. Menu background (theme-aware opacity slider) ──────────────────────
    const bgBase  = BG_BASES[s.themePreset ?? 'default'] ?? BG_BASES.default
    const opacity = clamp(s.menuOpacity ?? 97, 50, 100) / 100
    root.style.setProperty('--ui-ctx-bg', `rgba(${bgBase},${opacity})`)

    // ── 3. Font scale ────────────────────────────────────────────────────────
    root.style.setProperty('--ui-font-scale', (clamp(s.fontSize, 50, 200) / 100).toFixed(2))

    // ── 4. Accent color + darker hover shade ─────────────────────────────────
    const accentRaw = safeCssColor(s.accentColor)
    if (accentRaw) {
        root.style.setProperty('--ui-accent', accentRaw)
        root.style.setProperty('--ui-accent-text', '#ffffff')
        let r = -1, g = -1, b = -1
        if (/^#[0-9a-fA-F]{6}$/.test(accentRaw)) {
            ;[r, g, b] = [0, 2, 4].map(i => parseInt(accentRaw.slice(i + 1, i + 3), 16))
        } else if (/^#[0-9a-fA-F]{3}$/.test(accentRaw)) {
            const h = accentRaw[1]+accentRaw[1]+accentRaw[2]+accentRaw[2]+accentRaw[3]+accentRaw[3]
            ;[r, g, b] = [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16))
        } else {
            const m = accentRaw.match(/^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/)
            if (m) { r = +m[1]; g = +m[2]; b = +m[3] }
        }
        if (r >= 0) {
            const dim = [r, g, b].map(v => Math.max(0, Math.round(v * 0.88)).toString(16).padStart(2, '0')).join('')
            root.style.setProperty('--ui-accent-dim', '#' + dim)
        }
    }

    // ── 5. Notification position ─────────────────────────────────────────────
    root.style.setProperty('--ui-notify-position-x', s.notifyX === 'left' ? 'left' : 'right')
    root.style.setProperty('--ui-notify-position-y', s.notifyY === 'top'  ? 'top'  : 'bottom')

    // ── 6. Progress bar position presets ─────────────────────────────────────
    const progressPresets: Record<string, { bottom: string; top: string; left: string; right: string; transform: string }> = {
        'bottom-center': { bottom: '60px', top: 'auto', left: '50%',  right: 'auto', transform: 'translateX(-50%)' },
        'top-center':    { bottom: 'auto', top: '60px', left: '50%',  right: 'auto', transform: 'translateX(-50%)' },
        'bottom-left':   { bottom: '60px', top: 'auto', left: '20px', right: 'auto', transform: 'none' },
        'bottom-right':  { bottom: '60px', top: 'auto', left: 'auto', right: '20px', transform: 'none' },
    }
    const pp = progressPresets[s.progressPos ?? 'bottom-center'] ?? progressPresets['bottom-center']
    root.style.setProperty('--ui-progress-bottom',    pp.bottom)
    root.style.setProperty('--ui-progress-top',       pp.top)
    root.style.setProperty('--ui-progress-left',      pp.left)
    root.style.setProperty('--ui-progress-right',     pp.right)
    root.style.setProperty('--ui-progress-transform', pp.transform)

    // ── 7. Modal alignment ───────────────────────────────────────────────────
    const modalAlignMap: Record<string, string> = {
        'center':        'center',
        'top-center':    'flex-start',
        'bottom-center': 'flex-end',
    }
    root.style.setProperty('--ui-modal-align', modalAlignMap[s.modalAlign ?? 'center'] ?? 'center')

    // ── 8. Compact mode / menu width ─────────────────────────────────────────
    root.style.setProperty('--ui-ctx-item-height', s.compactMode ? '32px' : '40px')
    const widthMap: Record<string, string> = { compact: '260px', default: '320px', large: '400px' }
    root.style.setProperty('--ui-ctx-width', widthMap[s.menuWidth ?? 'default'] ?? '320px')

    // ── 9. Blur effects (disabled by perfMode) ────────────────────────────────
    root.style.setProperty('--ui-blur', (s.perfMode || !s.blurEffects) ? '0px' : '8px')

    // ── 10. Reduce motion / performance mode — zeroes all animation durations ─
    const noAnim = s.perfMode || s.reduceMotion
    const dur = (ms: number) => noAnim ? '0ms' : `${ms}ms`
    root.style.setProperty('--ui-ctx-anim-open',   dur(220))
    root.style.setProperty('--ui-ctx-anim-close',  dur(180))
    root.style.setProperty('--ui-ctx-anim-item',   dur(80))
    root.style.setProperty('--ui-ctx-anim-toggle', dur(200))
    root.style.setProperty('--ui-stat-anim',        dur(600))
    root.style.setProperty('--ui-anim-play', noAnim ? 'paused' : 'running')

    // ── 11. Line spacing ──────────────────────────────────────────────────────
    root.style.setProperty('--ui-line-spacing', clamp(s.lineSpacing ?? 1.2, 1.0, 2.0).toFixed(2))

    // ── 12. Hover delay (motor accessibility) ────────────────────────────────
    root.style.setProperty('--ui-hover-delay', `${clamp(s.hoverDelay ?? 0, 0, 600)}ms`)

    // ── 13. Custom border radius ──────────────────────────────────────────────
    if (s.borderRadius !== null && s.borderRadius !== undefined && s.borderRadius >= 0) {
        const r = clamp(s.borderRadius, 0, 24)
        root.style.setProperty('--ui-ctx-radius',      `${r}px`)
        root.style.setProperty('--ui-ctx-radius-item', `${Math.round(r * 0.625)}px`)
        root.style.setProperty('--ui-ctx-radius-xs',   `${Math.round(r * 0.375)}px`)
    }

    // ── 14. High contrast ────────────────────────────────────────────────────
    if (s.highContrast) {
        const isLight = (s.themePreset ?? 'default') === 'light'
        if (isLight) {
            root.style.setProperty('--ui-ctx-border',        'rgba(0,0,0,0.22)')
            root.style.setProperty('--ui-ctx-border-item',   'rgba(0,0,0,0.30)')
            root.style.setProperty('--ui-ctx-text',          'rgba(0,0,0,0.97)')
            root.style.setProperty('--ui-ctx-text-dim',      'rgba(0,0,0,0.75)')
            root.style.setProperty('--ui-ctx-text-muted',    'rgba(0,0,0,0.55)')
        } else {
            root.style.setProperty('--ui-ctx-border',        'rgba(255,255,255,0.28)')
            root.style.setProperty('--ui-ctx-border-item',   'rgba(255,255,255,0.35)')
            root.style.setProperty('--ui-ctx-text',          'rgba(255,255,255,0.97)')
            root.style.setProperty('--ui-ctx-text-dim',      'rgba(255,255,255,0.78)')
            root.style.setProperty('--ui-ctx-text-muted',    'rgba(255,255,255,0.58)')
        }
    }

    // ── 15. Color blind filter (applied to <html>) ───────────────────────────
    const VALID_CB = ['none', 'deuteranopia', 'protanopia', 'tritanopia']
    const cb = VALID_CB.includes(s.colorBlind) ? s.colorBlind : 'none'
    root.style.filter = cb !== 'none' ? `url(#lm-${cb})` : ''

    // ── 16. Radial size ───────────────────────────────────────────────────────
    if (s.radialSize !== null && s.radialSize !== undefined) {
        const radialSizeMap: Record<string, string> = { compact: '320px', normal: '400px', large: '500px' }
        root.style.setProperty('--ui-radial-size', radialSizeMap[s.radialSize] ?? '400px')
    }

    // ── 17. Target menu size ──────────────────────────────────────────────────
    if (s.targetSize !== null && s.targetSize !== undefined) {
        const targetSizeMap: Record<string, string> = { compact: '260px', normal: '320px', large: '400px' }
        root.style.setProperty('--ui-target-width', targetSizeMap[s.targetSize] ?? '320px')
    }
}
