<script>
    import '../styles/UserSettings.css'
    import { fly } from 'svelte/transition'
    import { X, RotateCcw, Type, Play, Palette, Eye, Globe, Check, Upload, Copy, ArrowRight } from 'lucide-svelte'
    import { useUserSettings } from './UserSettingsComponents/useUserSettings.svelte.ts'

    let { settings, onSave, onClose } = $props()

    const s = useUserSettings(() => settings, (v) => onSave(v), () => onClose())
</script>

<svelte:window onkeydown={s.handleKeydown} />

<div class="settings-backdrop" onclick={s.handleBackdrop} onkeydown={() => {}} role="dialog" aria-modal="true" tabindex="-1">
    <div class="settings-panel" in:fly={{ y: -20, duration: 200 }} out:fly={{ y: -16, duration: 120 }}>

        <!-- Header -->
        <div class="sp-header">
            <span class="sp-title">{s.t.title}</span>
            <button class="sp-close" onclick={onClose}><X size={14}/></button>
        </div>

        <!-- Layout: sidebar + content -->
        <div class="sp-layout">

            <!-- Sidebar navigation -->
            <nav class="sp-nav" aria-label="Sections">
                {#each s.SECTIONS as sec}
                    <button
                        class="sp-nav-item"
                        class:is-active={s.activeSection === sec.id}
                        onclick={() => s.activeSection = sec.id}
                        title={sec.label}
                    >
                        <sec.Icon size={15} />
                        <span class="sp-nav-label">{sec.label}</span>
                    </button>
                {/each}
            </nav>

            <!-- Content area -->
            <div class="sp-content">

                <!-- ── APPEARANCE ─────────────────────────────────── -->
                {#if s.activeSection === 'appearance'}

                    <div class="sp-section">
                        <div class="sp-label"><Palette size={12}/> {s.t.accent}</div>
                        <div class="color-preview-row">
                            <label class="color-row" for="lm-accent-picker">
                                <span class="color-swatch" style="background:{s.local.accentColor ?? '#e94560'}"></span>
                                <span class="color-hex">{s.local.accentColor ?? '#e94560'}</span>
                                <span class="color-cta">{s.t.accent_modify}</span>
                            </label>
                            <div class="color-chips">
                                <span class="chip chip-fill" style="background:{s.local.accentColor ?? '#e94560'}"></span>
                                <span class="chip chip-border" style="border-color:{s.local.accentColor ?? '#e94560'}; color:{s.local.accentColor ?? '#e94560'}">Aa</span>
                                <span class="chip chip-dim"  style="background:{s.darkenHex(s.local.accentColor ?? '#e94560')}"></span>
                            </div>
                        </div>
                        <input
                            id="lm-accent-picker"
                            type="color"
                            value={s.local.accentColor ?? '#e94560'}
                            oninput={s.handleColorInput}
                            class="color-input-hidden"
                        />
                        <p class="sp-hint">{s.t.accent_hint}</p>
                    </div>

                    <div class="sp-section">
                        <div class="sp-label">{s.t.theme_preset}</div>
                        <div class="opts-row" style="flex-wrap:wrap">
                            {#each s.THEMES as theme}
                                <button class="opt-btn" class:is-active={(s.local.themePreset ?? 'default') === theme.id}
                                    onclick={() => s.local.themePreset = theme.id}>
                                    {theme.label}
                                </button>
                            {/each}
                        </div>
                        <p class="sp-hint">{s.t.theme_hint}</p>
                    </div>

                    <div class="sp-section">
                        <div class="sp-label">{s.t.border_radius}
                            {#if s.local.borderRadius !== null && s.local.borderRadius !== undefined}
                                — {s.local.borderRadius}px
                            {:else}
                                — {s.t.border_radius_auto}
                            {/if}
                        </div>
                        {#if s.local.borderRadius !== null && s.local.borderRadius !== undefined}
                            <div class="font-row">
                                <span class="br-preview br-sharp"></span>
                                <input type="range" min="0" max="20" step="1"
                                    bind:value={s.local.borderRadius}
                                    style="--pct:{s.sliderPct(s.local.borderRadius, 0, 20)}%"
                                    class="slider" />
                                <span class="br-preview br-round"></span>
                            </div>
                            <button class="reset-btn" onclick={() => s.local.borderRadius = null}>
                                <RotateCcw size={11}/> {s.t.border_radius_reset}
                            </button>
                        {:else}
                            <button class="opt-btn" style="width:fit-content"
                                onclick={() => s.local.borderRadius = 8}>
                                {s.t.border_radius_custom}
                            </button>
                        {/if}
                        <p class="sp-hint">{s.t.border_radius_hint}</p>
                    </div>

                    <div class="sp-section">
                        <div class="sp-label">{s.t.menu_opacity} — {s.local.menuOpacity ?? 97}%</div>
                        <input type="range" min="50" max="100" step="1"
                            bind:value={s.local.menuOpacity}
                            style="--pct:{s.sliderPct(s.local.menuOpacity ?? 97, 50, 100)}%"
                            class="slider" />
                    </div>

                    <div class="sp-section">
                        <div class="sp-label">{s.t.menu_width}</div>
                        <div class="opts-col">
                            {#each [
                                { value: 'compact', label: s.t.menu_width_compact },
                                { value: 'default', label: s.t.menu_width_default },
                                { value: 'large',   label: s.t.menu_width_large },
                            ] as opt}
                                <button class="opt-btn" class:is-active={(s.local.menuWidth ?? 'default') === opt.value}
                                    onclick={() => s.local.menuWidth = opt.value}>
                                    {opt.label}
                                </button>
                            {/each}
                        </div>
                    </div>

                    <div class="sp-section">
                        <button class="sp-toggle-row" onclick={() => s.local.compactMode = !s.local.compactMode}>
                            <div class="sp-toggle-text">
                                <span class="sp-toggle-name">{s.t.compact_mode}</span>
                                <span class="sp-hint" style="margin-top:0">{s.t.compact_mode_hint}</span>
                            </div>
                            <div class="toggle-track" class:is-on={s.local.compactMode}>
                                <div class="toggle-knob"></div>
                            </div>
                        </button>
                    </div>

                    <div class="sp-section">
                        <button class="sp-toggle-row" onclick={() => s.local.blurEffects = !s.local.blurEffects}>
                            <div class="sp-toggle-text">
                                <span class="sp-toggle-name">{s.t.blur_effects}</span>
                                <span class="sp-hint" style="margin-top:0">{s.t.blur_effects_hint}</span>
                            </div>
                            <div class="toggle-track" class:is-on={s.local.blurEffects}>
                                <div class="toggle-knob"></div>
                            </div>
                        </button>
                    </div>

                    <div class="sp-section">
                        <div class="sp-label"><Type size={12}/> {s.t.font_size} — {s.local.fontSize ?? 100}%</div>
                        <div class="font-row">
                            <span class="font-sm">A</span>
                            <input type="range" min="80" max="140" step="5"
                                bind:value={s.local.fontSize}
                                style="--pct:{s.sliderPct(s.local.fontSize ?? 100, 80, 140)}%"
                                class="slider" />
                            <span class="font-lg">A</span>
                        </div>
                        <p class="sp-hint">{s.t.font_hint}</p>
                    </div>

                <!-- ── NAVIGATION ─────────────────────────────────── -->
                {:else if s.activeSection === 'navigation'}

                    <div class="sp-section">
                        <div class="sp-label">{s.t.nav_mode}</div>
                        <div class="opts-col">
                            {#each [
                                { value: 'both',     label: s.t.nav_both },
                                { value: 'mouse',    label: s.t.nav_mouse },
                                { value: 'keyboard', label: s.t.nav_kbd },
                            ] as opt}
                                <button class="opt-btn" class:is-active={s.local.navMode === opt.value}
                                    onclick={() => s.local.navMode = opt.value}>
                                    {opt.label}
                                </button>
                            {/each}
                        </div>
                        <p class="sp-hint">{s.t.nav_hint}</p>
                    </div>

                    <div class="sp-section">
                        <div class="sp-label">{s.t.target_key}</div>
                        <div class="opts-col">
                            {#each [
                                { value: 36, label: 'Left Ctrl' },
                                { value: 38, label: 'E' },
                                { value: 47, label: 'G' },
                                { value: 20, label: 'Z' },
                            ] as opt}
                                <button class="opt-btn" class:is-active={s.local.targetKey === opt.value}
                                    onclick={() => s.local.targetKey = opt.value}>
                                    {opt.label}
                                </button>
                            {/each}
                        </div>
                        <p class="sp-hint">{s.t.target_key_hint}</p>
                    </div>

                    <div class="sp-section">
                        <button class="sp-toggle-row" onclick={() => s.local.uiSounds = !s.local.uiSounds}>
                            <div class="sp-toggle-text">
                                <span class="sp-toggle-name">{s.t.ui_sounds}</span>
                                <span class="sp-hint" style="margin-top:0">{s.t.ui_sounds_hint}</span>
                            </div>
                            <div class="toggle-track" class:is-on={s.local.uiSounds}>
                                <div class="toggle-knob"></div>
                            </div>
                        </button>
                    </div>

                <!-- ── CONTEXT ─────────────────────────────────────── -->
                {:else if s.activeSection === 'context'}

                    <div class="sp-section">
                        <div class="sp-label"><Play size={12}/> {s.t.anim}</div>
                        <div class="opts-col">
                            {#each [
                                { value: 'slideLeft',  label: s.t.anim_sl },
                                { value: 'slideRight', label: s.t.anim_sr },
                                { value: 'fade',       label: s.t.anim_fade },
                                { value: 'scale',      label: s.t.anim_scale },
                                { value: 'none',       label: s.t.anim_none },
                            ] as opt}
                                <button class="opt-btn" class:is-active={s.local.animation === opt.value}
                                    onclick={() => s.local.animation = opt.value}>
                                    {opt.label}
                                </button>
                            {/each}
                        </div>
                        <p class="sp-hint">{s.t.anim_hint}</p>
                    </div>

                    <div class="sp-section">
                        <div class="sp-label">{s.t.pos_label}</div>
                        <button class="reset-btn" onclick={s.resetPosition}>
                            <RotateCcw size={11}/> {s.t.pos_reset}
                        </button>
                        <p class="sp-hint">{s.t.pos_hint}</p>
                    </div>

                <!-- ── NOTIFY ──────────────────────────────────────── -->
                {:else if s.activeSection === 'notify'}

                    <div class="sp-section">
                        <div class="sp-label">{s.t.notif_h}</div>
                        <div class="opts-row">
                            {#each [
                                { value: 'right', label: s.t.right },
                                { value: 'left',  label: s.t.left },
                            ] as opt}
                                <button class="opt-btn" class:is-active={(s.local.notifyX ?? 'right') === opt.value}
                                    onclick={() => s.local.notifyX = opt.value}>
                                    {opt.label}
                                </button>
                            {/each}
                        </div>
                    </div>

                    <div class="sp-section">
                        <div class="sp-label">{s.t.notif_v}</div>
                        <div class="opts-row">
                            {#each [
                                { value: 'bottom', label: s.t.bottom },
                                { value: 'top',    label: s.t.top },
                            ] as opt}
                                <button class="opt-btn" class:is-active={(s.local.notifyY ?? 'bottom') === opt.value}
                                    onclick={() => s.local.notifyY = opt.value}>
                                    {opt.label}
                                </button>
                            {/each}
                        </div>
                    </div>

                    <div class="sp-section">
                        <div class="sp-label">{s.t.notif_dur} — {s.local.notifyDuration ?? 4000}ms</div>
                        <input type="range" min="1500" max="10000" step="500"
                            bind:value={s.local.notifyDuration}
                            style="--pct:{s.sliderPct(s.local.notifyDuration ?? 4000, 1500, 10000)}%"
                            class="slider" />
                        <p class="sp-hint">{s.t.notif_dur_hint}</p>
                    </div>

                <!-- ── MODAL ───────────────────────────────────────── -->
                {:else if s.activeSection === 'modal'}

                    <div class="sp-section">
                        <div class="sp-label">{s.t.modal_align}</div>
                        <div class="opts-col">
                            {#each [
                                { value: 'center',        label: s.t.modal_center },
                                { value: 'top-center',    label: s.t.modal_top },
                                { value: 'bottom-center', label: s.t.modal_bottom },
                            ] as opt}
                                <button class="opt-btn" class:is-active={(s.local.modalAlign ?? 'center') === opt.value}
                                    onclick={() => s.local.modalAlign = opt.value}>
                                    {opt.label}
                                </button>
                            {/each}
                        </div>
                    </div>

                <!-- ── PROGRESS ────────────────────────────────────── -->
                {:else if s.activeSection === 'progress'}

                    <div class="sp-section">
                        <div class="sp-label">{s.t.prog_pos}</div>
                        <div class="opts-col">
                            {#each [
                                { value: 'bottom-center', label: s.t.prog_bc },
                                { value: 'top-center',    label: s.t.prog_tc },
                                { value: 'bottom-left',   label: s.t.prog_bl },
                                { value: 'bottom-right',  label: s.t.prog_br },
                            ] as opt}
                                <button class="opt-btn" class:is-active={(s.local.progressPos ?? 'bottom-center') === opt.value}
                                    onclick={() => s.local.progressPos = opt.value}>
                                    {opt.label}
                                </button>
                            {/each}
                        </div>
                    </div>

                <!-- ── ACCESSIBILITY ──────────────────────────────── -->
                {:else if s.activeSection === 'access'}

                    <div class="sp-section">
                        <div class="sp-label"><Eye size={12}/> {s.t.color_blind}</div>
                        <div class="opts-col">
                            {#each [
                                { value: 'none',         label: s.t.cb_none },
                                { value: 'deuteranopia', label: s.t.cb_deut },
                                { value: 'protanopia',   label: s.t.cb_prot },
                                { value: 'tritanopia',   label: s.t.cb_trit },
                            ] as opt}
                                <button class="opt-btn" class:is-active={(s.local.colorBlind ?? 'none') === opt.value}
                                    onclick={() => s.local.colorBlind = opt.value}>
                                    {opt.label}
                                </button>
                            {/each}
                        </div>
                        <p class="sp-hint">{s.t.color_blind_hint}</p>
                    </div>

                    <div class="sp-section">
                        <button class="sp-toggle-row" onclick={() => s.local.highContrast = !s.local.highContrast}>
                            <div class="sp-toggle-text">
                                <span class="sp-toggle-name">{s.t.high_contrast}</span>
                                <span class="sp-hint" style="margin-top:0">{s.t.high_contrast_hint}</span>
                            </div>
                            <div class="toggle-track" class:is-on={s.local.highContrast}>
                                <div class="toggle-knob"></div>
                            </div>
                        </button>
                    </div>

                    <div class="sp-section">
                        <button class="sp-toggle-row" onclick={() => s.local.reduceMotion = !s.local.reduceMotion}>
                            <div class="sp-toggle-text">
                                <span class="sp-toggle-name">{s.t.reduce_motion}</span>
                                <span class="sp-hint" style="margin-top:0">{s.t.reduce_motion_hint}</span>
                            </div>
                            <div class="toggle-track" class:is-on={s.local.reduceMotion}>
                                <div class="toggle-knob"></div>
                            </div>
                        </button>
                    </div>

                    <div class="sp-section">
                        <div class="sp-label">{s.t.line_spacing} — {(s.local.lineSpacing ?? 1.2).toFixed(1)}x</div>
                        <div class="font-row">
                            <span class="font-sm" style="line-height:1">≡</span>
                            <input type="range" min="1.0" max="2.0" step="0.1"
                                bind:value={s.local.lineSpacing}
                                style="--pct:{s.sliderPct(s.local.lineSpacing ?? 1.2, 1.0, 2.0)}%"
                                class="slider" />
                            <span class="font-lg" style="line-height:1.6">≡</span>
                        </div>
                        <p class="sp-hint">{s.t.line_spacing_hint}</p>
                    </div>

                    <div class="sp-section">
                        <div class="sp-label">{s.t.hover_delay} —
                            {#if (s.local.hoverDelay ?? 0) === 0}
                                {s.t.hover_off}
                            {:else}
                                {s.local.hoverDelay}ms
                            {/if}
                        </div>
                        <input type="range" min="0" max="600" step="50"
                            bind:value={s.local.hoverDelay}
                            style="--pct:{s.sliderPct(s.local.hoverDelay ?? 0, 0, 600)}%"
                            class="slider" />
                        <p class="sp-hint">{s.t.hover_delay_hint}</p>
                    </div>

                <!-- ── GAMEPLAY / PERFORMANCE ─────────────────────── -->
                {:else if s.activeSection === 'perf'}

                    <div class="sp-section">
                        <button class="sp-toggle-row sp-toggle-row--highlight" onclick={() => s.local.perfMode = !s.local.perfMode}>
                            <div class="sp-toggle-text">
                                <span class="sp-toggle-name">{s.t.perf_mode}</span>
                                <span class="sp-hint" style="margin-top:0">{s.t.perf_mode_hint}</span>
                            </div>
                            <div class="toggle-track" class:is-on={s.local.perfMode}>
                                <div class="toggle-knob"></div>
                            </div>
                        </button>
                    </div>

                <!-- ── LANGUAGE ────────────────────────────────────── -->
                {:else if s.activeSection === 'lang'}

                    <div class="sp-section">
                        <div class="sp-label"><Globe size={12}/> {s.t.lang_label}</div>
                        <div class="opts-col">
                            {#each s.LANGUAGES as lang}
                                <button class="opt-btn" class:is-active={(s.local.language ?? 'en') === lang.value}
                                    onclick={() => s.local.language = lang.value}>
                                    {lang.label}
                                </button>
                            {/each}
                        </div>
                        <p class="sp-hint">{s.t.lang_hint}</p>
                    </div>

                {/if}

            </div>
        </div>

        <!-- Footer -->
        <div class="sp-footer">
            <div class="sp-footer-io">
                <button class="btn-io" onclick={s.exportSettings} title={s.t.export_btn}>
                    {#if s.exportFeedback}
                        <Check size={12}/> {s.exportFeedback}
                    {:else}
                        <Copy size={12}/> {s.t.export_btn}
                    {/if}
                </button>
                <button class="btn-io" onclick={s.openImport} title={s.t.import_btn}>
                    {#if s.importFeedback}
                        <Check size={12}/> {s.importFeedback}
                    {:else}
                        <Upload size={12}/> {s.t.import_btn}
                    {/if}
                </button>
                {#if s.importError}
                    <span class="io-error">{s.importError}</span>
                {/if}
            </div>
            <div class="sp-footer-actions">
                <button class="btn-cancel" onclick={onClose}>{s.t.cancel}</button>
                <button class="btn-save"   onclick={s.handleSave}>{s.t.save}</button>
            </div>
        </div>

        <!-- ── Export overlay ───────────────────────────────────────── -->
        {#if s.exportJson !== null}
            <div class="sp-overlay" in:fly={{ y: 8, duration: 150 }} out:fly={{ y: 8, duration: 100 }}>
                <div class="ov-header">
                    <span class="ov-title">lastmenu-settings.json</span>
                    <button class="sp-close" onclick={s.closeExport}><X size={14}/></button>
                </div>
                <pre class="ov-json">{s.exportJson}</pre>
                <div class="ov-footer">
                    <button class="btn-save" onclick={s.copyExportJson}>
                        {#if s.exportCopied}
                            <Check size={12}/> Copied!
                        {:else}
                            <Copy size={12}/> Copy JSON
                        {/if}
                    </button>
                </div>
            </div>
        {/if}

        <!-- ── Import preview overlay ───────────────────────────────── -->
        {#if s.importPreview !== null}
            <div class="sp-overlay" in:fly={{ y: 8, duration: 150 }} out:fly={{ y: 8, duration: 100 }}>
                <div class="ov-header">
                    {#if s.importPreview.length > 0}
                        <span class="ov-title">{s.t.import_btn} — {s.importPreview.length} change{s.importPreview.length > 1 ? 's' : ''}</span>
                    {:else}
                        <span class="ov-title">{s.t.import_btn} — No changes</span>
                    {/if}
                </div>
                {#if s.importPreview.length > 0}
                    <div class="ov-diff">
                        {#each s.importPreview as row}
                            <div class="diff-row">
                                <span class="diff-label">{row.label}</span>
                                <span class="diff-from">{row.from}</span>
                                <ArrowRight size={10} class="diff-arrow" />
                                <span class="diff-to">{row.to}</span>
                            </div>
                        {/each}
                    </div>
                {:else}
                    <div class="ov-empty">
                        <span>The imported settings are identical to your current settings.</span>
                    </div>
                {/if}
                <div class="ov-footer">
                    <button class="btn-cancel" onclick={s.cancelImport}>{s.t.cancel}</button>
                    {#if s.importPreview.length > 0}
                        <button class="btn-save" onclick={s.applyImport}>{s.t.save}</button>
                    {/if}
                </div>
            </div>
        {/if}

    </div>
</div>
