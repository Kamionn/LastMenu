-- examples/progress_bar.lua
-- Progress bar showcase — all builder options.
--
-- Demonstrates:
--   • progress      — immediate one-shot
--   • progress_build — persistent handle
--   • p:label, p:duration, p:icon
--   • p:cancelable(bool) — allow Escape / cancel button
--   • p:confirm(cb)  — fires when bar fills naturally (completion)
--   • p:cancel(cb)   — fires when player cancels (only if cancelable = true)
--   • p:cb_tick(fn)  — called every ~100 ms with current pct 0–100
--   • p:anim(opts)   — plays a ped animation for the duration
--   • p:prop(opts)   — attaches a prop to the player ped for the duration
--   • All side effects (anim, prop) are cleaned up on complete / cancel / close

local LastMenu = exports['LastMenu']

local function notify(msg, t)
    LastMenu:notify(function(n) n:message(msg); n:type(t or 'info') end)
end

-- ── 1. Minimal one-shot ───────────────────────────────────────────────────────
RegisterCommand('progress_basic', function()
    LastMenu:progress(function(p)
        p:label('Loading…')
        p:duration(5000)
        p:confirm(function()
            notify('Loading complete!', 'success')
        end)
    end)
end, false)

-- ── 2. Cancelable with callbacks ──────────────────────────────────────────────
RegisterCommand('progress_cancel', function()
    LastMenu:progress(function(p)
        p:label('Hacking terminal…')
        p:icon('terminal')
        p:duration(8000)
        p:cancelable(true)
        p:confirm(function()
            notify('Terminal hacked!', 'success')
            TriggerServerEvent('hack:complete')
        end)
        p:cancel(function()
            notify('Hacking interrupted.', 'warning')
        end)
    end)
end, false)

-- ── 3. Ped animation + attached prop ─────────────────────────────────────────
-- The animation starts loading asynchronously; the bar opens immediately.
-- Both anim and prop are cleaned up automatically on any close path.
RegisterCommand('progress_weld', function()
    LastMenu:progress(function(p)
        p:label('Welding…')
        p:icon('zap')
        p:duration(10000)
        p:cancelable(true)

        p:anim({
            dict = 'amb@world_human_welding@male@base',
            clip = 'base',
            flag = 1,    -- AnimationFlag: 1 = loop
        })

        p:prop({
            model  = 'prop_tool_torch',
            bone   = 57005,                    -- right hand
            offset = vector3(0.12, 0.03, 0.0),
            rot    = vector3(0.0,  0.0,  0.0),
        })

        p:confirm(function()
            notify('Welding complete!', 'success')
            TriggerServerEvent('job:weldingDone')
        end)
        p:cancel(function()
            notify('Welding cancelled.', 'warning')
        end)
    end)
end, false)

-- ── 4. cb_tick — per-frame progress polling ───────────────────────────────────
-- Called every ~100 ms with a pct value from 0 to 100.
RegisterCommand('progress_tick', function()
    local halfway = false
    local quarter = false

    LastMenu:progress(function(p)
        p:label('Crafting…')
        p:icon('hammer')
        p:duration(12000)
        p:cancelable(true)

        p:anim({
            dict = 'anim@heists@ornate_bank@drill',
            clip = 'drill_straight_idle',
            flag = 1,
        })

        p:cb_tick(function(pct)
            if pct >= 25 and not quarter then
                quarter = true
                PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
            end
            if pct >= 50 and not halfway then
                halfway = true
                TriggerServerEvent('craft:halfwayDone')
                PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
            end
        end)

        p:confirm(function()
            notify('Item crafted!', 'success')
            TriggerServerEvent('craft:complete')
        end)
        p:cancel(function()
            notify('Crafting interrupted.', 'warning')
        end)
    end)
end, false)

-- ── 5. Reusable handle — progress_build ──────────────────────────────────────
-- Build once, open / close programmatically.
-- Closing via handle.close() does NOT fire confirm() or cancel().
local mineBar = LastMenu:progress_build(function(p)
    p:label('Mining…')
    p:icon('pickaxe')
    p:duration(6000)
    p:cancelable(false)

    p:anim({
        dict = 'amb@world_human_hammering@male@base',
        clip = 'base',
        flag = 1,
    })

    p:confirm(function()
        notify('Ore extracted!', 'success')
        TriggerServerEvent('mining:done')
    end)
end)

RegisterCommand('mine_start', function()
    mineBar.open()
end, false)

RegisterCommand('mine_stop', function()
    mineBar.close()
end, false)

-- ── 6. Full crafting flow — alert → progress → notify ────────────────────────
RegisterCommand('craft_sword', function()
    Citizen.CreateThread(function()
        local ok = LastMenu:alert_async(function(a)
            a:title('Craft Iron Sword')
            a:message('Requires: 3 × Iron Bar, 1 × Wood.\nThis will take 15 seconds.')
            a:confirm_label('Craft')
            a:cancel_label('Cancel')
        end)
        if not ok then return end

        LastMenu:progress(function(p)
            p:label('Forging Iron Sword…')
            p:icon('sword')
            p:duration(15000)
            p:cancelable(true)

            p:anim({
                dict = 'amb@world_human_hammering@male@base',
                clip = 'base',
                flag = 1,
            })

            p:confirm(function()
                notify('Iron Sword crafted!', 'success')
                TriggerServerEvent('craft:giveItem', 'iron_sword', 1)
            end)
            p:cancel(function()
                notify('Crafting cancelled — materials returned.', 'warning')
                TriggerServerEvent('craft:returnMaterials', 'iron_sword')
            end)
        end)
    end)
end, false)
