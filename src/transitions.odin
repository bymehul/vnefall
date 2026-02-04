package vnefall

import "core:math"

Transition_Kind :: enum {
    None,
    Fade,
    Wipe,
    Slide,
    Dissolve,
    Zoom,
    Blur,
    Flash,
    Shake,
}

BG_Transition :: struct {
    active:   bool,
    kind:     Transition_Kind,
    t:        f32,
    duration: f32,
    from_tex: u32,
    to_tex:   u32,
}

Transition_Override :: struct {
    active: bool,
    kind:   Transition_Kind,
    ms:     f32, // -1 means "use defaults"
}

g_transition_override: Transition_Override

transition_set_override :: proc(kind: Transition_Kind, ms: f32) {
    g_transition_override.active = true
    g_transition_override.kind = kind
    g_transition_override.ms = ms
}

transition_take_override :: proc() -> (Transition_Kind, f32, bool) {
    if !g_transition_override.active do return .None, 0, false
    g_transition_override.active = false
    return g_transition_override.kind, g_transition_override.ms, true
}

bg_transition_kind_from_string :: proc(s: string) -> Transition_Kind {
    switch s {
    case "fade": return .Fade
    case "wipe": return .Wipe
    case "slide": return .Slide
    case "dissolve": return .Dissolve
    case "zoom": return .Zoom
    case "blur": return .Blur
    case "flash": return .Flash
    case "shake": return .Shake
    case "none": return .None
    }
    return .Fade
}

bg_transition_start :: proc(state: ^Game_State, new_tex: u32) {
    if new_tex == 0 {
        state.current_bg = 0
        state.bg_transition.active = false
        return
    }

    kind := bg_transition_kind_from_string(ui_cfg.bg_transition)
    duration := ui_cfg.bg_transition_ms
    if k, ms, ok := transition_take_override(); ok {
        kind = k
        if ms >= 0 {
            duration = ms
        }
    }
    if duration <= 0 || kind == .None {
        state.current_bg = new_tex
        state.bg_transition.active = false
        return
    }

    base_tex := state.current_bg
    if state.bg_transition.active && state.bg_transition.to_tex != 0 {
        base_tex = state.bg_transition.to_tex
    }

    if base_tex == 0 {
        state.current_bg = new_tex
        state.bg_transition.active = false
        return
    }

    state.bg_transition.active = true
    state.bg_transition.kind = kind
    state.bg_transition.t = 0
    state.bg_transition.duration = duration / 1000.0
    state.bg_transition.from_tex = base_tex
    state.bg_transition.to_tex = new_tex
}

bg_transition_update :: proc(state: ^Game_State, dt: f32) {
    if !state.bg_transition.active do return
    state.bg_transition.t += dt
    if state.bg_transition.t >= state.bg_transition.duration {
        state.bg_transition.active = false
        state.current_bg = state.bg_transition.to_tex
        state.bg_transition.from_tex = 0
        return
    }
}

bg_transition_draw :: proc(state: ^Game_State, r: ^Renderer) {
    t := state.bg_transition.t / state.bg_transition.duration
    if t < 0 do t = 0
    if t > 1 do t = 1

    from_tex := state.bg_transition.from_tex
    to_tex := state.bg_transition.to_tex
    eased := t * t * (3 - 2*t)

    switch state.bg_transition.kind {
    case .Fade:
        if from_tex != 0 {
            renderer_draw_texture_tinted(r, from_tex, 0, 0, r.width, r.height, {1, 1, 1, 1 - t})
        }
        if to_tex != 0 {
            renderer_draw_texture_tinted(r, to_tex, 0, 0, r.width, r.height, {1, 1, 1, t})
        }
    case .Wipe:
        if from_tex != 0 {
            renderer_draw_texture(r, from_tex, 0, 0, r.width, r.height)
        }
        if to_tex != 0 {
            w := r.width * t
            uv1 := Vec2{t, 1}
            renderer_draw_texture_tinted_uv(r, to_tex, 0, 0, w, r.height, Vec2{0, 0}, uv1, {1, 1, 1, 1})
        }
    case .Slide:
        if from_tex != 0 {
            renderer_draw_texture(r, from_tex, 0, 0, r.width, r.height)
        }
        if to_tex != 0 {
            x := (1 - t) * r.width
            renderer_draw_texture(r, to_tex, x, 0, r.width, r.height)
        }
    case .Dissolve:
        if from_tex != 0 {
            renderer_draw_texture_tinted(r, from_tex, 0, 0, r.width, r.height, {1, 1, 1, 1 - eased})
        }
        if to_tex != 0 {
            renderer_draw_texture_tinted(r, to_tex, 0, 0, r.width, r.height, {1, 1, 1, eased})
        }
    case .Zoom:
        if from_tex != 0 {
            renderer_draw_texture_tinted(r, from_tex, 0, 0, r.width, r.height, {1, 1, 1, 1 - t})
        }
        if to_tex != 0 {
            scale := 0.9 + 0.1*t
            w := r.width * scale
            h := r.height * scale
            x := (r.width - w) * 0.5
            y := (r.height - h) * 0.5
            renderer_draw_texture_tinted(r, to_tex, x, y, w, h, {1, 1, 1, t})
        }
    case .Blur:
        // Placeholder: soft dissolve until a real blur shader exists.
        if from_tex != 0 {
            renderer_draw_texture_tinted(r, from_tex, 0, 0, r.width, r.height, {1, 1, 1, 1 - eased})
        }
        if to_tex != 0 {
            renderer_draw_texture_tinted(r, to_tex, 0, 0, r.width, r.height, {1, 1, 1, eased})
        }
        renderer_draw_rect(r, 0, 0, r.width, r.height, {0, 0, 0, (1 - eased) * 0.12})
    case .Flash:
        if t < 0.5 {
            if from_tex != 0 {
                renderer_draw_texture(r, from_tex, 0, 0, r.width, r.height)
            }
        } else {
            if to_tex != 0 {
                renderer_draw_texture(r, to_tex, 0, 0, r.width, r.height)
            }
        }
        flash := 1 - abs(2*t-1)
        renderer_draw_rect(r, 0, 0, r.width, r.height, {1, 1, 1, flash})
    case .Shake:
        // Simple screen shake during cross-fade.
        base := ui_cfg.bg_shake_px
        if base <= 0 do base = 10
        amp := base * (1 - t)
        x := math.sin(t * 50) * amp
        y := math.cos(t * 45) * amp
        if from_tex != 0 {
            renderer_draw_texture_tinted(r, from_tex, x, y, r.width, r.height, {1, 1, 1, 1 - t})
        }
        if to_tex != 0 {
            renderer_draw_texture_tinted(r, to_tex, x, y, r.width, r.height, {1, 1, 1, t})
        }
    case .None:
        if to_tex != 0 {
            renderer_draw_texture(r, to_tex, 0, 0, r.width, r.height)
        }
    }
}
