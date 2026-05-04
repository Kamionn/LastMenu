<script>
    import '../styles/Progress.css'
    import { onMount } from 'svelte'
    import LucideIcon from './LucideIcon.svelte'
    import { TRANSLATIONS } from '../i18n/translations.ts'

    let { data, onCallback, lang = 'en' } = $props()

    const t = $derived(TRANSLATIONS[lang] ?? TRANSLATIONS.en)

    let progress = $state(0)
    let timer = null

    onMount(() => {
        const start = Date.now()
        const duration = data.duration ?? 5000

        function tick() {
            const elapsed = Date.now() - start
            progress = Math.min((elapsed / duration) * 100, 100)
            if (progress < 100) {
                timer = requestAnimationFrame(tick)
            } else {
                if (data.cb_complete) onCallback(data.cb_complete)
            }
        }
        timer = requestAnimationFrame(tick)
        return () => { if (timer) cancelAnimationFrame(timer) }
    })
</script>

<div class="progress-wrap">
    <div class="progress-bar-container">
        {#if data.label || data.icon}
            <div class="progress-label">
                <span class="progress-label-text">
                    {#if data.icon}
                        <LucideIcon name={data.icon} size={13} />
                    {/if}
                    {data.label ?? ''}
                </span>
                <span class="progress-pct">{Math.floor(progress)}%</span>
            </div>
        {/if}
        <div class="progress-track">
            <div class="progress-fill" style="width: {progress}%"></div>
        </div>
        {#if data.cancelable}
            <div class="progress-hint">{t.progress_cancel_hint}</div>
        {/if}
    </div>
</div>

