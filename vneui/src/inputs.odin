package vneui

import "core:strings"
import "core:math"

UI_Text_Input_State :: struct {
    cursor: int,
}

UI_Text_Input_Options :: struct {
    placeholder: string,
    padding: f32,
}

ui_text_input :: proc(ctx: ^UI_Context, rect: Rect, label: string, value: ^string, state: ^UI_Text_Input_State) -> (bool, bool) {
    style := ui_style_from_theme(ctx.theme)
    opts := UI_Text_Input_Options{}
    return ui_text_input_style(ctx, rect, label, value, state, style, opts)
}

ui_text_input_layout :: proc(ctx: ^UI_Context, label: string, value: ^string, state: ^UI_Text_Input_State, w, h: f32) -> (bool, bool) {
    rect := ui_layout_next(ctx, w, h)
    return ui_text_input(ctx, rect, label, value, state)
}

ui_text_input_style :: proc(ctx: ^UI_Context, rect: Rect, label: string, value: ^string, state: ^UI_Text_Input_State, style: UI_Style, opts: UI_Text_Input_Options) -> (bool, bool) {
    if value == nil do return false, false
    if state == nil do return false, false

    id := ui_id_from_string(label)
    focused := ui_focus_register(ctx, id)

    allowed := ui_input_allowed(ctx, rect)
    hovered := allowed && ui_rect_contains(rect, ctx.input.mouse_pos)
    if hovered && ctx.input.mouse_pressed {
        ui_focus_set(ctx, id)
        focused = true
        state.cursor = len(value^)
    }

    changed := false
    submitted := false

    if focused {
        if ctx.input.text_input != "" {
            ui_string_insert(value, state.cursor, ctx.input.text_input)
            state.cursor += len(ctx.input.text_input)
            changed = true
        }

        if ctx.input.key_backspace && state.cursor > 0 {
            ui_string_remove(value, state.cursor-1, 1)
            state.cursor -= 1
            changed = true
        }
        if ctx.input.key_delete && state.cursor < len(value^) {
            ui_string_remove(value, state.cursor, 1)
            changed = true
        }

        if ctx.input.key_left {
            state.cursor -= 1
        }
        if ctx.input.key_right {
            state.cursor += 1
        }
        if ctx.input.key_home {
            state.cursor = 0
        }
        if ctx.input.key_end {
            state.cursor = len(value^)
        }
        if ctx.input.key_enter || ctx.input.nav_activate {
            submitted = true
        }
    }

    if state.cursor < 0 do state.cursor = 0
    if state.cursor > len(value^) do state.cursor = len(value^)

    pad := opts.padding
    if pad <= 0 do pad = style.padding
    bg := style.panel_color
    if focused {
        bg = ui_color_scale(bg, 1.05)
    } else if hovered {
        bg = ui_color_scale(bg, 1.02)
    }
    ui_panel_color_style(ctx, rect, bg, style)

    text_rect := ui_rect_inset(rect, pad)
    ui_push_scissor(ctx, text_rect)

    display := value^
    text_color := style.text_color
    if display == "" && !focused && opts.placeholder != "" {
        display = opts.placeholder
        text_color = ui_color_scale(text_color, 0.7)
    }

    ui_push_text_aligned(ctx, text_rect, display, style.font_id, style.font_size, text_color, .Start, .Center)

    if focused {
        prefix := ""
        if state.cursor > 0 {
            prefix = value^[0:state.cursor]
        }
        caret_x := text_rect.x + ui_measure_text(ctx, prefix, style.font_id, style.font_size)
        caret_rect := Rect{caret_x, text_rect.y + (text_rect.h - style.font_size) * 0.5, 1, style.font_size}
        blink := ui_smoothstep(math.mod_f32(ctx.time, 1.0))
        if blink > 0.2 {
            ui_push_rect(ctx, caret_rect, style.text_color)
        }
    }

    ui_pop_scissor(ctx)
    return changed, submitted
}

UI_Select_State :: struct {
    open: bool,
    scroll: UI_Scroll_State,
}

UI_Select_Layout :: struct {
    padding: f32,
    gap: f32,
    item_h: f32,
    max_visible: int,
    placeholder: string,
}

ui_select_layout_default :: proc(ctx: ^UI_Context) -> UI_Select_Layout {
    return UI_Select_Layout{
        padding = ctx.theme.padding,
        gap = ctx.theme.padding * 0.5,
        item_h = ctx.theme.text_line_height + ctx.theme.padding * 0.8,
        max_visible = 6,
        placeholder = "Select",
    }
}

ui_select :: proc(ctx: ^UI_Context, rect: Rect, label: string, options: []string, selected_index: int, state: ^UI_Select_State) -> (int, bool) {
    layout := ui_select_layout_default(ctx)
    return ui_select_layout(ctx, rect, label, options, selected_index, state, layout)
}

ui_select_layout :: proc(ctx: ^UI_Context, rect: Rect, label: string, options: []string, selected_index: int, state: ^UI_Select_State, layout: UI_Select_Layout) -> (int, bool) {
    if state == nil do return selected_index, false
    sel := selected_index
    changed := false
    id := ui_id_from_string(label)
    focused := ui_focus_register(ctx, id)

    if ui_input_allowed(ctx, rect) && ui_rect_contains(rect, ctx.input.mouse_pos) && ctx.input.mouse_pressed {
        ui_focus_set(ctx, id)
        focused = true
    }

    clicked := ui_panel_interact(ctx, rect, id, ctx.theme.panel_color)
    if clicked || (focused && ctx.input.nav_activate) {
        state.open = !state.open
    }
    if focused && ctx.input.nav_cancel {
        state.open = false
    }

    display := layout.placeholder
    if sel >= 0 && sel < len(options) {
        display = options[sel]
    }
    ui_push_text_aligned(ctx, rect, display, ctx.theme.font_id, ctx.theme.font_size, ctx.theme.text_color, .Start, .Center)
    ui_push_text_aligned(ctx, rect, "v", ctx.theme.font_id, ctx.theme.font_size, ui_color_scale(ctx.theme.text_color, 0.8), .End, .Center)

    if !state.open {
        return selected_index, changed
    }

    pad := layout.padding
    if pad <= 0 do pad = ctx.theme.padding
    gap := layout.gap
    if gap < 0 do gap = 0
    item_h := layout.item_h
    if item_h <= 0 do item_h = ctx.theme.text_line_height + ctx.theme.padding * 0.8
    max_visible := layout.max_visible
    if max_visible <= 0 do max_visible = 6

    visible_count := len(options)
    if visible_count > max_visible do visible_count = max_visible

    list_h := f32(visible_count) * item_h + pad*2 + gap*f32(visible_count-1)
    list_rect := Rect{rect.x, rect.y + rect.h + gap, rect.w, list_h}

    if ctx.input.mouse_pressed && !ui_rect_contains(rect, ctx.input.mouse_pos) && !ui_rect_contains(list_rect, ctx.input.mouse_pos) {
        state.open = false
        return selected_index, changed
    }

    ui_panel(ctx, list_rect)
    scroll_opts := ui_scroll_options_default()
    scroll_opts.scrollbar_thickness = 6

    if len(options) > visible_count {
        ui_scroll_begin_state(ctx, list_rect, &state.scroll, pad, gap)
    } else {
        ui_layout_begin(ctx, list_rect, .Column, pad, gap)
    }

    for i := 0; i < len(options); i += 1 {
        item := options[i]
        row := ui_layout_next(ctx, 0, item_h)
        base := ctx.theme.panel_color
        if i == selected_index {
            base = ui_color_scale(base, 1.06)
        }
        id_label := strings.concatenate({label, "_", item})
        item_id := ui_id_from_string(id_label)
        delete(id_label)
        if ui_panel_interact(ctx, row, item_id, base) {
            sel = i
            changed = true
            state.open = false
        }
        ui_push_text_aligned(ctx, row, item, ctx.theme.font_id, ctx.theme.font_size, ctx.theme.text_color, .Start, .Center)
    }

    if len(options) > visible_count {
        ui_scroll_end_state(ctx, list_rect, &state.scroll, scroll_opts)
    } else {
        ui_layout_end(ctx)
    }

    if focused {
        if ctx.input.key_down && sel < len(options)-1 {
            sel += 1
            changed = true
        }
        if ctx.input.key_up && sel > 0 {
            sel -= 1
            changed = true
        }
        if ctx.input.key_enter && len(options) > 0 {
            state.open = false
        }
    }

    return sel, changed
}

ui_string_insert :: proc(target: ^string, index: int, insert: string) {
    if target == nil do return
    if insert == "" do return
    idx := index
    if idx < 0 do idx = 0
    if idx > len(target^) do idx = len(target^)
    prefix := target^[0:idx]
    suffix := target^[idx:]
    combined := strings.concatenate({prefix, insert, suffix})
    delete(target^)
    target^ = combined
}

ui_string_remove :: proc(target: ^string, index, count: int) {
    if target == nil do return
    if count <= 0 do return
    idx := index
    if idx < 0 do idx = 0
    if idx > len(target^) do idx = len(target^)
    end := idx + count
    if end > len(target^) do end = len(target^)
    prefix := target^[0:idx]
    suffix := target^[end:]
    combined := strings.concatenate({prefix, suffix})
    delete(target^)
    target^ = combined
}
