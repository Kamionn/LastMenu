import { TriangleAlert, Info, CircleCheck, CircleX, CircleAlert } from 'lucide-svelte'

const TYPE_META: Record<string, { Icon: any; color: string; accentBg: string }> = {
    warning: { Icon: TriangleAlert, color: 'var(--ui-warning)',  accentBg: 'rgba(251,146,60,0.08)'  },
    error:   { Icon: CircleX,       color: 'var(--ui-error)',    accentBg: 'rgba(248,113,113,0.08)' },
    success: { Icon: CircleCheck,   color: 'var(--ui-success)',  accentBg: 'rgba(74,222,128,0.08)'  },
    info:    { Icon: Info,          color: 'var(--ui-info)',     accentBg: 'rgba(96,165,250,0.08)'  },
    confirm: { Icon: CircleAlert,   color: 'var(--ui-accent)',   accentBg: 'rgba(233,69,96,0.08)'   },
}

export function useAlert(getData: () => any, onCallback: (id: string) => void) {
    const type     = $derived(getData().type ?? (getData().confirm ? 'confirm' : 'info'))
    const typeMeta = $derived(TYPE_META[type] ?? TYPE_META.confirm)
    const Icon     = $derived(typeMeta.Icon)

    function handleKeydown(e: KeyboardEvent) {
        const data = getData()
        if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault()
            if (data.confirm) onCallback(data.confirm.id)
        } else if (e.key === 'Escape' || e.key === 'Backspace') {
            e.preventDefault()
            if (data.cancel) onCallback(data.cancel.id)
        }
    }

    return {
        get typeMeta() { return typeMeta },
        get Icon()     { return Icon },
        handleKeydown,
    }
}
