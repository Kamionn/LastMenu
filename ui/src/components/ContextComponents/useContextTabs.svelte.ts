export interface Tab { id: string; label: string; icon?: string }

/**
 * Composable for ContextTabs — manages the DOM ref and auto-scroll behaviour.
 */
export function useContextTabs(getActiveTab: () => string | null) {
    let tabsEl = $state<HTMLDivElement | null>(null)

    $effect(() => {
        const activeTab = getActiveTab()
        if (!activeTab || !tabsEl) return
        const activeBtn = tabsEl.querySelector<HTMLElement>('.tab-btn.is-active')
        activeBtn?.scrollIntoView({ block: 'nearest', inline: 'nearest' })
    })

    return {
        get tabsEl() { return tabsEl },
        set tabsEl(v: HTMLDivElement | null) { tabsEl = v },
    }
}
