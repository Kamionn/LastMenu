-- examples/async_confirm.lua
-- Async UI patterns: alert and input in sequence, all in one coroutine.
--
-- Demonstrates:
--   • UI_AlertAsync  — coroutine-blocking confirmation (returns true/false)
--   • UI_InputAsync  — coroutine-blocking form (returns values[] or nil)
--   • Chained multi-step UI without nested callbacks
--   • Field types: text, number; field validation: maxlen, min, max, pattern
--   • Wrapping a RegisterCommand inside Citizen.CreateThread (required)

-- ── Bank Transfer ─────────────────────────────────────────────────────────────
RegisterCommand('transfer', function()
    -- *_async functions must be called from a coroutine.
    Citizen.CreateThread(function()

        -- Step 1 — confirm intent
        local proceed = UI_AlertAsync(function(a)
            a:title('Bank Transfer')
            a:message('You are about to initiate a bank transfer.\nContinue?')
            a:confirm_label('Continue')
            a:cancel_label('Abort')
        end)
        if not proceed then return end

        -- Step 2 — collect transfer details
        local values = UI_InputAsync(function(b)
            b:title('Transfer Details')
            b:field('Recipient ID', {
                type        = 'text',
                placeholder = 'e.g. PLAYER-42',
                maxlen      = 20,
                pattern       = '^[A-Z]+-\\d+$',        -- must match WORD-number
                pattern_error = 'Format expected: NAME-123',
            })
            b:field('Amount (€)', {
                type    = 'number',
                min     = 1,
                max     = 50000,
                default = 100,
            })
            b:field('Note (optional)', {
                type        = 'text',
                placeholder = 'Payment reason…',
                maxlen      = 60,
            })
            b:confirm_label('Send')
            b:cancel_label('Back')
        end)
        if not values then return end  -- user cancelled

        local recipient = values[1]
        local amount    = values[2]   -- auto-cast to number (opts.type = 'number')
        local note      = values[3] or ''

        -- Step 3 — final confirmation with summary
        local finalOk = UI_AlertAsync(function(a)
            a:title('Confirm Transfer')
            a:message(string.format(
                'Send %d€ to %s?\n%s',
                amount, recipient,
                note ~= '' and ('Note: "' .. note .. '"') or '(no note)'
            ))
            a:confirm_label('Send Now')
            a:cancel_label('Edit')
        end)
        if not finalOk then
            -- Return to step 2 — simplified: just re-run the command
            TriggerEvent('transfer_restart')
            return
        end

        -- Step 4 — execute
        TriggerServerEvent('bank:transfer', recipient, amount, note)

        UI_Notify(function(n)
            n:message(string.format('Sent %d€ to %s.', amount, recipient))
            n:type('success')
            n:icon('send')
            n:duration(5000)
        end)
    end)
end, false)

-- ── Character Creator — multi-field form ─────────────────────────────────────
-- Shows pattern validation, typed fields, and chained alert for final confirm.
RegisterCommand('create_char', function()
    Citizen.CreateThread(function()
        local values = UI_InputAsync(function(b)
            b:title('Create Character')
            b:field('First Name', {
                type          = 'text',
                placeholder   = 'John',
                maxlen        = 20,
                pattern       = '^[A-Za-z]+$',
                pattern_error = 'Letters only.',
            })
            b:field('Last Name', {
                type          = 'text',
                placeholder   = 'Doe',
                maxlen        = 20,
                pattern       = '^[A-Za-z]+$',
                pattern_error = 'Letters only.',
            })
            b:field('Age', {
                type    = 'number',
                min     = 18,
                max     = 90,
                default = 25,
            })
            b:confirm_label('Create')
            b:cancel_label('Cancel')
        end)
        if not values then return end

        local firstName = values[1]
        local lastName  = values[2]
        local age       = values[3]   -- number

        local ok = UI_AlertAsync(function(a)
            a:title('Confirm Character')
            a:message(string.format(
                'Create %s %s, age %d?\n\nThis action cannot be undone.',
                firstName, lastName, age
            ))
            a:confirm_label('Confirm')
            a:cancel_label('Go Back')
        end)
        if not ok then return end

        TriggerServerEvent('character:create', firstName, lastName, age)

        UI_Notify(function(n)
            n:message(string.format('Character "%s %s" created!', firstName, lastName))
            n:type('success')
            n:icon('user')
            n:duration(4000)
        end)
    end)
end, false)

-- ── Non-blocking (callback) variant — UI_Alert ────────────────────────────────
-- Use this when you do NOT need the coroutine-blocking behaviour.
RegisterCommand('delete_save', function()
    UI_Alert(function(a)
        a:title('Delete Save File')
        a:message('This action is irreversible. All progress will be lost.')
        a:type('warn')
        a:confirm('Delete', function()
            TriggerServerEvent('save:delete')
            UI_Notify(function(n) n:message('Save deleted.'); n:type('error') end)
        end)
        a:cancel('Cancel')
    end)
end, false)
