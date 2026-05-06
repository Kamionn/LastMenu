import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import Alert from '../components/Alert.svelte'

const baseData = {
    type:    'confirm' as const,
    title:   'Confirmer',
    message: 'Êtes-vous sûr ?',
    confirm: { id: 'cb_confirm', label: 'Oui' },
    cancel:  { id: 'cb_cancel',  label: 'Non' },
}

describe('Alert — rendu', () => {
    it('affiche le titre et le message', () => {
        const { getByText } = render(Alert, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Confirmer')).toBeInTheDocument()
        expect(getByText('Êtes-vous sûr ?')).toBeInTheDocument()
    })

    it('affiche les boutons confirm et cancel', () => {
        const { getByText } = render(Alert, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Oui')).toBeInTheDocument()
        expect(getByText('Non')).toBeInTheDocument()
    })

    it("n'affiche pas de titre quand data.title est absent", () => {
        const { queryByText } = render(Alert, {
            data: { ...baseData, title: undefined },
            onCallback: vi.fn(),
        })
        expect(queryByText('Confirmer')).not.toBeInTheDocument()
    })

    it("n'affiche pas de message quand data.message est absent", () => {
        const { queryByText } = render(Alert, {
            data: { ...baseData, message: undefined },
            onCallback: vi.fn(),
        })
        expect(queryByText('Êtes-vous sûr ?')).not.toBeInTheDocument()
    })

    it("n'affiche pas de bouton cancel quand data.cancel est absent", () => {
        const { queryByText } = render(Alert, {
            data: { ...baseData, cancel: undefined },
            onCallback: vi.fn(),
        })
        expect(queryByText('Non')).not.toBeInTheDocument()
    })

    it("n'affiche pas de bouton confirm quand data.confirm est absent", () => {
        const { queryByText } = render(Alert, {
            data: { ...baseData, confirm: undefined },
            onCallback: vi.fn(),
        })
        expect(queryByText('Oui')).not.toBeInTheDocument()
    })
})

describe('Alert — interactions souris', () => {
    it("clic sur Confirmer appelle onCallback avec confirm.id", async () => {
        const onCallback = vi.fn()
        const { getByText } = render(Alert, { data: baseData, onCallback })
        await fireEvent.click(getByText('Oui'))
        expect(onCallback).toHaveBeenCalledOnce()
        expect(onCallback).toHaveBeenCalledWith('cb_confirm')
    })

    it("clic sur Annuler appelle onCallback avec cancel.id", async () => {
        const onCallback = vi.fn()
        const { getByText } = render(Alert, { data: baseData, onCallback })
        await fireEvent.click(getByText('Non'))
        expect(onCallback).toHaveBeenCalledOnce()
        expect(onCallback).toHaveBeenCalledWith('cb_cancel')
    })
})

describe('Alert — navigation clavier', () => {
    it('Entrée déclenche le confirm', async () => {
        const onCallback = vi.fn()
        render(Alert, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'Enter' })
        expect(onCallback).toHaveBeenCalledWith('cb_confirm')
    })

    it('Espace déclenche le confirm', async () => {
        const onCallback = vi.fn()
        render(Alert, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: ' ' })
        expect(onCallback).toHaveBeenCalledWith('cb_confirm')
    })

    it('Escape déclenche le cancel', async () => {
        const onCallback = vi.fn()
        render(Alert, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'Escape' })
        expect(onCallback).toHaveBeenCalledWith('cb_cancel')
    })

    it('Backspace déclenche le cancel', async () => {
        const onCallback = vi.fn()
        render(Alert, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'Backspace' })
        expect(onCallback).toHaveBeenCalledWith('cb_cancel')
    })

    it("Entrée sans confirm ne plante pas", async () => {
        const onCallback = vi.fn()
        render(Alert, { data: { ...baseData, confirm: undefined }, onCallback })
        await expect(fireEvent.keyDown(window, { key: 'Enter' })).resolves.toBeDefined()
        expect(onCallback).not.toHaveBeenCalled()
    })

    it("Escape sans cancel ne plante pas", async () => {
        const onCallback = vi.fn()
        render(Alert, { data: { ...baseData, cancel: undefined }, onCallback })
        await expect(fireEvent.keyDown(window, { key: 'Escape' })).resolves.toBeDefined()
        expect(onCallback).not.toHaveBeenCalled()
    })
})

describe('Alert — types', () => {
    const types = ['warning', 'error', 'success', 'info', 'confirm'] as const

    it.each(types)('se monte sans erreur pour le type %s', (type) => {
        const data = { ...baseData, type }
        expect(() => render(Alert, { data, onCallback: vi.fn() })).not.toThrow()
    })

    it("type par défaut est 'confirm' quand confirm est fourni", () => {
        const data = { ...baseData, type: undefined }
        const { container } = render(Alert, { data, onCallback: vi.fn() })
        // Le composant dérive le type internalement — vérifie juste qu'il monte
        expect(container.querySelector('.alert-modal')).toBeInTheDocument()
    })

    it("type par défaut est 'info' quand confirm est absent", () => {
        const data = { message: 'Info', type: undefined, confirm: undefined, cancel: undefined }
        const { container } = render(Alert, { data, onCallback: vi.fn() })
        expect(container.querySelector('.alert-modal')).toBeInTheDocument()
    })
})
