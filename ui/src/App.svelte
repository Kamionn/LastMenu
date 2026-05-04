<script>
    import './styles/App.css'
    import { onMount } from 'svelte'
    import Context      from './components/Context.svelte'
    import Alert        from './components/Alert.svelte'
    import Notify       from './components/Notify.svelte'
    import Progress     from './components/Progress.svelte'
    import Radial       from './components/Radial.svelte'
    import Input        from './components/Input.svelte'
    import Target       from './components/Target.svelte'
    import UserSettings from './components/UserSettings.svelte'
    import { loadSettings, applyTheme } from './utils/theme'

    let stack     = $state([])
    let topMenu   = $derived(stack.length > 0 ? stack[stack.length - 1] : null)
    let notifyRef = $state(null)

    // ── User settings ──────────────────────────────────────────────────────
    let userSettings = $state(loadSettings())

    $effect(() => {
        applyTheme(userSettings)
        localStorage.setItem('lm-settings', JSON.stringify(userSettings))
    })

    let showSettings = $state(false)

    // ── Escape debounce ────────────────────────────────────────────────────
    // Prevents two rapid Escape presses from popping two stack levels.
    let _escapeLock = false

    // ── NUI perf tracking ─────────────────────────────────────────────────
    // Only active when perf_start is received (sent by performance_test.lua). Zero overhead in normal use.
    let _perfEnabled  = false
    let _patchCount   = 0
    let _patchTotalMs = 0
    let _patchMaxMs   = 0
    let _heapInterval = null

    function perfReport(payload) {
        fetch('https://LastMenu/perf_report', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        })
    }

    // ── NUI callbacks ──────────────────────────────────────────────────────
    function sendCallback(cb_id, extra = {}) {
        fetch(`https://LastMenu/callback`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ cb_id, ...extra })
        })
    }

    function handleMessage(event) {
        const data = event.data
        if (!data || !data.type) return

        // Batched messages from Bridge.send on the Lua side
        if (data.type === 'batch') {
            for (const msg of data.messages) handleMessage({ data: msg })
            return
        }

        if (data.type === 'settings') {
            showSettings = data.show === true
            return
        }

        if (data.type === 'reset') {
            // Resource (re)started — clear stale NUI stack entries
            stack = []
            return
        }

        // Perf bench — enabled/disabled by performance_test.lua
        if (data.type === 'perf_start') {
            _perfEnabled = true; _patchCount = 0; _patchTotalMs = 0; _patchMaxMs = 0
            if (!_heapInterval) _heapInterval = setInterval(() => {
                const mem = /** @type {any} */ (performance).memory
                if (mem) perfReport({ event: 'heap', usedMB: +(mem.usedJSHeapSize / 1048576).toFixed(1) })
            }, 3000)
            return
        }
        if (data.type === 'perf_stop') {
            _perfEnabled = false
            if (_heapInterval) { clearInterval(_heapInterval); _heapInterval = null }
            return
        }

        if (data.type === 'open') {
            if (data.menu === 'notify') {
                if (notifyRef) notifyRef.addNotify(data.data ?? data)
            } else {
                // Dedup by ID: replace any existing entry with the same ID
                // Prevents each_key_duplicate when hardcoded IDs (e.g. target_reticle)
                // are re-sent after a resource restart without a full NUI reload.
                stack = [...stack.filter(m => m.id !== data.id), data]
                // Perf: measure initial render time (double RAF = after paint)
                if (_perfEnabled && data.menu === 'context') {
                    const t0 = performance.now()
                    const itemCount = data.data?.items?.length ?? 0
                    requestAnimationFrame(() => requestAnimationFrame(() => {
                        perfReport({ event: 'render', ms: +(performance.now() - t0).toFixed(2), items: itemCount })
                    }))
                }
            }
        } else if (data.type === 'close') {
            // Two-phase close: mark as closing first so the CSS exit animation can play,
            // then remove from stack after the animation duration (180ms).
            stack = stack.map(m => m.id === data.id ? { ...m, closing: true } : m)
            setTimeout(() => {
                stack = stack.filter(m => m.id !== data.id)
            }, 200)
        } else if (data.type === 'patch') {
            const _t0 = _perfEnabled ? performance.now() : 0
            // Context menus: item-level patches are handled entirely by Context.svelte's
            // liveOverrides listener (fine-grained O(m) write per changed item).
            // Skipping the O(n) items.map() here eliminates the full $derived cascade
            // (items → flatItems → displayItems → pagedItems → cumulHeights → navIndices)
            // that fires on every patch regardless of how many items actually changed.
            // Non-context menus (radial w/ buttons, etc.) keep the remap — no liveOverrides there.
            const patchEntry = stack.find(m => m.id === data.id)
            const isCtx = patchEntry?.menu === 'context'
            if (!isCtx || data.merge) {
                stack = stack.map(m => {
                    if (m.id !== data.id) return m
                    const d = { ...m.data }
                    if (!isCtx) {
                        const changes = data.changes || []
                        // Collapse multiple changes per id into {field: value, ...} map
                        const changeMap = new Map()
                        for (const c of changes) {
                            if (!changeMap.has(c.id)) changeMap.set(c.id, {})
                            changeMap.get(c.id)[c.field] = c.value
                        }
                        if (d.items)   d.items   = d.items.map(item => { const c = changeMap.get(item.id); return c ? { ...item, ...c } : item })
                        if (d.buttons) d.buttons = d.buttons.map(btn  => { const c = changeMap.get(btn.id);  return c ? { ...btn,  ...c } : btn  })
                    }
                    // merge: shallow-merge top-level data fields (used by target idle moving state)
                    if (data.merge) Object.assign(d, data.merge)
                    return { ...m, data: d }
                })
            }
            // Perf: accumulate patch timings, report every 50 patches
            if (_perfEnabled) {
                const ms = performance.now() - _t0
                _patchCount++; _patchTotalMs += ms
                if (ms > _patchMaxMs) _patchMaxMs = ms
                if (_patchCount >= 50) {
                    perfReport({ event: 'patch_batch', count: _patchCount, avgMs: +(_patchTotalMs / _patchCount).toFixed(3), maxMs: +_patchMaxMs.toFixed(3) })
                    _patchCount = 0; _patchTotalMs = 0; _patchMaxMs = 0
                }
            }
        }
    }

    function handleKeydown(e) {
        const isEscape = e.key === 'Escape'
        if (!isEscape) return
        // Settings panel takes priority: Escape closes it first
        if (showSettings) {
            showSettings = false
            fetch(`https://LastMenu/settings:close`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            })
            return
        }
        if (topMenu && !_escapeLock) {
            _escapeLock = true
            setTimeout(() => { _escapeLock = false }, 250)
            // Progress: fire cb_cancel before the Lua escape handler clears its callbacks
            if (topMenu.menu === 'progress' && topMenu.data?.cancelable && topMenu.data?.cb_cancel) {
                sendCallback(topMenu.data.cb_cancel)
            }
            fetch(`https://LastMenu/escape`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            })
        }
    }

    onMount(() => {
        fetch(`https://LastMenu/ready`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ navMode: userSettings.navMode, targetKey: userSettings.targetKey, uiSounds: userSettings.uiSounds })
        })
        window.addEventListener('message', handleMessage)
        window.addEventListener('keydown', handleKeydown)
        return () => {
            window.removeEventListener('message', handleMessage)
            window.removeEventListener('keydown', handleKeydown)
            if (_heapInterval) { clearInterval(_heapInterval); _heapInterval = null }
        }
    })
</script>

<Notify bind:this={notifyRef} onCallback={sendCallback} uiSounds={userSettings.uiSounds} defaultDuration={userSettings.notifyDuration} />

<!-- Context menus: rendered persistently so banner GIFs don't restart on sub-menu open/close.
     Each menu in the stack keeps its component alive; only the top one is active (visible + interactive). -->
{#each stack as menuItem (menuItem.id)}
    {#if menuItem.menu === 'context'}
        <Context
            menuId={menuItem.id}
            data={menuItem.data}
            onCallback={sendCallback}
            navMode={userSettings.navMode}
            defaultAnimation={userSettings.animation ?? 'slideLeft'}
            active={menuItem === topMenu}
            closing={menuItem.closing === true}
            compactMode={userSettings.compactMode}
            uiSounds={userSettings.uiSounds}
        />
    {/if}
{/each}

<!-- Non-context overlays only need the top menu -->
{#if topMenu && topMenu.menu !== 'context'}
    {#key topMenu.id}
        {#if topMenu.menu === 'alert'}
            <Alert    data={topMenu.data} onCallback={sendCallback} />
        {:else if topMenu.menu === 'progress'}
            <Progress data={topMenu.data} onCallback={sendCallback} lang={userSettings.language} />
        {:else if topMenu.menu === 'radial'}
            <Radial   data={topMenu.data} onCallback={sendCallback} closing={topMenu.closing === true} />
        {:else if topMenu.menu === 'input'}
            <Input    data={topMenu.data} onCallback={sendCallback} lang={userSettings.language} />
        {:else if topMenu.menu === 'target'}
            <Target   data={topMenu.data} onCallback={sendCallback} reticlePos={userSettings.reticlePos} lang={userSettings.language} />
        {/if}
    {/key}
{/if}

<!-- F12 settings hint — visible when the panel is closed -->
{#if !showSettings}
    <div class="settings-hint" aria-hidden="true">⚙ F12</div>
{/if}

<!-- SVG filter definitions for color blind simulation — hidden, referenced via url(#lm-*) -->
<svg style="display:none" aria-hidden="true">
    <defs>
        <filter id="lm-deuteranopia" color-interpolation-filters="linearRGB">
            <feColorMatrix type="matrix" values="0.367 0.861 -0.228 0 0  0.280 0.673 0.047 0 0  -0.012 0.043 0.969 0 0  0 0 0 1 0"/>
        </filter>
        <filter id="lm-protanopia" color-interpolation-filters="linearRGB">
            <feColorMatrix type="matrix" values="0.152 1.053 -0.205 0 0  0.115 0.786 0.099 0 0  -0.004 -0.048 1.052 0 0  0 0 0 1 0"/>
        </filter>
        <filter id="lm-tritanopia" color-interpolation-filters="linearRGB">
            <feColorMatrix type="matrix" values="1.256 -0.077 -0.179 0 0  -0.078 0.931 0.148 0 0  0.005 0.691 0.304 0 0  0 0 0 1 0"/>
        </filter>
    </defs>
</svg>

{#if showSettings}
    <UserSettings
        settings={userSettings}
        onSave={(s) => {
            userSettings = s
            showSettings = false
            fetch(`https://LastMenu/settings:update`, {
                method: 'POST', headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ navMode: s.navMode, targetKey: s.targetKey, uiSounds: s.uiSounds })
            })
            fetch(`https://LastMenu/settings:close`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({}) })
        }}
        onClose={() => {
            showSettings = false
            fetch(`https://LastMenu/settings:close`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({}) })
        }}
    />
{/if}
