package vnefall

import "core:strings"
import "core:math"
import vneui "vneui:src"
import gl "vendor:OpenGL"

ui_ctx: vneui.UI_Context

ui_layer_init :: proc() {
    vneui.ui_init(&ui_ctx)
    ui_ctx.measure_text = ui_measure_text
}

ui_layer_shutdown :: proc() {
    vneui.ui_shutdown(&ui_ctx)
}

ui_measure_text :: proc(text: string, font_id: int, font_size: f32) -> f32 {
    _ = font_id
    size := font_size
    if size <= 0 do size = f32(FONT_SIZE)
    scale := size / f32(FONT_SIZE)
    return font_text_width(text) * scale
}

ui_theme_from_config :: proc() -> vneui.UI_Theme {
    theme := vneui.ui_theme_default(0, ui_cfg.theme_font_size)
    theme.text_color = ui_color_from_rgba(ui_cfg.theme_text_color)
    theme.panel_color = ui_color_from_rgba(ui_cfg.theme_panel_color)
    theme.accent_color = ui_color_from_rgba(ui_cfg.theme_accent_color)
    theme.border_color = ui_color_from_rgba(ui_cfg.theme_border_color)
    theme.shadow_color = ui_color_from_rgba(ui_cfg.theme_shadow_color)
    theme.border_width = ui_cfg.theme_border_width
    theme.text_line_height = ui_cfg.theme_text_line_h
    theme.padding = ui_cfg.theme_padding
    theme.corner_radius = ui_cfg.theme_corner_radius
    theme.shadow_offset = vneui.Vec2{ui_cfg.theme_shadow_offset_x, ui_cfg.theme_shadow_offset_y}
    theme.shadow_enabled = ui_cfg.theme_shadow_enabled
    return theme
}

ui_color_from_rgba :: proc(c: [4]f32) -> vneui.Color {
    return vneui.Color{c[0], c[1], c[2], c[3]}
}

ui_layer_build_and_render :: proc(g: ^Game_State, r: ^Renderer, w: ^Window, dt: f32) {
    input := ui_input_from_game(g, w, dt)
    theme := ui_theme_from_config()
    vneui.ui_begin_frame(&ui_ctx, input, theme)

    if !g.menu.active && g.textbox.visible {
        ui_layer_draw_textbox(&ui_ctx, theme, &g.textbox, g.textbox_tex)
    }

    if !g.menu.active && g.choice.active {
        ui_layer_draw_choice_menu(&ui_ctx, theme, g)
    }

    if g.menu.active {
        ui_layer_draw_menu(&ui_ctx, theme, g)
    }

    cmds := vneui.ui_end_frame(&ui_ctx)
    ui_render_commands(r, w, cmds)
}

ui_input_from_game :: proc(g: ^Game_State, w: ^Window, dt: f32) -> vneui.UI_Input {
    mx := f32(g.input.mouse_x) * (cfg.design_width / f32(w.width))
    my := f32(g.input.mouse_y) * (cfg.design_height / f32(w.height))

    return vneui.UI_Input{
        mouse_pos = vneui.Vec2{mx, my},
        mouse_down = g.input.mouse_down,
        mouse_pressed = g.input.mouse_pressed,
        mouse_released = g.input.mouse_released,
        scroll_y = g.input.scroll_y,
        delta_time = dt,
        text_input = "",
        key_backspace = false,
        key_delete = false,
        key_enter = false,
        key_left = false,
        key_right = false,
        key_up = g.input.up_pressed,
        key_down = g.input.down_pressed,
        key_home = false,
        key_end = false,
        nav_next = g.input.down_pressed,
        nav_prev = g.input.up_pressed,
        nav_activate = g.input.select_pressed && !g.input.mouse_pressed,
        nav_cancel = false,
    }
}

ui_layer_draw_textbox :: proc(ctx: ^vneui.UI_Context, theme: vneui.UI_Theme, tb: ^Textbox_State, bg_tex: u32) {
    h  := ui_cfg.textbox_height
    m  := ui_cfg.textbox_margin
    p  := ui_cfg.textbox_padding
    bx := m
    by := cfg.design_height - h - m
    anchor := strings.to_lower(ui_cfg.textbox_anchor)
    defer delete(anchor)
    if anchor == "top" {
        by = m
    } else if anchor == "center" {
        by = (cfg.design_height - h) * 0.5
    }
    bw := cfg.design_width - (m * 2)

    rect := vneui.Rect{bx, by, bw, h}

    if bg_tex != 0 {
        tint := vneui.ui_color(1, 1, 1, ui_cfg.textbox_alpha)
        vneui.ui_push_image(ctx, rect, int(bg_tex), vneui.Vec2{0, 0}, vneui.Vec2{1, 1}, tint)
    } else {
        style := vneui.ui_style_from_theme(theme)
        style.panel_color = ui_color_from_rgba(ui_cfg.theme_panel_color)
        style.panel_color.a = ui_cfg.textbox_alpha
        vneui.ui_panel_color_style(ctx, rect, style.panel_color, style)
    }

    inner := vneui.Rect{bx + p, by + p, bw - (p * 2), h - (p * 2)}
    ty := inner.y

    speaker_col := ui_cfg.speaker_color
    text_col := ui_cfg.text_color
    if tb.speaker != "" {
        if style, ok := char_style_for(tb.speaker); ok {
            speaker_col = style.name_color
            text_col = style.text_color
        }
        speaker_rect := vneui.Rect{inner.x, ty, inner.w, theme.text_line_height}
        vneui.ui_push_text_aligned(ctx, speaker_rect, tb.speaker, theme.font_id, theme.font_size, ui_color_from_rgba(speaker_col), .Start, .Center)
        ty += theme.text_line_height
    }

    body_rect := vneui.Rect{inner.x, ty, inner.w, inner.h - (ty - inner.y)}
    if tb.shake && ui_cfg.text_shake_px > 0 {
        shake_x := math.sin(ctx.time * 40) * ui_cfg.text_shake_px
        shake_y := math.cos(ctx.time * 35) * ui_cfg.text_shake_px
        body_rect.x += shake_x
        body_rect.y += shake_y
    }

    if len(tb.shown_segments) > 0 {
        ui_draw_text_segments_wrapped(ctx, body_rect, tb.shown_segments[:], ui_color_from_rgba(text_col), theme)
    }
}

Text_Token :: struct {
    text: string,
    color: [4]f32,
    has_color: bool,
    is_newline: bool,
}

ui_draw_text_segments_wrapped :: proc(ctx: ^vneui.UI_Context, rect: vneui.Rect, segments: []Text_Segment, base_color: vneui.Color, theme: vneui.UI_Theme) {
    tokens: [dynamic]Text_Token
    defer {
        for t in tokens {
            if t.text != "" do delete(t.text)
        }
        delete(tokens)
    }

    // Tokenize (split by spaces/newlines, preserve spaces)
    for seg in segments {
        if seg.text == "" do continue
        start := 0
        i := 0
        for i < len(seg.text) {
            ch := seg.text[i]
            if ch == ' ' || ch == '\n' {
                if i > start {
                    slice := seg.text[start:i]
                    append(&tokens, Text_Token{
                        text = strings.clone(slice),
                        color = seg.color,
                        has_color = seg.has_color,
                    })
                }
                if ch == ' ' {
                    append(&tokens, Text_Token{
                        text = strings.clone(" "),
                        color = seg.color,
                        has_color = seg.has_color,
                    })
                } else {
                    append(&tokens, Text_Token{is_newline = true})
                }
                i += 1
                start = i
                continue
            }
            i += 1
        }
        if start < len(seg.text) {
            slice := seg.text[start:]
            append(&tokens, Text_Token{
                text = strings.clone(slice),
                color = seg.color,
                has_color = seg.has_color,
            })
        }
    }

    line_height := theme.text_line_height
    if line_height <= 0 do line_height = theme.font_size * 1.2

    x := rect.x
    y := rect.y
    line_w: f32 = 0

    for t in tokens {
        if t.is_newline {
            x = rect.x
            y += line_height
            line_w = 0
            continue
        }
        if t.text == "" do continue

        // Skip leading spaces
        if line_w == 0 && t.text == " " {
            continue
        }

        token_w := vneui.ui_measure_text(ctx, t.text, theme.font_id, theme.font_size)
        if line_w > 0 && line_w + token_w > rect.w {
            x = rect.x
            y += line_height
            line_w = 0
            if t.text == " " do continue
        }

        use_col := base_color
        if t.has_color {
            use_col = ui_color_from_rgba(t.color)
        }
        token_rect := vneui.Rect{x, y, token_w, line_height}
        vneui.ui_push_text_aligned(ctx, token_rect, t.text, theme.font_id, theme.font_size, use_col, .Start, .Center)
        x += token_w
        line_w += token_w
    }
}

ui_layer_draw_choice_menu :: proc(ctx: ^vneui.UI_Context, theme: vneui.UI_Theme, g: ^Game_State) {
    count := len(g.choice.options)
    if count == 0 do return

    button_w := ui_cfg.choice_w
    button_h := ui_cfg.choice_h
    spacing  := ui_cfg.choice_spacing

    total_h := f32(count) * button_h + f32(count - 1) * spacing
    start_y := (cfg.design_height - total_h) / 2
    x       := (cfg.design_width - button_w) / 2

    for opt, i in g.choice.options {
        rect := vneui.Rect{x, start_y + f32(i) * (button_h + spacing), button_w, button_h}
        id := vneui.ui_id_from_string(opt.label)
        selected := i == g.choice.selected
        clicked, hovered, focused := ui_choice_button(ctx, theme, rect, id, opt.text, selected, g.choice_tex_idle, g.choice_tex_hov)

        if hovered || focused {
            g.choice.selected = i
        }
        if clicked {
            choice_apply(g, i)
            break
        }
    }
}

ui_choice_button :: proc(ctx: ^vneui.UI_Context, theme: vneui.UI_Theme, rect: vneui.Rect, id: u64, label: string, selected: bool, tex_idle, tex_hov: u32) -> (bool, bool, bool) {
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

    active_state := hovered || focused || selected || ctx.active_id == id
    bg_color := ui_color_from_rgba(ui_cfg.choice_color_idle)
    text_color := ui_color_from_rgba(ui_cfg.choice_text_idle)
    use_tex := tex_idle
    if active_state {
        bg_color = ui_color_from_rgba(ui_cfg.choice_color_hov)
        text_color = ui_color_from_rgba(ui_cfg.choice_text_hov)
        if tex_hov != 0 {
            use_tex = tex_hov
        }
    }

    if use_tex != 0 {
        tint := vneui.ui_color(1, 1, 1, ui_cfg.choice_image_alpha)
        vneui.ui_push_image(ctx, rect, int(use_tex), vneui.Vec2{0, 0}, vneui.Vec2{1, 1}, tint)
    } else {
        style := vneui.ui_style_from_theme(theme)
        style.panel_color = bg_color
        vneui.ui_panel_color_style(ctx, rect, bg_color, style)
    }

    vneui.ui_push_text_aligned(ctx, rect, label, theme.font_id, theme.font_size, text_color, .Center, .Center)
    return clicked, hovered, focused
}

choice_apply :: proc(g: ^Game_State, index: int) {
    if index < 0 || index >= len(g.choice.options) do return
    choice := g.choice.options[index]
    target_label := strings.clone(choice.label)
    defer delete(target_label)

    choice_clear(g)
    g.choice.active = false

    if target, ok := g.script.labels[target_label]; ok {
        g.script.ip = target
        g.script.waiting = false
        g.textbox.visible = false
    }
}

ui_render_commands :: proc(r: ^Renderer, w: ^Window, cmds: []vneui.Draw_Command) {
    scissor_stack: [16]vneui.Rect
    stack_len := 0

    sx := f32(w.width) / cfg.design_width
    sy := f32(w.height) / cfg.design_height

    for cmd in cmds {
        switch cmd.kind {
        case .Rect:
            renderer_draw_rect(r, cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h, {cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a})
        case .Rounded_Rect:
            renderer_draw_rect(r, cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h, {cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a})
        case .Line:
            ui_render_line(r, cmd)
        case .Text:
            ui_render_text(r, cmd)
        case .Image:
            renderer_draw_texture_tinted(r, u32(cmd.image_id), cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h, {cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a})
        case .Scissor_Push:
            scissor := cmd.rect
            if stack_len > 0 {
                scissor = ui_rect_intersect(scissor_stack[stack_len-1], scissor)
            }
            if stack_len < len(scissor_stack) {
                scissor_stack[stack_len] = scissor
                stack_len += 1
            }
            ui_apply_scissor(scissor, sx, sy)
        case .Scissor_Pop:
            if stack_len > 0 {
                stack_len -= 1
            }
            if stack_len > 0 {
                ui_apply_scissor(scissor_stack[stack_len-1], sx, sy)
            } else {
                gl.Disable(gl.SCISSOR_TEST)
            }
        }
    }

    if stack_len > 0 {
        gl.Disable(gl.SCISSOR_TEST)
    }
}

ui_render_line :: proc(r: ^Renderer, cmd: vneui.Draw_Command) {
    dx := cmd.p1.x - cmd.p0.x
    dy := cmd.p1.y - cmd.p0.y
    if dx == 0 {
        y0 := min(cmd.p0.y, cmd.p1.y)
        renderer_draw_rect(r, cmd.p0.x, y0, cmd.thickness, abs(dy), {cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a})
    } else if dy == 0 {
        x0 := min(cmd.p0.x, cmd.p1.x)
        renderer_draw_rect(r, x0, cmd.p0.y, abs(dx), cmd.thickness, {cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a})
    }
}

ui_render_text :: proc(r: ^Renderer, cmd: vneui.Draw_Command) {
    if cmd.text == "" do return
    size := cmd.font_size
    if size <= 0 do size = f32(FONT_SIZE)
    scale := size / f32(FONT_SIZE)
    text_w := font_text_width(cmd.text) * scale
    x := cmd.rect.x
    switch cmd.align_h {
    case .Center:
        x = cmd.rect.x + (cmd.rect.w - text_w) * 0.5
    case .End:
        x = cmd.rect.x + cmd.rect.w - text_w
    case .Start:
        x = cmd.rect.x
    }

    // Baseline nudge: stbtt baked quads sit a bit high without this.
    baseline_nudge := size * 0.2
    if baseline_nudge < 1 do baseline_nudge = 1
    if baseline_nudge > 6 do baseline_nudge = 6

    y := cmd.rect.y + size - baseline_nudge
    switch cmd.align_v {
    case .Center:
        y = cmd.rect.y + (cmd.rect.h + size) * 0.5 - baseline_nudge
    case .End:
        y = cmd.rect.y + cmd.rect.h - baseline_nudge
    case .Start:
        y = cmd.rect.y + size - baseline_nudge
    }

    renderer_draw_text(r, cmd.text, x, y, {cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a})
}

ui_apply_scissor :: proc(rect: vneui.Rect, sx, sy: f32) {
    gl.Enable(gl.SCISSOR_TEST)
    sc_x := i32(rect.x * sx)
    sc_w := i32(rect.w * sx)
    sc_h := i32(rect.h * sy)
    sc_y := i32((cfg.design_height - (rect.y + rect.h)) * sy)
    if sc_w < 0 do sc_w = 0
    if sc_h < 0 do sc_h = 0
    gl.Scissor(sc_x, sc_y, sc_w, sc_h)
}

ui_rect_intersect :: proc(a, b: vneui.Rect) -> vneui.Rect {
    x0 := max(a.x, b.x)
    y0 := max(a.y, b.y)
    x1 := min(a.x + a.w, b.x + b.w)
    y1 := min(a.y + a.h, b.y + b.h)
    if x1 < x0 do x1 = x0
    if y1 < y0 do y1 = y0
    return vneui.Rect{x0, y0, x1 - x0, y1 - y0}
}
