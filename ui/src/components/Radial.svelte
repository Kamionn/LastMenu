<script>
    import '../styles/Radial.css'
    import LucideIcon from './LucideIcon.svelte'
    import { hasLucideIcon } from '../utils/icons.js'
    import { useRadial } from './RadialComponents/useRadial.svelte.ts'

    let { data, onCallback, closing = false } = $props()

    const r = useRadial(() => data, (id) => onCallback(id))
</script>

<svelte:window onkeydown={r.handleKeydown} onkeyup={r.handleKeyup} />

<!-- svelte-ignore a11y_click_events_have_key_events -- keyboard handled by <svelte:window> above -->
<div
    class="radial-overlay"
    class:is-closing={closing}
    onmousemove={r.handleMousemove}
    onclick={r.handleClick}
    onmousedown={r.handleMousedown}
    onmouseup={r.handleMouseup}
    onmouseleave={r.handleMouseup}
    role="menu"
    tabindex="-1"
>
    <!-- Backdrop blur -->
    <div class="radial-backdrop"></div>

    <div class="radial-container" bind:this={r.containerEl}>

        <svg width={r.SIZE} height={r.SIZE} class="radial-svg" aria-hidden="true" overflow="visible">

            <!-- Active arc shadow/glow — rendered below -->
            {#if r.selectedIndex >= 0}
                <path
                    d={r.arcPath(r.selectedIndex)}
                    class="arc-glow"
                />
            {/if}

            <!-- Background arcs -->
            {#each r.liveButtons as btn, i (btn.id)}
                <path
                    d={r.arcPath(i)}
                    class="arc"
                    class:arc-active={i === r.selectedIndex}
                    class:arc-disabled={btn.disabled}
                />
            {/each}

            <!-- Decorative inner ring -->
            <circle cx={r.SIZE/2} cy={r.SIZE/2} r={r.INNER_R} class="inner-ring" />
            <circle cx={r.SIZE/2} cy={r.SIZE/2} r={r.INNER_R - 8} class="inner-ring-inner" />

            <!-- Hold-to-confirm: arc progress ring around the inner circle -->
            {#if r.holdState.id !== null}
                <circle
                    cx={r.SIZE/2} cy={r.SIZE/2} r={r.HOLD_R}
                    class="hold-ring"
                    stroke-dasharray="{r.holdState.progress * r.HOLD_CIRC} {r.HOLD_CIRC}"
                    transform="rotate(-90 {r.SIZE/2} {r.SIZE/2})"
                />
            {/if}

            <!-- Outer labels — in SVG to stay within the overflow:visible viewport -->
            {#each r.liveButtons as btn, i (btn.id)}
                {#if !btn.disabled}
                    {@const lp     = r.labelPos(i)}
                    {@const active = i === r.selectedIndex}
                    <text
                        x={lp.x}
                        y={lp.y}
                        class="sector-label-svg"
                        class:label-active={active}
                        text-anchor={lp.align === 'left' ? 'start' : lp.align === 'right' ? 'end' : 'middle'}
                        dominant-baseline="middle"
                    >{btn.label}{btn.has_submenu ? ' ›' : ''}</text>
                {/if}
            {/each}

        </svg>

        <!-- Center: selected label > center_label > dot -->
        <div class="center-area">
            {#if r.selectedIndex >= 0}
                <span class="center-text">{r.selectedLabel}</span>
            {:else if data.center_label}
                <span class="center-text center-text-idle">{data.center_label}</span>
            {:else}
                <div class="center-dot"></div>
            {/if}
        </div>

        <!-- HTML icons overlaid on top of the SVG -->
        {#each r.liveButtons as btn, i (btn.id)}
            {@const pos    = r.iconCenter(i)}
            {@const active = i === r.selectedIndex}
            <div
                class="sector-icon"
                class:icon-active={active}
                class:icon-disabled={btn.disabled}
                style="left:{pos.x}px; top:{pos.y}px"
                aria-hidden="true"
            >
                {#if btn.icon && hasLucideIcon(btn.icon)}
                    <LucideIcon name={btn.icon} size={18} />
                {:else}
                    <span class="icon-fallback">{btn.icon ? btn.icon.slice(0,2).toUpperCase() : '•'}</span>
                {/if}
                {#if btn.has_submenu}
                    <span class="submenu-badge">›</span>
                {/if}
            </div>
        {/each}

    </div>
</div>
