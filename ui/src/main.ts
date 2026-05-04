import '../theme/default.css'
import { mount } from 'svelte'
import App from './App.svelte'
import { applyViewportScale } from './utils/viewport'

applyViewportScale()
window.addEventListener('resize', applyViewportScale)
mount(App, { target: document.body })
