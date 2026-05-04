-- test/regression.lua
-- Regression test suite for LastMenu.
-- Run in-game with: /lm_test  (add this file to fxmanifest client_scripts first)
-- Not loaded by default — luacheck scans it in CI without executing it.

-- ── Minimal test harness ───────────────────────────────────────────────────────

local _pass  = 0
local _fail  = 0
local _suite = ''
local _suitePass = 0
local _suiteFail = 0
local _suiteResults = {}

local function beginSuite(name)
    _suite = name
    _suitePass = 0
    _suiteFail = 0
end

local function endSuite()
    _suiteResults[#_suiteResults + 1] = {
        name = _suite, pass = _suitePass, fail = _suiteFail
    }
end

local function assert_eq(label, got, expected)
    if got == expected then
        _pass = _pass + 1; _suitePass = _suitePass + 1
    else
        _fail = _fail + 1; _suiteFail = _suiteFail + 1
        print(string.format('[LastMenu:test] FAIL  [%s] %s — expected %s, got %s',
            _suite, label, tostring(expected), tostring(got)))
    end
end

local function assert_true(label, val)  assert_eq(label, not not val, true)  end
local function assert_false(label, val) assert_eq(label, not not val, false) end

local function assert_type(label, val, expected_type)
    assert_eq(label .. ' (type)', type(val), expected_type)
end

-- Range check: asserts lo <= val <= hi (used for jitter-affected values).
local function assert_range(label, val, lo, hi)
    if type(val) == 'number' and val >= lo and val <= hi then
        _pass = _pass + 1; _suitePass = _suitePass + 1
    else
        _fail = _fail + 1; _suiteFail = _suiteFail + 1
        print(string.format('[LastMenu:test] FAIL  [%s] %s — expected [%s..%s], got %s',
            _suite, label, tostring(lo), tostring(hi), tostring(val)))
    end
end

-- ── _stableId ─────────────────────────────────────────────────────────────────

local function test_stableId()
    beginSuite('_stableId')
    local stableId = LastMenu._stableId

    -- Happy path: basic slugification
    local used = {}
    local id1 = stableId('menu1', 'Buy Weapons', 'btn', used)
    assert_eq('basic slug', id1, 'cb_menu1_buy_weapons')

    -- Collision → _2 suffix
    local id2 = stableId('menu1', 'Buy Weapons', 'btn', used)
    assert_eq('collision suffix', id2, 'cb_menu1_buy_weapons_2')

    -- Third collision → _3
    local id3 = stableId('menu1', 'Buy Weapons', 'btn', used)
    assert_eq('third collision', id3, 'cb_menu1_buy_weapons_3')

    -- Special characters stripped
    local used2 = {}
    local id4 = stableId('m', 'Hello, World!', 'btn', used2)
    assert_eq('special chars', id4, 'cb_m_hello_world')

    -- Empty label → fallback to kind
    local used3 = {}
    local id5 = stableId('m', '', 'radial', used3)
    assert_eq('empty label falls back to kind', id5, 'cb_m_radial')

    -- nil label → fallback to kind
    local used4 = {}
    local id6 = stableId('m', nil, 'tgt', used4)
    assert_eq('nil label falls back to kind', id6, 'cb_m_tgt')

    -- nil menuId → still produces a string (cb_nil_...)
    local used5 = {}
    local id7 = stableId(nil, 'action', 'btn', used5)
    assert_type('nil menuId returns string', id7, 'string')

    -- Dedup table is per-build: separate tables don't share collision counters
    local usedA, usedB = {}, {}
    local a = stableId('x', 'go', 'btn', usedA)
    local b = stableId('x', 'go', 'btn', usedB)
    assert_eq('separate used tables are independent', a, b)

    endSuite()
end

-- ── Config defaults ────────────────────────────────────────────────────────────

local function test_config()
    beginSuite('Config')
    local cfg = LastMenu.Config

    assert_false('debug default',             cfg.debug)
    assert_false('debugTarget default',       cfg.debugTarget)
    assert_eq('max_stack_depth default',      cfg.max_stack_depth, 10)
    assert_eq('target_hold_key default',      cfg.target_hold_key, 36)
    assert_eq('target_max_distance default',  cfg.target_max_distance, 10.0)
    assert_true('close_on_distance nil',      cfg.close_on_distance == nil)
    assert_true('sound_fn nil',               cfg.sound_fn == nil)

    endSuite()
end

-- ── Reactive lifecycle (attach / evaluate / stopTicking) ──────────────────────

local function test_reactive()
    beginSuite('Reactive')
    local R = LastMenu.Reactive

    -- attach registers watchers
    local fakeWatchers = {
        { id = 'w1', field = 'visible', fn = function() return true end, interval = 500 }
    }
    R.attach('__test_menu__', fakeWatchers)
    local stats = R.getStats()
    assert_true('attach registers menu',       stats['__test_menu__'] ~= nil)
    assert_eq('watcher id preserved',          stats['__test_menu__'][1].id, 'w1')
    assert_eq('watcher field preserved',       stats['__test_menu__'][1].field, 'visible')

    -- evaluate sets nextAt to 0 (forces immediate poll on next tick)
    R.evaluate('__test_menu__')
    local ws = R._watchers['__test_menu__']
    assert_true('evaluate sets nextAt=0', ws and ws[1].nextAt == 0)

    -- stopTicking cleans up
    R.stopTicking('__test_menu__')
    local stats2 = R.getStats()
    assert_false('stopTicking removes menu', stats2['__test_menu__'] ~= nil)

    -- attach with empty list is a no-op
    R.attach('__empty__', {})
    local stats3 = R.getStats()
    assert_false('empty attach is no-op', stats3['__empty__'] ~= nil)

    endSuite()
end

-- ── Reactive._processWatcher — unit tests ─────────────────────────────────────
--
-- Tests are deterministic: `now` is passed explicitly, no dependency on
-- GetGameTimer(). Every path in _processWatcher is covered.
--
-- Constants (must match reactive.lua):
--   STABLE_THRESHOLD    = 5    BACKOFF_FACTOR        = 1.5
--   BACKOFF_MAX_MULT    = 8    MAX_ERRORS            = 5
--   MAX_ZOMBIE_RETRIES  = 5    RETRY_DELAY_MS        = 30000
--   ERROR_BACKOFF_STEPS = { 1000, 2000, 4000, 8000 }  (indexed by errCount, 1-based)
-- Note: retryAt and error backoff steps include ±10% jitter — use assert_range for those.

local function test_reactiveEngine()
    beginSuite('Reactive._processWatcher')
    local R  = LastMenu.Reactive
    local pw = R._processWatcher

    assert_true('_processWatcher exists', type(pw) == 'function')
    if type(pw) ~= 'function' then endSuite() return end

    -- Helper: fresh watcher with sensible defaults
    local function W(opts)
        opts = opts or {}
        local iv = opts.interval or 100
        return {
            id               = opts.id            or 'tw',
            field            = opts.field         or 'val',
            fn               = opts.fn            or function() return 42 end,
            _menuId          = opts._menuId       or 'tm',
            interval         = iv,
            intervalCurrent  = opts.intervalCurrent or iv,
            stableCount      = opts.stableCount   or 0,
            nextAt           = opts.nextAt        or 0,
            errCount         = opts.errCount      or 0,
            disabled         = opts.disabled      or false,
            retryAt          = opts.retryAt,
            zombieRetries    = opts.zombieRetries  or 0,
            _tableWarned     = opts._tableWarned  or false,
            _debouncePending = nil,
            _debounceEmitAt  = nil,
            debounce_ms      = opts.debounce_ms,
            last             = opts.last,   -- nil by default (no previous value)
        }
    end

    -- ── 1. Not ready yet (now < nextAt) ──────────────────────────────────────
    do
        local w = W({ nextAt = 9999 })
        local b = pw(w, 100, nil)
        assert_false('notReady: no batch returned', b ~= nil)
        assert_eq('notReady: nextAt not mutated', w.nextAt, 9999)
        assert_eq('notReady: stableCount not mutated', w.stableCount, 0)
    end

    -- ── 2. First tick: nil → value → change detected ──────────────────────────
    do
        local w = W()           -- nextAt=0, last=nil, fn returns 42
        local b = pw(w, 0, nil)
        assert_true('firstTick: batch created', b ~= nil)
        assert_eq('firstTick: one entry', #b, 1)
        assert_eq('firstTick: change id', b[1].id, 'tw')
        assert_eq('firstTick: change value', b[1].val, 42)
        assert_eq('firstTick: w.last updated', w.last, 42)
        assert_eq('firstTick: stableCount=0', w.stableCount, 0)
        assert_eq('firstTick: intervalCurrent reset to base', w.intervalCurrent, 100)
        assert_true('firstTick: nextAt advanced', w.nextAt > 0)
    end

    -- ── 3. Stable tick: same value → no patch ────────────────────────────────
    do
        local w = W({ last = 42 })          -- fn returns 42 = last
        local b = pw(w, 0, nil)
        assert_false('stable: no batch', b ~= nil)
        assert_eq('stable: stableCount incremented', w.stableCount, 1)
    end

    -- ── 4. Value changed ─────────────────────────────────────────────────────
    do
        local w = W({ last = 42, fn = function() return 99 end })
        local b = pw(w, 0, nil)
        assert_true('change: batch created', b ~= nil)
        assert_eq('change: new value in patch', b[1].val, 99)
        assert_eq('change: w.last updated', w.last, 99)
        assert_eq('change: stableCount reset to 0', w.stableCount, 0)
        assert_eq('change: intervalCurrent reset to base', w.intervalCurrent, 100)
    end

    -- ── 5. Stable backoff: 1.5x multiplier after STABLE_THRESHOLD (5) ticks ──
    do
        local w = W({ last = 42, interval = 100 })
        -- ticks 1-4: stableCount goes 1→2→3→4, no backoff yet
        for _ = 1, 4 do
            w.nextAt = 0
            pw(w, 0, nil)
        end
        assert_eq('backoff: no backoff before threshold', w.intervalCurrent, 100)
        assert_eq('backoff: stableCount=4 before threshold', w.stableCount, 4)
        -- tick 5: stableCount=5 >= STABLE_THRESHOLD → backoff applies, stableCount resets
        w.nextAt = 0
        pw(w, 0, nil)
        local expected = math.min(math.floor(100 * 1.5), 100 * 8)  -- 150
        assert_eq('backoff: interval*1.5 after 5 stable ticks', w.intervalCurrent, expected)
        assert_eq('backoff: stableCount reset to 0', w.stableCount, 0)
    end

    -- ── 6. Stable backoff: cap at interval * BACKOFF_MAX_MULT (8) ────────────
    do
        local w = W({ last = 'x', interval = 100, fn = function() return 'x' end })
        -- drive to cap by running many batches of 5 stable ticks
        for _ = 1, 50 do
            w.nextAt = 0
            pw(w, 0, nil)
        end
        assert_eq('backoff cap: intervalCurrent = interval*8', w.intervalCurrent, 100 * 8)
    end

    -- ── 7. Error: intervalCurrent = ERROR_BACKOFF_STEPS[errCount] ± 10% jitter
    do
        local w = W({ fn = function() error('boom') end })
        pw(w, 0, nil)
        assert_range('errBackoff: step[1] in [900..1100]', w.intervalCurrent, 900, 1100)
        assert_eq('errBackoff: errCount=1', w.errCount, 1)
        assert_eq('errBackoff: nextAt advanced', w.nextAt, 0 + w.intervalCurrent)
    end

    -- ── 8. Error backoff: last step used when errCount >= len(STEPS) ─────────
    do
        local w = W({ fn = function() error('x') end, interval = 100 })
        -- 4 errors: steps ≈1000 → ≈2000 → ≈4000 → ≈8000 (±10% jitter each)
        for _ = 1, 4 do
            w.nextAt = 0
            pw(w, 0, nil)
        end
        assert_range('errBackoff lastStep: intervalCurrent in [7200..8800]', w.intervalCurrent, 7200, 8800)
        assert_eq('errBackoff lastStep: errCount=4', w.errCount, 4)
    end

    -- ── 9. Safe-mode: 5 consecutive errors → disabled ────────────────────────
    do
        local w = W({ fn = function() error('fail') end })
        for i = 1, 4 do
            w.nextAt = 0
            pw(w, 0, nil)
            assert_false('safeMode: not disabled after ' .. i .. ' error(s)', w.disabled)
        end
        -- error 5 → disabled
        w.nextAt = 0
        pw(w, 0, nil)
        assert_true('safeMode: disabled after 5 errors', w.disabled)
        assert_true('safeMode: retryAt set', w.retryAt ~= nil)
        assert_range('safeMode: retryAt in [now+27000..now+33000]', w.retryAt, 27000, 33000)
        assert_eq('safeMode: errCount=5', w.errCount, 5)
        assert_eq('safeMode: zombieRetries=1', w.zombieRetries, 1)
    end

    -- ── 10. Disabled watcher: skipped when now < retryAt ─────────────────────
    do
        local called = false
        local w = W({ disabled = true, retryAt = 9999,
                       fn = function() called = true; return 1 end })
        local b = pw(w, 100, nil)
        assert_false('disabled: no batch', b ~= nil)
        assert_false('disabled: fn not called', called)
        assert_true('disabled: still disabled', w.disabled)
    end

    -- ── 11. Recovery: re-enables when now >= retryAt ─────────────────────────
    -- retryAt is set externally (simulating a previously jittered value).
    do
        local w = W({ disabled = true, retryAt = 5000, zombieRetries = 1 })
        -- one tick before recovery threshold
        pw(w, 4999, nil)
        assert_true('recovery: still disabled at 4999', w.disabled)
        -- exact threshold
        pw(w, 5000, nil)
        assert_false('recovery: re-enabled at 5000', w.disabled)
        assert_eq('recovery: errCount reset to 0', w.errCount, 0)
        assert_false('recovery: retryAt cleared', w.retryAt ~= nil)
    end

    -- ── 12. Recovery: watcher fires on the same tick as recovery ─────────────
    do
        local called = false
        local w = W({ disabled = true, retryAt = 5000, zombieRetries = 1,
                       fn = function() called = true; return 1 end })
        -- nextAt=0, now=5000: recovery happens, then now(5000) > nextAt(0) → fires
        pw(w, 5000, nil)
        assert_true('recovery: fn called on recovery tick', called)
    end

    -- ── 13. Recovery: watcher does NOT fire if nextAt is in the future ────────
    do
        local called = false
        local w = W({ disabled = true, retryAt = 5000, nextAt = 16000, zombieRetries = 1,
                       fn = function() called = true; return 1 end })
        pw(w, 5000, nil)
        assert_false('recovery futurNextAt: re-enabled', w.disabled)
        assert_false('recovery futurNextAt: fn not called (nextAt still future)', called)
    end

    -- ── 14. errCount resets on next successful evaluation ────────────────────
    do
        local calls = 0
        local w = W({ fn = function()
            calls = calls + 1
            if calls < 2 then error('fail') end
            return 'ok'
        end })
        pw(w, 0, nil)           -- error, errCount=1
        w.nextAt = 0
        pw(w, 0, nil)           -- success, errCount should reset
        assert_eq('errReset: errCount=0 after success', w.errCount, 0)
    end

    -- ── 15. intervalCurrent resets to base on value change (even if backed off)
    do
        local val = 'a'
        local w = W({ fn = function() return val end, interval = 100,
                       last = 'a', intervalCurrent = 700 })
        val = 'b'
        pw(w, 0, nil)
        assert_eq('intervalReset: reset to base on change', w.intervalCurrent, 100)
    end

    -- ── 16. Table value: _tableWarned fires on first table return ─────────────
    do
        local w = W({ fn = function() return {} end })
        pw(w, 0, nil)
        assert_true('tableWarn: _tableWarned set on first table', w._tableWarned)
    end

    -- ── 17. Table value: _tableWarned is NOT reset (fires only once) ──────────
    do
        local w = W({ fn = function() return {} end })
        pw(w, 0, nil)
        w.nextAt = 0
        pw(w, 0, nil)           -- second table → no second print
        assert_true('tableWarn: still true on second table', w._tableWarned)
    end

    -- ── 18. Batch accumulation: two watchers, one call each ───────────────────
    do
        local w1 = W({ id = 'w1', field = 'hp',   fn = function() return 80 end })
        local w2 = W({ id = 'w2', field = 'ammo', fn = function() return 30 end })
        local b = pw(w1, 0, nil)
        b = pw(w2, 0, b)
        assert_eq('batchAccum: 2 entries', #b, 2)
        assert_eq('batchAccum: first entry id',    b[1].id, 'w1')
        assert_eq('batchAccum: first entry value', b[1].hp, 80)
        assert_eq('batchAccum: second entry id',   b[2].id, 'w2')
        assert_eq('batchAccum: second entry value',b[2].ammo, 30)
    end

    -- ── 19. Batch passed in: existing entries are preserved ───────────────────
    do
        local w = W({ id = 'w3', field = 'score' })
        local existing = { { id = 'prev', foo = 1 } }
        local b = pw(w, 0, existing)
        assert_eq('batchPreserve: length=2', #b, 2)
        assert_eq('batchPreserve: first entry untouched', b[1].id, 'prev')
        assert_eq('batchPreserve: new entry appended', b[2].id, 'w3')
    end

    -- ── 20. No batch when watcher is already stable (existing batch preserved) -
    do
        local w = W({ last = 42 })
        local existing = { { id = 'other', x = 7 } }
        local b = pw(w, 0, existing)
        -- no change from this watcher, but existing batch passed through
        assert_eq('noChangeBatch: existing batch returned as-is', #b, 1)
        assert_eq('noChangeBatch: existing entry intact', b[1].id, 'other')
    end

    -- ── 21. Zombie exhaustion: permanently dead after MAX_ZOMBIE_RETRIES ──────
    do
        local w = W({ fn = function() error('always fails') end })
        -- Drive through MAX_ZOMBIE_RETRIES (5) full disable cycles.
        for cycle = 1, 5 do
            -- Trigger 5 errors to disable the watcher.
            for _ = 1, 5 do
                w.nextAt = 0
                pw(w, 0, nil)
            end
            assert_true('zombie: disabled after cycle ' .. cycle, w.disabled)
            if cycle < 5 then
                assert_true('zombie: retryAt still set at cycle ' .. cycle, w.retryAt ~= nil)
                -- Simulate recovery tick.
                w.nextAt = 0
                pw(w, w.retryAt, nil)
                assert_false('zombie: re-enabled at cycle ' .. cycle, w.disabled)
                assert_eq('zombie: errCount reset at cycle ' .. cycle, w.errCount, 0)
            end
        end
        -- After 5th disable, retryAt must be nil (permanently dead).
        assert_false('zombie: retryAt nil after exhaustion', w.retryAt ~= nil)
        assert_eq('zombie: zombieRetries=5', w.zombieRetries, 5)
        -- Further ticks must not re-enable it.
        pw(w, 999999, nil)
        assert_true('zombie: stays dead after exhaustion', w.disabled)
    end

    -- ── 22. Debounce: patch deferred until silence window elapses ─────────────
    do
        local val = 10
        local w = W({ fn = function() return val end, debounce_ms = 200 })
        -- First change (nil → 10): should NOT emit patch immediately.
        local b1 = pw(w, 0, nil)
        assert_false('debounce: no patch on change within window', b1 ~= nil)
        assert_eq('debounce: last updated', w.last, 10)
        assert_true('debounce: pending set', w._debouncePending == 10)
        assert_eq('debounce: emitAt = now + debounce_ms', w._debounceEmitAt, 200)
        -- Before window elapses: still no patch.
        w.nextAt = 0
        local b2 = pw(w, 100, nil)
        assert_false('debounce: no patch before window', b2 ~= nil)
        -- Value changes again — timer resets.
        val = 99
        w.nextAt = 0
        local b3 = pw(w, 150, nil)
        assert_false('debounce: no patch on second change', b3 ~= nil)
        assert_eq('debounce: pending updated to new value', w._debouncePending, 99)
        assert_eq('debounce: emitAt reset', w._debounceEmitAt, 150 + 200)
        -- After silence window: flush.
        w.nextAt = 0
        local b4 = pw(w, 350, nil)  -- 350 >= 350 (150 + 200)
        assert_true('debounce: patch emitted after window', b4 ~= nil)
        assert_eq('debounce: flushed value = last seen', b4 and b4[1] and b4[1].val, 99)
        assert_false('debounce: pending cleared', w._debouncePending ~= nil)
        assert_false('debounce: emitAt cleared', w._debounceEmitAt ~= nil)
    end

    endSuite()
end

-- ── Reactive → Bridge integration ─────────────────────────────────────────────

local function test_reactiveIntegration()
    beginSuite('Reactive_Bridge_integration')
    local R      = LastMenu.Reactive
    local Bridge = LastMenu.Bridge

    -- ── Mock Bridge.send so we can inspect calls without NUI ─────────────────
    local sent     = {}
    local origSend = Bridge.send
    Bridge.send    = function(msgType, payload)
        sent[#sent + 1] = { msgType = msgType, payload = payload }
    end

    local ok, err = pcall(function()

        local val = 10
        R.attach('__integ__', {
            { id = 'iw1', field = 'score',
              fn = function() return val end, interval = 100 }
        })
        local ws = R._watchers['__integ__']
        assert_true('integ: watcher registered', ws ~= nil)

        local w = ws[1]

        -- ── tick 1: first evaluation, change nil→10 ─────────────────────────
        local batch = R._processWatcher(w, 0, nil)
        assert_true('integ: batch on first tick', batch ~= nil)
        if batch then
            Bridge.send('patch', { id = '__integ__', changes = batch })
        end
        assert_eq('integ: Bridge.send called once', #sent, 1)
        assert_eq('integ: message type = patch', sent[1].msgType, 'patch')
        assert_eq('integ: menu id', sent[1].payload.id, '__integ__')
        assert_eq('integ: changes count = 1', #sent[1].payload.changes, 1)
        assert_eq('integ: field value = 10', sent[1].payload.changes[1].score, 10)

        -- ── tick 2: same value → no patch ───────────────────────────────────
        w.nextAt = 0
        local batch2 = R._processWatcher(w, 0, nil)
        assert_false('integ: no batch on stable tick', batch2 ~= nil)
        assert_eq('integ: Bridge.send still called only once', #sent, 1)

        -- ── tick 3: value changes → new patch ───────────────────────────────
        val = 99
        w.nextAt = 0
        local batch3 = R._processWatcher(w, 0, nil)
        assert_true('integ: batch on value change', batch3 ~= nil)
        if batch3 then
            Bridge.send('patch', { id = '__integ__', changes = batch3 })
        end
        assert_eq('integ: Bridge.send called twice total', #sent, 2)
        assert_eq('integ: updated value = 99', sent[2].payload.changes[1].score, 99)

        -- ── tick 4: error path → no patch, errCount increments ───────────────
        w.fn = function() error('injected error') end
        w.nextAt = 0
        local batch4 = R._processWatcher(w, 0, nil)
        assert_false('integ: no patch on error', batch4 ~= nil)
        assert_eq('integ: errCount=1 after error', w.errCount, 1)
        assert_eq('integ: Bridge.send not called on error', #sent, 2)

        -- ── tick 5: safe-mode reached after 5 errors ─────────────────────────
        w.nextAt = 0; R._processWatcher(w, 0, nil)  -- error 2
        w.nextAt = 0; R._processWatcher(w, 0, nil)  -- error 3
        w.nextAt = 0; R._processWatcher(w, 0, nil)  -- error 4
        w.nextAt = 0; R._processWatcher(w, 0, nil)  -- error 5 → disabled
        assert_true('integ: disabled after 5 errors', w.disabled)
        assert_true('integ: retryAt set', w.retryAt ~= nil)
        assert_range('integ: retryAt in [27000..33000]', w.retryAt, 27000, 33000)
        assert_eq('integ: zombieRetries=1', w.zombieRetries, 1)

        -- ── tick 6: recovery at retryAt, fn fixed → fires again ─────────────
        w.fn = function() return 55 end
        local recoveryAt = w.retryAt   -- use exact jittered value
        local batch5 = R._processWatcher(w, recoveryAt, nil)  -- now = retryAt
        assert_false('integ: re-enabled after recovery', w.disabled)
        assert_true('integ: batch on recovery tick', batch5 ~= nil)
        if batch5 then
            Bridge.send('patch', { id = '__integ__', changes = batch5 })
        end
        assert_eq('integ: Bridge.send after recovery', #sent, 3)
        assert_eq('integ: recovery patch value = 55', sent[3].payload.changes[1].score, 55)

    end)

    -- Cleanup: always restore Bridge.send and remove test watcher
    R.stopTicking('__integ__')
    Bridge.send = origSend

    if not ok then
        _fail = _fail + 1; _suiteFail = _suiteFail + 1
        print('[LastMenu:test] FAIL  [Reactive_Bridge_integration] unexpected error: ' .. tostring(err))
    end

    endSuite()
end

-- ── Stack (via public interface) ───────────────────────────────────────────────

local function test_stack()
    beginSuite('Stack')
    local S = LastMenu.Stack

    -- peek on empty stack
    assert_false('peek on empty stack', S.peek())

    -- Direct internal manipulation to avoid NUI side effects.
    -- Stack.push() calls SetNuiFocus and TriggerEvent which require a live game session.
    -- We test the data layer, not the focus/event layer.
    local prev = #S._entries
    table.insert(S._entries, { id = '__test_e1__', type = 'context', cancelable = false })
    assert_eq('entry count after insert',   #S._entries, prev + 1)

    local top = S.peek()
    assert_true('peek returns entry',       top ~= nil)
    assert_eq('peek type field',            top.type, 'context')
    assert_eq('peek id field',              top.id, '__test_e1__')
    assert_false('peek cancelable field',   top.cancelable)

    -- Push a second entry and verify peek returns the latest
    table.insert(S._entries, { id = '__test_e2__', type = 'radial', cancelable = true })
    assert_eq('peek after second insert id', S.peek().id, '__test_e2__')

    -- Clean up both entries
    table.remove(S._entries)
    table.remove(S._entries)
    assert_false('empty after cleanup', S.peek())

    endSuite()
end

-- ── Target registrations ───────────────────────────────────────────────────────

local function test_target()
    beginSuite('Target')
    local T = LastMenu.Target

    -- addSphere happy path
    local id = T.addSphere(vector3(0, 0, 0), 5.0, { label = 'Test zone', actions = {} })
    assert_type('addSphere returns string id', id, 'string')
    local reg = T._registrations[id]
    assert_true('registration exists',    reg ~= nil)
    assert_eq('type field',               reg.type, 'sphere')
    assert_eq('radius field',             reg.radius, 5.0)
    assert_eq('label field',              reg.label, 'Test zone')
    assert_true('actions is table',       type(reg.actions) == 'table')

    -- addSphere with no label uses default
    local id2 = T.addSphere(vector3(0, 0, 0), 2.0, {})
    assert_eq('default label', T._registrations[id2].label, 'Interact')

    -- update() patches only supplied fields
    T.update(id, { label = 'Updated', radius = 8.0 })
    local reg2 = T._registrations[id]
    assert_eq('update patches label',  reg2.label, 'Updated')
    assert_eq('update patches radius', reg2.radius, 8.0)
    assert_eq('update keeps type',     reg2.type, 'sphere')

    -- update() on a non-existent id is a no-op (no crash)
    local ok = pcall(T.update, '__nonexistent__', { label = 'x' })
    assert_true('update on bad id does not crash', ok)

    -- remove cleans up
    T.remove(id)
    assert_false('remove deletes registration', T._registrations[id] ~= nil)

    -- remove non-existent id is a no-op
    local ok2 = pcall(T.remove, '__nonexistent__')
    assert_true('remove on bad id does not crash', ok2)

    -- addSphere with zero radius (edge case)
    local id3 = T.addSphere(vector3(0, 0, 0), 0.0, {})
    assert_eq('zero radius stored', T._registrations[id3].radius, 0.0)
    T.remove(id3)
    T.remove(id2)

    endSuite()
end

-- ── Entry point ───────────────────────────────────────────────────────────────

function RunLastMenuTests()
    _pass, _fail, _suiteResults = 0, 0, {}
    print('[LastMenu:test] ── Running regression suite ────────────────────')

    local suites = {
        { name = '_stableId',                 fn = test_stableId            },
        { name = 'Config',                    fn = test_config              },
        { name = 'Reactive',                  fn = test_reactive            },
        { name = 'Reactive._processWatcher',  fn = test_reactiveEngine      },
        { name = 'Reactive_Bridge',           fn = test_reactiveIntegration },
        { name = 'Stack',                     fn = test_stack               },
        { name = 'Target',                    fn = test_target              },
    }

    for _, suite in ipairs(suites) do
        local ok, err = pcall(suite.fn)
        if not ok then
            _fail = _fail + 1
            print(string.format('[LastMenu:test] ERROR in suite "%s": %s', suite.name, tostring(err)))
            _suiteResults[#_suiteResults + 1] = { name = suite.name, pass = 0, fail = 1 }
        end
    end

    -- Per-suite summary
    print('[LastMenu:test] ── Results by suite ──────────────────────────────')
    for _, r in ipairs(_suiteResults) do
        local status = r.fail > 0 and 'FAIL' or 'ok'
        print(string.format('[LastMenu:test]   %-32s %d/%d  %s',
            r.name, r.pass, r.pass + r.fail, status))
    end

    -- Total
    local total = _pass + _fail
    print(string.format('[LastMenu:test] ────────────────────────────────────────────────'))
    print(string.format('[LastMenu:test] %d/%d passed%s',
        _pass, total, _fail > 0 and (' — ' .. _fail .. ' FAILED') or ' ✓'))
end
RunLastMenuTests()