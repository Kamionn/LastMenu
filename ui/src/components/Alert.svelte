<script>
    import '../styles/Alert.css'
    import { fly, fade } from 'svelte/transition'
    import { useAlert } from './AlertComponents/useAlert.svelte.ts'

    let { data, onCallback } = $props()

    const alert = useAlert(() => data, (id) => onCallback(id))
    let AlertIcon = $derived(alert.Icon)
</script>

<svelte:window onkeydown={alert.handleKeydown} />

<!-- Backdrop -->
<div class="alert-backdrop"
    in:fade={{ duration: 160 }}
    out:fade={{ duration: 120 }}
></div>

<!-- Modal -->
<div class="alert-wrap"
    in:fly={{ y: 10, duration: 200 }}
    out:fly={{ y: -6, duration: 140 }}
>
    <div class="alert-modal" style="--alert-accent:{alert.typeMeta.color}; --alert-accent-bg:{alert.typeMeta.accentBg}">

        <!-- Icon zone -->
        <div class="alert-icon-zone">
            <div class="alert-icon-ring">
                <AlertIcon size={24} />
            </div>
        </div>

        <!-- Content -->
        <div class="alert-body">
            {#if data.title}
                <div class="alert-title">{data.title}</div>
            {/if}
            {#if data.message}
                <div class="alert-message">{data.message}</div>
            {/if}
        </div>

        <!-- Divider -->
        <div class="alert-divider"></div>

        <!-- Actions -->
        <div class="alert-actions">
            {#if data.cancel}
                <button class="btn btn-cancel" tabindex="0" onclick={() => onCallback(data.cancel.id)}>
                    {data.cancel.label}
                </button>
            {/if}
            {#if data.confirm}
                <!-- svelte-ignore a11y_autofocus -->
                <button class="btn btn-confirm" tabindex="0" autofocus onclick={() => onCallback(data.confirm.id)}>
                    {data.confirm.label}
                </button>
            {/if}
        </div>

    </div>
</div>
