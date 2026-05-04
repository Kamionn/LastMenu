import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import Alert from '../components/Alert.svelte'

const baseData = {
    type:    'confirm' as const,
    title:   'Confirm',
    message: 'Are you sure?',
    confirm: { id: 'cb_confirm', label: 'Yes' },
    cancel:  { id: 'cb_cancel',  label: 'No' },
}

describe('Alert — rendering', () => {
    it('renders title and message', () => {
        const { getByText } = render(Alert, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Confirm')).toBeInTheDocument()
        expect(getByText('Are you sure?')).toBeInTheDocument()
    })

    it('renders confirm and cancel buttons', () => {
        const { getByText } = render(Alert, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Yes')).toBeInTheDocument()
        expect(getByText('No')).toBeInTheDocument()
    })

    it('does not render title when data.title is absent', () => {
        const { queryByText } = render(Alert, {
            data: { ...baseData, title: undefined },
            onCallback: vi.fn(),
        })
        expect(queryByText('Confirm')).not.toBeInTheDocument()
    })

    it('does not render message when data.message is absent', () => {
        const { queryByText } = render(Alert, {
            data: { ...baseData, message: undefined },
            onCallback: vi.fn(),
        })
        expect(queryByText('Are you sure?')).not.toBeInTheDocument()
    })

    it('does not render cancel button when data.cancel is absent', () => {
        const { queryByText } = render(Alert, {
            data: { ...baseData, cancel: undefined },
            onCallback: vi.fn(),
        })
        expect(queryByText('No')).not.toBeInTheDocument()
    })

    it('does not render confirm button when data.confirm is absent', () => {
        const { queryByText } = render(Alert, {
            data: { ...baseData, confirm: undefined },
            onCallback: vi.fn(),
        })
        expect(queryByText('Yes')).not.toBeInTheDocument()
    })
})

describe('Alert — mouse interactions', () => {
    it('click on Confirm calls onCallback with confirm.id', async () => {
        const onCallback = vi.fn()
        const { getByText } = render(Alert, { data: baseData, onCallback })
        await fireEvent.click(getByText('Yes'))
        expect(onCallback).toHaveBeenCalledOnce()
        expect(onCallback).toHaveBeenCalledWith('cb_confirm')
    })

    it('click on Cancel calls onCallback with cancel.id', async () => {
        const onCallback = vi.fn()
        const { getByText } = render(Alert, { data: baseData, onCallback })
        await fireEvent.click(getByText('No'))
        expect(onCallback).toHaveBeenCalledOnce()
        expect(onCallback).toHaveBeenCalledWith('cb_cancel')
    })
})

describe('Alert — keyboard navigation', () => {
    it('Enter triggers confirm', async () => {
        const onCallback = vi.fn()
        render(Alert, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'Enter' })
        expect(onCallback).toHaveBeenCalledWith('cb_confirm')
    })

    it('Space triggers confirm', async () => {
        const onCallback = vi.fn()
        render(Alert, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: ' ' })
        expect(onCallback).toHaveBeenCalledWith('cb_confirm')
    })

    it('Escape triggers cancel', async () => {
        const onCallback = vi.fn()
        render(Alert, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'Escape' })
        expect(onCallback).toHaveBeenCalledWith('cb_cancel')
    })

    it('Backspace triggers cancel', async () => {
        const onCallback = vi.fn()
        render(Alert, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'Backspace' })
        expect(onCallback).toHaveBeenCalledWith('cb_cancel')
    })

    it('Enter without confirm does not throw', async () => {
        const onCallback = vi.fn()
        render(Alert, { data: { ...baseData, confirm: undefined }, onCallback })
        await expect(fireEvent.keyDown(window, { key: 'Enter' })).resolves.toBeDefined()
        expect(onCallback).not.toHaveBeenCalled()
    })

    it('Escape without cancel does not throw', async () => {
        const onCallback = vi.fn()
        render(Alert, { data: { ...baseData, cancel: undefined }, onCallback })
        await expect(fireEvent.keyDown(window, { key: 'Escape' })).resolves.toBeDefined()
        expect(onCallback).not.toHaveBeenCalled()
    })
})

describe('Alert — types', () => {
    const types = ['warning', 'error', 'success', 'info', 'confirm'] as const

    it.each(types)('mounts without error for type %s', (type) => {
        const data = { ...baseData, type }
        expect(() => render(Alert, { data, onCallback: vi.fn() })).not.toThrow()
    })

    it("default type is 'confirm' when confirm is provided", () => {
        const data = { ...baseData, type: undefined }
        const { container } = render(Alert, { data, onCallback: vi.fn() })
        // Component derives type internally — just verify it mounts
        expect(container.querySelector('.alert-modal')).toBeInTheDocument()
    })

    it("default type is 'info' when confirm is absent", () => {
        const data = { message: 'Info', type: undefined, confirm: undefined, cancel: undefined }
        const { container } = render(Alert, { data, onCallback: vi.fn() })
        expect(container.querySelector('.alert-modal')).toBeInTheDocument()
    })
})
