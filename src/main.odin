/*
    vnefall — A simple VN engine.
    
    This is the main entry point where we glue everything together. 
    It handles the lifecycle: init, the loop, and cleaning up.
*/

package vnefall

import "core:fmt"
import "core:os"
import "core:strings"
import "core:mem"
import SDL "vendor:sdl2"

VERSION :: "1.3.0"

Choice_Option :: struct {
    text:  string,
    label: string,
}

Choice_State :: struct {
    active:  bool,
    options: [dynamic]Choice_Option,
    selected: int,
}

// State of the whole game world
Game_State :: struct {
    running:      bool,
    window:       Window,
    renderer:     Renderer,
    audio:        Audio_State,
    script:       Script,
    input:        Input_State,
    
    current_bg:   u32,           // OpenGL texture handle
    loading_tex:  u32,
    loading_active: bool,
    textbox:      Textbox_State,
    choice:       Choice_State,
}

Textbox_State :: struct {
    visible:      bool,
    speaker:      string,
    text:         string,
}

// Global state to keep things simple for v1
g: Game_State

main :: proc() {
    // Setup tracking allocator to detect leaks
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)
    
    defer {
        if len(track.allocation_map) > 0 {
            fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
            for _, entry in track.allocation_map {
                fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
            }
        }
        if len(track.bad_free_array) > 0 {
            fmt.eprintf("=== %v bad frees detected: ===\n", len(track.bad_free_array))
            for entry in track.bad_free_array {
                fmt.eprintf("- %v @ %v\n", entry.memory, entry.location)
            }
        }
        mem.tracking_allocator_destroy(&track)
    }

    // Load config first so we know where everything is
    config_load("config.vnef")
    settings_load()
    
    // Check if we passed a script path, otherwise fallback to config entry
    args := os.args
    script_path := cfg.entry_script
    
    if len(args) >= 2 {
        script_path = args[1]
    } else {
        fmt.println("[vnefall] using default script:", script_path)
    }
    
    // Kick things off
    if !init_game(script_path) {
        fmt.eprintln("Failed to start engine.")
        os.exit(1)
    }
    defer cleanup_game()
    
    // Game loop
    for g.running {
        input_poll(&g.input, &g.running)
        
        if g.choice.active {
            // Translate mouse to virtual coordinates
            mx := f32(g.input.mouse_x) * (cfg.design_width / f32(g.window.width))
            my := f32(g.input.mouse_y) * (cfg.design_height / f32(g.window.height))
            
            // Re-calculate button layout (same as in renderer)
            count := len(g.choice.options)
            button_w := cfg.choice_w
            button_h := cfg.choice_h
            spacing  := cfg.choice_spacing
            total_h  := f32(count) * button_h + f32(count - 1) * spacing
            start_y  := (cfg.design_height - total_h) / 2
            bx       := (cfg.design_width - button_w) / 2
            
            // Check mouse hover
            hovered_idx := -1
            for i in 0..<count {
                by := start_y + f32(i) * (button_h + spacing)
                if mx >= bx && mx <= bx + button_w && my >= by && my <= by + button_h {
                    g.choice.selected = i
                    hovered_idx = i
                    break
                }
            }

            if g.input.up_pressed {
                g.choice.selected = max(0, g.choice.selected - 1)
            }
            if g.input.down_pressed {
                g.choice.selected = min(len(g.choice.options) - 1, g.choice.selected + 1)
            }
            
            if g.input.number_pressed > 0 && g.input.number_pressed <= count {
                g.choice.selected = g.input.number_pressed - 1
                g.input.select_pressed = true
            }
            if g.input.select_pressed {
                // If this was a mouse click, we MUST be hovering over the button
                if !g.input.mouse_clicked || (g.input.mouse_clicked && hovered_idx != -1) {
                    choice := g.choice.options[g.choice.selected]
                    target_label := strings.clone(choice.label)
                    defer delete(target_label)
                    
                    choice_clear(&g)
                    g.choice.active = false
                    
                    if target, ok := g.script.labels[target_label]; ok {
                        g.script.ip = target
                        g.script.waiting = false
                        g.textbox.visible = false
                    }
                }
            }
            
            // Keyboard shortcuts 1-9
            np := g.input.number_pressed
            if np > 0 && np <= len(g.choice.options) {
                target_label := g.choice.options[np-1].label
                if target, ok := g.script.labels[target_label]; ok {
                    choice_clear(&g)
                    g.choice.active = false
                    g.script.ip = target
                    g.script.waiting = false
                    g.textbox.visible = false
                }
            }
        } else if g.input.advance_pressed {
            script_advance(&g.script, &g)
        }
        
        // IP stays here until the user clicks to advance
        if !g.script.waiting && g.script.ip < len(g.script.commands) {
            script_execute(&g.script, &g)
        }
        
        renderer_begin(&g.renderer, &g.window)
        
        if g.loading_active {
            if g.loading_tex != 0 {
                renderer_draw_fullscreen(&g.renderer, g.loading_tex)
            } else {
                renderer_draw_rect(&g.renderer, 0, 0, cfg.design_width, cfg.design_height, {0.02, 0.02, 0.05, 1.0})
                msg := "Loading..."
                tw := font_text_width(msg)
                tx := (cfg.design_width - tw) / 2
                ty := cfg.design_height / 2
                renderer_draw_text(&g.renderer, msg, tx, ty, cfg.color_text)
            }
        } else if g.current_bg != 0 {
            renderer_draw_fullscreen(&g.renderer, g.current_bg)
        }
        
        character_draw_all(&g.renderer)
        
        if g.textbox.visible {
            renderer_draw_textbox(&g.renderer, g.textbox.speaker, g.textbox.text)
        }
        
        if g.choice.active {
            renderer_draw_choice_menu(&g.renderer, g.choice.options, g.choice.selected)
        }
        
        renderer_end(&g.renderer, &g.window)
    }
    
    fmt.println("Cleaning up and exiting.")
}

init_game :: proc(script_path: string) -> bool {
    fmt.printf("[vnefall] Starting up v%s...\n", VERSION)
    
    // Need a window first
    title_cstr := strings.clone_to_cstring(cfg.window_title)
    defer delete(title_cstr)
    if !window_create(&g.window, title_cstr, cfg.window_width, cfg.window_height) do return false
    
    // Setup GL state
    if !renderer_init(&g.renderer) do return false
    
    // Audio is optional, don't crash if it fails
    if !audio_init(&g.audio) {
        fmt.eprintln("Warning: Audio init failed.")
    } else {
        audio_apply_settings(&g.audio)
    }
    
    // Try to get our default font
    font_path := strings.concatenate({cfg.path_assets, "fonts/default.ttf"})
    defer delete(font_path)
    if !font_load(font_path) {
        fmt.eprintln("Warning: Could not load default font.")
    }
    
    // Optional loading screen image
    if cfg.loading_image != "" {
        load_path := strings.concatenate({cfg.path_images, cfg.loading_image})
        defer delete(load_path)
        info := texture_load(load_path)
        if info.id == 0 {
            fmt.eprintln("Warning: Could not load loading image:", load_path)
        } else {
            g.loading_tex = info.id
        }
    }
    
    // Finally, load the script file
    if !script_load(&g.script, script_path) {
        fmt.eprintln("Error: Failed to load script:", script_path)
        return false
    }
    
    // Initialize scene and character systems
    scene_init()
    character_init()
    g_scenes.current = scene_load_sync(script_path)
    
    g.running = true
    return true
}

cleanup_game :: proc() {
    choice_clear(&g)
    delete(g.choice.options)
    delete(g.textbox.text)
    script_destroy(&g.script)
    character_cleanup()
    scene_system_cleanup()
    audio_cleanup(&g.audio)
    renderer_cleanup(&g.renderer)
    window_destroy(&g.window)
    config_cleanup()
}
