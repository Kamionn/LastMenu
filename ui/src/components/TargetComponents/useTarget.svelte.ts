import { untrack } from 'svelte'

function _flatItems(items: any[]): any[] {
    const out: any[] = []
    for (const item of items ?? []) {
        out.push(item)
        if (item.kind === 'accordion') {
            for (const sub of item.items ?? []) out.push(sub)
        }
    }
    return out
}

export function useTarget(getData: () => any, onCallback: (id: string, extra?: any) => void) {

    // -- Cooldown tracking
    const _cdMap = new Map()
    let _cdTick   = $state(0)
    let _cdTimer = null

    function _startCdTimer() {
        if (_cdTimer) return
        _cdTimer = setInterval(() => {
            let active = false
            const now = Date.now()
            for (const [id, cd] of _cdMap) {
                if (cd.expiry > now) active = true
                else _cdMap.delete(id)
            }
            _cdTick++
            if (!active) { clearInterval(_cdTimer); _cdTimer = null }
        }, 100)
    }

    untrack(() => {
        for (const item of _flatItems(getData().items ?? [])) {
            if (item.cd_expiry && item.cooldown) {
                const remaining = item.cd_expiry - Date.now()
                if (remaining > 0) _cdMap.set(item.id, { expiry: item.cd_expiry, duration: item.cooldown })
            }
        }
        if (_cdMap.size > 0) _startCdTimer()
    })

    function isCooling(id) {
        _cdTick
        return (_cdMap.get(id)?.expiry ?? 0) > Date.now()
    }

    function cdRemaining(id) {
        _cdTick
        return Math.max(0, (_cdMap.get(id)?.expiry ?? 0) - Date.now())
    }

    function _startCooldown(item) {
        if (!item.cooldown) return
        _cdMap.set(item.id, { expiry: Date.now() + item.cooldown, duration: item.cooldown })
        _startCdTimer()
    }

    // -- Stateful items
    let states = $state(untrack(() => {
        const init = {}
        for (const item of _flatItems(getData().items ?? [])) {
            if (item.kind === 'toggle' || item.kind === 'checkbox') {
                init[item.id] = item.value ?? false
            } else if (item.kind === 'slider') {
                init[item.id] = item.value ?? item.min ?? 0
            }
        }
        return init
    }))

    function updateState(id, value) { states[id] = value }

    // -- Accordions
    let openAccordions = $state(untrack(() => {
        const s = new Set()
        for (const item of getData().items ?? []) {
            if (item.kind === 'accordion' && item.open) s.add(item.id)
        }
        return s
    }))

    function toggleAcc(id) {
        const next = new Set(openAccordions)
        if (next.has(id)) next.delete(id); else next.add(id)
        openAccordions = next
    }

    // -- Hold-to-confirm
    let holdId       = $state(null)
    let holdProgress = $state(0)
    let _holdRAF   = null
    let _holdStart = null

    function startHold(item) {
        const duration = (typeof item.confirm_hold === 'number' && item.confirm_hold > 0)
            ? item.confirm_hold : 1500
        holdId = item.id; holdProgress = 0; _holdStart = performance.now()
        function tick(now) {
            const p = Math.min(1, (now - _holdStart) / duration)
            holdProgress = p
            if (p < 1) { _holdRAF = requestAnimationFrame(tick) }
            else { holdId = null; holdProgress = 0; _holdRAF = null; _executeItem(item) }
        }
        _holdRAF = requestAnimationFrame(tick)
    }

    function cancelHold() {
        if (_holdRAF) cancelAnimationFrame(_holdRAF)
        _holdRAF = null; _holdStart = null; holdId = null; holdProgress = 0
    }

    // -- Item execution
    function _executeItem(item) {
        if (item.kind === 'toggle' || item.kind === 'checkbox') {
            const newVal = !(states[item.id] ?? false)
            states[item.id] = newVal
            onCallback(item.id, { value: newVal })
        } else {
            _startCooldown(item)
            onCallback(item.id)
        }
    }

    function clickItem(item) {
        if (item.disabled || isCooling(item.id)) return
        if (item.confirm_hold) return
        _executeItem(item)
    }

    return {
        get holdId()         { return holdId },
        get holdProgress()   { return holdProgress },
        get states()         { return states },
        get openAccordions() { return openAccordions },
        isCooling, cdRemaining, startHold, cancelHold, clickItem, toggleAcc, updateState,
    }
}