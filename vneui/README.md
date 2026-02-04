# VNEUI

VNEUI is a lightweight, renderer-agnostic UI toolkit written in Odin. It is built alongside the Vnefall engine and designed to power VN-style menus and tools without hardcoding layouts.

This library is intended to stay simple, flexible, and easy to integrate with custom renderers.

## Goals
- Clean, minimal core (no heavy dependencies)
- Renderer-agnostic drawing backend
- Flexible layout and theming
- Works for game UI **and** editor/debug tools

## Status
Active development. See `roadmap.md` for milestones and `docs/usage.md` for usage.

## Getting Started
1. Add the collection when building:

```bash
odin run your_app -collection:vneui=./vneui
```

2. Import it in code:

```odin
import "vneui:src"
```

3. Initialize and render per frame:

```odin
ctx: vneui.UI_Context
vneui.ui_init(&ctx)
defer vneui.ui_shutdown(&ctx)

for running {
    input := vneui.UI_Input{
        mouse_pos = vneui.Vec2{mx, my},
        mouse_down = mouse_down,
        mouse_pressed = mouse_pressed,
        mouse_released = mouse_released,
        scroll_y = wheel_delta,
        delta_time = dt,
        text_input = typed_text,
    }

    theme := vneui.ui_theme_default(0, 18)
    vneui.ui_begin_frame(&ctx, input, theme)

    vneui.ui_panel_begin(&ctx, vneui.Rect{40, 40, 320, 240}, .Column, 12, 8)
    vneui.ui_label_layout(&ctx, "Hello VNEUI", 0, 24)
    _ = vneui.ui_button_layout(&ctx, "Click", 0, 36)
    vneui.ui_panel_end(&ctx)

    commands := vneui.ui_end_frame(&ctx)
    // Render commands here
}
```

For full examples, see `docs/usage.md`.

## Current Features
- Draw command list (rects, rounded rects, borders, lines, text, images, scissor)
- Layout stack (row/column/stack/grid) with padding + gap
- Theme + style overrides (colors, borders, fonts, alignment, shadows)
- Core widgets: panel, label, button, toggle, slider
- Text input + dropdown/select
- Text wrapping helper
- Scroll container helper
- Scroll momentum + scrollbar helper
- Nine-slice image helper
- Keyboard navigation + focus helpers
- Menu helpers (main menu, preferences, save/load, confirm)
- Modals, tooltips, toasts, transitions
- SVG demo exporter (see `vneui/demo/`)

## Integration Note
For accurate text wrapping, set `ctx.measure_text` to your renderer's text-width function. If unset, VNEUI uses a simple character-width fallback.

## Demo
Generate a visual SVG demo:
```bash
odin run vneui/demo -collection:vneui=./vneui
```

## Why It Exists
Vnefall needs a UI system that supports:
- VN menus and preferences
- Save/Load screens
- Tooling and debug overlays

VNEUI aims to be reusable beyond Vnefall as the API stabilizes.
