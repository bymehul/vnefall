# VNEUI Usage Guide

VNEUI is a renderer-agnostic UI toolkit. It only outputs draw commands. You decide how to render them.

## Quick Start

1. Add the collection when building:

```bash
odin run your_app -collection:vneui=./vneui
```

2. Import it:

```odin
import "vneui:src"
```

3. Frame loop:

```odin
ctx: vneui.UI_Context
vneui.ui_init(&ctx)

for running {
    input := vneui.UI_Input{
        mouse_pos = vneui.Vec2{mx, my},
        mouse_down = mouse_down,
        mouse_pressed = mouse_pressed,
        mouse_released = mouse_released,
        scroll_y = wheel_delta,
        delta_time = dt,
        text_input = typed_text,
        key_backspace = backspace_pressed,
        key_delete = delete_pressed,
        key_enter = enter_pressed,
        key_left = left_pressed,
        key_right = right_pressed,
        nav_next = tab_pressed,
        nav_prev = shift_tab_pressed,
        nav_activate = activate_pressed,
        nav_cancel = cancel_pressed,
    }

    theme := vneui.ui_theme_default(0, 18)
    vneui.ui_begin_frame(&ctx, input, theme)

    vneui.ui_panel_begin(&ctx, vneui.Rect{40, 40, 320, 240}, .Column, 12, 8)
    vneui.ui_label_layout(&ctx, "Settings", 0, 24)
    _ = vneui.ui_button_layout(&ctx, "Apply", 0, 36)
    vneui.ui_panel_end(&ctx)

    commands := vneui.ui_end_frame(&ctx)
    // Render commands here
}

defer vneui.ui_shutdown(&ctx)
```

## Input Notes

- `text_input` should be an owned string if you plan to free it after the frame.
- `nav_next`, `nav_prev`, and `nav_activate` drive keyboard focus.

## Layout

Use layout containers to position widgets without hardcoding coordinates.

```odin
vneui.ui_layout_begin(&ctx, vneui.Rect{40, 40, 300, 200}, .Column, 10, 8)
_ = vneui.ui_button_layout(&ctx, "Start", 0, 32)
_ = vneui.ui_button_layout(&ctx, "Options", 0, 32)
vneui.ui_layout_end(&ctx)
```

### Grid Layout

```odin
vneui.ui_layout_grid_begin(&ctx, vneui.Rect{40, 40, 300, 200}, 3, 0, 0, 8, 8, 8)
for i in 0..<6 {
    _ = vneui.ui_button_layout(&ctx, "Slot", 0, 40)
}
vneui.ui_layout_end(&ctx)
```

## Core Widgets

- Panel: `ui_panel`, `ui_panel_begin`
- Label: `ui_label`, `ui_label_wrap`
- Button: `ui_button`
- Toggle: `ui_toggle`
- Slider: `ui_slider`
- Separator: `ui_separator`
- Image: `ui_image`

Every widget has a `*_layout` variant for use inside layouts.

## Theme and Style Overrides

```odin
style := vneui.ui_style_from_theme(theme)
style.panel_color = vneui.ui_color_rgba8(25, 25, 32, 255)
style.accent_color = vneui.ui_color_rgba8(200, 120, 255, 255)

_ = vneui.ui_button_style(&ctx, vneui.Rect{40, 40, 180, 36}, "Styled", style)
```

## Text Wrapping

```odin
vneui.ui_label_wrap(&ctx, vneui.Rect{40, 40, 280, 80}, "Long paragraph text...")
```

For accurate wrapping, supply a text measurement function:

```odin
ctx.measure_text = my_text_width_proc
```

## Text Input

```odin
name := strings.clone("Alex")
defer delete(name)
state := vneui.UI_Text_Input_State{}
opts := vneui.UI_Text_Input_Options{placeholder = "Enter name"}

rect := vneui.ui_layout_next(&ctx, 0, 36)
changed, submitted := vneui.ui_text_input_style(&ctx, rect, "player_name", &name, &state, vneui.ui_style_from_theme(theme), opts)
```

Note: `ui_text_input` replaces the string as you type, so pass an owned/allocated string (e.g., `strings.clone`).

## Dropdown / Select

```odin
options := []string{"Easy", "Normal", "Hard"}
select_state := vneui.UI_Select_State{}
selected := 1

rect := vneui.ui_layout_next(&ctx, 0, 36)
selected, _ = vneui.ui_select(&ctx, rect, "difficulty", options, selected, &select_state)
```

Keyboard navigation uses `input.nav_next` / `input.nav_prev` to cycle focus and `input.nav_activate` to activate the focused widget.

## Scroll Containers

Basic scroll container:

```odin
scroll_rect := vneui.Rect{40, 40, 300, 200}
scroll_y: f32 = 0

vneui.ui_scroll_begin(&ctx, scroll_rect, scroll_y, 8, 6)
for i in 0..<10 {
    _ = vneui.ui_button_layout(&ctx, "Item", 0, 26)
}
scroll_y = vneui.ui_scroll_end(&ctx, scroll_rect, scroll_y)
```

Momentum + scrollbar:

```odin
scroll_state := vneui.UI_Scroll_State{}
scroll_opts := vneui.ui_scroll_options_default()

scroll_rect := vneui.Rect{40, 40, 300, 200}
vneui.ui_scroll_begin_state(&ctx, scroll_rect, &scroll_state, 8, 6)
for i in 0..<20 {
    _ = vneui.ui_button_layout(&ctx, "Item", 0, 26)
}
_ = vneui.ui_scroll_end_state(&ctx, scroll_rect, &scroll_state, scroll_opts)
```

## Nine-slice Images

```odin
border := vneui.ui_insets(8, 8, 8, 8)
panel := vneui.Rect{40, 40, 220, 90}
vneui.ui_image_nine_slice(&ctx, panel, image_id, tex_w, tex_h, border, vneui.ui_color(1, 1, 1, 1))
```

## Menu Helpers

VNEUI includes data-driven helpers for common game menus:

- `ui_main_menu` / `ui_main_menu_layout`
- `ui_preferences_menu`
- `ui_save_list_menu`
- `ui_confirm_dialog`

These helpers take layout structs so you can tune spacing without hardcoding constants.

## Advanced UI

- Input scopes: `ui_input_scope_begin`, `ui_input_scope_end`
- Modals: `ui_modal_overlay`, `ui_modal_begin`, `ui_modal_end`
- Tooltips: `ui_tooltip_register`, `ui_tooltip_draw`
- Toasts: `ui_toast_push`, `ui_toasts_draw`
- Transitions: `ui_transition_begin`, `ui_transition_update`, `ui_transition_draw_fade`

Animations and toasts use `UI_Input.delta_time` (seconds) for timing.

## Rendering Commands

VNEUI outputs `[]Draw_Command`. Your renderer should handle:

- `.Rect`, `.Rounded_Rect` -> draw quad
- `.Line` -> draw line or thin quad
- `.Text` -> draw text
- `.Image` -> draw texture
- `.Scissor_Push` / `.Scissor_Pop` -> clip rectangle

## Demo (SVG Output)

Generate the SVG demo:

```bash
odin run vneui/demo -collection:vneui=./vneui
```

Output:

```
vneui/demo/demo_ui.svg
```
