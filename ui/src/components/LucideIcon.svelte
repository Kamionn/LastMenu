<script>
    import { loadLucideIcon } from '../utils/icons.js'
    import { AlertCircle } from 'lucide-svelte'

    let {
        name = '',
        size = 16,
        color = 'currentColor',
        strokeWidth = 2,
        absoluteStrokeWidth = false,
        class: className = ''
    } = $props()

    let Icon = $state(null)

    $effect(() => {
        let cancelled = false

        if (!name) {
            Icon = null
            return
        }

        loadLucideIcon(name).then(component => {
            if (cancelled) return
            if (component === null) {
                console.warn(`[LastMenu] LucideIcon: "${name}" not found — fallback AlertCircle`)
                Icon = AlertCircle
            } else {
                Icon = component
            }
        })

        return () => { cancelled = true }
    })
</script>

{#if Icon}
    <Icon
        {size}
        {color}
        strokeWidth={strokeWidth}
        absoluteStrokeWidth={absoluteStrokeWidth}
        class={className}
    />
{/if}