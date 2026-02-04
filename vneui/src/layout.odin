package vneui

ui_layout_begin :: proc(ctx: ^UI_Context, rect: Rect, direction: UILayout_Direction, padding, gap: f32) {
    start := Vec2{rect.x + padding, rect.y + padding}
    lay := UILayout{
        rect = rect,
        cursor = start,
        gap = gap,
        padding = padding,
        direction = direction,
        content_max = start,
        scroll_offset = 0,
        grid_cols = 0,
        grid_gap = Vec2{0, 0},
        cell_w = 0,
        cell_h = 0,
        grid_index = 0,
    }
    append(&ctx.layouts, lay)
}

ui_layout_grid_begin :: proc(ctx: ^UI_Context, rect: Rect, cols: int, cell_w, cell_h, padding, gap_x, gap_y: f32) {
    ui_layout_begin(ctx, rect, .Grid, padding, 0)
    lay, ok := ui_layout_current(ctx)
    if !ok do return
    lay.grid_cols = cols
    lay.cell_w = cell_w
    lay.cell_h = cell_h
    lay.grid_gap = Vec2{gap_x, gap_y}
    lay.grid_index = 0
}

ui_layout_grid_begin_layout :: proc(ctx: ^UI_Context, w, h: f32, cols: int, cell_w, cell_h, padding, gap_x, gap_y: f32) {
    rect := ui_layout_next(ctx, w, h)
    ui_layout_grid_begin(ctx, rect, cols, cell_w, cell_h, padding, gap_x, gap_y)
}

ui_layout_end :: proc(ctx: ^UI_Context) {
    _, _ = ui_layout_pop(ctx)
}

ui_layout_pop :: proc(ctx: ^UI_Context) -> (UILayout, bool) {
    if len(ctx.layouts) == 0 do return UILayout{}, false
    last := pop(&ctx.layouts)
    return last, true
}

ui_layout_current :: proc(ctx: ^UI_Context) -> (^UILayout, bool) {
    if len(ctx.layouts) == 0 do return nil, false
    return &ctx.layouts[len(ctx.layouts)-1], true
}

ui_layout_next :: proc(ctx: ^UI_Context, w, h: f32) -> Rect {
    lay, ok := ui_layout_current(ctx)
    if !ok do return Rect{}
    
    avail_w := lay.rect.w - lay.padding*2
    avail_h := lay.rect.h - lay.padding*2
    rw := w
    rh := h

    rect := Rect{}
    switch lay.direction {
    case .Row:
        if rw <= 0 do rw = avail_w
        if rh <= 0 do rh = avail_h
        rect = Rect{x = lay.cursor.x, y = lay.cursor.y, w = rw, h = rh}
        lay.cursor.x += rw + lay.gap
    case .Column:
        if rw <= 0 do rw = avail_w
        if rh <= 0 do rh = avail_h
        rect = Rect{x = lay.cursor.x, y = lay.cursor.y, w = rw, h = rh}
        lay.cursor.y += rh + lay.gap
    case .Stack:
        if rw <= 0 do rw = avail_w
        if rh <= 0 do rh = avail_h
        rect = Rect{x = lay.cursor.x, y = lay.cursor.y, w = rw, h = rh}
    case .Grid:
        cols := lay.grid_cols
        if cols <= 0 do cols = 1
        col := lay.grid_index % cols
        row := lay.grid_index / cols
        cell_w := lay.cell_w
        cell_h := lay.cell_h
        if cell_w <= 0 do cell_w = avail_w / f32(cols)
        if cell_h <= 0 do cell_h = avail_h
        if rw > 0 do cell_w = rw
        if rh > 0 do cell_h = rh
        
        base_x := lay.rect.x + lay.padding
        base_y := lay.rect.y + lay.padding - lay.scroll_offset
        rect = Rect{
            x = base_x + f32(col)*(cell_w + lay.grid_gap.x),
            y = base_y + f32(row)*(cell_h + lay.grid_gap.y),
            w = cell_w,
            h = cell_h,
        }
        lay.grid_index += 1
    }
    
    right := rect.x + rect.w
    bottom := rect.y + rect.h
    if right > lay.content_max.x do lay.content_max.x = right
    if bottom > lay.content_max.y do lay.content_max.y = bottom
    return rect
}

ui_layout_space :: proc(ctx: ^UI_Context, amount: f32) {
    lay, ok := ui_layout_current(ctx)
    if !ok do return
    switch lay.direction {
    case .Row:
        lay.cursor.x += amount
    case .Column:
        lay.cursor.y += amount
    case .Stack:
        // No-op for stack.
    case .Grid:
        // No-op for grid spacing.
    }
}

ui_layout_content_size :: proc(lay: UILayout) -> Vec2 {
    origin_x := lay.rect.x + lay.padding
    origin_y := lay.rect.y + lay.padding - lay.scroll_offset
    w := lay.content_max.x - origin_x
    h := lay.content_max.y - origin_y
    if w < 0 do w = 0
    if h < 0 do h = 0
    return Vec2{w, h}
}
