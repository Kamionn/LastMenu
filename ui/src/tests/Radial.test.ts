import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import Radial from '../components/Radial.svelte'

const btn = (id: string, label: string, overrides = {}) => ({
    id,
    label,
    icon:         null,
    visible:      true,
    disabled:     false,
    confirm_hold: false,
    ...overrides,
})

const baseData = {
    center_label: 'Actions',
    buttons: [
        btn('cb_repair',  'Réparer'),
        btn('cb_clean',   'Nettoyer'),
        btn('cb_inspect', 'Inspecter'),
    ],
}

describe('Radial — rendu', () => {
    it('affiche le center_label quand aucun secteur n\'est sélectionné', () => {
        const { getByText } = render(Radial, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Actions')).toBeInTheDocument()
    })

    it('affiche les labels de tous les boutons visibles', () => {
        const { getByText } = render(Radial, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Réparer')).toBeInTheDocument()
        expect(getByText('Nettoyer')).toBeInTheDocument()
        expect(getByText('Inspecter')).toBeInTheDocument()
    })

    it("n'affiche pas les boutons invisible (visible=false)", () => {
        const data = {
            ...baseData,
            buttons: [
                btn('cb_a', 'Visible'),
                btn('cb_b', 'Caché', { visible: false }),
            ],
        }
        const { getByText, queryByText } = render(Radial, { data, onCallback: vi.fn() })
        expect(getByText('Visible')).toBeInTheDocument()
        expect(queryByText('Caché')).not.toBeInTheDocument()
    })

    it('affiche le conteneur SVG', () => {
        const { container } = render(Radial, { data: baseData, onCallback: vi.fn() })
        expect(container.querySelector('.radial-svg')).toBeInTheDocument()
    })

    it('affiche un point central quand center_label est absent', () => {
        const data = { ...baseData, center_label: undefined }
        const { container } = render(Radial, { data, onCallback: vi.fn() })
        expect(container.querySelector('.center-dot')).toBeInTheDocument()
    })

    it('applique la classe is-closing quand closing=true', () => {
        const { container } = render(Radial, { data: baseData, onCallback: vi.fn(), closing: true })
        expect(container.querySelector('.radial-overlay')).toHaveClass('is-closing')
    })
})

describe('Radial — navigation clavier', () => {
    it('ArrowRight sélectionne le premier bouton', async () => {
        const { getByText } = render(Radial, { data: baseData, onCallback: vi.fn() })
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        // Le premier bouton sélectionné apparaît dans .center-area
        expect(getByText('Réparer')).toBeInTheDocument()
    })

    it('ArrowRight puis ArrowRight sélectionne le deuxième bouton', async () => {
        const onCallback = vi.fn()
        const { getByText } = render(Radial, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        expect(getByText('Nettoyer')).toBeInTheDocument()
    })

    it('Entrée sur un bouton sélectionné appelle onCallback', async () => {
        const onCallback = vi.fn()
        render(Radial, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        await fireEvent.keyDown(window, { key: 'Enter' })
        expect(onCallback).toHaveBeenCalledWith('cb_repair')
    })

    it('Espace sur un bouton sélectionné appelle onCallback', async () => {
        const onCallback = vi.fn()
        render(Radial, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        await fireEvent.keyDown(window, { key: ' ' })
        expect(onCallback).toHaveBeenCalledWith('cb_repair')
    })

    it('Tab cycle entre les boutons', async () => {
        const onCallback = vi.fn()
        render(Radial, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'Tab' })
        await fireEvent.keyDown(window, { key: 'Enter' })
        expect(onCallback).toHaveBeenCalledOnce()
    })

    it('Entrée sans sélection (kbIndex=-1, selectedIndex=-1) ne plante pas', async () => {
        const onCallback = vi.fn()
        render(Radial, { data: baseData, onCallback })
        await expect(fireEvent.keyDown(window, { key: 'Enter' })).resolves.toBeDefined()
        expect(onCallback).not.toHaveBeenCalled()
    })

    it('saute les boutons disabled lors du cycle clavier', async () => {
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            buttons: [
                btn('cb_a', 'Actif'),
                btn('cb_b', 'Désactivé', { disabled: true }),
                btn('cb_c', 'Aussi actif'),
            ],
        }
        render(Radial, { data, onCallback })
        // Premier ArrowRight → 'Actif' (index 0)
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        await fireEvent.keyDown(window, { key: 'Enter' })
        expect(onCallback).toHaveBeenCalledWith('cb_a')

        // Deuxième ArrowRight → saute 'Désactivé', arrive sur 'Aussi actif'
        onCallback.mockClear()
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        await fireEvent.keyDown(window, { key: 'Enter' })
        expect(onCallback).toHaveBeenCalledWith('cb_c')
    })
})

describe('Radial — cas limites', () => {
    it('se monte sans erreur avec zéro boutons', () => {
        const data = { center_label: 'Vide', buttons: [] }
        expect(() => render(Radial, { data, onCallback: vi.fn() })).not.toThrow()
    })

    it('se monte sans erreur avec un seul bouton', () => {
        const data = { buttons: [btn('cb_only', 'Seul')] }
        const { getByText } = render(Radial, { data, onCallback: vi.fn() })
        expect(getByText('Seul')).toBeInTheDocument()
    })

    it('se monte sans erreur avec 8 boutons', () => {
        const buttons = Array.from({ length: 8 }, (_, i) => btn(`cb_${i}`, `Action ${i}`))
        const { container } = render(Radial, { data: { buttons }, onCallback: vi.fn() })
        expect(container.querySelectorAll('.sector-icon')).toHaveLength(8)
    })
})
