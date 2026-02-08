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
import vneui "vneui:src"

VERSION :: "1.5.0"

load_menu_bg_texture :: proc(label, path: string) -> u32 {
    if path == "" do return 0
    info := texture_load(path)
    if info.id == 0 {
        fmt.eprintln("Warning: Could not load", label, ":", path)
        return 0
    }
    return info.id
}

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
    video:        Video_State,
    
    current_bg:   u32,           // OpenGL texture handle
    bg_transition: BG_Transition,
    bg_blur_strength: f32,
    bg_blur_base: f32,
    bg_blur_override_active: bool,
    bg_blur:     BG_Blur_State,
    loading_tex:  u32,
    loading_active: bool,
    menu_bg_tex:  u32,
    menu_bg_start_tex: u32,
    menu_bg_pause_tex: u32,
    menu_bg_settings_tex: u32,
    menu_intro_tex: u32,
    menu_intro_active: bool,
    menu_intro_timer: f32,
    textbox_tex:  u32,
    choice_tex_idle: u32,
    choice_tex_hov:  u32,
    textbox:      Textbox_State,
    choice:       Choice_State,
    menu:         Menu_State,
    save_list_state: vneui.UI_Save_List_State,
    last_tick:    u32,
}

Textbox_State :: struct {
    visible:      bool,
    force_hidden: bool,
    show_on_click: bool,
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

    menu_config_load_all(base_dir)

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
        window_update_size(&g.window)
        if g.input.menu_pressed {
            menu_toggle(&g)
        }
        menu_intro_update(&g, dt)
        textbox_update(&g.textbox, dt)
        bg_transition_update(&g, dt)
        character_update(dt)
        if video_update(&g.video, dt) {
            audio_stop_video(&g.audio)
        }
        
        if !g.menu.active && g.choice.active {
            // Keyboard shortcuts 1-9
            np := g.input.number_pressed
            if np > 0 && np <= len(g.choice.options) {
                choice_apply(&g, np-1)
            }
        } else if !g.menu.active && g.input.advance_pressed {
            if g.video.wait_for_click {
                g.video.wait_for_click = false
                if g.video.hold_last {
                    video_pause(&g.video)
                } else {
                    video_stop(&g.video)
                }
                audio_stop_video(&g.audio)
                if g.textbox.show_on_click {
                    g.textbox.show_on_click = false
                    g.textbox.force_hidden = false
                    g.textbox.visible = true
                }
                script_advance(&g.script, &g)
            } else if g.textbox.show_on_click {
                g.textbox.show_on_click = false
                g.textbox.force_hidden = false
                g.textbox.visible = true
                // If we were waiting on a textbox/movie gate, advance once.
                script_advance(&g.script, &g)
            } else if g.textbox.visible && !textbox_is_revealed(&g.textbox) {
                textbox_reveal_all(&g.textbox)
            } else {
                script_advance(&g.script, &g)
            }
        }
        
        // IP stays here until the user clicks to advance
        if !g.menu.active && !g.script.waiting && g.script.ip < len(g.script.commands) {
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
        } else if g.bg_blur_strength > 0 {
            if !bg_blur_init(&g.bg_blur, &g.renderer) {
                if g.bg_transition.active {
                    bg_transition_draw(&g, &g.renderer)
                } else if g.current_bg != 0 {
                    renderer_draw_fullscreen(&g.renderer, g.current_bg)
                }
            } else {
                bg_blur_set_strength(&g.bg_blur, g.bg_blur_strength)
                needs_update := g.bg_transition.active ||
                    g.bg_blur.last_bg_tex != g.current_bg ||
                    g.bg_blur.last_strength != g.bg_blur.strength
                
                if needs_update {
                    bg_blur_begin_capture(&g.bg_blur, &g.renderer)
                    if g.bg_transition.active {
                        bg_transition_draw(&g, &g.renderer)
                    } else if g.current_bg != 0 {
                        renderer_draw_fullscreen(&g.renderer, g.current_bg)
                    }
                    bg_blur_end_capture(&g.bg_blur, &g.renderer, &g.window)
                    bg_blur_apply(&g.bg_blur, &g.renderer, &g.window, g.bg_blur.iterations)
                    g.bg_blur.last_bg_tex = g.current_bg
                    g.bg_blur.last_strength = g.bg_blur.strength
                }
                if g.bg_blur.tex_a != 0 {
                    renderer_draw_fullscreen(&g.renderer, g.bg_blur.tex_a)
                }
            }
        } else if g.bg_transition.active {
            bg_transition_draw(&g, &g.renderer)
        } else if g.current_bg != 0 {
            renderer_draw_fullscreen(&g.renderer, g.current_bg)
        }

        if g.video.active && g.video.layer == .Background {
            video_draw_layer(&g.video, &g.renderer)
        }
        
        character_draw_all(&g.renderer)

        if g.video.active && g.video.layer == .Foreground {
            video_draw_layer(&g.video, &g.renderer)
        }
        
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

    if g_settings.fullscreen {
        window_set_fullscreen(&g.window, true)
    }
    
    // Setup GL state
    if !renderer_init(&g.renderer) do return false
    _ = bg_blur_init(&g.bg_blur, &g.renderer)
    
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

    if menu_cfg.menu_bg_image != "" {
        g.menu_bg_tex = load_menu_bg_texture("menu background", menu_cfg.menu_bg_image)
    }
    g.menu_bg_start_tex = g.menu_bg_tex
    g.menu_bg_pause_tex = g.menu_bg_tex
    g.menu_bg_settings_tex = g.menu_bg_tex
    if menu_cfg.menu_bg_start_image != "" {
        if menu_cfg.menu_bg_start_image == menu_cfg.menu_bg_image {
            g.menu_bg_start_tex = g.menu_bg_tex
        } else {
            g.menu_bg_start_tex = load_menu_bg_texture("menu start background", menu_cfg.menu_bg_start_image)
        }
    }
    if menu_cfg.menu_bg_pause_image != "" {
        if menu_cfg.menu_bg_pause_image == menu_cfg.menu_bg_image {
            g.menu_bg_pause_tex = g.menu_bg_tex
        } else {
            g.menu_bg_pause_tex = load_menu_bg_texture("menu pause background", menu_cfg.menu_bg_pause_image)
        }
    }
    if menu_cfg.menu_bg_settings_image != "" {
        if menu_cfg.menu_bg_settings_image == menu_cfg.menu_bg_image {
            g.menu_bg_settings_tex = g.menu_bg_tex
        } else {
            g.menu_bg_settings_tex = load_menu_bg_texture("menu settings background", menu_cfg.menu_bg_settings_image)
        }
    }
    if menu_cfg.menu_intro_image != "" {
        g.menu_intro_tex = load_menu_bg_texture("menu intro image", menu_cfg.menu_intro_image)
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

    if menu_cfg.show_start_menu {
        menu_open_main(&g)
        if menu_cfg.menu_intro_image != "" {
            g.menu_intro_active = true
        }
    }
    
    g.running = true
    return true
}

cleanup_game :: proc() {
    choice_clear(&g)
    delete(g.choice.options)
    textbox_destroy(&g.textbox)
    video_cleanup(&g.video)
    bg_blur_cleanup(&g.bg_blur)
    script_destroy(&g.script)
    character_cleanup()
    scene_system_cleanup()
    audio_cleanup(&g.audio)
    ui_layer_shutdown()
    renderer_cleanup(&g.renderer)
    window_destroy(&g.window)
    ui_config_cleanup()
    menu_config_cleanup()
    char_registry_cleanup()
    settings_cleanup()
    config_cleanup()
}
