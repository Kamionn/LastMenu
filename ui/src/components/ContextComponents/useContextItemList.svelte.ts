import { getContext } from 'svelte'

/**
 * Composable for ContextItemList — retrieves shared context and manages
 * the container height propagation needed by virtual scroll.
 */
export function useContextItemList() {
    const ctx = getContext<any>('ctx')

    let _clientHeight = $state(0)
    $effect(() => { ctx.containerClientHeight = _clientHeight })

    return {
        ctx,
        get clientHeight() { return _clientHeight },
        set clientHeight(v: number) { _clientHeight = v },
    }
}
