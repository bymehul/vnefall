package vnefall

import "core:fmt"
import "core:strings"
import "core:c"
import gl "vendor:OpenGL"
import stbi "vendor:stb/image"

// Texture info with dimensions
Texture_Info :: struct {
    id:     u32,
    width:  i32,
    height: i32,
}

// cache to avoid reloading same image twice
@(private)
cache: map[string]Texture_Info

texture_load :: proc(path: string) -> Texture_Info {
    if info, ok := cache[path]; ok do return info
    
    w, h, chans: c.int
    cp := strings.clone_to_cstring(path)
    defer delete(cp)
    
    // Force 4 channels (RGBA)
    data := stbi.load(cp, &w, &h, &chans, 4)
    if data == nil {
        fmt.eprintln("Image failed to load:", path)
        return {}
    }
    defer stbi.image_free(data)
    
    tex: u32
    gl.GenTextures(1, &tex)
    gl.BindTexture(gl.TEXTURE_2D, tex)
    
    // PixelStorei is important for non-power-of-two widths
    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
    
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
    
    info := Texture_Info{id = tex, width = i32(w), height = i32(h)}
    cache[path] = info
    return info
}

// Legacy function for backwards compatibility (returns just the ID)
texture_load_id :: proc(path: string) -> u32 {
    return texture_load(path).id
}

texture_cleanup :: proc() {
    for _, &info in cache {
        gl.DeleteTextures(1, &info.id)
    }
    delete(cache)
}
