import { untrack } from 'svelte'
import { Palette, Mouse, List, Bell, Square, Activity, Eye, Zap, Globe } from 'lucide-svelte'
import { SETTINGS_DEFAULTS, AVAILABLE_THEMES } from '../../utils/theme'
import { TRANSLATIONS, LANGUAGES } from '../../i18n/translations'

export interface ImportDiffRow {
    key: string
    label: string
    from: string
    to: string
}

export function useUserSettings(
    getSettings: () => any,
    onSave: (s: any) => void,
    onClose: () => void,
) {
    let local          = $state(untrack(() => ({ ...getSettings() })))
    let activeSection  = $state('navigation')
    let exportFeedback = $state('')
    let importFeedback = $state('')
    let importError    = $state('')
    let exportJson    = $state<string | null>(null)
    let exportCopied  = $state(false)
    // null = not open, array = open (may be empty = no changes)
    let importPreview  = $state<ImportDiffRow[] | null>(null)
    let pendingImport  = $state<any>(null)

    const t = $derived(TRANSLATIONS[local.language ?? 'en'] ?? TRANSLATIONS['en'])

    const SECTIONS = $derived([
        { id: 'appearance', label: t.sec_appearance, Icon: Palette  },
        { id: 'navigation', label: t.sec_nav,        Icon: Mouse    },
        { id: 'context',    label: t.sec_context,    Icon: List     },
        { id: 'notify',     label: t.sec_notify,     Icon: Bell     },
        { id: 'modal',      label: t.sec_modal,      Icon: Square   },
        { id: 'progress',   label: t.sec_progress,   Icon: Activity },
        { id: 'access',     label: t.sec_access,     Icon: Eye      },
        { id: 'perf',       label: t.sec_perf,       Icon: Zap      },
        { id: 'lang',       label: t.sec_lang,       Icon: Globe    },
    ])

    function resetPosition() {
        localStorage.removeItem('lm-pos-x')
        localStorage.removeItem('lm-pos-y')
    }

    function handleBackdrop(e: MouseEvent & { currentTarget: HTMLDivElement }) {
        if (e.target === e.currentTarget) onClose()
    }

    function handleKeydown(e: KeyboardEvent) {
        if (e.key === 'Escape') {
            if (importPreview) { cancelImport(); return }
            if (exportJson)    { closeExport();  return }
            onClose()
        }
    }

    function handleColorInput(e: Event & { currentTarget: HTMLInputElement }) {
        local.accentColor = e.currentTarget.value
    }

    function handleSave() {
        onSave(local)
    }

    // ── Export ──────────────────────────────────────────────────────────────

    function exportSettings() {
        const { _v, ...exportable } = local
        exportJson = JSON.stringify({ ...exportable, _v }, null, 2)
        exportCopied = false
    }

    function closeExport() {
        exportJson   = null
        exportCopied = false
    }

    // textarea+execCommand — works in FiveM's CEF where navigator.clipboard is unavailable.
    function _copyToClipboard(text: string): boolean {
        try {
            const ta = document.createElement('textarea')
            ta.value = text
            ta.style.cssText = 'position:fixed;top:0;left:0;width:2px;height:2px;padding:0;border:none;outline:none;box-shadow:none;background:transparent'
            document.body.appendChild(ta)
            ta.focus()
            ta.select()
            const ok = document.execCommand('copy')
            document.body.removeChild(ta)
            return ok
        } catch {
            return false
        }
    }

    async function copyExportJson() {
        if (!exportJson) return
        let ok = false
        try {
            await navigator.clipboard.writeText(exportJson)
            ok = true
        } catch {}
        if (!ok) ok = _copyToClipboard(exportJson)
        if (ok) {
            exportCopied = true
            setTimeout(() => { exportCopied = false }, 2000)
        }
    }

    // ── Import ──────────────────────────────────────────────────────────────

    function openImport() {
        importError    = ''
        const input    = document.createElement('input')
        input.type     = 'file'
        input.accept   = '.json,application/json'
        input.onchange = () => {
            const file = input.files?.[0]
            if (!file) return
            const reader  = new FileReader()
            reader.onload = () => {
                try {
                    const parsed = JSON.parse(reader.result as string)
                    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) throw new Error()
                    const merged = { ...SETTINGS_DEFAULTS, ...parsed, _v: SETTINGS_DEFAULTS._v }
                    const diff   = _computeDiff(local, merged)
                    pendingImport = merged
                    importPreview = diff  // may be [] (no changes)
                } catch {
                    importError = t.import_invalid
                    setTimeout(() => { importError = '' }, 3000)
                }
            }
            reader.readAsText(file)
        }
        input.click()
    }

    function _computeDiff(current: any, next: any): ImportDiffRow[] {
        const LABELS: Record<string, () => string> = {
            themePreset:    () => t.theme_preset,
            accentColor:    () => t.accent,
            fontSize:       () => t.font_size,
            menuOpacity:    () => t.menu_opacity,
            menuWidth:      () => t.menu_width,
            compactMode:    () => t.compact_mode,
            blurEffects:    () => t.blur_effects,
            navMode:        () => t.nav_mode,
            targetKey:      () => t.target_key,
            uiSounds:       () => t.ui_sounds,
            animation:      () => t.anim,
            notifyX:        () => t.notif_h,
            notifyY:        () => t.notif_v,
            notifyDuration: () => t.notif_dur,
            modalAlign:     () => t.modal_align,
            progressPos:    () => t.prog_pos,
            colorBlind:     () => t.color_blind,
            highContrast:   () => t.high_contrast,
            reduceMotion:   () => t.reduce_motion,
            lineSpacing:    () => t.line_spacing,
            hoverDelay:     () => t.hover_delay,
            perfMode:       () => t.perf_mode,
            borderRadius:   () => t.border_radius,
            language:       () => t.lang_label,
        }
        const rows: ImportDiffRow[] = []
        for (const key of Object.keys(LABELS)) {
            const from = current[key]
            const to   = next[key]
            if (String(from) !== String(to)) {
                rows.push({ key, label: LABELS[key](), from: _fmtVal(from), to: _fmtVal(to) })
            }
        }
        return rows
    }

    function _fmtVal(v: any): string {
        if (v === null || v === undefined) return '—'
        if (typeof v === 'boolean') return v ? '✓' : '✗'
        return String(v)
    }

    function applyImport() {
        if (!pendingImport) return
        local         = pendingImport
        pendingImport = null
        importPreview = null
        importFeedback = t.import_ok
        setTimeout(() => { importFeedback = '' }, 2000)
    }

    function cancelImport() {
        pendingImport = null
        importPreview = null
    }

    function darkenHex(hex: string, amount = 0.12) {
        const r  = parseInt(hex.slice(1, 3), 16)
        const g  = parseInt(hex.slice(3, 5), 16)
        const b  = parseInt(hex.slice(5, 7), 16)
        const dr = Math.max(0, Math.round(r * (1 - amount)))
        const dg = Math.max(0, Math.round(g * (1 - amount)))
        const db = Math.max(0, Math.round(b * (1 - amount)))
        return '#' + [dr, dg, db].map(v => v.toString(16).padStart(2, '0')).join('')
    }

    function sliderPct(value: number, min: number, max: number) {
        return Math.round(((value - min) / (max - min)) * 100)
    }

    return {
        get local()                  { return local },
        get activeSection()          { return activeSection },
        set activeSection(v: string) { activeSection = v },
        get exportFeedback()         { return exportFeedback },
        get importFeedback()         { return importFeedback },
        get importError()            { return importError },
        get exportJson()    { return exportJson },
        get exportCopied()  { return exportCopied },
        get importPreview() { return importPreview },
        get t()             { return t },
        get SECTIONS()      { return SECTIONS },
        LANGUAGES,
        THEMES: AVAILABLE_THEMES,
        resetPosition,
        handleBackdrop,
        handleKeydown,
        handleColorInput,
        handleSave,
        exportSettings,
        closeExport,
        copyExportJson,
        openImport,
        applyImport,
        cancelImport,
        darkenHex,
        sliderPct,
    }
}
