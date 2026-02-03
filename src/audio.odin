package vnefall

import "core:fmt"
import "core:strings"
import "vendor:sdl2"
import mix "vendor:sdl2/mixer"

// Flip to false to silence audio debug logs
AUDIO_DEBUG :: true

Audio_State :: struct {
    inited: bool,
    music:  ^mix.Music,
    chunks: map[string]^mix.Chunk,
    music_cache: map[string]^mix.Music,
    music_path: string,
    music_cached: bool,
    ambience_path: string,
    voice_path: string,
    sfx_paths: [SFX_CHANNEL_COUNT]string,
    volume_master: f32,
    volume_music:  f32,
    volume_ambience: f32,
    volume_sfx:    f32,
    volume_voice:  f32,
}

@(private)
audio_log :: proc(fmt_str: string, args: ..any) {
    if !AUDIO_DEBUG do return
    fmt.printf(fmt_str, ..args)
}

// Channel allocation
SFX_CHANNEL_START :: 0
SFX_CHANNEL_END   :: 7
SFX_CHANNEL_COUNT :: SFX_CHANNEL_END - SFX_CHANNEL_START + 1
VOICE_CHANNEL     :: 8
AMBIENCE_CHANNEL  :: 9

audio_init :: proc(a: ^Audio_State) -> bool {
    // We want MP3 and OGG support for v1
    if i32(mix.Init({.MP3, .OGG})) == 0 {
        fmt.eprintln("mixer flags failed to init, but we'll try to continue.")
    }

    if mix.OpenAudio(44100, mix.DEFAULT_FORMAT, 2, 2048) < 0 {
        fmt.eprintln("Audio device failed:", sdl2.GetError())
        return false
    }
    
    a.inited = true
    a.chunks = make(map[string]^mix.Chunk)
    a.music_cache = make(map[string]^mix.Music)
    mix.AllocateChannels(16)
    return true
}

audio_cleanup :: proc(a: ^Audio_State) {
    if a.music != nil && !a.music_cached {
        mix.FreeMusic(a.music)
        a.music = nil
    }
    if a.music_cache != nil {
        keys := make([dynamic]string, context.temp_allocator)
        for k in a.music_cache {
            append(&keys, k)
        }
        for k in keys {
            if mu, ok := a.music_cache[k]; ok {
                if mu != nil do mix.FreeMusic(mu)
                delete_key(&a.music_cache, k)
                delete(k)
            }
        }
        delete(a.music_cache)
    }
    if a.music_path != "" do delete(a.music_path)
    
    if a.chunks != nil {
        keys := make([dynamic]string, context.temp_allocator)
        for k in a.chunks {
            append(&keys, k)
        }
        for k in keys {
            if chunk, ok := a.chunks[k]; ok {
                if chunk != nil do mix.FreeChunk(chunk)
                delete_key(&a.chunks, k)
                delete(k)
            }
        }
        delete(a.chunks)
    }
    if a.ambience_path != "" do delete(a.ambience_path)
    if a.voice_path != "" do delete(a.voice_path)
    for i := 0; i < len(a.sfx_paths); i += 1 {
        if a.sfx_paths[i] != "" {
            delete(a.sfx_paths[i])
            a.sfx_paths[i] = ""
        }
    }
    
    if a.inited {
        mix.CloseAudio()
        mix.Quit()
        a.inited = false
    }
}

audio_play_music :: proc(a: ^Audio_State, path: string) {
    if !a.inited do return
    
    audio_log("[audio] music -> %s\n", path)
    if a.music != nil && !a.music_cached {
        mix.FreeMusic(a.music)
        a.music = nil
    }
    
    mu, cached := audio_get_music(a, path)
    if mu == nil do return
    
    if a.music_path != "" do delete(a.music_path)
    a.music_path = strings.clone(path)
    a.music = mu
    a.music_cached = cached
    
    mix.PlayMusic(a.music, -1) // -1 for infinite loop
}

audio_play_ambience :: proc(a: ^Audio_State, path: string) {
    if !a.inited do return
    
    audio_log("[audio] ambience -> %s\n", path)
    chunk := audio_load_chunk(a, path)
    if chunk == nil do return
    
    if a.ambience_path != "" do delete(a.ambience_path)
    a.ambience_path = strings.clone(path)
    
    mix.HaltChannel(i32(AMBIENCE_CHANNEL))
    mix.PlayChannel(i32(AMBIENCE_CHANNEL), chunk, -1)
}

audio_stop_music :: proc(a: ^Audio_State) {
    audio_log("[audio] music stop\n")
    mix.HaltMusic()
    if a.music != nil && !a.music_cached {
        mix.FreeMusic(a.music)
    }
    a.music = nil
    a.music_cached = false
    if a.music_path != "" {
        delete(a.music_path)
        a.music_path = ""
    }
}

audio_stop_music_fade :: proc(a: ^Audio_State, ms: int) {
    audio_log("[audio] music stop fade %dms\n", ms)
    if mix.PlayingMusic() == 1 {
        mix.FadeOutMusic(i32(ms))
    }
    // Keep pointers/path until the next play or scene cleanup to avoid
    // freeing while a fade-out is still in progress.
}

audio_stop_ambience :: proc(a: ^Audio_State) {
    audio_log("[audio] ambience stop\n")
    mix.HaltChannel(i32(AMBIENCE_CHANNEL))
    if a.ambience_path != "" {
        delete(a.ambience_path)
        a.ambience_path = ""
    }
}

audio_stop_voice :: proc(a: ^Audio_State) {
    audio_log("[audio] voice stop\n")
    mix.HaltChannel(i32(VOICE_CHANNEL))
    if a.voice_path != "" {
        delete(a.voice_path)
        a.voice_path = ""
    }
}

audio_stop_sfx_all :: proc(a: ^Audio_State) {
    audio_log("[audio] sfx stop all\n")
    for ch := SFX_CHANNEL_START; ch <= SFX_CHANNEL_END; ch += 1 {
        mix.HaltChannel(i32(ch))
    }
    for i := 0; i < len(a.sfx_paths); i += 1 {
        if a.sfx_paths[i] != "" {
            delete(a.sfx_paths[i])
            a.sfx_paths[i] = ""
        }
    }
}

// --- Save/Load Helpers ---

audio_get_music_asset_if_playing :: proc(a: ^Audio_State) -> string {
    if a.music_path == "" do return ""
    if mix.PlayingMusic() == 0 do return ""
    asset := asset_from_path(a.music_path, cfg.path_music)
    if asset == "" do return ""
    return strings.clone(asset)
}

audio_get_ambience_asset_if_playing :: proc(a: ^Audio_State) -> string {
    if a.ambience_path == "" do return ""
    if mix.Playing(i32(AMBIENCE_CHANNEL)) == 0 do return ""
    asset := asset_from_path(a.ambience_path, cfg.path_ambience)
    if asset == "" do return ""
    return strings.clone(asset)
}

audio_get_voice_asset_if_playing :: proc(a: ^Audio_State) -> string {
    if a.voice_path == "" do return ""
    if mix.Playing(i32(VOICE_CHANNEL)) == 0 do return ""
    asset := asset_from_path(a.voice_path, cfg.path_voice)
    if asset == "" do return ""
    return strings.clone(asset)
}

audio_get_sfx_assets_if_playing :: proc(a: ^Audio_State) -> [dynamic]string {
    paths: [dynamic]string
    for ch := SFX_CHANNEL_START; ch <= SFX_CHANNEL_END; ch += 1 {
        idx := ch - SFX_CHANNEL_START
        if idx < 0 || idx >= len(a.sfx_paths) do continue
        if a.sfx_paths[idx] == "" do continue
        if mix.Playing(i32(ch)) == 0 do continue
        asset := asset_from_path(a.sfx_paths[idx], cfg.path_sfx)
        if asset == "" do continue
        append(&paths, strings.clone(asset))
    }
    return paths
}

@(private)
audio_remove_music_cache_entry :: proc(a: ^Audio_State, path: string) {
    if cached, ok := a.music_cache[path]; ok {
        if a.music_path == path {
            mix.HaltMusic()
            a.music = nil
            a.music_cached = false
            if a.music_path != "" {
                delete(a.music_path)
                a.music_path = ""
            }
        }
        mix.FreeMusic(cached)
        key_to_delete := ""
        for k in a.music_cache {
            if k == path {
                key_to_delete = k
                break
            }
        }
        if key_to_delete != "" {
            delete_key(&a.music_cache, key_to_delete)
            delete(key_to_delete)
        } else {
            delete_key(&a.music_cache, path)
        }
    }
}

@(private)
audio_remove_chunk_entry :: proc(a: ^Audio_State, path: string) {
    if chunk, ok := a.chunks[path]; ok {
        mix.FreeChunk(chunk)
        key_to_delete := ""
        for k in a.chunks {
            if k == path {
                key_to_delete = k
                break
            }
        }
        if key_to_delete != "" {
            delete_key(&a.chunks, key_to_delete)
            delete(key_to_delete)
        } else {
            delete_key(&a.chunks, path)
        }
    }
}

audio_fade_music :: proc(a: ^Audio_State, path: string, ms: int) {
    if !a.inited do return
    
    audio_log("[audio] music fade -> %s (%dms)\n", path, ms)
    // Fade out existing music, then fade in the new track
    if mix.PlayingMusic() == 1 {
        mix.FadeOutMusic(i32(ms))
    }
    
    if a.music != nil && !a.music_cached {
        mix.FreeMusic(a.music)
        a.music = nil
    }
    
    mu, cached := audio_get_music(a, path)
    if mu == nil do return
    
    if a.music_path != "" do delete(a.music_path)
    a.music_path = strings.clone(path)
    a.music = mu
    a.music_cached = cached
    
    mix.FadeInMusic(a.music, -1, i32(ms))
}

audio_fade_ambience :: proc(a: ^Audio_State, path: string, ms: int) {
    if !a.inited do return
    
    audio_log("[audio] ambience fade -> %s (%dms)\n", path, ms)
    if mix.Playing(i32(AMBIENCE_CHANNEL)) == 1 {
        mix.FadeOutChannel(i32(AMBIENCE_CHANNEL), i32(ms))
    }
    
    chunk := audio_load_chunk(a, path)
    if chunk == nil do return
    
    if a.ambience_path != "" do delete(a.ambience_path)
    a.ambience_path = strings.clone(path)
    
    mix.FadeInChannel(i32(AMBIENCE_CHANNEL), chunk, -1, i32(ms))
}

audio_apply_settings :: proc(a: ^Audio_State) {
    a.volume_master = clamp_f32(g_settings.volume_master, 0.0, 1.0)
    a.volume_music  = clamp_f32(g_settings.volume_music, 0.0, 1.0)
    a.volume_ambience = clamp_f32(g_settings.volume_ambience, 0.0, 1.0)
    a.volume_sfx    = clamp_f32(g_settings.volume_sfx, 0.0, 1.0)
    a.volume_voice  = clamp_f32(g_settings.volume_voice, 0.0, 1.0)
    
    audio_apply_volumes(a)
}

audio_apply_volumes :: proc(a: ^Audio_State) {
    // SDL_mixer volume is 0..128
    master := a.volume_master
    music_vol := to_mixer_volume(master * a.volume_music)
    ambience_vol := to_mixer_volume(master * a.volume_ambience)
    sfx_vol   := to_mixer_volume(master * a.volume_sfx)
    voice_vol := to_mixer_volume(master * a.volume_voice)
    
    mix.VolumeMusic(music_vol)
    mix.Volume(i32(AMBIENCE_CHANNEL), ambience_vol)
    for ch := SFX_CHANNEL_START; ch <= SFX_CHANNEL_END; ch += 1 {
        mix.Volume(i32(ch), sfx_vol)
    }
    mix.Volume(i32(VOICE_CHANNEL), voice_vol)
}

audio_set_volume :: proc(a: ^Audio_State, channel: string, value: f32) {
    v := clamp_f32(value, 0.0, 1.0)
    
    audio_log("[audio] volume %s = %.2f\n", channel, v)
    switch channel {
    case "master": a.volume_master = v
    case "music":  a.volume_music  = v
    case "ambience": a.volume_ambience = v
    case "sfx":    a.volume_sfx    = v
    case "voice":  a.volume_voice  = v
    }
    
    audio_apply_volumes(a)
}

audio_play_sfx :: proc(a: ^Audio_State, path: string) {
    if !a.inited do return
    
    audio_log("[audio] sfx -> %s\n", path)
    chunk := audio_load_chunk(a, path)
    if chunk == nil do return
    
    ch := find_free_sfx_channel()
    if ch == -1 {
        fmt.eprintln("No available SFX channel.")
        return
    }
    
    idx := ch - SFX_CHANNEL_START
    if idx >= 0 && idx < len(a.sfx_paths) {
        if a.sfx_paths[idx] != "" do delete(a.sfx_paths[idx])
        a.sfx_paths[idx] = strings.clone(path)
    }
    mix.PlayChannel(i32(ch), chunk, 0)
}

audio_play_voice :: proc(a: ^Audio_State, path: string) {
    if !a.inited do return
    
    audio_log("[audio] voice -> %s\n", path)
    chunk := audio_load_chunk(a, path)
    if chunk == nil do return
    
    mix.HaltChannel(i32(VOICE_CHANNEL))
    if a.voice_path != "" do delete(a.voice_path)
    a.voice_path = strings.clone(path)
    mix.PlayChannel(i32(VOICE_CHANNEL), chunk, 0)
}

@(private)
audio_load_chunk :: proc(a: ^Audio_State, path: string) -> ^mix.Chunk {
    if chunk, ok := a.chunks[path]; ok do return chunk
    
    cpath := strings.clone_to_cstring(path)
    defer delete(cpath)
    
    chunk := mix.LoadWAV(cpath)
    if chunk == nil {
        fmt.eprintln("Couldn't load sfx/voice:", path, sdl2.GetError())
        return nil
    }
    
    a.chunks[strings.clone(path)] = chunk
    return chunk
}

@(private)
audio_get_music :: proc(a: ^Audio_State, path: string) -> (mu: ^mix.Music, cached: bool) {
    if m, ok := a.music_cache[path]; ok {
        return m, true
    }
    
    cpath := strings.clone_to_cstring(path)
    defer delete(cpath)
    
    m := mix.LoadMUS(cpath)
    if m == nil {
        fmt.eprintln("Couldn't load music:", path, sdl2.GetError())
        return nil, false
    }
    
    return m, false
}


@(private)
find_free_sfx_channel :: proc() -> int {
    for ch := SFX_CHANNEL_START; ch <= SFX_CHANNEL_END; ch += 1 {
        if mix.Playing(i32(ch)) == 0 do return ch
    }
    return -1
}

@(private)
to_mixer_volume :: proc(v: f32) -> i32 {
    clamped := clamp_f32(v, 0.0, 1.0)
    return i32(clamped * 128.0)
}

// --- Scene Prefetch / Flush ---

audio_prefetch_scene :: proc(a: ^Audio_State, m: ^Manifest) {
    if !a.inited do return
    
    audio_log("[audio] prefetch: %d music, %d ambience, %d sfx, %d voice\n", len(m.music), len(m.ambience), len(m.sfx), len(m.voice))
    // Prefetch music into cache
    for mu in m.music {
        cpath := strings.concatenate({cfg.path_music, mu})
        defer delete(cpath)
        
        if _, ok := a.music_cache[cpath]; ok do continue
        
        cstr := strings.clone_to_cstring(cpath)
        defer delete(cstr)
        
        mptr := mix.LoadMUS(cstr)
        if mptr == nil {
            fmt.eprintln("Couldn't prefetch music:", cpath, sdl2.GetError())
            continue
        }
        a.music_cache[strings.clone(cpath)] = mptr
    }
    
    // Prefetch ambience into cache
    for am in m.ambience {
        path := strings.concatenate({cfg.path_ambience, am})
        defer delete(path)
        audio_load_chunk(a, path)
    }
    
    // Prefetch sfx/voice chunks
    for sfx in m.sfx {
        path := strings.concatenate({cfg.path_sfx, sfx})
        defer delete(path)
        audio_load_chunk(a, path)
    }
    for vo in m.voice {
        path := strings.concatenate({cfg.path_voice, vo})
        defer delete(path)
        audio_load_chunk(a, path)
    }
}

audio_flush_scene :: proc(a: ^Audio_State, m: ^Manifest) {
    if !a.inited do return
    
    audio_log("[audio] flush scene\n")
    // Stop ambience, voice, and SFX channels before freeing chunks
    mix.HaltChannel(i32(AMBIENCE_CHANNEL))
    mix.HaltChannel(i32(VOICE_CHANNEL))
    for ch := SFX_CHANNEL_START; ch <= SFX_CHANNEL_END; ch += 1 {
        mix.HaltChannel(i32(ch))
    }
    if a.voice_path != "" {
        delete(a.voice_path)
        a.voice_path = ""
    }
    for i := 0; i < len(a.sfx_paths); i += 1 {
        if a.sfx_paths[i] != "" {
            delete(a.sfx_paths[i])
            a.sfx_paths[i] = ""
        }
    }
    
    // Free scene music cache entries
    for mu in m.music {
        path := strings.concatenate({cfg.path_music, mu})
        defer delete(path)
        
        audio_remove_music_cache_entry(a, path)
    }
    
    // Free ambience chunks
    for am in m.ambience {
        path := strings.concatenate({cfg.path_ambience, am})
        defer delete(path)
        
        if a.ambience_path == path {
            delete(a.ambience_path)
            a.ambience_path = ""
        }
        audio_remove_chunk_entry(a, path)
    }
    
    // Free scene chunks (sfx/voice)
    for sfx in m.sfx {
        path := strings.concatenate({cfg.path_sfx, sfx})
        defer delete(path)
        audio_remove_chunk_entry(a, path)
    }
    for vo in m.voice {
        path := strings.concatenate({cfg.path_voice, vo})
        defer delete(path)
        audio_remove_chunk_entry(a, path)
    }
}

audio_flush_scene_keep :: proc(a: ^Audio_State, m: ^Manifest, keep: ^Manifest) {
    if !a.inited do return
    
    audio_log("[audio] flush scene (keep shared)\n")
    // Stop voice and SFX channels before freeing chunks
    if a.ambience_path == "" {
        mix.HaltChannel(i32(AMBIENCE_CHANNEL))
    } else {
        asset := asset_from_path(a.ambience_path, cfg.path_ambience)
        if asset == "" || !contains_string_audio(keep.ambience[:], asset) {
            mix.HaltChannel(i32(AMBIENCE_CHANNEL))
        }
    }
    mix.HaltChannel(i32(VOICE_CHANNEL))
    for ch := SFX_CHANNEL_START; ch <= SFX_CHANNEL_END; ch += 1 {
        mix.HaltChannel(i32(ch))
    }
    if a.voice_path != "" {
        delete(a.voice_path)
        a.voice_path = ""
    }
    for i := 0; i < len(a.sfx_paths); i += 1 {
        if a.sfx_paths[i] != "" {
            delete(a.sfx_paths[i])
            a.sfx_paths[i] = ""
        }
    }
    
    // Free scene music cache entries (skip shared)
    for mu in m.music {
        if contains_string_audio(keep.music[:], mu) do continue
        
        path := strings.concatenate({cfg.path_music, mu})
        defer delete(path)
        
        audio_remove_music_cache_entry(a, path)
    }
    
    // Free ambience chunks (skip shared)
    for am in m.ambience {
        if contains_string_audio(keep.ambience[:], am) do continue
        
        path := strings.concatenate({cfg.path_ambience, am})
        defer delete(path)
        
        if a.ambience_path == path {
            delete(a.ambience_path)
            a.ambience_path = ""
        }
        audio_remove_chunk_entry(a, path)
    }
    
    // Free scene chunks (sfx/voice) that are not shared
    for sfx in m.sfx {
        if contains_string_audio(keep.sfx[:], sfx) do continue
        
        path := strings.concatenate({cfg.path_sfx, sfx})
        defer delete(path)
        audio_remove_chunk_entry(a, path)
    }
    for vo in m.voice {
        if contains_string_audio(keep.voice[:], vo) do continue
        
        path := strings.concatenate({cfg.path_voice, vo})
        defer delete(path)
        audio_remove_chunk_entry(a, path)
    }
}

@(private)
contains_string_audio :: proc(slice: []string, s: string) -> bool {
    for item in slice {
        if item == s do return true
    }
    return false
}

@(private)
asset_from_path :: proc(path, prefix: string) -> string {
    if strings.has_prefix(path, prefix) {
        return path[len(prefix):]
    }
    return ""
}
