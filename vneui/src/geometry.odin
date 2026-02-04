package vneui

ui_rect_contains :: proc(r: Rect, p: Vec2) -> bool {
    if p.x < r.x do return false
    if p.y < r.y do return false
    if p.x > r.x + r.w do return false
    if p.y > r.y + r.h do return false
    return true
}

ui_rect_inset :: proc(r: Rect, pad: f32) -> Rect {
    w := r.w - pad*2
    h := r.h - pad*2
    if w < 0 do w = 0
    if h < 0 do h = 0
    return Rect{x = r.x + pad, y = r.y + pad, w = w, h = h}
}

ui_rect_expand :: proc(r: Rect, pad: f32) -> Rect {
    return Rect{x = r.x - pad, y = r.y - pad, w = r.w + pad*2, h = r.h + pad*2}
}

ui_rect_offset :: proc(r: Rect, dx, dy: f32) -> Rect {
    return Rect{x = r.x + dx, y = r.y + dy, w = r.w, h = r.h}
}

ui_rect_center :: proc(r: Rect, w, h: f32) -> Rect {
    return Rect{
        x = r.x + (r.w - w) * 0.5,
        y = r.y + (r.h - h) * 0.5,
        w = w,
        h = h,
    }
}
