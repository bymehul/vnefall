/*
    Vnefall Settings System
    
    Player preferences (e.g., volume) are stored separately
    from project defaults (config.vnef).
*/

package vnefall

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

SETTINGS_PATH :: "settings.vnef"
g_settings_path: string

Settings :: struct {
    volume_master: f32,
    volume_music:  f32,
    volume_ambience: f32,
    volume_sfx:    f32,
    volume_voice:  f32,
    text_speed:    f32,
    fullscreen:    bool,
}

g_settings: Settings

settings_init_defaults :: proc() {
    g_settings.volume_master = cfg.volume_master
    g_settings.volume_music  = cfg.volume_music
    g_settings.volume_ambience = cfg.volume_ambience
    g_settings.volume_sfx    = cfg.volume_sfx
    g_settings.volume_voice  = cfg.volume_voice
    g_settings.text_speed    = ui_cfg.text_speed
    g_settings.fullscreen    = (cfg.window_mode == "fullscreen" || cfg.window_mode == "borderless")
}

settings_set_path :: proc(path: string) {
    if g_settings_path != "" do delete(g_settings_path)
    g_settings_path = strings.clone(path)
}

settings_resolve_path :: proc(path: string) -> string {
    if path != "" do return path
    if g_settings_path != "" do return g_settings_path
    return SETTINGS_PATH
}

settings_load :: proc(path: string = "") -> bool {
    settings_init_defaults()

    use_path := settings_resolve_path(path)
    data, ok := os.read_entire_file(use_path)
    if !ok {
        fmt.printf("[settings] No settings found at %s. Using defaults.\n", use_path)
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
        case "volume_master":
            v, _ := strconv.parse_f32(val)
            g_settings.volume_master = v
        case "volume_music":
            v, _ := strconv.parse_f32(val)
            g_settings.volume_music = v
        case "volume_ambience":
            v, _ := strconv.parse_f32(val)
            g_settings.volume_ambience = v
        case "volume_sfx":
            v, _ := strconv.parse_f32(val)
            g_settings.volume_sfx = v
        case "volume_voice":
            v, _ := strconv.parse_f32(val)
            g_settings.volume_voice = v
        case "text_speed":
            v, _ := strconv.parse_f32(val)
            g_settings.text_speed = v
        case "fullscreen":
            g_settings.fullscreen = parse_bool(val)
        }
        
        delete(parts)
    }
    
    ui_cfg.text_speed = g_settings.text_speed
    fmt.printf("[settings] Loaded settings from %s\n", use_path)
    return true
}

settings_save :: proc(path: string = "") -> bool {
    b: strings.Builder
    strings.builder_init(&b)
    defer strings.builder_destroy(&b)
    
    strings.write_string(&b, "# Vnefall Settings\n\n")
    fmt.sbprintf(&b, "volume_master = %v\n", g_settings.volume_master)
    fmt.sbprintf(&b, "volume_music  = %v\n", g_settings.volume_music)
    fmt.sbprintf(&b, "volume_ambience = %v\n", g_settings.volume_ambience)
    fmt.sbprintf(&b, "volume_sfx    = %v\n", g_settings.volume_sfx)
    fmt.sbprintf(&b, "volume_voice  = %v\n", g_settings.volume_voice)
    fmt.sbprintf(&b, "text_speed    = %v\n", g_settings.text_speed)
    fmt.sbprintf(&b, "fullscreen    = %v\n", g_settings.fullscreen)
    
    content := strings.to_string(b)
    use_path := settings_resolve_path(path)
    return os.write_entire_file(use_path, transmute([]u8)content)
}

settings_cleanup :: proc() {
    if g_settings_path != "" do delete(g_settings_path)
}

settings_reset_defaults :: proc() {
    settings_init_defaults()
    ui_cfg.text_speed = g_settings.text_speed
}

settings_set_volume :: proc(channel: string, value: f32) {
    v := clamp_f32(value, 0.0, 1.0)
    
    switch channel {
    case "master": g_settings.volume_master = v
    case "music":  g_settings.volume_music  = v
    case "ambience": g_settings.volume_ambience = v
    case "sfx":    g_settings.volume_sfx    = v
    case "voice":  g_settings.volume_voice  = v
    }
}

clamp_f32 :: proc(v, min_v, max_v: f32) -> f32 {
    if v < min_v do return min_v
    if v > max_v do return max_v
    return v
}
