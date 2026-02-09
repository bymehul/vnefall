/*
    UI configuration (ui.vnef)
    Keeps UI styling separate from engine settings.
*/

package vnefall

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

UI_Config :: struct {
    // Theme
    theme_text_color:   [4]f32,
    theme_panel_color:  [4]f32,
    theme_accent_color: [4]f32,
    theme_border_color: [4]f32,
    theme_shadow_color: [4]f32,
    theme_border_width: f32,
    theme_font_size:    f32,
    theme_text_line_h:  f32,
    theme_padding:      f32,
    theme_corner_radius: f32,
    theme_shadow_offset_x: f32,
    theme_shadow_offset_y: f32,
    theme_shadow_enabled:  bool,

    // Textbox
    textbox_height:  f32,
    textbox_margin:  f32,
    textbox_padding: f32,
    textbox_image:   string,
    textbox_alpha:   f32,
    textbox_anchor:  string,
    speaker_color:   [4]f32,
    text_color:      [4]f32,

    // Choice menu
    choice_w:          f32,
    choice_h:          f32,
    choice_spacing:    f32,
    choice_color_idle: [4]f32,
    choice_color_hov:  [4]f32,
    choice_text_idle:  [4]f32,
    choice_text_hov:   [4]f32,
    choice_image_idle:  string,
    choice_image_hov:   string,
    choice_image_alpha: f32,

    // Logic
    text_speed: f32,
    text_shake_px: f32,

    // Transitions
    bg_transition: string,
    bg_transition_ms: f32,
    char_fade_ms: f32,
    char_transition: string,
    char_slide_ms: f32,
    char_shake_ms: f32,
    char_shake_px: f32,
    char_float_default: bool,
    char_float_px: f32,
    char_float_speed: f32,
    bg_shake_px:   f32,
    bg_float_default: bool,
    bg_float_px: f32,
    bg_float_speed: f32,

    // Optional loading screen image (relative to path_images)
    loading_image: string,
}

ui_cfg: UI_Config

ui_config_init_defaults :: proc() {
    ui_cfg.theme_text_color   = {0.92, 0.92, 0.92, 1.0}
    ui_cfg.theme_panel_color  = {0.1, 0.1, 0.15, 0.9}
    ui_cfg.theme_accent_color = {0.35, 0.7, 1.0, 1.0}
    ui_cfg.theme_border_color = {0.07, 0.07, 0.08, 1.0}
    ui_cfg.theme_shadow_color = {0.0, 0.0, 0.0, 0.47}
    ui_cfg.theme_border_width = 1
    ui_cfg.theme_font_size    = f32(FONT_SIZE)
    ui_cfg.theme_text_line_h  = f32(FONT_SIZE) * 1.2
    ui_cfg.theme_padding      = 10
    ui_cfg.theme_corner_radius = 6
    ui_cfg.theme_shadow_offset_x = 0
    ui_cfg.theme_shadow_offset_y = 2
    ui_cfg.theme_shadow_enabled  = true

    ui_cfg.textbox_height  = 180
    ui_cfg.textbox_margin  = 40
    ui_cfg.textbox_padding = 20
    ui_cfg.textbox_image   = strings.clone("")
    ui_cfg.textbox_alpha   = 0.85
    ui_cfg.textbox_anchor  = strings.clone("bottom")
    ui_cfg.speaker_color   = {1.0, 0.84, 0.0, 1.0}
    ui_cfg.text_color      = {0.96, 0.96, 0.96, 1.0}

    ui_cfg.choice_w          = 600
    ui_cfg.choice_h          = 60
    ui_cfg.choice_spacing    = 20
    ui_cfg.choice_color_idle = {0.1, 0.1, 0.15, 0.9}
    ui_cfg.choice_color_hov  = {0.2, 0.3, 0.5, 0.95}
    ui_cfg.choice_text_idle  = {0.96, 0.96, 0.96, 1.0}
    ui_cfg.choice_text_hov   = {1.0, 0.84, 0.0, 1.0}
    ui_cfg.choice_image_idle  = strings.clone("")
    ui_cfg.choice_image_hov   = strings.clone("")
    ui_cfg.choice_image_alpha = 0.95

    ui_cfg.text_speed   = 0.05
    ui_cfg.text_shake_px = 2.0
    ui_cfg.bg_transition = strings.clone("none")
    ui_cfg.bg_transition_ms = 400
    ui_cfg.char_fade_ms = 250
    ui_cfg.char_transition = strings.clone("fade")
    ui_cfg.char_slide_ms = 250
    ui_cfg.char_shake_ms = 200
    ui_cfg.char_shake_px = 8
    ui_cfg.char_float_default = false
    ui_cfg.char_float_px = 6
    ui_cfg.char_float_speed = 0.25
    ui_cfg.bg_shake_px = 10
    ui_cfg.bg_float_default = false
    ui_cfg.bg_float_px = 8
    ui_cfg.bg_float_speed = 0.2
    ui_cfg.loading_image = strings.clone("")
}

ui_config_load :: proc(path: string) -> bool {
    ui_config_init_defaults()

    data, ok := os.read_entire_file(path)
    if !ok {
        fmt.printf("[vnefall] No UI config found at %s. Using defaults.\n", path)
        return true
    }
    defer delete(data)

    content := string(data)
    lines := strings.split_lines(content)
    defer delete(lines)

    for line in lines {
        trimmed := strings.trim_space(line)
        if len(trimmed) == 0 || strings.has_prefix(trimmed, "#") do continue

        parts := strings.split(trimmed, "=")
        if len(parts) != 2 {
            delete(parts)
            continue
        }

        key := strings.trim_space(parts[0])
        val := strings.trim_space(parts[1])
        if idx := strings.index(val, "#"); idx != -1 {
            val = strings.trim_space(val[:idx])
        }

        switch key {
        case "ui_text_color":   ui_cfg.theme_text_color = parse_hex_color(val)
        case "ui_panel_color":  ui_cfg.theme_panel_color = parse_hex_color(val)
        case "ui_accent_color": ui_cfg.theme_accent_color = parse_hex_color(val)
        case "ui_border_color": ui_cfg.theme_border_color = parse_hex_color(val)
        case "ui_shadow_color": ui_cfg.theme_shadow_color = parse_hex_color(val)
        case "ui_border_width":
            v, _ := strconv.parse_f32(val)
            ui_cfg.theme_border_width = v
        case "ui_font_size":
            v, _ := strconv.parse_f32(val)
            ui_cfg.theme_font_size = v
        case "ui_text_line_height":
            v, _ := strconv.parse_f32(val)
            ui_cfg.theme_text_line_h = v
        case "ui_padding":
            v, _ := strconv.parse_f32(val)
            ui_cfg.theme_padding = v
        case "ui_corner_radius":
            v, _ := strconv.parse_f32(val)
            ui_cfg.theme_corner_radius = v
        case "ui_shadow_offset_x":
            v, _ := strconv.parse_f32(val)
            ui_cfg.theme_shadow_offset_x = v
        case "ui_shadow_offset_y":
            v, _ := strconv.parse_f32(val)
            ui_cfg.theme_shadow_offset_y = v
        case "ui_shadow_enabled":
            ui_cfg.theme_shadow_enabled = parse_bool(val)

        case "textbox_height":
            v, _ := strconv.parse_f32(val)
            ui_cfg.textbox_height = v
        case "textbox_margin":
            v, _ := strconv.parse_f32(val)
            ui_cfg.textbox_margin = v
        case "textbox_padding":
            v, _ := strconv.parse_f32(val)
            ui_cfg.textbox_padding = v
        case "textbox_image":
            delete(ui_cfg.textbox_image)
            ui_cfg.textbox_image = strings.clone(strings.trim(val, "\""))
        case "textbox_alpha":
            v, _ := strconv.parse_f32(val)
            ui_cfg.textbox_alpha = v
        case "textbox_anchor":
            delete(ui_cfg.textbox_anchor)
            ui_cfg.textbox_anchor = strings.clone(strings.trim(val, "\""))
        case "speaker_color":
            ui_cfg.speaker_color = parse_hex_color(val)
        case "text_color":
            ui_cfg.text_color = parse_hex_color(val)

        case "choice_w":
            v, _ := strconv.parse_f32(val)
            ui_cfg.choice_w = v
        case "choice_h":
            v, _ := strconv.parse_f32(val)
            ui_cfg.choice_h = v
        case "choice_spacing":
            v, _ := strconv.parse_f32(val)
            ui_cfg.choice_spacing = v
        case "choice_color_idle": ui_cfg.choice_color_idle = parse_hex_color(val)
        case "choice_color_hov":  ui_cfg.choice_color_hov  = parse_hex_color(val)
        case "choice_text_idle":  ui_cfg.choice_text_idle  = parse_hex_color(val)
        case "choice_text_hov":   ui_cfg.choice_text_hov   = parse_hex_color(val)
        case "choice_image_idle":
            delete(ui_cfg.choice_image_idle)
            ui_cfg.choice_image_idle = strings.clone(strings.trim(val, "\""))
        case "choice_image_hov":
            delete(ui_cfg.choice_image_hov)
            ui_cfg.choice_image_hov = strings.clone(strings.trim(val, "\""))
        case "choice_image_alpha":
            v, _ := strconv.parse_f32(val)
            ui_cfg.choice_image_alpha = v

        case "text_speed":
            v, _ := strconv.parse_f32(val)
            ui_cfg.text_speed = v
        case "text_shake_px":
            v, _ := strconv.parse_f32(val)
            ui_cfg.text_shake_px = v

        case "bg_transition":
            delete(ui_cfg.bg_transition)
            ui_cfg.bg_transition = strings.clone(strings.trim(val, "\""))
        case "bg_transition_ms":
            v, _ := strconv.parse_f32(val)
            ui_cfg.bg_transition_ms = v
        case "char_fade_ms":
            v, _ := strconv.parse_f32(val)
            ui_cfg.char_fade_ms = v
        case "char_transition":
            delete(ui_cfg.char_transition)
            ui_cfg.char_transition = strings.clone(strings.trim(val, "\""))
        case "char_slide_ms":
            v, _ := strconv.parse_f32(val)
            ui_cfg.char_slide_ms = v
        case "char_shake_ms":
            v, _ := strconv.parse_f32(val)
            ui_cfg.char_shake_ms = v
        case "char_shake_px":
            v, _ := strconv.parse_f32(val)
            ui_cfg.char_shake_px = v
        case "char_float_default":
            ui_cfg.char_float_default = parse_bool(val)
        case "char_float_px":
            v, _ := strconv.parse_f32(val)
            ui_cfg.char_float_px = v
        case "char_float_speed":
            v, _ := strconv.parse_f32(val)
            ui_cfg.char_float_speed = v
        case "bg_shake_px":
            v, _ := strconv.parse_f32(val)
            ui_cfg.bg_shake_px = v
        case "bg_float_default":
            ui_cfg.bg_float_default = parse_bool(val)
        case "bg_float_px":
            v, _ := strconv.parse_f32(val)
            ui_cfg.bg_float_px = v
        case "bg_float_speed":
            v, _ := strconv.parse_f32(val)
            ui_cfg.bg_float_speed = v

        case "loading_image":
            delete(ui_cfg.loading_image)
            ui_cfg.loading_image = strings.clone(strings.trim(val, "\""))
        }

        delete(parts)
    }

    fmt.printf("[vnefall] UI configuration loaded from %s\n", path)
    return true
}

ui_config_cleanup :: proc() {
    delete(ui_cfg.textbox_image)
    delete(ui_cfg.textbox_anchor)
    delete(ui_cfg.choice_image_idle)
    delete(ui_cfg.choice_image_hov)
    delete(ui_cfg.bg_transition)
    delete(ui_cfg.char_transition)
    delete(ui_cfg.loading_image)
}

parse_bool :: proc(s: string) -> bool {
    t := strings.to_lower(s)
    defer delete(t)
    return t == "true" || t == "1" || t == "yes" || t == "on"
}
