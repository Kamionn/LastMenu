import js from '@eslint/js'
import svelte from 'eslint-plugin-svelte'
import globals from 'globals'

export default [
    js.configs.recommended,
    ...svelte.configs['flat/recommended'],
    {
        languageOptions: {
            globals: {
                ...globals.browser,
            }
        }
    },
    {
        files: ['**/*.svelte'],
        languageOptions: {
            parserOptions: {
                // Svelte 5 runes support
                svelteFeatures: { runes: true }
            }
        }
    },
    {
        // Svelte 5 rune globals for .svelte.ts files
        files: ['**/*.svelte.ts'],
        languageOptions: {
            globals: {
                $state: 'readonly',
                $derived: 'readonly',
                $effect: 'readonly',
                $props: 'readonly',
                $bindable: 'readonly',
                $inspect: 'readonly',
                $host: 'readonly',
            }
        }
    },
    {
        ignores: ['node_modules/', 'assets/']
    }
]
