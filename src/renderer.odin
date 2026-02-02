package vnefall

import "core:fmt"
import gl "vendor:OpenGL"

// Simple shaders to get pixels on screen
VS_SRC :: `#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;
out vec2 TexCoord;
uniform mat4 uProjection;
void main() {
    gl_Position = uProjection * vec4(aPos, 0.0, 1.0);
    TexCoord = aTexCoord;
}
`

FS_SRC :: `#version 330 core
in vec2 TexCoord;
out vec4 FragColor;
uniform sampler2D uTexture;
uniform vec4 uColor;
uniform int uUseTexture;
uniform int uIsFont;
void main() {
    if (uUseTexture == 1) {
        if (uIsFont == 1) {
            float alpha = texture(uTexture, TexCoord).r;
            FragColor = vec4(uColor.rgb, uColor.a * alpha);
        } else {
            FragColor = texture(uTexture, TexCoord) * uColor;
        }
    } else {
        FragColor = uColor;
    }
}
`

Renderer :: struct {
    shader:      u32,
    vao, vbo:    u32,
    u_proj:      i32,
    u_tex:       i32,
    u_color:     i32,
    u_use_tex:   i32,
    u_is_font:   i32,
    width, height: f32,
}

renderer_init :: proc(r: ^Renderer) -> bool {
    vs := compile_shader(gl.VERTEX_SHADER, VS_SRC)
    fs := compile_shader(gl.FRAGMENT_SHADER, FS_SRC)
    if vs == 0 || fs == 0 do return false
    
    r.shader = gl.CreateProgram()
    gl.AttachShader(r.shader, vs)
    gl.AttachShader(r.shader, fs)
    gl.LinkProgram(r.shader)
    
    success: i32
    gl.GetProgramiv(r.shader, gl.LINK_STATUS, &success)
    if success == 0 {
        fmt.eprintln("Shader link failed.")
        return false
    }
    
    gl.DeleteShader(vs)
    gl.DeleteShader(fs)
    
    r.u_proj     = gl.GetUniformLocation(r.shader, "uProjection")
    r.u_tex      = gl.GetUniformLocation(r.shader, "uTexture")
    r.u_color    = gl.GetUniformLocation(r.shader, "uColor")
    r.u_use_tex  = gl.GetUniformLocation(r.shader, "uUseTexture")
    r.u_is_font  = gl.GetUniformLocation(r.shader, "uIsFont")
    
    gl.GenVertexArrays(1, &r.vao)
    gl.GenBuffers(1, &r.vbo)
    
    gl.BindVertexArray(r.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, r.vbo)
    // Allocate 512KB of headroom for the VBO (Sweet spot for mobile/mid-range)
    gl.BufferData(gl.ARRAY_BUFFER, 512 * 1024, nil, gl.DYNAMIC_DRAW)
    
    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 4 * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 4 * size_of(f32), uintptr(2 * size_of(f32)))
    gl.EnableVertexAttribArray(1)
    
    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    
    return true
}

renderer_cleanup :: proc(r: ^Renderer) {
    gl.DeleteProgram(r.shader)
    gl.DeleteVertexArrays(1, &r.vao)
    gl.DeleteBuffers(1, &r.vbo)
    texture_cleanup()
    font_cleanup()
}

renderer_begin :: proc(r: ^Renderer, w: ^Window) {
    r.width  = cfg.design_width
    r.height = cfg.design_height
    
    gl.Viewport(0, 0, w.width, w.height)
    gl.ClearColor(0.05, 0.05, 0.08, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT)
    
    gl.UseProgram(r.shader)
    proj := ortho_matrix(0, cfg.design_width, cfg.design_height, 0)
    gl.UniformMatrix4fv(r.u_proj, 1, false, &proj[0, 0])
}

renderer_end :: proc(r: ^Renderer, w: ^Window) {
    window_swap(w)
}

renderer_draw_fullscreen :: proc(r: ^Renderer, tex: u32) {
    renderer_draw_texture(r, tex, 0, 0, r.width, r.height)
}

renderer_draw_texture :: proc(r: ^Renderer, tex: u32, x, y, w, h: f32) {
    // 2 triangles per quad
    verts := [6][4]f32{
        {x,     y,     0, 0},
        {x + w, y,     1, 0},
        {x + w, y + h, 1, 1},
        {x,     y,     0, 0},
        {x + w, y + h, 1, 1},
        {x,     y + h, 0, 1},
    }
    
    gl.BindVertexArray(r.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, r.vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(verts), &verts)
    
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, tex)
    gl.Uniform1i(r.u_tex, 0)
    gl.Uniform1i(r.u_use_tex, 1)
    gl.Uniform1i(r.u_is_font, 0)
    gl.Uniform4f(r.u_color, 1, 1, 1, 1)
    
    gl.DrawArrays(gl.TRIANGLES, 0, 6)
}

renderer_draw_rect :: proc(r: ^Renderer, x, y, w, h: f32, color: [4]f32) {
    verts := [6][4]f32{
        {x,     y,     0, 0},
        {x + w, y,     0, 0},
        {x + w, y + h, 0, 0},
        {x,     y,     0, 0},
        {x + w, y + h, 0, 0},
        {x,     y + h, 0, 0},
    }
    
    gl.BindVertexArray(r.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, r.vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(verts), &verts)
    
    gl.Uniform1i(r.u_use_tex, 0)
    gl.Uniform4f(r.u_color, color[0], color[1], color[2], color[3])
    gl.DrawArrays(gl.TRIANGLES, 0, 6)
}

renderer_draw_textbox :: proc(r: ^Renderer, speaker, text: string) {
    h  := cfg.textbox_height
    m  := cfg.textbox_margin
    p  := cfg.textbox_padding
    bx := m
    by := r.height - h - m
    bw := r.width - (m * 2)
    
    // The main box
    renderer_draw_rect(r, bx, by, bw, h, {0.02, 0.02, 0.05, 0.85})
    
    tx := bx + p
    ty := by + p + FONT_SIZE
    
    if len(speaker) > 0 {
        renderer_draw_text(r, speaker, tx, ty, cfg.color_speaker)
        ty += FONT_SIZE + 8
    }
    
    lines := font_wrap_text(text, bw - (p * 2))
    for line in lines {
        renderer_draw_text(r, line, tx, ty, cfg.color_text)
        ty += FONT_SIZE + 4
        delete(line)
    }
    delete(lines)
}

renderer_draw_choice_menu :: proc(r: ^Renderer, options: [dynamic]Choice_Option, selected: int) {
    count := len(options)
    if count == 0 do return
    
    button_w := cfg.choice_w
    button_h := cfg.choice_h
    spacing  := cfg.choice_spacing
    
    total_h := f32(count) * button_h + f32(count - 1) * spacing
    start_y := (r.height - total_h) / 2
    x       := (r.width - button_w) / 2
    
    for opt, i in options {
        y := start_y + f32(i) * (button_h + spacing)
        
        bg_color   := cfg.choice_color_idle
        text_color := cfg.choice_text_idle
        
        if i == selected {
            bg_color   = cfg.choice_color_hov
            text_color = cfg.choice_text_hov
        }
        
        renderer_draw_rect(r, x, y, button_w, button_h, bg_color)
        
        // Center text in button
        text_w := font_text_width(opt.text)
        tx := x + (button_w - text_w) / 2
        ty := y + (button_h + FONT_SIZE) / 2 - 4
        
        renderer_draw_text(r, opt.text, tx, ty, text_color)
    }
}

renderer_draw_text :: proc(r: ^Renderer, text: string, x, y: f32, color: [4]f32) {
    if !g_font.loaded do return
    
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, g_font.texture)
    gl.Uniform1i(r.u_tex, 0)
    gl.Uniform1i(r.u_use_tex, 1)
    gl.Uniform1i(r.u_is_font, 1)
    gl.Uniform4f(r.u_color, color[0], color[1], color[2], color[3])
    
    cx, cy := x, y
    for char in text {
        if char < FONT_FIRST_CHAR || char >= FONT_FIRST_CHAR + FONT_NUM_CHARS do continue
        
        q := font_get_glyph(u8(char), &cx, &cy)
        verts := [6][4]f32{
            {q.x0, q.y0, q.s0, q.t0},
            {q.x1, q.y0, q.s1, q.t0},
            {q.x1, q.y1, q.s1, q.t1},
            {q.x0, q.y0, q.s0, q.t0},
            {q.x1, q.y1, q.s1, q.t1},
            {q.x0, q.y1, q.s0, q.t1},
        }
        
        gl.BindBuffer(gl.ARRAY_BUFFER, r.vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(verts), &verts)
        gl.DrawArrays(gl.TRIANGLES, 0, 6)
    }
}

compile_shader :: proc(kind: u32, src: cstring) -> u32 {
    s := gl.CreateShader(kind)
    p := src
    gl.ShaderSource(s, 1, &p, nil)
    gl.CompileShader(s)
    
    ok: i32
    gl.GetShaderiv(s, gl.COMPILE_STATUS, &ok)
    if ok == 0 {
        log: [512]u8
        gl.GetShaderInfoLog(s, 512, nil, &log[0])
        fmt.eprintln("Shader error:", string(log[:]))
        return 0
    }
    return s
}

// Last row/col logic matches the fix that worked
ortho_matrix :: proc(l, r, b, t: f32) -> matrix[4, 4]f32 {
    m: matrix[4, 4]f32
    m[0, 0] = 2 / (r - l)
    m[1, 1] = 2 / (t - b)
    m[2, 2] = -1
    m[0, 3] = -(r + l) / (r - l)
    m[1, 3] = -(t + b) / (t - b)
    m[3, 3] = 1
    return m
}
