import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

export default defineConfig({
    plugins: [svelte()],
    build: {
        outDir: './assets',
        emptyOutDir: true,         
        rollupOptions: {
            input: './src/main.ts', 
            output: {
                entryFileNames: 'main.js',
                assetFileNames: '[name][extname]',
                chunkFileNames: '[name].js',
            }
        }
    },
    base: './'
})
