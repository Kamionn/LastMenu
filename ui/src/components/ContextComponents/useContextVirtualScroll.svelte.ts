import { getItemHeight } from './contextUtils.js'

const VIRTUAL_BUFFER = 5

interface VirtualScrollConfig {
    getScrollMode:    () => boolean
    getPagedItems:    () => any[]
    getCompactMode:   () => boolean
    getSearchQuery:   () => string
    getItemsListRef:  () => HTMLElement | null
    getOpenPopoverId?: () => string | null
}

/**
 * Virtual scroll composable — hauteurs estimées par type, sans ResizeObserver.
 */
export function useContextVirtualScroll(config: VirtualScrollConfig) {
    let containerScrollTop    = $state(0)
    let containerClientHeight = $state(0)

    const cumulHeights = $derived.by(() => {
        if (!config.getScrollMode()) return []
        const h = [0]
        const openPopoverId = config.getOpenPopoverId?.() ?? null
        for (const item of config.getPagedItems())
            h.push(h[h.length - 1] + getItemHeight(item, config.getCompactMode(), openPopoverId))
        return h
    })

    const totalHeight = $derived(
        cumulHeights.length > 0 ? cumulHeights[cumulHeights.length - 1] : 0
    )

    const virtualStart = $derived.by(() => {
        if (!config.getScrollMode() || cumulHeights.length === 0) return 0
        let lo = 0, hi = config.getPagedItems().length
        while (lo < hi) {
            const mid = (lo + hi) >> 1
            if ((cumulHeights[mid + 1] ?? 0) <= containerScrollTop) lo = mid + 1
            else hi = mid
        }
        return Math.max(0, lo - VIRTUAL_BUFFER)
    })

    const virtualEnd = $derived.by(() => {
        if (!config.getScrollMode() || cumulHeights.length === 0) return config.getPagedItems().length
        const viewBottom = containerScrollTop + Math.max(containerClientHeight, 320)
        let i = Math.max(0, virtualStart + VIRTUAL_BUFFER)
        while (i < config.getPagedItems().length && (cumulHeights[i] ?? 0) < viewBottom) i++
        return Math.min(config.getPagedItems().length, i + VIRTUAL_BUFFER)
    })

    const virtualItemsWithIndex = $derived(
        config.getScrollMode()
            ? config.getPagedItems().slice(virtualStart, virtualEnd).map((item, vi) => ({ item, i: virtualStart + vi }))
            : config.getPagedItems().map((item, i) => ({ item, i }))
    )

    const topSpacerHeight    = $derived(config.getScrollMode() ? (cumulHeights[virtualStart] ?? 0) : 0)
    const bottomSpacerHeight = $derived(
        config.getScrollMode() ? Math.max(0, totalHeight - (cumulHeights[virtualEnd] ?? totalHeight)) : 0
    )

    // Reset scroll to top when search query changes (nouveaux résultats = retour en haut)
    $effect(() => {
        void config.getSearchQuery()
        if (!config.getScrollMode()) return
        containerScrollTop = 0
        const ref = config.getItemsListRef()
        if (ref) ref.scrollTop = 0
    })

    return {
        get containerScrollTop()     { return containerScrollTop },
        set containerScrollTop(v: number)    { containerScrollTop = v },
        get containerClientHeight()  { return containerClientHeight },
        set containerClientHeight(v: number) { containerClientHeight = v },
        get cumulHeights()           { return cumulHeights },
        get totalHeight()            { return totalHeight },
        get virtualStart()           { return virtualStart },
        get virtualEnd()             { return virtualEnd },
        get virtualItemsWithIndex()  { return virtualItemsWithIndex },
        get topSpacerHeight()        { return topSpacerHeight },
        get bottomSpacerHeight()     { return bottomSpacerHeight },
    }
}
