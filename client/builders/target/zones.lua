-- target/zones.lua
-- Registration API: addEntity, addModel, addSphere, addBox, addPoly, update, remove, clear.
-- Exposes LastMenu.Target for use by raycast.lua and ui.lua.

---@class TargetModule
---@field _registrations table<string, table>   id → registration data
---@field _counter       integer
local Target = {}

---@class LM.TargetOpts
---@field label    string?
---@field icon     string?
---@field distance number?
---@field banner   string?
---@field actions  table[]?
---@field on_enter fun(entity: integer)?
---@field on_leave fun(entity: integer)?

---@class LM.TargetBoxOpts: LM.TargetOpts
---@field width   number?
---@field length  number?
---@field heading number?

---@class LM.TargetPolyOpts: LM.TargetOpts
---@field minZ number?
---@field maxZ number?
Target._registrations = {}
Target._counter       = 0

---@return string
local function newId()
    Target._counter = Target._counter + 1
    return 'tgt_' .. Target._counter
end

-- ── Builder helpers (defined first so add* methods can reference them) ──────

---@param actions    table[]
---@param kind       string
---@param label      string
---@param opts       table?
---@param groupLabel string?
---@param groupIcon  string?
---@param groupOpen  boolean?
local function _pushAction(actions, kind, label, opts, groupLabel, groupIcon, groupOpen)
    opts = opts or {}
    table.insert(actions, {
        kind         = kind,
        label        = label,
        icon         = opts.icon,
        color        = opts.color,
        gradient     = opts.gradient,
        confirm_hold = opts.confirm_hold,
        cooldown     = opts.cooldown,
        visible      = opts.condition or opts.visible,
        disabled     = opts.disabled,
        badge        = opts.badge,
        arrow        = opts.arrow,
        default      = opts.default,
        min          = opts.min,
        max          = opts.max,
        step         = opts.step,
        suffix       = opts.suffix,
        cb           = opts.cb,
        submenu      = opts.submenu,
        group        = groupLabel,
        group_icon   = groupIcon,
        group_open   = groupOpen,
    })
end

---@param  groupLabel string
---@param  groupOpts  table
---@param  actions    table[]
---@return table
local function _makeGroupBuilder(groupLabel, groupOpts, actions)
    local gIcon, gOpen = groupOpts.icon, groupOpts.open
    local g = {}
    g.button   = function(_, label, opts) _pushAction(actions, 'button',   label, opts, groupLabel, gIcon, gOpen) end
    g.toggle   = function(_, label, opts) _pushAction(actions, 'toggle',   label, opts, groupLabel, gIcon, gOpen) end
    g.checkbox = function(_, label, opts) _pushAction(actions, 'checkbox', label, opts, groupLabel, gIcon, gOpen) end
    g.slider   = function(_, label, opts) _pushAction(actions, 'slider',   label, opts, groupLabel, gIcon, gOpen) end
    return g
end

-- buildTarget: converts a chaining function into the flat opts table.
-- Usage:
--   LM:target_add_model(nil, function(t)
--       t:label("Vehicle")
--       t:distance(4.0)
--       t:button("Repair",   { icon="wrench", gradient=true, cooldown=60000, cb=fn })
--       t:separator()
--       t:group("Services",  { icon="tool" }, function(g)
--           g:button("Clean", { cb=fn })
--       end)
--       t:toggle("Lock",     { icon="lock",  default=false, cb=fn })
--       t:slider("Fuel",     { min=0, max=100, step=5, suffix="%", cb=fn })
--       t:checkbox("Invoice", { default=false, cb=fn })
--       t:submenu("Advanced", { icon="settings-2", cb=fn })
--   end)

---@param  fn fun(t: table)
---@return LM.TargetOpts
local function buildTarget(fn)
    local out = { label = 'Interact', icon = 'eye', distance = 3.0, actions = {} }
    local t   = {}

    t.label    = function(_, v) out.label    = v end
    t.icon     = function(_, v) out.icon     = v end
    t.distance = function(_, v) out.distance = v end
    t.banner   = function(_, v) out.banner   = v end
    t.on_enter = function(_, v) out.on_enter = v end
    t.on_leave = function(_, v) out.on_leave = v end

    t.button   = function(_, label, opts) _pushAction(out.actions, 'button',   label, opts) end
    t.toggle   = function(_, label, opts) _pushAction(out.actions, 'toggle',   label, opts) end
    t.checkbox = function(_, label, opts) _pushAction(out.actions, 'checkbox', label, opts) end
    t.slider   = function(_, label, opts) _pushAction(out.actions, 'slider',   label, opts) end

    t.separator = function(_)
        table.insert(out.actions, { kind = 'separator' })
    end

    t.submenu = function(_, label, opts)
        opts = opts or {}
        _pushAction(out.actions, 'button', label, { icon = opts.icon, arrow = true, submenu = opts.cb })
    end

    t.group = function(_, label, opts, groupFn)
        if type(opts) == 'function' then groupFn = opts; opts = {} end
        groupFn(_makeGroupBuilder(label, opts, out.actions))
    end

    LastMenu._safeBuilder('target', fn, t)
    return out
end

-- Resolves opts: if a function is passed, run through builder; otherwise return as-is.
-- FiveM cross-resource funcrefs can have type "userdata", "function", or even "table" depending
-- on the runtime build. If it looks like a table but indexing fails, treat it as a builder fn.
---@param  opts any
---@return LM.TargetOpts
local function _resolve(opts)
    if type(opts) ~= 'table' then return buildTarget(opts) end
    -- Detect funcrefs that masquerade as 'table' but cannot be indexed.
    local ok = pcall(function() return opts.label end)
    if not ok then return buildTarget(opts) end
    return opts
end

-- ── Registration API ───────────────────────────────────────────────────────

--- Registers a target on a specific entity handle.
---@param entity integer  Entity handle
---@param opts   LM.TargetOpts
---@return string  Registration ID
function Target.addEntity(entity, opts)
    opts = _resolve(opts) or {}
    local id = newId()
    Target._registrations[id] = {
        type      = 'entity',
        entity    = entity,
        label     = opts.label    or 'Interact',
        icon      = opts.icon     or 'eye',
        distance  = opts.distance or 3.0,
        banner    = opts.banner   or nil,
        actions   = opts.actions  or {},
        on_enter  = opts.on_enter or nil,
        on_leave  = opts.on_leave or nil,
        _resource = GetInvokingResource(),
    }
    return id
end

--- Registers a target on all peds matching a model hash.
---@param model string|integer  Model name or hash (nil = all peds)
---@param opts  LM.TargetOpts
---@return string
function Target.addModel(model, opts)
    opts = _resolve(opts) or {}
    local id = newId()
    local modelHash = type(model) == 'string' and GetHashKey(model) or model
    Target._registrations[id] = {
        type      = 'model',
        model     = modelHash,
        label     = opts.label    or 'Interact',
        icon      = opts.icon     or 'eye',
        distance  = opts.distance or 3.0,
        actions   = opts.actions  or {},
        banner    = opts.banner   or nil,
        on_enter  = opts.on_enter or nil,
        on_leave  = opts.on_leave or nil,
        _resource = GetInvokingResource(),
    }

    -- Hints the streaming system early so GetEntityModel() doesn't throw a native
    -- exception on an entity that isn't fully loaded yet.
    if modelHash and modelHash ~= 0 then
        Citizen.CreateThread(function()
            if not HasModelLoaded(modelHash) then
                RequestModel(modelHash)
                Citizen.Wait(0)
                SetModelAsNoLongerNeeded(modelHash)
            end
        end)
    end

    return id
end

--- Registers a target on a sphere zone.
---@param coords vector3
---@param radius number
---@param opts   LM.TargetOpts
---@return string
function Target.addSphere(coords, radius, opts)
    opts = _resolve(opts) or {}
    local id = newId()
    Target._registrations[id] = {
        type      = 'sphere',
        coords    = coords,
        radius    = radius or 2.0,
        label     = opts.label    or 'Interact',
        icon      = opts.icon     or 'map-pin',
        banner    = opts.banner   or nil,
        actions   = opts.actions  or {},
        on_enter  = opts.on_enter or nil,
        on_leave  = opts.on_leave or nil,
        _resource = GetInvokingResource(),
    }
    return id
end

--- Registers a target on an oriented rectangular zone.
--- opts.width / opts.length are full extents (the OBB test divides them by 2 internally); opts.heading is clockwise degrees (GTA convention).
---@param coords vector3
---@param opts   LM.TargetBoxOpts
---@return string
function Target.addBox(coords, opts)
    opts = _resolve(opts) or {}
    local id = newId()
    Target._registrations[id] = {
        type      = 'box',
        coords    = coords,
        width     = opts.width    or 2.0,
        length    = opts.length   or 2.0,
        heading   = opts.heading  or 0.0,
        label     = opts.label    or 'Interact',
        icon      = opts.icon     or 'box',
        banner    = opts.banner   or nil,
        actions   = opts.actions  or {},
        on_enter  = opts.on_enter or nil,
        on_leave  = opts.on_leave or nil,
        _resource = GetInvokingResource(),
    }
    return id
end

--- Registers a target on a 2D polygon zone.
---@param points vector2[]|vector3[]
---@param opts   LM.TargetPolyOpts
---@return string
function Target.addPoly(points, opts)
    opts = _resolve(opts) or {}
    local id = newId()
    Target._registrations[id] = {
        type      = 'poly',
        points    = points,
        minZ      = opts.minZ    or -math.huge,
        maxZ      = opts.maxZ    or  math.huge,
        label     = opts.label    or 'Interact',
        icon      = opts.icon     or 'map-pin',
        banner    = opts.banner   or nil,
        actions   = opts.actions  or {},
        on_enter  = opts.on_enter or nil,
        on_leave  = opts.on_leave or nil,
        _resource = GetInvokingResource(),
    }
    return id
end

-- Remove registrations belonging to a resource when it stops.
AddEventHandler('onResourceStop', function(resource)
    local removed = false
    for id, reg in pairs(Target._registrations) do
        if reg._resource == resource then
            Target._registrations[id] = nil
            removed = true
        end
    end
    -- Signal polling thread to re-evaluate on the next tick.
    if removed and LastMenu._targetUi then
        LastMenu._targetUi.resetMatchKey()
    end
end)

--- Partially updates an existing registration (only supplied fields are overwritten).
---@param id   string
---@param opts table
function Target.update(id, opts)
    local reg = Target._registrations[id]
    if not reg then return end
    opts = opts or {}
    for k, v in pairs(opts) do reg[k] = v end
    if LastMenu._targetUi then LastMenu._targetUi.resetMatchKey() end
end

--- Removes a registration by ID.
---@param id string
function Target.remove(id)
    Target._registrations[id] = nil
end

--- Removes all registrations.
function Target.clear()
    Target._registrations = {}
end

rawset(LastMenu, 'Target', Target)

-- ── Export wrappers ────────────────────────────────────────────────────────

---@param  entity integer
---@param  opts   LM.TargetOpts|fun(t: table)
---@return string
function UI_Target_AddEntity(entity, opts) return Target.addEntity(entity, opts) end

---@param  model string|integer|nil
---@param  opts  LM.TargetOpts|fun(t: table)
---@return string
function UI_Target_AddModel(model, opts)   return Target.addModel(model,  opts)  end

---@param  coords vector3
---@param  radius number
---@param  opts   LM.TargetOpts|fun(t: table)
---@return string
function UI_Target_AddSphere(coords, radius, opts) return Target.addSphere(coords, radius, opts) end

---@param  coords vector3
---@param  opts   LM.TargetBoxOpts|fun(t: table)
---@return string
function UI_Target_AddBox(coords, opts)    return Target.addBox(coords,   opts)  end

---@param  points vector2[]|vector3[]
---@param  opts   LM.TargetPolyOpts|fun(t: table)
---@return string
function UI_Target_AddPoly(points, opts)   return Target.addPoly(points,  opts)  end

---@param id   string
---@param opts table
function UI_Target_Update(id, opts)        Target.update(id, opts)               end

---@param id string
function UI_Target_Remove(id)              Target.remove(id)                     end

function UI_Target_Clear()                 Target.clear()                        end
