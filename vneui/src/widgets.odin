package vneui

ui_panel :: proc(ctx: ^UI_Context, rect: Rect) {
    ui_panel_color(ctx, rect, ctx.theme.panel_color)
}

ui_panel_layout :: proc(ctx: ^UI_Context, w, h: f32) {
    rect := ui_layout_next(ctx, w, h)
    ui_panel(ctx, rect)
}

ui_panel_style :: proc(ctx: ^UI_Context, rect: Rect, style: UI_Style) {
    ui_panel_color_style(ctx, rect, style.panel_color, style)
}

ui_panel_style_layout :: proc(ctx: ^UI_Context, style: UI_Style, w, h: f32) {
    rect := ui_layout_next(ctx, w, h)
    ui_panel_style(ctx, rect, style)
}

ui_panel_color :: proc(ctx: ^UI_Context, rect: Rect, fill: Color) {
    style := ui_style_from_theme(ctx.theme)
    ui_panel_color_style(ctx, rect, fill, style)
}

ui_panel_color_style :: proc(ctx: ^UI_Context, rect: Rect, fill: Color, style: UI_Style) {
    if style.shadow_enabled {
        shadow_rect := ui_rect_offset(rect, style.shadow_offset.x, style.shadow_offset.y)
        ui_push_rounded_rect(ctx, shadow_rect, style.corner_radius, style.shadow_color)
    }
    if style.border_width > 0 {
        ui_push_rounded_rect(ctx, rect, style.corner_radius, style.border_color)
        inner := ui_rect_inset(rect, style.border_width)
        radius := style.corner_radius - style.border_width
        if radius < 0 do radius = 0
        ui_push_rounded_rect(ctx, inner, radius, fill)
        return
    }
    ui_push_rounded_rect(ctx, rect, style.corner_radius, fill)
}

ui_panel_interact :: proc(ctx: ^UI_Context, rect: Rect, id: u64, base: Color) -> bool {
    allowed := ui_input_allowed(ctx, rect)
    hovered := allowed && ui_rect_contains(rect, ctx.input.mouse_pos)
    if hovered {
        ctx.hot_id = id
        if ctx.input.mouse_pressed {
            ctx.active_id = id
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

    color := base
    if ctx.hot_id == id {
        color = ui_color_scale(color, 1.06)
    }
    if ctx.active_id == id {
        color = ui_color_scale(color, 0.94)
    }

    ui_panel_color(ctx, rect, color)
    return clicked
}

ui_panel_interact_style :: proc(ctx: ^UI_Context, rect: Rect, id: u64, base: Color, style: UI_Style) -> bool {
    allowed := ui_input_allowed(ctx, rect)
    hovered := allowed && ui_rect_contains(rect, ctx.input.mouse_pos)
    if hovered {
        ctx.hot_id = id
        if ctx.input.mouse_pressed {
            ctx.active_id = id
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

    color := base
    if ctx.hot_id == id {
        color = ui_color_scale(color, 1.06)
    }
    if ctx.active_id == id {
        color = ui_color_scale(color, 0.94)
    }

    ui_panel_color_style(ctx, rect, color, style)
    return clicked
}

ui_panel_begin :: proc(ctx: ^UI_Context, rect: Rect, direction: UILayout_Direction, padding, gap: f32) {
    ui_panel(ctx, rect)
    ui_layout_begin(ctx, rect, direction, padding, gap)
}

ui_panel_end :: proc(ctx: ^UI_Context) {
    ui_layout_end(ctx)
}

ui_panel_begin_layout :: proc(ctx: ^UI_Context, w, h: f32, direction: UILayout_Direction, padding, gap: f32) {
    rect := ui_layout_next(ctx, w, h)
    ui_panel_begin(ctx, rect, direction, padding, gap)
}

ui_panel_begin_style :: proc(ctx: ^UI_Context, rect: Rect, style: UI_Style, direction: UILayout_Direction, padding, gap: f32) {
    ui_panel_style(ctx, rect, style)
    ui_layout_begin(ctx, rect, direction, padding, gap)
}

ui_panel_begin_style_layout :: proc(ctx: ^UI_Context, style: UI_Style, direction: UILayout_Direction, padding, gap: f32, w, h: f32) {
    rect := ui_layout_next(ctx, w, h)
    ui_panel_begin_style(ctx, rect, style, direction, padding, gap)
}

ui_label :: proc(ctx: ^UI_Context, rect: Rect, text: string) {
    ui_push_text_aligned(ctx, rect, text, ctx.theme.font_id, ctx.theme.font_size, ctx.theme.text_color, ctx.theme.text_align_h, ctx.theme.text_align_v)
}

ui_label_layout :: proc(ctx: ^UI_Context, text: string, w, h: f32) {
    rect := ui_layout_next(ctx, w, h)
    ui_label(ctx, rect, text)
}

ui_label_align :: proc(ctx: ^UI_Context, rect: Rect, text: string, align_h, align_v: UI_Align) {
    ui_push_text_aligned(ctx, rect, text, ctx.theme.font_id, ctx.theme.font_size, ctx.theme.text_color, align_h, align_v)
}

ui_label_align_layout :: proc(ctx: ^UI_Context, text: string, w, h: f32, align_h, align_v: UI_Align) {
    rect := ui_layout_next(ctx, w, h)
    ui_label_align(ctx, rect, text, align_h, align_v)
}

ui_label_wrap :: proc(ctx: ^UI_Context, rect: Rect, text: string) {
    ui_push_text_wrapped(ctx, rect, text, ctx.theme.font_id, ctx.theme.font_size, ctx.theme.text_color, ctx.theme.text_align_h, ctx.theme.text_align_v, ctx.theme.text_line_height)
}

ui_label_wrap_layout :: proc(ctx: ^UI_Context, text: string, w, h: f32) {
    rect := ui_layout_next(ctx, w, h)
    ui_label_wrap(ctx, rect, text)
}

ui_label_style :: proc(ctx: ^UI_Context, rect: Rect, text: string, style: UI_Style) {
    ui_push_text_aligned(ctx, rect, text, style.font_id, style.font_size, style.text_color, style.text_align_h, style.text_align_v)
}

ui_label_style_layout :: proc(ctx: ^UI_Context, text: string, style: UI_Style, w, h: f32) {
    rect := ui_layout_next(ctx, w, h)
    ui_label_style(ctx, rect, text, style)
}

ui_label_wrap_style :: proc(ctx: ^UI_Context, rect: Rect, text: string, style: UI_Style) {
    ui_push_text_wrapped(ctx, rect, text, style.font_id, style.font_size, style.text_color, style.text_align_h, style.text_align_v, style.text_line_height)
}

ui_label_wrap_style_layout :: proc(ctx: ^UI_Context, text: string, style: UI_Style, w, h: f32) {
    rect := ui_layout_next(ctx, w, h)
    ui_label_wrap_style(ctx, rect, text, style)
}

ui_button :: proc(ctx: ^UI_Context, rect: Rect, label: string) -> bool {
    id := ui_id_from_string(label)
    return ui_button_id(ctx, id, rect, label)
}

ui_button_id :: proc(ctx: ^UI_Context, id: u64, rect: Rect, label: string) -> bool {
    focused := ui_focus_register(ctx, id)
    allowed := ui_input_allowed(ctx, rect)
    hovered := allowed && ui_rect_contains(rect, ctx.input.mouse_pos)
    if hovered {
        ctx.hot_id = id
        if ctx.input.mouse_pressed {
            ctx.active_id = id
            ui_focus_set(ctx, id)
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
        color = ui_color_scale(color, 1.08)
    }
    if ctx.active_id == id {
        color = ui_color_scale(color, 0.92)
    }
    if focused {
        color = ui_color_scale(color, 1.05)
    }
    
    ui_panel_color(ctx, rect, color)
    ui_push_text_aligned(ctx, rect, label, ctx.theme.font_id, ctx.theme.font_size, ctx.theme.text_color, .Center, .Center)
    return clicked
}

ui_button_layout :: proc(ctx: ^UI_Context, label: string, w, h: f32) -> bool {
    rect := ui_layout_next(ctx, w, h)
    return ui_button(ctx, rect, label)
}

ui_button_style :: proc(ctx: ^UI_Context, rect: Rect, label: string, style: UI_Style) -> bool {
    id := ui_id_from_string(label)
    return ui_button_style_id(ctx, id, rect, label, style)
}

ui_button_style_id :: proc(ctx: ^UI_Context, id: u64, rect: Rect, label: string, style: UI_Style) -> bool {
    focused := ui_focus_register(ctx, id)
    allowed := ui_input_allowed(ctx, rect)
    hovered := allowed && ui_rect_contains(rect, ctx.input.mouse_pos)
    if hovered {
        ctx.hot_id = id
        if ctx.input.mouse_pressed {
            ctx.active_id = id
            ui_focus_set(ctx, id)
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
    
    color := style.panel_color
    if ctx.hot_id == id {
        color = ui_color_scale(color, 1.08)
    }
    if ctx.active_id == id {
        color = ui_color_scale(color, 0.92)
    }
    if focused {
        color = ui_color_scale(color, 1.05)
    }
    
    ui_panel_color_style(ctx, rect, color, style)
    ui_push_text_aligned(ctx, rect, label, style.font_id, style.font_size, style.text_color, .Center, .Center)
    return clicked
}

ui_button_style_layout :: proc(ctx: ^UI_Context, label: string, style: UI_Style, w, h: f32) -> bool {
    rect := ui_layout_next(ctx, w, h)
    return ui_button_style(ctx, rect, label, style)
}

ui_toggle :: proc(ctx: ^UI_Context, rect: Rect, value: bool, label: string) -> (bool, bool) {
    id := ui_id_from_string(label)
    return ui_toggle_id(ctx, id, rect, value, label)
}

ui_toggle_id :: proc(ctx: ^UI_Context, id: u64, rect: Rect, value: bool, label: string) -> (bool, bool) {
    focused := ui_focus_register(ctx, id)
    allowed := ui_input_allowed(ctx, rect)
    hovered := allowed && ui_rect_contains(rect, ctx.input.mouse_pos)
    if hovered {
        ctx.hot_id = id
        if ctx.input.mouse_pressed {
            ctx.active_id = id
            ui_focus_set(ctx, id)
            focused = true
        }
    }
    
    next_value := value
    changed := false
    if allowed && ctx.input.mouse_released {
        if ctx.active_id == id && hovered {
            next_value = !next_value
            changed = true
        }
        if ctx.active_id == id {
            ctx.active_id = 0
        }
    }
    if focused && ctx.input.nav_activate {
        next_value = !next_value
        changed = true
    }
    
    base := ctx.theme.panel_color
    if ctx.hot_id == id {
        base = ui_color_scale(base, 1.06)
    }
    if focused {
        base = ui_color_scale(base, 1.05)
    }
    ui_panel_color(ctx, rect, base)
    
    box := Rect{x = rect.x + ctx.theme.padding, y = rect.y + ctx.theme.padding, w = rect.h - ctx.theme.padding*2, h = rect.h - ctx.theme.padding*2}
    box_color := ui_color_scale(base, 0.9)
    ui_push_rounded_rect(ctx, box, ctx.theme.corner_radius, box_color)
    if next_value {
        inner := Rect{x = box.x + 4, y = box.y + 4, w = box.w - 8, h = box.h - 8}
        ui_push_rounded_rect(ctx, inner, ctx.theme.corner_radius, ctx.theme.accent_color)
    }
    
    text_rect := Rect{
        x = rect.x + rect.h + ctx.theme.padding,
        y = rect.y,
        w = rect.w - rect.h - ctx.theme.padding,
        h = rect.h,
    }
    ui_push_text_aligned(ctx, text_rect, label, ctx.theme.font_id, ctx.theme.font_size, ctx.theme.text_color, .Start, .Center)
    return next_value, changed
}

ui_toggle_layout :: proc(ctx: ^UI_Context, label: string, value: bool, w, h: f32) -> (bool, bool) {
    rect := ui_layout_next(ctx, w, h)
    return ui_toggle(ctx, rect, value, label)
}

ui_toggle_style :: proc(ctx: ^UI_Context, rect: Rect, value: bool, label: string, style: UI_Style) -> (bool, bool) {
    id := ui_id_from_string(label)
    return ui_toggle_style_id(ctx, id, rect, value, label, style)
}

ui_toggle_style_id :: proc(ctx: ^UI_Context, id: u64, rect: Rect, value: bool, label: string, style: UI_Style) -> (bool, bool) {
    focused := ui_focus_register(ctx, id)
    allowed := ui_input_allowed(ctx, rect)
    hovered := allowed && ui_rect_contains(rect, ctx.input.mouse_pos)
    if hovered {
        ctx.hot_id = id
        if ctx.input.mouse_pressed {
            ctx.active_id = id
            ui_focus_set(ctx, id)
            focused = true
        }
    }
    
    next_value := value
    changed := false
    if allowed && ctx.input.mouse_released {
        if ctx.active_id == id && hovered {
            next_value = !next_value
            changed = true
        }
        if ctx.active_id == id {
            ctx.active_id = 0
        }
    }
    if focused && ctx.input.nav_activate {
        next_value = !next_value
        changed = true
    }
    
    base := style.panel_color
    if ctx.hot_id == id {
        base = ui_color_scale(base, 1.06)
    }
    if focused {
        base = ui_color_scale(base, 1.05)
    }
    ui_panel_color_style(ctx, rect, base, style)
    
    box := Rect{x = rect.x + style.padding, y = rect.y + style.padding, w = rect.h - style.padding*2, h = rect.h - style.padding*2}
    box_color := ui_color_scale(base, 0.9)
    ui_push_rounded_rect(ctx, box, style.corner_radius, box_color)
    if next_value {
        inner := Rect{x = box.x + 4, y = box.y + 4, w = box.w - 8, h = box.h - 8}
        ui_push_rounded_rect(ctx, inner, style.corner_radius, style.accent_color)
    }
    
    text_rect := Rect{
        x = rect.x + rect.h + style.padding,
        y = rect.y,
        w = rect.w - rect.h - style.padding,
        h = rect.h,
    }
    ui_push_text_aligned(ctx, text_rect, label, style.font_id, style.font_size, style.text_color, .Start, .Center)
    return next_value, changed
}

ui_toggle_style_layout :: proc(ctx: ^UI_Context, label: string, value: bool, style: UI_Style, w, h: f32) -> (bool, bool) {
    rect := ui_layout_next(ctx, w, h)
    return ui_toggle_style(ctx, rect, value, label, style)
}

ui_slider :: proc(ctx: ^UI_Context, rect: Rect, value, min, max: f32) -> (f32, bool) {
    id := ui_gen_id(ctx)
    return ui_slider_id(ctx, id, rect, value, min, max)
}

ui_slider_id :: proc(ctx: ^UI_Context, id: u64, rect: Rect, value, min, max: f32) -> (f32, bool) {
    if max <= min do return value, false
    
    focused := ui_focus_register(ctx, id)
    allowed := ui_input_allowed(ctx, rect)
    hovered := allowed && ui_rect_contains(rect, ctx.input.mouse_pos)
    if hovered && ctx.input.mouse_pressed {
        ctx.active_id = id
        ui_focus_set(ctx, id)
        focused = true
    }
    
    next_value := value
    changed := false
    if allowed && ctx.active_id == id && ctx.input.mouse_down {
        t := (ctx.input.mouse_pos.x - rect.x) / rect.w
        t = ui_clamp_f32(t, 0, 1)
        new_value := min + t*(max-min)
        if new_value != next_value {
            next_value = new_value
            changed = true
        }
    }
    if allowed && ctx.input.mouse_released && ctx.active_id == id {
        ctx.active_id = 0
    }
    if focused {
        step := (max - min) * 0.02
        if step <= 0 do step = 1
        if ctx.input.key_left {
            next_value -= step
            changed = true
        }
        if ctx.input.key_right {
            next_value += step
            changed = true
        }
        next_value = ui_clamp_f32(next_value, min, max)
    }
    
    ui_panel_color(ctx, rect, ctx.theme.panel_color)
    t := (next_value - min) / (max - min)
    t = ui_clamp_f32(t, 0, 1)
    fill := Rect{x = rect.x, y = rect.y, w = rect.w * t, h = rect.h}
    ui_push_rounded_rect(ctx, fill, ctx.theme.corner_radius, ctx.theme.accent_color)
    
    handle_w := rect.h
    handle_x := rect.x + t*(rect.w - handle_w)
    handle := Rect{x = handle_x, y = rect.y, w = handle_w, h = rect.h}
    ui_push_rounded_rect(ctx, handle, ctx.theme.corner_radius, ui_color_scale(ctx.theme.panel_color, 0.9))
    return next_value, changed
}

ui_slider_layout :: proc(ctx: ^UI_Context, value, min, max: f32, w, h: f32) -> (f32, bool) {
    rect := ui_layout_next(ctx, w, h)
    return ui_slider(ctx, rect, value, min, max)
}

ui_slider_style :: proc(ctx: ^UI_Context, rect: Rect, value, min, max: f32, style: UI_Style) -> (f32, bool) {
    id := ui_gen_id(ctx)
    return ui_slider_style_id(ctx, id, rect, value, min, max, style)
}

ui_slider_style_id :: proc(ctx: ^UI_Context, id: u64, rect: Rect, value, min, max: f32, style: UI_Style) -> (f32, bool) {
    if max <= min do return value, false
    
    focused := ui_focus_register(ctx, id)
    allowed := ui_input_allowed(ctx, rect)
    hovered := allowed && ui_rect_contains(rect, ctx.input.mouse_pos)
    if hovered && ctx.input.mouse_pressed {
        ctx.active_id = id
        ui_focus_set(ctx, id)
        focused = true
    }
    
    next_value := value
    changed := false
    if allowed && ctx.active_id == id && ctx.input.mouse_down {
        t := (ctx.input.mouse_pos.x - rect.x) / rect.w
        t = ui_clamp_f32(t, 0, 1)
        new_value := min + t*(max-min)
        if new_value != next_value {
            next_value = new_value
            changed = true
        }
    }
    if allowed && ctx.input.mouse_released && ctx.active_id == id {
        ctx.active_id = 0
    }
    if focused {
        step := (max - min) * 0.02
        if step <= 0 do step = 1
        if ctx.input.key_left {
            next_value -= step
            changed = true
        }
        if ctx.input.key_right {
            next_value += step
            changed = true
        }
        next_value = ui_clamp_f32(next_value, min, max)
    }
    
    ui_panel_color_style(ctx, rect, style.panel_color, style)
    t := (next_value - min) / (max - min)
    t = ui_clamp_f32(t, 0, 1)
    fill := Rect{x = rect.x, y = rect.y, w = rect.w * t, h = rect.h}
    ui_push_rounded_rect(ctx, fill, style.corner_radius, style.accent_color)
    
    handle_w := rect.h
    handle_x := rect.x + t*(rect.w - handle_w)
    handle := Rect{x = handle_x, y = rect.y, w = handle_w, h = rect.h}
    ui_push_rounded_rect(ctx, handle, style.corner_radius, ui_color_scale(style.panel_color, 0.9))
    return next_value, changed
}

ui_slider_style_layout :: proc(ctx: ^UI_Context, value, min, max: f32, style: UI_Style, w, h: f32) -> (f32, bool) {
    rect := ui_layout_next(ctx, w, h)
    return ui_slider_style(ctx, rect, value, min, max, style)
}

ui_separator :: proc(ctx: ^UI_Context, rect: Rect, thickness: f32) {
    y := rect.y + rect.h * 0.5
    ui_push_line_thick(ctx, Vec2{rect.x, y}, Vec2{rect.x + rect.w, y}, thickness, ui_color_scale(ctx.theme.panel_color, 0.85))
}

ui_separator_layout :: proc(ctx: ^UI_Context, thickness: f32, w, h: f32) {
    rect := ui_layout_next(ctx, w, h)
    ui_separator(ctx, rect, thickness)
}

ui_image :: proc(ctx: ^UI_Context, rect: Rect, image_id: int) {
    ui_push_image(ctx, rect, image_id, Vec2{0, 0}, Vec2{1, 1}, ui_color(1, 1, 1, 1))
}

ui_image_layout :: proc(ctx: ^UI_Context, image_id: int, w, h: f32) {
    rect := ui_layout_next(ctx, w, h)
    ui_image(ctx, rect, image_id)
}
