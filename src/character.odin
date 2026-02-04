package vnefall

import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:slice"
import "core:math"

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
    alpha:      f32,
    fade_active: bool,
    fade_dir:   f32,
    fade_duration: f32,
    pending_remove: bool,
    slide_active: bool,
    slide_t:      f32,
    slide_duration: f32,
    slide_from_x: f32,
    slide_to_x:   f32,
    shake_active: bool,
    shake_t:      f32,
    shake_duration: f32,
    shake_amp:    f32,
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

character_offscreen_x :: proc(target_x, sprite_w: f32) -> f32 {
    mid := cfg.design_width * 0.5
    pad := sprite_w * 0.6
    if target_x <= mid {
        return -pad
    }
    return cfg.design_width + pad
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

    t_kind := bg_transition_kind_from_string(ui_cfg.char_transition)
    fade_ms := ui_cfg.char_fade_ms
    if t_kind == .Slide {
        fade_ms = ui_cfg.char_slide_ms
    } else if t_kind == .Shake {
        fade_ms = ui_cfg.char_shake_ms
    }
    if k, ms, ok := transition_take_override(); ok {
        t_kind = k
        if ms >= 0 {
            fade_ms = ms
        }
    }
    if fade_ms < 0 do fade_ms = 0
    if t_kind == .None {
        fade_ms = 0
    }
    use_slide := t_kind == .Slide
    use_shake := t_kind == .Shake
    use_fade := !use_slide && t_kind != .None

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
        char.pending_remove = false
        char.fade_active = false
        char.fade_duration = 0
        char.slide_active = false
        char.slide_duration = 0
        char.shake_active = false
        char.shake_duration = 0
        if use_slide && fade_ms > 0 {
            start_x := character_offscreen_x(target_x, final_w)
            char.pos_x = start_x
            char.slide_active = true
            char.slide_t = 0
            char.slide_duration = fade_ms
            char.slide_from_x = start_x
            char.slide_to_x = target_x
            char.alpha = 1
        } else if use_fade && fade_ms > 0 {
            char.alpha = 0
            char.fade_active = true
            char.fade_dir = 1
            char.fade_duration = fade_ms
        } else {
            char.alpha = 1
        }
        if use_shake && fade_ms > 0 {
            char.shake_active = true
            char.shake_t = 0
            char.shake_duration = fade_ms
            char.shake_amp = ui_cfg.char_shake_px
            if char.shake_amp <= 0 do char.shake_amp = 8
        }
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
            alpha   = 1,
        }
        if use_slide && fade_ms > 0 {
            start_x := character_offscreen_x(target_x, final_w)
            new_char.pos_x = start_x
            new_char.slide_active = true
            new_char.slide_t = 0
            new_char.slide_duration = fade_ms
            new_char.slide_from_x = start_x
            new_char.slide_to_x = target_x
        } else if use_fade && fade_ms > 0 {
            new_char.alpha = 0
            new_char.fade_active = true
            new_char.fade_dir = 1
            new_char.fade_duration = fade_ms
        }
        if use_shake && fade_ms > 0 {
            new_char.shake_active = true
            new_char.shake_t = 0
            new_char.shake_duration = fade_ms
            new_char.shake_amp = ui_cfg.char_shake_px
            if new_char.shake_amp <= 0 do new_char.shake_amp = 8
        }
        g_characters[name] = new_char
    }
}

character_hide :: proc(name: string) {
    if char, exists := g_characters[name]; exists {
        t_kind := bg_transition_kind_from_string(ui_cfg.char_transition)
        fade_ms := ui_cfg.char_fade_ms
        if t_kind == .Slide {
            fade_ms = ui_cfg.char_slide_ms
        } else if t_kind == .Shake {
            fade_ms = ui_cfg.char_shake_ms
        }
        if k, ms, ok := transition_take_override(); ok {
            t_kind = k
            if ms >= 0 {
                fade_ms = ms
            }
        }
        if fade_ms < 0 do fade_ms = 0
        if t_kind == .None {
            fade_ms = 0
        }

        if t_kind == .Slide && fade_ms > 0 {
            target_x := character_offscreen_x(char.pos_x, char.width)
            char.slide_active = true
            char.slide_t = 0
            char.slide_duration = fade_ms
            char.slide_from_x = char.pos_x
            char.slide_to_x = target_x
            char.pending_remove = true
            char.fade_active = false
            char.alpha = 1
            g_characters[name] = char
        } else if fade_ms > 0 {
            char.fade_active = true
            char.fade_dir = -1
            char.fade_duration = fade_ms
            char.pending_remove = true
            char.slide_active = false
            if t_kind == .Shake {
                char.shake_active = true
                char.shake_t = 0
                char.shake_duration = fade_ms
                char.shake_amp = ui_cfg.char_shake_px
                if char.shake_amp <= 0 do char.shake_amp = 8
            }
            g_characters[name] = char
        } else {
            delete(char.name)
            delete(char.sprite_path)
            delete(char.pos_name)
            delete_key(&g_characters, name)
            fmt.printf("[character] Flushed character: %s\n", name)
        }
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
        shake_x: f32 = 0
        shake_y: f32 = 0
        if char.shake_active && char.shake_duration > 0 {
            t := char.shake_t / (char.shake_duration / 1000.0)
            if t < 0 do t = 0
            if t > 1 do t = 1
            amp := char.shake_amp * (1 - t)
            shake_x = math.sin(char.shake_t * 60) * amp
            shake_y = math.cos(char.shake_t * 53) * amp
        }
        x := (char.pos_x + shake_x) - (w / 2)
        y := (char.pos_y + shake_y) - (h / 2)
        
        alpha := char.alpha
        if alpha <= 0 do continue
        renderer_draw_texture_tinted(r, char.texture, x, y, w, h, {1, 1, 1, alpha})
    }
}

character_update :: proc(dt: f32) {
    to_remove: [dynamic]string
    for name, &char in g_characters {
        if char.fade_active {
            if char.fade_duration <= 0 {
                char.fade_active = false
            } else {
                step := dt / (char.fade_duration / 1000.0)
                char.alpha += step * char.fade_dir
                if char.alpha >= 1 {
                    char.alpha = 1
                    char.fade_active = false
                } else if char.alpha <= 0 {
                    char.alpha = 0
                    char.fade_active = false
                    if char.pending_remove {
                        append(&to_remove, name)
                        continue
                    }
                }
            }
        }

        if char.slide_active {
            if char.slide_duration <= 0 {
                char.slide_active = false
                char.pos_x = char.slide_to_x
                if char.pending_remove {
                    append(&to_remove, name)
                    continue
                }
            } else {
                char.slide_t += dt
                t := char.slide_t / (char.slide_duration / 1000.0)
                if t >= 1 {
                    char.slide_active = false
                    char.pos_x = char.slide_to_x
                    if char.pending_remove {
                        append(&to_remove, name)
                        continue
                    }
                } else {
                    eased := t * t * (3 - 2*t)
                    char.pos_x = char.slide_from_x + (char.slide_to_x - char.slide_from_x) * eased
                }
            }
        }

        if char.shake_active {
            if char.shake_duration <= 0 {
                char.shake_active = false
            } else {
                char.shake_t += dt
                if char.shake_t >= (char.shake_duration / 1000.0) {
                    char.shake_active = false
                }
            }
        }

        if char.pending_remove && !char.fade_active && !char.slide_active && !char.shake_active {
            append(&to_remove, name)
            continue
        }
    }

    for name in to_remove {
        if char, ok := g_characters[name]; ok {
            delete(char.name)
            delete(char.sprite_path)
            delete(char.pos_name)
            delete_key(&g_characters, name)
        }
    }
    delete(to_remove)
}
