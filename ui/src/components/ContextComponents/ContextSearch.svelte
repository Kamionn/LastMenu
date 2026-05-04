<script lang="ts">
    import '../../styles/ContextSearch.css'
    import { Search as SearchIcon } from 'lucide-svelte'

    interface Props {
        show:      boolean
        value?:    string
        ref?:      HTMLInputElement | null
        onInput:   (e: Event) => void
        onEscape?: () => void
    }

    let { show, value = $bindable(''), ref = $bindable(null), onInput, onEscape }: Props = $props()
</script>

{#if show}
    <div class="ctx-search">
        <SearchIcon size={12} />
        <input
            type="text"
            placeholder="Search... ( / )"
            {value}
            oninput={onInput}
            bind:this={ref}
            onkeydown={(e) => {
                if (e.key === 'Escape') {
                    e.preventDefault()
                    onEscape?.()
                }
            }}
        />
    </div>
{/if}
