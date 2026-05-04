const DESIGN_W = 1920
const DESIGN_H = 1080

export function applyViewportScale(): void {
    const scale = Math.min(window.innerWidth / DESIGN_W, window.innerHeight / DESIGN_H)
    // Only scale UP (> design resolution). Sub-1080p screens keep 1:1 to avoid shrinking the UI.
    document.documentElement.style.zoom = scale > 1 ? String(scale) : ''
}
