package vneui

import "core:strings"

UI_Toast_Kind :: enum {
    Info,
    Success,
    Warning,
    Error,
}

UI_Toast :: struct {
    text: string,
    timer: f32,
    duration: f32,
    kind: UI_Toast_Kind,
}

UI_Tooltip :: struct {
    text: string,
    offset: Vec2,
    max_width: f32,
}

UI_Toast_Layout :: struct {
    padding: f32,
    gap: f32,
    max_width: f32,
    anchor_h: UI_Align,
    anchor_v: UI_Align,
}

UI_Transition_Kind :: enum {
    Fade,
    Slide_Left,
    Slide_Right,
    Slide_Up,
    Slide_Down,
}

UI_Transition :: struct {
    kind: UI_Transition_Kind,
    progress: f32,
    duration: f32,
    active: bool,
    reverse: bool,
}

UI_DEFAULT_TOAST_DURATION :: 2.6

ui_input_scope_begin :: proc(ctx: ^UI_Context, rect: Rect) {
    append(&ctx.input_scopes, rect)
}

ui_input_scope_end :: proc(ctx: ^UI_Context) {
    if len(ctx.input_scopes) == 0 do return
    _ = pop(&ctx.input_scopes)
}

ui_input_allowed :: proc(ctx: ^UI_Context, rect: Rect) -> bool {
    if len(ctx.input_scopes) == 0 do return true
    scope := ctx.input_scopes[len(ctx.input_scopes)-1]
    if !ui_rect_contains(scope, ctx.input.mouse_pos) do return false
    center := Vec2{rect.x + rect.w * 0.5, rect.y + rect.h * 0.5}
    if !ui_rect_contains(scope, center) do return false
    return true
}

ui_modal_overlay :: proc(ctx: ^UI_Context, rect: Rect, color: Color) {
    ui_push_rect(ctx, rect, color)
}

ui_modal_begin :: proc(ctx: ^UI_Context, rect: Rect, style: UI_Style, direction: UILayout_Direction, padding, gap: f32) {
    ui_input_scope_begin(ctx, rect)
    ui_panel_begin_style(ctx, rect, style, direction, padding, gap)
}

ui_modal_end :: proc(ctx: ^UI_Context) {
    ui_panel_end(ctx)
    ui_input_scope_end(ctx)
}

ui_tooltip_clear :: proc(ctx: ^UI_Context) {
    if ctx.tooltip.text != "" {
        delete(ctx.tooltip.text)
        ctx.tooltip.text = ""
    }
    ctx.tooltip.offset = Vec2{0, 0}
    ctx.tooltip.max_width = 0
}

ui_tooltip_set :: proc(ctx: ^UI_Context, text: string, offset: Vec2, max_width: f32) {
    ui_tooltip_clear(ctx)
    if text == "" do return
    ctx.tooltip.text = strings.clone(text)
    ctx.tooltip.offset = offset
    ctx.tooltip.max_width = max_width
}

ui_tooltip_register :: proc(ctx: ^UI_Context, rect: Rect, text: string) {
    if !ui_input_allowed(ctx, rect) do return
    if ui_rect_contains(rect, ctx.input.mouse_pos) {
        ui_tooltip_set(ctx, text, Vec2{12, 16}, 0)
    }
}

ui_tooltip_draw :: proc(ctx: ^UI_Context, bounds: Rect, style: UI_Style, max_width: f32) {
    if ctx.tooltip.text == "" do return

    width_limit := max_width
    if width_limit <= 0 {
        width_limit = ctx.tooltip.max_width
    }
    if width_limit <= 0 {
        width_limit = ctx.theme.font_size * 20
    }
    if width_limit > bounds.w do width_limit = bounds.w

    text_max := width_limit - style.padding*2
    if text_max < style.font_size * 2 {
        text_max = style.font_size * 2
    }

    ranges := ui_wrap_text_ranges(ctx, ctx.tooltip.text, text_max, style.font_id, style.font_size)
    line_count := len(ranges)
    delete(ranges)
    if line_count == 0 do return

    height := f32(line_count) * style.text_line_height + style.padding*2
    width := width_limit
    x := ctx.input.mouse_pos.x + ctx.tooltip.offset.x
    y := ctx.input.mouse_pos.y + ctx.tooltip.offset.y

    if x + width > bounds.x + bounds.w {
        x = bounds.x + bounds.w - width
    }
    if x < bounds.x do x = bounds.x
    if y + height > bounds.y + bounds.h {
        y = bounds.y + bounds.h - height
    }
    if y < bounds.y do y = bounds.y

    rect := Rect{x = x, y = y, w = width, h = height}
    fill := ui_color_scale(style.panel_color, 0.94)
    ui_panel_color_style(ctx, rect, fill, style)
    text_rect := ui_rect_inset(rect, style.padding)
    ui_push_text_wrapped(ctx, text_rect, ctx.tooltip.text, style.font_id, style.font_size, style.text_color, .Start, .Start, style.text_line_height)
}

ui_toasts_clear :: proc(ctx: ^UI_Context) {
    for i := 0; i < len(ctx.toasts); i += 1 {
        if ctx.toasts[i].text != "" {
            delete(ctx.toasts[i].text)
            ctx.toasts[i].text = ""
        }
    }
    clear(&ctx.toasts)
}

ui_toasts_update :: proc(ctx: ^UI_Context, dt: f32) {
    if dt <= 0 do return
    if len(ctx.toasts) == 0 do return

    out := 0
    for i := 0; i < len(ctx.toasts); i += 1 {
        toast := ctx.toasts[i]
        toast.timer -= dt
        if toast.timer > 0 {
            ctx.toasts[out] = toast
            out += 1
        } else if toast.text != "" {
            delete(toast.text)
        }
    }
    resize(&ctx.toasts, out)
}

ui_toast_push :: proc(ctx: ^UI_Context, text: string, duration: f32, kind: UI_Toast_Kind) {
    if text == "" do return
    d := duration
    if d <= 0 do d = UI_DEFAULT_TOAST_DURATION
    toast := UI_Toast{
        text = strings.clone(text),
        timer = d,
        duration = d,
        kind = kind,
    }
    append(&ctx.toasts, toast)
}

ui_toast_kind_color :: proc(style: UI_Style, kind: UI_Toast_Kind) -> Color {
    switch kind {
    case .Success:
        return ui_color_rgba8(88, 201, 126, 255)
    case .Warning:
        return ui_color_rgba8(240, 186, 86, 255)
    case .Error:
        return ui_color_rgba8(232, 92, 92, 255)
    case .Info:
        return style.accent_color
    }
    return style.accent_color
}

ui_toasts_draw :: proc(ctx: ^UI_Context, bounds: Rect, style: UI_Style, layout: UI_Toast_Layout) {
    if len(ctx.toasts) == 0 do return

    pad := layout.padding
    if pad <= 0 do pad = style.padding
    gap := layout.gap
    if gap <= 0 do gap = style.padding * 0.6
    max_w := layout.max_width
    if max_w <= 0 do max_w = bounds.w * 0.45
    if max_w < style.font_size * 8 do max_w = style.font_size * 8
    if max_w > bounds.w - pad*2 do max_w = bounds.w - pad*2

    cursor_y := bounds.y + pad
    if layout.anchor_v == .End {
        cursor_y = bounds.y + bounds.h - pad
    }

    for i := 0; i < len(ctx.toasts); i += 1 {
        toast := ctx.toasts[i]
        text_max := max_w - style.padding*2
        if text_max < style.font_size * 2 {
            text_max = style.font_size * 2
        }
        ranges := ui_wrap_text_ranges(ctx, toast.text, text_max, style.font_id, style.font_size)
        line_count := len(ranges)
        delete(ranges)
        if line_count == 0 do continue

        height := f32(line_count) * style.text_line_height + style.padding*2
        width := max_w
        x := bounds.x + pad
        if layout.anchor_h == .Center {
            x = bounds.x + (bounds.w - width) * 0.5
        } else if layout.anchor_h == .End {
            x = bounds.x + bounds.w - pad - width
        }

        y := cursor_y
        if layout.anchor_v == .End {
            y = cursor_y - height
        }

        alpha: f32 = 1
        fade_in := toast.duration * f32(0.12)
        fade_out := toast.duration * f32(0.2)
        elapsed := toast.duration - toast.timer
        if fade_in > 0 && elapsed < fade_in {
            alpha = elapsed / fade_in
        }
        if fade_out > 0 && toast.timer < fade_out {
            t := toast.timer / fade_out
            if t < alpha do alpha = t
        }

        rect := Rect{x = x, y = y, w = width, h = height}
        fill := ui_color_scale(style.panel_color, 0.98)
        fill.a *= alpha
        ui_panel_color_style(ctx, rect, fill, style)

        bar_w := style.border_width
        if bar_w < 2 do bar_w = 2
        bar := Rect{x = rect.x, y = rect.y, w = bar_w, h = rect.h}
        bar_color := ui_toast_kind_color(style, toast.kind)
        bar_color.a *= alpha
        ui_push_rect(ctx, bar, bar_color)

        text_rect := ui_rect_inset(rect, style.padding)
        text_color := style.text_color
        text_color.a *= alpha
        ui_push_text_wrapped(ctx, text_rect, toast.text, style.font_id, style.font_size, text_color, .Start, .Start, style.text_line_height)

        if layout.anchor_v == .End {
            cursor_y = y - gap
        } else {
            cursor_y = y + height + gap
        }
    }
}

ui_lerp :: proc(a, b, t: f32) -> f32 {
    return a + (b - a) * t
}

ui_smoothstep :: proc(t: f32) -> f32 {
    tt := ui_clamp_f32(t, 0, 1)
    return tt * tt * (3 - 2 * tt)
}

ui_anim_step :: proc(current, target, speed, dt: f32) -> f32 {
    if dt <= 0 do return current
    if speed <= 0 do return target
    t := ui_clamp_f32(speed * dt, 0, 1)
    return current + (target - current) * t
}

ui_transition_begin :: proc(t: ^UI_Transition, kind: UI_Transition_Kind, duration: f32, reverse: bool) {
    t.kind = kind
    t.duration = duration
    t.reverse = reverse
    t.active = true
    if reverse {
        t.progress = 1
    } else {
        t.progress = 0
    }
}

ui_transition_update :: proc(t: ^UI_Transition, dt: f32) -> f32 {
    if !t.active do return t.progress
    if t.duration <= 0 {
        t.progress = 1
        t.active = false
        return t.progress
    }
    step := dt / t.duration
    if t.reverse {
        t.progress -= step
        if t.progress <= 0 {
            t.progress = 0
            t.active = false
        }
    } else {
        t.progress += step
        if t.progress >= 1 {
            t.progress = 1
            t.active = false
        }
    }
    return t.progress
}

ui_transition_apply_rect :: proc(rect: Rect, kind: UI_Transition_Kind, progress: f32) -> Rect {
    t := ui_smoothstep(progress)
    switch kind {
    case .Slide_Left:
        return ui_rect_offset(rect, -rect.w * (1 - t), 0)
    case .Slide_Right:
        return ui_rect_offset(rect, rect.w * (1 - t), 0)
    case .Slide_Up:
        return ui_rect_offset(rect, 0, -rect.h * (1 - t))
    case .Slide_Down:
        return ui_rect_offset(rect, 0, rect.h * (1 - t))
    case .Fade:
        return rect
    }
    return rect
}

ui_transition_draw_fade :: proc(ctx: ^UI_Context, rect: Rect, color: Color, progress: f32) {
    c := color
    c.a *= ui_clamp_f32(progress, 0, 1)
    ui_push_rect(ctx, rect, c)
}
