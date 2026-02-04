package vneui

UI_Scroll_State :: struct {
    scroll_y: f32,
    velocity: f32,
    dragging: bool,
    drag_offset: f32,
    id: u64,
}

UI_Scroll_Options :: struct {
    speed: f32,
    momentum: bool,
    friction: f32,
    scrollbar: bool,
    scrollbar_thickness: f32,
    scrollbar_min_size: f32,
}

ui_scroll_options_default :: proc() -> UI_Scroll_Options {
    return UI_Scroll_Options{
        speed = UI_DEFAULT_SCROLL_SPEED,
        momentum = true,
        friction = 14,
        scrollbar = true,
        scrollbar_thickness = 8,
        scrollbar_min_size = 24,
    }
}

ui_scroll_begin_state :: proc(ctx: ^UI_Context, rect: Rect, state: ^UI_Scroll_State, padding, gap: f32) {
    if state == nil do return
    ui_push_scissor(ctx, rect)
    ui_layout_begin(ctx, rect, .Column, padding, gap)
    lay, ok := ui_layout_current(ctx)
    if ok {
        lay.scroll_offset = state.scroll_y
        lay.cursor.y -= state.scroll_y
    }
}

ui_scroll_end_state :: proc(ctx: ^UI_Context, rect: Rect, state: ^UI_Scroll_State, options: UI_Scroll_Options) -> f32 {
    if state == nil do return 0
    lay, ok := ui_layout_pop(ctx)
    ui_pop_scissor(ctx)
    if !ok do return state.scroll_y

    opts := options
    if opts.speed <= 0 do opts.speed = UI_DEFAULT_SCROLL_SPEED
    if opts.friction <= 0 do opts.friction = 14
    if opts.scrollbar_thickness <= 0 do opts.scrollbar_thickness = 8
    if opts.scrollbar_min_size <= 0 do opts.scrollbar_min_size = 24

    content := ui_layout_content_size(lay)
    view_h := rect.h - lay.padding*2
    max_scroll := content.y - view_h
    if max_scroll < 0 do max_scroll = 0

    allowed := ui_input_allowed(ctx, rect) && ui_rect_contains(rect, ctx.input.mouse_pos)

    if allowed && ctx.input.scroll_y != 0 {
        if opts.momentum {
            state.velocity += -ctx.input.scroll_y * opts.speed
        } else {
            state.scroll_y += -ctx.input.scroll_y * opts.speed
        }
    }

    if opts.momentum {
        dt := ctx.input.delta_time
        if dt <= 0 do dt = 0.016
        state.scroll_y += state.velocity
        state.velocity = ui_anim_step(state.velocity, 0, opts.friction, dt)
    }

    if state.scroll_y < 0 {
        state.scroll_y = 0
        state.velocity = 0
    } else if state.scroll_y > max_scroll {
        state.scroll_y = max_scroll
        state.velocity = 0
    }

    if opts.scrollbar && max_scroll > 0 {
        if state.id == 0 do state.id = ui_gen_id(ctx)
        track_x := rect.x + rect.w - opts.scrollbar_thickness
        track_y := rect.y + lay.padding
        track_h := view_h
        if track_h < 0 do track_h = 0

        track_rect := Rect{track_x, track_y, opts.scrollbar_thickness, track_h}

        handle_h := track_h * (view_h / content.y)
        if handle_h < opts.scrollbar_min_size do handle_h = opts.scrollbar_min_size
        if handle_h > track_h do handle_h = track_h
        span := track_h - handle_h
        handle_y := track_y
        if span > 0 {
            handle_y = track_y + (state.scroll_y / max_scroll) * span
        }
        handle_rect := Rect{track_x, handle_y, opts.scrollbar_thickness, handle_h}

        handle_hovered := ui_input_allowed(ctx, handle_rect) && ui_rect_contains(handle_rect, ctx.input.mouse_pos)
        if handle_hovered && ctx.input.mouse_pressed {
            ctx.active_id = state.id
            state.dragging = true
            state.drag_offset = ctx.input.mouse_pos.y - handle_rect.y
        }
        if ctx.input.mouse_released && ctx.active_id == state.id {
            ctx.active_id = 0
            state.dragging = false
        }
        if ctx.active_id == state.id && ctx.input.mouse_down {
            local_y := ctx.input.mouse_pos.y - state.drag_offset
            t := (local_y - track_y) / span
            t = ui_clamp_f32(t, 0, 1)
            state.scroll_y = t * max_scroll
            state.velocity = 0
        }

        track_col := ui_color_scale(ctx.theme.panel_color, 0.9)
        handle_col := ui_color_scale(ctx.theme.accent_color, 1.0)
        if handle_hovered || ctx.active_id == state.id {
            handle_col = ui_color_scale(handle_col, 1.1)
        }

        ui_push_rect(ctx, track_rect, track_col)
        ui_push_rect(ctx, handle_rect, handle_col)
    }

    return state.scroll_y
}
