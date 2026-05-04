import { untrack } from 'svelte'

function collectStates(items: any[]) {
    const out: Record<string, any> = {}
    for (const item of items ?? []) {
        if (item.kind === 'accordion') Object.assign(out, collectStates(item.items))
        else if (item.kind === 'toggle' || item.kind === 'checkbox') out[item.id] = item.value ?? false
        else if (item.kind === 'slider') out[item.id] = item.value ?? item.min ?? 0
    }
    return out
}

export function useTarget(getData: () => any, onCallback: (id: string, extra?: Record<string, any>) => void) {
    let openAccordions = $state<Set<string>>(untrack(() => new Set(
        (getData().items ?? []).filter((i: any) => i.kind === 'accordion' && i.open).map((i: any) => i.id)
    )))
    let states    = $state<Record<string, any>>(untrack(() => collectStates(getData().items)))
    let cooldowns = $state<Record<string, number>>({})
    let _now      = $state(Date.now())

    $effect(() => {
        if (Object.keys(cooldowns).length === 0) return
        const iv = setInterval(() => { _now = Date.now() }, 100)
        return () => clearInterval(iv)
    })

    let holdId       = $state<string | null>(null)
    let holdProgress = $state(0)
    let _holdRaf     = 0

    function startHold(item: any) {
        cancelHold()
        const dur = item.confirm_hold
        const t0  = performance.now()
        holdId       = item.id
        holdProgress = 0
        const tick = (now: number) => {
            const p = Math.min(1, (now - t0) / dur)
            holdProgress = p
            if (p >= 1) {
                holdId = null; holdProgress = 0
                fireCallback(item)
            } else {
                _holdRaf = requestAnimationFrame(tick)
            }
        }
        _holdRaf = requestAnimationFrame(tick)
    }

    function cancelHold() {
        if (_holdRaf) { cancelAnimationFrame(_holdRaf); _holdRaf = 0 }
        holdId = null; holdProgress = 0
    }

    function startCooldown(item: any) {
        if (!item.cooldown) return
        const expiry = Date.now() + item.cooldown
        cooldowns = { ...cooldowns, [item.id]: expiry }
        setTimeout(() => {
            const c = { ...cooldowns }
            delete c[item.id]
            cooldowns = c
        }, item.cooldown + 100)
    }

    const isCooling   = (id: string) => cooldowns[id] != null && _now < cooldowns[id]
    const cdRemaining = (id: string) => Math.max(0, (cooldowns[id] ?? 0) - _now)

    function fireCallback(item: any, extra: Record<string, any> = {}) {
        onCallback(item.id, extra)
        startCooldown(item)
    }

    function clickItem(item: any) {
        if (item.disabled || isCooling(item.id)) return
        if (item.confirm_hold) return
        if (item.kind === 'toggle' || item.kind === 'checkbox') {
            const v = !(states[item.id] ?? false)
            states = { ...states, [item.id]: v }
            onCallback(item.id, { value: v })
        } else {
            fireCallback(item)
        }
    }

    function toggleAcc(id: string) {
        const s = new Set(openAccordions)
        s.has(id) ? s.delete(id) : s.add(id)
        openAccordions = s
    }

    function updateState(id: string, value: any) {
        states = { ...states, [id]: value }
    }

    return {
        get openAccordions() { return openAccordions },
        get states()         { return states },
        get holdId()         { return holdId },
        get holdProgress()   { return holdProgress },
        isCooling,
        cdRemaining,
        startHold,
        cancelHold,
        clickItem,
        toggleAcc,
        updateState,
    }
}
