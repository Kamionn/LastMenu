<script>
    import '../styles/Notify.css'
    import { CircleCheck, CircleX, TriangleAlert, Info } from 'lucide-svelte'
    import LucideIcon from './LucideIcon.svelte'
    import { onMount } from 'svelte'

    let { onCallback = null, uiSounds = false, defaultDuration = 4000 } = $props()

    let toasts  = $state([])
    let posX    = $state('right')
    let posY    = $state('bottom')

    onMount(() => {
        const style = getComputedStyle(document.documentElement)
        posX = style.getPropertyValue('--ui-notify-position-x').trim() || 'right'
        posY = style.getPropertyValue('--ui-notify-position-y').trim() || 'bottom'
    })

    export function addNotify(data) {
        // duration=0 → persistent (no auto-dismiss, no timer bar)
        const duration = data.duration != null ? data.duration : defaultDuration
        const id       = data.id ?? Math.random().toString(36).slice(2)
        const entry    = { ...data, id, _start: Date.now(), _duration: duration, _pct: duration > 0 ? 100 : null }

        // group deduplication: replace existing toast with same group
        if (data.group) {
            toasts = toasts.filter(t => t.group !== data.group)
        }

        toasts = [...toasts, entry]

        if (duration > 0) {
            requestAnimationFrame(function tick() {
                const elapsed = Date.now() - entry._start
                const pct     = Math.max(0, 100 - (elapsed / duration) * 100)
                toasts = toasts.map(t => t.id === id ? { ...t, _pct: pct } : t)
                if (pct > 0) requestAnimationFrame(tick)
            })

            // isUserAction=false → auto-expiry (does not trigger the Lua callback)
            setTimeout(() => dismiss(id, false), duration)
        }
    }

    // isUserAction=true  → × click: triggers the Lua dismiss_cb (documented).
    // isUserAction=false → timeout expiry: sends notify_expired to clean up
    //                      Lua-side Bridge._callbacks without calling the user callback.
    function dismiss(id, isUserAction = false) {
        const toast = toasts.find(t => t.id === id)
        toasts = toasts.filter(t => t.id !== id)
        if (toast?.dismiss_cb) {
            if (isUserAction && onCallback) {
                onCallback(toast.dismiss_cb)
            } else if (!isUserAction) {
                // Clean up Lua-side without calling the user callback
                fetch(`https://LastMenu/notify_expired`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ dismiss_cb: toast.dismiss_cb })
                })
            }
        }
    }

    const TYPE_ICONS = {
        success: CircleCheck,
        error:   CircleX,
        warning: TriangleAlert,
        info:    Info,
    }

    const COLORS = {
        success: { main: 'var(--ui-success, #4ade80)', bg: 'rgba(74,222,128,0.08)',  glow: 'rgba(74,222,128,0.15)'  },
        error:   { main: 'var(--ui-error,   #f87171)', bg: 'rgba(248,113,113,0.08)', glow: 'rgba(248,113,113,0.15)' },
        warning: { main: 'var(--ui-warning, #fb923c)', bg: 'rgba(251,146,60,0.08)',  glow: 'rgba(251,146,60,0.15)'  },
        info:    { main: 'var(--ui-info,    #60a5fa)', bg: 'rgba(96,165,250,0.08)',   glow: 'rgba(96,165,250,0.15)'  },
    }
</script>

<div
    class="notify-container"
    class:pos-right={posX === 'right'}
    class:pos-left={posX === 'left'}
    class:pos-bottom={posY === 'bottom'}
    class:pos-top={posY === 'top'}
    class:dir-bottom={posY === 'bottom'}
    class:dir-top={posY === 'top'}
>
    {#each toasts as toast (toast.id)}
        {@const TypeIcon = TYPE_ICONS[toast.type] ?? Info}
        {@const colors   = COLORS[toast.type] ?? COLORS.info}
        <div
            class="toast"
            class:enter-right={posX === 'right'}
            class:enter-left={posX === 'left'}
            style="--c:{colors.main}; --cbg:{colors.bg}; --cglow:{colors.glow}"
            role="status"
            aria-live="polite"
        >
            <!-- Timer bar — full width (hidden when persistent) -->
            {#if toast._pct != null}
            <div class="timer-bar">
                <div class="timer-fill" style="width:{toast._pct}%"></div>
            </div>
            {/if}

            <div class="toast-body">
                <!-- Badge icon — custom Lucide icon or default type icon -->
                <div class="toast-badge">
                    {#if toast.icon}
                        <LucideIcon name={toast.icon} size={16} />
                    {:else}
                        <TypeIcon size={16} />
                    {/if}
                </div>

                <!-- Content -->
                <div class="toast-text">
                    {#if toast.title}
                        <div class="toast-title">{toast.title}</div>
                    {/if}
                    <div class="toast-message">{toast.message ?? ''}</div>
                </div>

                <!-- Dismiss -->
                <button class="toast-dismiss" onclick={() => dismiss(toast.id, true)} aria-label="Close">×</button>
            </div>
        </div>
    {/each}
</div>

