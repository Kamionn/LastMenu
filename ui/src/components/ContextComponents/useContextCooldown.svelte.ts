interface CooldownItem {
    id: string
    cooldown?: number
    cooldown_key?: string  // computed by Lua (persist_key ?? cb_id) — single source of truth
    cd_expiry?: number     // injected by Lua from ResourceKvp
}

/**
 * Cooldown composable for Context menu buttons.
 * Persistence is delegated to Lua (ResourceKvp) via NUI fetch — immune to
 * client-side DevTools manipulation. `cd_expiry` on each item is injected
 * by the Lua button builder when the resource starts.
 */
export function useContextCooldown(getActive: () => boolean) {
    let now        = $state(Date.now())
    let cooldowns  = $state<Record<string, number>>({})
    let cdInterval: ReturnType<typeof setInterval> | null = null
    let mountedItems: CooldownItem[] = []

    $effect(() => {
        if (getActive()) now = Date.now()
    })

    function isCooling(id: string): boolean  { return !!cooldowns[id] && cooldowns[id] > now }
    function cdRemaining(id: string): number { return Math.max(0, (cooldowns[id] ?? 0) - now) }

    function cdStorageKey(item: CooldownItem): string | null {
        return item.cooldown_key ?? null
    }

    function nuiFetch(endpoint: string, body: object): void {
        fetch(`https://LastMenu/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
        }).catch(() => {})
    }

    function startCooldown(item: CooldownItem): void {
        if (!item.cooldown) return
        const expiry = now + item.cooldown
        cooldowns = { ...cooldowns, [item.id]: expiry }
        const key = cdStorageKey(item)
        if (key) nuiFetch('cooldown:set', { key, expiry })
    }

    function mount(items?: CooldownItem[]): void {
        mountedItems = items ?? []

        // Restore cooldowns from cd_expiry injected by Lua builder (read from ResourceKvp).
        const n = Date.now()
        const restored: Record<string, number> = {}
        for (const item of mountedItems) {
            if (!item.cooldown || !item.cd_expiry) continue
            if (item.cd_expiry > n) restored[item.id] = item.cd_expiry
        }
        if (Object.keys(restored).length > 0) cooldowns = restored

        cdInterval = setInterval(() => {
            if (!getActive()) return
            now = Date.now()
            if (Object.keys(cooldowns).some(id => cooldowns[id] <= now)) {
                const nc: Record<string, number> = {}
                for (const id in cooldowns) {
                    if (cooldowns[id] > now) {
                        nc[id] = cooldowns[id]
                    } else {
                        const item = mountedItems.find(i => i.id === id)
                        if (item) {
                            const key = cdStorageKey(item)
                            if (key) nuiFetch('cooldown:clear', { key })
                        }
                    }
                }
                cooldowns = nc
            }
        }, 100)
    }

    function unmount(): void {
        if (cdInterval !== null) clearInterval(cdInterval)
    }

    return {
        get now()       { return now },
        get cooldowns() { return cooldowns },
        isCooling,
        cdRemaining,
        startCooldown,
        mount,
        unmount,
    }
}
