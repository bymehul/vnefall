package vneui

ui_wrap_text_ranges :: proc(ctx: ^UI_Context, text: string, max_width: f32, font_id: int, font_size: f32) -> [dynamic]UI_Text_Range {
    ranges := make([dynamic]UI_Text_Range)
    if text == "" {
        return ranges
    }
    if max_width <= 0 {
        append(&ranges, UI_Text_Range{0, len(text)})
        return ranges
    }
    
    space_w := ui_measure_text(ctx, " ", font_id, font_size)
    line_start := 0
    word_start := 0
    line_width: f32 = 0
    
    for i := 0; i <= len(text); i += 1 {
        at_end := i == len(text)
        is_space := !at_end && text[i] == ' '
        is_newline := !at_end && text[i] == '\n'
        if at_end || is_space || is_newline {
            word_end := i
            if word_end > word_start {
                word := text[word_start:word_end]
                word_w := ui_measure_text(ctx, word, font_id, font_size)
                if line_width > 0 && line_width + space_w + word_w > max_width {
                    line_len := word_start - line_start
                    if line_len > 0 && text[line_start + line_len - 1] == ' ' {
                        line_len -= 1
                    }
                    if line_len > 0 {
                        append(&ranges, UI_Text_Range{line_start, line_len})
                    }
                    line_start = word_start
                    line_width = 0
                }
                if line_width > 0 {
                    line_width += space_w
                }
                line_width += word_w
            }
            
            if is_newline {
                line_len := word_end - line_start
                if line_len > 0 && text[line_start + line_len - 1] == ' ' {
                    line_len -= 1
                }
                if line_len > 0 {
                    append(&ranges, UI_Text_Range{line_start, line_len})
                }
                line_start = i + 1
                line_width = 0
            }
            
            if is_space || is_newline {
                word_start = i + 1
            }
        }
    }
    
    if line_start < len(text) {
        line_len := len(text) - line_start
        if line_len > 0 && text[line_start + line_len - 1] == ' ' {
            line_len -= 1
        }
        if line_len > 0 {
            append(&ranges, UI_Text_Range{line_start, line_len})
        }
    }
    return ranges
}

ui_push_text_wrapped :: proc(ctx: ^UI_Context, rect: Rect, text: string, font_id: int, font_size: f32, color: Color, align_h, align_v: UI_Align, line_height: f32) {
    lh := line_height
    if lh <= 0 {
        lh = font_size * 1.2
    }
    ranges := ui_wrap_text_ranges(ctx, text, rect.w, font_id, font_size)
    if len(ranges) == 0 {
        delete(ranges)
        return
    }
    
    total_h := f32(len(ranges)) * lh
    start_y := rect.y
    switch align_v {
    case .Center:
        start_y = rect.y + (rect.h - total_h) * 0.5
    case .End:
        start_y = rect.y + rect.h - total_h
    case .Start:
        start_y = rect.y
    }
    
    for i := 0; i < len(ranges); i += 1 {
        r := ranges[i]
        line_rect := Rect{x = rect.x, y = start_y + f32(i)*lh, w = rect.w, h = lh}
        slice := text[r.start : r.start+r.len]
        ui_push_text_aligned(ctx, line_rect, slice, font_id, font_size, color, align_h, .Center)
    }
    delete(ranges)
}
