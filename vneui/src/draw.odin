package vneui

import "core:strings"

ui_push_rect :: proc(ctx: ^UI_Context, rect: Rect, color: Color) {
    cmd := Draw_Command{kind = .Rect, rect = rect, color = color}
    append(&ctx.commands, cmd)
}

ui_push_rounded_rect :: proc(ctx: ^UI_Context, rect: Rect, radius: f32, color: Color) {
    cmd := Draw_Command{kind = .Rounded_Rect, rect = rect, radius = radius, color = color}
    append(&ctx.commands, cmd)
}

ui_push_line :: proc(ctx: ^UI_Context, p0, p1: Vec2, color: Color) {
    cmd := Draw_Command{kind = .Line, p0 = p0, p1 = p1, color = color, thickness = 1}
    append(&ctx.commands, cmd)
}

ui_push_line_thick :: proc(ctx: ^UI_Context, p0, p1: Vec2, thickness: f32, color: Color) {
    cmd := Draw_Command{kind = .Line, p0 = p0, p1 = p1, color = color, thickness = thickness}
    append(&ctx.commands, cmd)
}

ui_push_border :: proc(ctx: ^UI_Context, rect: Rect, thickness: f32, color: Color) {
    if thickness <= 0 do return
    top := Rect{x = rect.x, y = rect.y, w = rect.w, h = thickness}
    bottom := Rect{x = rect.x, y = rect.y + rect.h - thickness, w = rect.w, h = thickness}
    left := Rect{x = rect.x, y = rect.y + thickness, w = thickness, h = rect.h - thickness*2}
    right := Rect{x = rect.x + rect.w - thickness, y = rect.y + thickness, w = thickness, h = rect.h - thickness*2}
    ui_push_rect(ctx, top, color)
    ui_push_rect(ctx, bottom, color)
    ui_push_rect(ctx, left, color)
    ui_push_rect(ctx, right, color)
}

ui_push_text :: proc(ctx: ^UI_Context, rect: Rect, text: string, font_id: int, font_size: f32, color: Color) {
    ui_push_text_aligned(ctx, rect, text, font_id, font_size, color, .Start, .Center)
}

ui_push_text_aligned :: proc(ctx: ^UI_Context, rect: Rect, text: string, font_id: int, font_size: f32, color: Color, align_h, align_v: UI_Align) {
    cmd := Draw_Command{
        kind = .Text,
        rect = rect,
        text = strings.clone(text),
        font_id = font_id,
        font_size = font_size,
        color = color,
        align_h = align_h,
        align_v = align_v,
    }
    append(&ctx.commands, cmd)
}

ui_push_image :: proc(ctx: ^UI_Context, rect: Rect, image_id: int, uv0, uv1: Vec2, tint: Color) {
    cmd := Draw_Command{
        kind = .Image,
        rect = rect,
        image_id = image_id,
        uv0 = uv0,
        uv1 = uv1,
        color = tint,
    }
    append(&ctx.commands, cmd)
}

ui_push_scissor :: proc(ctx: ^UI_Context, rect: Rect) {
    cmd := Draw_Command{kind = .Scissor_Push, rect = rect}
    append(&ctx.commands, cmd)
}

ui_pop_scissor :: proc(ctx: ^UI_Context) {
    cmd := Draw_Command{kind = .Scissor_Pop}
    append(&ctx.commands, cmd)
}
