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
    ambience:    [dynamic]string,
    sfx:         [dynamic]string,
    voice:       [dynamic]string,
    videos:      [dynamic]string,
    video_audio: [dynamic]string,
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
            rest := strings.trim_space(trimmed[3:])
            asset := ""
            if len(rest) > 0 && rest[0] == '"' {
                q2 := strings.index(rest[1:], "\"")
                if q2 != -1 {
                    asset = rest[1 : 1+q2]
                } else {
                    asset = strings.trim(rest, "\"")
                }
            } else {
                parts := strings.split(rest, " ")
                defer delete(parts)
                if len(parts) >= 1 {
                    asset = parts[0]
                }
            }
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
        } else if strings.has_prefix(trimmed, "ambience ") {
            asset := strings.trim_space(trimmed[9:])
            asset = strings.trim(asset, "\"")
            
            ext := ".ogg"
            if strings.contains(asset, ".") do ext = ""
            asset_full := strings.concatenate({asset, ext})
            defer delete(asset_full)
            
            if !contains_string(m.ambience[:], asset_full) {
                append(&m.ambience, strings.clone(asset_full))
            }
        } else if strings.has_prefix(trimmed, "sfx ") {
            asset := strings.trim_space(trimmed[4:])
            asset = strings.trim(asset, "\"")
            
            ext := ".ogg"
            if strings.contains(asset, ".") do ext = ""
            asset_full := strings.concatenate({asset, ext})
            defer delete(asset_full)
            
            if !contains_string(m.sfx[:], asset_full) {
                append(&m.sfx, strings.clone(asset_full))
            }
        } else if strings.has_prefix(trimmed, "voice ") {
            asset := strings.trim_space(trimmed[6:])
            asset = strings.trim(asset, "\"")
            
            ext := ".ogg"
            if strings.contains(asset, ".") do ext = ""
            asset_full := strings.concatenate({asset, ext})
            defer delete(asset_full)
            
            if !contains_string(m.voice[:], asset_full) {
                append(&m.voice, strings.clone(asset_full))
            }
        } else if strings.has_prefix(trimmed, "movie ") {
            rest := strings.trim_space(trimmed[6:])
            if rest == "stop" || rest == "pause" || rest == "resume" do continue

            path := ""
            tail := ""
            if len(rest) > 0 && rest[0] == '"' {
                q2 := strings.index(rest[1:], "\"")
                if q2 != -1 {
                    path = rest[1 : 1+q2]
                    tail = strings.trim_space(rest[1+q2+1:])
                } else {
                    path = strings.trim(rest, "\"")
                }
            } else {
                parts := strings.split(rest, " ")
                defer delete(parts)
                if len(parts) >= 1 {
                    path = parts[0]
                }
                if len(parts) > 1 {
                    tail = strings.trim_space(rest[len(parts[0]):])
                }
            }

            if path == "" do continue

            base := path
            if idx := strings.last_index(base, "/"); idx != -1 {
                base = base[idx+1:]
            }
            if idx := strings.last_index(base, "\\"); idx != -1 {
                base = base[idx+1:]
            }
            ext := ""
            if dot := strings.last_index(base, "."); dot != -1 {
                ext = strings.to_lower(base[dot:])
            }
            if ext != "" {
                defer delete(ext)
            }

            asset_full := ""
            if ext == "" {
                asset_full = strings.concatenate({path, ".video"})
            } else if ext == ".video" {
                asset_full = strings.clone(path)
            } else {
                fmt.eprintln("[manifest] movie: unsupported extension (use .video):", ext)
                continue
            }
            defer delete(asset_full)

            if !contains_string(m.videos[:], asset_full) {
                append(&m.videos, strings.clone(asset_full))
            }

            // Only prefetch audio if not explicitly disabled
            audio_disabled := false
            if tail != "" {
                parts := strings.split(tail, " ")
                defer delete(parts)
                for p in parts {
                    t := strings.to_lower(strings.trim_space(p))
                    defer delete(t)
                    if t == "audio=off" || t == "audio=0" || t == "audio=false" || t == "mute" {
                        audio_disabled = true
                        break
                    }
                }
            }
            if !audio_disabled {
                base := path
                if idx := strings.last_index(base, "/"); idx != -1 do base = base[idx+1:]
                if idx := strings.last_index(base, "\\"); idx != -1 do base = base[idx+1:]
                if dot := strings.last_index(base, "."); dot != -1 do base = base[:dot]
                audio_file := strings.concatenate({base, ".ogg"})
                defer delete(audio_file)
                if !contains_string(m.video_audio[:], audio_file) {
                    append(&m.video_audio, strings.clone(audio_file))
                }
            }
        }
    }
    
    total := len(m.backgrounds) + len(m.sprites) + len(m.music) + len(m.ambience) + len(m.sfx) + len(m.voice) + len(m.videos) + len(m.video_audio)
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
        } else if strings.has_prefix(trimmed, "ambience ") {
            asset := strings.trim_space(trimmed[9:])
            append(&m.ambience, strings.clone(asset))
        } else if strings.has_prefix(trimmed, "sfx ") {
            asset := strings.trim_space(trimmed[4:])
            append(&m.sfx, strings.clone(asset))
        } else if strings.has_prefix(trimmed, "voice ") {
            asset := strings.trim_space(trimmed[6:])
            append(&m.voice, strings.clone(asset))
        } else if strings.has_prefix(trimmed, "video ") {
            asset := strings.trim_space(trimmed[6:])
            append(&m.videos, strings.clone(asset))
        } else if strings.has_prefix(trimmed, "video_audio ") {
            asset := strings.trim_space(trimmed[12:])
            append(&m.video_audio, strings.clone(asset))
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
    
    for am in m.ambience {
        strings.write_string(&b, "ambience ")
        strings.write_string(&b, am)
        strings.write_string(&b, "\n")
    }
    
    for sfx in m.sfx {
        strings.write_string(&b, "sfx ")
        strings.write_string(&b, sfx)
        strings.write_string(&b, "\n")
    }
    
    for vo in m.voice {
        strings.write_string(&b, "voice ")
        strings.write_string(&b, vo)
        strings.write_string(&b, "\n")
    }

    for v in m.videos {
        strings.write_string(&b, "video ")
        strings.write_string(&b, v)
        strings.write_string(&b, "\n")
    }

    for va in m.video_audio {
        strings.write_string(&b, "video_audio ")
        strings.write_string(&b, va)
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
    for am in m.ambience do delete(am)
    delete(m.ambience)
    for sfx in m.sfx do delete(sfx)
    delete(m.sfx)
    for vo in m.voice do delete(vo)
    delete(m.voice)
    for v in m.videos do delete(v)
    delete(m.videos)
    for va in m.video_audio do delete(va)
    delete(m.video_audio)
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
