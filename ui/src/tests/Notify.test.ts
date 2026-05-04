import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import Notify from '../components/Notify.svelte'

describe('Notify — addNotify', () => {
    it('renders a toast with message', async () => {
        const { component, findByText } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ message: 'Operation successful', type: 'success', duration: 0 })
        expect(await findByText('Operation successful')).toBeInTheDocument()
    })

    it('renders toast title when provided', async () => {
        const { component, findByText } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ title: 'Success', message: 'Vehicle repaired', type: 'success', duration: 0 })
        expect(await findByText('Success')).toBeInTheDocument()
        expect(await findByText('Vehicle repaired')).toBeInTheDocument()
    })

    it('renders multiple independent toasts', async () => {
        const { component, findByText } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ message: 'Toast A', type: 'info',    duration: 0 })
        component.addNotify({ message: 'Toast B', type: 'warning', duration: 0 })
        expect(await findByText('Toast A')).toBeInTheDocument()
        expect(await findByText('Toast B')).toBeInTheDocument()
    })

    it('replaces existing toast with same group', async () => {
        const { component, findByText, queryByText } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ message: 'Old',  type: 'info', duration: 0, group: 'status' })
        component.addNotify({ message: 'New', type: 'info', duration: 0, group: 'status' })
        expect(await findByText('New')).toBeInTheDocument()
        // Old toast is replaced
        expect(queryByText('Old')).not.toBeInTheDocument()
    })

    it('does not render timer bar when duration=0 (persistent)', async () => {
        const { component, container } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ message: 'Persistent', type: 'info', duration: 0 })
        // Wait for mount
        await new Promise(r => setTimeout(r, 10))
        expect(container.querySelector('.timer-bar')).not.toBeInTheDocument()
    })

    it('renders timer bar when duration > 0', async () => {
        const { component, container } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ message: 'Temporary', type: 'info', duration: 3000 })
        await new Promise(r => setTimeout(r, 10))
        expect(container.querySelector('.timer-bar')).toBeInTheDocument()
    })
})

describe('Notify — interactions', () => {
    it('click on × removes the toast', async () => {
        const { component, findByLabelText, queryByText } = render(Notify, { onCallback: vi.fn() })
        component.addNotify({ message: 'Close me', type: 'info', duration: 0 })
        const btn = await findByLabelText('Close')
        await fireEvent.click(btn)
        expect(queryByText('Close me')).not.toBeInTheDocument()
    })

    it('click on × calls onCallback if dismiss_cb is defined', async () => {
        const onCallback = vi.fn()
        const { component, findByLabelText } = render(Notify, { onCallback })
        component.addNotify({ message: 'Callback', type: 'info', duration: 0, dismiss_cb: 'cb_dismiss' })
        const btn = await findByLabelText('Close')
        await fireEvent.click(btn)
        expect(onCallback).toHaveBeenCalledWith('cb_dismiss')
    })

    it('click on × does not call onCallback if dismiss_cb is absent', async () => {
        const onCallback = vi.fn()
        const { component, findByLabelText } = render(Notify, { onCallback })
        component.addNotify({ message: 'No callback', type: 'info', duration: 0 })
        const btn = await findByLabelText('Close')
        await fireEvent.click(btn)
        expect(onCallback).not.toHaveBeenCalled()
    })
})

describe('Notify — toast types', () => {
    const types = ['success', 'error', 'warning', 'info'] as const

    it.each(types)('mounts without error for type %s', async (type) => {
        const { component } = render(Notify, { onCallback: vi.fn() })
        expect(() => component.addNotify({ message: `Toast ${type}`, type, duration: 0 })).not.toThrow()
    })
})
