/*
    Vnefall Configuration System
    
    Handles loading and parsing of the config.vnef file to
    remove hardcoded values from the engine.
*/

package vnefall

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

Config :: struct {
    // Window settings
    window_width:    i32,
    window_height:   i32,
    window_title:    string,
    
    // Design resolution
    design_width:    f32,
    design_height:   f32,
    
    // Path settings
    path_assets:     string,
    path_images:     string,
    path_music:      string,
    path_scripts:    string,
    path_manifests:  string,
    path_characters: string,
    path_saves:      string,
    entry_script:    string,
    
    // Visual defaults
    color_speaker:   [4]f32, // RGBA 0-1
    color_text:      [4]f32, // RGBA 0-1
    textbox_height:  f32,
    textbox_margin:  f32,
    textbox_padding: f32,
    
    // Choice Menu Styles
    choice_w:          f32,
    choice_h:          f32,
    choice_spacing:    f32,
    choice_color_idle: [4]f32,
    choice_color_hov:  [4]f32,
    choice_text_idle:  [4]f32,
    choice_text_hov:   [4]f32,
    
    // Logic
    text_speed:      f32,
}

// Global config instance
cfg: Config

// Set some sensible defaults in case the file is missing
config_init_defaults :: proc() {
    cfg.window_width   = 1280
    cfg.window_height  = 720
    cfg.window_title   = strings.clone("Vnefall Story")
    
    cfg.design_width   = 1280
    cfg.design_height  = 720
    
    cfg.path_assets    = strings.clone("assets/")
    cfg.path_images    = strings.clone("assets/images/")
    cfg.path_music     = strings.clone("assets/music/")
    cfg.path_scripts   = strings.clone("assets/scripts/")
    cfg.path_manifests = strings.clone("assets/manifests/")
    cfg.path_characters = strings.clone("assets/images/characters/")
    cfg.path_saves     = strings.clone("saves/")
    cfg.entry_script   = strings.clone("assets/scripts/demo.vnef")
    
    cfg.color_speaker  = {1.0, 0.84, 0.0, 1.0} // Gold
    cfg.color_text     = {0.96, 0.96, 0.96, 1.0} // Off-white
    cfg.textbox_height  = 180
    cfg.textbox_margin  = 40
    cfg.textbox_padding = 20
    
    cfg.choice_w          = 600
    cfg.choice_h          = 60
    cfg.choice_spacing    = 20
    cfg.choice_color_idle = {0.1, 0.1, 0.15, 0.9}
    cfg.choice_color_hov  = {0.2, 0.3, 0.5, 0.95}
    cfg.choice_text_idle  = {0.96, 0.96, 0.96, 1.0}
    cfg.choice_text_hov   = {1.0, 0.84, 0.0, 1.0}
    
    cfg.text_speed     = 0.05
}

config_load :: proc(path: string) -> bool {
    config_init_defaults()
    
    data, ok := os.read_entire_file(path)
    if !ok {
        fmt.printf("[vnefall] No config found at %s. Using defaults.\n", path)
        return true // Not a fatal error
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
        
        // Remove trailing comments from values if any
        if idx := strings.index(val, "#"); idx != -1 {
            val = strings.trim_space(val[:idx])
        }
        
        switch key {
        case "window_width":    
            v, _ := strconv.parse_int(val)
            cfg.window_width = i32(v)
        case "window_height":   
            v, _ := strconv.parse_int(val)
            cfg.window_height = i32(v)
        case "window_title":    
            delete(cfg.window_title)
            cfg.window_title  = strings.clone(strings.trim(val, "\""))
        
        case "design_width":    
            v, _ := strconv.parse_f32(val)
            cfg.design_width = v
        case "design_height":   
            v, _ := strconv.parse_f32(val)
            cfg.design_height = v
        
        case "path_assets":     
            delete(cfg.path_assets)
            cfg.path_assets   = strings.clone(strings.trim(val, "\""))
        case "path_images":     
            delete(cfg.path_images)
            cfg.path_images   = strings.clone(strings.trim(val, "\""))
        case "path_music":      
            delete(cfg.path_music)
            cfg.path_music    = strings.clone(strings.trim(val, "\""))
        case "path_scripts":    
            delete(cfg.path_scripts)
            cfg.path_scripts  = strings.clone(strings.trim(val, "\""))
        case "path_manifests":  
            delete(cfg.path_manifests)
            cfg.path_manifests = strings.clone(strings.trim(val, "\""))
        case "path_characters":  
            delete(cfg.path_characters)
            cfg.path_characters = strings.clone(strings.trim(val, "\""))
        case "path_saves":
            delete(cfg.path_saves)
            cfg.path_saves = strings.clone(strings.trim(val, "\""))
        case "entry_script":    
            delete(cfg.entry_script)
            cfg.entry_script  = strings.clone(strings.trim(val, "\""))
        
        case "color_speaker":   cfg.color_speaker = parse_hex_color(val)
        case "color_text":      cfg.color_text    = parse_hex_color(val)
        case "textbox_height":  
            v, _ := strconv.parse_f32(val)
            cfg.textbox_height = v
        case "textbox_margin":  
            v, _ := strconv.parse_f32(val)
            cfg.textbox_margin = v
        case "textbox_padding":  
            v, _ := strconv.parse_f32(val)
            cfg.textbox_padding = v

        case "choice_w":
            v, _ := strconv.parse_f32(val)
            cfg.choice_w = v
        case "choice_h":
            v, _ := strconv.parse_f32(val)
            cfg.choice_h = v
        case "choice_spacing":
            v, _ := strconv.parse_f32(val)
            cfg.choice_spacing = v
        case "choice_color_idle": cfg.choice_color_idle = parse_hex_color(val)
        case "choice_color_hov":  cfg.choice_color_hov  = parse_hex_color(val)
        case "choice_text_idle":  cfg.choice_text_idle  = parse_hex_color(val)
        case "choice_text_hov":   cfg.choice_text_hov   = parse_hex_color(val)
        
        case "text_speed":      
            v, _ := strconv.parse_f32(val)
            cfg.text_speed = v
        }
        
        delete(parts)
    }
    
    fmt.printf("[vnefall] Configuration loaded from %s\n", path)
    return true
}

config_cleanup :: proc() {
    delete(cfg.window_title)
    delete(cfg.path_assets)
    delete(cfg.path_images)
    delete(cfg.path_music)
    delete(cfg.path_scripts)
    delete(cfg.path_manifests)
    delete(cfg.path_characters)
    delete(cfg.path_saves)
    delete(cfg.entry_script)
}

// Parses 0xRRGGBBAA or #RRGGBBAA into [4]f32
parse_hex_color :: proc(hex: string) -> [4]f32 {
    clean := hex
    if strings.has_prefix(clean, "0x") do clean = clean[2:]
    if strings.has_prefix(clean, "#")  do clean = clean[1:]
    
    if len(clean) != 8 {
        return {1, 1, 1, 1}
    }
    
    r := f32(parse_hex_byte(clean[0:2])) / 255.0
    g := f32(parse_hex_byte(clean[2:4])) / 255.0
    b := f32(parse_hex_byte(clean[4:6])) / 255.0
    a := f32(parse_hex_byte(clean[6:8])) / 255.0
    
    return {r, g, b, a}
}

parse_hex_byte :: proc(s: string) -> int {
    val, _ := strconv.parse_int(s, 16)
    return val
}
