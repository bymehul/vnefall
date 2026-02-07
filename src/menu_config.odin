/*
    Menu configuration (menu.vnef)
    Keeps pause/settings UI tuning separate from core UI theme.
*/

package vnefall

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

Menu_Config :: struct {
    overlay_alpha: f32,
    panel_color:   [4]f32,
    panel_w:       f32,
    panel_h:       f32,
    settings_w:    f32,
    settings_h:    f32,
    start_w:       f32,
    start_h:       f32,
    start_x:       f32,
    start_y:       f32,
    panel_w_pct:   f32,
    panel_h_pct:   f32,
    settings_w_pct: f32,
    settings_h_pct: f32,
    start_w_pct:   f32,
    start_h_pct:   f32,
    start_x_pct:   f32,
    start_y_pct:   f32,
    pause_anchor:  string,
    pause_x:       f32,
    pause_y:       f32,
    pause_x_pct:   f32,
    pause_y_pct:   f32,
    pause_panel:   bool,
    settings_anchor: string,
    settings_x:    f32,
    settings_y:    f32,
    settings_x_pct: f32,
    settings_y_pct: f32,
    settings_label_w: f32,
    settings_value_w: f32,
    padding:       f32,
    gap:           f32,
    button_h:      f32,
    max_button_w:  f32,
    align_h:       string,
    start_align_h: string,
    start_anchor:  string,
    start_panel:   bool,

    menu_bg_image: string,
    menu_bg_start_image: string,
    menu_bg_pause_image: string,
    menu_bg_settings_image: string,
    menu_bg_alpha: f32,
    menu_bg_start_alpha: f32,
    menu_bg_pause_alpha: f32,
    menu_bg_settings_alpha: f32,
    menu_intro_image: string,
    menu_intro_ms: f32,
    menu_intro_skip: bool,
    menu_overlay_start_alpha: f32,
    menu_overlay_pause_alpha: f32,
    menu_overlay_settings_alpha: f32,
    menu_panel_color_start: [4]f32,
    menu_panel_color_pause: [4]f32,
    menu_panel_color_settings: [4]f32,
    menu_panel_color_start_set: bool,
    menu_panel_color_pause_set: bool,
    menu_panel_color_settings_set: bool,

    start_title:   string,
    btn_start:     string,
    btn_load:      string,
    show_start_menu: bool,
    show_load:     bool,
    load_slot:     string,

    pause_title:   string,
    settings_title: string,
    btn_resume:    string,
    btn_settings:  string,
    btn_quit:      string,
    btn_back:      string,
    btn_reset:     string,

    show_quit:     bool,
    show_reset:    bool,

    label_master:  string,
    label_music:   string,
    label_ambience: string,
    label_sfx:     string,
    label_voice:   string,
    label_text_speed: string,
    label_fullscreen: string,
    section_audio: string,
    section_reading: string,
    section_display: string,

    text_speed_min: f32,
    text_speed_max: f32,
}

menu_cfg: Menu_Config

menu_config_init_defaults :: proc() {
    menu_cfg.overlay_alpha = 0.55
    menu_cfg.panel_color   = {0.08, 0.09, 0.12, 0.92}
    menu_cfg.panel_w       = 520
    menu_cfg.panel_h       = 420
    menu_cfg.settings_w    = 720
    menu_cfg.settings_h    = 520
    menu_cfg.start_w       = 520
    menu_cfg.start_h       = 420
    menu_cfg.start_x       = 0
    menu_cfg.start_y       = 0
    menu_cfg.panel_w_pct   = 0
    menu_cfg.panel_h_pct   = 0
    menu_cfg.settings_w_pct = 0
    menu_cfg.settings_h_pct = 0
    menu_cfg.start_w_pct   = 0
    menu_cfg.start_h_pct   = 0
    menu_cfg.start_x_pct   = 0
    menu_cfg.start_y_pct   = 0
    menu_cfg.pause_anchor  = strings.clone("center")
    menu_cfg.pause_x       = 0
    menu_cfg.pause_y       = 0
    menu_cfg.pause_x_pct   = 0
    menu_cfg.pause_y_pct   = 0
    menu_cfg.pause_panel   = true
    menu_cfg.settings_anchor = strings.clone("center")
    menu_cfg.settings_x    = 0
    menu_cfg.settings_y    = 0
    menu_cfg.settings_x_pct = 0
    menu_cfg.settings_y_pct = 0
    menu_cfg.settings_label_w = 0
    menu_cfg.settings_value_w = 0
    menu_cfg.padding       = ui_cfg.theme_padding
    menu_cfg.gap           = ui_cfg.theme_padding * 0.6
    menu_cfg.button_h      = ui_cfg.theme_text_line_h + ui_cfg.theme_padding * 1.1
    menu_cfg.max_button_w  = 0
    menu_cfg.align_h       = strings.clone("center")
    menu_cfg.start_align_h = strings.clone("start")
    menu_cfg.start_anchor  = strings.clone("center")
    menu_cfg.start_panel   = true

    menu_cfg.menu_bg_image = strings.clone("")
    menu_cfg.menu_bg_start_image = strings.clone("")
    menu_cfg.menu_bg_pause_image = strings.clone("")
    menu_cfg.menu_bg_settings_image = strings.clone("")
    menu_cfg.menu_bg_alpha = 1.0
    menu_cfg.menu_bg_start_alpha = 1.0
    menu_cfg.menu_bg_pause_alpha = 1.0
    menu_cfg.menu_bg_settings_alpha = 1.0
    menu_cfg.menu_overlay_start_alpha = -1
    menu_cfg.menu_overlay_pause_alpha = -1
    menu_cfg.menu_overlay_settings_alpha = -1
    menu_cfg.menu_panel_color_start_set = false
    menu_cfg.menu_panel_color_pause_set = false
    menu_cfg.menu_panel_color_settings_set = false
    menu_cfg.menu_intro_image = strings.clone("")
    menu_cfg.menu_intro_ms = 1200
    menu_cfg.menu_intro_skip = true

    menu_cfg.start_title  = strings.clone("Vnefall")
    menu_cfg.btn_start    = strings.clone("Start")
    menu_cfg.btn_load     = strings.clone("Load")
    menu_cfg.show_start_menu = true
    menu_cfg.show_load    = true
    menu_cfg.load_slot    = strings.clone("auto_start")

    menu_cfg.pause_title    = strings.clone("Paused")
    menu_cfg.settings_title = strings.clone("Settings")
    menu_cfg.btn_resume   = strings.clone("Resume")
    menu_cfg.btn_settings = strings.clone("Settings")
    menu_cfg.btn_quit     = strings.clone("Quit")
    menu_cfg.btn_back     = strings.clone("Back")
    menu_cfg.btn_reset    = strings.clone("Reset")

    menu_cfg.show_quit  = true
    menu_cfg.show_reset = true

    menu_cfg.label_master     = strings.clone("Master Volume")
    menu_cfg.label_music      = strings.clone("Music")
    menu_cfg.label_ambience   = strings.clone("Ambience")
    menu_cfg.label_sfx        = strings.clone("SFX")
    menu_cfg.label_voice      = strings.clone("Voice")
    menu_cfg.label_text_speed = strings.clone("Text Speed")
    menu_cfg.label_fullscreen = strings.clone("Fullscreen")
    menu_cfg.section_audio    = strings.clone("Audio")
    menu_cfg.section_reading  = strings.clone("Reading")
    menu_cfg.section_display  = strings.clone("Display")

    menu_cfg.text_speed_min = 0.01
    menu_cfg.text_speed_max = 0.2
}

menu_config_apply :: proc(path: string, warn_missing: bool) -> bool {
    data, ok := os.read_entire_file(path)
    if !ok {
        if warn_missing {
            fmt.printf("[vnefall] No menu config found at %s. Using defaults.\n", path)
        }
        return false
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
        case "menu_overlay_alpha":
            v, _ := strconv.parse_f32(val)
            menu_cfg.overlay_alpha = v
        case "menu_panel_color":
            menu_cfg.panel_color = parse_hex_color(val)
        case "menu_panel_w":
            v, _ := strconv.parse_f32(val)
            menu_cfg.panel_w = v
        case "menu_panel_h":
            v, _ := strconv.parse_f32(val)
            menu_cfg.panel_h = v
        case "menu_panel_w_pct":
            v, _ := strconv.parse_f32(val)
            menu_cfg.panel_w_pct = v
        case "menu_panel_h_pct":
            v, _ := strconv.parse_f32(val)
            menu_cfg.panel_h_pct = v
        case "menu_settings_w":
            v, _ := strconv.parse_f32(val)
            menu_cfg.settings_w = v
        case "menu_settings_h":
            v, _ := strconv.parse_f32(val)
            menu_cfg.settings_h = v
        case "menu_settings_w_pct":
            v, _ := strconv.parse_f32(val)
            menu_cfg.settings_w_pct = v
        case "menu_settings_h_pct":
            v, _ := strconv.parse_f32(val)
            menu_cfg.settings_h_pct = v
        case "menu_start_w":
            v, _ := strconv.parse_f32(val)
            menu_cfg.start_w = v
        case "menu_start_h":
            v, _ := strconv.parse_f32(val)
            menu_cfg.start_h = v
        case "menu_start_w_pct":
            v, _ := strconv.parse_f32(val)
            menu_cfg.start_w_pct = v
        case "menu_start_h_pct":
            v, _ := strconv.parse_f32(val)
            menu_cfg.start_h_pct = v
        case "menu_start_x":
            v, _ := strconv.parse_f32(val)
            menu_cfg.start_x = v
        case "menu_start_y":
            v, _ := strconv.parse_f32(val)
            menu_cfg.start_y = v
        case "menu_start_x_pct":
            v, _ := strconv.parse_f32(val)
            menu_cfg.start_x_pct = v
        case "menu_start_y_pct":
            v, _ := strconv.parse_f32(val)
            menu_cfg.start_y_pct = v
        case "menu_pause_anchor":
            delete(menu_cfg.pause_anchor)
            menu_cfg.pause_anchor = strings.clone(strings.trim(val, "\""))
        case "menu_pause_x":
            v, _ := strconv.parse_f32(val)
            menu_cfg.pause_x = v
        case "menu_pause_y":
            v, _ := strconv.parse_f32(val)
            menu_cfg.pause_y = v
        case "menu_pause_x_pct":
            v, _ := strconv.parse_f32(val)
            menu_cfg.pause_x_pct = v
        case "menu_pause_y_pct":
            v, _ := strconv.parse_f32(val)
            menu_cfg.pause_y_pct = v
        case "menu_pause_panel":
            menu_cfg.pause_panel = parse_bool(val)
        case "menu_settings_anchor":
            delete(menu_cfg.settings_anchor)
            menu_cfg.settings_anchor = strings.clone(strings.trim(val, "\""))
        case "menu_settings_x":
            v, _ := strconv.parse_f32(val)
            menu_cfg.settings_x = v
        case "menu_settings_y":
            v, _ := strconv.parse_f32(val)
            menu_cfg.settings_y = v
        case "menu_settings_x_pct":
            v, _ := strconv.parse_f32(val)
            menu_cfg.settings_x_pct = v
        case "menu_settings_y_pct":
            v, _ := strconv.parse_f32(val)
            menu_cfg.settings_y_pct = v
        case "menu_settings_label_w":
            v, _ := strconv.parse_f32(val)
            menu_cfg.settings_label_w = v
        case "menu_settings_value_w":
            v, _ := strconv.parse_f32(val)
            menu_cfg.settings_value_w = v
        case "menu_padding":
            v, _ := strconv.parse_f32(val)
            menu_cfg.padding = v
        case "menu_gap":
            v, _ := strconv.parse_f32(val)
            menu_cfg.gap = v
        case "menu_button_h":
            v, _ := strconv.parse_f32(val)
            menu_cfg.button_h = v
        case "menu_max_button_w":
            v, _ := strconv.parse_f32(val)
            menu_cfg.max_button_w = v
        case "menu_align_h":
            delete(menu_cfg.align_h)
            menu_cfg.align_h = strings.clone(strings.trim(val, "\""))
        case "menu_start_align_h":
            delete(menu_cfg.start_align_h)
            menu_cfg.start_align_h = strings.clone(strings.trim(val, "\""))
        case "menu_start_anchor":
            delete(menu_cfg.start_anchor)
            menu_cfg.start_anchor = strings.clone(strings.trim(val, "\""))
        case "menu_start_panel":
            menu_cfg.start_panel = parse_bool(val)

        case "menu_bg_image":
            delete(menu_cfg.menu_bg_image)
            menu_cfg.menu_bg_image = strings.clone(strings.trim(val, "\""))
        case "menu_bg_start_image":
            delete(menu_cfg.menu_bg_start_image)
            menu_cfg.menu_bg_start_image = strings.clone(strings.trim(val, "\""))
        case "menu_bg_pause_image":
            delete(menu_cfg.menu_bg_pause_image)
            menu_cfg.menu_bg_pause_image = strings.clone(strings.trim(val, "\""))
        case "menu_bg_settings_image":
            delete(menu_cfg.menu_bg_settings_image)
            menu_cfg.menu_bg_settings_image = strings.clone(strings.trim(val, "\""))
        case "menu_bg_alpha":
            v, _ := strconv.parse_f32(val)
            menu_cfg.menu_bg_alpha = v
        case "menu_bg_start_alpha":
            v, _ := strconv.parse_f32(val)
            menu_cfg.menu_bg_start_alpha = v
        case "menu_bg_pause_alpha":
            v, _ := strconv.parse_f32(val)
            menu_cfg.menu_bg_pause_alpha = v
        case "menu_bg_settings_alpha":
            v, _ := strconv.parse_f32(val)
            menu_cfg.menu_bg_settings_alpha = v
        case "menu_overlay_start_alpha":
            v, _ := strconv.parse_f32(val)
            menu_cfg.menu_overlay_start_alpha = v
        case "menu_overlay_pause_alpha":
            v, _ := strconv.parse_f32(val)
            menu_cfg.menu_overlay_pause_alpha = v
        case "menu_overlay_settings_alpha":
            v, _ := strconv.parse_f32(val)
            menu_cfg.menu_overlay_settings_alpha = v
        case "menu_panel_color_start":
            menu_cfg.menu_panel_color_start = parse_hex_color(val)
            menu_cfg.menu_panel_color_start_set = true
        case "menu_panel_color_pause":
            menu_cfg.menu_panel_color_pause = parse_hex_color(val)
            menu_cfg.menu_panel_color_pause_set = true
        case "menu_panel_color_settings":
            menu_cfg.menu_panel_color_settings = parse_hex_color(val)
            menu_cfg.menu_panel_color_settings_set = true
        case "menu_intro_image":
            delete(menu_cfg.menu_intro_image)
            menu_cfg.menu_intro_image = strings.clone(strings.trim(val, "\""))
        case "menu_intro_ms":
            v, _ := strconv.parse_f32(val)
            menu_cfg.menu_intro_ms = v
        case "menu_intro_skip":
            menu_cfg.menu_intro_skip = parse_bool(val)

        case "menu_start_title":
            delete(menu_cfg.start_title)
            menu_cfg.start_title = strings.clone(strings.trim(val, "\""))
        case "menu_btn_start":
            delete(menu_cfg.btn_start)
            menu_cfg.btn_start = strings.clone(strings.trim(val, "\""))
        case "menu_btn_load":
            delete(menu_cfg.btn_load)
            menu_cfg.btn_load = strings.clone(strings.trim(val, "\""))
        case "menu_show_start":
            menu_cfg.show_start_menu = parse_bool(val)
        case "menu_show_load":
            menu_cfg.show_load = parse_bool(val)
        case "menu_load_slot":
            delete(menu_cfg.load_slot)
            menu_cfg.load_slot = strings.clone(strings.trim(val, "\""))

        case "menu_pause_title":
            delete(menu_cfg.pause_title)
            menu_cfg.pause_title = strings.clone(strings.trim(val, "\""))
        case "menu_settings_title":
            delete(menu_cfg.settings_title)
            menu_cfg.settings_title = strings.clone(strings.trim(val, "\""))
        case "menu_btn_resume":
            delete(menu_cfg.btn_resume)
            menu_cfg.btn_resume = strings.clone(strings.trim(val, "\""))
        case "menu_btn_settings":
            delete(menu_cfg.btn_settings)
            menu_cfg.btn_settings = strings.clone(strings.trim(val, "\""))
        case "menu_btn_quit":
            delete(menu_cfg.btn_quit)
            menu_cfg.btn_quit = strings.clone(strings.trim(val, "\""))
        case "menu_btn_back":
            delete(menu_cfg.btn_back)
            menu_cfg.btn_back = strings.clone(strings.trim(val, "\""))
        case "menu_btn_reset":
            delete(menu_cfg.btn_reset)
            menu_cfg.btn_reset = strings.clone(strings.trim(val, "\""))

        case "menu_show_quit":
            menu_cfg.show_quit = parse_bool(val)
        case "menu_show_reset":
            menu_cfg.show_reset = parse_bool(val)

        case "label_master":
            delete(menu_cfg.label_master)
            menu_cfg.label_master = strings.clone(strings.trim(val, "\""))
        case "label_music":
            delete(menu_cfg.label_music)
            menu_cfg.label_music = strings.clone(strings.trim(val, "\""))
        case "label_ambience":
            delete(menu_cfg.label_ambience)
            menu_cfg.label_ambience = strings.clone(strings.trim(val, "\""))
        case "label_sfx":
            delete(menu_cfg.label_sfx)
            menu_cfg.label_sfx = strings.clone(strings.trim(val, "\""))
        case "label_voice":
            delete(menu_cfg.label_voice)
            menu_cfg.label_voice = strings.clone(strings.trim(val, "\""))
        case "label_text_speed":
            delete(menu_cfg.label_text_speed)
            menu_cfg.label_text_speed = strings.clone(strings.trim(val, "\""))
        case "label_fullscreen":
            delete(menu_cfg.label_fullscreen)
            menu_cfg.label_fullscreen = strings.clone(strings.trim(val, "\""))
        case "section_audio":
            delete(menu_cfg.section_audio)
            menu_cfg.section_audio = strings.clone(strings.trim(val, "\""))
        case "section_reading":
            delete(menu_cfg.section_reading)
            menu_cfg.section_reading = strings.clone(strings.trim(val, "\""))
        case "section_display":
            delete(menu_cfg.section_display)
            menu_cfg.section_display = strings.clone(strings.trim(val, "\""))

        case "text_speed_min":
            v, _ := strconv.parse_f32(val)
            menu_cfg.text_speed_min = v
        case "text_speed_max":
            v, _ := strconv.parse_f32(val)
            menu_cfg.text_speed_max = v
        }

        delete(parts)
    }

    fmt.printf("[vnefall] Menu configuration loaded from %s\n", path)
    return true
}

menu_config_load :: proc(path: string) -> bool {
    menu_config_init_defaults()
    menu_config_apply(path, true)
    return true
}

menu_config_load_all :: proc(base_dir: string) -> bool {
    menu_config_init_defaults()

    base_path := strings.concatenate({base_dir, "menu.vnef"})
    defer delete(base_path)
    menu_config_apply(base_path, true)

    start_path := strings.concatenate({base_dir, "menu_start.vnef"})
    defer delete(start_path)
    menu_config_apply(start_path, false)

    pause_path := strings.concatenate({base_dir, "menu_pause.vnef"})
    defer delete(pause_path)
    menu_config_apply(pause_path, false)

    settings_path := strings.concatenate({base_dir, "menu_settings.vnef"})
    defer delete(settings_path)
    menu_config_apply(settings_path, false)

    return true
}

menu_config_cleanup :: proc() {
    delete(menu_cfg.align_h)
    delete(menu_cfg.start_align_h)
    delete(menu_cfg.start_anchor)
    delete(menu_cfg.menu_bg_start_image)
    delete(menu_cfg.menu_bg_pause_image)
    delete(menu_cfg.menu_bg_settings_image)
    delete(menu_cfg.pause_anchor)
    delete(menu_cfg.settings_anchor)
    delete(menu_cfg.menu_bg_image)
    delete(menu_cfg.menu_intro_image)
    delete(menu_cfg.start_title)
    delete(menu_cfg.btn_start)
    delete(menu_cfg.btn_load)
    delete(menu_cfg.load_slot)
    delete(menu_cfg.pause_title)
    delete(menu_cfg.settings_title)
    delete(menu_cfg.btn_resume)
    delete(menu_cfg.btn_settings)
    delete(menu_cfg.btn_quit)
    delete(menu_cfg.btn_back)
    delete(menu_cfg.btn_reset)
    delete(menu_cfg.label_master)
    delete(menu_cfg.label_music)
    delete(menu_cfg.label_ambience)
    delete(menu_cfg.label_sfx)
    delete(menu_cfg.label_voice)
    delete(menu_cfg.label_text_speed)
    delete(menu_cfg.label_fullscreen)
    delete(menu_cfg.section_audio)
    delete(menu_cfg.section_reading)
    delete(menu_cfg.section_display)
}
