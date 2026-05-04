import * as LucideIcons from 'lucide-svelte'
import type { Component } from 'svelte'

type AnyComponent = Component<any>

const aliasMap: Record<string, string> = {
    trash:        'trash-2',
    edit:         'edit-2',
    building:     'building-2',
    grid:         'grid-3x3',
    'bar-chart':  'bar-chart-2',
    parking:      'parking-circle',
}

const componentCache = new Map<string, AnyComponent | null>()

function normalize(name: unknown): string {
    return String(name ?? '')
        .trim()
        .toLowerCase()
        .replace(/[\s_]+/g, '-')
}

function toPascalCase(kebab: string): string {
    return kebab.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join('')
}

function candidateNames(raw: unknown): string[] {
    const normalized = normalize(raw)
    if (!normalized) return []

    const candidates: string[] = [normalized]

    if (aliasMap[normalized]) {
        candidates.push(aliasMap[normalized])
    }

    const parts = normalized.split('-').filter(Boolean)
    if (parts.length === 2) {
        candidates.push(`${parts[1]}-${parts[0]}`)
    }

    return [...new Set(candidates)]
}

function lookupIcon(candidate: string): AnyComponent | null {
    return ((LucideIcons as unknown) as Record<string, AnyComponent | undefined>)[toPascalCase(candidate)] ?? null
}

export function hasLucideIcon(name: unknown): boolean {
    return candidateNames(name).some(candidate => lookupIcon(candidate) !== null)
}

export async function loadLucideIcon(name: unknown): Promise<AnyComponent | null> {
    const normalized = normalize(name)
    if (!normalized) return null

    if (componentCache.has(normalized)) {
        return componentCache.get(normalized) ?? null
    }

    for (const candidate of candidateNames(normalized)) {
        const icon = lookupIcon(candidate)
        if (!icon) continue

        componentCache.set(normalized, icon)
        return icon
    }

    componentCache.set(normalized, null)
    return null
}
