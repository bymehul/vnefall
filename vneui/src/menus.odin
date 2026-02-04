package vneui

import "core:fmt"

UI_Menu_Item :: struct {
    id: u64,
    label: string,
    disabled: bool,
}

UI_Menu_Result :: struct {
    id: u64,
    index: int,
}

UI_Menu_Layout :: struct {
    padding: f32,
    gap: f32,
    button_h: f32,
    max_button_w: f32,
    align_h: UI_Align,
}

UI_Main_Menu_Action :: enum {
    None,
    Start,
    Continue,
    Load,
    Preferences,
    Quit,
}

UI_Main_Menu_Labels :: struct {
    start: string,
    continue_label: string,
    load: string,
    preferences: string,
    quit: string,
}

UI_Main_Menu_Config :: struct {
    title: string,
    show_continue: bool,
    show_load: bool,
    show_quit: bool,
    labels: UI_Main_Menu_Labels,
}

UI_Pref_Slider_Item :: struct {
    id: u64,
    label: string,
    value: ^f32,
    min: f32,
    max: f32,
    format: string,
}

UI_Pref_Toggle_Item :: struct {
    id: u64,
    label: string,
    value: ^bool,
}

UI_Preferences_Section :: struct {
    title: string,
    sliders: []UI_Pref_Slider_Item,
    toggles: []UI_Pref_Toggle_Item,
}

UI_Preferences_Menu :: struct {
    title: string,
    sections: []UI_Preferences_Section,
    show_back: bool,
    show_reset: bool,
    back_label: string,
    reset_label: string,
}

UI_Preferences_Action :: enum {
    None,
    Back,
    Reset,
}

UI_Preferences_Layout :: struct {
    padding: f32,
    gap: f32,
    row_h: f32,
    label_w: f32,
    value_w: f32,
    button_h: f32,
}

UI_Save_List_Mode :: enum {
    Save,
    Load,
}

UI_Save_Slot :: struct {
    id: u64,
    title: string,
    subtitle: string,
    timestamp: string,
    thumbnail_id: int,
    disabled: bool,
}

UI_Save_List_Action :: enum {
    None,
    Select,
    Back,
}

UI_Save_List_Result :: struct {
    action: UI_Save_List_Action,
    index: int,
}

UI_Save_List_Config :: struct {
    title: string,
    mode: UI_Save_List_Mode,
    show_back: bool,
    back_label: string,
}

UI_Save_List_State :: struct {
    scroll_y: f32,
    scroll: UI_Scroll_State,
    selected_index: int,
}

UI_Save_List_Layout :: struct {
    padding: f32,
    gap: f32,
    slot_h: f32,
    thumb_w: f32,
    button_h: f32,
}

UI_Confirm_Result :: enum {
    None,
    Confirm,
    Cancel,
}

UI_Confirm_Config :: struct {
    title: string,
    message: string,
    confirm_label: string,
    cancel_label: string,
    overlay_alpha: f32,
}

ui_menu_layout_default :: proc(ctx: ^UI_Context) -> UI_Menu_Layout {
    return UI_Menu_Layout{
        padding = ctx.theme.padding,
        gap = ctx.theme.padding * 0.6,
        button_h = ctx.theme.text_line_height + ctx.theme.padding * 1.2,
        max_button_w = 0,
        align_h = .Center,
    }
}

ui_menu_list :: proc(ctx: ^UI_Context, rect: Rect, title: string, items: []UI_Menu_Item, layout: UI_Menu_Layout) -> UI_Menu_Result {
    result := UI_Menu_Result{id = 0, index = -1}
    lay := layout
    if lay.padding <= 0 do lay.padding = ctx.theme.padding
    if lay.gap <= 0 do lay.gap = ctx.theme.padding * 0.6
    if lay.button_h <= 0 do lay.button_h = ctx.theme.text_line_height + ctx.theme.padding * 1.2

    ui_layout_begin(ctx, rect, .Column, lay.padding, lay.gap)
    if title != "" {
        ui_label_layout(ctx, title, 0, ctx.theme.text_line_height + ctx.theme.padding * 0.5)
        ui_separator_layout(ctx, 2, 0, ctx.theme.padding * 0.6)
    }

    for i := 0; i < len(items); i += 1 {
        item := items[i]
        if item.label == "" do continue
        id := item.id
        if id == 0 do id = ui_id_from_string(item.label)
        row := ui_layout_next(ctx, 0, lay.button_h)
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
        btn_rect := Rect{x = btn_x, y = row.y, w = btn_w, h = row.h}

        if item.disabled {
            disabled_color := ui_color_scale(ctx.theme.panel_color, 0.92)
            ui_panel_color(ctx, btn_rect, disabled_color)
            ui_push_text_aligned(ctx, btn_rect, item.label, ctx.theme.font_id, ctx.theme.font_size, ui_color_scale(ctx.theme.text_color, 0.8), .Center, .Center)
            continue
        }

        clicked := ui_button_id(ctx, id, btn_rect, item.label)
        if clicked && result.index == -1 {
            result.id = id
            result.index = i
        }
    }
    ui_layout_end(ctx)
    return result
}

ui_main_menu :: proc(ctx: ^UI_Context, rect: Rect, cfg: UI_Main_Menu_Config) -> UI_Main_Menu_Action {
    layout := ui_menu_layout_default(ctx)
    return ui_main_menu_layout(ctx, rect, cfg, layout)
}

ui_main_menu_layout :: proc(ctx: ^UI_Context, rect: Rect, cfg: UI_Main_Menu_Config, layout: UI_Menu_Layout) -> UI_Main_Menu_Action {
    items := make([dynamic]UI_Menu_Item)
    defer delete(items)

    title := cfg.title
    if title == "" do title = "Main Menu"

    start_label := cfg.labels.start
    if start_label == "" do start_label = "Start"
    cont_label := cfg.labels.continue_label
    if cont_label == "" do cont_label = "Continue"
    load_label := cfg.labels.load
    if load_label == "" do load_label = "Load"
    pref_label := cfg.labels.preferences
    if pref_label == "" do pref_label = "Preferences"
    quit_label := cfg.labels.quit
    if quit_label == "" do quit_label = "Quit"

    start_id := ui_id_from_string("vneui_main_start")
    cont_id := ui_id_from_string("vneui_main_continue")
    load_id := ui_id_from_string("vneui_main_load")
    prefs_id := ui_id_from_string("vneui_main_prefs")
    quit_id := ui_id_from_string("vneui_main_quit")

    append(&items, UI_Menu_Item{id = start_id, label = start_label})
    if cfg.show_continue {
        append(&items, UI_Menu_Item{id = cont_id, label = cont_label})
    }
    if cfg.show_load {
        append(&items, UI_Menu_Item{id = load_id, label = load_label})
    }
    append(&items, UI_Menu_Item{id = prefs_id, label = pref_label})
    if cfg.show_quit {
        append(&items, UI_Menu_Item{id = quit_id, label = quit_label})
    }

    res := ui_menu_list(ctx, rect, title, items[:], layout)
    switch res.id {
    case start_id:
        return .Start
    case cont_id:
        return .Continue
    case load_id:
        return .Load
    case prefs_id:
        return .Preferences
    case quit_id:
        return .Quit
    }
    return .None
}

ui_preferences_layout_default :: proc(ctx: ^UI_Context) -> UI_Preferences_Layout {
    return UI_Preferences_Layout{
        padding = ctx.theme.padding,
        gap = ctx.theme.padding * 0.6,
        row_h = ctx.theme.text_line_height + ctx.theme.padding * 1.2,
        label_w = 0,
        value_w = 0,
        button_h = ctx.theme.text_line_height + ctx.theme.padding * 1.1,
    }
}

ui_preferences_section :: proc(ctx: ^UI_Context, section: UI_Preferences_Section, layout: UI_Preferences_Layout) -> bool {
    changed := false
    if section.title != "" {
        ui_label_layout(ctx, section.title, 0, ctx.theme.text_line_height + ctx.theme.padding * 0.4)
    }

    label_w := layout.label_w
    if label_w <= 0 {
        max_w: f32 = 0
        for i := 0; i < len(section.sliders); i += 1 {
            w := ui_measure_text(ctx, section.sliders[i].label, ctx.theme.font_id, ctx.theme.font_size)
            if w > max_w do max_w = w
        }
        for i := 0; i < len(section.toggles); i += 1 {
            w := ui_measure_text(ctx, section.toggles[i].label, ctx.theme.font_id, ctx.theme.font_size)
            if w > max_w do max_w = w
        }
        label_w = max_w + ctx.theme.padding * 2
    }

    row_h := layout.row_h
    if row_h <= 0 do row_h = ctx.theme.text_line_height + ctx.theme.padding * 1.2
    gap := layout.gap
    if gap <= 0 do gap = ctx.theme.padding * 0.6

    for i := 0; i < len(section.sliders); i += 1 {
        item := section.sliders[i]
        if item.value == nil do continue
        row := ui_layout_next(ctx, 0, row_h)

        label_rect := Rect{x = row.x, y = row.y, w = label_w, h = row.h}
        ui_push_text_aligned(ctx, label_rect, item.label, ctx.theme.font_id, ctx.theme.font_size, ctx.theme.text_color, .Start, .Center)

        value_text := ""
        value_w := layout.value_w
        if item.format != "" {
            value_text = fmt.aprintf(item.format, item.value^)
            if value_w <= 0 {
                value_w = ui_measure_text(ctx, value_text, ctx.theme.font_id, ctx.theme.font_size) + ctx.theme.padding
            }
        } else if value_w < 0 {
            value_w = 0
        }

        slider_w := row.w - label_w - gap - value_w
        if slider_w < ctx.theme.font_size * 2 do slider_w = ctx.theme.font_size * 2

        slider_rect := Rect{x = row.x + label_w + gap, y = row.y, w = slider_w, h = row.h}
        new_value, changed_now := ui_slider(ctx, slider_rect, item.value^, item.min, item.max)
        if changed_now {
            item.value^ = new_value
            changed = true
        }

        if value_text != "" {
            value_rect := Rect{
                x = slider_rect.x + slider_rect.w + gap,
                y = row.y,
                w = value_w,
                h = row.h,
            }
            ui_push_text_aligned(ctx, value_rect, value_text, ctx.theme.font_id, ctx.theme.font_size, ctx.theme.text_color, .End, .Center)
            delete(value_text)
        }
    }

    for i := 0; i < len(section.toggles); i += 1 {
        item := section.toggles[i]
        if item.value == nil do continue
        row := ui_layout_next(ctx, 0, row_h)
        id := item.id
        if id == 0 do id = ui_id_from_string(item.label)
        next_value, changed_now := ui_toggle_id(ctx, id, row, item.value^, item.label)
        if changed_now {
            item.value^ = next_value
            changed = true
        }
    }

    return changed
}

ui_preferences_menu :: proc(ctx: ^UI_Context, rect: Rect, menu: UI_Preferences_Menu, layout: UI_Preferences_Layout) -> UI_Preferences_Action {
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

    ui_layout_begin(ctx, rect, .Column, lay.padding, lay.gap)
    if title != "" {
        ui_label_layout(ctx, title, 0, ctx.theme.text_line_height + ctx.theme.padding * 0.5)
        ui_separator_layout(ctx, 2, 0, ctx.theme.padding * 0.6)
    }

    for i := 0; i < len(menu.sections); i += 1 {
        if i > 0 {
            ui_separator_layout(ctx, 2, 0, ctx.theme.padding * 0.6)
        }
        _ = ui_preferences_section(ctx, menu.sections[i], lay)
    }

    action := UI_Preferences_Action.None
    if menu.show_back || menu.show_reset {
        ui_layout_space(ctx, ctx.theme.padding * 0.4)
        row := ui_layout_next(ctx, 0, lay.button_h)
        ui_layout_begin(ctx, row, .Row, 0, lay.gap)
        button_count := 0
        if menu.show_back do button_count += 1
        if menu.show_reset do button_count += 1
        button_w: f32 = row.w
        if button_count > 0 {
            button_w = (row.w - f32(button_count-1)*lay.gap) / f32(button_count)
        }
        if menu.show_back {
            if ui_button_layout(ctx, back_label, button_w, lay.button_h) {
                action = .Back
            }
        }
        if menu.show_reset {
            if ui_button_layout(ctx, reset_label, button_w, lay.button_h) {
                action = .Reset
            }
        }
        ui_layout_end(ctx)
    }

    ui_layout_end(ctx)
    return action
}

ui_save_list_layout_default :: proc(ctx: ^UI_Context) -> UI_Save_List_Layout {
    return UI_Save_List_Layout{
        padding = ctx.theme.padding,
        gap = ctx.theme.padding * 0.6,
        slot_h = ctx.theme.text_line_height * 2.4 + ctx.theme.padding * 1.2,
        thumb_w = ctx.theme.text_line_height * 2.4,
        button_h = ctx.theme.text_line_height + ctx.theme.padding * 1.1,
    }
}

ui_save_list_menu :: proc(ctx: ^UI_Context, rect: Rect, slots: []UI_Save_Slot, cfg: UI_Save_List_Config, layout: UI_Save_List_Layout, state: ^UI_Save_List_State) -> UI_Save_List_Result {
    result := UI_Save_List_Result{action = .None, index = -1}
    if state == nil do return result

    lay := layout
    if lay.padding <= 0 do lay.padding = ctx.theme.padding
    if lay.gap <= 0 do lay.gap = ctx.theme.padding * 0.6
    if lay.slot_h <= 0 do lay.slot_h = ctx.theme.text_line_height * 2.4 + ctx.theme.padding * 1.2
    if lay.thumb_w <= 0 do lay.thumb_w = ctx.theme.text_line_height * 2.4
    if lay.button_h <= 0 do lay.button_h = ctx.theme.text_line_height + ctx.theme.padding * 1.1

    title := cfg.title
    if title == "" {
        switch cfg.mode {
        case .Save:
            title = "Save"
        case .Load:
            title = "Load"
        }
    }
    back_label := cfg.back_label
    if back_label == "" do back_label = "Back"

    content_h := rect.h - lay.padding * 2
    header_h := ctx.theme.text_line_height + ctx.theme.padding * 1.1
    separator_h := ctx.theme.padding * 0.6
    footer_h: f32 = 0
    if cfg.show_back {
        footer_h = lay.button_h + lay.gap
    }
    list_h := content_h - header_h - separator_h - footer_h
    if list_h < lay.slot_h do list_h = lay.slot_h

    ui_layout_begin(ctx, rect, .Column, lay.padding, lay.gap)
    ui_label_layout(ctx, title, 0, header_h)
    ui_separator_layout(ctx, 2, 0, separator_h)

    list_rect := ui_layout_next(ctx, 0, list_h)
    if state.scroll.scroll_y == 0 && state.scroll_y != 0 {
        state.scroll.scroll_y = state.scroll_y
    }
    scroll_opts := ui_scroll_options_default()
    scroll_opts.scrollbar_thickness = 6
    ui_scroll_begin_state(ctx, list_rect, &state.scroll, lay.gap, lay.gap)

    for i := 0; i < len(slots); i += 1 {
        slot := slots[i]
        row := ui_layout_next(ctx, 0, lay.slot_h)
        if slot.disabled {
            dim := ui_color_scale(ctx.theme.panel_color, 0.9)
            ui_panel_color(ctx, row, dim)
        } else {
            base := ctx.theme.panel_color
            if state.selected_index == i {
                base = ui_color_scale(base, 1.06)
            }
            id := slot.id
            if id == 0 {
                label := fmt.aprintf("vneui_save_slot_%d", i)
                id = ui_id_from_string(label)
                delete(label)
            }
            if ui_panel_interact(ctx, row, id, base) {
                state.selected_index = i
                result.action = .Select
                result.index = i
            }
        }

        thumb := Rect{x = row.x + lay.gap, y = row.y + lay.gap, w = lay.thumb_w, h = row.h - lay.gap*2}
        if slot.thumbnail_id > 0 {
            ui_image(ctx, thumb, slot.thumbnail_id)
        } else {
            ui_push_rect(ctx, thumb, ui_color_scale(ctx.theme.panel_color, 0.88))
            ui_push_border(ctx, thumb, 1, ui_color_scale(ctx.theme.border_color, 0.9))
        }

        text_x := thumb.x + thumb.w + lay.gap
        text_rect := Rect{x = text_x, y = row.y + lay.gap, w = row.w - (text_x - row.x) - lay.gap, h = row.h - lay.gap*2}
        line_h := ctx.theme.text_line_height
        title_rect := Rect{x = text_rect.x, y = text_rect.y, w = text_rect.w, h = line_h}
        ui_push_text_aligned(ctx, title_rect, slot.title, ctx.theme.font_id, ctx.theme.font_size, ctx.theme.text_color, .Start, .Center)

        if slot.subtitle != "" {
            sub_rect := Rect{x = text_rect.x, y = text_rect.y + line_h, w = text_rect.w, h = line_h}
            ui_push_text_aligned(ctx, sub_rect, slot.subtitle, ctx.theme.font_id, ctx.theme.font_size, ui_color_scale(ctx.theme.text_color, 0.85), .Start, .Center)
        } else if slot.timestamp != "" {
            sub_rect := Rect{x = text_rect.x, y = text_rect.y + line_h, w = text_rect.w, h = line_h}
            ui_push_text_aligned(ctx, sub_rect, slot.timestamp, ctx.theme.font_id, ctx.theme.font_size, ui_color_scale(ctx.theme.text_color, 0.85), .Start, .Center)
        }
    }

    state.scroll.scroll_y = ui_scroll_end_state(ctx, list_rect, &state.scroll, scroll_opts)
    state.scroll_y = state.scroll.scroll_y

    if cfg.show_back {
        if ui_button_layout(ctx, back_label, 0, lay.button_h) {
            result.action = .Back
        }
    }
    ui_layout_end(ctx)
    return result
}

ui_confirm_dialog :: proc(ctx: ^UI_Context, screen_rect: Rect, rect: Rect, cfg: UI_Confirm_Config, style: UI_Style) -> UI_Confirm_Result {
    result := UI_Confirm_Result.None
    overlay_alpha := cfg.overlay_alpha
    if overlay_alpha <= 0 do overlay_alpha = 0.45
    overlay := ui_color(0, 0, 0, overlay_alpha)
    ui_modal_overlay(ctx, screen_rect, overlay)

    ui_modal_begin(ctx, rect, style, .Column, style.padding, style.padding * 0.6)
    title := cfg.title
    if title == "" do title = "Confirm"
    confirm_label := cfg.confirm_label
    if confirm_label == "" do confirm_label = "Confirm"
    cancel_label := cfg.cancel_label
    if cancel_label == "" do cancel_label = "Cancel"

    ui_label_layout(ctx, title, 0, style.text_line_height + style.padding * 0.4)
    ui_separator_layout(ctx, 2, 0, style.padding * 0.6)
    ui_label_wrap_layout(ctx, cfg.message, 0, style.text_line_height * 2.6)

    ui_layout_space(ctx, style.padding * 0.3)
    row := ui_layout_next(ctx, 0, style.text_line_height + style.padding * 1.1)
    ui_layout_begin(ctx, row, .Row, 0, style.padding * 0.6)
    button_w := (row.w - style.padding * 0.6) * 0.5
    if button_w < style.font_size * 4 do button_w = style.font_size * 4
    if ui_button_layout(ctx, cancel_label, button_w, row.h) {
        result = .Cancel
    }
    if ui_button_layout(ctx, confirm_label, button_w, row.h) {
        result = .Confirm
    }
    ui_layout_end(ctx)

    ui_modal_end(ctx)
    return result
}
