-- stack.lua
-- Navigation stack + NUI focus management.
-- Registered in the LastMenu namespace as LastMenu.Stack.

local Bridge     = LastMenu.Bridge
local Config     = LastMenu.Config
local EasySwitch = LastMenu.EasySwitch
local Sound      = LastMenu.Sound

-- Dispatch NUI focus acquisition based on nav mode.
-- 'keyboard' → mouse cursor suppressed (keep input for keyboard nav).
-- anything else ('both', 'mouse') → full NUI focus with mouse cursor.
local _navFocus = EasySwitch.new()
    :when('keyboard', function()
        SetNuiFocus(true, false)
        SetNuiFocusKeepInput(true)
    end)
    :default(function()
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
    end)

---@class LM.StackEntry
---@field id          string
---@field type        string   'context'|'alert'|'input'|'progress'|'radial'|'target'
---@field nav?        string   'mouse'|'keyboard'|'both'
---@field cancelable? boolean

---@class LM.Stack
---@field _entries    LM.StackEntry[]
---@field _reactive   LM.Reactive|nil
---@field _openCoords vector3|nil

local Stack = {}
Stack._entries    = {}
Stack._reactive   = nil   -- set by reactive.lua after it loads
Stack._openCoords = nil

local function _resolveNav(entry)
    local nav = entry.nav or 'both'
    if nav == 'both' then nav = LastMenu._userNav or 'both' end
    return nav
end

-- Auto-closes the stack when the player walks too far from where the menu opened.
Citizen.CreateThread(function()
    while true do
        local dist = Config.close_on_distance
        if dist and #Stack._entries > 0 and Stack._openCoords then
            local cur = GetEntityCoords(PlayerPedId())
            if #(cur - Stack._openCoords) > dist then
                Stack.clear()
            end
        end
        Citizen.Wait(250)
    end
end)

-- ── Core operations ───────────────────────────────────────────────────────────

-- Pushes a menu onto the stack. Pauses the previous top's reactive watchers.
-- Acquires NUI focus on the first push.
---@param entry LM.StackEntry
function Stack.push(entry)
    local wasEmpty = #Stack._entries == 0
    local maxDepth = Config.max_stack_depth or 10

    if #Stack._entries >= maxDepth then
        print(('[LastMenu] max_stack_depth (%d) reached — push ignored (%s)')
            :format(maxDepth, entry.type or '?'))
        return
    end

    if not wasEmpty and Stack._reactive then
        local prev = Stack._entries[#Stack._entries]
        Stack._reactive.pause(prev.id)
    end

    if wasEmpty then
        Stack._openCoords = GetEntityCoords(PlayerPedId())
    end

    table.insert(Stack._entries, entry)
    if LastMenu._userSounds then Sound.play('open') end

    TriggerEvent('LastMenu:menuOpened', entry.id, entry.type or 'unknown')

    if wasEmpty then
        local nav = _resolveNav(entry)

        _navFocus:execute(nav)
    end
end

-- Pops the top menu, cleans up its callbacks and reactive state, and restores focus.
function Stack.pop()
    local n = #Stack._entries
    if n == 0 then return end

    local entry = Stack._entries[n]
    table.remove(Stack._entries, n)
    if LastMenu._userSounds then Sound.play('close') end

    TriggerEvent('LastMenu:menuClosed', entry.id, entry.type or 'unknown')
    Bridge.send('close', { id = entry.id })
    Bridge.removeCallbacks(entry.id)

    if Stack._reactive then
        Stack._reactive.stopTicking(entry.id)
    end

    if #Stack._entries > 0 and Stack._reactive then
        local newTop = Stack._entries[#Stack._entries]
        Stack._reactive.resume(newTop.id)
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        Stack._openCoords = nil
    end
end

-- Returns the top entry without removing it.
---@return LM.StackEntry|nil
function Stack.peek()
    return Stack._entries[#Stack._entries]
end

-- Pops all entries in order.
function Stack.clear()
    while #Stack._entries > 0 do
        Stack.pop()
    end
end

-- ── Resource lifecycle ────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        -- Release NUI focus synchronously BEFORE queuing Stack.clear().
        -- The Bridge batch queue may not flush before the resource exits,
        -- but SetNuiFocus is a native call and executes immediately.
        if #Stack._entries > 0 then
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
        end
        Stack.clear()
    end
end)

-- ── Overlay helpers (user settings panel, etc.) ───────────────────────────────

-- Acquires full NUI focus for an overlay component.
function Stack.overlayOpen()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
end

-- Restores NUI focus to the current top menu after an overlay closes.
function Stack.overlayClose()
    local top = Stack.peek()

    if not top then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        return
    end

    local nav = _resolveNav(top)

    _navFocus:execute(nav)
end

-- ── Register in namespace ─────────────────────────────────────────────────────
rawset(LastMenu, 'Stack', Stack)

-- Wire the Bridge close hook: NUI escape and __cancel__ both pop the cancelable
-- top menu. Defined here (not in bridge.lua) so Bridge has no reverse dependency
-- on Stack — Bridge loads first and only knows about the hook interface.
Bridge.onClose = function()
    local top = Stack.peek()
    if top and top.cancelable ~= false then Stack.pop() end
end
