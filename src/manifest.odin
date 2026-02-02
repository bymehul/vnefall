/*
    Vnefall Manifest System
    
    Manifests are simple text files that list all assets needed for a scene.
    The engine uses them to preload assets in the background.
    
    Format:
        # Comment
        bg image.png
        sprite character.png
        music track.ogg
*/

package vnefall

import "core:fmt"
import "core:os"
import "core:strings"

Manifest :: struct {
    name:        string,
    backgrounds: [dynamic]string,
    sprites:     [dynamic]string,
    music:       [dynamic]string,
}

// Generate a manifest by scanning a script file for asset commands
manifest_generate :: proc(script_path: string) -> (Manifest, bool) {
    m: Manifest
    
    // Derive manifest name from script path
    m.name = strings.clone(script_path)
    
    data, ok := os.read_entire_file(script_path)
    if !ok {
        fmt.eprintln("[manifest] Failed to read script:", script_path)
        return m, false
    }
    defer delete(data)
    
    content := string(data)
    lines := strings.split_lines(content)
    defer delete(lines)
    
    for line in lines {
        trimmed := strings.trim_space(line)
        if len(trimmed) == 0 || trimmed[0] == '#' do continue
        
        // Parse asset commands
        if strings.has_prefix(trimmed, "bg ") {
            asset := strings.trim_space(trimmed[3:])
            asset = strings.trim(asset, "\"")
            
            ext := ".png"
            if strings.contains(asset, ".") do ext = ""
            asset_full := strings.concatenate({asset, ext})
            defer delete(asset_full)

            if !contains_string(m.backgrounds[:], asset_full) {
                append(&m.backgrounds, strings.clone(asset_full))
            }
        } else if strings.has_prefix(trimmed, "sprite ") {
            asset := strings.trim_space(trimmed[7:])
            asset = strings.trim(asset, "\"")
            
            ext := ".png"
            if strings.contains(asset, ".") do ext = ""
            asset_full := strings.concatenate({asset, ext})
            defer delete(asset_full)

            if !contains_string(m.sprites[:], asset_full) {
                append(&m.sprites, strings.clone(asset_full))
            }
        } else if strings.has_prefix(trimmed, "char ") {
            // char [Name] show [Sprite] at [Pos]
            parts := strings.split(trimmed, " ")
            defer delete(parts)
            
            if len(parts) >= 4 && parts[2] == "show" {
                name := parts[1]
                sprite := parts[3]
                
                ext := ".png"
                if strings.contains(sprite, ".") do ext = ""
                
                // Construct path: characters/[Name]/[Sprite].png
                asset := strings.concatenate({"characters/", name, "/", sprite, ext})
                defer delete(asset)
                
                if !contains_string(m.sprites[:], asset) {
                    append(&m.sprites, strings.clone(asset))
                }
            }
        } else if strings.has_prefix(trimmed, "music ") {
            asset := strings.trim_space(trimmed[6:])
            asset = strings.trim(asset, "\"")
            
            ext := ".ogg"
            if strings.contains(asset, ".") do ext = ""
            asset_full := strings.concatenate({asset, ext})
            defer delete(asset_full)

            if !contains_string(m.music[:], asset_full) {
                append(&m.music, strings.clone(asset_full))
            }
        }
    }
    
    total := len(m.backgrounds) + len(m.sprites) + len(m.music)
    fmt.printf("[manifest] Generated manifest for %s: %d assets\n", script_path, total)
    
    return m, true
}

// Load a manifest from a .manifest file
manifest_load :: proc(path: string) -> (Manifest, bool) {
    m: Manifest
    
    data, ok := os.read_entire_file(path)
    if !ok {
        return m, false
    }
    defer delete(data)
    
    m.name = strings.clone(path)
    
    content := string(data)
    lines := strings.split_lines(content)
    defer delete(lines)
    
    for line in lines {
        trimmed := strings.trim_space(line)
        if len(trimmed) == 0 || trimmed[0] == '#' do continue
        
        if strings.has_prefix(trimmed, "bg ") {
            asset := strings.trim_space(trimmed[3:])
            append(&m.backgrounds, strings.clone(asset))
        } else if strings.has_prefix(trimmed, "sprite ") {
            asset := strings.trim_space(trimmed[7:])
            append(&m.sprites, strings.clone(asset))
        } else if strings.has_prefix(trimmed, "music ") {
            asset := strings.trim_space(trimmed[6:])
            append(&m.music, strings.clone(asset))
        }
    }
    
    return m, true
}

// Save a manifest to disk
manifest_save :: proc(m: ^Manifest, path: string) -> bool {
    b: strings.Builder
    strings.builder_init(&b)
    defer strings.builder_destroy(&b)
    
    strings.write_string(&b, "# Auto-generated manifest for ")
    strings.write_string(&b, m.name)
    strings.write_string(&b, "\n\n")
    
    for bg in m.backgrounds {
        strings.write_string(&b, "bg ")
        strings.write_string(&b, bg)
        strings.write_string(&b, "\n")
    }
    
    for sp in m.sprites {
        strings.write_string(&b, "sprite ")
        strings.write_string(&b, sp)
        strings.write_string(&b, "\n")
    }
    
    for mu in m.music {
        strings.write_string(&b, "music ")
        strings.write_string(&b, mu)
        strings.write_string(&b, "\n")
    }
    
    content := strings.to_string(b)
    ok := os.write_entire_file(path, transmute([]u8)content)
    return ok
}

// Cleanup manifest memory
manifest_cleanup :: proc(m: ^Manifest) {
    delete(m.name)
    for bg in m.backgrounds do delete(bg)
    delete(m.backgrounds)
    for sp in m.sprites do delete(sp)
    delete(m.sprites)
    for mu in m.music do delete(mu)
    delete(m.music)
}

// Helper to check if a string is in a slice
@(private)
contains_string :: proc(slice: []string, s: string) -> bool {
    for item in slice {
        if item == s do return true
    }
    return false
}

// Get manifest path from script path
manifest_path_from_script :: proc(script_path: string) -> string {
    // Extract just the filename
    filename := script_path
    for i := len(script_path) - 1; i >= 0; i -= 1 {
        if script_path[i] == '/' || script_path[i] == '\\' {
            filename = script_path[i+1:]
            break
        }
    }
    
    // Replace .vnef with .manifest
    if strings.has_suffix(filename, ".vnef") {
        base := filename[:len(filename) - 5]
        return strings.concatenate({cfg.path_manifests, base, ".manifest"})
    }
    return strings.concatenate({cfg.path_manifests, filename, ".manifest"})
}
