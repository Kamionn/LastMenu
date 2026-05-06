-- exports.lua
-- This file is loaded last. After all modules are registered via rawset,
-- we apply the __newindex metatable lock to prevent external writes to LastMenu.

local Stack = LastMenu.Stack

-- ── Namespace lock ─────────────────────────────────────────────────────────
-- Must run after all rawset(LastMenu, ...) calls in other files.
setmetatable(LastMenu, {
    __newindex = function(_, key, _)
        error('[LastMenu] Attempt to write to read-only namespace (key: ' .. tostring(key) .. ')', 2)
    end
})

-- ── Debug / test command ───────────────────────────────────────────────────

RegisterCommand('lm_test', function()
    if type(RunLastMenuTests) == 'function' then
        RunLastMenuTests()
    else
        print('[LastMenu] Tests not loaded. Uncomment "test/regression.lua" in fxmanifest.lua.')
    end
end, 'lastmenu.dev')

-- ── Debug stats ────────────────────────────────────────────────────────────

--- Prints a snapshot of all active watcher state to the console.
--- Useful for diagnosing whether watchers are polling, disabled, or in safe-mode retry.
local function debugStats()
    local Reactive = LastMenu.Reactive
    if not Reactive then
        print('[LastMenu] debug_stats: Reactive module not loaded.')
        return
    end
    local state = Reactive.getStats()
    if not state or next(state) == nil then
        print('[LastMenu] debug_stats: No active menus.')
        return
    end
    print('[LastMenu] ── Watcher stats ──────────────────────────')
    for menuId, watchers in pairs(state) do
        print(string.format('  Menu: %s', menuId))
        for _, w in ipairs(watchers) do
            local status = w.disabled and (w.retryAt and 'retry@' .. w.retryAt or 'DISABLED') or 'ok'
            print(string.format('    cb=%-32s field=%-10s interval=%dms errors=%d status=%s',
                w.id, w.field, w.interval, w.errCount or 0, status))
        end
    end
    print('[LastMenu] ─────────────────────────────────────────')
end

RegisterCommand('lm_debug', debugStats, 'lastmenu.dev')

-- ── Debug overlay — draws watcher stats on-screen every frame ─────────────
local _overlayActive = false

local function _toggleOverlay()
    _overlayActive = not _overlayActive
    if not _overlayActive then return end
    Citizen.CreateThread(function()
        while _overlayActive do
            local Reactive = LastMenu.Reactive
            if Reactive then
                local state = Reactive.getStats()
                local y = 0.01
                for _, watchers in pairs(state) do
                    for _, w in ipairs(watchers) do
                        local status = w.disabled and 'DIS' or 'ok '
                        local line   = ('%s  %-4s  %4dms  %s'):format(
                            w.field, status, w.interval, w.id:sub(-16))
                        SetTextFont(4)
                        SetTextScale(0.3, 0.3)
                        SetTextColour(255, 255, 80, 220)
                        SetTextEntry('STRING')
                        AddTextComponentString(line)
                        DrawText(0.01, y)
                        y = y + 0.018
                    end
                end
            end
            Citizen.Wait(0)
        end
    end)
end

RegisterCommand('lm_overlay', _toggleOverlay, 'lastmenu.dev')

-- ── Internal exports ───────────────────────────────────────────────────────

exports('lastmenu_back', function()
    Stack.pop()
end)

-- Context
exports('context',        UI_Context)
exports('context_build',  UI_Context_Build)
exports('context_update', UI_Context_Update)

-- Alerts / notifications
exports('alert',          UI_Alert)
exports('alert_build',    UI_Alert_Build)
exports('alert_async',    UI_AlertAsync)
exports('confirm_async',  UI_ConfirmAsync)
exports('notify',         UI_Notify)

-- Progress
exports('progress',       UI_Progress)
exports('progress_build', UI_Progress_Build)

-- Radial
exports('radial',       UI_Radial)
exports('radial_build', UI_Radial_Build)

-- Input
exports('input',          UI_Input)
exports('input_build',    UI_Input_Build)
exports('input_async',    UI_InputAsync)

-- Target
exports('target_add_entity', UI_Target_AddEntity)
exports('target_add_model',  UI_Target_AddModel)
exports('target_add_sphere', UI_Target_AddSphere)
exports('target_add_box',    UI_Target_AddBox)
exports('target_add_poly',   UI_Target_AddPoly)
exports('target_update',     UI_Target_Update)
exports('target_remove',     UI_Target_Remove)
exports('target_clear',      UI_Target_Clear)

-- Observability
exports('debug_stats',    debugStats)
exports('debug_overlay',  _toggleOverlay)
exports('version',        function() return GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0' end)
