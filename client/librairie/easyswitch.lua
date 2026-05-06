
local _M_matchigo, _M_dispatcher, _M_eventManager, _M_middlewareManager, _M_switch, _M_registry

_M_matchigo = (function()

    local _M_compat, _M_bigint, _M_map, _M_set, _M_p, _M_compile, _M_dsl_ast, _M_dsl_lex, _M_dsl_parse, _M_dsl_eval, _M_dsl_comp, _M_parsePat

    do
        local M = {}

        M.mathType = math.type or function(n)
            if type(n) ~= "number" then return nil end
            if n ~= n or n == math.huge or n == -math.huge then return "float" end
            return (math.floor(n) == n) and "integer" or "float"
        end

        local nativeTableType = table.type

        local function pureIsArray(t)
            local n = #t
            if n == 0 then return next(t) == nil end
            local count = 0
            for k in pairs(t) do
                count = count + 1
                if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > n then
                    return false
                end
            end
            return count == n
        end

        M.isArray = nativeTableType
            and function(t)
                if type(t) ~= "table" then return false end
                local kind = nativeTableType(t)
                if kind == "hash" or kind == "mixed" then return false end
                return pureIsArray(t)
            end
            or function(t)
                if type(t) ~= "table" then return false end
                return pureIsArray(t)
            end
        _M_compat = M
    end

    do

        local M = {}

        local mt = {}

        local function isBigInt(v)
            return type(v) == "table" and getmetatable(v) == mt
        end
        M.isBigInt = isBigInt

        local function normalize(sign, digits)
            local i, n = 1, #digits
            while i < n and digits:sub(i, i) == "0" do
                i = i + 1
            end
            digits = digits:sub(i)
            if digits == "0" then sign = 1 end
            return setmetatable({ sign = sign, digits = digits }, mt)
        end

        function M.new(v)

            if isBigInt(v) then return v end
            if type(v) == "number" then
                if v ~= v or v == math.huge or v == -math.huge then
                    error("BigInt: cannot construct from non-finite number", 2)
                end
                if v % 1 ~= 0 then
                    error("BigInt: cannot construct from non-integer number " .. tostring(v), 2)
                end
                local s = string.format("%.0f", v)
                local sign = 1
                if s:sub(1, 1) == "-" then
                    sign = -1
                    s = s:sub(2)
                end
                return normalize(sign, s)
            end
            if type(v) == "string" then
                local sign = 1
                local s = v
                local first = s:sub(1, 1)
                if first == "-" then sign = -1; s = s:sub(2)
                elseif first == "+" then s = s:sub(2) end
                if s == "" or not s:match("^%d+$") then
                    error("BigInt: invalid string '" .. v .. "'", 2)
                end
                return normalize(sign, s)
            end
            error("BigInt: cannot construct from " .. type(v), 2)
        end

        local function compareMagnitude(a, b)
            local la, lb = #a, #b
            if la < lb then return -1
            elseif la > lb then return 1
            elseif a < b then return -1
            elseif a > b then return 1
            else return 0 end
        end

        local function compare(a, b)
            if a.sign ~= b.sign then
                return a.sign < b.sign and -1 or 1
            end
            local m = compareMagnitude(a.digits, b.digits)
            if a.sign == -1 then m = -m end
            return m
        end
        M.compare = compare

        mt.__eq = function(a, b)
            return a.sign == b.sign and a.digits == b.digits
        end

        mt.__lt = function(a, b)
            return compare(a, b) < 0
        end

        mt.__le = function(a, b)
            return compare(a, b) <= 0
        end

        mt.__unm = function(a)
            if a.digits == "0" then return a end
            return setmetatable({ sign = -a.sign, digits = a.digits }, mt)
        end

        mt.__tostring = function(a)
            return (a.sign == -1 and "-" or "") .. a.digits
        end

        mt.__index = {
            isPositive = function(self) return self.sign == 1 and self.digits ~= "0" end,
            isNegative = function(self) return self.sign == -1 end,
            isZero     = function(self) return self.digits == "0" end,
        }

        M.ZERO = normalize(1, "0")
        M.ONE  = normalize(1, "1")
        _M_bigint = M
    end

    do

        local M = {}

        local mt = {}

        local NIL_KEY = {}
        local NAN_KEY = {}

        local function normalizeKey(k)
            if k == nil then return NIL_KEY end
            if k ~= k then return NAN_KEY end
            return k
        end

        local function denormalizeKey(k)
            if k == NIL_KEY then return nil end
            if k == NAN_KEY then return 0 / 0 end
            return k
        end

        local function isMap(v)
            return type(v) == "table" and getmetatable(v) == mt
        end
        M.isMap = isMap

        local methods = {}
        mt.__index = methods

        function M.new(entries)
            local self = setmetatable({
                _byKey = {},
                _head = nil,
                _tail = nil,
                size = 0,
            }, mt)
            if entries ~= nil then
                local n = #entries
                for i = 1, n do
                    local e = entries[i]
                    self:set(e[1], e[2])
                end
            end
            return self
        end

        function methods:get(key)
            local entry = self._byKey[normalizeKey(key)]
            return entry and entry.value or nil
        end

        function methods:has(key)
            return self._byKey[normalizeKey(key)] ~= nil
        end

        function methods:set(key, value)
            local nk = normalizeKey(key)
            local entry = self._byKey[nk]
            if entry then
                entry.value = value
                return self
            end
            entry = { key = nk, value = value, prev = self._tail, next = nil }
            self._byKey[nk] = entry
            if self._tail then
                self._tail.next = entry
            else
                self._head = entry
            end
            self._tail = entry
            self.size = self.size + 1
            return self
        end

        function methods:delete(key)
            local nk = normalizeKey(key)
            local entry = self._byKey[nk]
            if not entry then return false end
            self._byKey[nk] = nil
            if entry.prev then entry.prev.next = entry.next else self._head = entry.next end
            if entry.next then entry.next.prev = entry.prev else self._tail = entry.prev end
            self.size = self.size - 1
            return true
        end

        function methods:clear()
            self._byKey = {}
            self._head = nil
            self._tail = nil
            self.size = 0
        end

        function methods:pairs()
            local cur = self._head
            return function()
                if not cur then return nil end
                local e = cur
                cur = cur.next
                return denormalizeKey(e.key), e.value
            end
        end

        function methods:keys()
            local cur = self._head
            return function()
                if not cur then return nil end
                local e = cur
                cur = cur.next
                return denormalizeKey(e.key)
            end
        end

        function methods:values()
            local cur = self._head
            return function()
                if not cur then return nil end
                local e = cur
                cur = cur.next
                return e.value
            end
        end

        function methods:forEach(fn)
            local cur = self._head
            while cur do
                fn(cur.value, denormalizeKey(cur.key), self)
                cur = cur.next
            end
        end
        _M_map = M
    end

    do

        local M = {}

        local mt = {}

        local NIL_ITEM = {}
        local NAN_ITEM = {}

        local function normalizeItem(v)
            if v == nil then return NIL_ITEM end
            if v ~= v then return NAN_ITEM end
            return v
        end

        local function denormalizeItem(v)
            if v == NIL_ITEM then return nil end
            if v == NAN_ITEM then return 0 / 0 end
            return v
        end

        local function isSet(v)
            return type(v) == "table" and getmetatable(v) == mt
        end
        M.isSet = isSet

        local methods = {}
        mt.__index = methods

        function M.new(items)
            local self = setmetatable({
                _byItem = {},
                _head = nil,
                _tail = nil,
                size = 0,
            }, mt)
            if items ~= nil then
                local n = #items
                for i = 1, n do
                    self:add(items[i])
                end
            end
            return self
        end

        function methods:has(item)
            return self._byItem[normalizeItem(item)] ~= nil
        end

        function methods:add(item)
            local ni = normalizeItem(item)
            if self._byItem[ni] then return self end
            local entry = { item = ni, prev = self._tail, next = nil }
            self._byItem[ni] = entry
            if self._tail then
                self._tail.next = entry
            else
                self._head = entry
            end
            self._tail = entry
            self.size = self.size + 1
            return self
        end

        function methods:delete(item)
            local ni = normalizeItem(item)
            local entry = self._byItem[ni]
            if not entry then return false end
            self._byItem[ni] = nil
            if entry.prev then entry.prev.next = entry.next else self._head = entry.next end
            if entry.next then entry.next.prev = entry.prev else self._tail = entry.prev end
            self.size = self.size - 1
            return true
        end

        function methods:clear()
            self._byItem = {}
            self._head = nil
            self._tail = nil
            self.size = 0
        end

        function methods:items()
            local cur = self._head
            return function()
                if not cur then return nil end
                local e = cur
                cur = cur.next
                return denormalizeItem(e.item)
            end
        end

        function methods:forEach(fn)
            local cur = self._head
            while cur do
                local v = denormalizeItem(cur.item)
                fn(v, v, self)
                cur = cur.next
            end
        end
        _M_set = M
    end

    do

        local compat = _M_compat
        local BigInt = _M_bigint
        local Map    = _M_map
        local Set    = _M_set

        local mathType  = compat.mathType
        local isArray   = compat.isArray
        local newBigInt = BigInt.new
        local isBigInt  = BigInt.isBigInt
        local isMap     = Map.isMap
        local isSet     = Set.isSet

        local huge = math.huge
        local sfind = string.find
        local smatch = string.match
        local ssub = string.sub
        local type = type
        local pairs = pairs
        local getmetatable = getmetatable
        local select = select

        local M = {}

        local PATTERN = {}
        M.PATTERN = PATTERN

        local function leaf(name, test)
            return { [PATTERN] = name, _test = test }
        end

        local function tag(name, t)
            t = t or {}
            t[PATTERN] = name
            return t
        end

        local function isP(v)
            return type(v) == "table" and v[PATTERN] ~= nil
        end
        M.isP = isP

        local function isSelect(v)
            return isP(v) and v[PATTERN] == "select"
        end
        M.isSelect = isSelect

        local buildTest

        local function buildTopArrayTest(arr)
            local set, hasNan, hasNil = {}, false, false
            local n = #arr
            for i = 1, n do
                local v = arr[i]
                if v == nil then hasNil = true
                elseif v ~= v then hasNan = true
                else set[v] = true end
            end
            return function(v)
                if v == nil then return hasNil end
                if v ~= v then return hasNan end
                return set[v] == true
            end
        end

        local function buildShapeTest(shape)
            local entries, n = {}, 0
            for k, sub in pairs(shape) do
                n = n + 1
                entries[n] = { key = k, test = buildTest(sub) }
            end
            return function(v)
                if type(v) ~= "table" then return false end
                for i = 1, n do
                    local e = entries[i]
                    if not e.test(v[e.key]) then return false end
                end
                return true
            end
        end

        local plainCache = setmetatable({}, { __mode = "k" })

        buildTest = function(pat)
            if pat == nil then
                return function(v) return v == nil end
            end
            if type(pat) ~= "table" then
                local lit = pat
                if lit ~= lit then
                    return function(v) return v ~= v end
                end
                return function(v) return v == lit end
            end
            if pat._test ~= nil then return pat._test end
            if pat[PATTERN] ~= nil then
                error("buildTest : P descriptor missing _test for tag " .. tostring(pat[PATTERN]), 0)
            end
            local cached = plainCache[pat]
            if cached ~= nil then return cached end
            if isArray(pat) then
                cached = buildTopArrayTest(pat)
            else
                cached = buildShapeTest(pat)
            end
            plainCache[pat] = cached
            return cached
        end
        M.buildTest = buildTest

        local P = {}

        P.any            = leaf("any",            function() return true end)
        P.string         = leaf("string",         function(v) return type(v) == "string" end)
        P.number         = leaf("number",         function(v) return type(v) == "number" end)
        P.boolean        = leaf("boolean",        function(v) return type(v) == "boolean" end)
        P.bigint         = leaf("bigint",         function(v) return isBigInt(v) end)
        P.func           = leaf("function",       function(v) return type(v) == "function" end)
        P.nullish        = leaf("nullish",        function(v) return v == nil end)
        P.defined        = leaf("defined",        function(v) return v ~= nil end)
        P.nonNullable    = P.defined
        P.positive       = leaf("positive",       function(v) return type(v) == "number" and v > 0 end)
        P.negative       = leaf("negative",       function(v) return type(v) == "number" and v < 0 end)
        P.integer        = leaf("integer",        function(v) return mathType(v) == "integer" end)
        P.float          = leaf("float",          function(v) return mathType(v) == "float"   end)
        P.finite         = leaf("finite",         function(v)
            return type(v) == "number" and v == v and v ~= huge and v ~= -huge
        end)
        P.bigintPositive = leaf("bigintPositive", function(v) return isBigInt(v) and v:isPositive() end)
        P.bigintNegative = leaf("bigintNegative", function(v) return isBigInt(v) and v:isNegative() end)

        function P.when(fn)
            return { [PATTERN] = "when", fn = fn, _test = fn }
        end

        function P.instanceOf(mt)
            return { [PATTERN] = "instanceOf", mt = mt,
                     _test = function(v) return type(v) == "table" and getmetatable(v) == mt end }
        end

        function P.luaPattern(pat)
            return { [PATTERN] = "luaPattern", pat = pat,
                     _test = function(v) return type(v) == "string" and smatch(v, pat) ~= nil end }
        end

        function P.startsWithStr(s)
            local len = #s
            return { [PATTERN] = "startsWithStr", s = s,
                     _test = function(v) return type(v) == "string" and ssub(v, 1, len) == s end }
        end

        function P.endsWithStr(s)
            local len = #s
            return { [PATTERN] = "endsWithStr", s = s,
                     _test = function(v) return type(v) == "string" and ssub(v, -len) == s end }
        end

        function P.minLengthStr(n)
            return { [PATTERN] = "minLengthStr", n = n,
                     _test = function(v) return type(v) == "string" and #v >= n end }
        end
        function P.maxLengthStr(n)
            return { [PATTERN] = "maxLengthStr", n = n,
                     _test = function(v) return type(v) == "string" and #v <= n end }
        end
        function P.lengthStr(n)
            return { [PATTERN] = "lengthStr", n = n,
                     _test = function(v) return type(v) == "string" and #v == n end }
        end
        function P.includesStr(s)
            return { [PATTERN] = "includesStr", s = s,
                     _test = function(v) return type(v) == "string" and sfind(v, s, 1, true) ~= nil end }
        end

        function P.between(min, max)
            return { [PATTERN] = "between", min = min, max = max,
                     _test = function(v) return type(v) == "number" and v >= min and v <= max end }
        end
        function P.gt(n)  return { [PATTERN] = "gt",  n = n,
                                   _test = function(v) return type(v) == "number" and v >  n end } end
        function P.gte(n) return { [PATTERN] = "gte", n = n,
                                   _test = function(v) return type(v) == "number" and v >= n end } end
        function P.lt(n)  return { [PATTERN] = "lt",  n = n,
                                   _test = function(v) return type(v) == "number" and v <  n end } end
        function P.lte(n) return { [PATTERN] = "lte", n = n,
                                   _test = function(v) return type(v) == "number" and v <= n end } end

        function P.bigintGt(n)
            n = newBigInt(n)
            return { [PATTERN] = "bigintGt", n = n,
                     _test = function(v) return isBigInt(v) and v >  n end }
        end
        function P.bigintGte(n)
            n = newBigInt(n)
            return { [PATTERN] = "bigintGte", n = n,
                     _test = function(v) return isBigInt(v) and v >= n end }
        end
        function P.bigintLt(n)
            n = newBigInt(n)
            return { [PATTERN] = "bigintLt", n = n,
                     _test = function(v) return isBigInt(v) and v <  n end }
        end
        function P.bigintLte(n)
            n = newBigInt(n)
            return { [PATTERN] = "bigintLte", n = n,
                     _test = function(v) return isBigInt(v) and v <= n end }
        end
        function P.bigintBetween(min, max)
            min = newBigInt(min); max = newBigInt(max)
            return { [PATTERN] = "bigintBetween", min = min, max = max,
                     _test = function(v) return isBigInt(v) and v >= min and v <= max end }
        end

        function P.union(...)
            local values, n = { ... }, select("#", ...)
            local set, hasNan, hasNil = {}, false, false
            for i = 1, n do
                local v = values[i]
                if v == nil then hasNil = true
                elseif v ~= v then hasNan = true
                else set[v] = true end
            end
            return {
                [PATTERN] = "union", values = values, n = n,
                _test = function(v)
                    if v == nil then return hasNil end
                    if v ~= v then return hasNan end
                    return set[v] == true
                end,
            }
        end

        function P.not_(inner)
            local innerTest = buildTest(inner)
            return tag("not", { inner = inner,
                _test = function(v) return not innerTest(v) end })
        end

        function P.optional(inner)
            local innerTest = buildTest(inner)
            return tag("optional", { inner = inner,
                _test = function(v) return v == nil or innerTest(v) end })
        end

        function P.array(item)
            local itemTest = buildTest(item)
            return tag("array", { item = item,
                _test = function(v)
                    if type(v) ~= "table" then return false end
                    local n = #v
                    for i = 1, n do
                        if not itemTest(v[i]) then return false end
                    end
                    return true
                end })
        end

        function P.arrayOf(item, opts)
            local itemTest = buildTest(item)
            local min = opts and opts.min
            local max = opts and opts.max
            return tag("arrayOf", { item = item, min = min, max = max,
                _test = function(v)
                    if type(v) ~= "table" then return false end
                    local n = #v
                    if min ~= nil and n < min then return false end
                    if max ~= nil and n > max then return false end
                    for i = 1, n do
                        if not itemTest(v[i]) then return false end
                    end
                    return true
                end })
        end

        function P.arrayIncludes(item)
            local itemTest = buildTest(item)
            return tag("arrayIncludes", { item = item,
                _test = function(v)
                    if type(v) ~= "table" then return false end
                    local n = #v
                    for i = 1, n do
                        if itemTest(v[i]) then return true end
                    end
                    return false
                end })
        end

        function P.set(item)
            local itemTest = buildTest(item)
            return tag("set", { item = item,
                _test = function(v)
                    if not isSet(v) then return false end
                    for it in v:items() do
                        if not itemTest(it) then return false end
                    end
                    return true
                end })
        end

        function P.map(key, value)
            local keyTest = buildTest(key)
            local valTest = buildTest(value)
            return tag("map", { key = key, value = value,
                _test = function(v)
                    if not isMap(v) then return false end
                    for k, val in v:pairs() do
                        if not keyTest(k) or not valTest(val) then return false end
                    end
                    return true
                end })
        end

        function P.intersection(...)
            local parts, n = { ... }, select("#", ...)
            local tests = {}
            for i = 1, n do tests[i] = buildTest(parts[i]) end
            return tag("intersection", { parts = parts, n = n,
                _test = function(v)
                    for i = 1, n do
                        if not tests[i](v) then return false end
                    end
                    return true
                end })
        end

        function P.anyOf(...)
            local items, n = { ... }, select("#", ...)
            local tests = {}
            for i = 1, n do tests[i] = buildTest(items[i]) end
            return tag("anyOf", { items = items, n = n,
                _test = function(v)
                    for i = 1, n do
                        if tests[i](v) then return true end
                    end
                    return false
                end })
        end

        function P.tuple(...)
            local items, n = { ... }, select("#", ...)
            local tests = {}
            for i = 1, n do tests[i] = buildTest(items[i]) end
            return tag("tuple", { items = items, n = n,
                _test = function(v)
                    if type(v) ~= "table" or #v ~= n then return false end
                    for i = 1, n do
                        if not tests[i](v[i]) then return false end
                    end
                    return true
                end })
        end

        function P.startsWith(...)
            local items, n = { ... }, select("#", ...)
            local tests = {}
            for i = 1, n do tests[i] = buildTest(items[i]) end
            return tag("startsWith", { items = items, n = n,
                _test = function(v)
                    if type(v) ~= "table" or #v < n then return false end
                    for i = 1, n do
                        if not tests[i](v[i]) then return false end
                    end
                    return true
                end })
        end

        function P.endsWith(...)
            local items, n = { ... }, select("#", ...)
            local tests = {}
            for i = 1, n do tests[i] = buildTest(items[i]) end
            return tag("endsWith", { items = items, n = n,
                _test = function(v)
                    if type(v) ~= "table" then return false end
                    local vn = #v
                    if vn < n then return false end
                    local offset = vn - n
                    for i = 1, n do
                        if not tests[i](v[offset + i]) then return false end
                    end
                    return true
                end })
        end

        function P.shape(tbl)
            if type(tbl) ~= "table" then
                error("P.shape expects a table", 2)
            end
            local entries, n = {}, 0
            local declared = {}
            for k, sub in pairs(tbl) do
                n = n + 1
                entries[n] = { key = k, test = buildTest(sub) }
                declared[k] = true
            end
            return tag("shape", {
                shape = tbl, declared = declared,
                _test = function(v)
                    if type(v) ~= "table" then return false end
                    for i = 1, n do
                        local e = entries[i]
                        if not e.test(v[e.key]) then return false end
                    end
                    for k in pairs(v) do
                        if not declared[k] then return false end
                    end
                    return true
                end
            })
        end

        function P.captureSlice(label, sliceFn)
            return tag("captureSlice", { label = label, sliceFn = sliceFn,
                _test = function() return true end })
        end

        function P.select(arg1, arg2)
            if arg1 == nil and arg2 == nil then
                return tag("select", { label = nil, pattern = nil,
                    _test = function() return true end })
            end
            if arg2 == nil then
                if type(arg1) == "string" then
                    return tag("select", { label = arg1, pattern = nil,
                        _test = function() return true end })
                end
                local innerTest = buildTest(arg1)
                return tag("select", { label = nil, pattern = arg1,
                    _test = function(v) return innerTest(v) end })
            end
            local innerTest = buildTest(arg2)
            return tag("select", { label = arg1, pattern = arg2,
                _test = function(v) return innerTest(v) end })
        end

        M.P = P
        _M_p = M
    end

    do

        local p = _M_p

        local PATTERN = p.PATTERN
        local isP = p.isP
        local isSelect = p.isSelect
        local buildTest = p.buildTest
        local type = type
        local pairs = pairs

        local compat = _M_compat
        local isArray = compat.isArray

        local M = {}

        local function appendPath(path, pn, key)
            local out = {}
            for i = 1, pn do out[i] = path[i] end
            out[pn + 1] = key
            return out
        end

        local function collectSelects(pattern, path, pn)
            path = path or {}
            pn = pn or 0
            if isSelect(pattern) then
                local head = { label = pattern.label, path = path, n = pn }
                local sub = pattern.pattern
                if sub == nil then return { head } end
                local rest = collectSelects(sub, path, pn)
                local out = { head }
                local rn = #rest
                for i = 1, rn do out[i + 1] = rest[i] end
                return out
            end
            if isP(pattern) then
                local tag = pattern[PATTERN]
                if tag == "captureSlice" then
                    return { { label = pattern.label,
                               path = appendPath(path, pn, pattern.sliceFn),
                               n = pn + 1 } }
                end
                if tag == "array" or tag == "arrayOf" or tag == "arrayIncludes" then
                    return collectSelects(pattern.item, appendPath(path, pn, 1), pn + 1)
                end
                if tag == "tuple" or tag == "startsWith" or tag == "endsWith" then
                    local out, on = {}, 0
                    local n = pattern.n
                    local items = pattern.items
                    for i = 1, n do
                        local sub = collectSelects(items[i], appendPath(path, pn, i), pn + 1)
                        local sn = #sub
                        for j = 1, sn do
                            on = on + 1
                            out[on] = sub[j]
                        end
                    end
                    return out
                end
                if tag == "not" or tag == "optional" then
                    return collectSelects(pattern.inner, path, pn)
                end
                if tag == "shape" then
                    local out, on = {}, 0
                    for k, sub in pairs(pattern.shape) do
                        local subSelects = collectSelects(sub, appendPath(path, pn, k), pn + 1)
                        local sn = #subSelects
                        for j = 1, sn do
                            on = on + 1
                            out[on] = subSelects[j]
                        end
                    end
                    return out
                end
                if tag == "intersection" then
                    local out, on = {}, 0
                    local n = pattern.n
                    local parts = pattern.parts
                    for i = 1, n do
                        local sub = collectSelects(parts[i], path, pn)
                        local sn = #sub
                        for j = 1, sn do
                            on = on + 1
                            out[on] = sub[j]
                        end
                    end
                    return out
                end
                return {}
            end
            if type(pattern) ~= "table" then return {} end
            if isArray(pattern) then return {} end
            local out, on = {}, 0
            for k, v in pairs(pattern) do
                local sub = collectSelects(v, appendPath(path, pn, k), pn + 1)
                local sn = #sub
                for i = 1, sn do
                    on = on + 1
                    out[on] = sub[i]
                end
            end
            return out
        end
        M.collectSelects = collectSelects

        local function readPath(value, path, n)
            local cur = value
            for i = 1, n do
                if cur == nil then return nil end
                local step = path[i]
                if type(step) == "function" then
                    cur = step(cur)
                else
                    cur = cur[step]
                end
            end
            return cur
        end
        M.readPath = readPath

        local function resolveThen(thenVal, selects)
            if type(thenVal) ~= "function" then
                return function(_) return thenVal end
            end
            local nsel = #selects

            if nsel == 0 then return thenVal end
            local fn = thenVal
            if nsel == 1 and selects[1].label == nil then
                local s = selects[1]
                local path, pn = s.path, s.n
                return function(v) return fn(readPath(v, path, pn), v) end
            end
            return function(v)
                local out = {}
                for i = 1, nsel do
                    local s = selects[i]
                    local key = s.label or "$0"
                    out[key] = readPath(v, s.path, s.n)
                end
                return fn(out, v)
            end
        end

        local function ruleHandler(rule)
            return rule.handler
        end

        local function isLiteralKeySafe(v)
            if v == nil then return false end
            if type(v) == "table" then return false end
            return v == v
        end

        function M.compileRules(rules)
            local literalMap = {}
            local literalCount = 0
            local complex = {}
            local complexCount = 0
            local fallback = nil

            local n = #rules
            for i = 1, n do
                local rule = rules[i]
                if rule.otherwise ~= nil then
                    local r = rule.otherwise
                    if type(r) == "function" then
                        fallback = r
                    else
                        fallback = function(_) return r end
                    end
                else
                    local pattern = rule.with
                    local selects = collectSelects(pattern)
                    local thenFn = resolveThen(ruleHandler(rule), selects)
                    local guard = rule.when

                    if isLiteralKeySafe(pattern)
                        and guard == nil
                        and #selects == 0
                        and literalMap[pattern] == nil
                    then
                        literalMap[pattern] = thenFn
                        literalCount = literalCount + 1
                    else
                        complexCount = complexCount + 1
                        complex[complexCount] = {
                            test = buildTest(pattern),
                            guard = guard,
                            thenFn = thenFn,
                        }
                    end
                end
            end

            local hasMap = literalCount > 0
            local hasComplex = complexCount > 0

            if hasMap and not hasComplex then
                return function(v)
                    local hit = literalMap[v]
                    if hit ~= nil then return hit(v) end
                    if fallback ~= nil then return fallback(v) end
                    error("Non-exhaustive match", 0)
                end
            end
            if not hasMap and hasComplex then
                return function(v)
                    for i = 1, complexCount do
                        local r = complex[i]
                        if r.test(v) and (r.guard == nil or r.guard(v)) then
                            return r.thenFn(v)
                        end
                    end
                    if fallback ~= nil then return fallback(v) end
                    error("Non-exhaustive match", 0)
                end
            end
            return function(v)
                local hit = literalMap[v]
                if hit ~= nil then return hit(v) end
                for i = 1, complexCount do
                    local r = complex[i]
                    if r.test(v) and (r.guard == nil or r.guard(v)) then
                        return r.thenFn(v)
                    end
                end
                if fallback ~= nil then return fallback(v) end
                error("Non-exhaustive match", 0)
            end
        end
        _M_compile = M
    end

    do

        local M = {}

        M.LIT     = "Lit"
        M.WILD    = "Wild"
        M.BIND    = "Bind"
        M.REF     = "Ref"
        M.INTERP  = "Interp"
        M.UNION   = "Union"
        M.INTER   = "Inter"
        M.OPT     = "Opt"
        M.AS      = "As"
        M.NOT     = "Not"
        M.GUARD   = "Guard"
        M.SHAPE   = "Shape"

        M.TUPLE   = "Tuple"
        M.ARRAY   = "Array"

        M.E_LIT    = "ELit"
        M.E_VAR    = "EVar"
        M.E_INTERP = "EInterp"
        M.E_MEMBER = "EMember"
        M.E_CALL   = "ECall"
        M.E_UNARY  = "EUnary"
        M.E_BINARY = "EBinary"

        function M.lit(v)              return { kind = M.LIT,   value = v } end
        function M.wild()              return { kind = M.WILD } end
        function M.bind(name)          return { kind = M.BIND,  name = name } end
        function M.ref(name, args)     return { kind = M.REF,   name = name, args = args } end
        function M.interp(name)        return { kind = M.INTERP, name = name } end
        function M.union(items)        return { kind = M.UNION, items = items } end
        function M.inter(items)        return { kind = M.INTER, items = items } end
        function M.opt(inner)          return { kind = M.OPT,   inner = inner } end
        function M.asNode(inner, name) return { kind = M.AS,    inner = inner, name = name } end
        function M.notNode(inner)      return { kind = M.NOT,   inner = inner } end
        function M.guard(inner, expr)  return { kind = M.GUARD, inner = inner, expr = expr } end
        function M.shape(fields, rest, strict) return { kind = M.SHAPE, fields = fields, rest = rest, strict = strict or false } end
        function M.tuple(items)        return { kind = M.TUPLE, items = items } end
        function M.array(items, rest)  return { kind = M.ARRAY, items = items, rest = rest } end

        function M.eLit(v)               return { kind = M.E_LIT,    value = v } end
        function M.eVar(name)            return { kind = M.E_VAR,    name = name } end
        function M.eInterp(name)         return { kind = M.E_INTERP, name = name } end
        function M.eMember(obj, prop)    return { kind = M.E_MEMBER, obj = obj, prop = prop } end
        function M.eCall(callee, args)   return { kind = M.E_CALL,   callee = callee, args = args } end
        function M.eUnary(op, operand)   return { kind = M.E_UNARY,  op = op, operand = operand } end
        function M.eBinary(op, l, r)     return { kind = M.E_BINARY, op = op, left = l, right = r } end
        _M_dsl_ast = M
    end

    do

        local ssub = string.sub

        local M = {}

        local KEYWORDS = {
            ["if"]    = "KW_IF",    ["and"]   = "KW_AND",   ["or"]    = "KW_OR",
            ["not"]   = "KW_NOT",   ["as"]    = "KW_AS",
            ["true"]  = "KW_TRUE",  ["false"] = "KW_FALSE", ["nil"]   = "KW_NIL",
        }

        local THREE_CHAR = { ["..."] = "ELLIPSIS" }

        local TWO_CHAR = {
            ["=="] = "EQ",  ["~="] = "NEQ", ["!="] = "NEQ",
            ["<="] = "LTE", [">="] = "GTE",
            ["||"] = "OR",  ["&&"] = "AND",
            ["//"] = "IDIV",
            ["{|"] = "LBRACE_PIPE", ["|}"] = "PIPE_RBRACE",
        }

        local ONE_CHAR = {
            ["|"] = "PIPE",   ["&"] = "AMP",    ["!"] = "BANG",   ["?"] = "QMARK",
            ["$"] = "DOLLAR", ["("] = "LPAREN", [")"] = "RPAREN",
            ["["] = "LBRACK", ["]"] = "RBRACK", ["{"] = "LBRACE", ["}"] = "RBRACE",
            ["."] = "DOT",    [","] = "COMMA",  [":"] = "COLON",
            ["+"] = "PLUS",   ["-"] = "MINUS",  ["*"] = "STAR",   ["/"] = "SLASH",
            ["%"] = "PERCENT", ["<"] = "LT",    [">"] = "GT",
        }

        local function isAlpha(c)
            return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"
        end
        local function isDigit(c) return c >= "0" and c <= "9" end
        local function isAlnum(c) return isAlpha(c) or isDigit(c) end
        local function isUpper(c) return c >= "A" and c <= "Z" end

        function M.tokenize(src)
            local tokens, ntok = {}, 0
            local pos, line, col = 1, 1, 1
            local n = #src

            local function err(msg)
                error(("DSL lex error at %d:%d : %s"):format(line, col, msg), 0)
            end

            local function push(kind, value, l, c)
                ntok = ntok + 1
                tokens[ntok] = { kind = kind, value = value, line = l, col = c }
            end

            while pos <= n do
                local c = ssub(src, pos, pos)

                if c == " " or c == "\t" or c == "\r" then
                    pos = pos + 1; col = col + 1

                elseif c == "\n" then
                    pos = pos + 1; line = line + 1; col = 1

                elseif pos + 2 <= n and THREE_CHAR[ssub(src, pos, pos + 2)] then
                    local s = ssub(src, pos, pos + 2)
                    push(THREE_CHAR[s], s, line, col)
                    pos = pos + 3; col = col + 3

                elseif pos + 1 <= n and TWO_CHAR[ssub(src, pos, pos + 1)] then
                    local s = ssub(src, pos, pos + 1)
                    push(TWO_CHAR[s], s, line, col)
                    pos = pos + 2; col = col + 2

                elseif c == "'" or c == '"' then
                    local quote = c
                    local startL, startC = line, col
                    pos = pos + 1; col = col + 1
                    local buf, bn = {}, 0
                    while pos <= n do
                        local ch = ssub(src, pos, pos)
                        if ch == quote then break end
                        if ch == "\\" then
                            if pos + 1 > n then err("unterminated escape") end
                            local esc = ssub(src, pos + 1, pos + 1)
                            local mapped
                            if     esc == "n"  then mapped = "\n"
                            elseif esc == "t"  then mapped = "\t"
                            elseif esc == "r"  then mapped = "\r"
                            elseif esc == "\\" then mapped = "\\"
                            elseif esc == "'"  then mapped = "'"
                            elseif esc == '"'  then mapped = '"'
                            else err("unknown escape \\" .. esc) end
                            bn = bn + 1; buf[bn] = mapped
                            pos = pos + 2; col = col + 2
                        elseif ch == "\n" then
                            err("unterminated string (newline in literal)")
                        else
                            bn = bn + 1; buf[bn] = ch
                            pos = pos + 1; col = col + 1
                        end
                    end
                    if pos > n then err("unterminated string") end
                    pos = pos + 1; col = col + 1
                    push("STRING", table.concat(buf), startL, startC)

                elseif isDigit(c) then
                    local startL, startC = line, col
                    local startPos = pos
                    while pos <= n and isDigit(ssub(src, pos, pos)) do
                        pos = pos + 1; col = col + 1
                    end
                    if pos <= n and ssub(src, pos, pos) == "." then
                        local next1 = ssub(src, pos + 1, pos + 1)
                        if isDigit(next1) then
                            pos = pos + 1; col = col + 1
                            while pos <= n and isDigit(ssub(src, pos, pos)) do
                                pos = pos + 1; col = col + 1
                            end
                        end
                    end
                    local s = ssub(src, startPos, pos - 1)
                    local num = tonumber(s)
                    if num == nil then err("invalid number '" .. s .. "'") end
                    push("NUMBER", num, startL, startC)

                elseif isAlpha(c) then
                    local startL, startC = line, col
                    local startPos = pos
                    while pos <= n and isAlnum(ssub(src, pos, pos)) do
                        pos = pos + 1; col = col + 1
                    end
                    local s = ssub(src, startPos, pos - 1)
                    local kw = KEYWORDS[s]
                    local kind
                    if kw then
                        kind = kw
                    elseif s == "_" then
                        kind = "WILDCARD"
                    elseif isUpper(ssub(s, 1, 1)) then
                        kind = "IDENT_UP"
                    else
                        kind = "IDENT_LO"
                    end
                    push(kind, s, startL, startC)

                elseif ONE_CHAR[c] then
                    push(ONE_CHAR[c], c, line, col)
                    pos = pos + 1; col = col + 1

                else
                    err("unexpected character '" .. c .. "'")
                end
            end

            push("EOF", nil, line, col)
            return tokens
        end
        _M_dsl_lex = M
    end

    do

        local lexer = _M_dsl_lex
        local ast   = _M_dsl_ast

        local M = {}

        local function perr(t, msg)
            error(("DSL parse error at %d:%d : %s"):format(t.line, t.col, msg), 0)
        end

        local function peek(s, off)
            return s.tokens[s.pos + (off or 0)]
        end

        local function take(s)
            local t = s.tokens[s.pos]; s.pos = s.pos + 1; return t
        end

        local function check(s, kind)
            return s.tokens[s.pos].kind == kind
        end

        local function accept(s, kind)
            if s.tokens[s.pos].kind == kind then return take(s) end
            return nil
        end

        local function expect(s, kind, what)
            local t = s.tokens[s.pos]
            if t.kind ~= kind then
                perr(t, ("expected %s, got %s"):format(what or kind, t.kind))
            end
            return take(s)
        end

        local parsePattern, parseUnion, parseIntersect, parsePostfix, parsePrimary
        local parseShape, parseArray, parseScopeRefArgs
        local parseExpr, parseOr, parseAnd, parseNot, parseCmp
        local parseAdd, parseMul, parseUnary, parseCall, parseAtom

        parsePattern = function(s)
            local p = parseUnion(s)
            if accept(s, "KW_IF") then
                return ast.guard(p, parseExpr(s))
            end
            return p
        end

        parseUnion = function(s)
            local first = parseIntersect(s)
            if not check(s, "PIPE") then return first end
            local items = { first }
            while accept(s, "PIPE") do
                items[#items + 1] = parseIntersect(s)
            end
            return ast.union(items)
        end

        parseIntersect = function(s)
            local first = parsePostfix(s)
            if not check(s, "AMP") then return first end
            local items = { first }
            while accept(s, "AMP") do
                items[#items + 1] = parsePostfix(s)
            end
            return ast.inter(items)
        end

        parsePostfix = function(s)
            local p = parsePrimary(s)
            while true do
                if accept(s, "QMARK") then
                    p = ast.opt(p)
                elseif accept(s, "KW_AS") then
                    local nameTok = peek(s)
                    if nameTok.kind ~= "IDENT_LO" then
                        perr(nameTok, "expected lowercase binding name after 'as'")
                    end
                    take(s)
                    p = ast.asNode(p, nameTok.value)
                else
                    break
                end
            end
            return p
        end

        parsePrimary = function(s)
            local t = peek(s)
            local k = t.kind

            if k == "WILDCARD" then take(s); return ast.wild() end
            if k == "NUMBER"   then take(s); return ast.lit(t.value) end
            if k == "STRING"   then take(s); return ast.lit(t.value) end
            if k == "KW_TRUE"  then take(s); return ast.lit(true) end
            if k == "KW_FALSE" then take(s); return ast.lit(false) end
            if k == "KW_NIL"   then take(s); return ast.lit(nil) end
            if k == "IDENT_LO" then take(s); return ast.bind(t.value) end

            if k == "IDENT_UP" then
                take(s)
                local args = nil
                if accept(s, "LPAREN") then
                    args = parseScopeRefArgs(s)
                    expect(s, "RPAREN", "')'")
                end
                return ast.ref(t.value, args)
            end

            if k == "DOLLAR" then
                take(s)
                local id = peek(s)
                if id.kind ~= "IDENT_LO" and id.kind ~= "IDENT_UP" then
                    perr(id, "expected ident after '$'")
                end
                take(s)
                return ast.interp(id.value)
            end

            if k == "LBRACE" then return parseShape(s, false) end
            if k == "LBRACE_PIPE" then return parseShape(s, true) end
            if k == "LBRACK" then return parseArray(s) end
            if k == "LPAREN" then
                take(s)
                local first = parsePattern(s)
                if accept(s, "COMMA") then
                    local items = { first }
                    while true do
                        items[#items + 1] = parsePattern(s)
                        if not accept(s, "COMMA") then break end
                        if check(s, "RPAREN") then break end
                    end
                    expect(s, "RPAREN", "')'")
                    return ast.tuple(items)
                end
                expect(s, "RPAREN", "')'")
                return first
            end

            if k == "BANG" or k == "KW_NOT" then
                take(s)
                return ast.notNode(parsePrimary(s))
            end

            if (k == "MINUS" or k == "PLUS") and peek(s, 1).kind == "NUMBER" then
                local sign = take(s).kind
                local num = take(s).value
                if sign == "MINUS" then num = -num end
                return ast.lit(num)
            end

            perr(t, ("unexpected %s '%s' in pattern"):format(k, tostring(t.value)))
        end

        parseScopeRefArgs = function(s)
            if check(s, "RPAREN") then return {} end
            local args = {}
            while true do
                local fld = peek(s)
                if fld.kind ~= "IDENT_LO" and fld.kind ~= "IDENT_UP" then
                    perr(fld, "expected field name in scope ref args")
                end
                take(s)
                local op = peek(s)
                local opStr
                if     op.kind == "EQ"  then opStr = "=="
                elseif op.kind == "NEQ" then opStr = "~="
                elseif op.kind == "LT"  then opStr = "<"
                elseif op.kind == "LTE" then opStr = "<="
                elseif op.kind == "GT"  then opStr = ">"
                elseif op.kind == "GTE" then opStr = ">="
                else
                    perr(op, "expected comparison operator (==, ~=, <, <=, >, >=)")
                end
                take(s)
                local rhs = parseExpr(s)
                args[#args + 1] = { field = fld.value, op = opStr, expr = rhs }
                if not accept(s, "COMMA") then break end
            end
            return args
        end

        parseShape = function(s, strict)
            local openKind  = strict and "LBRACE_PIPE" or "LBRACE"
            local openStr   = strict and "'{|'"        or "'{'"
            local closeKind = strict and "PIPE_RBRACE" or "RBRACE"
            local closeStr  = strict and "'|}'"        or "'}'"
            expect(s, openKind, openStr)
            local fields, rest = {}, nil
            if accept(s, closeKind) then return ast.shape(fields, rest, strict) end
            while true do
                if accept(s, "ELLIPSIS") then
                    if strict then
                        perr(s.tokens[s.pos - 1],
                            "...rest is not allowed in a strict shape ('{| ... |}'). Use a regular '{ ... }' shape if you want to capture extras.")
                    end
                    local name = nil
                    local nx = peek(s)
                    if nx.kind == "IDENT_LO" then take(s); name = nx.value end
                    rest = { name = name }
                    if accept(s, "COMMA") then
                        perr(s.tokens[s.pos - 1], "...rest must be the last field in shape")
                    end
                    break
                end
                local keyTok = peek(s)
                local k = keyTok.kind
                if k ~= "IDENT_LO" and k ~= "IDENT_UP" and k ~= "STRING" then
                    perr(keyTok, "expected field name (ident or quoted string)")
                end
                take(s)
                local key = keyTok.value
                if accept(s, "COLON") then
                    local p = parsePattern(s)
                    fields[#fields + 1] = { key = key, pattern = p, shorthand = false }
                else
                    if k ~= "IDENT_LO" then
                        perr(keyTok, "shape shorthand requires lowercase ident (got '" .. tostring(key) .. "')")
                    end
                    fields[#fields + 1] = { key = key, pattern = ast.bind(key), shorthand = true }
                end
                if not accept(s, "COMMA") then break end
                if check(s, closeKind) then break end
            end
            expect(s, closeKind, closeStr)
            return ast.shape(fields, rest, strict)
        end

        parseArray = function(s)
            expect(s, "LBRACK", "'['")
            local items, rest = {}, nil
            if accept(s, "RBRACK") then return ast.array(items, rest) end

            if accept(s, "ELLIPSIS") then
                local name = nil
                local nx = peek(s)
                if nx.kind == "IDENT_LO" then take(s); name = nx.value end
                rest = { name = name, atStart = true }
                if accept(s, "COMMA") then

                elseif check(s, "RBRACK") then
                    take(s)
                    return ast.array(items, rest)
                else
                    perr(peek(s), "expected ',' or ']' after rest")
                end
            end

            while true do
                if accept(s, "ELLIPSIS") then
                    if rest ~= nil then
                        perr(s.tokens[s.pos - 1], "only one '...' allowed per array")
                    end
                    local name = nil
                    local nx = peek(s)
                    if nx.kind == "IDENT_LO" then take(s); name = nx.value end
                    rest = { name = name, atStart = false }
                    if accept(s, "COMMA") then
                        perr(s.tokens[s.pos - 1], "...rest must be the last item in array")
                    end
                    break
                end
                items[#items + 1] = parsePattern(s)
                if not accept(s, "COMMA") then break end
                if check(s, "RBRACK") then break end
            end
            expect(s, "RBRACK", "']'")
            return ast.array(items, rest)
        end

        parseExpr = function(s) return parseOr(s) end

        parseOr = function(s)
            local l = parseAnd(s)
            while check(s, "KW_OR") or check(s, "OR") do
                take(s)
                l = ast.eBinary("or", l, parseAnd(s))
            end
            return l
        end

        parseAnd = function(s)
            local l = parseNot(s)
            while check(s, "KW_AND") or check(s, "AND") do
                take(s)
                l = ast.eBinary("and", l, parseNot(s))
            end
            return l
        end

        parseNot = function(s)
            if accept(s, "KW_NOT") or accept(s, "BANG") then
                return ast.eUnary("not", parseNot(s))
            end
            return parseCmp(s)
        end

        parseCmp = function(s)
            local l = parseAdd(s)
            local k = peek(s).kind
            local op
            if     k == "EQ"  then op = "=="
            elseif k == "NEQ" then op = "~="
            elseif k == "LT"  then op = "<"
            elseif k == "LTE" then op = "<="
            elseif k == "GT"  then op = ">"
            elseif k == "GTE" then op = ">="
            end
            if op then
                take(s)
                return ast.eBinary(op, l, parseAdd(s))
            end
            return l
        end

        parseAdd = function(s)
            local l = parseMul(s)
            while true do
                local k = peek(s).kind
                if k == "PLUS" or k == "MINUS" then
                    local op = take(s).value
                    l = ast.eBinary(op, l, parseMul(s))
                else break end
            end
            return l
        end

        parseMul = function(s)
            local l = parseUnary(s)
            while true do
                local k = peek(s).kind
                if k == "STAR" or k == "SLASH" or k == "PERCENT" or k == "IDIV" then
                    local op = take(s).value
                    l = ast.eBinary(op, l, parseUnary(s))
                else break end
            end
            return l
        end

        parseUnary = function(s)
            local k = peek(s).kind
            if k == "MINUS" or k == "PLUS" then
                local op = take(s).value
                return ast.eUnary(op, parseUnary(s))
            end
            return parseCall(s)
        end

        parseCall = function(s)
            local p = parseAtom(s)
            while true do
                local k = peek(s).kind
                if k == "DOT" then
                    take(s)
                    local id = peek(s)
                    if id.kind ~= "IDENT_LO" and id.kind ~= "IDENT_UP" then
                        perr(id, "expected ident after '.'")
                    end
                    take(s)
                    p = ast.eMember(p, id.value)
                elseif k == "LPAREN" then
                    take(s)
                    local args = {}
                    if not check(s, "RPAREN") then
                        while true do
                            args[#args + 1] = parseExpr(s)
                            if not accept(s, "COMMA") then break end
                        end
                    end
                    expect(s, "RPAREN", "')'")
                    p = ast.eCall(p, args)
                else
                    break
                end
            end
            return p
        end

        parseAtom = function(s)
            local t = peek(s)
            local k = t.kind
            if k == "NUMBER"   then take(s); return ast.eLit(t.value) end
            if k == "STRING"   then take(s); return ast.eLit(t.value) end
            if k == "KW_TRUE"  then take(s); return ast.eLit(true) end
            if k == "KW_FALSE" then take(s); return ast.eLit(false) end
            if k == "KW_NIL"   then take(s); return ast.eLit(nil) end
            if k == "IDENT_LO" or k == "IDENT_UP" then
                take(s); return ast.eVar(t.value)
            end
            if k == "DOLLAR" then
                take(s)
                local id = peek(s)
                if id.kind ~= "IDENT_LO" and id.kind ~= "IDENT_UP" then
                    perr(id, "expected ident after '$'")
                end
                take(s)
                return ast.eInterp(id.value)
            end
            if k == "LPAREN" then
                take(s)
                local e = parseExpr(s)
                expect(s, "RPAREN", "')'")
                return e
            end
            perr(t, ("unexpected %s in expression"):format(k))
        end

        function M.parse(src)
            local state = { tokens = lexer.tokenize(src), pos = 1 }
            local result = parsePattern(state)
            if state.tokens[state.pos].kind ~= "EOF" then
                perr(state.tokens[state.pos],
                    ("trailing input, expected EOF, got %s"):format(state.tokens[state.pos].kind))
            end
            return result
        end
        _M_dsl_parse = M
    end

    do

        local tunpack = table.unpack or unpack

        local M = {}

        local function eval(e, env, ctx)
            local k = e.kind
            if k == "ELit"    then return e.value end
            if k == "EVar"    then return env[e.name] end
            if k == "EInterp" then return ctx and ctx[e.name] end
            if k == "EMember" then
                local obj = eval(e.obj, env, ctx)
                if obj == nil then return nil end
                return obj[e.prop]
            end
            if k == "ECall" then
                local fn = eval(e.callee, env, ctx)
                if type(fn) ~= "function" then
                    error("DSL eval : attempted to call non-function", 0)
                end
                local n = #e.args
                local args = {}
                for i = 1, n do args[i] = eval(e.args[i], env, ctx) end
                return fn(tunpack(args, 1, n))
            end
            if k == "EUnary" then
                local x = eval(e.operand, env, ctx)
                local op = e.op
                if op == "not" then return not x end
                if op == "-"   then return -x end
                if op == "+"   then return x end
            end
            if k == "EBinary" then
                local op = e.op
                local l = eval(e.left, env, ctx)
                if op == "and" then
                    if not l then return l end
                    return eval(e.right, env, ctx)
                end
                if op == "or" then
                    if l then return l end
                    return eval(e.right, env, ctx)
                end
                local r = eval(e.right, env, ctx)
                if op == "==" then return l == r end
                if op == "~=" or op == "!=" then return l ~= r end
                if op == "<"  then return l <  r end
                if op == "<=" then return l <= r end
                if op == ">"  then return l >  r end
                if op == ">=" then return l >= r end
                if op == "+"  then return l +  r end
                if op == "-"  then return l -  r end
                if op == "*"  then return l *  r end
                if op == "/"  then return l /  r end
                if op == "%"  then return l %  r end

                if op == "//" then return math.floor(l / r) end
            end
            error("DSL eval : unknown expr kind '" .. tostring(k) .. "'", 0)
        end

        M.eval = eval
        _M_dsl_eval = M
    end

    do

        local ast       = _M_dsl_ast
        local p         = _M_p
        local mcompile  = _M_compile
        local evalMod   = _M_dsl_eval

        local P = p.P
        local collectSelects = mcompile.collectSelects
        local readPath       = mcompile.readPath
        local evalExpr       = evalMod.eval

        local tunpack = table.unpack or unpack

        local M = {}

        local compile

        local function err(msg)
            error("DSL compile error : " .. msg, 0)
        end

        local function checkShadowing(node, names)
            local k = node.kind
            if k == ast.BIND then
                if names[node.name] then
                    err("binding '" .. node.name .. "' shadows an earlier binding in the same pattern")
                end
                names[node.name] = true
                return
            end
            if k == ast.AS then
                if names[node.name] then
                    err("binding '" .. node.name .. "' shadows an earlier binding in the same pattern")
                end
                names[node.name] = true
                checkShadowing(node.inner, names)
                return
            end
            if k == ast.UNION then
                for i = 1, #node.items do
                    checkShadowing(node.items[i], {})
                end
                return
            end
            if k == ast.INTER then
                for i = 1, #node.items do checkShadowing(node.items[i], names) end
                return
            end
            if k == ast.OPT or k == ast.NOT then
                checkShadowing(node.inner, names); return
            end
            if k == ast.GUARD then
                checkShadowing(node.inner, names); return
            end
            if k == ast.SHAPE then
                for i = 1, #node.fields do
                    checkShadowing(node.fields[i].pattern, names)
                end
                if node.rest and node.rest.name then
                    if names[node.rest.name] then
                        err("rest binding '" .. node.rest.name .. "' shadows an earlier binding")
                    end
                    names[node.rest.name] = true
                end
                return
            end
            if k == ast.TUPLE or k == ast.ARRAY then
                for i = 1, #node.items do checkShadowing(node.items[i], names) end
                if node.rest and node.rest.name then
                    if names[node.rest.name] then
                        err("rest binding '" .. node.rest.name .. "' shadows an earlier binding")
                    end
                    names[node.rest.name] = true
                end
                return
            end

        end

        local function isLiteralValue(v)
            local t = type(v)
            if t == "string" or t == "number" or t == "boolean" then return true end
            return v == nil
        end

        local function cLit(node)   return node.value end
        local function cWild()      return P.any end
        local function cBind(node)  return P.select(node.name) end

        local function buildRefArgsGuard(args, scope, ctx)
            local n = #args
            local fields, ops, rhss = {}, {}, {}
            local env = setmetatable({}, { __index = scope })
            for i = 1, n do
                fields[i] = args[i].field
                ops[i]    = args[i].op
                rhss[i]   = evalExpr(args[i].expr, env, ctx)
            end
            return P.when(function(v)
                if type(v) ~= "table" then return false end
                for i = 1, n do
                    local l, r, op = v[fields[i]], rhss[i], ops[i]
                    local ok
                    if     op == "==" then ok = (l == r)
                    elseif op == "~=" then ok = (l ~= r)
                    elseif op == "<"  then ok = (l <  r)
                    elseif op == "<=" then ok = (l <= r)
                    elseif op == ">"  then ok = (l >  r)
                    elseif op == ">=" then ok = (l >= r)
                    end
                    if not ok then return false end
                end
                return true
            end)
        end

        local function cRef(node, scope, ctx)
            local v = scope[node.name]
            if v == nil then
                err(("scope ref '%s' not found"):format(node.name))
            end
            if node.args == nil or #node.args == 0 then
                return v
            end
            return P.intersection(v, buildRefArgsGuard(node.args, scope, ctx))
        end

        local function cInterp(node, _, ctx)
            if ctx[node.name] == nil then
                err(("$interpolation '%s' not provided in ctx"):format(node.name))
            end
            return ctx[node.name]
        end

        local function cUnion(node, scope, ctx)
            local n = #node.items
            local items, allLit = {}, true
            for i = 1, n do
                local c = compile(node.items[i], scope, ctx)
                items[i] = c
                if not isLiteralValue(c) then allLit = false end
            end
            if allLit then return P.union(tunpack(items, 1, n)) end
            return P.anyOf(tunpack(items, 1, n))
        end

        local function cInter(node, scope, ctx)
            local n = #node.items
            local items = {}
            for i = 1, n do
                items[i] = compile(node.items[i], scope, ctx)
            end
            return P.intersection(tunpack(items, 1, n))
        end

        local function cOpt(node, scope, ctx)
            return P.optional(compile(node.inner, scope, ctx))
        end

        local function cAs(node, scope, ctx)
            return P.select(node.name, compile(node.inner, scope, ctx))
        end

        local function cNot(node, scope, ctx)
            return P.not_(compile(node.inner, scope, ctx))
        end

        local function cGuard(node, scope, ctx)
            local inner = compile(node.inner, scope, ctx)
            local selects = collectSelects(inner)
            local nsel = #selects

            local env = setmetatable({}, { __index = scope })
            local expr = node.expr
            local guardFn
            if nsel == 0 then
                guardFn = function(_)
                    return evalExpr(expr, env, ctx) and true or false
                end
            else
                guardFn = function(v)
                    for i = 1, nsel do
                        local s = selects[i]
                        env[s.label or false] = readPath(v, s.path, s.n)
                    end
                    return evalExpr(expr, env, ctx) and true or false
                end
            end
            return P.intersection(inner, P.when(guardFn))
        end

        local function buildShapeRestExtractor(declaredKeys)
            local declared = {}
            for i = 1, #declaredKeys do declared[declaredKeys[i]] = true end
            return function(v)
                if type(v) ~= "table" then return nil end
                local out = {}
                for k, val in pairs(v) do
                    if not declared[k] then out[k] = val end
                end
                return out
            end
        end

        local function cShape(node, scope, ctx)
            local out = {}
            local declared = {}
            for i = 1, #node.fields do
                local f = node.fields[i]
                out[f.key] = compile(f.pattern, scope, ctx)
                declared[i] = f.key
            end
            if node.strict then

                return p.P.shape(out)
            end
            if node.rest and node.rest.name then
                return p.P.intersection(out,
                    p.P.captureSlice(node.rest.name, buildShapeRestExtractor(declared)))
            end
            return out
        end

        local function cTuple(node, scope, ctx)
            local n = #node.items
            local items = {}
            for i = 1, n do
                items[i] = compile(node.items[i], scope, ctx)
            end
            return P.tuple(tunpack(items, 1, n))
        end

        local function buildArrayTailExtractor(headLen)
            return function(v)
                if type(v) ~= "table" then return nil end
                local len = #v
                local out = {}
                for i = headLen + 1, len do out[i - headLen] = v[i] end
                return out
            end
        end

        local function buildArrayHeadExtractor(tailLen)
            return function(v)
                if type(v) ~= "table" then return nil end
                local len = #v
                local out = {}
                for i = 1, len - tailLen do out[i] = v[i] end
                return out
            end
        end

        local function cArray(node, scope, ctx)
            local rest = node.rest
            local n = #node.items
            local items = {}
            for i = 1, n do
                items[i] = compile(node.items[i], scope, ctx)
            end
            if rest == nil then
                return P.tuple(tunpack(items, 1, n))
            end

            if rest.name == nil then
                if rest.atStart then return P.endsWith(tunpack(items, 1, n)) end
                return P.startsWith(tunpack(items, 1, n))
            end

            if rest.atStart then
                return P.intersection(
                    P.endsWith(tunpack(items, 1, n)),
                    p.P.captureSlice(rest.name, buildArrayHeadExtractor(n))
                )
            end
            return P.intersection(
                P.startsWith(tunpack(items, 1, n)),
                p.P.captureSlice(rest.name, buildArrayTailExtractor(n))
            )
        end

        local DISPATCH = {
            [ast.LIT]    = cLit,
            [ast.WILD]   = cWild,
            [ast.BIND]   = cBind,
            [ast.REF]    = cRef,
            [ast.INTERP] = cInterp,
            [ast.UNION]  = cUnion,
            [ast.INTER]  = cInter,
            [ast.OPT]    = cOpt,
            [ast.AS]     = cAs,
            [ast.NOT]    = cNot,
            [ast.GUARD]  = cGuard,
            [ast.SHAPE]  = cShape,
            [ast.TUPLE]  = cTuple,
            [ast.ARRAY]  = cArray,
        }

        compile = function(node, scope, ctx)
            local fn = DISPATCH[node.kind]
            if fn == nil then err("unknown AST kind '" .. tostring(node.kind) .. "'") end
            return fn(node, scope, ctx)
        end

        function M.compile(node, scope, ctx)
            checkShadowing(node, {})
            return compile(node, scope or {}, ctx or {})
        end
        _M_dsl_comp = M
    end

    do

        local parser  = _M_dsl_parse
        local compile = _M_dsl_comp

        local M = {}

        local astCache = {}

        function M.parsePattern(src, scope, ctx)
            local node = astCache[src]
            if node == nil then
                node = parser.parse(src)
                astCache[src] = node
            end
            return compile.compile(node, scope, ctx)
        end

        function M.cacheSize()
            local n = 0
            for _ in pairs(astCache) do n = n + 1 end
            return n
        end

        function M.clearCache()
            astCache = {}
        end
        _M_parsePat = M
    end

    local p = _M_p
    local parsePatternMod = _M_parsePat
    local BigInt = _M_bigint
    local Map = _M_map
    local Set = _M_set

    return {
        P = p.P,
        isP = p.isP,
        isSelect = p.isSelect,
        buildTest = p.buildTest,

        parsePattern = parsePatternMod.parsePattern,

        BigInt = BigInt,
        Map = Map,
        Set = Set,
    }

end)()

do

    local matchigo = _M_matchigo
    local buildTest    = matchigo.buildTest
    local isP          = matchigo.isP
    local parsePattern = matchigo.parsePattern

    local M = {}

    local FALLTHROUGH = setmetatable({}, {
        __tostring = function() return "EasySwitch.FALLTHROUGH" end,
    })
    M.FALLTHROUGH = FALLTHROUGH

    local Dispatcher = {}
    Dispatcher.__index = Dispatcher
    M.Dispatcher = Dispatcher

    function M.new()
        return setmetatable({
            literals     = {},
            complex      = {},
            complexCount = 0,
            default      = nil,
        }, Dispatcher)
    end

    local function hasDSLLeadingChar(s)
        local first = s:sub(1, 1)
        return first == "{" or first == "[" or first == "(" or first == "'" or first == '"'
    end
    M.hasDSLLeadingChar = hasDSLLeadingChar

    local function isLiteralKeySafe(v)
        if v == nil then return false end
        if type(v) == "table" then return false end
        return v == v
    end

    function Dispatcher:add(cases, guard, action, scope)
        if type(action) ~= "function" then
            error("Action must be a function", 3)
        end

        if type(cases) == "string" and (scope ~= nil or hasDSLLeadingChar(cases)) then
            cases = parsePattern(cases, scope)
        end

        if isP(cases) then
            self.complexCount = self.complexCount + 1
            self.complex[self.complexCount] = {
                test = cases._test, guard = guard, action = action,
            }
            return
        end

        if type(cases) == "table" then
            local n = #cases
            if n > 0 then
                if guard ~= nil then
                    error("Guards are not supported with literal arrays", 3)
                end
                for i = 1, n do
                    self.literals[cases[i]] = action
                end
                return
            end
            self.complexCount = self.complexCount + 1
            self.complex[self.complexCount] = {
                test = buildTest(cases), guard = guard, action = action,
            }
            return
        end

        if guard == nil and isLiteralKeySafe(cases) then
            self.literals[cases] = action
            return
        end

        self.complexCount = self.complexCount + 1
        self.complex[self.complexCount] = {
            test = buildTest(cases), guard = guard, action = action,
        }
    end

    function Dispatcher:setDefault(action)
        if type(action) ~= "function" then
            error("Default action must be a function", 3)
        end
        self.default = action
    end

    function Dispatcher:execute(value)
        local everMatched = false

        local action = self.literals[value]
        if action ~= nil then
            local result = action(value)
            if result ~= FALLTHROUGH then
                return result, true
            end
            everMatched = true
        end

        local complex, n = self.complex, self.complexCount
        for i = 1, n do
            local r = complex[i]
            if r.test(value) and (r.guard == nil or r.guard(value)) then
                local result = r.action(value)
                if result ~= FALLTHROUGH then
                    return result, true
                end
                everMatched = true
            end
        end

        if self.default then
            return self.default(value), true
        end

        return nil, everMatched
    end
    _M_dispatcher = M
end

do

    local M = {}

    local EventManager = {}
    EventManager.__index = EventManager
    M.EventManager = EventManager

    local KNOWN_EVENTS = {
        beforeExecute     = true,
        afterExecute      = true,
        error             = true,
        middlewareStart   = true,
        middlewareEnd     = true,
        noMatch           = true,
        beforeCheckFailed = true,
    }
    M.KNOWN_EVENTS = KNOWN_EVENTS

    function M.new()
        return setmetatable({
            beforeExecute     = {},
            afterExecute      = {},
            error             = {},
            middlewareStart   = {},
            middlewareEnd     = {},
            noMatch           = {},
            beforeCheckFailed = {},
        }, EventManager)
    end

    function EventManager:on(event, callback)
        if not KNOWN_EVENTS[event] then
            error("Unknown event: '" .. tostring(event) .. "'", 2)
        end
        local arr = self[event]
        arr[#arr + 1] = callback
    end

    function EventManager:has(event)
        local arr = self[event]
        return arr ~= nil and #arr > 0
    end

    function EventManager:emit(event, ...)
        local arr = self[event]
        if arr == nil then return end
        local n = #arr
        if n == 0 then return end
        for i = 1, n do
            local ok, err = pcall(arr[i], ...)
            if not ok then
                print("[EasySwitch] Event error in '" .. event .. "':", err)
            end
        end
    end

    function EventManager:clear(event)
        if event then
            if self[event] then self[event] = {} end
        else
            for k in pairs(KNOWN_EVENTS) do self[k] = {} end
        end
    end
    _M_eventManager = M
end

do

    local M = {}

    local MiddlewareManager = {}
    MiddlewareManager.__index = MiddlewareManager
    M.MiddlewareManager = MiddlewareManager

    function M.new()
        return setmetatable({
            list = {},
            n    = 0,
        }, MiddlewareManager)
    end

    function MiddlewareManager:add(middleware)
        if type(middleware) ~= "function" then
            error("Middleware must be a function", 2)
        end
        self.n = self.n + 1
        self.list[self.n] = middleware
    end

    function MiddlewareManager:execute(value, events)
        local n = self.n
        if n == 0 then return value end

        if events:has("middlewareStart") then
            events:emit("middlewareStart", value)
        end

        local current, list = value, self.list
        for i = 1, n do
            local ok, result = pcall(list[i], current)
            if not ok then
                if events:has("error") then
                    events:emit("error", "middleware", result)
                end
            elseif result ~= nil then
                current = result
            end
        end

        if events:has("middlewareEnd") then
            events:emit("middlewareEnd", current)
        end

        return current
    end

    function MiddlewareManager:count()
        return self.n
    end
    _M_middlewareManager = M
end

do

    local Dispatcher        = _M_dispatcher
    local EventManager      = _M_eventManager
    local MiddlewareManager = _M_middlewareManager

    local M = {}

    local FALLTHROUGH = Dispatcher.FALLTHROUGH
    M.FALLTHROUGH = FALLTHROUGH

    local Switch = {}
    Switch.__index = Switch
    M.Switch = Switch

    function M.new(options)
        local opts = options or {}
        return setmetatable({
            _dispatcher    = Dispatcher.new(),
            _events        = EventManager.new(),
            _middleware    = MiddlewareManager.new(),
            _beforeCheck   = nil,
            _safe          = opts.safe == true,
            _cache         = nil,
            _memoizeVerify = false,
            FALLTHROUGH    = FALLTHROUGH,
        }, Switch)
    end

    local function newCache()
        return setmetatable({}, { __mode = "kv" })
    end

    local function invalidate(self)
        if self._cache ~= nil then self._cache = newCache() end
    end

    function Switch:on(event, callback)
        self._events:on(event, callback)
        return self
    end

    function Switch:when(cases, second, action)
        if type(action) == "function" then
            if type(second) == "function" then
                self._dispatcher:add(cases, second, action)
            elseif type(second) == "table" then
                self._dispatcher:add(cases, nil, action, second)
            else
                error("Switch:when : 3-arg form expects (cases, guard|scope, action)", 2)
            end
        else
            self._dispatcher:add(cases, nil, second)
        end
        invalidate(self)
        return self
    end

    function Switch:default(action)
        self._dispatcher:setDefault(action)
        invalidate(self)
        return self
    end

    function Switch:use(middleware)
        self._middleware:add(middleware)
        invalidate(self)
        return self
    end

    function Switch:before(checkFunction)
        self._beforeCheck = checkFunction
        invalidate(self)
        return self
    end

    function Switch:memoize(opts)
        opts = opts or {}
        if self._cache == nil then
            self._cache = newCache()
        end
        self._memoizeVerify = opts.verify == true
        return self
    end

    function Switch:clearCache()
        if self._cache ~= nil then
            self._cache = newCache()
        end
        return self
    end

    function Switch:_runPipelineForVerify(value)
        local check = self._beforeCheck
        if check ~= nil and not check(value) then return nil end

        local middleware = self._middleware
        local final_value
        if middleware.n == 0 then
            final_value = value
        else
            final_value = middleware:execute(value, self._events)
        end

        local dispatcher = self._dispatcher
        if self._safe then
            local ok, r = pcall(dispatcher.execute, dispatcher, final_value)
            return ok and r or nil
        end
        return (dispatcher:execute(final_value))
    end

    function Switch:execute(value)
        local events     = self._events
        local middleware = self._middleware
        local dispatcher = self._dispatcher

        if events.beforeExecute[1] ~= nil then
            events:emit("beforeExecute", value)
        end

        local cache = self._cache
        local cacheable = cache ~= nil and value ~= nil and value == value
        if cacheable then
            local cached = cache[value]
            if cached ~= nil then
                if self._memoizeVerify then
                    local fresh = self:_runPipelineForVerify(value)
                    if fresh ~= cached then
                        error(string.format(
                            "Memoize verify failed for input %s : cached=%s, action returned %s. Your action is non-deterministic ; do not enable memoize.",
                            tostring(value), tostring(cached), tostring(fresh)), 2)
                    end
                end
                if events.afterExecute[1] ~= nil then
                    events:emit("afterExecute", value, cached)
                end
                return cached
            end
        end

        local check = self._beforeCheck
        if check ~= nil and not check(value) then
            if events.beforeCheckFailed[1] ~= nil then
                events:emit("beforeCheckFailed", value)
            end
            return nil
        end

        local final_value
        if middleware.n == 0 then
            final_value = value
        else
            final_value = middleware:execute(value, events)
        end

        local result, matched
        if self._safe then
            local ok, r, m = pcall(dispatcher.execute, dispatcher, final_value)
            if not ok then
                if events.error[1] ~= nil then
                    events:emit("error", "action", r)
                end
                if events.afterExecute[1] ~= nil then
                    events:emit("afterExecute", value, nil)
                end
                return nil
            end
            result, matched = r, m
        else
            result, matched = dispatcher:execute(final_value)
        end

        if cacheable and result ~= nil then
            cache[value] = result
        end

        if not matched and events.noMatch[1] ~= nil then
            events:emit("noMatch", value)
        end

        if events.afterExecute[1] ~= nil then
            events:emit("afterExecute", value, result)
        end

        return result
    end

    function Switch:clearEvents(event)
        self._events:clear(event)
        return self
    end
    _M_switch = M
end

do

    local Switch   = _M_switch
    local matchigo = _M_matchigo

    local Map = matchigo.Map

    local M = {}

    local store = Map.new()
    M.store = store

    function M.create(name, options)
        if type(name) ~= "string" or name == "" then
            error("Registry name must be a non-empty string. Use EasySwitch.new() for anonymous switches.", 2)
        end
        if store:has(name) then
            error("Switch [" .. name .. "] is already registered", 2)
        end
        local instance = Switch.new(options)
        store:set(name, instance)
        return instance
    end

    function M.get(name)
        if name then
            return store:get(name)
        end
        if store.size == 0 then return nil, 0 end
        local result = {}
        for k, v in store:pairs() do
            result[k] = v
        end
        return result, store.size
    end

    function M.clear(name)
        if name then
            store:delete(name)
        else
            store:clear()
        end
    end
    _M_registry = M
end

local Switch   = _M_switch
local Registry = _M_registry
local matchigo = _M_matchigo

local EasySwitch = setmetatable({
    new          = Switch.new,
    P            = matchigo.P,
    parsePattern = matchigo.parsePattern,
    Map          = matchigo.Map,
    Set          = matchigo.Set,
    BigInt       = matchigo.BigInt,
    FALLTHROUGH  = Switch.FALLTHROUGH,
    get          = Registry.get,
    clear        = Registry.clear,
}, {
    __call = function(_, name, options)
        return Registry.create(name, options)
    end,
})

_G.EasySwitch = EasySwitch
return EasySwitch