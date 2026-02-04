/*
    Character registry (char.vnef)
    Stores per-character UI colors.
*/

package vnefall

import "core:fmt"
import "core:os"
import "core:strings"

Char_UI_Style :: struct {
    name: string,
    name_color: [4]f32,
    text_color: [4]f32,
}

g_char_styles: map[string]Char_UI_Style

char_registry_init :: proc() {
    g_char_styles = make(map[string]Char_UI_Style)
}

char_registry_cleanup :: proc() {
    for _, v in g_char_styles {
        delete(v.name)
    }
    delete(g_char_styles)
}

char_registry_load :: proc(path: string) -> bool {
    if g_char_styles == nil {
        char_registry_init()
    } else {
        for _, v in g_char_styles {
            delete(v.name)
        }
        clear(&g_char_styles)
    }

    data, ok := os.read_entire_file(path)
    if !ok {
        fmt.printf("[vnefall] No character registry found at %s. Using defaults.\n", path)
        return true
    }
    defer delete(data)

    content := string(data)
    lines := strings.split_lines(content)
    defer delete(lines)

    current_name := ""
    current_style := Char_UI_Style{}

    for line in lines {
        trimmed := strings.trim_space(line)
        if len(trimmed) == 0 || strings.has_prefix(trimmed, "#") do continue

        if strings.has_prefix(trimmed, "[") && strings.has_suffix(trimmed, "]") {
            // Commit previous section
            if current_name != "" {
                g_char_styles[current_name] = current_style
            }

            section := strings.trim(trimmed, "[]")
            if section == "" do continue

            current_name = strings.clone(section)

            current_style = Char_UI_Style{
                name = current_name,
                name_color = ui_cfg.speaker_color,
                text_color = ui_cfg.text_color,
            }
            continue
        }

        if current_name == "" do continue

        parts := strings.split(trimmed, "=")
        if len(parts) != 2 {
            delete(parts)
            continue
        }

        key := strings.trim_space(parts[0])
        val := strings.trim_space(parts[1])
        if idx := strings.index(val, "#"); idx != -1 {
            val = strings.trim_space(val[:idx])
        }

        switch key {
        case "name_color":
            current_style.name_color = parse_hex_color(val)
        case "text_color":
            current_style.text_color = parse_hex_color(val)
        }

        delete(parts)
    }

    if current_name != "" {
        g_char_styles[current_name] = current_style
    }

    fmt.printf("[vnefall] Character registry loaded from %s\n", path)
    return true
}

char_style_for :: proc(name: string) -> (Char_UI_Style, bool) {
    if name == "" do return {}, false
    if v, ok := g_char_styles[name]; ok do return v, true
    return {}, false
}
