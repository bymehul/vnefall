package vneui

UI_DEFAULT_SCROLL_SPEED :: 24.0

ui_scroll_begin :: proc(ctx: ^UI_Context, rect: Rect, scroll_y: f32, padding, gap: f32) {
    ui_push_scissor(ctx, rect)
    ui_layout_begin(ctx, rect, .Column, padding, gap)
    lay, ok := ui_layout_current(ctx)
    if ok {
        lay.scroll_offset = scroll_y
        lay.cursor.y -= scroll_y
    }
}

ui_scroll_end :: proc(ctx: ^UI_Context, rect: Rect, scroll_y: f32) -> f32 {
    lay, ok := ui_layout_pop(ctx)
    ui_pop_scissor(ctx)
    if !ok do return scroll_y
    
    content := ui_layout_content_size(lay)
    view_h := rect.h - lay.padding*2
    max_scroll := content.y - view_h
    if max_scroll < 0 do max_scroll = 0
    
    next_scroll := scroll_y
    if ui_input_allowed(ctx, rect) && ui_rect_contains(rect, ctx.input.mouse_pos) {
        next_scroll -= ctx.input.scroll_y * UI_DEFAULT_SCROLL_SPEED
    }
    next_scroll = ui_clamp_f32(next_scroll, 0, max_scroll)
    return next_scroll
}
