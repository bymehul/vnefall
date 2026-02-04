package main

import "core:fmt"
import "core:os"
import "core:strings"
import vneui "vneui:src"

// Run with:
//   odin run vneui/demo -collection:vneui=./vneui

main :: proc() {
    ctx: vneui.UI_Context
    vneui.ui_init(&ctx)
    defer vneui.ui_shutdown(&ctx)

    theme := vneui.ui_theme_default(0, 18)
    theme.panel_color = vneui.ui_color_rgba8(30, 32, 38, 255)
    theme.accent_color = vneui.ui_color_rgba8(100, 190, 255, 255)
    theme.shadow_enabled = true
    theme.text_line_height = 22

    accent_style := vneui.ui_style_from_theme(theme)
    accent_style.panel_color = vneui.ui_color_rgba8(24, 26, 32, 255)
    accent_style.accent_color = vneui.ui_color_rgba8(255, 168, 88, 255)
    accent_style.text_color = vneui.ui_color_rgba8(250, 240, 220, 255)
    accent_style.border_color = vneui.ui_color_rgba8(16, 16, 20, 255)
    accent_style.border_width = 1.5
    accent_style.corner_radius = 10
    accent_style.shadow_offset = vneui.Vec2{0, 3}

    canvas_w := 960
    canvas_h := 640
    view_w := f32(canvas_w)
    view_h := f32(canvas_h)
    margin := f32(28)
    root := vneui.Rect{margin, margin, view_w - margin*2, view_h - margin*2}

    modal_w := root.w * 0.44
    modal_h := root.h * 0.28
    modal_rect := vneui.Rect{
        x = root.x + (root.w - modal_w) * 0.5,
        y = root.y + (root.h - modal_h) * 0.5,
        w = modal_w,
        h = modal_h,
    }

    input := vneui.UI_Input{
        mouse_pos = vneui.Vec2{
            modal_rect.x + modal_rect.w * 0.5,
            modal_rect.y + modal_rect.h * 0.4,
        },
        mouse_down = false,
        mouse_pressed = false,
        mouse_released = false,
        scroll_y = 0,
        delta_time = 0.6,
    }

    vneui.ui_begin_frame(&ctx, input, theme)

    vneui.ui_toast_push(&ctx, "Settings saved successfully.", 2.4, .Success)
    vneui.ui_toast_push(&ctx, "New entry unlocked in the gallery.", 2.6, .Info)
    vneui.ui_toast_push(&ctx, "Connection lost. Retrying...", 2.2, .Warning)

    vneui.ui_input_scope_begin(&ctx, modal_rect)

    root_pad := theme.padding + 2
    root_gap := theme.padding * 0.7
    vneui.ui_panel_begin(&ctx, root, .Column, root_pad, root_gap)

    title_h := theme.text_line_height + theme.padding * 0.6
    sep_h := theme.padding * 0.6
    desc_h := theme.text_line_height * 2.2

    vneui.ui_label_layout(&ctx, "VNEUI Demo - Menus + Overlays", 0, title_h)
    vneui.ui_separator_layout(&ctx, 2, 0, sep_h)

    vneui.ui_label_wrap_layout(&ctx, "This demo exercises the roadmap features: menu helpers, preferences, save/load UI, confirm dialogs, toasts, tooltips, and transitions.", 0, desc_h)

    content_h := root.h - root_pad*2 - title_h - sep_h - desc_h - root_gap*3
    if content_h < theme.text_line_height * 8 do content_h = theme.text_line_height * 8
    content_rect := vneui.ui_layout_next(&ctx, 0, content_h)
    vneui.ui_layout_begin(&ctx, content_rect, .Row, 0, root_gap)

    col_w := (content_rect.w - root_gap) * 0.5
    left_col := vneui.ui_layout_next(&ctx, col_w, content_rect.h)
    right_col := vneui.ui_layout_next(&ctx, col_w, content_rect.h)
    vneui.ui_layout_end(&ctx)

    player_name := strings.clone("Alex")
    defer delete(player_name)
    name_state := vneui.UI_Text_Input_State{cursor = len(player_name)}
    difficulty_index := 1
    difficulty_state := vneui.UI_Select_State{}

    left_pad := theme.padding
    left_gap := theme.padding * 0.7
    vneui.ui_layout_begin(&ctx, left_col, .Column, left_pad, left_gap)
    avail_left_h := left_col.h - left_pad*2
    menu_h := avail_left_h * 0.34
    prefs_h := avail_left_h * 0.44
    inputs_h := avail_left_h - menu_h - prefs_h - left_gap*2
    if inputs_h < theme.text_line_height * 4 do inputs_h = theme.text_line_height * 4
    menu_rect := vneui.ui_layout_next(&ctx, 0, menu_h)
    prefs_rect := vneui.ui_layout_next(&ctx, 0, prefs_h)
    inputs_rect := vneui.ui_layout_next(&ctx, 0, inputs_h)
    vneui.ui_layout_end(&ctx)

    main_labels := vneui.UI_Main_Menu_Labels{
        start = "Start",
        continue_label = "Continue",
        load = "Load",
        preferences = "Preferences",
        quit = "Quit",
    }
    main_cfg := vneui.UI_Main_Menu_Config{
        title = "Main Menu",
        show_continue = true,
        show_load = true,
        show_quit = true,
        labels = main_labels,
    }
    menu_layout := vneui.ui_menu_layout_default(&ctx)
    menu_layout.max_button_w = menu_rect.w * 0.78
    vneui.ui_panel(&ctx, menu_rect)
    _ = vneui.ui_main_menu_layout(&ctx, menu_rect, main_cfg, menu_layout)

    master_vol: f32 = 80
    music_vol: f32 = 65
    text_speed: f32 = 5
    auto_advance := false
    skip_unread := true

    audio_sliders := []vneui.UI_Pref_Slider_Item{
        {label = "Master", value = &master_vol, min = 0, max = 100, format = "%.0f%%"},
        {label = "Music", value = &music_vol, min = 0, max = 100, format = "%.0f%%"},
    }
    text_sliders := []vneui.UI_Pref_Slider_Item{
        {label = "Speed", value = &text_speed, min = 1, max = 10, format = "%.0f"},
    }
    text_toggles := []vneui.UI_Pref_Toggle_Item{
        {label = "Auto-Advance", value = &auto_advance},
        {label = "Skip Unread", value = &skip_unread},
    }
    prefs_sections := []vneui.UI_Preferences_Section{
        {title = "Audio", sliders = audio_sliders, toggles = nil},
        {title = "Text", sliders = text_sliders, toggles = text_toggles},
    }
    prefs_menu := vneui.UI_Preferences_Menu{
        title = "Preferences",
        sections = prefs_sections,
        show_back = true,
        show_reset = true,
    }
    prefs_layout := vneui.ui_preferences_layout_default(&ctx)
    prefs_layout.label_w = prefs_rect.w * 0.32
    vneui.ui_panel(&ctx, prefs_rect)
    _ = vneui.ui_preferences_menu(&ctx, prefs_rect, prefs_menu, prefs_layout)

    vneui.ui_panel_begin(&ctx, inputs_rect, .Column, theme.padding, theme.padding * 0.6)
    vneui.ui_label_layout(&ctx, "Inputs", 0, theme.text_line_height + theme.padding * 0.4)
    vneui.ui_separator_layout(&ctx, 2, 0, theme.padding * 0.5)

    vneui.ui_label_layout(&ctx, "Player Name", 0, theme.text_line_height + theme.padding * 0.2)
    input_rect := vneui.ui_layout_next(&ctx, 0, theme.text_line_height + theme.padding * 1.1)
    input_opts := vneui.UI_Text_Input_Options{placeholder = "Enter name"}
    _, _ = vneui.ui_text_input_style(&ctx, input_rect, "player_name", &player_name, &name_state, accent_style, input_opts)

    vneui.ui_layout_space(&ctx, theme.padding * 0.3)
    vneui.ui_label_layout(&ctx, "Difficulty", 0, theme.text_line_height + theme.padding * 0.2)
    select_rect := vneui.ui_layout_next(&ctx, 0, theme.text_line_height + theme.padding * 1.1)
    difficulties := []string{"Easy", "Normal", "Hard"}
    difficulty_index, _ = vneui.ui_select(&ctx, select_rect, "difficulty", difficulties, difficulty_index, &difficulty_state)

    vneui.ui_layout_space(&ctx, theme.padding * 0.3)
    vneui.ui_label_layout(&ctx, "Nine-slice (debug)", 0, theme.text_line_height + theme.padding * 0.2)
    nine_rect := vneui.ui_layout_next(&ctx, 0, theme.text_line_height * 2.2)
    vneui.ui_image_nine_slice(&ctx, nine_rect, -1, 32, 32, vneui.ui_insets(8, 8, 8, 8), vneui.ui_color_scale(theme.accent_color, 0.9))

    vneui.ui_panel_end(&ctx)

    right_pad := theme.padding
    right_gap := theme.padding * 0.7
    vneui.ui_layout_begin(&ctx, right_col, .Column, right_pad, right_gap)
    avail_right_h := right_col.h - right_pad*2
    save_h := avail_right_h * 0.62
    adv_h := avail_right_h - save_h - right_gap
    save_rect := vneui.ui_layout_next(&ctx, 0, save_h)
    adv_rect := vneui.ui_layout_next(&ctx, 0, adv_h)
    vneui.ui_layout_end(&ctx)

    save_slots := []vneui.UI_Save_Slot{
        {
            id = vneui.ui_id_from_string("slot_1"),
            title = "Prologue - Rainy Night",
            subtitle = "Street 7",
            timestamp = "00:12:45",
            thumbnail_id = 0,
            disabled = false,
        },
        {
            id = vneui.ui_id_from_string("slot_2"),
            title = "Chapter 1 - Rooftop",
            subtitle = "Cityline",
            timestamp = "00:48:02",
            thumbnail_id = 0,
            disabled = false,
        },
        {
            id = vneui.ui_id_from_string("slot_3"),
            title = "Chapter 2 - Silent Room",
            subtitle = "Dormitory",
            timestamp = "01:15:10",
            thumbnail_id = 0,
            disabled = true,
        },
    }
    save_state := vneui.UI_Save_List_State{scroll_y = 0, selected_index = 1}
    save_cfg := vneui.UI_Save_List_Config{
        title = "Save / Load",
        mode = .Load,
        show_back = true,
        back_label = "Back",
    }
    save_layout := vneui.ui_save_list_layout_default(&ctx)
    vneui.ui_panel(&ctx, save_rect)
    _ = vneui.ui_save_list_menu(&ctx, save_rect, save_slots, save_cfg, save_layout, &save_state)

    vneui.ui_panel_begin(&ctx, adv_rect, .Column, theme.padding, theme.padding * 0.6)
    vneui.ui_label_layout(&ctx, "Advanced UI", 0, theme.text_line_height + theme.padding * 0.4)
    vneui.ui_separator_layout(&ctx, 2, 0, theme.padding * 0.5)

    vneui.ui_label_layout(&ctx, "Transition Preview", 0, theme.text_line_height + theme.padding * 0.2)
    transition_rect := vneui.ui_layout_next(&ctx, 0, theme.text_line_height * 2.4)
    vneui.ui_panel_color(&ctx, transition_rect, vneui.ui_color_scale(theme.panel_color, 0.92))

    card_pad := theme.padding * 0.5
    card_rect := vneui.Rect{
        x = transition_rect.x + card_pad,
        y = transition_rect.y + card_pad,
        w = transition_rect.w * 0.48,
        h = transition_rect.h - card_pad*2,
    }
    transition := vneui.UI_Transition{}
    vneui.ui_transition_begin(&transition, .Slide_Right, 1.0, false)
    _ = vneui.ui_transition_update(&transition, 0.6)
    card_rect = vneui.ui_transition_apply_rect(card_rect, transition.kind, transition.progress)
    vneui.ui_panel_color(&ctx, card_rect, vneui.ui_color_scale(theme.accent_color, 1.0))
    vneui.ui_push_text_aligned(&ctx, card_rect, "Slide", theme.font_id, theme.font_size * 0.9, theme.text_color, .Center, .Center)
    vneui.ui_transition_draw_fade(&ctx, transition_rect, vneui.ui_color(0, 0, 0, 0.25), 1 - transition.progress)

    vneui.ui_layout_space(&ctx, theme.padding * 0.4)
    vneui.ui_label_wrap_layout(&ctx, "Modal dialogs trap input. Tooltips and toasts are layered above the main layout.", 0, theme.text_line_height * 2.2)
    vneui.ui_panel_end(&ctx)

    vneui.ui_panel_end(&ctx)

    confirm_cfg := vneui.UI_Confirm_Config{
        title = "Overwrite Slot 3?",
        message = "This modal blocks background input until you confirm or cancel. The tooltip is anchored near the cursor.",
        confirm_label = "Overwrite",
        cancel_label = "Cancel",
        overlay_alpha = 0.5,
    }
    _ = vneui.ui_confirm_dialog(&ctx, root, modal_rect, confirm_cfg, accent_style)

    vneui.ui_tooltip_register(&ctx, modal_rect, "Tooltip: modal input is trapped to this dialog.")
    vneui.ui_tooltip_draw(&ctx, root, accent_style, root.w * 0.38)

    vneui.ui_input_scope_end(&ctx)

    toast_layout := vneui.UI_Toast_Layout{
        padding = theme.padding * 0.8,
        gap = theme.padding * 0.5,
        max_width = root.w * 0.38,
        anchor_h = .End,
        anchor_v = .Start,
    }
    vneui.ui_toasts_draw(&ctx, root, accent_style, toast_layout)

    commands := vneui.ui_end_frame(&ctx)

    out_path := "vneui/demo/demo_ui.svg"
    if !write_svg(out_path, canvas_w, canvas_h, commands) {
        fmt.eprintf("Failed to write SVG: %v\n", out_path)
        os.exit(1)
    }

    fmt.println("Wrote:", out_path)
}

write_svg :: proc(path: string, width, height: int, commands: []vneui.Draw_Command) -> bool {
    sb := strings.builder_make()

    fmt.sbprintf(&sb, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">\n", width, height, width, height)
    strings.write_string(&sb, "<rect width=\"100%\" height=\"100%\" fill=\"#0b0c12\"/>\n")

    for cmd in commands {
        switch cmd.kind {
        case .Rect:
            write_rect(&sb, cmd.rect, 0, cmd.color)
        case .Rounded_Rect:
            write_rect(&sb, cmd.rect, cmd.radius, cmd.color)
        case .Line:
            write_line(&sb, cmd.p0, cmd.p1, cmd.thickness, cmd.color)
        case .Text:
            write_text(&sb, cmd.rect, cmd.text, cmd.font_size, cmd.color, cmd.align_h, cmd.align_v)
        case .Image:
            if cmd.image_id < 0 {
                write_rect(&sb, cmd.rect, 0, cmd.color)
            } else {
                write_image_placeholder(&sb, cmd.rect)
            }
        case .Scissor_Push:
            // Scissor is ignored in this simple SVG output.
        case .Scissor_Pop:
        }
    }
    strings.write_string(&sb, "</svg>\n")

    out := strings.to_string(sb)
    defer delete(out)
    ok := os.write_entire_file(path, transmute([]u8)out)
    if !ok do return false
    return true
}

write_rect :: proc(sb: ^strings.Builder, r: vneui.Rect, radius: f32, c: vneui.Color) {
    fill := rgba(c)
    if radius > 0 {
        fmt.sbprintf(sb, "<rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\" rx=\"%.2f\" ry=\"%.2f\" fill=\"%s\"/>\n", r.x, r.y, r.w, r.h, radius, radius, fill)
        delete(fill)
        return
    }
    fmt.sbprintf(sb, "<rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\" fill=\"%s\"/>\n", r.x, r.y, r.w, r.h, fill)
    delete(fill)
}

write_line :: proc(sb: ^strings.Builder, p0, p1: vneui.Vec2, thickness: f32, c: vneui.Color) {
    stroke := rgba(c)
    t := thickness
    if t <= 0 do t = 1
    fmt.sbprintf(sb, "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" stroke=\"%s\" stroke-width=\"%.2f\"/>\n", p0.x, p0.y, p1.x, p1.y, stroke, t)
    delete(stroke)
}

write_text :: proc(sb: ^strings.Builder, r: vneui.Rect, text: string, size: f32, c: vneui.Color, align_h, align_v: vneui.UI_Align) {
    fill := rgba(c)
    x := r.x
    anchor := "start"
    switch align_h {
    case .Center:
        x = r.x + r.w * 0.5
        anchor = "middle"
    case .End:
        x = r.x + r.w
        anchor = "end"
    case .Start:
        x = r.x
    }

    y := r.y + r.h * 0.5
    switch align_v {
    case .Start:
        y = r.y + size
    case .End:
        y = r.y + r.h
    case .Center:
        y = r.y + r.h * 0.5
    }

    escaped := escape_xml(text)
    fmt.sbprintf(sb, "<text x=\"%.2f\" y=\"%.2f\" fill=\"%s\" font-size=\"%.2f\" font-family=\"Arial, sans-serif\" text-anchor=\"%s\" dominant-baseline=\"middle\">%s</text>\n", x, y, fill, size, anchor, escaped)
    delete(escaped)
    delete(fill)
}

write_image_placeholder :: proc(sb: ^strings.Builder, r: vneui.Rect) {
    fmt.sbprintf(sb, "<rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\" fill=\"none\" stroke=\"#6b6f7a\" stroke-width=\"1\" stroke-dasharray=\"4 3\"/>\n", r.x, r.y, r.w, r.h)
    fmt.sbprintf(sb, "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" stroke=\"#6b6f7a\" stroke-width=\"1\"/>\n", r.x, r.y, r.x + r.w, r.y + r.h)
    fmt.sbprintf(sb, "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" stroke=\"#6b6f7a\" stroke-width=\"1\"/>\n", r.x + r.w, r.y, r.x, r.y + r.h)
}

rgba :: proc(c: vneui.Color) -> string {
    r := int(c.r * 255)
    g := int(c.g * 255)
    b := int(c.b * 255)
    return fmt.aprintf("rgba(%d,%d,%d,%.2f)", r, g, b, c.a)
}

escape_xml :: proc(text: string) -> string {
    sb := strings.builder_make()
    for ch in text {
        switch ch {
        case '&':
            strings.write_string(&sb, "&amp;")
        case '<':
            strings.write_string(&sb, "&lt;")
        case '>':
            strings.write_string(&sb, "&gt;")
        case '"':
            strings.write_string(&sb, "&quot;")
        case '\'':
            strings.write_string(&sb, "&apos;")
        case:
            strings.write_byte(&sb, u8(ch))
        }
    }
    return strings.to_string(sb)
}
