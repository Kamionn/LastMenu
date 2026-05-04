<script>
    import '../styles/Input.css'
    import { untrack, onMount } from 'svelte'
    import { TRANSLATIONS } from '../i18n/translations.ts'

    let { data, onCallback, lang = 'en' } = $props()
    const t = $derived(TRANSLATIONS[lang] ?? TRANSLATIONS.en)

    // untrack: snapshot of initial values at mount — prevents reactive re-capture
    let values    = $state(untrack(() => data.fields.map(f => f.default ?? '')))
    let fieldRefs = $state([])
    let errors    = $state([])

    // Debounce timers per field for inline validation
    const debounceTimers = []

    function validateField(i) {
        const f = data.fields[i]
        const v = values[i]
        if (f.type === 'number') {
            const n = parseFloat(v)
            if (isNaN(n)) return t.field_numeric
            if (f.min != null && n < f.min) return `${t.field_min}: ${f.min}`
            if (f.max != null && n > f.max) return `${t.field_max}: ${f.max}`
        }
        if (f.pattern) {
            try {
                const re = new RegExp(f.pattern)
                if (!re.test(v)) return f.pattern_error ?? t.field_pattern
            } catch (_) {
                // invalid regex from Lua — skip silently
            }
        }
        return null
    }

    function handleInput(i, value) {
        values[i] = value
        errors[i] = null
        // Debounced inline validation (300ms) — only validates when the user pauses
        if (debounceTimers[i]) clearTimeout(debounceTimers[i])
        debounceTimers[i] = setTimeout(() => {
            const err = validateField(i)
            if (err) errors[i] = err
        }, 300)
    }

    function handleConfirm() {
        for (let i = 0; i < debounceTimers.length; i++) {
            if (debounceTimers[i]) clearTimeout(debounceTimers[i])
        }
        const errs = data.fields.map((_, i) => validateField(i))
        errors = errs
        if (errs.some(e => e != null)) return
        onCallback(data.confirm.id, { values })
    }

    function handleCancel() {
        if (data.cancel) onCallback(data.cancel.id)
    }

    function handleKeydown(e) {
        if (e.key === 'Enter') {
            e.preventDefault()
            // Tab to the next field, or confirm from the last field
            const cur = fieldRefs.indexOf(e.target)
            if (cur >= 0 && cur < fieldRefs.length - 1) {
                fieldRefs[cur + 1]?.focus()
            } else {
                handleConfirm()
            }
        } else if (e.key === 'Escape') {
            e.preventDefault()
            handleCancel()
        }
    }

    onMount(() => {
        // Auto-focus the first field on open
        fieldRefs[0]?.focus()
    })
</script>

<div class="input-wrap">
    <div class="input-modal">
        {#if data.title}
            <div class="input-title">{data.title}</div>
        {/if}
        <div class="input-fields">
            {#each data.fields as field, i (field.index)}
                <div class="field-group">
                    <label class="field-label" for="field-{i}">{field.label}</label>
                    <input
                        id="field-{i}"
                        class="field-input"
                        class:field-error={errors[i]}
                        type={field.type ?? 'text'}
                        maxlength={field.maxlen ?? undefined}
                        placeholder={field.placeholder ?? undefined}
                        value={values[i]}
                        oninput={(e) => handleInput(i, e.currentTarget.value)}
                        onkeydown={handleKeydown}
                        bind:this={fieldRefs[i]}
                        autocomplete="off"
                    />
                    {#if errors[i]}
                        <span class="field-err-msg">{errors[i]}</span>
                    {/if}
                </div>
            {/each}
        </div>
        <div class="input-actions">
            {#if data.cancel}
                <button class="btn btn-cancel" onclick={handleCancel}>{data.cancel.label}</button>
            {/if}
            {#if data.confirm}
                <button class="btn btn-confirm" onclick={handleConfirm}>{data.confirm.label}</button>
            {/if}
        </div>
    </div>
</div>

