import '@testing-library/jest-dom/vitest'
import { vi } from 'vitest'

// requestAnimationFrame stub — Progress and Radial use it for animations.
// We replace it with an instant synchronous noop so components mount cleanly.
global.requestAnimationFrame = (cb) => { setTimeout(cb, 0); return 0 }
global.cancelAnimationFrame  = (id) => clearTimeout(id)

// fetch stub — Notify uses it for notify_expired housekeeping
global.fetch = vi.fn().mockResolvedValue({ ok: true } as Response)

// getComputedStyle stub — Notify reads CSS custom props in onMount
const _getComputedStyle = global.getComputedStyle
global.getComputedStyle = (el, ...rest) => {
    const style = _getComputedStyle(el, ...rest)
    ;(style as any).getPropertyValue = (prop: string) => {
        if (prop === '--ui-notify-position-x') return 'right'
        if (prop === '--ui-notify-position-y') return 'bottom'
        return ''
    }
    return style
}
