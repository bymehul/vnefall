package vnefall

import "core:strings"
import "core:fmt"
import "core:os"
import "core:math"
import vneui "vneui:src"

ui_layer_draw_menu :: proc(ctx: ^vneui.UI_Context, theme: vneui.UI_Theme, g: ^Game_State) {
    if ctx == nil || g == nil do return

    if g.menu_intro_active {
        rect := vneui.Rect{0, 0, cfg.design_width, cfg.design_height}
        if menu_cfg.menu_intro_float && menu_cfg.menu_intro_float_px > 0 {
            dx, dy, pad := menu_float_offset(ctx.time, menu_cfg.menu_intro_float_px, menu_cfg.menu_intro_float_speed)
            rect = vneui.Rect{-pad + dx, -pad + dy, cfg.design_width + pad*2, cfg.design_height + pad*2}
        }
        if g.menu_intro_tex != 0 {
            vneui.ui_push_image(ctx, rect, int(g.menu_intro_tex), vneui.Vec2{0, 0}, vneui.Vec2{1, 1}, vneui.ui_color(1, 1, 1, 1))
        } else {
            vneui.ui_panel_color(ctx, rect, vneui.ui_color(0, 0, 0, 1))
        }
        return
    }

    if g.menu.page == .Main {
        ui_layer_draw_start_menu(ctx, theme, g)
        return
    }
    if g.menu.page == .Settings {
        ui_layer_draw_settings_menu(ctx, theme, g)
        return
    }
    if g.menu.page == .Save {
        ui_layer_draw_save_menu(ctx, theme, g)
        return
    }
    if g.menu.page == .Load {
        ui_layer_draw_load_menu(ctx, theme, g)
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
    menu_draw_blocks(ctx, g)

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

    title_scale := menu_scale_value(menu_cfg.menu_title_scale, menu_cfg.menu_title_scale_start)
    item_scale := menu_scale_value(menu_cfg.menu_item_scale, menu_cfg.menu_item_scale_start)
    res := menu_button_list(ctx, rect, menu_cfg.start_title, items[:], layout, menu_button_style_for_start(), title_scale, item_scale)
    switch res.id {
    case start_id:
        menu_start_fresh(g)
        menu_close(g)
    case load_id:
        menu_open_load(g, .Main)
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
    menu_draw_blocks(ctx, g)

    layout := menu_layout_from_cfg(ctx)
    items := make([dynamic]vneui.UI_Menu_Item, 0, 4)
    defer delete(items)

    resume_id := vneui.ui_id_from_string("menu_resume")
    save_id := vneui.ui_id_from_string("menu_save")
    load_id := vneui.ui_id_from_string("menu_load")
    settings_id := vneui.ui_id_from_string("menu_settings")
    quit_id := vneui.ui_id_from_string("menu_quit")

    append(&items, vneui.UI_Menu_Item{id = resume_id, label = menu_cfg.btn_resume})
    if menu_cfg.show_save {
        append(&items, vneui.UI_Menu_Item{id = save_id, label = menu_cfg.btn_save})
    }
    if menu_cfg.show_load {
        append(&items, vneui.UI_Menu_Item{id = load_id, label = menu_cfg.btn_load})
    }
    append(&items, vneui.UI_Menu_Item{id = settings_id, label = menu_cfg.btn_settings})
    if menu_cfg.show_quit {
        append(&items, vneui.UI_Menu_Item{id = quit_id, label = menu_cfg.btn_quit})
    }

    title_scale := menu_scale_value(menu_cfg.menu_title_scale, menu_cfg.menu_title_scale_pause)
    item_scale := menu_scale_value(menu_cfg.menu_item_scale, menu_cfg.menu_item_scale_pause)
    res := menu_button_list(ctx, rect, menu_cfg.pause_title, items[:], layout, menu_button_style_for_pause(), title_scale, item_scale)
    switch res.id {
    case resume_id:
        menu_close(g)
    case save_id:
        menu_open_save(g, .Pause)
    case load_id:
        menu_open_load(g, .Pause)
    case settings_id:
        menu_open_settings(g)
    case quit_id:
        g.running = false
    }
}

SAVE_PAGE_COUNT :: 10
SAVE_SLOTS_PER_PAGE :: 6

ui_layer_draw_save_menu :: proc(ctx: ^vneui.UI_Context, theme: vneui.UI_Theme, g: ^Game_State) {
    save_w := menu_dim(menu_cfg.save_w, menu_cfg.save_w_pct, cfg.design_width)
    save_h := menu_dim(menu_cfg.save_h, menu_cfg.save_h_pct, cfg.design_height)
    rect := menu_save_rect(save_w, save_h)
    if menu_cfg.save_panel {
        style := vneui.ui_style_from_theme(theme)
        style.panel_color = ui_color_from_rgba(menu_panel_color_for_page(g))
        vneui.ui_panel_color_style(ctx, rect, style.panel_color, style)
    }
    menu_draw_blocks(ctx, g)

    // Page controls
    layout := vneui.ui_save_list_layout_default(ctx)
    layout.padding = menu_cfg.padding
    layout.gap = menu_cfg.gap
    if layout.slot_h <= 0 do layout.slot_h = theme.text_line_height * 2.4 + theme.padding * 1.2

    slots := menu_build_save_slots(g.menu.save_page, .Save)
    defer menu_free_save_slots(&slots)

    cfg_save := vneui.UI_Save_List_Config{
        title = menu_cfg.save_title,
        mode = .Save,
        show_back = false,
        back_label = menu_cfg.btn_back,
    }
    res := vneui.ui_save_list_menu(ctx, rect, slots[:], cfg_save, layout, &g.save_list_state)
    if res.action == .Select && res.index >= 0 {
        slot_name := menu_save_slot_name(g.menu.save_page, res.index)
        defer delete(slot_name)
        _ = save_game_to_slot(g, &g.script, slot_name)
    }

    // Page + Back footer
    footer_h := layout.button_h
    footer_rect := vneui.Rect{rect.x, rect.y + rect.h - footer_h - layout.padding, rect.w - layout.padding * 2, footer_h}
    vneui.ui_layout_begin(ctx, footer_rect, .Row, 0, layout.gap)
    prev_label := "< Prev"
    next_label := "Next >"
    page_label := fmt.aprintf("Page %d / %d", g.menu.save_page+1, SAVE_PAGE_COUNT)
    defer delete(page_label)
    btn_w := (footer_rect.w - layout.gap*3) * 0.2
    if btn_w < 80 do btn_w = 80
    if vneui.ui_button_layout(ctx, prev_label, btn_w, layout.button_h) {
        if g.menu.save_page > 0 do g.menu.save_page -= 1
    }
    vneui.ui_label_layout(ctx, page_label, footer_rect.w - btn_w*3 - layout.gap*2, layout.button_h)
    if vneui.ui_button_layout(ctx, menu_cfg.btn_back, btn_w, layout.button_h) {
        if g.menu.return_page != .None {
            g.menu.page = g.menu.return_page
        } else {
            menu_open_pause(g)
        }
    }
    if vneui.ui_button_layout(ctx, next_label, btn_w, layout.button_h) {
        if g.menu.save_page < SAVE_PAGE_COUNT-1 do g.menu.save_page += 1
    }
    vneui.ui_layout_end(ctx)
}

ui_layer_draw_load_menu :: proc(ctx: ^vneui.UI_Context, theme: vneui.UI_Theme, g: ^Game_State) {
    load_w := menu_dim(menu_cfg.save_w, menu_cfg.save_w_pct, cfg.design_width)
    load_h := menu_dim(menu_cfg.save_h, menu_cfg.save_h_pct, cfg.design_height)
    rect := menu_save_rect(load_w, load_h)
    if menu_cfg.save_panel {
        style := vneui.ui_style_from_theme(theme)
        style.panel_color = ui_color_from_rgba(menu_panel_color_for_page(g))
        vneui.ui_panel_color_style(ctx, rect, style.panel_color, style)
    }
    menu_draw_blocks(ctx, g)

    layout := vneui.ui_save_list_layout_default(ctx)
    layout.padding = menu_cfg.padding
    layout.gap = menu_cfg.gap
    if layout.slot_h <= 0 do layout.slot_h = theme.text_line_height * 2.4 + theme.padding * 1.2

    slots := menu_build_save_slots(g.menu.save_page, .Load)
    defer menu_free_save_slots(&slots)

    title := menu_cfg.load_title
    if title == "" do title = "Load"
    cfg_save := vneui.UI_Save_List_Config{
        title = title,
        mode = .Load,
        show_back = false,
        back_label = menu_cfg.btn_back,
    }
    res := vneui.ui_save_list_menu(ctx, rect, slots[:], cfg_save, layout, &g.save_list_state)
    if res.action == .Select && res.index >= 0 {
        slot_name := menu_save_slot_name(g.menu.save_page, res.index)
        defer delete(slot_name)
        if load_game_from_slot(g, slot_name) {
            menu_close(g)
        } else {
            fmt.eprintln("[menu] Load failed:", slot_name)
        }
    }

    footer_h := layout.button_h
    footer_rect := vneui.Rect{rect.x, rect.y + rect.h - footer_h - layout.padding, rect.w - layout.padding * 2, footer_h}
    vneui.ui_layout_begin(ctx, footer_rect, .Row, 0, layout.gap)
    prev_label := "< Prev"
    next_label := "Next >"
    page_label := fmt.aprintf("Page %d / %d", g.menu.save_page+1, SAVE_PAGE_COUNT)
    defer delete(page_label)
    btn_w := (footer_rect.w - layout.gap*3) * 0.2
    if btn_w < 80 do btn_w = 80
    if vneui.ui_button_layout(ctx, prev_label, btn_w, layout.button_h) {
        if g.menu.save_page > 0 do g.menu.save_page -= 1
    }
    vneui.ui_label_layout(ctx, page_label, footer_rect.w - btn_w*3 - layout.gap*2, layout.button_h)
    if vneui.ui_button_layout(ctx, menu_cfg.btn_back, btn_w, layout.button_h) {
        if g.menu.return_page != .None {
            g.menu.page = g.menu.return_page
        } else {
            menu_open_pause(g)
        }
    }
    if vneui.ui_button_layout(ctx, next_label, btn_w, layout.button_h) {
        if g.menu.save_page < SAVE_PAGE_COUNT-1 do g.menu.save_page += 1
    }
    vneui.ui_layout_end(ctx)
}

ui_layer_draw_settings_menu :: proc(ctx: ^vneui.UI_Context, theme: vneui.UI_Theme, g: ^Game_State) {
    settings_w := menu_dim(menu_cfg.settings_w, menu_cfg.settings_w_pct, cfg.design_width)
    settings_h := menu_dim(menu_cfg.settings_h, menu_cfg.settings_h_pct, cfg.design_height)
    rect := menu_settings_rect(settings_w, settings_h)
    style := vneui.ui_style_from_theme(theme)
    style.panel_color = ui_color_from_rgba(menu_panel_color_for_page(g))
    vneui.ui_panel_color_style(ctx, rect, style.panel_color, style)
    menu_draw_blocks(ctx, g)

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

menu_button_list :: proc(ctx: ^vneui.UI_Context, rect: vneui.Rect, title: string, items: []vneui.UI_Menu_Item, layout: vneui.UI_Menu_Layout, style: Menu_Button_Style, title_scale: f32, item_scale: f32) -> vneui.UI_Menu_Result {
    result := vneui.UI_Menu_Result{id = 0, index = -1}
    lay := layout
    if lay.padding <= 0 do lay.padding = ctx.theme.padding
    if lay.gap <= 0 do lay.gap = ctx.theme.padding * 0.6
    if lay.button_h <= 0 do lay.button_h = ctx.theme.text_line_height + ctx.theme.padding * 1.2

    vneui.ui_layout_begin(ctx, rect, .Column, lay.padding, lay.gap)
    title_size := ctx.theme.font_size * title_scale
    item_size := ctx.theme.font_size * item_scale
    min_h := item_size + ctx.theme.padding * 1.2
    if lay.button_h < min_h do lay.button_h = min_h

    if title != "" {
        header_h := title_size + ctx.theme.padding * 0.6
        header_rect := vneui.ui_layout_next(ctx, 0, header_h)

        if style == .Panel {
            header_style := vneui.ui_style_from_theme(ctx.theme)
            header_style.corner_radius = 0
            header_style.border_width = 0
            header_fill := vneui.ui_color_scale(ctx.theme.panel_color, 1.06)
            vneui.ui_panel_color_style(ctx, header_rect, header_fill, header_style)
        }

        title_align := lay.align_h
        title_rect := header_rect
        title_rect.x += ctx.theme.padding * 0.6
        title_rect.w -= ctx.theme.padding * 1.2
        vneui.ui_push_text_aligned(ctx, title_rect, title, ctx.theme.font_id, title_size, ctx.theme.text_color, title_align, .Center)

        if style == .Panel {
            line_rect := vneui.ui_layout_next(ctx, 0, 2)
            vneui.ui_panel_color(ctx, line_rect, ctx.theme.accent_color)
            _ = vneui.ui_layout_next(ctx, 0, ctx.theme.padding * 0.4)
        } else {
            _ = vneui.ui_layout_next(ctx, 0, ctx.theme.padding * 0.2)
        }
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

        clicked := menu_button_id(ctx, id, btn_rect, item.label, style, item_size, lay.align_h)
        if clicked && result.index == -1 {
            result.id = id
            result.index = i
        }
    }
    vneui.ui_layout_end(ctx)
    return result
}

menu_button_id :: proc(ctx: ^vneui.UI_Context, id: u64, rect: vneui.Rect, label: string, style: Menu_Button_Style, font_size: f32, align: vneui.UI_Align) -> bool {
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

    text_rect := rect
    text_color := ctx.theme.text_color
    if hovered || focused {
        text_color = ctx.theme.accent_color
    }

    if style == .Text {
        text_rect.x += ctx.theme.padding * 0.4
        text_rect.w -= ctx.theme.padding * 0.4
        vneui.ui_push_text_aligned(ctx, text_rect, label, ctx.theme.font_id, font_size, text_color, align, .Center)
        if hovered || focused {
            line := vneui.Rect{rect.x, rect.y + rect.h - 2, rect.w, 2}
            vneui.ui_panel_color(ctx, line, ctx.theme.accent_color)
        }
        return clicked
    }

    style_cfg := vneui.ui_style_from_theme(ctx.theme)
    style_cfg.corner_radius = ctx.theme.corner_radius
    style_cfg.border_width = max(style_cfg.border_width, 1)

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

    vneui.ui_panel_color_style(ctx, rect, color, style_cfg)
    if hovered || focused {
        bar := vneui.Rect{rect.x, rect.y, 4, rect.h}
        vneui.ui_panel_color(ctx, bar, ctx.theme.accent_color)
    }

    text_rect.x += ctx.theme.padding * 0.8
    text_rect.w -= ctx.theme.padding * 0.8
    vneui.ui_push_text_aligned(ctx, text_rect, label, ctx.theme.font_id, font_size, text_color, .Start, .Center)
    return clicked
}

menu_block_align :: proc(s: string) -> vneui.UI_Align {
    lower := strings.to_lower(strings.trim_space(s))
    switch lower {
    case "center":
        return .Center
    case "right", "end":
        return .End
    }
    return .Start
}

menu_block_matches_page :: proc(block: Menu_Block, page: Menu_Page) -> bool {
    p := strings.to_lower(strings.trim_space(block.page))
    if p == "" || p == "all" do return true
    switch page {
    case .None:
        return false
    case .Main:
        return p == "main" || p == "start"
    case .Pause:
        return p == "pause"
    case .Settings:
        return p == "settings"
    case .Save:
        return p == "save"
    case .Load:
        return p == "load"
    }
    return false
}

menu_draw_blocks :: proc(ctx: ^vneui.UI_Context, g: ^Game_State) {
    if ctx == nil || g == nil do return
    if len(menu_cfg.menu_blocks) == 0 do return

    for block in menu_cfg.menu_blocks {
        if block.text == "" do continue
        if !menu_block_matches_page(block, g.menu.page) do continue

        font_size := ctx.theme.font_size
        if block.size > 0 do font_size = ctx.theme.font_size * block.size

        text_w := vneui.ui_measure_text(ctx, block.text, ctx.theme.font_id, font_size)
        text_h := ctx.theme.text_line_height * (font_size / ctx.theme.font_size)

        x := block.x
        y := block.y
        if block.use_pct {
            if block.x_pct >= 0 do x = block.x_pct * cfg.design_width
            if block.y_pct >= 0 do y = block.y_pct * cfg.design_height
        }

        rect := vneui.Rect{x, y, text_w, text_h}
        align_h := menu_block_align(block.anchor)
        align_v := menu_block_align(block.valign)

    switch align_h {
    case .Start:
        // no-op
    case .Center:
        rect.x -= text_w * 0.5
    case .End:
        rect.x -= text_w
    }
    switch align_v {
    case .Start:
        // no-op
    case .Center:
        rect.y -= text_h * 0.5
    case .End:
        rect.y -= text_h
    }

        if block.shadow {
            shadow_rect := rect
            shadow_rect.x += block.shadow_px
            shadow_rect.y += block.shadow_px
            vneui.ui_push_text_aligned(ctx, shadow_rect, block.text, ctx.theme.font_id, font_size, ui_color_from_rgba(block.shadow_color), .Start, .Start)
        }
        vneui.ui_push_text_aligned(ctx, rect, block.text, ctx.theme.font_id, font_size, ui_color_from_rgba(block.color), .Start, .Start)
    }
}

menu_start_fresh :: proc(g: ^Game_State) {
    if g == nil do return
    choice_clear(g)
    g.choice.active = false
    g.choice.selected = 0
    textbox_destroy(&g.textbox)
    g.textbox.visible = false
    g.textbox.force_hidden = false
    g.textbox.show_on_click = false
    g.textbox.speaker = ""
    g.textbox.text = ""
    g.textbox.shake = false
    g.textbox.speed_override_active = false
    g.textbox.speed_override = 0
    video_stop(&g.video)

    audio_stop_music(&g.audio)
    audio_stop_ambience(&g.audio)
    audio_stop_voice(&g.audio)
    audio_stop_video(&g.audio)
    audio_stop_sfx_all(&g.audio)
    audio_apply_settings(&g.audio)

    start_path := g.start_script
    if start_path == "" {
        start_path = cfg.entry_script
    }
    script_load(&g.script, start_path)
    scene_system_cleanup()
    scene_init()
    g_scenes.current = scene_load_sync(start_path)
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

menu_save_rect :: proc(w, h: f32) -> vneui.Rect {
    anchor := strings.to_lower(menu_cfg.save_anchor)
    defer delete(anchor)
    offset_x := menu_dim(menu_cfg.save_x, menu_cfg.save_x_pct, cfg.design_width)
    offset_y := menu_dim(menu_cfg.save_y, menu_cfg.save_y_pct, cfg.design_height)
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

menu_save_slot_name :: proc(page, index: int) -> string {
    return fmt.aprintf("save_p%02d_s%02d", page+1, index+1)
}

menu_build_save_slots :: proc(page: int, mode: vneui.UI_Save_List_Mode) -> [dynamic]vneui.UI_Save_Slot {
    slots := make([dynamic]vneui.UI_Save_Slot, 0, SAVE_SLOTS_PER_PAGE)
    p := page
    if p < 0 do p = 0
    if p >= SAVE_PAGE_COUNT do p = SAVE_PAGE_COUNT-1
    for i := 0; i < SAVE_SLOTS_PER_PAGE; i += 1 {
        slot_name := menu_save_slot_name(p, i)
        path := strings.concatenate({cfg.path_saves, slot_name, ".sthiti"})
        exists := os.is_file(path)
        delete(path)
        
        title := ""
        subtitle := ""
        if exists {
            title = fmt.aprintf("Slot %02d", p*SAVE_SLOTS_PER_PAGE+i+1)
            subtitle = strings.clone("Saved")
        } else {
            title = fmt.aprintf("Empty Slot %02d", p*SAVE_SLOTS_PER_PAGE+i+1)
            subtitle = strings.clone("")
        }
        
        disabled := false
        if mode == .Load && !exists {
            disabled = true
        }

        slot := vneui.UI_Save_Slot{
            id = vneui.ui_id_from_string(slot_name),
            title = title,
            subtitle = subtitle,
            timestamp = strings.clone(""),
            thumbnail_id = 0,
            disabled = disabled,
        }
        append(&slots, slot)
        delete(slot_name)
    }
    return slots
}

menu_free_save_slots :: proc(slots: ^[dynamic]vneui.UI_Save_Slot) {
    if slots == nil do return
    for i := 0; i < len(slots^); i += 1 {
        slot := &slots^[i]
        if slot.title != "" do delete(slot.title)
        if slot.subtitle != "" do delete(slot.subtitle)
        if slot.timestamp != "" do delete(slot.timestamp)
    }
    delete(slots^)
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
    case .Pause, .Save, .Load:
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
    case .Pause, .Save, .Load:
        if menu_cfg.menu_bg_pause_alpha > 0 do return menu_cfg.menu_bg_pause_alpha
    case .None:
    }
    return menu_cfg.menu_bg_alpha
}

menu_panel_color_for_page :: proc(g: ^Game_State) -> [4]f32 {
    if g == nil do return menu_cfg.panel_color
    switch g.menu.page {
    case .Main:
        if menu_cfg.menu_panel_color_start_set do return menu_cfg.menu_panel_color_start
    case .Settings:
        if menu_cfg.menu_panel_color_settings_set do return menu_cfg.menu_panel_color_settings
    case .Pause, .Save, .Load:
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

Menu_Button_Style :: enum {
    Panel,
    Text,
}

menu_button_style_from_string :: proc(value: string) -> Menu_Button_Style {
    lower := strings.to_lower(value)
    defer delete(lower)
    switch lower {
    case "text":
        return .Text
    }
    return .Panel
}

menu_button_style_for_start :: proc() -> Menu_Button_Style {
    if menu_cfg.menu_btn_style_start != "" {
        return menu_button_style_from_string(menu_cfg.menu_btn_style_start)
    }
    return menu_button_style_from_string(menu_cfg.menu_btn_style)
}

menu_button_style_for_pause :: proc() -> Menu_Button_Style {
    if menu_cfg.menu_btn_style_pause != "" {
        return menu_button_style_from_string(menu_cfg.menu_btn_style_pause)
    }
    return menu_button_style_from_string(menu_cfg.menu_btn_style)
}

menu_scale_value :: proc(base, override: f32) -> f32 {
    v := base
    if v <= 0 do v = 1.0
    if override > 0 do v = override
    return v
}

menu_float_offset :: proc(t, amp, speed: f32) -> (f32, f32, f32) {
    speed_val := speed
    amp_val := amp
    if speed_val <= 0 do speed_val = 0.2
    if amp_val < 0 do amp_val = 0
    phase := t * speed_val * 6.2831853
    dx := math.sin(phase) * amp_val
    dy := math.cos(phase * 0.9) * amp_val
    pad := amp_val
    return dx, dy, pad
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
