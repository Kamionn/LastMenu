<script>
    import '../styles/Target.css'
    import LucideIcon from './LucideIcon.svelte'
    import { Eye, X, ChevronDown, ChevronUp, ChevronRight, Check, Lock } from 'lucide-svelte'
    import { useTarget } from './TargetComponents/useTarget.svelte.ts'
    import { TRANSLATIONS } from '../i18n/translations.ts'

    let { data, onCallback, reticlePos = 'center', lang = 'en' } = $props()

    const target = useTarget(() => data, (id, extra) => onCallback(id, extra))
    const t = $derived(TRANSLATIONS[lang] ?? TRANSLATIONS.en)
</script>

<!-- ── Shared item renderer (used for root items and accordion children) ── -->
{#snippet renderItem(item)}
    {#if item.kind === 'separator'}
        <div class="target-sep"></div>

    {:else if item.kind === 'button'}
        {@const isHeld     = target.holdId === item.id}
        {@const cooling    = target.isCooling(item.id)}
        {@const cdMs       = cooling ? target.cdRemaining(item.id) : 0}
        {@const isDisabled = item.disabled || cooling}
        <button
            class="target-btn"
            class:is-disabled={isDisabled}
            class:has-gradient={item.gradient}
            class:is-hold={isHeld}
            class:is-cooling={cooling}
            style={item.gradient && item.color ? `--btn-color:${item.color}` : ''}
            disabled={isDisabled}
            onmousedown={() => { if (item.confirm_hold && !isDisabled) target.startHold(item) }}
            onmouseup={target.cancelHold}
            onmouseleave={target.cancelHold}
            onclick={() => target.clickItem(item)}
        >
            {#if isHeld}
                <div class="hold-fill" style="width:{target.holdProgress * 100}%"></div>
            {/if}
            {#if cooling}
                <div class="cd-bar" style="width:{(item.cooldown - cdMs) / item.cooldown * 100}%"></div>
            {/if}
            {#if cooling}
                <span class="tbtn-icon"><Lock size={12}/></span>
            {:else if item.icon}
                <span class="tbtn-icon"><LucideIcon name={item.icon} size={12}/></span>
            {/if}
            <span class="tbtn-label">{item.label}</span>
            {#if cooling}
                <span class="tbtn-cd">{(cdMs / 1000).toFixed(1)}s</span>
            {:else}
                {#if item.badge}<span class="tbtn-badge">{item.badge}</span>{/if}
                {#if item.arrow}<span class="tbtn-arrow"><ChevronRight size={11}/></span>{/if}
                {#if item.disabled && !item.arrow}<span class="tbtn-locked">✕</span>{/if}
            {/if}
        </button>

    {:else if item.kind === 'toggle'}
        {@const on = target.states[item.id] ?? false}
        <button class="target-btn" onclick={() => target.clickItem(item)}>
            {#if item.icon}<span class="tbtn-icon"><LucideIcon name={item.icon} size={12}/></span>{/if}
            <span class="tbtn-label">{item.label}</span>
            <span class="toggle-track" class:is-on={on}><span class="toggle-knob"></span></span>
        </button>

    {:else if item.kind === 'checkbox'}
        {@const checked = target.states[item.id] ?? false}
        <button class="target-btn" onclick={() => target.clickItem(item)}>
            {#if item.icon}<span class="tbtn-icon"><LucideIcon name={item.icon} size={12}/></span>{/if}
            <span class="tbtn-label">{item.label}</span>
            <span class="checkbox-box" class:is-checked={checked}>{#if checked}<Check size={10}/>{/if}</span>
        </button>

    {:else if item.kind === 'slider'}
        {@const val = target.states[item.id] ?? 0}
        {@const pct = item.max > item.min ? (val - item.min) / (item.max - item.min) * 100 : 0}
        <div class="target-slider-row">
            <div class="slider-top">
                {#if item.icon}<span class="tbtn-icon"><LucideIcon name={item.icon} size={12}/></span>{/if}
                <span class="tbtn-label">{item.label}</span>
                <span class="slider-val">{val}{item.suffix ?? ''}</span>
            </div>
            <input type="range" class="tgt-range" min={item.min} max={item.max} step={item.step ?? 1} value={val}
                style="--pct:{pct}%"
                oninput={(e) => target.updateState(item.id, Number(e.currentTarget.value))}
                onchange={(e) => { onCallback(item.id, { value: Number(e.currentTarget.value) }) }}
            />
        </div>
    {/if}
{/snippet}


{#if data.items?.length > 0}
    <!-- ── Rich action menu ──────────────────────────────────────────── -->
    <div class="target-actions-wrap">
        <div class="target-actions">
            {#if data.banner}
                <div class="target-banner" style="background-image:url('{data.banner}')">
                    <button class="target-banner-close" onclick={() => onCallback('__cancel__')} title={t.target_close}>
                        <X size={11}/>
                    </button>
                    <div class="target-banner-title">{data.label ?? t.target_interact}</div>
                </div>
            {:else}
                <div class="target-header">
                    <span class="target-eye"><Eye size={13} /></span>
                    <span class="target-label">{data.label ?? t.target_interact}</span>
                    <button class="target-close" onclick={() => onCallback('__cancel__')} title={t.target_close}>
                        <X size={11}/>
                    </button>
                </div>
            {/if}
            <div class="target-items">
                {#each data.items as item (item.id)}
                    {#if item.kind === 'accordion'}
                        {@const isOpen = target.openAccordions.has(item.id)}
                        <button class="target-acc-hdr" class:is-open={isOpen} onclick={() => target.toggleAcc(item.id)}>
                            {#if item.icon}<span class="tbtn-icon"><LucideIcon name={item.icon} size={12}/></span>{/if}
                            <span class="tbtn-label">{item.label}</span>
                            <span class="acc-chevron">
                                {#if isOpen}<ChevronUp size={11}/>{:else}<ChevronDown size={11}/>{/if}
                            </span>
                        </button>
                        {#if isOpen}
                            <div class="target-acc-body">
                                {#each item.items ?? [] as sub (sub.id)}
                                    {@render renderItem(sub)}
                                {/each}
                            </div>
                        {/if}
                    {:else}
                        {@render renderItem(item)}
                    {/if}
                {/each}
            </div>
        </div>
    </div>

{:else if data.idle}
    <!-- ── Idle: CTRL held but no zone in range ───────────────── -->
    <div class="target-idle">
        <div class="idle-cross">
            <span class="ic-h"></span>
            <span class="ic-v"></span>
            <div class="idle-ring"></div>
        </div>
        {#if data.moving}
            <div class="idle-hint">
                <span class="hint-key">E</span>
                <span class="idle-hint-text">{t.target_no_zone}</span>
            </div>
        {/if}
    </div>

{:else}
    <!-- ── Passive reticle: entity/zone targeted, hold key active -->
    <div class="target-reticle">
        <div class="reticle-ring">
            <Eye size={15} />
        </div>
        <div class="reticle-hint">
            <span class="hint-key">E</span>
            <span class="hint-text">{data.label ?? t.target_interact}</span>
        </div>
    </div>
{/if}
