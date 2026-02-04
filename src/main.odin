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

VERSION :: "1.4.1"

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
    bg_transition: BG_Transition,
    loading_tex:  u32,
    loading_active: bool,
    textbox_tex:  u32,
    choice_tex_idle: u32,
    choice_tex_hov:  u32,
    textbox:      Textbox_State,
    choice:       Choice_State,
    last_tick:    u32,
}

Textbox_State :: struct {
    visible:      bool,
    speaker:      string,
    text:         string,
    reveal_count: int,
    reveal_total: int,
    reveal_accum: f32,
    segments:     [dynamic]Text_Segment,
    shown_segments: [dynamic]Text_Segment,
    shake:        bool,
    speed_override: f32,
    speed_override_active: bool,
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
    config_path := "config.vnef"
    base_dir := ""
    if os.is_file("demo/config.vnef") {
        config_path = "demo/config.vnef"
        base_dir = "demo/"
    }
    config_load(config_path)

    ui_path := strings.concatenate({base_dir, "ui.vnef"})
    defer delete(ui_path)
    ui_config_load(ui_path)

    char_path := strings.concatenate({base_dir, "char.vnef"})
    defer delete(char_path)
    char_registry_load(char_path)

    settings_path := strings.concatenate({base_dir, "settings.vnef"})
    defer delete(settings_path)
    settings_set_path(settings_path)
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
        now := SDL.GetTicks()
        dt  := f32(now - g.last_tick) / 1000.0
        g.last_tick = now

        input_poll(&g.input, &g.running)
        textbox_update(&g.textbox, dt)
        bg_transition_update(&g, dt)
        character_update(dt)
        
        if g.choice.active {
            // Keyboard shortcuts 1-9
            np := g.input.number_pressed
            if np > 0 && np <= len(g.choice.options) {
                choice_apply(&g, np-1)
            }
        } else if g.input.advance_pressed {
            if g.textbox.visible && !textbox_is_revealed(&g.textbox) {
                textbox_reveal_all(&g.textbox)
            } else {
                script_advance(&g.script, &g)
            }
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
                renderer_draw_text(&g.renderer, msg, tx, ty, ui_cfg.text_color)
            }
        } else if g.bg_transition.active {
            bg_transition_draw(&g, &g.renderer)
        } else if g.current_bg != 0 {
            renderer_draw_fullscreen(&g.renderer, g.current_bg)
        }
        
        character_draw_all(&g.renderer)
        
        ui_layer_build_and_render(&g, &g.renderer, &g.window, dt)
        
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

    ui_layer_init()
    g.bg_transition.active = false
    
    // Optional loading screen image
    if ui_cfg.loading_image != "" {
        load_path := strings.concatenate({cfg.path_images, ui_cfg.loading_image})
        defer delete(load_path)
        info := texture_load(load_path)
        if info.id == 0 {
            fmt.eprintln("Warning: Could not load loading image:", load_path)
        } else {
            g.loading_tex = info.id
        }
    }

    // Optional UI textures
    if ui_cfg.textbox_image != "" {
        path := strings.concatenate({cfg.path_images, ui_cfg.textbox_image})
        defer delete(path)
        info := texture_load(path)
        if info.id != 0 do g.textbox_tex = info.id
    }
    if ui_cfg.choice_image_idle != "" {
        path := strings.concatenate({cfg.path_images, ui_cfg.choice_image_idle})
        defer delete(path)
        info := texture_load(path)
        if info.id != 0 do g.choice_tex_idle = info.id
    }
    if ui_cfg.choice_image_hov != "" {
        path := strings.concatenate({cfg.path_images, ui_cfg.choice_image_hov})
        defer delete(path)
        info := texture_load(path)
        if info.id != 0 do g.choice_tex_hov = info.id
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
    g.last_tick = SDL.GetTicks()
    
    g.running = true
    return true
}

cleanup_game :: proc() {
    choice_clear(&g)
    delete(g.choice.options)
    textbox_destroy(&g.textbox)
    script_destroy(&g.script)
    character_cleanup()
    scene_system_cleanup()
    audio_cleanup(&g.audio)
    ui_layer_shutdown()
    renderer_cleanup(&g.renderer)
    window_destroy(&g.window)
    ui_config_cleanup()
    char_registry_cleanup()
    settings_cleanup()
    config_cleanup()
}
