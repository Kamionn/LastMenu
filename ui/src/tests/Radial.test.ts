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
        btn('cb_repair',  'Repair'),
        btn('cb_clean',   'Clean'),
        btn('cb_inspect', 'Inspect'),
    ],
}

describe('Radial — rendering', () => {
    it('renders center_label when no sector is selected', () => {
        const { getByText } = render(Radial, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Actions')).toBeInTheDocument()
    })

    it('renders labels of all visible buttons', () => {
        const { getByText } = render(Radial, { data: baseData, onCallback: vi.fn() })
        expect(getByText('Repair')).toBeInTheDocument()
        expect(getByText('Clean')).toBeInTheDocument()
        expect(getByText('Inspect')).toBeInTheDocument()
    })

    it('does not render invisible buttons (visible=false)', () => {
        const data = {
            ...baseData,
            buttons: [
                btn('cb_a', 'Visible'),
                btn('cb_b', 'Hidden', { visible: false }),
            ],
        }
        const { getByText, queryByText } = render(Radial, { data, onCallback: vi.fn() })
        expect(getByText('Visible')).toBeInTheDocument()
        expect(queryByText('Hidden')).not.toBeInTheDocument()
    })

    it('renders SVG container', () => {
        const { container } = render(Radial, { data: baseData, onCallback: vi.fn() })
        expect(container.querySelector('.radial-svg')).toBeInTheDocument()
    })

    it('renders center dot when center_label is absent', () => {
        const data = { ...baseData, center_label: undefined }
        const { container } = render(Radial, { data, onCallback: vi.fn() })
        expect(container.querySelector('.center-dot')).toBeInTheDocument()
    })

    it('applies is-closing class when closing=true', () => {
        const { container } = render(Radial, { data: baseData, onCallback: vi.fn(), closing: true })
        expect(container.querySelector('.radial-overlay')).toHaveClass('is-closing')
    })
})

describe('Radial — keyboard navigation', () => {
    it('ArrowRight selects first button', async () => {
        const { getByText } = render(Radial, { data: baseData, onCallback: vi.fn() })
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        // First selected button appears in .center-area
        expect(getByText('Repair')).toBeInTheDocument()
    })

    it('ArrowRight then ArrowRight selects second button', async () => {
        const onCallback = vi.fn()
        const { getByText } = render(Radial, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        expect(getByText('Clean')).toBeInTheDocument()
    })

    it('Enter on selected button calls onCallback', async () => {
        const onCallback = vi.fn()
        render(Radial, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        await fireEvent.keyDown(window, { key: 'Enter' })
        expect(onCallback).toHaveBeenCalledWith('cb_repair')
    })

    it('Space on selected button calls onCallback', async () => {
        const onCallback = vi.fn()
        render(Radial, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        await fireEvent.keyDown(window, { key: ' ' })
        expect(onCallback).toHaveBeenCalledWith('cb_repair')
    })

    it('Tab cycles through buttons', async () => {
        const onCallback = vi.fn()
        render(Radial, { data: baseData, onCallback })
        await fireEvent.keyDown(window, { key: 'Tab' })
        await fireEvent.keyDown(window, { key: 'Enter' })
        expect(onCallback).toHaveBeenCalledOnce()
    })

    it('Enter with no selection (kbIndex=-1, selectedIndex=-1) does not throw', async () => {
        const onCallback = vi.fn()
        render(Radial, { data: baseData, onCallback })
        await expect(fireEvent.keyDown(window, { key: 'Enter' })).resolves.toBeDefined()
        expect(onCallback).not.toHaveBeenCalled()
    })

    it('skips disabled buttons during keyboard cycle', async () => {
        const onCallback = vi.fn()
        const data = {
            ...baseData,
            buttons: [
                btn('cb_a', 'Active'),
                btn('cb_b', 'Disabled', { disabled: true }),
                btn('cb_c', 'Also active'),
            ],
        }
        render(Radial, { data, onCallback })
        // First ArrowRight → 'Active' (index 0)
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        await fireEvent.keyDown(window, { key: 'Enter' })
        expect(onCallback).toHaveBeenCalledWith('cb_a')

        // Second ArrowRight → skips 'Disabled', lands on 'Also active'
        onCallback.mockClear()
        await fireEvent.keyDown(window, { key: 'ArrowRight' })
        await fireEvent.keyDown(window, { key: 'Enter' })
        expect(onCallback).toHaveBeenCalledWith('cb_c')
    })
})

describe('Radial — edge cases', () => {
    it('mounts without error with zero buttons', () => {
        const data = { center_label: 'Empty', buttons: [] }
        expect(() => render(Radial, { data, onCallback: vi.fn() })).not.toThrow()
    })

    it('mounts without error with a single button', () => {
        const data = { buttons: [btn('cb_only', 'Solo')] }
        const { getByText } = render(Radial, { data, onCallback: vi.fn() })
        expect(getByText('Solo')).toBeInTheDocument()
    })

    it('mounts without error with 8 buttons', () => {
        const buttons = Array.from({ length: 8 }, (_, i) => btn(`cb_${i}`, `Action ${i}`))
        const { container } = render(Radial, { data: { buttons }, onCallback: vi.fn() })
        expect(container.querySelectorAll('.sector-icon')).toHaveLength(8)
    })
})
