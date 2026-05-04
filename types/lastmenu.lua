---@meta LastMenu
-- LastMenu — LuaLS type definitions
-- Place this file in a `types/` directory and reference it in .luarc.json
-- to get full autocompletion in VS Code / any LuaLS-powered editor.

-- ── Shared option types ────────────────────────────────────────────────────

---@class LM.PreviewStat
---@field label  string
---@field value  number
---@field max    number
---@field color? string   Hex colour override

---@class LM.Preview
---@field image? string         https:// or nui:// URL
---@field title? string
---@field desc?  string
---@field stats? LM.PreviewStat[]

-- ── Context menu builder ───────────────────────────────────────────────────

---@class LM.ContextBuilder
local ContextBuilder = {}

--- Title displayed in the header.
---@param str string
function ContextBuilder:title(str) end

--- Image URL shown above the title (https:// or nui://).
---@param url string
function ContextBuilder:banner(url) end

--- Subtitle shown below the title.
---@param txt string
function ContextBuilder:description(txt) end

--- Force navigation mode. Overrides user's global setting.
---@param mode 'mouse'|'keyboard'|'both'
function ContextBuilder:nav(mode) end

--- Open animation.
---@param anim 'slideLeft'|'slideRight'|'fade'|'scale'|'none'
function ContextBuilder:animation(anim) end

--- Force-show the search bar regardless of item count.
--- search() / search(true) = force visible ; search(false) = force hidden.
---@param v? boolean  Default true
function ContextBuilder:search(v) end

--- Items per page (pagination auto-activates above this threshold).
---@param n integer
function ContextBuilder:page_size(n) end

--- Disable pagination — render all items with native scroll.
--- Mutually exclusive with page_size().
function ContextBuilder:scroll() end

--- Whether Escape / B can close the menu.
---@param v boolean
function ContextBuilder:cancelable(v) end

---@class LM.ButtonOpts
---@field icon?         string         Lucide icon name (e.g. "wrench")
---@field color?        string|fun():string   Hex accent colour or reactive function
---@field gradient?     boolean        Show a coloured gradient background
---@field badge?        string|fun():string   Badge text top-right (e.g. "NEW", "500€")
---@field hint?         string         Dim right-side text
---@field hotkey?       string         Keyboard shortcut label shown as kbd
---@field arrow?        boolean        Show › (indicates a sub-menu)
---@field confirm_hold? boolean|integer  true = 1500ms hold, number = custom ms
---@field cooldown?     integer        ms before the button can be clicked again
---@field persist_key?  string         Stable cooldown key for localStorage persistence
---@field keep_open?    boolean        Don't close the menu on click
---@field preview?      LM.Preview     Hover preview panel
---@field visible?      boolean|fun():boolean
---@field disabled?     boolean|fun():boolean
---@field refresh?      integer        Poll interval for reactive fields (ms)
---@field timeout?      integer        Auto-disable after N ms from menu open
---@field cb?           fun()          Called when clicked

--- Add a button item.
---@param label string|fun():string   Static label or reactive function
---@param opts  LM.ButtonOpts
function ContextBuilder:button(label, opts) end

---@class LM.SliderOpts
---@field icon?    string
---@field min?     number   Default 0
---@field max?     number   Default 100
---@field step?    number   Default 1
---@field default? number
---@field suffix?  string
---@field cb?      fun(value: number)

--- Add a horizontal slider.
---@param label string
---@param opts  LM.SliderOpts
function ContextBuilder:slider(label, opts) end

---@class LM.StepperOpts
---@field icon?    string
---@field min?     number   Default 0
---@field max?     number   Default 99
---@field step?    number   Default 1
---@field default? number
---@field suffix?  string
---@field cb?      fun(value: number)

--- Add a − / value / + stepper.
---@param label string
---@param opts  LM.StepperOpts
function ContextBuilder:stepper(label, opts) end

---@class LM.CheckboxOpts
---@field icon?    string
---@field default? boolean
---@field cb?      fun(checked: boolean)

--- Add a square checkbox.
---@param label string
---@param opts  LM.CheckboxOpts
function ContextBuilder:checkbox(label, opts) end

---@class LM.ToggleOpts
---@field icon?    string
---@field default? boolean
---@field cb?      fun(enabled: boolean)

--- Add an animated ON/OFF pill switch.
---@param label string
---@param opts  LM.ToggleOpts
function ContextBuilder:toggle(label, opts) end

---@class LM.ListOpts
---@field icon?         string
---@field items?        string[]
---@field default?      integer    1-based index (default 1)
---@field confirm_hold? boolean|integer
---@field cb?           fun(index: integer, value: string)

--- Add a ‹ value › carousel.
---@param label string
---@param opts  LM.ListOpts
function ContextBuilder:list(label, opts) end

---@class LM.StatOpts
---@field value?   number|fun():number   Current value
---@field max?     number|fun():number   Maximum value
---@field icon?    string
---@field suffix?  string
---@field color?   string|fun():string   Hex color (nil = accent color; "auto" = green/orange/red by percentage)
---@field refresh? integer

--- Add a read-only animated progress bar.
--- New signature: b:stat(label, opts) — opts.value / opts.max
--- Legacy: b:stat(label, value, max, opts) still accepted.
---@param label string
---@param opts  LM.StatOpts
function ContextBuilder:stat(label, opts) end

---@class LM.InputInlineOpts
---@field icon?        string
---@field type?        'text'|'number'
---@field placeholder? string
---@field default?     string|number
---@field maxlen?      integer
---@field min?         number
---@field max?         number
---@field cb?          fun(value: string|number)

--- Add an inline text/number input field.
---@param label string
---@param opts  LM.InputInlineOpts
function ContextBuilder:input_inline(label, opts) end

---@class LM.ColorPickerOpts
---@field icon?    string
---@field default? string    Hex colour (default "#e94560")
---@field presets? string[]  Custom preset palette
---@field cb?      fun(hex: string)

--- Add a color swatch with preset grid and hex input.
---@param label string
---@param opts  LM.ColorPickerOpts
function ContextBuilder:color_picker(label, opts) end

---@class LM.DatePickerOpts
---@field icon?    string
---@field default? string   "YYYY-MM-DD" (default: today)
---@field min?     string   "YYYY-MM-DD"
---@field max?     string   "YYYY-MM-DD"
---@field format?  'dmy'|'mdy'|'ymd'
---@field cb?      fun(date: string)   ISO "YYYY-MM-DD"

--- Add a day/month/year date input.
---@param label string
---@param opts  LM.DatePickerOpts
function ContextBuilder:date_picker(label, opts) end

---@class LM.AccordionOpts
---@field icon? string
---@field open? boolean   Open by default (default false)

--- Add a collapsible section.
---@param label string
---@param fn    fun(b: LM.ContextBuilder)
---@param opts? LM.AccordionOpts
function ContextBuilder:accordion(label, fn, opts) end

---@class LM.TabOpts
---@field icon? string

--- Add a named tab. A tab bar appears when at least one tab is defined.
---@param label string
---@param fn    fun(b: LM.ContextBuilder)
---@param opts? LM.TabOpts
function ContextBuilder:tab(label, fn, opts) end

--- Shorthand: open a sub-menu from this menu (keep_open + arrow implicit).
---@param label  string
---@param subFn  fun(b: LM.ContextBuilder)
---@param opts?  LM.ButtonOpts
function ContextBuilder:submenu(label, subFn, opts) end

---@class LM.BackOpts
---@field icon?     string
---@field color?    string
---@field gradient? boolean
---@field cb?       fun()   Executed before pop (optional cleanup)

--- Add a back button that pops the current menu. `cb` runs before pop.
---@param label? string   Default "Back"
---@param opts?  LM.BackOpts
function ContextBuilder:back(label, opts) end

--- Add a thin horizontal separator.
function ContextBuilder:separator() end

---@class LM.HeaderOpts
---@field color? string   Hex colour for the label text
---@field align? 'left'|'center'|'right'

--- Add an all-caps section label.
---@param str   string
---@param opts? LM.HeaderOpts
function ContextBuilder:header(str, opts) end

-- ── Context menu handles ───────────────────────────────────────────────────

---@class LM.ContextHandle
---@field open   fun()
---@field close  fun()
---@field update fun(fn?: fun(b: LM.ContextBuilder))  Rebuild the open menu without close/reopen. fn defaults to the original builder.

-- ── Alert builder ─────────────────────────────────────────────────────────

---@class LM.AlertBuilder
local AlertBuilder = {}
---@param str string
function AlertBuilder:title(str) end
---@param str string
function AlertBuilder:message(str) end
---@param str 'info'|'success'|'warning'|'error'|'confirm'
function AlertBuilder:type(str) end
---@param label string
---@param cb    fun()
function AlertBuilder:confirm(label, cb) end
---@param label string
---@param cb    fun()
function AlertBuilder:cancel(label, cb) end

---@class LM.AlertHandle
---@field open  fun()
---@field close fun()

-- ── Notify builder ────────────────────────────────────────────────────────

---@class LM.NotifyBuilder
local NotifyBuilder = {}
---@param str string
function NotifyBuilder:message(str) end
---@param str string  Optional title displayed above the message
function NotifyBuilder:title(str) end
---@param str 'info'|'success'|'warning'|'error'
function NotifyBuilder:type(str) end
---@param ms integer
function NotifyBuilder:duration(ms) end
---@param str string  Lucide icon name
function NotifyBuilder:icon(str) end
--- Make the toast persistent (no auto-dismiss, no timer bar). Equivalent to duration(0).
function NotifyBuilder:persistent() end
--- Group key for deduplication: replaces any existing toast with the same group.
---@param str string
function NotifyBuilder:group(str) end
--- Called when the toast is closed manually (× button). NOT called on auto-expiry.
---@param cb fun()
function NotifyBuilder:on_dismiss(cb) end

-- ── Progress builder ──────────────────────────────────────────────────────

---@class LM.ProgressBuilder
local ProgressBuilder = {}
---@param str string
function ProgressBuilder:label(str) end
---@param ms integer
function ProgressBuilder:duration(ms) end
---@param allow boolean
function ProgressBuilder:cancel(allow) end
---@param str string
function ProgressBuilder:icon(str) end
---@param cb fun(pct: number)  Called every 100ms with 0-100
function ProgressBuilder:cb_tick(cb) end
---@param opts { dict: string, clip: string, flag?: integer }
function ProgressBuilder:anim(opts) end
---@param opts { model: string, bone?: integer, offset?: vector3, rotation?: vector3 }
function ProgressBuilder:prop(opts) end
---@param cb fun()
function ProgressBuilder:onComplete(cb) end
---@param cb fun()
function ProgressBuilder:onCancel(cb) end

---@class LM.ProgressHandle
---@field open  fun()
---@field close fun()

-- ── Radial menu builder ────────────────────────────────────────────────────

---@class LM.RadialBuilder
local RadialBuilder = {}
---@param str string
function RadialBuilder:center_label(str) end
---@class LM.RadialButtonOpts
---@field icon?     string
---@field visible?  boolean|fun():boolean
---@field disabled? boolean|fun():boolean
---@field keep_open? boolean
---@field refresh?  integer
---@field cb?       fun()
---@field submenu?  fun(b: LM.RadialBuilder)
---@param label string
---@param opts  LM.RadialButtonOpts
function RadialBuilder:button(label, opts) end

---@class LM.RadialHandle
---@field open  fun()
---@field close fun()

-- ── Input form builder ─────────────────────────────────────────────────────

---@class LM.InputBuilder
local InputBuilder = {}
---@param str string
function InputBuilder:title(str) end
---@class LM.InputFieldOpts
---@field type?          'text'|'number'
---@field placeholder?   string
---@field default?       string|number
---@field maxlen?        integer
---@field min?           number
---@field max?           number
---@field pattern?       string   Regex the value must match (JavaScript syntax)
---@field pattern_error? string   Custom error message shown when the pattern fails
---@field required?      boolean
---@param label string
---@param opts  LM.InputFieldOpts
function InputBuilder:field(label, opts) end
---@param label string
---@param cb    fun(values: table<integer, string|number>)
function InputBuilder:confirm(label, cb) end
---@param label string
---@param cb    fun()
function InputBuilder:cancel(label, cb) end

---@class LM.InputHandle
---@field open  fun()
---@field close fun()

-- ── Target system ──────────────────────────────────────────────────────────

---@class LM.TargetAction
---@field label     string
---@field icon?     string
---@field condition? fun(entity: integer): boolean
---@field visible?  fun(entity: integer): boolean
---@field disabled? boolean|fun(entity: integer): boolean
---@field cb?       fun(entity: integer)

---@class LM.TargetOpts
---@field label?    string
---@field icon?     string
---@field banner?   string
---@field distance? number
---@field on_enter? fun()
---@field on_leave? fun()
---@field actions?  LM.TargetAction[]

---@class LM.TargetBoxOpts : LM.TargetOpts
---@field width?   number   Full width on local X axis (default 2.0)
---@field length?  number   Full length on local Y axis (default 2.0)
---@field heading? number   Rotation degrees clockwise (default 0.0)

---@class LM.TargetPolyOpts : LM.TargetOpts
---@field minZ? number
---@field maxZ? number

-- ── Public API (exports) ───────────────────────────────────────────────────

---@class LastMenuExports
local LastMenuExports = {}

--- Pop the top menu off the stack (equivalent to Escape).
function LastMenuExports:lastmenu_back() end

--- Open a one-shot context menu.
---@param fn fun(menu: LM.ContextBuilder)
function LastMenuExports:context(fn) end

--- Build a reusable context menu handle.
---@param fn fun(menu: LM.ContextBuilder)
---@return LM.ContextHandle
function LastMenuExports:context_build(fn) end

--- Rebuild the currently open context menu in-place without close/reopen.
--- No-op if the stack top is not a context menu.
---@param fn fun(b: LM.ContextBuilder)
function LastMenuExports:context_update(fn) end

--- Open a one-shot alert modal.
---@param fn fun(b: LM.AlertBuilder)
function LastMenuExports:alert(fn) end

--- Build a reusable alert modal handle.
---@param fn fun(b: LM.AlertBuilder)
---@return LM.AlertHandle
function LastMenuExports:alert_build(fn) end

--- Open an alert modal and block the coroutine until confirmed/cancelled.
--- Returns true if confirmed, false if cancelled.
---@param fn fun(b: LM.AlertBuilder)
---@return boolean
function LastMenuExports:alert_async(fn) end

--- Send a toast notification (non-blocking, outside the menu stack).
---@param fn fun(b: LM.NotifyBuilder)
function LastMenuExports:notify(fn) end

--- Start a one-shot progress bar.
---@param fn fun(b: LM.ProgressBuilder)
function LastMenuExports:progress(fn) end

--- Build a reusable progress bar handle.
---@param fn fun(b: LM.ProgressBuilder)
---@return LM.ProgressHandle
function LastMenuExports:progress_build(fn) end

--- Open a one-shot radial menu.
---@param fn fun(b: LM.RadialBuilder)
function LastMenuExports:radial(fn) end

--- Build a reusable radial menu handle.
---@param fn fun(b: LM.RadialBuilder)
---@return LM.RadialHandle
function LastMenuExports:radial_build(fn) end

--- Open a one-shot input form.
---@param fn fun(b: LM.InputBuilder)
function LastMenuExports:input(fn) end

--- Build a reusable input form handle.
---@param fn fun(b: LM.InputBuilder)
---@return LM.InputHandle
function LastMenuExports:input_build(fn) end

--- Open an input form and block the coroutine until submitted/cancelled.
--- Returns a table of field values, or nil if cancelled.
---@param fn fun(b: LM.InputBuilder)
---@return table<integer, string|number>|nil
function LastMenuExports:input_async(fn) end

--- Register a target on a specific entity handle.
---@param entity integer
---@param opts   LM.TargetOpts
---@return string  Registration ID
function LastMenuExports:target_add_entity(entity, opts) end

--- Register a target on all entities of a given model.
---@param model  string|integer  Model name or hash (nil = all peds)
---@param opts   LM.TargetOpts
---@return string
function LastMenuExports:target_add_model(model, opts) end

--- Register a target on a sphere zone.
---@param coords vector3
---@param radius number
---@param opts   LM.TargetOpts
---@return string
function LastMenuExports:target_add_sphere(coords, radius, opts) end

--- Register a target on an oriented rectangle zone.
---@param coords vector3
---@param opts   LM.TargetBoxOpts
---@return string
function LastMenuExports:target_add_box(coords, opts) end

--- Register a target on a 2D polygon zone.
---@param points vector2[]|vector3[]
---@param opts   LM.TargetPolyOpts
---@return string
function LastMenuExports:target_add_poly(points, opts) end

--- Update an existing target registration (partial update).
---@param id   string
---@param opts LM.TargetOpts
function LastMenuExports:target_update(id, opts) end

--- Remove a target registration by ID.
---@param id string
function LastMenuExports:target_remove(id) end

--- Remove all target registrations.
function LastMenuExports:target_clear() end

--- Open the user settings panel (Shift+F12).
function LastMenuExports:settings_open() end

--- Close the user settings panel.
function LastMenuExports:settings_close() end

--- Print a watcher health snapshot to the server console.
--- Shows all active menus, their watchers, poll intervals, error counts, and Safe Mode status.
function LastMenuExports:debug_stats() end
