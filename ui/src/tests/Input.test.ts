import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent, waitFor } from '@testing-library/svelte'
import Input from '../components/Input.svelte'

const makeField = (overrides = {}) => ({
    label:   'Name',
    type:    'text',
    default: '',
    index:   0,
    ...overrides,
})

const baseData = {
    title:   'Form',
    fields:  [makeField()],
    confirm: { id: 'cb_ok',     label: 'Submit' },
    cancel:  { id: 'cb_cancel', label: 'Cancel' },
}

describe('Input — rendering', () => {
    it('renders title', () => {
        const { getByText } = render(Input, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Form')).toBeInTheDocument()
    })

    it('renders field label', () => {
        const { getByText } = render(Input, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Name')).toBeInTheDocument()
    })

    it('renders submit and cancel buttons', () => {
        const { getByText } = render(Input, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Submit')).toBeInTheDocument()
        expect(getByText('Cancel')).toBeInTheDocument()
    })

    it('renders all fields', () => {
        const data = {
            ...baseData,
            fields: [
                makeField({ label: 'First Name', index: 0 }),
                makeField({ label: 'Last Name',  index: 1 }),
                makeField({ label: 'Email', type: 'email', index: 2 }),
            ],
        }
        const { getByText } = render(Input, { data, onCallback: vi.fn() })
        expect(getByText('First Name')).toBeInTheDocument()
        expect(getByText('Last Name')).toBeInTheDocument()
        expect(getByText('Email')).toBeInTheDocument()
    })

    it('pre-fills default value', () => {
        const data = { ...baseData, fields: [makeField({ default: 'Alice' })] }
        const { getByRole } = render(Input, { data, onCallback: vi.fn() })
        expect(getByRole('textbox')).toHaveValue('Alice')
    })

    it('does not render title when absent', () => {
        const { queryByText } = render(Input, {
            data: { ...baseData, title: undefined },
            onCallback: vi.fn(),
        })
        expect(queryByText('Form')).not.toBeInTheDocument()
    })
})

describe('Input — callbacks', () => {
    it('click on Submit calls onCallback with confirm.id and values', async () => {
        const onCallback = vi.fn()
        const { getByText, getByRole } = render(Input, { data: baseData, onCallback })
        await fireEvent.input(getByRole('textbox'), { target: { value: 'Alice' } })
        await fireEvent.click(getByText('Submit'))
        expect(onCallback).toHaveBeenCalledWith('cb_ok', { values: ['Alice'] })
    })

    it('click on Cancel calls onCallback with cancel.id', async () => {
        const onCallback = vi.fn()
        const { getByText } = render(Input, { data: baseData, onCallback })
        await fireEvent.click(getByText('Cancel'))
        expect(onCallback).toHaveBeenCalledWith('cb_cancel')
    })

    it('Escape calls cancel', async () => {
        const onCallback = vi.fn()
        const { getByRole } = render(Input, { data: baseData, onCallback })
        await fireEvent.keyDown(getByRole('textbox'), { key: 'Escape' })
        expect(onCallback).toHaveBeenCalledWith('cb_cancel')
    })

    it('Enter on last field confirms', async () => {
        const onCallback = vi.fn()
        const { getAllByRole } = render(Input, {
            data: { ...baseData, fields: [makeField({ index: 0 })] },
            onCallback,
        })
        const inputs = getAllByRole('textbox')
        await fireEvent.keyDown(inputs[0], { key: 'Enter' })
        expect(onCallback).toHaveBeenCalledWith('cb_ok', expect.any(Object))
    })

    it('Enter on non-last field does not confirm', async () => {
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            fields: [
                makeField({ label: 'First Name', index: 0 }),
                makeField({ label: 'Last Name',  index: 1 }),
            ],
        }
        const { getAllByRole } = render(Input, { data, onCallback })
        const inputs = getAllByRole('textbox')
        await fireEvent.keyDown(inputs[0], { key: 'Enter' })
        expect(onCallback).not.toHaveBeenCalled()
    })
})

describe('Input — validation', () => {
    it('validates number field below min (> 300ms)', async () => {
        vi.useFakeTimers()
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            fields: [makeField({ label: 'Age', type: 'number', min: 18, max: 99, index: 0 })],
        }
        const { getByRole, findByText } = render(Input, { data, onCallback })
        await fireEvent.input(getByRole('spinbutton'), { target: { value: '5' } })
        vi.advanceTimersByTime(350)
        expect(await findByText(/Min/)).toBeInTheDocument()
        vi.useRealTimers()
    })

    it('validates number field above max (> 300ms)', async () => {
        vi.useFakeTimers()
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            fields: [makeField({ label: 'Age', type: 'number', min: 18, max: 99, index: 0 })],
        }
        const { getByRole, findByText } = render(Input, { data, onCallback })
        await fireEvent.input(getByRole('spinbutton'), { target: { value: '200' } })
        vi.advanceTimersByTime(350)
        expect(await findByText(/Max/)).toBeInTheDocument()
        vi.useRealTimers()
    })

    it('shows pattern_error for value not matching pattern', async () => {
        vi.useFakeTimers()
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            fields: [makeField({
                label:         'Zip code',
                pattern:       '^\\d{5}$',
                pattern_error: 'Invalid format (e.g. 75001)',
                index:         0,
            })],
        }
        const { getByRole, findByText } = render(Input, { data, onCallback })
        await fireEvent.input(getByRole('textbox'), { target: { value: 'abc' } })
        vi.advanceTimersByTime(350)
        expect(await findByText('Invalid format (e.g. 75001)')).toBeInTheDocument()
        vi.useRealTimers()
    })

    it('blocks confirm when an error is present', async () => {
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            fields: [makeField({ label: 'Age', type: 'number', min: 18, max: 99, index: 0 })],
        }
        const { getByRole, getByText } = render(Input, { data, onCallback })
        // Type an invalid value then confirm immediately (without waiting for debounce)
        await fireEvent.input(getByRole('spinbutton'), { target: { value: '5' } })
        await fireEvent.click(getByText('Submit'))
        expect(onCallback).not.toHaveBeenCalled()
    })

    it('allows confirm when value is valid', async () => {
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            fields: [makeField({ label: 'Age', type: 'number', min: 18, max: 99, index: 0 })],
        }
        const { getByRole, getByText } = render(Input, { data, onCallback })
        await fireEvent.input(getByRole('spinbutton'), { target: { value: '25' } })
        await fireEvent.click(getByText('Submit'))
        expect(onCallback).toHaveBeenCalledWith('cb_ok', { values: ['25'] })
    })
})
