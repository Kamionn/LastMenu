import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent, waitFor } from '@testing-library/svelte'
import Input from '../components/Input.svelte'

const makeField = (overrides = {}) => ({
    label:   'Nom',
    type:    'text',
    default: '',
    index:   0,
    ...overrides,
})

const baseData = {
    title:   'Formulaire',
    fields:  [makeField()],
    confirm: { id: 'cb_ok',     label: 'Valider' },
    cancel:  { id: 'cb_cancel', label: 'Annuler' },
}

describe('Input — rendu', () => {
    it('affiche le titre', () => {
        const { getByText } = render(Input, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Formulaire')).toBeInTheDocument()
    })

    it('affiche le label du champ', () => {
        const { getByText } = render(Input, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Nom')).toBeInTheDocument()
    })

    it('affiche les boutons confirmer et annuler', () => {
        const { getByText } = render(Input, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Valider')).toBeInTheDocument()
        expect(getByText('Annuler')).toBeInTheDocument()
    })

    it('affiche tous les champs', () => {
        const data = {
            ...baseData,
            fields: [
                makeField({ label: 'Prénom', index: 0 }),
                makeField({ label: 'Nom', index: 1 }),
                makeField({ label: 'Email', type: 'email', index: 2 }),
            ],
        }
        const { getByText } = render(Input, { data, onCallback: vi.fn() })
        expect(getByText('Prénom')).toBeInTheDocument()
        expect(getByText('Nom')).toBeInTheDocument()
        expect(getByText('Email')).toBeInTheDocument()
    })

    it('pré-remplit la valeur par défaut', () => {
        const data = { ...baseData, fields: [makeField({ default: 'Alice' })] }
        const { getByRole } = render(Input, { data, onCallback: vi.fn() })
        expect(getByRole('textbox')).toHaveValue('Alice')
    })

    it("n'affiche pas le titre quand absent", () => {
        const { queryByText } = render(Input, {
            data: { ...baseData, title: undefined },
            onCallback: vi.fn(),
        })
        expect(queryByText('Formulaire')).not.toBeInTheDocument()
    })
})

describe('Input — callbacks', () => {
    it("clic sur Valider appelle onCallback avec confirm.id et les valeurs", async () => {
        const onCallback = vi.fn()
        const { getByText, getByRole } = render(Input, { data: baseData, onCallback })
        await fireEvent.input(getByRole('textbox'), { target: { value: 'Alice' } })
        await fireEvent.click(getByText('Valider'))
        expect(onCallback).toHaveBeenCalledWith('cb_ok', { values: ['Alice'] })
    })

    it("clic sur Annuler appelle onCallback avec cancel.id", async () => {
        const onCallback = vi.fn()
        const { getByText } = render(Input, { data: baseData, onCallback })
        await fireEvent.click(getByText('Annuler'))
        expect(onCallback).toHaveBeenCalledWith('cb_cancel')
    })

    it("Escape appelle cancel", async () => {
        const onCallback = vi.fn()
        const { getByRole } = render(Input, { data: baseData, onCallback })
        await fireEvent.keyDown(getByRole('textbox'), { key: 'Escape' })
        expect(onCallback).toHaveBeenCalledWith('cb_cancel')
    })

    it("Entrée sur le dernier champ confirme", async () => {
        const onCallback = vi.fn()
        const { getAllByRole } = render(Input, {
            data: { ...baseData, fields: [makeField({ index: 0 })] },
            onCallback,
        })
        const inputs = getAllByRole('textbox')
        await fireEvent.keyDown(inputs[0], { key: 'Enter' })
        expect(onCallback).toHaveBeenCalledWith('cb_ok', expect.any(Object))
    })

    it("Entrée sur un champ non-dernier ne confirme pas", async () => {
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            fields: [
                makeField({ label: 'Prénom', index: 0 }),
                makeField({ label: 'Nom',    index: 1 }),
            ],
        }
        const { getAllByRole } = render(Input, { data, onCallback })
        const inputs = getAllByRole('textbox')
        await fireEvent.keyDown(inputs[0], { key: 'Enter' })
        expect(onCallback).not.toHaveBeenCalled()
    })
})

describe('Input — validation', () => {
    it("valide un champ number hors-min (> 300ms)", async () => {
        vi.useFakeTimers()
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            fields: [makeField({ label: 'Âge', type: 'number', min: 18, max: 99, index: 0 })],
        }
        const { getByRole, findByText } = render(Input, { data, onCallback })
        await fireEvent.input(getByRole('spinbutton'), { target: { value: '5' } })
        vi.advanceTimersByTime(350)
        expect(await findByText(/Min/)).toBeInTheDocument()
        vi.useRealTimers()
    })

    it("valide un champ number hors-max (> 300ms)", async () => {
        vi.useFakeTimers()
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            fields: [makeField({ label: 'Âge', type: 'number', min: 18, max: 99, index: 0 })],
        }
        const { getByRole, findByText } = render(Input, { data, onCallback })
        await fireEvent.input(getByRole('spinbutton'), { target: { value: '200' } })
        vi.advanceTimersByTime(350)
        expect(await findByText(/Max/)).toBeInTheDocument()
        vi.useRealTimers()
    })

    it("affiche pattern_error pour une valeur ne correspondant pas au pattern", async () => {
        vi.useFakeTimers()
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            fields: [makeField({
                label:         'Code postal',
                pattern:       '^\\d{5}$',
                pattern_error: 'Format invalide (ex: 75001)',
                index:         0,
            })],
        }
        const { getByRole, findByText } = render(Input, { data, onCallback })
        await fireEvent.input(getByRole('textbox'), { target: { value: 'abc' } })
        vi.advanceTimersByTime(350)
        expect(await findByText('Format invalide (ex: 75001)')).toBeInTheDocument()
        vi.useRealTimers()
    })

    it("bloque la confirmation si une erreur est présente", async () => {
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            fields: [makeField({ label: 'Âge', type: 'number', min: 18, max: 99, index: 0 })],
        }
        const { getByRole, getByText } = render(Input, { data, onCallback })
        // Taper une valeur invalide puis confirmer immédiatement (sans attendre le debounce)
        await fireEvent.input(getByRole('spinbutton'), { target: { value: '5' } })
        await fireEvent.click(getByText('Valider'))
        expect(onCallback).not.toHaveBeenCalled()
    })

    it("laisse passer la confirmation si la valeur est valide", async () => {
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            fields: [makeField({ label: 'Âge', type: 'number', min: 18, max: 99, index: 0 })],
        }
        const { getByRole, getByText } = render(Input, { data, onCallback })
        await fireEvent.input(getByRole('spinbutton'), { target: { value: '25' } })
        await fireEvent.click(getByText('Valider'))
        expect(onCallback).toHaveBeenCalledWith('cb_ok', { values: ['25'] })
    })
})
