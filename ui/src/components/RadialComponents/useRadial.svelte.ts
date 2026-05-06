import { untrack } from 'svelte'
import { onMount } from 'svelte'

const INNER_R   = 52
const OUTER_R   = 138
const LABEL_R   = 168
const SIZE      = 340
const HOLD_R    = INNER_R + 2
const HOLD_CIRC = 2 * Math.PI * HOLD_R

function polar(r: number, deg: number): [number, number] {
    const rad = (deg - 90) * Math.PI / 180
    return [SIZE / 2 + r * Math.cos(rad), SIZE / 2 + r * Math.sin(rad)]
}

export function useRadial(getData: () => any, onCallback: (id: string) => void) {
    let containerEl  = $state<HTMLElement | null>(null)

    let frozenIds = $state<string[]>(untrack(() =>
        (getData().buttons ?? []).map((b: any) => b.id)
    ))

    
    let mouseX    = $state(SIZE / 2)
    let mouseY    = $state(SIZE / 2)
    let kbIndex   = $state(-1)
    let holdState = $state<{ id: string | null, progress: number }>({ id: null, progress: 0 })
    let holdStart: number | null = null
    let holdRAF:   number | null = null

    let liveButtons = $derived.by(() => {
        const all = getData().buttons ?? []
        if (frozenIds.length === 0) return all.filter((b: any) => b.visible !== false)
        const byId = new Map(all.map((b: any) => [b.id, b]))
        return frozenIds
            .map(fid => byId.get(fid))
            .filter(Boolean)
            .filter((b: any) => b.visible !== false)
            .map((b: any) => ({ ...b }))
    })

    let n = $derived(liveButtons.length)

    let selectedIndex = $derived.by(() => {
        if (kbIndex >= 0 && kbIndex < n) return kbIndex
        if (n === 0) return -1
        const dx = mouseX - SIZE / 2
        const dy = mouseY - SIZE / 2
        if (Math.sqrt(dx * dx + dy * dy) < INNER_R) return -1
        let angle = Math.atan2(dx, -dy) * (180 / Math.PI)
        if (angle < 0) angle += 360
        const idx = Math.floor(angle / (360 / n)) % n
        if (liveButtons[idx]?.disabled) return -1
        return idx
    })

    let selectedLabel = $derived(selectedIndex >= 0 ? (liveButtons[selectedIndex]?.label ?? '') : '')

    onMount(() => {
        function handleNUI(e: MessageEvent) {
            const d = e.data
            if (!d || typeof d !== 'object') return
            if (d.type === 'radial_gamepad') {
                if (d.dx === 0 && d.dy === 0) { mouseX = SIZE / 2; mouseY = SIZE / 2 }
                else {
                    const reach = OUTER_R * 0.72
                    mouseX = SIZE / 2 + d.dx * reach
                    mouseY = SIZE / 2 + d.dy * reach
                }
            } else if (d.type === 'radial_confirm') {
                handleClick()
            }
        }
        window.addEventListener('message', handleNUI)
        return () => window.removeEventListener('message', handleNUI)
    })

    function arcPath(i: number): string {
        const step  = 360 / n
        const gap   = n <= 1 ? 0 : Math.max(2, Math.min(8, Math.round(16 / n)))
        const s     = i * step + gap / 2
        const e     = (i + 1) * step - gap / 2
        const large = (e - s > 180) ? 1 : 0

        const [x1, y1] = polar(INNER_R + 2, s)
        const [x2, y2] = polar(OUTER_R,     s)
        const [x3, y3] = polar(OUTER_R,     e)
        const [x4, y4] = polar(INNER_R + 2, e)

        return (
            `M${x1},${y1} ` +
            `L${x2},${y2} ` +
            `A${OUTER_R},${OUTER_R} 0 ${large} 1 ${x3},${y3} ` +
            `L${x4},${y4} ` +
            `A${INNER_R + 2},${INNER_R + 2} 0 ${large} 0 ${x1},${y1}Z`
        )
    }

    function iconCenter(i: number): { x: number, y: number } {
        const step   = 360 / n
        const mid    = (i + 0.5) * step
        const r      = (INNER_R + OUTER_R) / 2
        const [x, y] = polar(r, mid)
        return { x, y }
    }

    function labelPos(i: number): { x: number, y: number, align: 'left' | 'right' | 'center' } {
        const step   = 360 / n
        const mid    = (i + 0.5) * step
        const [x, y] = polar(LABEL_R, mid)
        const angle  = mid % 360
        const align  = angle > 10 && angle < 170 ? 'left' : angle > 190 && angle < 350 ? 'right' : 'center'
        return { x, y, align }
    }

    function handleMousemove(e: MouseEvent) {
        if (!containerEl) return
        // In FiveM's CEF, clientX/Y are in physical viewport pixels while
        // getBoundingClientRect() returns values in zoom-adjusted layout pixels.
        // Divide clientX by zoom first to convert to layout space, then subtract
        // the container's layout-space offset.
        const zoom = parseFloat(document.documentElement.style.zoom) || 1
        const rect = containerEl.getBoundingClientRect()
        mouseX  = e.clientX / zoom - rect.left
        mouseY  = e.clientY / zoom - rect.top
        kbIndex = -1
    }

    function handleClick() {
        const btn = selectedIndex >= 0 ? liveButtons[selectedIndex] : null
        if (!btn || btn.confirm_hold) return
        onCallback(btn.id)
    }

    function handleMousedown() {
        const btn = selectedIndex >= 0 ? liveButtons[selectedIndex] : null
        if (btn && btn.confirm_hold && !btn.disabled) startHold(btn)
    }

    function handleMouseup() {
        if (holdState.id) cancelHold()
    }

    function startHold(btn: any) {
        const duration = (typeof btn.confirm_hold === 'number' && btn.confirm_hold > 0)
            ? btn.confirm_hold : 1500
        holdStart = performance.now()
        holdState = { id: btn.id, progress: 0 }
        function tick(now: number) {
            const p = Math.min(1, (now - holdStart!) / duration)
            holdState = { id: btn.id, progress: p }
            if (p < 1) holdRAF = requestAnimationFrame(tick)
            else { holdState = { id: null, progress: 0 }; onCallback(btn.id) }
        }
        holdRAF = requestAnimationFrame(tick)
    }

    function cancelHold() {
        if (holdRAF) cancelAnimationFrame(holdRAF)
        holdRAF = null; holdStart = null
        holdState = { id: null, progress: 0 }
    }

    function nextEnabled(from: number, dir: number): number {
        if (n === 0) return -1
        let idx = ((from + dir) % n + n) % n
        for (let i = 0; i < n; i++) {
            if (!liveButtons[idx]?.disabled) return idx
            idx = ((idx + dir) % n + n) % n
        }
        return -1
    }

    function handleKeydown(e: KeyboardEvent) {
        if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
            e.preventDefault()
            kbIndex = nextEnabled(kbIndex >= 0 ? kbIndex : -1, 1)
        } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
            e.preventDefault()
            kbIndex = nextEnabled(kbIndex >= 0 ? kbIndex : n, -1)
        } else if (e.key === 'Tab') {
            e.preventDefault()
            kbIndex = nextEnabled(kbIndex >= 0 ? kbIndex : (e.shiftKey ? n : -1), e.shiftKey ? -1 : 1)
        } else if ((e.key === 'Enter' || e.key === ' ') && !e.repeat) {
            e.preventDefault()
            const idx = kbIndex >= 0 ? kbIndex : selectedIndex
            const btn = idx >= 0 ? liveButtons[idx] : null
            if (!btn || btn.disabled) return
            if (btn.confirm_hold) startHold(btn)
            else onCallback(btn.id)
        }
    }

    function handleKeyup(e: KeyboardEvent) {
        if ((e.key === 'Enter' || e.key === ' ') && holdState.id) cancelHold()
    }

    return {
        get containerEl()          { return containerEl },
        set containerEl(v)         { containerEl = v },
        get liveButtons()          { return liveButtons },
        get selectedIndex()        { return selectedIndex },
        get selectedLabel()        { return selectedLabel },
        get holdState()            { return holdState },
        SIZE, INNER_R, HOLD_R, HOLD_CIRC,
        arcPath, iconCenter, labelPos,
        handleMousemove, handleClick, handleMousedown, handleMouseup,
        handleKeydown, handleKeyup,
    }
}
