<script lang="ts">
    import '../../styles/ContextTabs.css'
    import LucideIcon from '../LucideIcon.svelte'
    import { useContextTabs } from './useContextTabs.svelte.ts'
    import type { Tab } from './useContextTabs.svelte.ts'

    interface Props {
        hasTabs:   boolean
        tabs:      Tab[]
        activeTab: string | null
        onChange?: () => void
    }

    let { hasTabs, tabs, activeTab = $bindable(null), onChange }: Props = $props()

    const t = useContextTabs(() => activeTab)
</script>

{#if hasTabs}
    <div class="ctx-tabs" bind:this={t.tabsEl}>
        {#each tabs as tab}
            <button
                class="tab-btn"
                class:is-active={activeTab === tab.id}
                onclick={() => { activeTab = tab.id; onChange?.() }}
            >
                {#if tab.icon}<LucideIcon name={tab.icon} size={12} />{/if}
                {tab.label}
            </button>
        {/each}
    </div>
{/if}
