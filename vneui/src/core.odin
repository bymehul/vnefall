package vneui

ui_init :: proc(ctx: ^UI_Context) {
    ctx.commands = make([dynamic]Draw_Command)
    ctx.layouts = make([dynamic]UILayout)
    ctx.input_scopes = make([dynamic]Rect)
    ctx.toasts = make([dynamic]UI_Toast)
    ctx.focus_order = make([dynamic]u64)
    ctx.focus_order_prev = make([dynamic]u64)
}

ui_shutdown :: proc(ctx: ^UI_Context) {
    ui_clear_text(ctx)
    ui_tooltip_clear(ctx)
    ui_toasts_clear(ctx)
    delete(ctx.commands)
    delete(ctx.layouts)
    delete(ctx.input_scopes)
    delete(ctx.toasts)
    delete(ctx.focus_order)
    delete(ctx.focus_order_prev)
}

ui_begin_frame :: proc(ctx: ^UI_Context, input: UI_Input, theme: UI_Theme) {
    ui_clear_text(ctx)
    ui_tooltip_clear(ctx)
    ui_toasts_update(ctx, input.delta_time)
    ctx.input = input
    ctx.theme = theme
    ctx.hot_id = 0
    ctx.last_id = 0
    ctx.time += input.delta_time
    clear(&ctx.layouts)
    clear(&ctx.commands)
    clear(&ctx.input_scopes)

    // Swap focus order buffers for keyboard navigation.
    prev := ctx.focus_order_prev
    ctx.focus_order_prev = ctx.focus_order
    ctx.focus_order = prev
    clear(&ctx.focus_order)

    ui_focus_apply_nav(ctx)
}

ui_end_frame :: proc(ctx: ^UI_Context) -> []Draw_Command {
    if ctx.input.mouse_released {
        ctx.active_id = 0
    }
    return ctx.commands[:]
}

ui_clear_text :: proc(ctx: ^UI_Context) {
    // Free any cloned text stored in commands.
    for i := 0; i < len(ctx.commands); i += 1 {
        if ctx.commands[i].kind == .Text && ctx.commands[i].text != "" {
            delete(ctx.commands[i].text)
            ctx.commands[i].text = ""
        }
    }
}

ui_id_from_string :: proc(label: string) -> u64 {
    // FNV-1a 64-bit
    hash: u64 = 14695981039346656037
    for i := 0; i < len(label); i += 1 {
        hash ~= u64(label[i])
        hash *= 1099511628211
    }
    return hash
}

ui_gen_id :: proc(ctx: ^UI_Context) -> u64 {
    ctx.last_id += 1
    return ctx.last_id
}

ui_measure_text :: proc(ctx: ^UI_Context, text: string, font_id: int, font_size: f32) -> f32 {
    if ctx.measure_text != nil {
        return ctx.measure_text(text, font_id, font_size)
    }
    // Fallback: approximate width based on character count.
    return f32(len(text)) * font_size * 0.55
}

ui_clamp_f32 :: proc(v, lo, hi: f32) -> f32 {
    if v < lo do return lo
    if v > hi do return hi
    return v
}

ui_color_scale :: proc(c: Color, s: f32) -> Color {
    return Color{
        r = ui_clamp_f32(c.r * s, 0, 1),
        g = ui_clamp_f32(c.g * s, 0, 1),
        b = ui_clamp_f32(c.b * s, 0, 1),
        a = c.a,
    }
}

ui_color :: proc(r, g, b, a: f32) -> Color {
    return Color{r, g, b, a}
}

ui_color_rgba8 :: proc(r, g, b, a: u8) -> Color {
    return Color{
        r = f32(r) / 255.0,
        g = f32(g) / 255.0,
        b = f32(b) / 255.0,
        a = f32(a) / 255.0,
    }
}

ui_theme_default :: proc(font_id: int, font_size: f32) -> UI_Theme {
    return UI_Theme{
        text_color = ui_color_rgba8(235, 235, 235, 255),
        panel_color = ui_color_rgba8(40, 40, 46, 255),
        accent_color = ui_color_rgba8(90, 180, 255, 255),
        border_color = ui_color_rgba8(18, 18, 20, 255),
        border_width = 1,
        font_id = font_id,
        font_size = font_size,
        text_line_height = font_size * 1.2,
        padding = 10,
        corner_radius = 6,
        text_align_h = .Start,
        text_align_v = .Center,
        shadow_color = ui_color_rgba8(0, 0, 0, 120),
        shadow_offset = Vec2{0, 2},
        shadow_enabled = true,
    }
}

ui_style_from_theme :: proc(theme: UI_Theme) -> UI_Style {
    return UI_Style{
        text_color = theme.text_color,
        panel_color = theme.panel_color,
        accent_color = theme.accent_color,
        border_color = theme.border_color,
        border_width = theme.border_width,
        font_id = theme.font_id,
        font_size = theme.font_size,
        text_line_height = theme.text_line_height,
        padding = theme.padding,
        corner_radius = theme.corner_radius,
        text_align_h = theme.text_align_h,
        text_align_v = theme.text_align_v,
        shadow_color = theme.shadow_color,
        shadow_offset = theme.shadow_offset,
        shadow_enabled = theme.shadow_enabled,
    }
}
