// ── Shared types ──────────────────────────────────────────────────────────

export interface DateFields { d: number; m: number; y: number }

export interface DateItem { min?: string; max?: string }

export interface DateFieldDef {
    min: number
    max: number
    cls: string
    get: (df: DateFields) => number
    set: (df: DateFields, v: number) => DateFields
}

export interface HeightItem { kind: string; id?: string }

// ── Security helpers ──────────────────────────────────────────────────────

export function safeCss(str: string): string {
    if (!str || typeof str !== 'string') return ''
    return str.replace(/[^a-zA-Z0-9#(),.\s%+-]/g, '')
}

export function safeUrl(str: string): string {
    if (!str || typeof str !== 'string') return ''
    if (/^https?:\/\//i.test(str) || /^nui:\/\//i.test(str)) return str
    return ''
}

// ── Date helpers ──────────────────────────────────────────────────────────

export function parseDateFields(iso: string | null | undefined): DateFields {
    if (!iso) { const n = new Date(); return { d: n.getDate(), m: n.getMonth()+1, y: n.getFullYear() } }
    const p = iso.split('-')
    return { d: parseInt(p[2]||'1'), m: parseInt(p[1]||'1'), y: parseInt(p[0]||'2024') }
}

export function composeDateISO(d: number, m: number, y: number): string {
    return `${y}-${String(m).padStart(2,'0')}-${String(d).padStart(2,'0')}`
}

export function getDateFieldOrder(format: string | undefined, item?: DateItem): DateFieldDef[] {
    const minYear = item?.min ? parseInt(item.min.slice(0, 4)) : 1700
    const maxYear = item?.max ? parseInt(item.max.slice(0, 4)) : 3000
    const defs: Record<string, DateFieldDef> = {
        d: { min:1,       max:31,       cls:'',          get: df=>df.d, set: (df,v)=>({...df,d:v}) },
        m: { min:1,       max:12,       cls:'',          get: df=>df.m, set: (df,v)=>({...df,m:v}) },
        y: { min:minYear, max:maxYear,  cls:'date-year', get: df=>df.y, set: (df,v)=>({...df,y:v}) },
    }
    return (format || 'dmy').split('').map(c => defs[c]).filter(Boolean)
}

// ── Stat color ────────────────────────────────────────────────────────────

export function statColor(value: number, max: number, custom?: string): string {
    if (custom === 'auto') {
        const p = max > 0 ? value / max * 100 : 0
        return p > 60 ? 'var(--ui-stat-high)' : p > 30 ? 'var(--ui-stat-mid)' : 'var(--ui-stat-low)'
    }
    if (custom) return custom
    return 'var(--ui-accent)'
}

// ── Virtual scroll height map ─────────────────────────────────────────────

export const ITEM_HEIGHTS: Record<string, number> = {
    button: 40, checkbox: 40, toggle: 40, accordion_start: 40,
    slider: 40, stepper: 40, list: 40, input_inline: 40,
    color_picker: 40, date_picker: 40,
    stat: 52, header: 28, separator: 8,
}

// Additional height of the color_picker popover when open:
// presets grid (2 rows × 25px + gaps) + color-bottom (custom + hex input) + padding
const COLOR_PICKER_POPOVER_H = 135

export function getItemHeight(item: HeightItem, compactMode: boolean, openPopoverId?: string | null): number {
    const base = ITEM_HEIGHTS[item.kind] ?? 40
    const adjusted = compactMode && base === 40 ? 32 : base
    if (item.kind === 'color_picker' && item.id && item.id === openPopoverId) {
        return adjusted + COLOR_PICKER_POPOVER_H
    }
    return adjusted
}
