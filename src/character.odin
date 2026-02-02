package vnefall

import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:slice"

Character :: struct {
    name:       string,
    texture:    u32,      // Texture handle
    width:      f32,      // Actual texture width
    height:     f32,      // Actual texture height
    
    // State
    sprite_path: string,    // e.g. "happy"
    pos_name:    string,    // e.g. "center" or "400"
    pos_x:      f32,
    pos_y:      f32,
    z:          i32,      // Z-index (higher draws in front)
    visible:    bool,
}

// The "Backstage" (Dharana Cache)
g_characters: map[string]Character

character_init :: proc() {
    g_characters = make(map[string]Character)
}

character_cleanup :: proc() {
    for k, v in g_characters {
        delete(v.name)
        delete(v.sprite_path)
        delete(v.pos_name)
    }
    delete(g_characters)
}

character_get_position :: proc(pos_name: string) -> f32 {
    w := cfg.design_width
    
    switch pos_name {
    case "left":   return w * 0.25
    case "center": return w * 0.50
    case "right":  return w * 0.75
    }
    
    // If it's a number, parse it
    val, ok := strconv.parse_f32(pos_name)
    if ok do return val
    
    return w * 0.50
}

character_show :: proc(name: string, sprite_path: string, pos_name: string, z: i32 = 0) {
    target_x := character_get_position(pos_name)
    
    // Load texture with dimensions
    ext := ".png"
    if strings.contains(sprite_path, ".") do ext = ""
    
    path := strings.concatenate({"characters/", name, "/", sprite_path, ext})
    defer delete(path)
    
    full_path := strings.concatenate({cfg.path_images, path})
    defer delete(full_path)
    
    info := texture_load(full_path)
    if info.id == 0 {
        fmt.eprintln("[character] Failed to load sprite:", full_path)
        return
    }
    
    // Scale to fit within 80% of screen height (like Ren'Py)
    max_height := cfg.design_height * 0.80
    original_w := f32(info.width)
    original_h := f32(info.height)
    
    scale: f32 = 1.0
    if original_h > max_height {
        scale = max_height / original_h
    }
    
    final_w := original_w * scale
    final_h := original_h * scale
    
    // Calculate Y position: bottom-aligned to screen
    target_y := cfg.design_height - (final_h / 2)

    if char, exists := g_characters[name]; exists {
        if char.sprite_path != "" do delete(char.sprite_path)
        if char.pos_name != ""    do delete(char.pos_name)
        
        char.sprite_path = strings.clone(sprite_path)
        char.pos_name    = strings.clone(pos_name)
        char.pos_x   = target_x
        char.pos_y   = target_y
        char.texture = info.id
        char.width   = final_w
        char.height  = final_h
        char.z       = z
        char.visible = true
        g_characters[name] = char
    } else {
        new_char := Character{
            name    = strings.clone(name),
            sprite_path = strings.clone(sprite_path),
            pos_name    = strings.clone(pos_name),
            pos_x   = target_x,
            pos_y   = target_y,
            z       = z,
            texture = info.id,
            width   = final_w,
            height  = final_h,
            visible = true,
        }
        g_characters[name] = new_char
    }
}

character_hide :: proc(name: string) {
    if char, exists := g_characters[name]; exists {
        delete(char.name)
        delete(char.sprite_path)
        delete(char.pos_name)
        delete_key(&g_characters, name)
        fmt.printf("[character] Flushed character: %s\n", name)
    }
}

// Hard flush all characters (call on script switch)
character_flush_all :: proc() {
    for k, v in g_characters {
        delete(v.name)
        delete(v.sprite_path)
        delete(v.pos_name)
    }
    clear(&g_characters)
    fmt.println("[character] Flushed all characters")
}

character_draw_all :: proc(r: ^Renderer) {
    // Collect visible characters
    active := make([dynamic]Character, context.temp_allocator)
    for _, char in g_characters {
        if char.visible && char.texture != 0 {
            append(&active, char)
        }
    }
    
    // Sort by Z index
    slice.sort_by(active[:], proc(a, b: Character) -> bool {
        return a.z < b.z
    })
    
    // Draw in order
    for char in active {
        w := char.width
        h := char.height
        x := char.pos_x - (w / 2)
        y := char.pos_y - (h / 2)
        
        renderer_draw_texture(r, char.texture, x, y, w, h)
    }
}
