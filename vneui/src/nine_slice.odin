package vneui

UI_Insets :: struct {
    left: f32,
    top: f32,
    right: f32,
    bottom: f32,
}

ui_insets :: proc(left, top, right, bottom: f32) -> UI_Insets {
    return UI_Insets{left, top, right, bottom}
}

ui_image_nine_slice :: proc(ctx: ^UI_Context, rect: Rect, image_id: int, tex_w, tex_h: f32, border: UI_Insets, tint: Color) {
    ui_image_nine_slice_uv(ctx, rect, image_id, Vec2{0, 0}, Vec2{1, 1}, tex_w, tex_h, border, tint)
}

ui_image_nine_slice_uv :: proc(ctx: ^UI_Context, rect: Rect, image_id: int, uv0, uv1: Vec2, tex_w, tex_h: f32, border: UI_Insets, tint: Color) {
    if rect.w <= 0 || rect.h <= 0 do return

    left := border.left
    right := border.right
    top := border.top
    bottom := border.bottom

    if left + right > rect.w {
        scale := rect.w / (left + right)
        left *= scale
        right *= scale
    }
    if top + bottom > rect.h {
        scale := rect.h / (top + bottom)
        top *= scale
        bottom *= scale
    }

    u_left: f32 = 0
    u_right: f32 = 0
    v_top: f32 = 0
    v_bottom: f32 = 0
    if tex_w > 0 && tex_h > 0 {
        u_span := uv1.x - uv0.x
        v_span := uv1.y - uv0.y
        u_left = u_span * (border.left / tex_w)
        u_right = u_span * (border.right / tex_w)
        v_top = v_span * (border.top / tex_h)
        v_bottom = v_span * (border.bottom / tex_h)
    }

    x0 := rect.x
    x1 := rect.x + left
    x2 := rect.x + rect.w - right
    x3 := rect.x + rect.w

    y0 := rect.y
    y1 := rect.y + top
    y2 := rect.y + rect.h - bottom
    y3 := rect.y + rect.h

    u0 := uv0.x
    u1 := uv0.x + u_left
    u2 := uv1.x - u_right
    u3 := uv1.x

    v0 := uv0.y
    v1 := uv0.y + v_top
    v2 := uv1.y - v_bottom
    v3 := uv1.y

    // Top row
    ui_push_image(ctx, Rect{x0, y0, x1 - x0, y1 - y0}, image_id, Vec2{u0, v0}, Vec2{u1, v1}, tint)
    ui_push_image(ctx, Rect{x1, y0, x2 - x1, y1 - y0}, image_id, Vec2{u1, v0}, Vec2{u2, v1}, tint)
    ui_push_image(ctx, Rect{x2, y0, x3 - x2, y1 - y0}, image_id, Vec2{u2, v0}, Vec2{u3, v1}, tint)
    // Middle row
    ui_push_image(ctx, Rect{x0, y1, x1 - x0, y2 - y1}, image_id, Vec2{u0, v1}, Vec2{u1, v2}, tint)
    ui_push_image(ctx, Rect{x1, y1, x2 - x1, y2 - y1}, image_id, Vec2{u1, v1}, Vec2{u2, v2}, tint)
    ui_push_image(ctx, Rect{x2, y1, x3 - x2, y2 - y1}, image_id, Vec2{u2, v1}, Vec2{u3, v2}, tint)
    // Bottom row
    ui_push_image(ctx, Rect{x0, y2, x1 - x0, y3 - y2}, image_id, Vec2{u0, v2}, Vec2{u1, v3}, tint)
    ui_push_image(ctx, Rect{x1, y2, x2 - x1, y3 - y2}, image_id, Vec2{u1, v2}, Vec2{u2, v3}, tint)
    ui_push_image(ctx, Rect{x2, y2, x3 - x2, y3 - y2}, image_id, Vec2{u2, v2}, Vec2{u3, v3}, tint)
}
