package vnefall

import "core:strings"
import "core:fmt"
import vneui "vneui:src"

ui_layer_draw_menu :: proc(ctx: ^vneui.UI_Context, theme: vneui.UI_Theme, g: ^Game_State) {
    if ctx == nil || g == nil do return

    if g.menu_intro_active {
        rect := vneui.Rect{0, 0, cfg.design_width, cfg.design_height}
        if g.menu_intro_tex != 0 {
            vneui.ui_push_image(ctx, rect, int(g.menu_intro_tex), vneui.Vec2{0, 0}, vneui.Vec2{1, 1}, vneui.ui_color(1, 1, 1, 1))
        } else {
            vneui.ui_panel_color(ctx, rect, vneui.ui_color(0, 0, 0, 1))
        }
        return
    }

    bg_tex := menu_bg_tex_for_page(g)
    if bg_tex != 0 {
        tint := vneui.ui_color(1, 1, 1, menu_bg_alpha_for_page(g))
        vneui.ui_push_image(ctx, vneui.Rect{0, 0, cfg.design_width, cfg.design_height}, int(bg_tex), vneui.Vec2{0, 0}, vneui.Vec2{1, 1}, tint)
    }

    overlay := vneui.Rect{0, 0, cfg.design_width, cfg.design_height}
    vneui.ui_panel_color(ctx, overlay, vneui.ui_color(0, 0, 0, menu_overlay_alpha_for_page(g)))

    if g.menu.page == .Main {
        ui_layer_draw_start_menu(ctx, theme, g)
        return
    }
    if g.menu.page == .Settings {
        ui_layer_draw_settings_menu(ctx, theme, g)
        return
    }
    ui_layer_draw_pause_menu(ctx, theme, g)
}

ui_layer_draw_start_menu :: proc(ctx: ^vneui.UI_Context, theme: vneui.UI_Theme, g: ^Game_State) {
    start_w := menu_dim(menu_cfg.start_w, menu_cfg.start_w_pct, cfg.design_width)
    start_h := menu_dim(menu_cfg.start_h, menu_cfg.start_h_pct, cfg.design_height)
    rect := menu_start_rect(start_w, start_h)
    if menu_cfg.start_panel {
        style := vneui.ui_style_from_theme(theme)
        style.panel_color = ui_color_from_rgba(menu_panel_color_for_page(g))
        vneui.ui_panel_color_style(ctx, rect, style.panel_color, style)
    }

    layout := menu_layout_from_cfg_start(ctx)
    items := make([dynamic]vneui.UI_Menu_Item, 0, 4)
    defer delete(items)

    start_id := vneui.ui_id_from_string("menu_start")
    load_id := vneui.ui_id_from_string("menu_load")
    quit_id := vneui.ui_id_from_string("menu_quit")

    append(&items, vneui.UI_Menu_Item{id = start_id, label = menu_cfg.btn_start})
    if menu_cfg.show_load {
        append(&items, vneui.UI_Menu_Item{id = load_id, label = menu_cfg.btn_load})
    }
    if menu_cfg.show_quit {
        append(&items, vneui.UI_Menu_Item{id = quit_id, label = menu_cfg.btn_quit})
    }

    res := menu_button_list(ctx, rect, menu_cfg.start_title, items[:], layout)
    switch res.id {
    case start_id:
        menu_start_fresh(g)
        menu_close(g)
    case load_id:
        if menu_quick_load(g, menu_cfg.load_slot) {
            menu_close(g)
        } else {
            fmt.eprintln("[menu] Load failed:", menu_cfg.load_slot)
        }
    case quit_id:
        g.running = false
    }
}

ui_layer_draw_pause_menu :: proc(ctx: ^vneui.UI_Context, theme: vneui.UI_Theme, g: ^Game_State) {
    panel_w := menu_dim(menu_cfg.panel_w, menu_cfg.panel_w_pct, cfg.design_width)
    panel_h := menu_dim(menu_cfg.panel_h, menu_cfg.panel_h_pct, cfg.design_height)
    rect := menu_pause_rect(panel_w, panel_h)
    if menu_cfg.pause_panel {
        style := vneui.ui_style_from_theme(theme)
        style.panel_color = ui_color_from_rgba(menu_panel_color_for_page(g))
        vneui.ui_panel_color_style(ctx, rect, style.panel_color, style)
    }

    layout := menu_layout_from_cfg(ctx)
    items := make([dynamic]vneui.UI_Menu_Item, 0, 4)
    defer delete(items)

    resume_id := vneui.ui_id_from_string("menu_resume")
    settings_id := vneui.ui_id_from_string("menu_settings")
    quit_id := vneui.ui_id_from_string("menu_quit")

    append(&items, vneui.UI_Menu_Item{id = resume_id, label = menu_cfg.btn_resume})
    append(&items, vneui.UI_Menu_Item{id = settings_id, label = menu_cfg.btn_settings})
    if menu_cfg.show_quit {
        append(&items, vneui.UI_Menu_Item{id = quit_id, label = menu_cfg.btn_quit})
    }

    res := menu_button_list(ctx, rect, menu_cfg.pause_title, items[:], layout)
    switch res.id {
    case resume_id:
        menu_close(g)
    case settings_id:
        menu_open_settings(g)
    case quit_id:
        g.running = false
    }
}

ui_layer_draw_settings_menu :: proc(ctx: ^vneui.UI_Context, theme: vneui.UI_Theme, g: ^Game_State) {
    settings_w := menu_dim(menu_cfg.settings_w, menu_cfg.settings_w_pct, cfg.design_width)
    settings_h := menu_dim(menu_cfg.settings_h, menu_cfg.settings_h_pct, cfg.design_height)
    rect := menu_settings_rect(settings_w, settings_h)
    style := vneui.ui_style_from_theme(theme)
    style.panel_color = ui_color_from_rgba(menu_panel_color_for_page(g))
    vneui.ui_panel_color_style(ctx, rect, style.panel_color, style)

    prev := g_settings

    audio_sliders := make([dynamic]vneui.UI_Pref_Slider_Item, 0, 5)
    defer delete(audio_sliders)
    append(&audio_sliders,
        vneui.UI_Pref_Slider_Item{label = menu_cfg.label_master, value = &g_settings.volume_master, min = 0, max = 1, format = "%.2f"},
        vneui.UI_Pref_Slider_Item{label = menu_cfg.label_music, value = &g_settings.volume_music, min = 0, max = 1, format = "%.2f"},
        vneui.UI_Pref_Slider_Item{label = menu_cfg.label_ambience, value = &g_settings.volume_ambience, min = 0, max = 1, format = "%.2f"},
        vneui.UI_Pref_Slider_Item{label = menu_cfg.label_sfx, value = &g_settings.volume_sfx, min = 0, max = 1, format = "%.2f"},
        vneui.UI_Pref_Slider_Item{label = menu_cfg.label_voice, value = &g_settings.volume_voice, min = 0, max = 1, format = "%.2f"},
    )

    text_sliders := make([dynamic]vneui.UI_Pref_Slider_Item, 0, 2)
    defer delete(text_sliders)
    append(&text_sliders,
        vneui.UI_Pref_Slider_Item{label = menu_cfg.label_text_speed, value = &g_settings.text_speed, min = menu_cfg.text_speed_min, max = menu_cfg.text_speed_max, format = "%.3f"},
    )

    toggles := make([dynamic]vneui.UI_Pref_Toggle_Item, 0, 1)
    defer delete(toggles)
    append(&toggles,
        vneui.UI_Pref_Toggle_Item{label = menu_cfg.label_fullscreen, value = &g_settings.fullscreen},
    )

    sections := make([dynamic]vneui.UI_Preferences_Section, 0, 3)
    defer delete(sections)
    append(&sections,
        vneui.UI_Preferences_Section{title = menu_cfg.section_audio, sliders = audio_sliders[:]},
        vneui.UI_Preferences_Section{title = menu_cfg.section_reading, sliders = text_sliders[:]},
        vneui.UI_Preferences_Section{title = menu_cfg.section_display, toggles = toggles[:]},
    )

    prefs := vneui.UI_Preferences_Menu{
        title = menu_cfg.settings_title,
        sections = sections[:],
        show_back = true,
        show_reset = menu_cfg.show_reset,
        back_label = menu_cfg.btn_back,
        reset_label = menu_cfg.btn_reset,
    }

    lay := vneui.ui_preferences_layout_default(ctx)
    lay.padding = menu_cfg.padding
    lay.gap = menu_cfg.gap
    lay.row_h = menu_cfg.button_h
    lay.button_h = menu_cfg.button_h
    if menu_cfg.settings_label_w > 0 do lay.label_w = menu_cfg.settings_label_w
    if menu_cfg.settings_value_w > 0 do lay.value_w = menu_cfg.settings_value_w

    action := ui_preferences_menu_scroll(ctx, rect, prefs, lay)
    if action == .Reset {
        settings_reset_defaults()
    }
    if action == .Back {
        g.menu.page = .Pause
    }

    if settings_changed(prev, g_settings) {
        settings_apply_runtime(g, prev)
    }
}

menu_settings_scroll: vneui.UI_Scroll_State

ui_preferences_menu_scroll :: proc(ctx: ^vneui.UI_Context, rect: vneui.Rect, menu: vneui.UI_Preferences_Menu, layout: vneui.UI_Preferences_Layout) -> vneui.UI_Preferences_Action {
    lay := layout
    if lay.padding <= 0 do lay.padding = ctx.theme.padding
    if lay.gap <= 0 do lay.gap = ctx.theme.padding * 0.6
    if lay.row_h <= 0 do lay.row_h = ctx.theme.text_line_height + ctx.theme.padding * 1.2
    if lay.button_h <= 0 do lay.button_h = ctx.theme.text_line_height + ctx.theme.padding * 1.1

    title := menu.title
    if title == "" do title = "Preferences"
    back_label := menu.back_label
    if back_label == "" do back_label = "Back"
    reset_label := menu.reset_label
    if reset_label == "" do reset_label = "Reset"

    content_h := rect.h - lay.padding * 2
    header_h := ctx.theme.text_line_height + ctx.theme.padding * 0.5
    separator_h := ctx.theme.padding * 0.6
    footer_h: f32 = 0
    if menu.show_back || menu.show_reset {
        footer_h = lay.button_h + lay.gap
    }
    list_h := content_h - header_h - separator_h - footer_h
    if list_h < lay.row_h do list_h = lay.row_h

    vneui.ui_layout_begin(ctx, rect, .Column, lay.padding, lay.gap)
    vneui.ui_label_layout(ctx, title, 0, header_h)
    line_h: f32 = 2
    line_rect := vneui.ui_layout_next(ctx, 0, line_h)
    vneui.ui_panel_color(ctx, line_rect, ctx.theme.accent_color)
    if separator_h > line_h {
        _ = vneui.ui_layout_next(ctx, 0, separator_h - line_h)
    }

    list_rect := vneui.ui_layout_next(ctx, 0, list_h)
    scroll_opts := vneui.ui_scroll_options_default()
    scroll_opts.scrollbar_thickness = 6
    vneui.ui_scroll_begin_state(ctx, list_rect, &menu_settings_scroll, lay.gap, lay.gap)

    for i := 0; i < len(menu.sections); i += 1 {
        if i > 0 {
            vneui.ui_separator_layout(ctx, 2, 0, lay.gap)
        }
        _ = vneui.ui_preferences_section(ctx, menu.sections[i], lay)
    }

    menu_settings_scroll.scroll_y = vneui.ui_scroll_end_state(ctx, list_rect, &menu_settings_scroll, scroll_opts)

    action := vneui.UI_Preferences_Action.None
    if menu.show_back || menu.show_reset {
        row := vneui.ui_layout_next(ctx, 0, lay.button_h)
        vneui.ui_layout_begin(ctx, row, .Row, 0, lay.gap)
        button_count := 0
        if menu.show_back do button_count += 1
        if menu.show_reset do button_count += 1
        button_w: f32 = row.w
        if button_count > 0 {
            button_w = (row.w - f32(button_count-1)*lay.gap) / f32(button_count)
        }
        if menu.show_back {
            if vneui.ui_button_layout(ctx, back_label, button_w, lay.button_h) {
                action = .Back
            }
        }
        if menu.show_reset {
            if vneui.ui_button_layout(ctx, reset_label, button_w, lay.button_h) {
                action = .Reset
            }
        }
        vneui.ui_layout_end(ctx)
    }
    vneui.ui_layout_end(ctx)
    return action
}

menu_button_list :: proc(ctx: ^vneui.UI_Context, rect: vneui.Rect, title: string, items: []vneui.UI_Menu_Item, layout: vneui.UI_Menu_Layout) -> vneui.UI_Menu_Result {
    result := vneui.UI_Menu_Result{id = 0, index = -1}
    lay := layout
    if lay.padding <= 0 do lay.padding = ctx.theme.padding
    if lay.gap <= 0 do lay.gap = ctx.theme.padding * 0.6
    if lay.button_h <= 0 do lay.button_h = ctx.theme.text_line_height + ctx.theme.padding * 1.2

    vneui.ui_layout_begin(ctx, rect, .Column, lay.padding, lay.gap)
    if title != "" {
        header_h := ctx.theme.text_line_height + ctx.theme.padding * 0.5
        vneui.ui_label_layout(ctx, title, 0, header_h)
        line_rect := vneui.ui_layout_next(ctx, 0, 2)
        vneui.ui_panel_color(ctx, line_rect, ctx.theme.accent_color)
        _ = vneui.ui_layout_next(ctx, 0, ctx.theme.padding * 0.4)
    }

    for i := 0; i < len(items); i += 1 {
        item := items[i]
        if item.label == "" do continue
        id := item.id
        if id == 0 do id = vneui.ui_id_from_string(item.label)
        row := vneui.ui_layout_next(ctx, 0, lay.button_h)
        btn_w := row.w
        if lay.max_button_w > 0 && lay.max_button_w < row.w {
            btn_w = lay.max_button_w
        }
        btn_x := row.x
        switch lay.align_h {
        case .Center:
            btn_x = row.x + (row.w - btn_w) * 0.5
        case .End:
            btn_x = row.x + row.w - btn_w
        case .Start:
            btn_x = row.x
        }
        btn_rect := vneui.Rect{x = btn_x, y = row.y, w = btn_w, h = row.h}

        if item.disabled {
            disabled_color := vneui.ui_color_scale(ctx.theme.panel_color, 0.92)
            vneui.ui_panel_color(ctx, btn_rect, disabled_color)
            text_rect := btn_rect
            text_rect.x += ctx.theme.padding * 0.8
            text_rect.w -= ctx.theme.padding * 0.8
            vneui.ui_push_text_aligned(ctx, text_rect, item.label, ctx.theme.font_id, ctx.theme.font_size, vneui.ui_color_scale(ctx.theme.text_color, 0.8), .Start, .Center)
            continue
        }

        clicked := menu_button_id(ctx, id, btn_rect, item.label)
        if clicked && result.index == -1 {
            result.id = id
            result.index = i
        }
    }
    vneui.ui_layout_end(ctx)
    return result
}

menu_button_id :: proc(ctx: ^vneui.UI_Context, id: u64, rect: vneui.Rect, label: string) -> bool {
    focused := vneui.ui_focus_register(ctx, id)
    allowed := vneui.ui_input_allowed(ctx, rect)
    hovered := allowed && vneui.ui_rect_contains(rect, ctx.input.mouse_pos)
    if hovered {
        ctx.hot_id = id
        if ctx.input.mouse_pressed {
            ctx.active_id = id
            vneui.ui_focus_set(ctx, id)
            focused = true
        }
    }

    clicked := false
    if allowed && ctx.input.mouse_released {
        if ctx.active_id == id && hovered {
            clicked = true
        }
        if ctx.active_id == id {
            ctx.active_id = 0
        }
    }
    if focused && ctx.input.nav_activate {
        clicked = true
    }

    color := ctx.theme.panel_color
    if ctx.hot_id == id {
        color = vneui.ui_color_scale(color, 1.08)
    }
    if ctx.active_id == id {
        color = vneui.ui_color_scale(color, 0.92)
    }
    if focused {
        color = vneui.ui_color_scale(color, 1.05)
    }

    vneui.ui_panel_color(ctx, rect, color)
    if hovered || focused {
        bar := vneui.Rect{rect.x, rect.y, 4, rect.h}
        vneui.ui_panel_color(ctx, bar, ctx.theme.accent_color)
    }

    text_rect := rect
    text_rect.x += ctx.theme.padding * 0.8
    text_rect.w -= ctx.theme.padding * 0.8
    vneui.ui_push_text_aligned(ctx, text_rect, label, ctx.theme.font_id, ctx.theme.font_size, ctx.theme.text_color, .Start, .Center)
    return clicked
}

menu_start_fresh :: proc(g: ^Game_State) {
    if g == nil do return
    choice_clear(g)
    g.choice.active = false
    g.choice.selected = 0
    textbox_destroy(&g.textbox)
    g.textbox.visible = false
    g.textbox.speaker = ""
    g.textbox.text = ""
    g.textbox.shake = false
    g.textbox.speed_override_active = false
    g.textbox.speed_override = 0

    audio_stop_music(&g.audio)
    audio_stop_ambience(&g.audio)
    audio_stop_voice(&g.audio)
    audio_stop_sfx_all(&g.audio)
    audio_apply_settings(&g.audio)

    script_load(&g.script, cfg.entry_script)
    scene_system_cleanup()
    scene_init()
    g_scenes.current = scene_load_sync(cfg.entry_script)
    character_flush_all()
    g.current_bg = 0
    g.bg_transition.active = false

    pre_bg := ""
    for cmd in g.script.commands {
        if cmd.type == .Bg {
            pre_bg = cmd.who
            break
        }
    }
    if pre_bg != "" {
        tex := scene_get_texture(pre_bg)
        if tex != 0 {
            g.current_bg = tex
            g.loading_active = false
        } else {
            g.loading_active = true
        }
    } else {
        g.loading_active = true
    }
}

menu_quick_load :: proc(g: ^Game_State, slot: string) -> bool {
    if g == nil || slot == "" do return false
    return load_game_from_slot(g, slot)
}

menu_center_rect :: proc(w, h: f32) -> vneui.Rect {
    x := (cfg.design_width - w) * 0.5
    y := (cfg.design_height - h) * 0.5
    return vneui.Rect{x, y, w, h}
}

menu_layout_from_cfg :: proc(ctx: ^vneui.UI_Context) -> vneui.UI_Menu_Layout {
    layout := vneui.ui_menu_layout_default(ctx)
    layout.padding = menu_cfg.padding
    layout.gap = menu_cfg.gap
    layout.button_h = menu_cfg.button_h
    layout.max_button_w = menu_cfg.max_button_w
    layout.align_h = menu_align_from_cfg(menu_cfg.align_h)
    return layout
}

menu_layout_from_cfg_start :: proc(ctx: ^vneui.UI_Context) -> vneui.UI_Menu_Layout {
    layout := menu_layout_from_cfg(ctx)
    layout.align_h = menu_align_from_cfg(menu_cfg.start_align_h)
    return layout
}

menu_start_rect :: proc(w, h: f32) -> vneui.Rect {
    anchor := strings.to_lower(menu_cfg.start_anchor)
    defer delete(anchor)
    offset_x := menu_dim(menu_cfg.start_x, menu_cfg.start_x_pct, cfg.design_width)
    offset_y := menu_dim(menu_cfg.start_y, menu_cfg.start_y_pct, cfg.design_height)
    x := (cfg.design_width - w) * 0.5 + offset_x
    switch anchor {
    case "left":
        x = offset_x
    case "right":
        x = cfg.design_width - w - offset_x
    }
    y := (cfg.design_height - h) * 0.5 + offset_y
    return vneui.Rect{x, y, w, h}
}

menu_pause_rect :: proc(w, h: f32) -> vneui.Rect {
    anchor := strings.to_lower(menu_cfg.pause_anchor)
    defer delete(anchor)
    offset_x := menu_dim(menu_cfg.pause_x, menu_cfg.pause_x_pct, cfg.design_width)
    offset_y := menu_dim(menu_cfg.pause_y, menu_cfg.pause_y_pct, cfg.design_height)
    x := (cfg.design_width - w) * 0.5 + offset_x
    switch anchor {
    case "left":
        x = offset_x
    case "right":
        x = cfg.design_width - w - offset_x
    }
    y := (cfg.design_height - h) * 0.5 + offset_y
    return vneui.Rect{x, y, w, h}
}

menu_settings_rect :: proc(w, h: f32) -> vneui.Rect {
    anchor := strings.to_lower(menu_cfg.settings_anchor)
    defer delete(anchor)
    offset_x := menu_dim(menu_cfg.settings_x, menu_cfg.settings_x_pct, cfg.design_width)
    offset_y := menu_dim(menu_cfg.settings_y, menu_cfg.settings_y_pct, cfg.design_height)
    x := (cfg.design_width - w) * 0.5 + offset_x
    switch anchor {
    case "left":
        x = offset_x
    case "right":
        x = cfg.design_width - w - offset_x
    }
    y := (cfg.design_height - h) * 0.5 + offset_y
    return vneui.Rect{x, y, w, h}
}

menu_dim :: proc(value, pct, total: f32) -> f32 {
    if pct > 0 {
        return total * pct
    }
    return value
}

menu_bg_tex_for_page :: proc(g: ^Game_State) -> u32 {
    if g == nil do return 0
    switch g.menu.page {
    case .Main:
        if g.menu_bg_start_tex != 0 do return g.menu_bg_start_tex
    case .Settings:
        if g.menu_bg_settings_tex != 0 do return g.menu_bg_settings_tex
    case .Pause:
        if g.menu_bg_pause_tex != 0 do return g.menu_bg_pause_tex
    case .None:
        // fallthrough to default background
    }
    return g.menu_bg_tex
}

menu_bg_alpha_for_page :: proc(g: ^Game_State) -> f32 {
    if g == nil do return menu_cfg.menu_bg_alpha
    switch g.menu.page {
    case .Main:
        if menu_cfg.menu_bg_start_alpha > 0 do return menu_cfg.menu_bg_start_alpha
    case .Settings:
        if menu_cfg.menu_bg_settings_alpha > 0 do return menu_cfg.menu_bg_settings_alpha
    case .Pause:
        if menu_cfg.menu_bg_pause_alpha > 0 do return menu_cfg.menu_bg_pause_alpha
    case .None:
    }
    return menu_cfg.menu_bg_alpha
}

menu_overlay_alpha_for_page :: proc(g: ^Game_State) -> f32 {
    if g == nil do return menu_cfg.overlay_alpha
    switch g.menu.page {
    case .Main:
        if menu_cfg.menu_overlay_start_alpha >= 0 do return menu_cfg.menu_overlay_start_alpha
    case .Settings:
        if menu_cfg.menu_overlay_settings_alpha >= 0 do return menu_cfg.menu_overlay_settings_alpha
    case .Pause:
        if menu_cfg.menu_overlay_pause_alpha >= 0 do return menu_cfg.menu_overlay_pause_alpha
    case .None:
    }
    return menu_cfg.overlay_alpha
}

menu_panel_color_for_page :: proc(g: ^Game_State) -> [4]f32 {
    if g == nil do return menu_cfg.panel_color
    switch g.menu.page {
    case .Main:
        if menu_cfg.menu_panel_color_start_set do return menu_cfg.menu_panel_color_start
    case .Settings:
        if menu_cfg.menu_panel_color_settings_set do return menu_cfg.menu_panel_color_settings
    case .Pause:
        if menu_cfg.menu_panel_color_pause_set do return menu_cfg.menu_panel_color_pause
    case .None:
    }
    return menu_cfg.panel_color
}

menu_align_from_cfg :: proc(value: string) -> vneui.UI_Align {
    lower := strings.to_lower(value)
    defer delete(lower)
    switch lower {
    case "start": return .Start
    case "end": return .End
    }
    return .Center
}

settings_changed :: proc(a, b: Settings) -> bool {
    if a.volume_master != b.volume_master do return true
    if a.volume_music != b.volume_music do return true
    if a.volume_ambience != b.volume_ambience do return true
    if a.volume_sfx != b.volume_sfx do return true
    if a.volume_voice != b.volume_voice do return true
    if a.text_speed != b.text_speed do return true
    if a.fullscreen != b.fullscreen do return true
    return false
}

settings_apply_runtime :: proc(g: ^Game_State, prev: Settings) {
    if g == nil do return
    if prev.volume_master != g_settings.volume_master ||
       prev.volume_music != g_settings.volume_music ||
       prev.volume_ambience != g_settings.volume_ambience ||
       prev.volume_sfx != g_settings.volume_sfx ||
       prev.volume_voice != g_settings.volume_voice {
        audio_apply_settings(&g.audio)
    }

    if prev.text_speed != g_settings.text_speed {
        ui_cfg.text_speed = g_settings.text_speed
    }

    if prev.fullscreen != g_settings.fullscreen {
        window_set_fullscreen(&g.window, g_settings.fullscreen)
    }

    settings_save()
}
