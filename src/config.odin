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
    path_ambience:   string,
    path_sfx:        string,
    path_voice:      string,
    path_scripts:    string,
    path_manifests:  string,
    path_characters: string,
    path_saves:      string,
    entry_script:    string,
    
    // Audio (defaults)
    volume_master:   f32,
    volume_music:    f32,
    volume_ambience: f32,
    volume_sfx:      f32,
    volume_voice:    f32,
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
    
    cfg.path_assets    = strings.clone("demo/assets/")
    cfg.path_images    = strings.clone("demo/assets/images/")
    cfg.path_music     = strings.clone("demo/assets/music/")
    cfg.path_ambience  = strings.clone("demo/assets/ambience/")
    cfg.path_sfx       = strings.clone("demo/assets/sfx/")
    cfg.path_voice     = strings.clone("demo/assets/voice/")
    cfg.path_scripts   = strings.clone("demo/assets/scripts/")
    cfg.path_manifests = strings.clone("demo/assets/manifests/")
    cfg.path_characters = strings.clone("demo/assets/images/characters/")
    cfg.path_saves     = strings.clone("demo/saves/")
    cfg.entry_script   = strings.clone("demo/assets/scripts/demo.vnef")
    
    cfg.volume_master = 1.0
    cfg.volume_music  = 1.0
    cfg.volume_ambience = 1.0
    cfg.volume_sfx    = 1.0
    cfg.volume_voice  = 1.0
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
        case "path_ambience":
            delete(cfg.path_ambience)
            cfg.path_ambience = strings.clone(strings.trim(val, "\""))
        case "path_sfx":
            delete(cfg.path_sfx)
            cfg.path_sfx      = strings.clone(strings.trim(val, "\""))
        case "path_voice":
            delete(cfg.path_voice)
            cfg.path_voice    = strings.clone(strings.trim(val, "\""))
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
        
        case "volume_master":
            v, _ := strconv.parse_f32(val)
            cfg.volume_master = v
        case "volume_music":
            v, _ := strconv.parse_f32(val)
            cfg.volume_music = v
        case "volume_ambience":
            v, _ := strconv.parse_f32(val)
            cfg.volume_ambience = v
        case "volume_sfx":
            v, _ := strconv.parse_f32(val)
            cfg.volume_sfx = v
        case "volume_voice":
            v, _ := strconv.parse_f32(val)
            cfg.volume_voice = v
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
    delete(cfg.path_ambience)
    delete(cfg.path_sfx)
    delete(cfg.path_voice)
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
