-- builders/context.lua
-- Builder for UI:context() — full vertical context menu.
-- Item types: button, slider, stepper, checkbox, toggle, list, stat,
--             input_inline, color_picker, date_picker, separator, header,
--             accordion, tab

local Bridge         = LastMenu.Bridge
local Stack          = LastMenu.Stack
local Reactive       = LastMenu.Reactive
local Config         = LastMenu.Config
local GenerateMenuId = LastMenu._genId
local assert_        = LastMenu._assert

local _stableId  = LastMenu._stableId
local _resName   = GetCurrentResourceName()

---@class LM.ContextBuilder
---@field title        fun(self: LM.ContextBuilder, str: string)
---@field banner       fun(self: LM.ContextBuilder, url: string)
---@field description  fun(self: LM.ContextBuilder, txt: string)
---@field nav          fun(self: LM.ContextBuilder, mode: 'both'|'mouse'|'keyboard')
---@field animation    fun(self: LM.ContextBuilder, anim: string)
---@field search       fun(self: LM.ContextBuilder, v?: boolean)
---@field page_size    fun(self: LM.ContextBuilder, n: integer)
---@field cancelable   fun(self: LM.ContextBuilder, v: boolean)
---@field scroll       fun(self: LM.ContextBuilder)
---@field button       fun(self: LM.ContextBuilder, label: string, opts?: table)
---@field slider       fun(self: LM.ContextBuilder, label: string, opts?: table)
---@field stepper      fun(self: LM.ContextBuilder, label: string, opts?: table)
---@field checkbox     fun(self: LM.ContextBuilder, label: string, opts?: table)
---@field toggle       fun(self: LM.ContextBuilder, label: string, opts?: table)
---@field list         fun(self: LM.ContextBuilder, label: string, opts?: table)
---@field stat         fun(self: LM.ContextBuilder, label: string, value?: number|fun():number, max?: number|fun():number, opts?: table)
---@field input_inline fun(self: LM.ContextBuilder, label: string, opts?: table)
---@field color_picker fun(self: LM.ContextBuilder, label: string, opts?: table)
---@field date_picker  fun(self: LM.ContextBuilder, label: string, opts?: table)
---@field separator    fun(self: LM.ContextBuilder)
---@field header       fun(self: LM.ContextBuilder, str: string, opts?: table)
---@field accordion    fun(self: LM.ContextBuilder, label: string, fn: fun(b: LM.ContextBuilder), opts?: table)
---@field tab          fun(self: LM.ContextBuilder, label: string, fn: fun(b: LM.ContextBuilder), opts?: table)
---@field submenu      fun(self: LM.ContextBuilder, label: string, subFn: fun(b: LM.ContextBuilder), opts?: table)
---@field back         fun(self: LM.ContextBuilder, label?: string, opts?: table)

---@class LM.ContextHandle
---@field open   fun()
---@field close  fun()
---@field update fun(newFn?: fun(menu: LM.ContextBuilder))

---@param  id string
---@param  fn fun(b: LM.ContextBuilder)
---@return table, table[], table[]
local function _buildContext(id, fn)
    local meta = {
        title       = '',
        banner      = nil,
        description = nil,
        nav         = 'both',
        animation   = nil,
        search      = false,
        pageSize    = 20,
        scroll      = false,
    }
    local items          = {}
    local watchers       = {}
    local accordionDepth = 0
    local b              = {}

    -- Per-build dedup table — reset each build so slugs are scoped to this menu only.
    local _used = {}
    local function sid(label, kind) return _stableId(id, label, kind, _used) end

    -- ── Helpers ───────────────────────────────────────────────────────────────

    local resolveField         = LastMenu._makeResolver(watchers)
    local normalizeConfirmHold = LastMenu._normalizeHold

    -- ── Meta ──────────────────────────────────────────────────────────────────

    function b:title(str)       meta.title       = str        end
    function b:banner(url)      meta.banner      = url        end
    function b:description(txt) meta.description = txt        end
    function b:nav(mode)        meta.nav         = mode       end
    function b:animation(anim)  meta.animation   = anim       end
    function b:search(v)        meta.search      = v ~= false end
    function b:page_size(n)     meta.pageSize    = n          end
    function b:cancelable(v)    meta.cancelable  = v          end
    function b:scroll()         meta.scroll      = true       end

    -- ── button ────────────────────────────────────────────────────────────────

    function b:button(label, opts)
        opts = opts or {}
        -- opts.id provides a stable cb_id across conditional item lists.
        -- Without it, the ID is positional and shifts when items are added/removed.
        local cb_id = opts.id or sid(label, 'btn')

        assert_(opts.cooldown,  'number',  'button.cooldown')
        assert_(opts.timeout,   'number',  'button.timeout')

        -- Defaults: visible/disabled poll at 500ms (was 250ms — lower CPU cost).
        local resolvedLabel    = resolveField(cb_id, label,         'label',   'string',  '',    opts.refresh or 500)
        local resolvedVisible  = resolveField(cb_id, opts.visible,  'visible', 'boolean', true,  opts.refresh or 500)
        local resolvedDisabled = resolveField(cb_id, opts.disabled, 'disabled','boolean', false, opts.refresh or 500)
        local resolvedColor    = resolveField(cb_id, opts.color,    'color',   'string',  nil,   opts.refresh or 500)
        local resolvedBadge    = resolveField(cb_id, opts.badge,    'badge',   'string',  nil,   opts.refresh or 500)
        local resolvedPreview  = resolveField(cb_id, opts.preview,  'preview', 'table',   nil,   opts.refresh or 500)

        -- Read persisted cooldown expiry from ResourceKvp.
        -- Key is persist_key if provided, otherwise the stable cb_id.
        -- Lua owns the key so both sides always agree on the format.
        local cd_key    = nil
        local cd_expiry = nil
        if opts.cooldown then
            cd_key = opts.persist_key or cb_id
            local stored = GetResourceKvpString('lm_cd_' .. _resName .. '_' .. cd_key)
            if stored then
                local expiry_ms = tonumber(stored)
                if expiry_ms and expiry_ms > os.time() * 1000 then
                    cd_expiry = expiry_ms
                end
            end
        end

        local keepOpen = opts.keep_open ~= false

        if opts.cb then
            local userCb = opts.cb
            Bridge.onCallback(cb_id, function(data)
                if not keepOpen then Stack.pop() end
                userCb(data)
            end, id)
        end

        items[#items + 1] = {
            kind         = 'button',
            id           = cb_id,
            label        = resolvedLabel,
            icon         = opts.icon         or nil,
            color        = resolvedColor,
            gradient     = opts.gradient     or false,
            badge        = resolvedBadge,
            hint         = opts.hint         or nil,
            hotkey       = opts.hotkey       or nil,
            arrow        = opts.arrow        or false,
            confirm_hold = normalizeConfirmHold(opts.confirm_hold),
            cooldown     = opts.cooldown     or nil,
            persist_key  = opts.persist_key  or nil,
            cooldown_key = cd_key,
            cd_expiry    = cd_expiry,
            keep_open    = keepOpen,
            preview      = resolvedPreview,
            visible      = resolvedVisible,
            disabled     = resolvedDisabled,
            timeout      = opts.timeout      or nil,
        }
    end

    -- ── slider ────────────────────────────────────────────────────────────────

    function b:slider(label, opts)
        opts = opts or {}
        assert_(opts.min,  'number', 'slider.min')
        assert_(opts.max,  'number', 'slider.max')
        assert_(opts.step, 'number', 'slider.step')
        local cb_id = opts.id or sid(label, 'slider')
        if opts.cb then
            local userCb = opts.cb
            Bridge.onCallback(cb_id, function(data) userCb(data.value) end, id)
        end
        items[#items + 1] = {
            kind   = 'slider', id = cb_id, label = label,
            icon   = opts.icon   or nil,
            min    = opts.min    or 0,
            max    = opts.max    or 100,
            step   = opts.step   or 1,
            value  = opts.default ~= nil and opts.default or (opts.min or 0),
            suffix = opts.suffix or '',
        }
    end

    -- ── stepper ───────────────────────────────────────────────────────────────

    function b:stepper(label, opts)
        opts = opts or {}
        assert_(opts.min,  'number', 'stepper.min')
        assert_(opts.max,  'number', 'stepper.max')
        assert_(opts.step, 'number', 'stepper.step')
        local cb_id = opts.id or sid(label, 'stepper')
        if opts.cb then
            local userCb = opts.cb
            Bridge.onCallback(cb_id, function(data) userCb(data.value) end, id)
        end
        items[#items + 1] = {
            kind   = 'stepper', id = cb_id, label = label,
            icon   = opts.icon   or nil,
            min    = opts.min    or 0,
            max    = opts.max    or 99,
            step   = opts.step   or 1,
            value  = opts.default ~= nil and opts.default or (opts.min or 0),
            suffix = opts.suffix or '',
        }
    end

    -- ── checkbox ──────────────────────────────────────────────────────────────

    function b:checkbox(label, opts)
        opts = opts or {}
        local cb_id = opts.id or sid(label, 'chk')
        if opts.cb then
            local userCb = opts.cb
            Bridge.onCallback(cb_id, function(data) userCb(data.value) end, id)
        end
        items[#items + 1] = {
            kind = 'checkbox', id = cb_id, label = label,
            icon = opts.icon or nil, value = opts.default == true,
        }
    end

    -- ── toggle ────────────────────────────────────────────────────────────────

    function b:toggle(label, opts)
        opts = opts or {}
        local cb_id = opts.id or sid(label, 'toggle')
        if opts.cb then
            local userCb = opts.cb
            Bridge.onCallback(cb_id, function(data) userCb(data.value) end, id)
        end
        items[#items + 1] = {
            kind = 'toggle', id = cb_id, label = label,
            icon = opts.icon or nil, value = opts.default == true,
        }
    end

    -- ── list ──────────────────────────────────────────────────────────────────

    function b:list(label, opts)
        opts = opts or {}
        local cb_id = opts.id or sid(label, 'list')
        if opts.cb then
            local userCb = opts.cb
            Bridge.onCallback(cb_id, function(data) userCb(data.index, data.value) end, id)
        end
        items[#items + 1] = {
            kind         = 'list', id = cb_id, label = label,
            icon         = opts.icon         or nil,
            items        = opts.items        or {},
            index        = (opts.default or 1) - 1,
            confirm_hold = normalizeConfirmHold(opts.confirm_hold),
        }
    end

    -- ── stat ──────────────────────────────────────────────────────────────────

    function b:stat(label, valueOrOpts, maxOrNil, optsOrNil)
        local opts, value, max
        if type(valueOrOpts) == 'table' then
            opts = valueOrOpts; value = opts.value; max = opts.max
        else
            value = valueOrOpts; max = maxOrNil; opts = optsOrNil or {}
        end

        local stat_id = opts.id or sid(label, 'stat')
        local resolvedValue = resolveField(stat_id, value,      'value', 'number', 0,   opts.refresh or 500)
        local resolvedMax   = resolveField(stat_id, max,        'max',   'number', 100, opts.refresh or 500)
        local resolvedColor = resolveField(stat_id, opts.color, 'color', 'string', nil, opts.refresh or 500)

        items[#items + 1] = {
            kind   = 'stat', id = stat_id, label = label,
            icon   = opts.icon   or nil,
            value  = resolvedValue,
            max    = resolvedMax,
            suffix = opts.suffix or '',
            color  = resolvedColor,
        }
    end

    -- ── input_inline ──────────────────────────────────────────────────────────

    function b:input_inline(label, opts)
        opts = opts or {}
        local cb_id = opts.id or sid(label, 'input')
        if opts.cb then
            local userCb = opts.cb
            Bridge.onCallback(cb_id, function(data) userCb(data.value) end, id)
        end
        items[#items + 1] = {
            kind        = 'input_inline', id = cb_id, label = label,
            icon        = opts.icon        or nil,
            inputType   = opts.type        or 'text',
            placeholder = opts.placeholder or '',
            default     = opts.default     or '',
            maxlen      = opts.maxlen      or nil,
            min         = opts.min         or nil,
            max         = opts.max         or nil,
        }
    end

    -- ── color_picker ──────────────────────────────────────────────────────────

    function b:color_picker(label, opts)
        opts = opts or {}
        local cb_id = opts.id or sid(label, 'color')
        if opts.cb then
            local userCb = opts.cb
            Bridge.onCallback(cb_id, function(data) userCb(data.value) end, id)
        end
        items[#items + 1] = {
            kind    = 'color_picker', id = cb_id, label = label,
            icon    = opts.icon    or nil,
            default = opts.default or '#e94560',
            presets = opts.presets or nil,
        }
    end

    -- ── date_picker ───────────────────────────────────────────────────────────

    function b:date_picker(label, opts)
        opts = opts or {}
        local cb_id = opts.id or sid(label, 'date')
        if opts.cb then
            local userCb = opts.cb
            Bridge.onCallback(cb_id, function(data) userCb(data.value) end, id)
        end
        items[#items + 1] = {
            kind    = 'date_picker', id = cb_id, label = label,
            icon    = opts.icon    or nil,
            default = opts.default or '',
            min     = opts.min     or nil,
            max     = opts.max     or nil,
            format  = opts.format  or 'dmy',
        }
    end

    -- ── accordion ─────────────────────────────────────────────────────────────

    function b:accordion(label, fn, opts)
        opts = opts or {}
        local acc_id = opts.id or sid(label, 'acc')
        items[#items + 1] = {
            kind        = 'accordion_start', id = acc_id,
            label       = label, icon = opts.icon or nil,
            defaultOpen = opts.open == true,
        }
        accordionDepth = accordionDepth + 1
        local ok, err = pcall(fn, b)
        accordionDepth = accordionDepth - 1
        items[#items + 1] = { kind = 'accordion_end', id = acc_id }
        if not ok then print('[LastMenu] accordion "' .. label .. '" error: ' .. tostring(err)) end
    end

    -- ── tab ───────────────────────────────────────────────────────────────────

    function b:tab(label, fn, opts)
        opts = opts or {}
        local tab_id = opts.id or sid(label, 'tab')
        items[#items + 1] = { kind = 'tab_start', id = tab_id, label = label, icon = opts.icon or nil }
        local ok, err = pcall(fn, b)
        items[#items + 1] = { kind = 'tab_end', id = tab_id }
        if not ok then print('[LastMenu] tab "' .. label .. '" error: ' .. tostring(err)) end
    end

    -- ── submenu ───────────────────────────────────────────────────────────────

    function b:submenu(label, subFn, opts)
        opts           = opts or {}
        opts.arrow     = true
        opts.keep_open = true
        opts.cb        = function() UI_Context(subFn) end
        self:button(label, opts)
    end

    -- ── back ──────────────────────────────────────────────────────────────────

    function b:back(label, opts)
        opts  = opts  or {}
        label = label or 'Back'
        local cb_id  = opts.id or sid(label, 'back')
        local userCb = opts.cb
        Bridge.onCallback(cb_id, function()
            local t = type(userCb)
            if t == 'function' or t == 'funcref' then
                local ok, err = pcall(userCb)
                if not ok then print('[LastMenu] back() cb error: ' .. tostring(err)) end
            end
            Stack.pop()
        end, id)
        items[#items + 1] = {
            kind         = 'button', id = cb_id,
            label        = label,   icon = opts.icon or 'arrow-left',
            color        = opts.color or nil, gradient = opts.gradient or false,
            arrow        = false, confirm_hold = false,
            keep_open    = false, visible = true, disabled = false,
        }
    end

    -- ── separator / header ────────────────────────────────────────────────────

    function b:separator()
        items[#items + 1] = { kind = 'separator', id = sid(nil, 'sep') }
    end

    function b:header(str, opts)
        opts = opts or {}
        items[#items + 1] = {
            kind  = 'header', id = opts.id or sid(str, 'hdr'),
            label = str, color = opts.color or nil, align = opts.align or 'left',
        }
    end

    -- ── Build ─────────────────────────────────────────────────────────────────

    LastMenu._safeBuilder('context', fn, b, id)

    if meta.scroll and meta.pageSize ~= 20 then
        print('[LastMenu] Warning: scroll() and page_size() are mutually exclusive — page_size will be ignored.')
    end

    return meta, items, watchers
end

-- ── Registry for context_build handles ───────────────────────────────────────

local _buildCleanup = {}

AddEventHandler('LastMenu:menuClosed', function(closedId)
    local cb = _buildCleanup[closedId]
    if cb then cb(); _buildCleanup[closedId] = nil end
end)

-- ── Shared open logic ─────────────────────────────────────────────────────────

---@param id string
---@param fn fun(b: LM.ContextBuilder)
local function _openContext(id, fn)
    local meta, items, watchers = _buildContext(id, fn)
    if #watchers > 0 then Reactive.attach(id, watchers) end
    Stack.push({ id = id, type = 'context', nav = meta.nav, cancelable = meta.cancelable })
    Bridge.send('open', { menu = 'context', id = id, data = { meta = meta, items = items } })
    if #watchers > 0 then Reactive.startTicking(id) end
end

-- ── Shared update logic ───────────────────────────────────────────────────────

---@param id string
---@param fn fun(b: LM.ContextBuilder)
local function _updateContext(id, fn)
    -- Tear down old reactive state for this menu.
    Reactive.stopTicking(id)
    Bridge.removeCallbacks(id)

    local meta, items, watchers = _buildContext(id, fn)
    if #watchers > 0 then
        Reactive.attach(id, watchers)
        Reactive.startTicking(id)
    end
    -- Sending 'open' with an existing ID replaces the NUI entry (App.svelte deduplicates by id).
    Bridge.send('open', { menu = 'context', id = id, data = { meta = meta, items = items } })
end

-- ── Public functions ──────────────────────────────────────────────────────────

--- Opens a context menu immediately.
---@param fn fun(menu: LM.ContextBuilder)
function UI_Context(fn)
    _openContext(GenerateMenuId(), fn)
end

--- Rebuilds the currently visible context menu without closing and reopening it.
--- Only works when the top of the stack is a context menu.
--- Useful for refreshing item lists that aren't covered by watchers.
---@param fn fun(menu: LM.ContextBuilder)
function UI_Context_Update(fn)
    local top = Stack.peek()
    if not top or top.type ~= 'context' then
        if Config.debug then
            print('[LastMenu] context_update: top of stack is not a context menu — ignored.')
        end
        return
    end
    _updateContext(top.id, fn)
end

--- Returns a reusable handle: { open(), close(), update(fn?) }.
---@param fn fun(menu: LM.ContextBuilder)
---@return LM.ContextHandle
function UI_Context_Build(fn)
    local _activeId = nil

    return {
        open = function()
            if _activeId then return end
            local id = GenerateMenuId()
            _activeId = id
            _buildCleanup[id] = function() _activeId = nil end
            _openContext(id, fn)
        end,

        close = function()
            if not _activeId then return end
            _buildCleanup[_activeId] = nil
            _activeId = nil
            Stack.pop()
        end,

        -- Rebuilds the menu content while it is open.
        -- Pass newFn to use a different builder; omit to re-run the original fn.
        ---@param newFn? fun(menu: LM.ContextBuilder)
        update = function(newFn)
            if not _activeId then
                if Config.debug then
                    print('[LastMenu] handle.update(): menu is not open — ignored.')
                end
                return
            end
            _updateContext(_activeId, newFn or fn)
        end,
    }
end