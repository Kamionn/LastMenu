interface DragStart { mx: number; my: number; ox: number; oy: number }

/**
 * Drag-to-reposition composable for the Context menu.
 * Position is persisted in localStorage, scoped by menuId to avoid collisions
 * across multiple instances or dev multi-window setups.
 */
export function useContextDrag(getActive: () => boolean, _menuId: string = '') {
    const _keyX = 'lm-pos-x'
    const _keyY = 'lm-pos-y'

    let pos = $state({
        x: Math.max(0, parseInt(localStorage.getItem(_keyX) || '16')),
        y: Math.max(0, parseInt(localStorage.getItem(_keyY) || '72')),
    })

    let dragging  = $state(false)
    let dragStart: DragStart | null = null

    const previewOnLeft = $derived(pos.x + 320 > window.innerWidth / 2)

    function startDrag(e: MouseEvent): void {
        if (e.button !== 0) return
        dragging  = true
        dragStart = { mx: e.clientX, my: e.clientY, ox: pos.x, oy: pos.y }
        e.preventDefault()
    }

    function onWinMouseMove(e: MouseEvent): void {
        if (!getActive() || !dragging || !dragStart) return
        pos = {
            x: Math.max(0, dragStart.ox + e.clientX - dragStart.mx),
            y: Math.max(0, dragStart.oy + e.clientY - dragStart.my),
        }
    }

    function onWinMouseUp(): void {
        if (!dragging) return
        dragging = false
        localStorage.setItem(_keyX, String(pos.x))
        localStorage.setItem(_keyY, String(pos.y))
    }

    return {
        get pos()           { return pos },
        get dragging()      { return dragging },
        get previewOnLeft() { return previewOnLeft },
        startDrag,
        onWinMouseMove,
        onWinMouseUp,
    }
}
