/*
    Vnefall Scene System
    
    Scenes group assets together with their own memory arena.
    When a scene is unloaded, all its memory is freed at once.
    Prefetching loads the next scene in the background while
    the current scene is still playing.
*/

package vnefall

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"
import gl "vendor:OpenGL"

Scene :: struct {
    name:     string,
    manifest: Manifest,
    textures: map[string]u32,  // path -> OpenGL texture ID
    ready:    bool,            // True when all assets are loaded
    loading:  bool,            // True while loading in background
}

Scene_Manager :: struct {
    current:        ^Scene,
    next:           ^Scene,         // Being prefetched
    prefetch_mutex: sync.Mutex,     // Protect next scene access
}

// Global scene manager
g_scenes: Scene_Manager

// Initialize the scene system
scene_init :: proc() {
    g_scenes.current = nil
    g_scenes.next = nil
    
    // Ensure manifest directory exists
    if !os.exists(cfg.path_manifests) {
        os.make_directory(cfg.path_manifests)
    }
}

// Load a scene synchronously (blocking)
scene_load_sync :: proc(script_path: string) -> ^Scene {
    s := new(Scene)
    s.name = strings.clone(script_path)
    s.textures = make(map[string]u32)
    s.ready = false
    s.loading = true
    
    // Try to load existing manifest, or generate one
    manifest_path := manifest_path_from_script(script_path)
    defer delete(manifest_path)
    
    needs_rebuild := !os.exists(manifest_path)
    if !needs_rebuild {
        s_info, s_err := os.stat(script_path)
        m_info, m_err := os.stat(manifest_path)
        
        if s_err == os.ERROR_NONE && m_err == os.ERROR_NONE {
            if time.diff(m_info.modification_time, s_info.modification_time) > 0 {
                fmt.println("[scene] Script updated, regenerating manifest:", manifest_path)
                needs_rebuild = true
            }
            os.file_info_delete(s_info)
            os.file_info_delete(m_info)
        }
    }

    manifest: Manifest
    ok: bool
    if !needs_rebuild {
        manifest, ok = manifest_load(manifest_path)
        if !ok do needs_rebuild = true
    }

    if needs_rebuild {
        // Generate manifest from script
        manifest, ok = manifest_generate(script_path)
        if ok {
            // Save for future runs
            manifest_save(&manifest, manifest_path)
        }
    }
    s.manifest = manifest
    
    // Load all textures
    scene_load_textures(s, nil)
    audio_prefetch_scene(&g.audio, &s.manifest)
    
    s.ready = true
    s.loading = false
    fmt.printf("[scene] Loaded scene: %s (%d textures)\n", s.name, len(s.textures))
    
    return s
}

// Internal helper to load all textures in a manifest
@(private)
scene_load_textures :: proc(s: ^Scene, reuse: ^Scene) {
    for bg in s.manifest.backgrounds {
        if reuse != nil {
            if tex, ok := reuse.textures[bg]; ok {
                s.textures[strings.clone(bg)] = tex
                continue
            }
        }
        
        path := strings.concatenate({cfg.path_images, bg})
        defer delete(path)
        info := texture_load(path)
        if info.id != 0 {
            s.textures[strings.clone(bg)] = info.id
        }
    }
    
    for sp in s.manifest.sprites {
        if reuse != nil {
            if tex, ok := reuse.textures[sp]; ok {
                s.textures[strings.clone(sp)] = tex
                continue
            }
        }
        
        path := strings.concatenate({cfg.path_images, sp})
        defer delete(path)
        info := texture_load(path)
        if info.id != 0 {
            s.textures[strings.clone(sp)] = info.id
        }
    }
}

// Cleanup a scene and free all its resources
scene_cleanup :: proc(s: ^Scene) {
    if s == nil do return
    
    delete(s.name)
    audio_flush_scene(&g.audio, &s.manifest)
    
    // Delete OpenGL textures owned by this scene
    for path, &tex in s.textures {
        full := strings.concatenate({cfg.path_images, path})
        texture_release(full)
        delete(full)
        delete(path)
    }
    delete(s.textures)
    
    manifest_cleanup(&s.manifest)
    free(s)
}

// Cleanup a scene but keep shared assets from the next scene
scene_cleanup_keep :: proc(s: ^Scene, next: ^Scene) {
    if s == nil do return
    
    delete(s.name)
    audio_flush_scene_keep(&g.audio, &s.manifest, &next.manifest)
    
    // Delete OpenGL textures owned by this scene (skip shared)
    for path, &tex in s.textures {
        shared := false
        if contains_string_scene(next.manifest.backgrounds[:], path) do shared = true
        if !shared && contains_string_scene(next.manifest.sprites[:], path) do shared = true
        
        if !shared {
            full := strings.concatenate({cfg.path_images, path})
            texture_release(full)
            delete(full)
        }
        delete(path)
    }
    delete(s.textures)
    
    manifest_cleanup(&s.manifest)
    free(s)
}

@(private)
contains_string_scene :: proc(slice: []string, s: string) -> bool {
    for item in slice {
        if item == s do return true
    }
    return false
}

// Start prefetching a scene in the background
scene_prefetch :: proc(script_path: string) {
    // If already prefetching something, skip
    sync.mutex_lock(&g_scenes.prefetch_mutex)
    defer sync.mutex_unlock(&g_scenes.prefetch_mutex)
    
    if g_scenes.next != nil && g_scenes.next.loading {
        fmt.println("[scene] Already prefetching, skipping:", script_path)
        return
    }
    
    // Clean up any old prefetched scene that wasn't used
    if g_scenes.next != nil {
        scene_cleanup(g_scenes.next)
        g_scenes.next = nil
    }
    
    // Support manual clear via "none"
    if script_path == "none" {
        fmt.println("[scene] Prefetch cleared: textures + audio freed.")
        return
    }
    
    // Start background loading
    fmt.println("[scene] Starting prefetch for:", script_path)
    
    // Create scene struct first (on main thread)
    s := new(Scene)
    s.name = strings.clone(script_path)
    s.textures = make(map[string]u32)
    s.ready = false
    s.loading = true
    g_scenes.next = s
    
    // Load manifest (needed for asset paths)
    manifest_path := manifest_path_from_script(script_path)
    defer delete(manifest_path)

    needs_rebuild := !os.exists(manifest_path)
    if !needs_rebuild {
        s_info, s_err := os.stat(script_path)
        m_info, m_err := os.stat(manifest_path)
        
        if s_err == os.ERROR_NONE && m_err == os.ERROR_NONE {
            if time.diff(m_info.modification_time, s_info.modification_time) > 0 {
                fmt.println("[scene] Script updated, regenerating prefetch manifest:", manifest_path)
                needs_rebuild = true
            }
            os.file_info_delete(s_info)
            os.file_info_delete(m_info)
        }
    }

    manifest: Manifest
    ok: bool
    if !needs_rebuild {
        manifest, ok = manifest_load(manifest_path)
        if !ok do needs_rebuild = true
    }

    if needs_rebuild {
        manifest, ok = manifest_generate(script_path)
        if ok {
            manifest_save(&manifest, manifest_path)
        }
    }
    s.manifest = manifest
    
    // Load textures immediately (main thread for OpenGL safety)
    scene_load_textures(s, g_scenes.current)
    audio_prefetch_scene(&g.audio, &s.manifest)
    
    s.loading = false
    s.ready = true
}

// Switch to the prefetched scene (call after scene_prefetch)
scene_switch :: proc() -> bool {
    sync.mutex_lock(&g_scenes.prefetch_mutex)
    defer sync.mutex_unlock(&g_scenes.prefetch_mutex)
    
    if g_scenes.next == nil {
        fmt.eprintln("[scene] No prefetched scene to switch to!")
        return false
    }
    
    // Cleanup current scene
    if g_scenes.current != nil {
        scene_cleanup_keep(g_scenes.current, g_scenes.next)
    }
    
    // Switch
    g_scenes.current = g_scenes.next
    g_scenes.next = nil
    
    // Maintain background ID if possible to avoid black screen flash
    if g.script.bg_path != "" {
        tex := scene_get_texture(g.script.bg_path)
        if tex != 0 do g.current_bg = tex
        else do g.current_bg = 0
    } else {
        g.current_bg = 0
    }
    
    fmt.println("[scene] Switched to scene:", g_scenes.current.name)
    return true
}

// Get a texture from the current scene (with fallback to global cache)
scene_get_texture :: proc(name: string) -> u32 {
    // Check current scene first
    if g_scenes.current != nil {
        if tex, ok := g_scenes.current.textures[name]; ok {
            return tex
        }
    }
    
    // Fallback to loading from disk
    ext := ".png"
    if strings.contains(name, ".") do ext = ""
    
    path := strings.concatenate({cfg.path_images, name, ext})
    defer delete(path)
    return texture_load(path).id
}

// Cleanup the entire scene system
scene_system_cleanup :: proc() {
    if g_scenes.current != nil {
        scene_cleanup(g_scenes.current)
        g_scenes.current = nil
    }
    if g_scenes.next != nil {
        scene_cleanup(g_scenes.next)
        g_scenes.next = nil
    }
}
