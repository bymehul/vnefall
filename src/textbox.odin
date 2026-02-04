package vnefall

import "core:strings"

Text_Segment :: struct {
    text:      string,
    color:     [4]f32,
    has_color: bool,
}

textbox_set_text :: proc(tb: ^Textbox_State, text: string) {
    if len(tb.text) > 0 do delete(tb.text)
    textbox_clear_segments(tb)
    
    tb.text = text
    tb.reveal_accum = 0
    tb.reveal_count = 0
    tb.shake = false
    tb.speed_override_active = false
    tb.speed_override = 0
    textbox_parse_segments(tb)
    tb.reveal_total = segments_rune_count(tb.segments[:])
    textbox_rebuild_shown_segments(tb, tb.reveal_count)
}

textbox_set_text_with_speed :: proc(tb: ^Textbox_State, text: string, speed: f32) {
    textbox_set_text(tb, text)
    tb.speed_override_active = true
    tb.speed_override = speed
}

textbox_reveal_all :: proc(tb: ^Textbox_State) {
    tb.reveal_total = segments_rune_count(tb.segments[:])
    tb.reveal_count = tb.reveal_total
    tb.reveal_accum = 0
    textbox_rebuild_shown_segments(tb, tb.reveal_count)
}

textbox_destroy :: proc(tb: ^Textbox_State) {
    if tb.text != "" {
        delete(tb.text)
        tb.text = ""
    }
    textbox_clear_segments(tb)
    delete(tb.segments)
    delete(tb.shown_segments)
}

textbox_is_revealed :: proc(tb: ^Textbox_State) -> bool {
    return tb.reveal_count >= tb.reveal_total
}

textbox_update :: proc(tb: ^Textbox_State, dt: f32) {
    if !tb.visible do return
    if tb.reveal_total == 0 do return
    speed := ui_cfg.text_speed
    if tb.speed_override_active {
        speed = tb.speed_override
    }
    if speed <= 0 {
        textbox_reveal_all(tb)
        return
    }
    if textbox_is_revealed(tb) do return
    
    tb.reveal_accum += dt
    if tb.reveal_accum < speed do return
    
    steps := int(tb.reveal_accum / speed)
    tb.reveal_accum -= f32(steps) * speed
    tb.reveal_count = min(tb.reveal_total, tb.reveal_count + steps)
    
    textbox_rebuild_shown_segments(tb, tb.reveal_count)
}

textbox_clear_segments :: proc(tb: ^Textbox_State) {
    for seg in tb.segments {
        if seg.text != "" do delete(seg.text)
    }
    for seg in tb.shown_segments {
        if seg.text != "" do delete(seg.text)
    }
    clear(&tb.segments)
    clear(&tb.shown_segments)
}

textbox_parse_segments :: proc(tb: ^Textbox_State) {
    b: strings.Builder
    strings.builder_init(&b)
    defer strings.builder_destroy(&b)

    current_color: [4]f32
    has_color := false

    i := 0
    for i < len(tb.text) {
        if tb.text[i] == '{' {
            end := strings.index(tb.text[i+1:], "}")
            if end != -1 {
                tag := tb.text[i+1 : i+1+end]
                if textbox_handle_tag(tb, tag, &current_color, &has_color, &b) {
                    i += end + 2
                    continue
                }
            }
        }
        strings.write_rune(&b, rune(tb.text[i]))
        i += 1
    }
    textbox_flush_segment(tb, &b, current_color, has_color)
}

textbox_handle_tag :: proc(tb: ^Textbox_State, tag: string, color: ^[4]f32, has_color: ^bool, b: ^strings.Builder) -> bool {
    trimmed := strings.trim_space(tag)
    if trimmed == "" do return false

    if trimmed == "shake" {
        tb.shake = true
        textbox_flush_segment(tb, b, color^, has_color^)
        return true
    }
    if trimmed == "/shake" {
        textbox_flush_segment(tb, b, color^, has_color^)
        return true
    }
    if trimmed == "/color" || trimmed == "color=reset" {
        textbox_flush_segment(tb, b, color^, has_color^)
        has_color^ = false
        return true
    }

    if strings.has_prefix(trimmed, "color=") {
        val := strings.trim_space(trimmed[6:])
        if val == "reset" {
            textbox_flush_segment(tb, b, color^, has_color^)
            has_color^ = false
            return true
        }
        textbox_flush_segment(tb, b, color^, has_color^)
        color^ = parse_hex_color(val)
        has_color^ = true
        return true
    }
    return false
}

textbox_flush_segment :: proc(tb: ^Textbox_State, b: ^strings.Builder, color: [4]f32, has_color: bool) {
    s := strings.to_string(b^)
    if len(s) == 0 do return
    seg := Text_Segment{
        text = strings.clone(s),
        color = color,
        has_color = has_color,
    }
    append(&tb.segments, seg)
    strings.builder_reset(b)
}

textbox_rebuild_shown_segments :: proc(tb: ^Textbox_State, count: int) {
    for seg in tb.shown_segments {
        if seg.text != "" do delete(seg.text)
    }
    clear(&tb.shown_segments)

    remaining := count
    for seg in tb.segments {
        if remaining <= 0 do break
        seg_count := rune_count(seg.text)
        if seg_count <= remaining {
            append(&tb.shown_segments, Text_Segment{
                text = strings.clone(seg.text),
                color = seg.color,
                has_color = seg.has_color,
            })
            remaining -= seg_count
        } else {
            prefix := prefix_runes(seg.text, remaining)
            append(&tb.shown_segments, Text_Segment{
                text = prefix,
                color = seg.color,
                has_color = seg.has_color,
            })
            remaining = 0
        }
    }
}

segments_rune_count :: proc(segs: []Text_Segment) -> int {
    total := 0
    for seg in segs {
        total += rune_count(seg.text)
    }
    return total
}

rune_count :: proc(text: string) -> int {
    count := 0
    for _ in text do count += 1
    return count
}

prefix_runes :: proc(text: string, count: int) -> string {
    if count <= 0 do return strings.clone("")
    if count >= rune_count(text) do return strings.clone(text)
    
    b: strings.Builder
    strings.builder_init(&b)
    defer strings.builder_destroy(&b)
    
    seen := 0
    for r in text {
        if seen >= count do break
        strings.write_rune(&b, r)
        seen += 1
    }
    return strings.clone(strings.to_string(b))
}
