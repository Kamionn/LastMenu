const NAV_KINDS = ['button','slider','stepper','checkbox','toggle','list','color_picker','date_picker','input_inline','accordion_start']

interface MenuItem {
    id: string
    kind: string
    visible?: boolean
    disabled?: boolean
    confirm_hold?: boolean
    presets?: string[]
    default?: string
}

interface Tab { id: string; [key: string]: unknown }

interface CooldownController {
    isCooling:     (id: string) => boolean
    startCooldown: (item: MenuItem) => void
}

interface KeyboardState {
    getActive:        () => boolean
    getEffectiveNav:  () => string
    getShowSearch:    () => boolean
    getSearchRef:     () => HTMLElement | null
    setSearchQuery:   (v: string) => void
    setCurrentPage:   (v: number) => void
    getHasTabs:       () => boolean
    getTabs:          () => Tab[]
    getActiveTab:     () => string | null
    setActiveTab:     (v: string) => void
    getFocused:       () => number
    setFocused:       (v: number) => void
    getCurrentPage:   () => number
    getTotalPages:    () => number
    getPagedItems:    () => MenuItem[]
    getTimedOutIds:   () => Set<string>
    getOpenPopover:   () => string | null
    setOpenPopover:   (v: string | null) => void
    getColorFocusIdx: () => number
    setColorFocusIdx: (v: number) => void
    getColorHexRef:   () => HTMLElement | null
    getStates:        () => Record<string, unknown>
    getInputRefs:     () => Record<string, HTMLElement>
    getDateFieldRefs: () => Record<string, HTMLElement>
    getItemsListRef:  () => HTMLElement | null
    PRESET_COLORS:    string[]
    onCallback:       (id: string, payload?: unknown) => void
    playSound:        (event: string) => void
    cd:               CooldownController
    startHold:        (item: MenuItem) => void
    cancelHold:       () => void
    selectColor:      (item: MenuItem, c: string) => void
    toggleAccordion:  (id: string) => void
    toggleBool:       (item: MenuItem) => void
    stepSlider:       (item: MenuItem, dir: number) => void
    stepStepper:      (item: MenuItem, dir: number) => void
    stepList:         (item: MenuItem, dir: number) => void
}

interface HeldKey { id: string; key: string }

/**
 * Keyboard navigation composable for Context menu.
 * keyHeldFor is kept local (non-reactive) — it is only read/written
 * inside the keydown/keyup handlers of this composable.
 */
export function useContextKeyboard(state: KeyboardState) {
    let afterPageDir = $state(0)
    let keyHeldFor: HeldKey | null = null

    const navIndices = $derived(
        state.getPagedItems()
            .map((item, i) => ({ item, i }))
            .filter(({ item }) => NAV_KINDS.includes(item.kind) && item.visible !== false && !item.disabled && !state.getTimedOutIds().has(item.id))
            .map(({ i }) => i)
    )

    // Auto-focus first (dir=1) or last (dir=-1) navigable item after a page change
    $effect(() => {
        void navIndices.length
        if (afterPageDir !== 0 && navIndices.length > 0) {
            const d = afterPageDir; afterPageDir = 0
            state.setFocused(d === 1 ? navIndices[0] : navIndices[navIndices.length - 1])
        }
    })

    function scrollFocusedIntoView(): void {
        requestAnimationFrame(() => {
            const ref = state.getItemsListRef()
            if (!ref) return
            const el = ref.querySelector('.is-focused')
            if (el) el.scrollIntoView({ block: 'nearest' })
        })
    }

    function moveFocus(dir: number): void {
        const cur = navIndices.indexOf(state.getFocused())
        if (dir === 1) {
            if (cur < navIndices.length - 1) { state.setFocused(navIndices[cur + 1]) }
            else if (state.getCurrentPage() < state.getTotalPages() - 1) {
                state.setCurrentPage(state.getCurrentPage() + 1); afterPageDir = 1
            } else { state.setFocused(navIndices[0] ?? -1) }
        } else {
            if (cur > 0) { state.setFocused(navIndices[cur - 1]) }
            else if (state.getCurrentPage() > 0) {
                state.setCurrentPage(state.getCurrentPage() - 1); afterPageDir = -1
            } else { state.setFocused(navIndices[navIndices.length - 1] ?? -1) }
        }
        scrollFocusedIntoView()
    }

    function handleKeydown(e: KeyboardEvent): void {
        if (!state.getActive()) return
        if (state.getEffectiveNav() === 'mouse') return

        // '/' — focus the search bar if visible
        if (e.key === '/' && state.getShowSearch() && (e.target as HTMLElement).tagName !== 'INPUT') {
            e.preventDefault()
            state.getSearchRef()?.focus()
            return
        }

        // Escape from the search bar: clear the query and return focus to the menu
        if (e.key === 'Escape' && e.target === state.getSearchRef()) {
            e.preventDefault()
            state.setSearchQuery('')
            state.setCurrentPage(0)
            state.getSearchRef()!.blur()
            return
        }

        if ((e.target as HTMLElement).tagName === 'INPUT') return

        // Tab / Shift+Tab — cycle through tabs when the menu has tabs
        if (e.key === 'Tab' && state.getHasTabs() && state.getTabs().length > 1) {
            e.preventDefault()
            const tabs = state.getTabs()
            const cur = tabs.findIndex(t => t.id === state.getActiveTab())
            const next = e.shiftKey
                ? (cur - 1 + tabs.length) % tabs.length
                : (cur + 1) % tabs.length
            state.playSound('nav_lr')
            state.setActiveTab(tabs[next].id)
            state.setCurrentPage(0)
            state.setFocused(-1)
            return
        }

        // Backspace / Delete — close the top menu (same as Escape)
        if (e.key === 'Backspace' || e.key === 'Delete') {
            e.preventDefault()
            fetch('https://LastMenu/escape', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            })
            return
        }

        // Arrow keys navigate inside an open color-picker popover
        const openPopover = state.getOpenPopover()
        if (openPopover !== null) {
            const item = state.getPagedItems()[state.getFocused()]
            if (item?.kind === 'color_picker' && openPopover === item.id) {
                const presets = item.presets ?? state.PRESET_COLORS
                // colorFocusIdx === presets.length → hex text input is focused
                const onHex = state.getColorFocusIdx() === presets.length
                if (onHex) {
                    // Only Escape closes from the hex input; other keys are handled natively
                    if (e.key === 'Escape') { e.preventDefault(); state.setOpenPopover(null); return }
                    return
                }
                if (e.key === 'ArrowRight') { e.preventDefault(); state.setColorFocusIdx((state.getColorFocusIdx() + 1) % presets.length); return }
                if (e.key === 'ArrowLeft')  { e.preventDefault(); state.setColorFocusIdx((state.getColorFocusIdx() - 1 + presets.length) % presets.length); return }
                if (e.key === 'ArrowDown') {
                    e.preventDefault()
                    const next = state.getColorFocusIdx() + 4
                    if (next >= presets.length) { state.setColorFocusIdx(presets.length); state.getColorHexRef()?.focus() }
                    else state.setColorFocusIdx(next)
                    return
                }
                if (e.key === 'ArrowUp') { e.preventDefault(); state.setColorFocusIdx(Math.max(0, state.getColorFocusIdx() - 4)); return }
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault()
                    const idx = state.getColorFocusIdx()
                    if (idx >= 0 && idx < presets.length) { state.playSound('select'); state.selectColor(item, presets[idx]) }
                    state.setOpenPopover(null); return
                }
                if (e.key === 'Escape') { e.preventDefault(); state.setOpenPopover(null); return }
            }
        }

        if (e.key === 'ArrowDown') { e.preventDefault(); state.playSound('nav'); moveFocus(1); return }
        if (e.key === 'ArrowUp')   { e.preventDefault(); state.playSound('nav'); moveFocus(-1); return }

        const item = state.getPagedItems()[state.getFocused()]

        if (e.key === 'ArrowRight') {
            e.preventDefault()
            if (!item) return
            if (item.kind === 'slider')  state.stepSlider(item,  1)
            if (item.kind === 'stepper') state.stepStepper(item, 1)
            if (item.kind === 'list')    state.stepList(item,    1)
        }
        if (e.key === 'ArrowLeft') {
            e.preventDefault()
            if (!item) return
            if (item.kind === 'slider')  state.stepSlider(item,  -1)
            if (item.kind === 'stepper') state.stepStepper(item, -1)
            if (item.kind === 'list')    state.stepList(item,    -1)
        }

        if ((e.key === 'Enter' || e.key === ' ') && !e.repeat) {
            if (!item) return
            e.preventDefault()
            if (item.kind === 'button' && !item.confirm_hold && !item.disabled && !state.cd.isCooling(item.id) && !state.getTimedOutIds().has(item.id)) {
                state.playSound('select'); state.onCallback(item.id); state.cd.startCooldown(item)
            } else if (item.kind === 'button' && item.confirm_hold && !item.disabled && !state.cd.isCooling(item.id) && !state.getTimedOutIds().has(item.id)) {
                keyHeldFor = { id: item.id, key: e.key }
                state.startHold(item)
            } else if ((item.kind === 'checkbox' || item.kind === 'toggle') && !item.disabled && !state.getTimedOutIds().has(item.id)) {
                state.toggleBool(item)
            } else if (item.kind === 'accordion_start') {
                state.playSound('select')
                state.toggleAccordion(item.id)
            } else if (item.kind === 'color_picker') {
                state.playSound('select')
                const cur = state.getOpenPopover()
                state.setOpenPopover(cur === item.id ? null : item.id)
                if (state.getOpenPopover()) {
                    state.setColorFocusIdx((item.presets ?? state.PRESET_COLORS).indexOf(state.getStates()[item.id] as string ?? item.default))
                }
            } else if (item.kind === 'input_inline') {
                state.getInputRefs()[item.id]?.focus()
            } else if (item.kind === 'date_picker') {
                state.getDateFieldRefs()[item.id + '_0']?.focus()
            }
        }
    }

    function handleKeyup(e: KeyboardEvent): void {
        if (keyHeldFor && e.key === keyHeldFor.key) {
            state.cancelHold()
            keyHeldFor = null
        }
    }

    return {
        get navIndices() { return navIndices },
        handleKeydown,
        handleKeyup,
        moveFocus,
        scrollFocusedIntoView,
    }
}
