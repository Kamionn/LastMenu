import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import Notify from '../components/Notify.svelte'

describe('Notify — addNotify', () => {
    it('affiche un toast avec le message', async () => {
        const { component, findByText } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ message: 'Opération réussie', type: 'success', duration: 0 })
        expect(await findByText('Opération réussie')).toBeInTheDocument()
    })

    it('affiche le titre du toast si fourni', async () => {
        const { component, findByText } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ title: 'Succès', message: 'Véhicule réparé', type: 'success', duration: 0 })
        expect(await findByText('Succès')).toBeInTheDocument()
        expect(await findByText('Véhicule réparé')).toBeInTheDocument()
    })

    it('affiche plusieurs toasts indépendants', async () => {
        const { component, findByText } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ message: 'Toast A', type: 'info',    duration: 0 })
        component.addNotify({ message: 'Toast B', type: 'warning', duration: 0 })
        expect(await findByText('Toast A')).toBeInTheDocument()
        expect(await findByText('Toast B')).toBeInTheDocument()
    })

    it('remplace un toast existant avec le même group', async () => {
        const { component, findByText, queryByText } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ message: 'Ancien',  type: 'info', duration: 0, group: 'status' })
        component.addNotify({ message: 'Nouveau', type: 'info', duration: 0, group: 'status' })
        expect(await findByText('Nouveau')).toBeInTheDocument()
        // L'ancien toast est remplacé
        expect(queryByText('Ancien')).not.toBeInTheDocument()
    })

    it("n'affiche pas de barre de timer quand duration=0 (persistant)", async () => {
        const { component, container } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ message: 'Persistant', type: 'info', duration: 0 })
        // Attendre le montage
        await new Promise(r => setTimeout(r, 10))
        expect(container.querySelector('.timer-bar')).not.toBeInTheDocument()
    })

    it("affiche une barre de timer quand duration > 0", async () => {
        const { component, container } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ message: 'Temporaire', type: 'info', duration: 3000 })
        await new Promise(r => setTimeout(r, 10))
        expect(container.querySelector('.timer-bar')).toBeInTheDocument()
    })
})

describe('Notify — interactions', () => {
    it('clic sur × supprime le toast', async () => {
        const { component, findByLabelText, queryByText } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ message: 'Fermer moi', type: 'info', duration: 0 })
        const btn = await findByLabelText('Fermer')
        await fireEvent.click(btn)
        expect(queryByText('Fermer moi')).not.toBeInTheDocument()
    })

    it("clic sur × appelle onCallback si dismiss_cb est défini", async () => {
        const onCallback = vi.fn()
        const { component, findByLabelText } = render(Notify, { onCallback })
        component.addNotify({ message: 'Callback', type: 'info', duration: 0, dismiss_cb: 'cb_dismiss' })
        const btn = await findByLabelText('Fermer')
        await fireEvent.click(btn)
        expect(onCallback).toHaveBeenCalledWith('cb_dismiss')
    })

    it("clic sur × n'appelle pas onCallback si dismiss_cb absent", async () => {
        const onCallback = vi.fn()
        const { component, findByLabelText } = render(Notify, { onCallback })
        component.addNotify({ message: 'Sans callback', type: 'info', duration: 0 })
        const btn = await findByLabelText('Fermer')
        await fireEvent.click(btn)
        expect(onCallback).not.toHaveBeenCalled()
    })
})

describe('Notify — types de toast', () => {
    const types = ['success', 'error', 'warning', 'info'] as const

    it.each(types)('se monte sans erreur pour le type %s', async (type) => {
        const { component } = render(Notify, { onCallback: vi.fn() })
        expect(() => component.addNotify({ message: `Toast ${type}`, type, duration: 0 })).not.toThrow()
    })
})
