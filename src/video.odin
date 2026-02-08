package vnefall

import "core:fmt"
import "core:strings"
import "core:c"
import gl "vendor:OpenGL"
import vnef_video "vnefvideo:odin"

Video_Layer :: enum {
    Background,
    Foreground,
}

Video_Play_Options :: struct {
    loop: bool,
    hold_last: bool,
    wait_for_click: bool,
    blur_alpha: f32,
    layer: Video_Layer,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    use_rect: bool,
    fit: string,    // "stretch" | "contain" | "cover"
    align: string,  // "center" | "top" | "bottom" | "left" | "right" | "topleft" | "topright" | "bottomleft" | "bottomright"
    audio_enabled: bool,
}

Video_State :: struct {
    active: bool,
    playing: bool,
    loop: bool,
    hold_last: bool,
    wait_for_click: bool,
    layer: Video_Layer,
    blur_alpha: f32,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    use_rect: bool,
    fit: string,
    align: string,
    audio_enabled: bool,
    audio_warned: bool,

    handle: ^vnef_video.VNEVideo,
    info: vnef_video.VNEVideoInfo,
    tex: u32,
    frame_ms: f32,
    frame_accum: f32,
    path: string,
}

@(private)
video_prefetch_cache: map[string]u32

@(private)
video_full_path :: proc(asset: string) -> string {
    if strings.has_prefix(asset, "/") || strings.has_prefix(asset, "./") || strings.has_prefix(asset, "../") || strings.contains(asset, ":\\") {
        return strings.clone(asset)
    }
    return strings.concatenate({cfg.path_videos, asset})
}

@(private)
video_prefetch_path :: proc(asset: string) {
    if asset == "" do return
    if video_prefetch_cache == nil {
        video_prefetch_cache = make(map[string]u32)
    }
    if _, ok := video_prefetch_cache[asset]; ok do return

    info: vnef_video.VNEVideoInfo
    cpath := strings.clone_to_cstring(asset)
    defer delete(cpath)
    v := vnef_video.vne_video_open(cpath, &info)
    if v == nil do return
    defer vnef_video.vne_video_close(v)

    vf := vnef_video.VNEVideoFrame{}
    af := vnef_video.VNEAudioFrame{}
    for {
        t := vnef_video.vne_video_next(v, &vf, &af)
        switch t {
        case .VNE_FRAME_VIDEO:
            // Create a texture from the first frame
            tex: u32
            gl.GenTextures(1, &tex)
            gl.BindTexture(gl.TEXTURE_2D, tex)
            gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
            gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
            gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
            gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
            gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
            if vf.stride != vf.width * 4 {
                row_len := vf.stride / 4
                gl.PixelStorei(gl.UNPACK_ROW_LENGTH, row_len)
            } else {
                gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)
            }
            gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, vf.width, vf.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, vf.data)
            gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)
            vnef_video.vne_video_free_video_frame(&vf)
            video_prefetch_cache[strings.clone(asset)] = tex
            return
        case .VNE_FRAME_AUDIO:
            vnef_video.vne_video_free_audio_frame(&af)
        case .VNE_FRAME_EOF, .VNE_FRAME_ERROR, .VNE_FRAME_NONE:
            return
        }
    }
}

video_prefetch_scene :: proc(m: ^Manifest) {
    if m == nil do return
    for v in m.videos {
        full := video_full_path(v)
        video_prefetch_path(full)
        delete(full)
    }
}

video_prefetch_take :: proc(path: string) -> (u32, bool) {
    if video_prefetch_cache == nil do return 0, false
    if tex, ok := video_prefetch_cache[path]; ok {
        delete_key(&video_prefetch_cache, path)
        return tex, true
    }
    return 0, false
}

video_prefetch_release_for_manifest :: proc(m: ^Manifest, keep: ^Manifest = nil) {
    if m == nil || video_prefetch_cache == nil do return
    for v in m.videos {
        if keep != nil && contains_string_video(keep.videos[:], v) do continue
        full := video_full_path(v)
        if tex, ok := video_prefetch_cache[full]; ok {
            gl.DeleteTextures(1, &tex)
            delete_key(&video_prefetch_cache, full)
        }
        delete(full)
    }
    if len(video_prefetch_cache) == 0 {
        delete(video_prefetch_cache)
        video_prefetch_cache = nil
    }
}

@(private)
contains_string_video :: proc(slice: []string, s: string) -> bool {
    for item in slice {
        if item == s do return true
    }
    return false
}

video_stop :: proc(v: ^Video_State) {
    if v.handle != nil {
        vnef_video.vne_video_close(v.handle)
        v.handle = nil
    }
    if v.tex != 0 {
        gl.DeleteTextures(1, &v.tex)
        v.tex = 0
    }
    if v.path != "" {
        delete(v.path)
        v.path = ""
    }
    v.active = false
    v.playing = false
    v.wait_for_click = false
    v.use_rect = false
    v.audio_enabled = false
    v.audio_warned = false
    if v.fit != "" {
        delete(v.fit)
        v.fit = ""
    }
    if v.align != "" {
        delete(v.align)
        v.align = ""
    }
    v.frame_accum = 0
    v.frame_ms = 0
}

video_pause :: proc(v: ^Video_State) {
    v.playing = false
}

video_resume :: proc(v: ^Video_State) {
    if v.active {
        v.playing = true
    }
}

@(private)
video_upload_frame :: proc(v: ^Video_State, frame: ^vnef_video.VNEVideoFrame) {
    if v.tex == 0 {
        gl.GenTextures(1, &v.tex)
        gl.BindTexture(gl.TEXTURE_2D, v.tex)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, frame.width, frame.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
    } else {
        gl.BindTexture(gl.TEXTURE_2D, v.tex)
    }
    
    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
    // Handle stride when it doesn't match width*4
    if frame.stride != frame.width * 4 {
        row_len := frame.stride / 4
        gl.PixelStorei(gl.UNPACK_ROW_LENGTH, row_len)
    } else {
        gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)
    }
    gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, frame.width, frame.height, gl.RGBA, gl.UNSIGNED_BYTE, frame.data)
    gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)
}

@(private)
video_decode_next_frame :: proc(v: ^Video_State) -> bool {
    if v.handle == nil do return false
    
    vf := vnef_video.VNEVideoFrame{}
    af := vnef_video.VNEAudioFrame{}
    
    for {
        t := vnef_video.vne_video_next(v.handle, &vf, &af)
        switch t {
        case .VNE_FRAME_VIDEO:
            video_upload_frame(v, &vf)
            vnef_video.vne_video_free_video_frame(&vf)
            return true
        case .VNE_FRAME_AUDIO:
            vnef_video.vne_video_free_audio_frame(&af)
        case .VNE_FRAME_EOF:
            return false
        case .VNE_FRAME_ERROR:
            err := vnef_video.vne_video_last_error(v.handle)
            if err != nil {
                fmt.eprintln("[video] decode error:", string(err))
            } else {
                fmt.eprintln("[video] decode error")
            }
            return false
        case .VNE_FRAME_NONE:
            return false
        }
    }
    return false
}

video_play :: proc(v: ^Video_State, path: string, opts: Video_Play_Options) -> bool {
    video_stop(v)
    
    info: vnef_video.VNEVideoInfo
    cpath := strings.clone_to_cstring(path)
    defer delete(cpath)
    handle := vnef_video.vne_video_open(cpath, &info)
    if handle == nil {
        fmt.eprintln("[video] Failed to open:", path)
        return false
    }
    
    v.handle = handle
    v.info = info
    v.path = strings.clone(path)
    v.active = true
    v.playing = true
    v.loop = opts.loop
    v.hold_last = opts.hold_last
    v.wait_for_click = opts.wait_for_click
    v.layer = opts.layer
    v.blur_alpha = opts.blur_alpha
    v.x = opts.x
    v.y = opts.y
    v.w = opts.w
    v.h = opts.h
    v.use_rect = opts.use_rect
    if opts.fit != "" {
        v.fit = strings.clone(opts.fit)
    } else {
        v.fit = strings.clone("stretch")
    }
    if opts.align != "" {
        v.align = strings.clone(opts.align)
    } else {
        v.align = strings.clone("center")
    }
    v.audio_enabled = opts.audio_enabled
    v.audio_warned = false
    
    // fps fallback
    if info.fps_num > 0 && info.fps_den > 0 {
        v.frame_ms = 1000.0 * f32(info.fps_den) / f32(info.fps_num)
    } else {
        v.frame_ms = 33.33
    }
    v.frame_accum = v.frame_ms // Decode a frame immediately
    
    // If a prefetched texture exists, use it as the initial frame.
    if tex, ok := video_prefetch_take(path); ok {
        v.tex = tex
    }

    // Prime first frame
    if !video_decode_next_frame(v) {
        if !v.loop {
            if v.hold_last {
                v.playing = false
            } else {
                video_stop(v)
            }
        }
    }
    
    return v.active
}

video_update :: proc(v: ^Video_State, dt: f32) -> bool {
    if !v.active || !v.playing do return false
    
    v.frame_accum += dt * 1000.0
    if v.frame_ms <= 0 do v.frame_ms = 33.33
    
    for v.frame_accum >= v.frame_ms {
        v.frame_accum -= v.frame_ms
        if !video_decode_next_frame(v) {
            if v.loop {
                _ = vnef_video.vne_video_seek_ms(v.handle, 0)
                // Try again on next tick
            } else if v.hold_last {
                v.playing = false
                return true
            } else {
                video_stop(v)
                return true
            }
        }
    }
    return false
}

@(private)
video_apply_fit_align :: proc(v: ^Video_State) -> (f32, f32, f32, f32) {
    x := v.x
    y := v.y
    w := v.w
    h := v.h
    if !v.use_rect || w <= 0 || h <= 0 {
        return 0, 0, cfg.design_width, cfg.design_height
    }

    // Default to rect region. If stretch, keep as-is.
    if v.fit == "" || v.fit == "stretch" {
        return x, y, w, h
    }

    vw := f32(v.info.width)
    vh := f32(v.info.height)
    if vw <= 0 || vh <= 0 {
        return x, y, w, h
    }

    scale := f32(1.0)
    if v.fit == "contain" {
        scale = min(w / vw, h / vh)
    } else if v.fit == "cover" {
        scale = max(w / vw, h / vh)
    }

    dw := vw * scale
    dh := vh * scale

    ax := v.align
    if ax == "" do ax = "center"

    px := x
    py := y

    switch ax {
    case "center":
        px = x + (w - dw) * 0.5
        py = y + (h - dh) * 0.5
    case "top":
        px = x + (w - dw) * 0.5
        py = y
    case "bottom":
        px = x + (w - dw) * 0.5
        py = y + (h - dh)
    case "left":
        px = x
        py = y + (h - dh) * 0.5
    case "right":
        px = x + (w - dw)
        py = y + (h - dh) * 0.5
    case "topleft":
        px = x
        py = y
    case "topright":
        px = x + (w - dw)
        py = y
    case "bottomleft":
        px = x
        py = y + (h - dh)
    case "bottomright":
        px = x + (w - dw)
        py = y + (h - dh)
    }

    return px, py, dw, dh
}

video_draw_layer :: proc(v: ^Video_State, r: ^Renderer) {
    if !v.active do return
    if v.blur_alpha > 0 {
        a := v.blur_alpha
        if a < 0 do a = 0
        if a > 1 do a = 1
        // Placeholder blur: dim overlay until a real blur shader exists.
        renderer_draw_rect(r, 0, 0, r.width, r.height, {0, 0, 0, a})
    }
    if v.tex != 0 {
        if v.use_rect && v.w > 0 && v.h > 0 {
            px, py, pw, ph := video_apply_fit_align(v)
            renderer_draw_texture(r, v.tex, px, py, pw, ph)
        } else {
            renderer_draw_fullscreen(r, v.tex)
        }
    }
}

video_cleanup :: proc(v: ^Video_State) {
    video_stop(v)
}
