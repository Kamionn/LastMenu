<script lang="ts">
    // @ts-nocheck
    import { fly } from 'svelte/transition'
    import { onMount, untrack, setContext } from 'svelte'
    import LucideIcon from '../LucideIcon.svelte'
    import ContextSearch    from './ContextSearch.svelte'
    import ContextTabs      from './ContextTabs.svelte'
    import ContextItemList  from './ContextItemList.svelte'
    import { GripVertical } from 'lucide-svelte'
    import { safeCss, safeUrl, parseDateFields, composeDateISO, getDateFieldOrder, statColor } from './contextUtils.js'
    import { useContextCooldown }      from './useContextCooldown.svelte.ts'
    import { useContextKeyboard }      from './useContextKeyboard.svelte.ts'
    import { useContextVirtualScroll } from './useContextVirtualScroll.svelte.ts'
    let {
        data,
        onCallback: _onCallbackProp,
        navMode   = 'both',
        meta,
        active    = true,
        menuId    = '',
        compactMode  = false,
        uiSounds     = false,
        onDragStart,
        hoveredPreview = $bindable(null),
    } = $props()

    // Rate-limit NUI callbacks: prevents click-spam from firing hundreds of
    // callbacks/second for the same item, independent of any user-visible cooldown.
    const _MIN_CB_INTERVAL = 100
    const _lastCbTime = new Map<string, number>()
    function onCallback(id: string, data?: unknown): void {
        const t = Date.now()
        if (t - (_lastCbTime.get(id) ?? 0) < _MIN_CB_INTERVAL) return
        _lastCbTime.set(id, t)
        _onCallbackProp(id, data)
    }

    const cd = useContextCooldown(() => active)

    // liveOverrides: overlay sparse pour les patches Lua.
    let liveOverrides = $state<Record<string, any>>({})

    const items = $derived(data.items ?? [])

    const effectiveNav = $derived(meta.nav !== 'both' ? meta.nav : navMode)

    // ── Tabs ──────────────────────────────────────────────────────────────────
    const hasTabs = $derived(items.some(i => i.kind === 'tab_start'))
    const tabs    = $derived(items.filter(i => i.kind === 'tab_start'))
    let activeTab = $state(null)

    $effect(() => {
        if (hasTabs && tabs.length > 0 && activeTab === null) activeTab = tabs[0].id
    })

    const tabItems = $derived.by(() => {
        if (!hasTabs || !activeTab) return items.filter(i => i.kind !== 'tab_start' && i.kind !== 'tab_end')
        const result = []
        let inside = false
        for (const item of items) {
            if (item.kind === 'tab_start') { inside = item.id === activeTab }
            else if (item.kind === 'tab_end') { inside = false }
            else if (inside) result.push(item)
        }
        return result
    })

    // ── Accordion ─────────────────────────────────────────────────────────────
    let openAccordions = $state(new Set(
        untrack(() => (data.items ?? []).filter(i => i.kind === 'accordion_start' && i.defaultOpen).map(i => i.id))
    ))

    function toggleAccordion(id) {
        const next = new Set(openAccordions)
        if (next.has(id)) next.delete(id)
        else next.add(id)
        openAccordions = next
    }

    const flatItems = $derived.by(() => {
        const base = hasTabs ? tabItems : items
        const result = []
        const stack = []
        for (const item of base) {
            if (item.kind === 'accordion_start') {
                stack.push({ id: item.id, open: openAccordions.has(item.id) })
                result.push({ item, hidden: false })
            } else if (item.kind === 'accordion_end') {
                stack.pop()
            } else {
                result.push({ item, hidden: stack.length > 0 && stack.some(a => !a.open) })
            }
        }
        return result
    })
    const displayItems = $derived(flatItems.filter(v => !v.hidden).map(v => v.item))

    // ── Search ────────────────────────────────────────────────────────────────
    const SEARCH_KINDS = new Set(['button','slider','stepper','checkbox','toggle','list','stat','input_inline','color_picker','date_picker'])
    let searchQuery = $state('')
    let searchRef   = $state(null)

    const showSearch = $derived(
        meta.search === true ||
        displayItems.filter(i => SEARCH_KINDS.has(i.kind)).length > (meta.pageSize ?? 20)
    )

    $effect(() => {
        const q = searchQuery.toLowerCase().trim()
        if (!q) return
        const base = hasTabs ? tabItems : items
        let insideAcc = null
        for (const item of base) {
            if (item.kind === 'accordion_start') {
                insideAcc = item.id
            } else if (item.kind === 'accordion_end') {
                insideAcc = null
            } else if (insideAcc && SEARCH_KINDS.has(item.kind) && (item.label ?? '').toLowerCase().includes(q)) {
                if (!openAccordions.has(insideAcc)) {
                    const next = new Set(openAccordions)
                    next.add(insideAcc)
                    openAccordions = next
                }
            }
        }
    })

    const searchFiltered = $derived.by(() => {
        const q = searchQuery.toLowerCase().trim()
        if (!q) return displayItems
        return displayItems.filter(i => !SEARCH_KINDS.has(i.kind) || (i.label ?? '').toLowerCase().includes(q))
    })

    // ── Scroll mode vs Pagination ─────────────────────────────────────────────
    const scrollMode = $derived(meta.scroll === true)

    // ── Pagination ────────────────────────────────────────────────────────────
    let currentPage = $state(0)
    const pageSize       = $derived(meta.pageSize ?? 20)
    const totalPages     = $derived(scrollMode ? 1 : Math.max(1, Math.ceil(searchFiltered.length / pageSize)))
    const pagedItems     = $derived(scrollMode ? searchFiltered : searchFiltered.slice(currentPage * pageSize, (currentPage + 1) * pageSize))
    const showPagination = $derived(!scrollMode && totalPages > 1)

    // ── Virtual Scrolling ─────────────────────────────────────────────────────
    let itemsListRef = $state(null)

    const vs = useContextVirtualScroll({
        getScrollMode:    () => scrollMode,
        getPagedItems:    () => pagedItems,
        getCompactMode:   () => compactMode,
        getSearchQuery:   () => searchQuery,
        getItemsListRef:  () => itemsListRef,
        getOpenPopoverId: () => openPopover,
    })

    function handleSearch(e) { searchQuery = e.target.value; currentPage = 0; focused = -1 }

    // ── Item timeout (auto-disable) ───────────────────────────────────────────
    const TIMEOUT_KINDS = new Set(['button','slider','stepper','checkbox','toggle','list','color_picker','date_picker','input_inline'])
    let timedOutIds = $state(new Set())

    $effect(() => {
        const timeouts = []
        for (const item of (data.items ?? [])) {
            if (TIMEOUT_KINDS.has(item.kind) && item.timeout != null && item.timeout > 0) {
                const t = setTimeout(() => {
                    timedOutIds = new Set([...timedOutIds, item.id])
                }, item.timeout)
                timeouts.push(t)
            }
        }
        return () => { for (const t of timeouts) clearTimeout(t) }
    })

    // ── Local item states ─────────────────────────────────────────────────────
    let states = $state((() => {
        const s = {}
        for (const item of (data.items ?? [])) {
            if (item.kind === 'slider'  || item.kind === 'stepper')
                s[item.id] = item.value ?? item.min ?? 0
            else if (item.kind === 'checkbox' || item.kind === 'toggle')
                s[item.id] = item.value ?? false
            else if (item.kind === 'list')
                s[item.id] = item.index ?? 0
            else if (item.kind === 'input_inline')
                s[item.id] = item.default ?? ''
            else if (item.kind === 'color_picker')
                s[item.id] = item.default ?? '#e94560'
            else if (item.kind === 'date_picker')
                s[item.id] = parseDateFields(item.default)
        }
        return s
    })())

    // ── Keyboard navigation ───────────────────────────────────────────────────
    let focused = $state(-1)

    let inputRefs     = $state({})
    let dateFieldRefs = $state({})

    function fireDateCb(itemId, df) {
        if (df) onCallback(itemId, { value: composeDateISO(df.d, df.m, df.y) })
    }

    let inputEnterFired = new Set()

    // ── Hover preview panel ───────────────────────────────────────────────────
    let previewSource  = $state('none')
    let hoveredItemId  = $state<string | null>(null)

    // Keyboard show/hide: reactive to focused/pagedItems ONLY.
    // liveOverrides and previewSource read via untrack — no reactive dep on either.
    // Prevents ghost preview when patches arrive while not actively interacting.
    $effect(() => {
        const base    = pagedItems[focused]
        const src     = untrack(() => previewSource)
        const preview = base
            ? untrack(() => (liveOverrides[base.id] ? { ...base, ...liveOverrides[base.id] } : base).preview ?? null)
            : null
        if (preview && src !== 'mouse') {
            hoveredPreview = preview
            previewSource  = 'keyboard'
        } else if (!preview && src === 'keyboard') {
            hoveredPreview = null
            previewSource  = 'none'
        }
    })

    // Live update: reactive to liveOverrides, but ONLY while actively hovering.
    // When previewSource is 'none', returns early and holds no liveOverrides dep —
    // patches never retrigger it in idle state.
    $effect(() => {
        if (previewSource === 'mouse' && hoveredItemId) {
            const base = displayItems.find(i => i.id === hoveredItemId)
            if (!base) return
            const merged = liveOverrides[hoveredItemId] ? { ...base, ...liveOverrides[hoveredItemId] } : base
            if (merged.preview) hoveredPreview = merged.preview
        } else if (previewSource === 'keyboard') {
            const base = pagedItems[focused]
            if (!base) return
            const merged = liveOverrides[base.id] ? { ...base, ...liveOverrides[base.id] } : base
            if (merged.preview) hoveredPreview = merged.preview
        }
    })

    // ── Hold-to-confirm ───────────────────────────────────────────────────────
    let holdState  = $state({ id: null, progress: 0 })
    let holdStart  = null
    let holdRAF    = null

    function startHold(item) {
        const duration = (typeof item.confirm_hold === 'number' && item.confirm_hold > 0)
            ? item.confirm_hold
            : 1500
        holdStart = performance.now()
        holdState = { id: item.id, progress: 0 }
        function tick(now) {
            const p = Math.min(1, (now - holdStart) / duration)
            holdState = { id: item.id, progress: p }
            if (p < 1) holdRAF = requestAnimationFrame(tick)
            else { holdState = { id: null, progress: 0 }; onCallback(item.id); cd.startCooldown(item) }
        }
        holdRAF = requestAnimationFrame(tick)
    }
    function cancelHold() {
        if (holdRAF) cancelAnimationFrame(holdRAF)
        holdRAF = null; holdStart = null
        holdState = { id: null, progress: 0 }
    }

    // ── Color picker ──────────────────────────────────────────────────────────
    let openPopover   = $state(null)
    let colorFocusIdx = $state(-1)
    let colorHexRef   = $state(null)

    const PRESET_COLORS = [
        '#e94560','#f87171','#fb923c','#fbbf24','#facc15',
        '#4ade80','#34d399','#22d3ee','#60a5fa','#818cf8',
        '#c084fc','#f472b6','#ffffff','#94a3b8','#475569','#0f172a',
    ]
    function selectColor(item, c) {
        states[item.id] = c
        onCallback(item.id, { value: c })
    }

    // ── Stat bar animation ────────────────────────────────────────────────────
    let mounted = $state(false)

    onMount(() => {
        setTimeout(() => { mounted = true }, 60)
        cd.mount(data.items ?? [])

        function applyPatchChanges(changes) {
            for (const change of changes) {
                liveOverrides[change.id] = { ...(liveOverrides[change.id] ?? {}), ...change }
            }
        }

        function onPatch(event) {
            const msg = event.data
            if (!msg) return
            if (msg.type === 'batch') {
                for (const sub of msg.messages) {
                    if (sub.type === 'patch' && sub.id === menuId && sub.changes?.length) {
                        applyPatchChanges(sub.changes)
                    }
                }
                return
            }
            if (msg.type !== 'patch') return
            if (msg.id !== menuId) return
            const changes = msg.changes || []
            if (!changes.length) return
            applyPatchChanges(changes)
        }
        window.addEventListener('message', onPatch)

        return () => {
            cd.unmount()
            if (holdRAF) cancelAnimationFrame(holdRAF)
            window.removeEventListener('message', onPatch)
        }
    })

    // ── Item interaction helpers ──────────────────────────────────────────────
    function stepSlider(item, dir) {
        const v = Math.min(item.max, Math.max(item.min, (states[item.id] ?? item.min) + dir * item.step))
        states[item.id] = v; onCallback(item.id, { value: v })
    }
    function stepStepper(item, dir) {
        const v = Math.min(item.max, Math.max(item.min, (states[item.id] ?? item.min) + dir * item.step))
        states[item.id] = v; onCallback(item.id, { value: v })
    }
    function toggleBool(item) {
        states[item.id] = !states[item.id]; onCallback(item.id, { value: states[item.id] })
    }
    function stepList(item, dir) {
        const len = item.items?.length ?? 0; if (!len) return
        const v = ((states[item.id] ?? 0) + dir + len) % len
        states[item.id] = v; onCallback(item.id, { index: v+1, value: item.items[v] })
    }

    // ── Keyboard composable ───────────────────────────────────────────────────
    const kb = useContextKeyboard({
        getActive:        () => active,
        getEffectiveNav:  () => effectiveNav,
        getShowSearch:    () => showSearch,
        getSearchRef:     () => searchRef,
        setSearchQuery:   (v) => { searchQuery = v },
        setCurrentPage:   (v) => { currentPage = v },
        getHasTabs:       () => hasTabs,
        getTabs:          () => tabs,
        getActiveTab:     () => activeTab,
        setActiveTab:     (v) => { activeTab = v },
        getFocused:       () => focused,
        setFocused:       (v) => { focused = v },
        getCurrentPage:   () => currentPage,
        getTotalPages:    () => totalPages,
        getPagedItems:    () => pagedItems,
        getTimedOutIds:   () => timedOutIds,
        getOpenPopover:   () => openPopover,
        setOpenPopover:   (v) => { openPopover = v },
        getColorFocusIdx: () => colorFocusIdx,
        setColorFocusIdx: (v) => { colorFocusIdx = v },
        getColorHexRef:   () => colorHexRef,
        getStates:        () => states,
        getInputRefs:     () => inputRefs,
        getDateFieldRefs: () => dateFieldRefs,
        getItemsListRef:  () => itemsListRef,
        PRESET_COLORS,
        onCallback: (...args) => onCallback(...args),
        cd,
        startHold,
        cancelHold,
        selectColor,
        toggleAccordion,
        toggleBool,
        stepSlider,
        stepStepper,
        stepList,
    })

    // ── Share reactive state + actions with ContextItemList ───────────────────
    setContext('ctx', {
        get states()              { return states },
        get focused()             { return focused },
        set focused(v)            { focused = v },
        get holdState()           { return holdState },
        get liveOverrides()       { return liveOverrides },
        get timedOutIds()         { return timedOutIds },
        get openAccordions()      { return openAccordions },
        set openAccordions(v)     { openAccordions = v },
        get mounted()             { return mounted },
        get effectiveNav()        { return effectiveNav },
        get hoveredPreview()      { return hoveredPreview },
        set hoveredPreview(v)     { hoveredPreview = v },
        get hoveredItemId()       { return hoveredItemId },
        set hoveredItemId(v)      { hoveredItemId = v },
        get previewSource()       { return previewSource },
        set previewSource(v)      { previewSource = v },
        get openPopover()         { return openPopover },
        set openPopover(v)        { openPopover = v },
        get colorFocusIdx()       { return colorFocusIdx },
        set colorFocusIdx(v)      { colorFocusIdx = v },
        get colorHexRef()         { return colorHexRef },
        set colorHexRef(v)        { colorHexRef = v },
        get inputRefs()           { return inputRefs },
        get dateFieldRefs()       { return dateFieldRefs },
        get inputEnterFired()     { return inputEnterFired },
        get PRESET_COLORS()       { return PRESET_COLORS },
        get onCallback()          { return onCallback },
        set containerClientHeight(v) { vs.containerClientHeight = v },
        isCooling: cd.isCooling, cdRemaining: cd.cdRemaining, statColor, safeCss, safeUrl,
        parseDateFields, getDateFieldOrder, composeDateISO, fireDateCb,
        startHold, cancelHold, stepSlider, stepStepper,
        toggleBool, stepList, toggleAccordion, startCooldown: cd.startCooldown, selectColor,
    })
</script>

<svelte:window
    onkeydown={kb.handleKeydown}
    onkeyup={kb.handleKeyup}
/>

<div class="ctx-menu">

    <ContextTabs
        {hasTabs}
        {tabs}
        bind:activeTab
        onChange={() => { currentPage = 0; focused = -1 }}
    />

    {#if meta.banner}
        <div class="ctx-banner" style="background-image:url('{safeUrl(meta.banner)}')"
            onmousedown={onDragStart} role="presentation">
            <div class="drag-hint"><GripVertical size={14} /></div>
            {#if meta.title}<div class="ctx-banner-title">{meta.title}</div>{/if}
        </div>
    {:else if meta.title}
        <div class="ctx-title" onmousedown={onDragStart} role="presentation">
            <span class="title-text">{meta.title}</span>
            <span class="drag-icon"><GripVertical size={13} /></span>
        </div>
    {/if}

    {#if meta.description}
        <div class="ctx-desc">{meta.description}</div>
    {/if}

    <ContextSearch
        show={showSearch}
        bind:value={searchQuery}
        bind:ref={searchRef}
        onInput={handleSearch}
        onEscape={() => { searchQuery = ''; currentPage = 0; searchRef?.blur() }}
    />

    <ContextItemList
        virtualItemsWithIndex={vs.virtualItemsWithIndex}
        topSpacerHeight={vs.topSpacerHeight}
        bottomSpacerHeight={vs.bottomSpacerHeight}
        {searchQuery}
        searchFilteredLength={searchFiltered.length}
        {showPagination}
        bind:currentPage
        {totalPages}
        bind:ref={itemsListRef}
        onScrollUpdate={(top) => { vs.containerScrollTop = top }}
    />

</div>