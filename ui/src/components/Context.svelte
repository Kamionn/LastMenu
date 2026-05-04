<script>
    import '../styles/Context.css'
    import { fly } from 'svelte/transition'
    import { onMount, untrack } from 'svelte'
    import { safeCss, safeUrl, statColor } from './ContextComponents/contextUtils.js'
    import { useContextDrag } from './ContextComponents/useContextDrag.svelte.ts'
    import ContextContent    from './ContextComponents/ContextContent.svelte'

    let { data, onCallback, navMode = 'both', defaultAnimation = 'slideLeft', active = true, menuId = '', closing = false, compactMode = false, uiSounds = false } = $props()

    const drag = useContextDrag(() => active, untrack(() => menuId))

    const meta = $derived(data.meta ?? { title: data.title ?? '', nav: 'both', animation: null })
    const effectiveAnimation = $derived(meta.animation ?? defaultAnimation ?? 'slideLeft')

    // CEF open-animation fix: flip animReady after one RAF so the browser has
    // a full paint cycle before the keyframe animation begins.
    let animReady = $state(false)
    onMount(() => {
        requestAnimationFrame(() => { animReady = true })
    })

    // hoveredPreview is set by ContextContent (via $bindable) and read here to
    // render the preview panel without prop-drilling all item state up to the shell.
    let hoveredPreview = $state(null)
</script>

<svelte:window
    onmousemove={drag.onWinMouseMove}
    onmouseup={drag.onWinMouseUp}
/>

<div
    class="ctx-wrap anim-{effectiveAnimation}"
    class:anim-ready={animReady}
    class:is-dragging={drag.dragging}
    class:ctx-inactive={!active}
    class:is-closing={closing}
    style="top:{drag.pos.y}px; left:{drag.pos.x}px"
>

    {#if hoveredPreview}
        <div class="ctx-preview"
            class:is-left={drag.previewOnLeft}
            in:fly={{ x: drag.previewOnLeft ? -12 : 12, duration: 120 }}
            out:fly={{ x: drag.previewOnLeft ? -12 : 12, duration: 80 }}
        >
            {#if hoveredPreview.image}
                <img src={safeUrl(hoveredPreview.image)} alt="" class="preview-img" />
            {/if}
            {#if hoveredPreview.title}
                <div class="preview-title">{hoveredPreview.title}</div>
            {/if}
            {#if hoveredPreview.desc}
                <div class="preview-desc">{hoveredPreview.desc}</div>
            {/if}
            {#if hoveredPreview.stats?.length}
                <div class="preview-stats">
                    {#each hoveredPreview.stats as s}
                        {@const pc = s.max > 0 ? Math.min(100, s.value / s.max * 100) : 0}
                        {@const sc = statColor(s.value, s.max, s.color)}
                        <div class="ps-item">
                            <div class="ps-row">
                                <span class="ps-label">{s.label}</span>
                                <span class="ps-val" style="color:{safeCss(sc)}">{s.value}/{s.max}</span>
                            </div>
                            <div class="ps-bar-bg"><div class="ps-bar-fill" style="width:{pc}%;background:{safeCss(sc)}"></div></div>
                        </div>
                    {/each}
                </div>
            {/if}
        </div>
    {/if}

    <ContextContent
        {data}
        {onCallback}
        {navMode}
        {meta}
        {active}
        {menuId}
        {compactMode}
        {uiSounds}
        onDragStart={drag.startDrag}
        bind:hoveredPreview={hoveredPreview}
    />

</div>
