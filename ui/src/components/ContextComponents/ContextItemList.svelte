<script lang="ts">
    import '../../styles/ContextItemList.css'
    import { fly } from 'svelte/transition'
    import LucideIcon from '../LucideIcon.svelte'
    import { ChevronLeft, ChevronRight, Check, Minus, Plus, ChevronDown, ChevronUp, Lock } from 'lucide-svelte'
    import { useContextItemList } from './useContextItemList.svelte.ts'

    let {
        virtualItemsWithIndex,
        topSpacerHeight,
        bottomSpacerHeight,
        searchQuery,
        searchFilteredLength,
        showPagination,
        currentPage = $bindable(0),
        totalPages = 1,
        ref        = $bindable(null),
        onScrollUpdate,
    } = $props()

    // All shared reactive state + actions come from Context.svelte via setContext.
    // JS getter/setter property accessors let this component both read AND write
    // Context's $state variables without prop drilling or extra indirection.
    const il = useContextItemList()
    const ctx = il.ctx
</script>

<div class="ctx-items"
    bind:this={ref}
    bind:clientHeight={il.clientHeight}
    onscroll={(e) => onScrollUpdate?.(e.currentTarget.scrollTop)}>

    {#if topSpacerHeight > 0}
        <div style="height:{topSpacerHeight}px;flex-shrink:0;pointer-events:none" aria-hidden="true"></div>
    {/if}

    {#each virtualItemsWithIndex as {item: baseItem, i} (baseItem.id)}
        {@const item = ctx.liveOverrides[baseItem.id] ? { ...baseItem, ...ctx.liveOverrides[baseItem.id] } : baseItem}

        {#if item.kind === 'separator'}
            <div class="ctx-sep"></div>

        {:else if item.kind === 'header'}
            <div class="ctx-hdr ctx-hdr-{item.align ?? 'left'}"
                style={item.color ? `color:${ctx.safeCss(item.color)}` : ''}
            >{item.label}</div>

        <!-- accordion_start: collapsible section header ──────────────────── -->
        {:else if item.kind === 'accordion_start'}
            {@const isOpen = ctx.openAccordions.has(item.id)}
            <button class="ctx-accordion"
                class:is-focused={ctx.focused === i}
                class:is-open={isOpen}
                aria-expanded={isOpen}
                onmouseenter={() => ctx.focused = i}
                onclick={() => { ctx.playSound?.('select'); ctx.toggleAccordion(item.id) }}>
                {#if item.icon}<span class="btn-icon"><LucideIcon name={item.icon} size={14} /></span>{/if}
                <span class="btn-label">{item.label}</span>
                <span class="acc-chevron">{#if isOpen}<ChevronUp size={12} />{:else}<ChevronDown size={12} />{/if}</span>
            </button>

        <!-- button ──────────────────────────────────────────────────────────── -->
        {:else if item.kind === 'button' && item.visible !== false}
            {@const isHeld     = ctx.holdState.id === item.id}
            {@const cooling    = ctx.isCooling(item.id)}
            {@const cdMs       = cooling ? ctx.cdRemaining(item.id) : 0}
            {@const isTimedOut = ctx.timedOutIds.has(item.id)}
            {@const isDisabled = item.disabled || cooling || isTimedOut}
            <button
                class="ctx-btn"
                class:is-focused={ctx.focused === i}
                class:is-disabled={isDisabled}
                class:has-gradient={item.gradient}
                class:is-hold={isHeld}
                class:is-cooling={cooling}
                class:is-timed-out={isTimedOut}
                style={item.color ? `--btn-color:${ctx.safeCss(item.color)}` : ''}
                disabled={isDisabled}
                onmouseenter={() => {
                    ctx.focused = i
                    if (item.preview) { ctx.hoveredItemId = item.id; ctx.previewSource = 'mouse' }
                }}
                onmouseleave={() => {
                    if (ctx.previewSource === 'mouse') { ctx.hoveredItemId = null; ctx.hoveredPreview = null; ctx.previewSource = 'none' }
                    if (item.confirm_hold) ctx.cancelHold()
                }}
                onmousedown={() => { if (item.confirm_hold && !isDisabled) ctx.startHold(item) }}
                onmouseup={ctx.cancelHold}
                onclick={() => {
                    if (!isDisabled && !item.confirm_hold) {
                        ctx.onCallback(item.id); ctx.startCooldown(item)
                    }
                }}
            >
                {#if isHeld}
                    <div class="hold-fill" style="width:{ctx.holdState.progress * 100}%"></div>
                {/if}
                {#if cooling}
                    <div class="cd-bar" style="width:{((item.cooldown - cdMs) / item.cooldown * 100)}%"></div>
                {/if}
                {#if cooling}
                    <span class="btn-icon btn-lock"><Lock size={13} /></span>
                {:else if item.icon}
                    <span class="btn-icon"><LucideIcon name={item.icon} size={14} /></span>
                {/if}
                <span class="btn-label">{item.label}</span>
                {#if cooling}
                    <span class="btn-cooldown">{(cdMs/1000).toFixed(1)}s</span>
                {:else}
                    {#if item.badge}  <span class="btn-badge">{item.badge}</span>      {/if}
                    {#if item.hint}   <span class="btn-hint">{item.hint}</span>        {/if}
                    {#if item.hotkey} <kbd class="btn-hotkey">{item.hotkey}</kbd>      {/if}
                    {#if item.arrow}  <span class="btn-arrow"><ChevronRight size={12} /></span>{/if}
                {/if}
            </button>

        <!-- slider ──────────────────────────────────────────────────────────── -->
        {:else if item.kind === 'slider' && item.visible !== false}
            {@const val        = ctx.states[item.id] ?? item.min}
            {@const pct        = item.max > item.min ? (val-item.min)/(item.max-item.min)*100 : 0}
            {@const isTimedOut = ctx.timedOutIds.has(item.id)}
            <div class="ctx-row" class:is-focused={ctx.focused === i} class:is-timed-out={isTimedOut}
                onmouseenter={() => ctx.focused = i} role="slider"
                aria-valuenow={val} aria-valuemin={item.min} aria-valuemax={item.max} tabindex="-1">
                <div class="row-left">
                    {#if item.icon}<span class="btn-icon"><LucideIcon name={item.icon} size={14} /></span>{/if}
                    <span class="row-label">{item.label}</span>
                </div>
                <div class="slider-right">
                    <span class="slider-val">{val}{item.suffix}</span>
                    <div class="slider-track">
                        <input type="range" min={item.min} max={item.max} step={item.step} value={val}
                            style="--pct:{pct}%"
                            disabled={isTimedOut}
                            oninput={(e) => { if (!isTimedOut) { const v=Number(e.currentTarget.value); ctx.states[item.id]=v; ctx.onCallback(item.id,{value:v}) } }} />
                    </div>
                </div>
            </div>

        <!-- stepper ─────────────────────────────────────────────────────────── -->
        {:else if item.kind === 'stepper' && item.visible !== false}
            {@const val        = ctx.states[item.id] ?? item.min}
            {@const isTimedOut = ctx.timedOutIds.has(item.id)}
            <div class="ctx-row" class:is-focused={ctx.focused === i} class:is-timed-out={isTimedOut}
                onmouseenter={() => ctx.focused = i} role="group" tabindex="-1">
                <div class="row-left">
                    {#if item.icon}<span class="btn-icon"><LucideIcon name={item.icon} size={14} /></span>{/if}
                    <span class="row-label">{item.label}</span>
                </div>
                <div class="stepper-ctrl">
                    <button class="step-btn" onclick={() => ctx.stepStepper(item,-1)} disabled={val<=item.min || isTimedOut}><Minus size={11}/></button>
                    <span class="step-val">{val}{item.suffix}</span>
                    <button class="step-btn" onclick={() => ctx.stepStepper(item, 1)} disabled={val>=item.max || isTimedOut}><Plus  size={11}/></button>
                </div>
            </div>

        <!-- checkbox ────────────────────────────────────────────────────────── -->
        {:else if item.kind === 'checkbox' && item.visible !== false}
            {@const checked    = ctx.states[item.id] ?? false}
            {@const isTimedOut = ctx.timedOutIds.has(item.id)}
            <button class="ctx-btn" class:is-focused={ctx.focused === i} class:is-timed-out={isTimedOut} class:is-disabled={isTimedOut}
                disabled={isTimedOut}
                onmouseenter={() => ctx.focused = i} onclick={() => { if (!isTimedOut) ctx.toggleBool(item) }}>
                {#if item.icon}<span class="btn-icon"><LucideIcon name={item.icon} size={14} /></span>{/if}
                <span class="btn-label">{item.label}</span>
                <span class="checkbox-box" class:is-checked={checked}>{#if checked}<Check size={13}/>{/if}</span>
            </button>

        <!-- toggle ──────────────────────────────────────────────────────────── -->
        {:else if item.kind === 'toggle' && item.visible !== false}
            {@const on         = ctx.states[item.id] ?? false}
            {@const isTimedOut = ctx.timedOutIds.has(item.id)}
            <button class="ctx-btn" class:is-focused={ctx.focused === i} class:is-timed-out={isTimedOut} class:is-disabled={isTimedOut}
                disabled={isTimedOut}
                onmouseenter={() => ctx.focused = i} onclick={() => { if (!isTimedOut) ctx.toggleBool(item) }}>
                {#if item.icon}<span class="btn-icon"><LucideIcon name={item.icon} size={14} /></span>{/if}
                <span class="btn-label">{item.label}</span>
                <span class="toggle-track" class:is-on={on}><span class="toggle-knob"></span></span>
            </button>

        <!-- list ────────────────────────────────────────────────────────────── -->
        {:else if item.kind === 'list' && item.visible !== false}
            {@const idx        = ctx.states[item.id] ?? 0}
            {@const isHeld     = ctx.holdState.id === item.id}
            {@const isTimedOut = ctx.timedOutIds.has(item.id)}
            <div class="ctx-row ctx-row-list" class:is-focused={ctx.focused === i} class:is-hold={isHeld} class:is-timed-out={isTimedOut}
                onmouseenter={() => ctx.focused = i} role="listbox" tabindex="-1"
                onmousedown={() => { if (item.confirm_hold && !isTimedOut) ctx.startHold(item) }}
                onmouseup={() => { if (item.confirm_hold) ctx.cancelHold() }}
                onmouseleave={() => { if (item.confirm_hold) ctx.cancelHold() }}
                onclick={() => {
                    if (!item.confirm_hold && !isTimedOut) { ctx.playSound?.('select'); ctx.onCallback(item.id, { index: idx + 1, value: item.items?.[idx] ?? '' }) }
                }}
                onkeydown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault()
                        if (isTimedOut) return
                        if (item.confirm_hold) ctx.startHold(item)
                        else ctx.onCallback(item.id, { index: idx + 1, value: item.items?.[idx] ?? '' })
                    }
                }}
                onkeyup={(e) => { if ((e.key === 'Enter' || e.key === ' ') && item.confirm_hold) ctx.cancelHold() }}
            >
                {#if isHeld}
                    <div class="hold-fill" style="width:{ctx.holdState.progress * 100}%"></div>
                {/if}
                <div class="row-left">
                    {#if item.icon}<span class="btn-icon"><LucideIcon name={item.icon} size={14} /></span>{/if}
                    <span class="row-label">{item.label}</span>
                </div>
                <div class="list-ctrl">
                    <button class="list-arrow" onclick={(e) => { e.stopPropagation(); if (!isTimedOut) ctx.stepList(item,-1) }} disabled={isTimedOut}><ChevronLeft  size={12}/></button>
                    <span class="list-val">{item.items?.[idx] ?? ''}</span>
                    <button class="list-arrow" onclick={(e) => { e.stopPropagation(); if (!isTimedOut) ctx.stepList(item, 1) }} disabled={isTimedOut}><ChevronRight size={12}/></button>
                </div>
            </div>

        <!-- stat ────────────────────────────────────────────────────────────── -->
        {:else if item.kind === 'stat' && item.visible !== false}
            {@const pct   = item.max > 0 ? Math.min(100, item.value/item.max*100) : 0}
            {@const color = ctx.statColor(item.value, item.max, item.color)}
            <div class="ctx-stat">
                <div class="stat-header">
                    {#if item.icon}<span class="btn-icon"><LucideIcon name={item.icon} size={13}/></span>{/if}
                    <span class="stat-label">{item.label}</span>
                    <span class="stat-value" style="color:{ctx.safeCss(color)}">{item.value}{item.suffix} / {item.max}{item.suffix}</span>
                </div>
                <div class="stat-bar-bg">
                    <div class="stat-bar-fill" style="width:{ctx.mounted?pct:0}%; background:{ctx.safeCss(color)}"></div>
                </div>
            </div>

        <!-- input_inline ─────────────────────────────────────────────────────── -->
        {:else if item.kind === 'input_inline' && item.visible !== false}
            <div class="ctx-row ctx-input-row" class:is-focused={ctx.focused === i}
                onmouseenter={() => ctx.focused = i} role="group" tabindex="-1">
                <div class="row-left">
                    {#if item.icon}<span class="btn-icon"><LucideIcon name={item.icon} size={14}/></span>{/if}
                    <span class="row-label">{item.label}</span>
                </div>
                <input
                    class="inline-input"
                    type={item.inputType ?? 'text'}
                    placeholder={item.placeholder ?? ''}
                    maxlength={item.maxlen}
                    min={item.min} max={item.max}
                    value={ctx.states[item.id]}
                    bind:this={ctx.inputRefs[item.id]}
                    oninput={(e) => { ctx.states[item.id] = e.currentTarget.value }}
                    onblur={(e) => {
                        if (!ctx.inputEnterFired.has(item.id)) {
                            ctx.onCallback(item.id, { value: e.currentTarget.value })
                        }
                        ctx.inputEnterFired.delete(item.id)
                    }}
                    onkeydown={(e) => {
                        if (e.key === 'Enter') {
                            ctx.inputEnterFired.add(item.id)
                            ctx.onCallback(item.id, { value: ctx.states[item.id] })
                            e.currentTarget.blur()
                        }
                        if (e.key === 'Escape') {
                            ctx.inputEnterFired.add(item.id)
                            e.currentTarget.blur()
                        }
                    }}
                />
            </div>

        <!-- color_picker ─────────────────────────────────────────────────────── -->
        {:else if item.kind === 'color_picker' && item.visible !== false}
            {@const curColor = ctx.states[item.id] ?? item.default ?? '#e94560'}
            {@const presets  = item.presets ?? ctx.PRESET_COLORS}
            <div class="ctx-row" class:is-focused={ctx.focused === i}
                onmouseenter={() => ctx.focused = i} role="group" tabindex="-1">
                <div class="row-left">
                    {#if item.icon}<span class="btn-icon"><LucideIcon name={item.icon} size={14}/></span>{/if}
                    <span class="row-label">{item.label}</span>
                </div>
                <button class="color-swatch-btn"
                    onclick={() => {
                        ctx.playSound?.('select')
                        ctx.openPopover = ctx.openPopover === item.id ? null : item.id
                        if (ctx.openPopover) ctx.colorFocusIdx = presets.indexOf(curColor)
                    }}>
                    <span class="color-swatch" style="background:{ctx.safeCss(curColor)}"></span>
                    <span class="color-hex">{curColor}</span>
                    <ChevronDown size={10}/>
                </button>
            </div>
            {#if ctx.openPopover === item.id}
                <div class="color-popover" in:fly={{ y: -6, duration: 100 }}>
                    <div class="color-presets">
                        {#each presets as c, ci}
                            <button class="preset-dot"
                                class:is-selected={curColor === c}
                                class:is-key-focused={ctx.colorFocusIdx === ci && ctx.effectiveNav !== 'mouse'}
                                style="background:{ctx.safeCss(c)}"
                                onclick={() => { ctx.playSound?.('select'); ctx.selectColor(item, c); ctx.openPopover = null }}
                                title={c}>
                            </button>
                        {/each}
                    </div>
                    <div class="color-bottom">
                        <label class="color-custom">
                            <span>Personnalisé</span>
                            <input type="color" value={curColor}
                                oninput={(e) => ctx.selectColor(item, e.currentTarget.value)} />
                        </label>
                        <input
                            type="text"
                            class="color-hex-input"
                            maxlength="7"
                            spellcheck="false"
                            placeholder="#e94560"
                            value={curColor}
                            bind:this={ctx.colorHexRef}
                            oninput={(e) => {
                                const v = e.currentTarget.value.trim()
                                if (/^#[0-9a-fA-F]{6}$/.test(v)) ctx.selectColor(item, v)
                            }}
                            onblur={(e) => {
                                if (!/^#[0-9a-fA-F]{6}$/.test(e.currentTarget.value.trim()))
                                    e.currentTarget.value = curColor
                                ctx.colorFocusIdx = -1
                            }}
                            onkeydown={(e) => {
                                if (e.key === 'Enter') { e.preventDefault(); ctx.openPopover = null }
                                if (e.key === 'ArrowUp') { e.preventDefault(); ctx.colorHexRef?.blur(); ctx.colorFocusIdx = (presets?.length ?? ctx.PRESET_COLORS.length) - 1 }
                            }}
                        />
                    </div>
                </div>
            {/if}

        <!-- date_picker ──────────────────────────────────────────────────────── -->
        {:else if item.kind === 'date_picker' && item.visible !== false}
            {@const df     = ctx.states[item.id] ?? ctx.parseDateFields(item.default)}
            {@const fields = ctx.getDateFieldOrder(item.format, item)}
            <div class="ctx-row ctx-date-row" class:is-focused={ctx.focused === i}
                onmouseenter={() => ctx.focused = i} role="group" tabindex="-1">
                <div class="row-left">
                    {#if item.icon}<span class="btn-icon"><LucideIcon name={item.icon} size={14}/></span>{/if}
                    <span class="row-label">{item.label}</span>
                </div>
                <div class="date-ctrl">
                    {#each fields as field, fi}
                        {#if fi > 0}<span class="date-sep">/</span>{/if}
                        <input
                            class="date-field {field.cls}"
                            type="number"
                            min={field.min}
                            max={field.max}
                            value={field.get(df)}
                            data-date-picker-id={item.id}
                            bind:this={ctx.dateFieldRefs[item.id + '_' + fi]}
                            oninput={(e) => {
                                const v = Math.min(field.max, Math.max(field.min, parseInt(e.currentTarget.value) || field.min))
                                ctx.states[item.id] = field.set(df, v)
                            }}
                            onblur={(e) => {
                                const next = e.relatedTarget as HTMLElement | null
                                if (next && next.dataset['datePickerId'] === item.id) return
                                ctx.fireDateCb(item.id, ctx.states[item.id] ?? df)
                            }}
                            onkeydown={(e) => {
                                if (e.key === 'Enter') {
                                    e.preventDefault()
                                    if (fi < fields.length - 1) {
                                        ctx.dateFieldRefs[item.id + '_' + (fi + 1)]?.focus()
                                    } else {
                                        const curDf = ctx.states[item.id] ?? df
                                        ctx.fireDateCb(item.id, curDf)
                                        e.currentTarget.blur()
                                    }
                                }
                            }}
                        />
                    {/each}
                </div>
            </div>

        {/if}
    {/each}

    {#if bottomSpacerHeight > 0}
        <div style="height:{bottomSpacerHeight}px;flex-shrink:0;pointer-events:none" aria-hidden="true"></div>
    {/if}
</div>

{#if searchQuery && searchFilteredLength === 0}
    <div class="ctx-no-results">Aucun résultat pour « {searchQuery} »</div>
{/if}

{#if showPagination}
    <div class="ctx-pager">
        <button class="pager-btn" onclick={() => { ctx.playSound?.('nav'); currentPage--; ctx.focused = -1 }} disabled={currentPage===0}><ChevronLeft size={12}/></button>
        <span class="pager-info">{currentPage+1} / {totalPages}</span>
        <button class="pager-btn" onclick={() => { ctx.playSound?.('nav'); currentPage++; ctx.focused = -1 }} disabled={currentPage>=totalPages-1}><ChevronRight size={12}/></button>
    </div>
{/if}