package vneui

Vec2 :: struct {
    x, y: f32,
}

Rect :: struct {
    x, y: f32,
    w, h: f32,
}

Color :: struct {
    r, g, b, a: f32,
}

Draw_Command_Kind :: enum {
    Rect,
    Rounded_Rect,
    Line,
    Text,
    Image,
    Scissor_Push,
    Scissor_Pop,
}

UI_Align :: enum {
    Start,
    Center,
    End,
}

UI_Text_Measure :: proc(text: string, font_id: int, font_size: f32) -> f32

// Renderer-agnostic draw command list.
Draw_Command :: struct {
    kind: Draw_Command_Kind,
    rect: Rect,
    radius: f32,
    color: Color,
    p0, p1: Vec2,
    thickness: f32,
    text: string,
    font_id: int,
    font_size: f32,
    align_h: UI_Align,
    align_v: UI_Align,
    image_id: int,
    uv0, uv1: Vec2,
}

UI_Input :: struct {
    mouse_pos: Vec2,
    mouse_down: bool,
    mouse_pressed: bool,
    mouse_released: bool,
    scroll_y: f32,
    delta_time: f32,
    text_input: string,
    key_backspace: bool,
    key_delete: bool,
    key_enter: bool,
    key_left: bool,
    key_right: bool,
    key_up: bool,
    key_down: bool,
    key_home: bool,
    key_end: bool,
    nav_next: bool,
    nav_prev: bool,
    nav_activate: bool,
    nav_cancel: bool,
}

UI_Theme :: struct {
    text_color: Color,
    panel_color: Color,
    accent_color: Color,
    border_color: Color,
    border_width: f32,
    font_id: int,
    font_size: f32,
    text_line_height: f32,
    padding: f32,
    corner_radius: f32,
    text_align_h: UI_Align,
    text_align_v: UI_Align,
    shadow_color: Color,
    shadow_offset: Vec2,
    shadow_enabled: bool,
}

UI_Style :: struct {
    text_color: Color,
    panel_color: Color,
    accent_color: Color,
    border_color: Color,
    border_width: f32,
    font_id: int,
    font_size: f32,
    text_line_height: f32,
    padding: f32,
    corner_radius: f32,
    text_align_h: UI_Align,
    text_align_v: UI_Align,
    shadow_color: Color,
    shadow_offset: Vec2,
    shadow_enabled: bool,
}

UI_Context :: struct {
    input: UI_Input,
    theme: UI_Theme,
    measure_text: UI_Text_Measure,
    commands: [dynamic]Draw_Command,
    layouts: [dynamic]UILayout,
    hot_id: u64,
    active_id: u64,
    last_id: u64,
    time: f32,
    input_scopes: [dynamic]Rect,
    tooltip: UI_Tooltip,
    toasts: [dynamic]UI_Toast,
    focus_id: u64,
    focus_order: [dynamic]u64,
    focus_order_prev: [dynamic]u64,
}

UILayout_Direction :: enum {
    Row,
    Column,
    Stack,
    Grid,
}

UILayout :: struct {
    rect: Rect,
    cursor: Vec2,
    gap: f32,
    padding: f32,
    direction: UILayout_Direction,
    content_max: Vec2,
    scroll_offset: f32,
    grid_cols: int,
    grid_gap: Vec2,
    cell_w: f32,
    cell_h: f32,
    grid_index: int,
}

UI_Text_Range :: struct {
    start: int,
    len: int,
}
