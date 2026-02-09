package vnefall

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
import "sthiti"

Command_Type :: enum {
    None,
    Bg,
    BgBlur,
    Say,
    Wait,
    End,
    Music,
    MusicFade,
    MusicStop,
    MusicStopFade,
    Ambience,
    AmbienceFade,
    AmbienceStop,
    Sfx,
    Voice,
    Volume,
    Title,
    Label,
    Character,
    Jump,
    JumpFile,   // jump_file "chapter_2.vnef" (load new script)
    Choice,
    ChoiceAdd,
    ChoiceShow,
    Save,
    Load,
    Set,
    If,
    Else,
    BlockStart, // For {
    BlockEnd,   // For }
    Scene,      // scene "chapter_1"
    SceneNext,  // scene_next "chapter_2" (prefetch)
    With,       // with fade 400
    Movie,      // movie "intro.video" [options]
    MovieStop,  // movie stop
    MoviePause, // movie pause
    MovieResume,// movie resume
    TextboxShow,// textbox show
    TextboxHide,// textbox hide
    TextboxWait,// textbox wait (hide until click)
}

Command :: struct {
    type: Command_Type,
    who:  string, // arg1: image path or character name
    what: string, // arg2: dialogue text
    args: [dynamic]string, // arg3+: for multi-param commands like 'choice'
    jump: int,    // Jump index for blocks (IF false, or BlockEnd skip ELSE)
    indented: bool, // True if the line had leading whitespace
}

Value :: union {
    int,
    string,
}

Script :: struct {
    commands:  [dynamic]Command,
    labels:    map[string]int,
    variables: map[string]Value,
    path:      string, // Path to this script file
    bg_path:   string, // Current background path for persistence
    ip:        int,
    waiting:   bool,
}

script_load :: proc(s: ^Script, path: string) -> bool {
    // Clear any existing data first (for reload case)
    script_cleanup(s)
    
    // Initialize maps if they don't exist yet
    if s.labels == nil    do s.labels = make(map[string]int)
    if s.variables == nil do s.variables = make(map[string]Value)
    if s.commands == nil  do s.commands = make([dynamic]Command)
    
    s.path = strings.clone(path)
    s.ip = 0
    s.waiting = false
    
    data, ok := os.read_entire_file(path)
    if !ok {
        fmt.eprintln("Could not read script:", path)
        return false
    }
    defer delete(data)
    
    content := string(data)
    lines := strings.split_lines(content)
    defer delete(lines)
    
    for line in lines {
        trimmed := strings.trim_space(line)
        if len(trimmed) == 0 || trimmed[0] == '#' do continue
        
        is_indented := len(line) > 0 && (line[0] == ' ' || line[0] == '\t')
        
        // Revised approach: Just check specific combo tokens first (no allocation)
        if strings.contains(trimmed, "} else {") {
            append(&s.commands, Command{type = .BlockEnd, indented = is_indented})
            append(&s.commands, Command{type = .Else, indented = is_indented})
            append(&s.commands, Command{type = .BlockStart, indented = is_indented})
            continue
        }
        if strings.contains(trimmed, "} else") {
            append(&s.commands, Command{type = .BlockEnd, indented = is_indented})
            append(&s.commands, Command{type = .Else, indented = is_indented})
            continue
        }
        
        // Handle trailing { on commands like if/else
        has_trailing_brace := strings.has_suffix(trimmed, "{") && trimmed != "{" && !strings.has_prefix(trimmed, "say ")
        
        cmd := parse_line(trimmed)
        if cmd.type != .None {
            cmd.indented = is_indented
            append(&s.commands, cmd)
            if has_trailing_brace {
                append(&s.commands, Command{type = .BlockStart, indented = is_indented})
            }
        }
    }
    
    // Pre-scan for labels so we can jump instantly
    for cmd, i in s.commands {
        if cmd.type == .Label {
            s.labels[cmd.who] = i
        }
    }
    
    // Pass 2: Resolve blocks and if/else jumps
    block_stack := make([dynamic]int)
    defer delete(block_stack)
    
    for i := 0; i < len(s.commands); i += 1 {
        cmd := &s.commands[i]
        
        // Indentation check: commands inside blocks or after labels should be indented
        in_block := len(block_stack) > 0
        is_structural := cmd.type == .Label || cmd.type == .BlockStart || cmd.type == .BlockEnd || cmd.type == .Else
        
        if in_block && !is_structural && !cmd.indented {
            fmt.printf("[script] Warning: Missing indentation inside block at instruction %d\n", i)
        }
        
        // After-label check
        if i > 0 && s.commands[i-1].type == .Label && !cmd.indented && !is_structural {
             fmt.printf("[script] Warning: Missing indentation after label '%s' at instruction %d\n", s.commands[i-1].who, i)
        }

        #partial switch cmd.type {
        case .BlockStart:
            append(&block_stack, i)
        
        case .BlockEnd:
            if len(block_stack) == 0 {
                fmt.eprintln("Error: Unmatched } at instruction", i)
                continue
            }
            start_idx := pop(&block_stack)
            start_cmd := &s.commands[start_idx]
            
            // Link the parent (IF or ELSE) to the end of its block
            parent_idx := start_idx - 1
            if parent_idx >= 0 {
                parent := &s.commands[parent_idx]
                if parent.type == .If || parent.type == .Else {
                    parent.jump = i + 1
                }
                
                // If we just finished an ELSE block, we need to check if the 
                // preceding IF block's end needs to be patched to jump HERE.
                if parent.type == .Else {
                    // Search for the preceding IF's block end
                    // (It would have been pushed if an else followed it)
                    if len(block_stack) > 0 {
                        potential_if_end_idx := block_stack[len(block_stack)-1]
                        if s.commands[potential_if_end_idx].type == .BlockEnd {
                            if_end_idx := pop(&block_stack)
                            s.commands[if_end_idx].jump = i + 1
                        }
                    }
                }
            }
            
            // If an ELSE follows this block, we need to skip it if the IF was true.
            // Push this BlockEnd so the ELSE's BlockEnd can patch its jump.
            if i + 1 < len(s.commands) && s.commands[i+1].type == .Else {
                append(&block_stack, i) 
            }
        }
    }
    
    fmt.printf("[script] Parsed %d commands (%d labels) from %s\n", len(s.commands), len(s.labels), path)
    return len(s.commands) > 0
}

parse_line :: proc(line: string) -> (cmd: Command) {
    // bg / images
    if strings.has_prefix(line, "bg ") {
        cmd.type = .Bg
        rest := strings.trim_space(line[3:])
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
        
        cmd.who = strings.clone(strings.trim_space(path))
        if tail != "" {
            parts := strings.split(tail, " ")
            defer delete(parts)
            for p in parts {
                t := strings.trim_space(p)
                if t == "" do continue
                append(&cmd.args, strings.clone(strings.trim(t, "\"")))
            }
        }
        return
    }

    // bg_blur <value>
    if strings.has_prefix(line, "bg_blur ") {
        cmd.type = .BgBlur
        cmd.what = strings.clone(strings.trim_space(line[8:]))
        return
    }

    // with <fade|wipe|slide|dissolve|zoom|blur|flash|shake|none> [ms]
    if strings.has_prefix(line, "with ") {
        cmd.type = .With
        rest := strings.trim_space(line[5:])
        parts := strings.split(rest, " ")
        defer delete(parts)
        if len(parts) >= 1 {
            cmd.who = strings.clone(strings.trim_space(parts[0]))
        }
        if len(parts) >= 2 {
            cmd.what = strings.clone(strings.trim_space(parts[1]))
        }
        return
    }

    // movie "intro.video" [loop] [hold] [wait] [layer=bg|fg] [textbox=hide|wait]
    if strings.has_prefix(line, "movie ") {
        rest := strings.trim_space(line[6:])
        if rest == "stop" {
            cmd.type = .MovieStop
            return
        }
        if rest == "pause" {
            cmd.type = .MoviePause
            return
        }
        if rest == "resume" {
            cmd.type = .MovieResume
            return
        }
        
        cmd.type = .Movie
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
                for i := 1; i < len(parts); i += 1 {
                    t := strings.trim_space(parts[i])
                    if t == "" do continue
                    append(&cmd.args, strings.clone(strings.trim(t, "\"")))
                }
            }
        }
        
        cmd.who = strings.clone(strings.trim_space(path))
        if tail != "" {
            parts := strings.split(tail, " ")
            defer delete(parts)
            for p in parts {
                t := strings.trim_space(p)
                if t == "" do continue
                append(&cmd.args, strings.clone(strings.trim(t, "\"")))
            }
        }
        return
    }

    // textbox show|hide|wait
    if strings.has_prefix(line, "textbox ") {
        rest := strings.trim_space(line[8:])
        if rest == "show" {
            cmd.type = .TextboxShow
            return
        }
        if rest == "hide" {
            cmd.type = .TextboxHide
            return
        }
        if rest == "wait" {
            cmd.type = .TextboxWait
            return
        }
    }
    
    // dialogue: say Alice "Hello"
    if strings.has_prefix(line, "say ") {
        rest := line[4:]
        
        // Find quotes for the text
        q1 := strings.index(rest, "\"")
        if q1 < 0 {
            fmt.eprintln("Missing quotes in say:", line)
            return
        }
        
        cmd.type = .Say
        header := strings.trim_space(rest[:q1])
        speed_val := ""
        if idx := strings.index(header, "[speed="); idx != -1 {
            end := strings.index(header[idx:], "]")
            if end != -1 {
                start := idx + len("[speed=")
                speed_val = strings.trim_space(header[start : idx+end])
                header = strings.trim_space(header[:idx])
            }
        }
        cmd.who  = strings.clone(strings.trim_space(header))
        
        q2_part := rest[q1+1:]
        q2 := strings.index(q2_part, "\"")
        if q2 < 0 {
            cmd.what = strings.clone(q2_part)
        } else {
            cmd.what = strings.clone(q2_part[:q2])
        }
        if speed_val != "" {
            append(&cmd.args, strings.clone(speed_val))
        }
        return
    }
    
    // Audio / Music
    if strings.has_prefix(line, "music ") || strings.has_prefix(line, "play ") {
        off := strings.has_prefix(line, "music ") ? 6 : 5
        cmd.type = .Music
        rest := strings.trim_space(line[off:])
        cmd.who = strings.clone(strings.trim(rest, "\""))
        return
    }

    // music_fade <filename> <ms>
    if strings.has_prefix(line, "music_fade ") {
        cmd.type = .MusicFade
        rest := strings.trim_space(line[11:])
        parts := strings.split(rest, " ")
        defer delete(parts)
        if len(parts) >= 1 {
            cmd.who = strings.clone(strings.trim(parts[0], "\""))
        }
        if len(parts) >= 2 {
            cmd.what = strings.clone(strings.trim_space(parts[1]))
        }
        return
    }
    
    // music_stop_fade <ms>
    if strings.has_prefix(line, "music_stop_fade ") {
        cmd.type = .MusicStopFade
        rest := strings.trim_space(line[16:])
        cmd.what = strings.clone(strings.trim_space(rest))
        return
    }
    
    // music_stop
    if line == "music_stop" {
        cmd.type = .MusicStop
        return
    }

    // ambience <filename>
    if strings.has_prefix(line, "ambience ") {
        cmd.type = .Ambience
        rest := strings.trim_space(line[9:])
        cmd.who = strings.clone(strings.trim(rest, "\""))
        return
    }
    
    // ambience_fade <filename> <ms>
    if strings.has_prefix(line, "ambience_fade ") {
        cmd.type = .AmbienceFade
        rest := strings.trim_space(line[14:])
        parts := strings.split(rest, " ")
        defer delete(parts)
        if len(parts) >= 1 {
            cmd.who = strings.clone(strings.trim(parts[0], "\""))
        }
        if len(parts) >= 2 {
            cmd.what = strings.clone(strings.trim_space(parts[1]))
        }
        return
    }
    
    // ambience_stop
    if line == "ambience_stop" {
        cmd.type = .AmbienceStop
        return
    }
    
    // sfx <filename>
    if strings.has_prefix(line, "sfx ") {
        cmd.type = .Sfx
        rest := strings.trim_space(line[4:])
        cmd.who = strings.clone(strings.trim(rest, "\""))
        return
    }
    
    // voice <filename>
    if strings.has_prefix(line, "voice ") {
        cmd.type = .Voice
        rest := strings.trim_space(line[6:])
        cmd.who = strings.clone(strings.trim(rest, "\""))
        return
    }
    
    // volume <channel> <value>
    if strings.has_prefix(line, "volume ") {
        cmd.type = .Volume
        rest := strings.trim_space(line[7:])
        parts := strings.split(rest, " ")
        defer delete(parts)
        if len(parts) >= 1 do cmd.who  = strings.clone(strings.trim_space(parts[0]))
        if len(parts) >= 2 do cmd.what = strings.clone(strings.trim_space(parts[1]))
        return
    }
    
    if strings.has_prefix(line, "title ") {
        cmd.type = .Title
        rest := strings.trim_space(line[6:])
        // Strip quotes if present
        if len(rest) >= 2 && rest[0] == '"' && rest[len(rest)-1] == '"' {
            cmd.who = strings.clone(rest[1:len(rest)-1])
        } else {
            cmd.who = strings.clone(rest)
        }
        return
    }
    
    // label <name> or label <name>:
    if strings.has_prefix(line, "label ") {
        cmd.type = .Label
        rest := strings.trim_space(line[6:])
        if strings.has_suffix(rest, ":") {
            rest = rest[:len(rest)-1]
        }
        cmd.who = strings.clone(strings.trim_space(rest))
        return
    }
    
    // jump <label>
    if strings.has_prefix(line, "jump ") && !strings.has_prefix(line, "jump_file") {
        cmd.type = .Jump
        cmd.who  = strings.clone(strings.trim_space(line[5:]))
        return
    }
    
    // jump_file "chapter_2.vnef" - load a different script file
    if strings.has_prefix(line, "jump_file ") {
        cmd.type = .JumpFile
        rest := strings.trim_space(line[10:])
        cmd.who = strings.clone(strings.trim(rest, "\""))
        return
    }

    // choice_add "Text" label
    if strings.has_prefix(line, "choice_add ") {
        cmd.type = .ChoiceAdd
        rest := strings.trim_space(line[11:])
        // Split text and label
        q1 := strings.index(rest, "\"")
        if q1 != -1 {
            q2 := strings.index(rest[q1+1:], "\"")
            if q2 != -1 {
                cmd.who = strings.clone(rest[q1+1 : q1+1+q2])
                cmd.what = strings.clone(strings.trim_space(rest[q1+1+q2+1:]))
            }
        }
        return
    }

    if strings.has_prefix(line, "choice_show") {
        cmd.type = .ChoiceShow
        rest := strings.trim_space(line[11:])
        if len(rest) >= 2 && rest[0] == '"' && rest[len(rest)-1] == '"' {
             cmd.who = strings.clone(rest[1:len(rest)-1])
        } else {
             cmd.who = strings.clone(rest)
        }
        return
    }

    // set money = 100  OR  set flag true
    if strings.has_prefix(line, "set ") {
        cmd.type = .Set
        rest := strings.trim_space(line[4:])
        if idx := strings.index(rest, "="); idx != -1 {
            cmd.who  = strings.clone(strings.trim_space(rest[:idx]))
            cmd.what = strings.clone(strings.trim_space(rest[idx+1:]))
        } else {
            parts := strings.split(rest, " ")
            if len(parts) >= 2 {
                cmd.who  = strings.clone(parts[0])
                cmd.what = strings.clone(parts[1])
            }
        }
        return
    }

    // if (expr) {
    if strings.has_prefix(line, "if ") {
        cmd.type = .If
        rest := strings.trim_space(line[3:])
        
        // Strip trailing {
        if strings.has_suffix(rest, "{") {
            rest = strings.trim_space(rest[:len(rest)-1])
        }

        // Handle JS-style if (expr)
        if strings.has_prefix(rest, "(") {
            end := strings.last_index(rest, ")")
            if end != -1 {
                cmd.who = strings.clone(rest[1:end]) // The expression
            }
        } else {
            // Legacy: if <flag> jump <label>
            parts := strings.split(rest, " ")
            defer delete(parts)
            if len(parts) >= 3 && parts[1] == "jump" {
                cmd.who  = strings.clone(parts[0])
                cmd.what = strings.clone(parts[2])
            }
        }
        return
    }

    if line == "else" || line == "else {" do return Command{type = .Else}
    if line == "{"    do return Command{type = .BlockStart}
    if line == "}"    do return Command{type = .BlockEnd}
    
    // scene "chapter_1" - bind to a manifest
    if strings.has_prefix(line, "scene ") && !strings.has_prefix(line, "scene_next") {
        cmd.type = .Scene
        rest := strings.trim_space(line[6:])
        cmd.who = strings.clone(strings.trim(rest, "\""))
        return
    }
    
    // scene_next "chapter_2" - prefetch next scene
    if strings.has_prefix(line, "scene_next ") {
        cmd.type = .SceneNext
        rest := strings.trim_space(line[11:])
        cmd.who = strings.clone(strings.trim(rest, "\""))
        return
    }
    
    // char Alice show happy at left
    // char Alice hide
    if strings.has_prefix(line, "char ") {
        cmd.type = .Character
        parts := strings.split(line, " ")
        defer delete(parts)
        if len(parts) >= 3 {
            cmd.who = strings.clone(parts[1]) // Alice
            cmd.what = strings.clone(parts[2]) // show/hide
            
            // For 'show happy at left', args would be ["happy", "left"]
            start := 3
            for i := start; i < len(parts); i += 1 {
                if parts[i] == "at" do continue
                cmd_arg := strings.trim_space(parts[i])
                append(&cmd.args, strings.clone(strings.trim(cmd_arg, "\"")))
            }
        }
        return
    }
    
    // save "slot_1"
    if strings.has_prefix(line, "save ") {
        cmd.type = .Save
        rest := strings.trim_space(line[5:])
        cmd.who = strings.clone(strings.trim(rest, "\""))
        return
    }
    
    // load "slot_1"
    if strings.has_prefix(line, "load ") {
        cmd.type = .Load
        rest := strings.trim_space(line[5:])
        cmd.who = strings.clone(strings.trim(rest, "\""))
        return
    }

    if line == "wait" do return Command{type = .Wait}
    if line == "end"  do return Command{type = .End}
    
    fmt.eprintln("Unrecognized command:", line)
    return
}

script_cleanup :: proc(s: ^Script) {
    for cmd in s.commands {
        if cmd.who != "" do delete(cmd.who)
        if cmd.what != "" do delete(cmd.what)
        for arg in cmd.args {
            delete(arg)
        }
        delete(cmd.args)
    }
    clear(&s.commands)  // Clear but keep the dynamic array
    clear(&s.labels)    // Clear but keep the map
    if s.path != "" {
        delete(s.path)
        s.path = ""
    }
    if s.bg_path != "" {
        delete(s.bg_path)
        s.bg_path = ""
    }
    // Keep variables across file jumps for persistent state
    
    // Flush character state (Dharana)
    character_flush_all()
}

// Final cleanup that frees all memory (call on game exit)
script_destroy :: proc(s: ^Script) {
    script_cleanup(s)
    delete(s.commands)
    delete(s.labels)
    for k, v in s.variables {
        delete(k) // keys are cloned in 'set'
        if str, ok := v.(string); ok do delete(str) // values are cloned strings
    }
    delete(s.variables)
}

script_execute :: proc(s: ^Script, state: ^Game_State) {
    if s.ip >= len(s.commands) {
        state.running = false
        return
    }
    
    c := s.commands[s.ip]
    
    #partial switch c.type {
    case .With:
        kind := strings.to_lower(strings.trim_space(c.who))
        defer delete(kind)
        if kind == "" {
            s.ip += 1
            return
        }
        t_kind := bg_transition_kind_from_string(kind)
        if kind != "fade" && kind != "wipe" && kind != "slide" && kind != "dissolve" && kind != "zoom" && kind != "blur" && kind != "flash" && kind != "shake" && kind != "none" {
            fmt.eprintln("[script] Unknown transition:", kind, "using fade")
            t_kind = .Fade
        }
        ms: f32 = -1
        if c.what != "" {
            if v, ok := strconv.parse_f32(c.what); ok {
                ms = v
            }
        }
        if ms < 0 && c.what != "" {
            ms = 0
        }
        if t_kind == .None {
            ms = 0
        }
        transition_set_override(t_kind, ms)
        s.ip += 1

    case .BgBlur:
        val := f32(0)
        if c.what != "" {
            lower := strings.to_lower(strings.trim_space(c.what))
            defer delete(lower)
            if lower == "off" || lower == "none" {
                val = 0
            } else if v, ok := strconv.parse_f32(c.what); ok {
                val = v
            }
        }
        if val < 0 do val = 0
        state.bg_blur_strength = val
        state.bg_blur_base = val
        state.bg_blur_override_active = false
        bg_blur_set_strength(&state.bg_blur, val)
        s.ip += 1

    case .Movie:
        // Options: loop, hold, wait, layer=bg|fg, textbox=hide|wait
        loop := false
        hold := false
        wait := false
        audio_enabled := true
        rect_x: f32 = 0
        rect_y: f32 = 0
        rect_w: f32 = 0
        rect_h: f32 = 0
        use_rect := false
        fit := ""
        align := ""
        layer := Video_Layer.Background
        textbox_hide := false
        textbox_wait := false
        
        for arg in c.args {
            lower := strings.to_lower(arg)
            defer delete(lower)
            
            if lower == "loop" {
                loop = true
                continue
            }
            if lower == "audio=on" || lower == "audio=1" || lower == "audio=true" {
                audio_enabled = true
                continue
            }
            if lower == "audio=off" || lower == "audio=0" || lower == "audio=false" || lower == "mute" {
                audio_enabled = false
                continue
            }
            if lower == "hold" || lower == "hold_last" {
                hold = true
                continue
            }
            if lower == "wait" {
                wait = true
                continue
            }
            if lower == "bg" || lower == "background" {
                layer = .Background
                continue
            }
            if lower == "fg" || lower == "front" || lower == "foreground" {
                layer = .Foreground
                continue
            }
            if strings.has_prefix(lower, "layer=") {
                val := strings.trim_space(lower[6:])
                if val == "fg" || val == "front" || val == "foreground" {
                    layer = .Foreground
                } else {
                    layer = .Background
                }
                continue
            }
            if strings.has_prefix(lower, "x=") {
                if v, ok := strconv.parse_f32(strings.trim_space(lower[2:])); ok {
                    rect_x = v
                    use_rect = true
                }
                continue
            }
            if strings.has_prefix(lower, "y=") {
                if v, ok := strconv.parse_f32(strings.trim_space(lower[2:])); ok {
                    rect_y = v
                    use_rect = true
                }
                continue
            }
            if strings.has_prefix(lower, "w=") {
                if v, ok := strconv.parse_f32(strings.trim_space(lower[2:])); ok {
                    rect_w = v
                    use_rect = true
                }
                continue
            }
            if strings.has_prefix(lower, "h=") {
                if v, ok := strconv.parse_f32(strings.trim_space(lower[2:])); ok {
                    rect_h = v
                    use_rect = true
                }
                continue
            }
            if strings.has_prefix(lower, "fit=") {
                fit = strings.clone(strings.trim_space(lower[4:]))
                continue
            }
            if strings.has_prefix(lower, "align=") {
                align = strings.clone(strings.trim_space(lower[6:]))
                continue
            }
            if lower == "hide_textbox" || lower == "textbox=hide" {
                textbox_hide = true
                continue
            }
            if lower == "textbox=wait" || lower == "textbox_wait" {
                textbox_wait = true
                continue
            }
        }
        
        if textbox_wait {
            textbox_hide = true
            wait = true
            state.textbox.show_on_click = true
        }
        if textbox_hide {
            state.textbox.force_hidden = true
            state.textbox.visible = false
            if !textbox_wait {
                state.textbox.show_on_click = false
            }
        }
        if c.who == "" {
            fmt.eprintln("[script] movie: missing path")
            s.ip += 1
            return
        }

        // Enforce .video only (convert beforehand)
        {
            base := c.who
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
            if ext != "" && ext != ".video" {
                fmt.eprintln("[script] movie: unsupported extension (use .video):", ext)
                s.ip += 1
                return
            }
            if ext != "" {
                delete(ext)
            }
        }

        // Build video path
        path := ""
        if strings.has_prefix(c.who, "/") || strings.has_prefix(c.who, "./") || strings.has_prefix(c.who, "../") || strings.contains(c.who, ":\\") {
            path = strings.clone(c.who)
        } else {
            ext := ".video"
            if strings.contains(c.who, ".") do ext = ""
            path = strings.concatenate({cfg.path_videos, c.who, ext})
        }
        defer delete(path)

        // Auto-map audio: path_video_audio + <base>.ogg
        if audio_enabled && cfg.path_video_audio != "" {
            base := c.who
            if idx := strings.last_index(base, "/"); idx != -1 {
                base = base[idx+1:]
            }
            if idx := strings.last_index(base, "\\"); idx != -1 {
                base = base[idx+1:]
            }
            if dot := strings.last_index(base, "."); dot != -1 {
                base = base[:dot]
            }
            audio_path := strings.concatenate({cfg.path_video_audio, base, ".ogg"})
            if os.is_file(audio_path) {
                audio_play_video(&state.audio, audio_path)
            } else {
                audio_stop_video(&state.audio)
            }
            delete(audio_path)
        } else {
            audio_stop_video(&state.audio)
        }
        
        opts := Video_Play_Options{
            loop = loop,
            hold_last = hold,
            wait_for_click = wait,
            layer = layer,
            x = rect_x,
            y = rect_y,
            w = rect_w,
            h = rect_h,
            use_rect = use_rect,
            fit = fit,
            align = align,
        }
        
        if !video_play(&state.video, path, opts) {
            if fit != "" do delete(fit)
            if align != "" do delete(align)
            s.ip += 1
            return
        }
        if fit != "" do delete(fit)
        if align != "" do delete(align)
        
        if wait {
            s.waiting = true
            return
        }
        s.ip += 1

    case .MovieStop:
        video_stop(&state.video)
        audio_stop_video(&state.audio)
        s.ip += 1

    case .MoviePause:
        video_pause(&state.video)
        audio_pause_video(&state.audio)
        s.ip += 1

    case .MovieResume:
        video_resume(&state.video)
        audio_resume_video(&state.audio)
        s.ip += 1

    case .TextboxShow:
        state.textbox.force_hidden = false
        state.textbox.show_on_click = false
        state.textbox.visible = true
        s.ip += 1

    case .TextboxHide:
        state.textbox.force_hidden = true
        state.textbox.show_on_click = false
        state.textbox.visible = false
        s.ip += 1

    case .TextboxWait:
        state.textbox.force_hidden = true
        state.textbox.show_on_click = true
        state.textbox.visible = false
        s.waiting = true

    case .Bg:
        if s.bg_path != "" do delete(s.bg_path)
        s.bg_path = strings.clone(c.who)

        // Optional one-shot blur override: bg "image.png" blur=12
        blur_override: f32 = -1
        float_specified := false
        float_active := ui_cfg.bg_float_default
        float_px := ui_cfg.bg_float_px
        float_speed := ui_cfg.bg_float_speed
        for arg in c.args {
            lower := strings.to_lower(arg)
            defer delete(lower)
            if strings.has_prefix(lower, "blur=") {
                if v, ok := strconv.parse_f32(strings.trim_space(lower[5:])); ok {
                    blur_override = v
                }
            }
            if lower == "float" {
                float_specified = true
                float_active = true
                continue
            }
            if lower == "nofloat" || lower == "float=off" || lower == "float=false" {
                float_specified = true
                float_active = false
                continue
            }
            if strings.has_prefix(lower, "float=") {
                float_specified = true
                val := strings.trim_space(lower[6:])
                if val == "off" || val == "false" || val == "0" {
                    float_active = false
                } else if v, ok := strconv.parse_f32(val); ok {
                    float_active = v > 0
                    if v >= 0 do float_px = v
                }
                continue
            }
            if strings.has_prefix(lower, "float_px=") {
                float_specified = true
                if v, ok := strconv.parse_f32(strings.trim_space(lower[9:])); ok {
                    float_px = v
                    float_active = v > 0
                }
                continue
            }
            if strings.has_prefix(lower, "float_speed=") {
                float_specified = true
                if v, ok := strconv.parse_f32(strings.trim_space(lower[12:])); ok {
                    float_speed = v
                    float_active = true
                }
                continue
            }
        }
        if blur_override >= 0 {
            if blur_override < 0 do blur_override = 0
            state.bg_blur_strength = blur_override
            state.bg_blur_override_active = true
            bg_blur_set_strength(&state.bg_blur, blur_override)
        } else if state.bg_blur_override_active {
            // Revert to persistent blur when no override is provided.
            state.bg_blur_strength = state.bg_blur_base
            state.bg_blur_override_active = false
            bg_blur_set_strength(&state.bg_blur, state.bg_blur_base)
        }

        if float_specified {
            state.bg_float_active = float_active
            state.bg_float_px = float_px
            state.bg_float_speed = float_speed
        } else {
            state.bg_float_active = ui_cfg.bg_float_default
            state.bg_float_px = ui_cfg.bg_float_px
            state.bg_float_speed = ui_cfg.bg_float_speed
        }
        
        tex := scene_get_texture(c.who)
        if tex != 0 do bg_transition_start(state, tex)
        state.loading_active = false
        s.ip += 1
        
    case .Music:
        ext := ".ogg"
        if strings.contains(c.who, ".") do ext = ""
        
        path := strings.concatenate({cfg.path_music, c.who, ext})
        defer delete(path)
        audio_play_music(&state.audio, path)
        s.ip += 1

    case .MusicFade:
        ext := ".ogg"
        if strings.contains(c.who, ".") do ext = ""
        
        ms := 1000
        if c.what != "" {
            if v, ok := strconv.parse_int(c.what); ok do ms = v
        }
        
        path := strings.concatenate({cfg.path_music, c.who, ext})
        defer delete(path)
        audio_fade_music(&state.audio, path, ms)
        s.ip += 1
    
    case .MusicStop:
        audio_stop_music(&state.audio)
        s.ip += 1
    
    case .MusicStopFade:
        ms := 1000
        if c.what != "" {
            if v, ok := strconv.parse_int(c.what); ok do ms = v
        }
        audio_stop_music_fade(&state.audio, ms)
        s.ip += 1
    
    case .Ambience:
        ext := ".ogg"
        if strings.contains(c.who, ".") do ext = ""
        
        path := strings.concatenate({cfg.path_ambience, c.who, ext})
        defer delete(path)
        audio_play_ambience(&state.audio, path)
        s.ip += 1
    
    case .AmbienceFade:
        ext := ".ogg"
        if strings.contains(c.who, ".") do ext = ""
        
        ms := 1000
        if c.what != "" {
            if v, ok := strconv.parse_int(c.what); ok do ms = v
        }
        
        path := strings.concatenate({cfg.path_ambience, c.who, ext})
        defer delete(path)
        audio_fade_ambience(&state.audio, path, ms)
        s.ip += 1
    
    case .AmbienceStop:
        audio_stop_ambience(&state.audio)
        s.ip += 1
    
    case .Sfx:
        ext := ".ogg"
        if strings.contains(c.who, ".") do ext = ""
        
        path := strings.concatenate({cfg.path_sfx, c.who, ext})
        defer delete(path)
        audio_play_sfx(&state.audio, path)
        s.ip += 1
    
    case .Voice:
        ext := ".ogg"
        if strings.contains(c.who, ".") do ext = ""
        
        path := strings.concatenate({cfg.path_voice, c.who, ext})
        defer delete(path)
        audio_play_voice(&state.audio, path)
        s.ip += 1
    
    case .Volume:
        if c.who != "" && c.what != "" {
            if v, ok := strconv.parse_f32(c.what); ok {
                audio_set_volume(&state.audio, c.who, v)
                settings_set_volume(c.who, v)
                settings_save()
            }
        }
        s.ip += 1
        
    case .Title:
        window_set_title(&state.window, c.who)
        s.ip += 1
        
    case .Label:
        // Labels do nothing at runtime, skip them
        s.ip += 1
        
    case .Jump:
        if target, ok := s.labels[c.who]; ok {
            fmt.printf("[script] Jump to label: %s (IP: %d)\n", c.who, target)
            s.ip = target
        } else {
            fmt.eprintln("Error: Jump to non-existent label:", c.who)
            s.ip += 1
        }
    
    case .JumpFile:
        // Load a completely new script file
        // Clone the path BEFORE cleanup since c.who will be freed
        target_file := strings.clone(c.who)
        path := strings.concatenate({cfg.path_scripts, target_file})
        delete(target_file)
        fmt.printf("[script] Jumping to file: %s\n", path)
        
        // Capture current BG name before cleanup
        bg_name := ""
        if s.bg_path != "" do bg_name = strings.clone(s.bg_path)
        defer if bg_name != "" do delete(bg_name)
        
        // Cleanup old script
        script_cleanup(s)
        
        // Handle Scene transition
        if g_scenes.next != nil && g_scenes.next.name == path {
            scene_switch()
        } else {
            // No prefetch or wrong prefetch, sync load
            scene_system_cleanup() // Clear anything currently loaded
            g_scenes.current = scene_load_sync(path)
            
            if bg_name != "" {
                state.current_bg = scene_get_texture(bg_name)
            } else {
                state.current_bg = 0
            }
        }
        
        // Load new script
        if !script_load(s, path) {
            fmt.eprintln("Error: Failed to load script file:", path)
            delete(path)
            state.running = false
            return
        }
        delete(path)
        
        // Pre-set first background (first bg command in the file)
        pre_bg := ""
        for cmd in s.commands {
            if cmd.type == .Bg {
                pre_bg = cmd.who
                break
            }
        }
        if pre_bg != "" {
            tex := scene_get_texture(pre_bg)
            if tex != 0 do state.current_bg = tex
            state.loading_active = false
        } else {
            state.current_bg = 0
            state.loading_active = true
        }
        
        // Reset state for new script
        state.textbox.visible = false
        s.waiting = false
        // IP is already 0 from script_load

    case .Choice:
        if len(c.args) < 2 {
            fmt.eprintln("Error: choice command needs at least 2 arguments (text, label).")
            s.ip += 1
            return
        }
        
        fmt.printf("[script] Choice menu activated with %d options\n", len(c.args)/2)
        state.choice.active = true
        state.choice.selected = 0
        choice_clear(state)
        
        for i := 0; i < len(c.args); i += 2 {
            if i + 1 >= len(c.args) {
                break
            }
            append(&state.choice.options, Choice_Option{
                text  = c.args[i],
                label = c.args[i+1],
            })
        }
        s.waiting = true
        
    case .ChoiceAdd:
        text := interpolate_text(s, c.who)
        defer delete(text)
        
        fmt.printf("[script] Adding dynamic choice: %s -> %s\n", text, c.what)
        append(&state.choice.options, Choice_Option{
            text  = strings.clone(text),
            label = strings.clone(c.what),
        })
        s.ip += 1

    case .ChoiceShow:
        if len(state.choice.options) == 0 {
            fmt.eprintln("Warning: choice_show called with 0 options.")
            s.ip += 1
            return
        }
        fmt.printf("[script] Showing dynamic choice menu with %d options\n", len(state.choice.options))
        state.choice.active = true
        state.choice.selected = 0
        s.waiting = true

    case .Set:
        // Before we set the new value, if the old value was a string, we MUST delete it.
        if old, exists := s.variables[c.who]; exists {
            // Already exists: update value, key pointer stays the same (owned)
            if str, ok := old.(string); ok do delete(str)
            s.variables[c.who] = evaluate_complex_expression(s, c.what)
        } else {
            // New variable: clone the key so its memory is owned by the map
            s.variables[strings.clone(c.who)] = evaluate_complex_expression(s, c.what)
        }
        
        #partial switch v in s.variables[c.who] {
        case int:    fmt.printf("[script] Set variable: %s = %d\n", c.who, v)
        case string: fmt.printf("[script] Set variable: %s = \"%s\"\n", c.who, v)
        }
        s.ip += 1

    case .If:
        // Evaluate the expression in c.who
        result := evaluate_expression(s, c.who)
        
        if result {
            fmt.printf("[script] If (%s) is TRUE\n", c.who)
            // If it's a legacy jump, jump now
            if c.what != "" {
                if target, ok := s.labels[c.what]; ok {
                    s.ip = target
                } else {
                    fmt.eprintln("Error: if-jump to non-existent label:", c.what)
                    s.ip += 1
                }
            } else {
                // JS-style: proceed into the block
                s.ip += 1
            }
        } else {
            fmt.printf("[script] If (%s) is FALSE\n", c.who)
            // Skip to the jump target (Else or after BlockEnd)
            if c.jump > 0 {
                s.ip = c.jump
            } else {
                s.ip += 1 
            }
        }

    case .Else:
        // If we hit an ELSE naturally, it means the IF was TRUE and we finished its block.
        // We shouldn't even reach the ELSE command because the BlockEnd should have jumped past it.
        // But if we do (e.g. no BlockEnd jump or just logic falling through), we skip into it.
        s.ip += 1

    case .BlockStart:
        s.ip += 1

    case .BlockEnd:
        // If this BlockEnd has a jump, it's because it needs to skip an ELSE block
        if c.jump > 0 {
            fmt.printf("[script] BlockEnd skipping to: %d\n", c.jump)
            s.ip = c.jump
        } else {
            s.ip += 1
        }

    case .Say:
        if !state.textbox.force_hidden {
            state.textbox.visible = true
        } else {
            state.textbox.visible = false
        }
        state.textbox.speaker = c.who
        
        // Handle interpolation
        text := interpolate_text(s, c.what)
        fmt.printf("[script] Say %s: %s\n", c.who, text)
        if len(c.args) > 0 {
            if v, ok := strconv.parse_f32(c.args[0]); ok {
                textbox_set_text_with_speed(&state.textbox, text, v)
            } else {
                textbox_set_text(&state.textbox, text)
            }
        } else {
            textbox_set_text(&state.textbox, text)
        }
        s.waiting = true
        
    case .Wait:
        s.waiting = true
    
    case .Scene:
        // Load or switch to a scene
        script_path := strings.concatenate({cfg.path_scripts, c.who, ".vnef"})
        defer delete(script_path)
        scene := scene_load_sync(script_path)
        if g_scenes.current != nil {
            scene_cleanup(g_scenes.current)
        }
        g_scenes.current = scene
        fmt.println("[script] Activated scene:", c.who)
        s.ip += 1
    
    case .SceneNext:
        // Prefetch next scene in background
        if c.who == "none" {
            scene_prefetch("none")
        } else {
            script_path := strings.concatenate({cfg.path_scripts, c.who, ".vnef"})
            defer delete(script_path)
            scene_prefetch(script_path)
        }
        s.ip += 1
        
    case .Character:
        sprite := ""
        pos    := "center"
        z      := i32(0)

        has_with := false
        with_kind := Transition_Kind.Fade
        with_ms: f32 = -1
        float_specified := false
        float_active := ui_cfg.char_float_default
        float_px := ui_cfg.char_float_px
        float_speed := ui_cfg.char_float_speed

        // Parse args: sprite/pos, optional "with", optional "z"
        i := 0
        for i < len(c.args) {
            arg := c.args[i]
            lower := strings.to_lower(arg)
            defer delete(lower)
            if lower == "with" {
                has_with = true
                if i + 1 < len(c.args) {
                    name := strings.to_lower(c.args[i+1])
                    defer delete(name)
                    with_kind = bg_transition_kind_from_string(name)
                    if name != "fade" && name != "wipe" && name != "slide" && name != "dissolve" && name != "zoom" && name != "blur" && name != "flash" && name != "shake" && name != "none" {
                        fmt.eprintln("[script] Unknown transition:", name, "using fade")
                        with_kind = .Fade
                    }
                    i += 1
                }
                if i + 1 < len(c.args) {
                    if v, ok := strconv.parse_f32(c.args[i+1]); ok {
                        with_ms = v
                        i += 1
                    }
                }
            } else if lower == "z" && i + 1 < len(c.args) {
                val, ok := strconv.parse_int(c.args[i+1])
                if ok do z = i32(val)
                i += 1
            } else if lower == "float" {
                float_specified = true
                float_active = true
            } else if lower == "nofloat" || lower == "float=off" || lower == "float=false" {
                float_specified = true
                float_active = false
            } else if strings.has_prefix(lower, "float=") {
                float_specified = true
                val := strings.trim_space(lower[6:])
                if val == "off" || val == "false" || val == "0" {
                    float_active = false
                } else if v, ok := strconv.parse_f32(val); ok {
                    float_active = v > 0
                    if v >= 0 do float_px = v
                }
            } else if strings.has_prefix(lower, "float_px=") {
                float_specified = true
                if v, ok := strconv.parse_f32(strings.trim_space(lower[9:])); ok {
                    float_px = v
                    float_active = v > 0
                }
            } else if strings.has_prefix(lower, "float_speed=") {
                float_specified = true
                if v, ok := strconv.parse_f32(strings.trim_space(lower[12:])); ok {
                    float_speed = v
                    float_active = true
                }
            } else {
                if sprite == "" {
                    sprite = arg
                } else if pos == "center" {
                    pos = arg
                }
            }
            i += 1
        }

        if has_with {
            if with_ms < 0 && with_ms != -1 {
                with_ms = 0
            }
            if with_kind == .None {
                with_ms = 0
            }
            transition_set_override(with_kind, with_ms)
        }

        if c.what == "show" {
             character_show_ex(c.who, sprite, pos, z, float_specified, float_active, float_px, float_speed)
        } else if c.what == "hide" {
             character_hide(c.who)
        }
        s.ip += 1

    case .Save:
        _ = save_game_to_slot(state, s, c.who)
        s.ip += 1

    case .Load:
        path := strings.concatenate({cfg.path_saves, c.who, ".sthiti"})
        defer delete(path)
        if !load_game_from_path(state, s, path) {
            fmt.eprintln("[script] Failed to load save:", path)
            s.ip += 1
        }

    case .End:
        state.running = false
    }
}

save_game_to_slot :: proc(state: ^Game_State, s: ^Script, slot: string) -> bool {
    if state == nil || s == nil || slot == "" do return false
    // Ensure saves directory exists
    if !os.is_dir(cfg.path_saves) {
        os.make_directory(cfg.path_saves)
    }

    // Convert Script state to Sthiti state
    save := sthiti.save_state_init()
    defer sthiti.save_state_destroy(&save)

    save.script_path = strings.clone(s.path)
    save.script_ip   = i32(s.ip) // Save EXACT current index (don't skip)
    if s.bg_path != "" do save.bg_path = strings.clone(s.bg_path)
    save.bg_blur_base = state.bg_blur_base
    save.bg_blur_value = state.bg_blur_strength
    save.bg_blur_override = state.bg_blur_override_active

    // Save current textbox state
    save.textbox_vis = state.textbox.visible
    if state.textbox.speaker != "" do save.speaker = strings.clone(state.textbox.speaker)
    if state.textbox.text != ""    do save.textbox_text = strings.clone(state.textbox.text)

    // Save audio state (asset names)
    save.music_path = audio_get_music_asset_if_playing(&state.audio)
    save.ambience_path = audio_get_ambience_asset_if_playing(&state.audio)
    save.voice_path = audio_get_voice_asset_if_playing(&state.audio)
    save.sfx_paths = audio_get_sfx_assets_if_playing(&state.audio)

    // Save choice menu state
    save.choice_active = state.choice.active
    save.choice_selected = i32(state.choice.selected)
    for opt in state.choice.options {
        c_opt: sthiti.Choice_Option_Save
        c_opt.text  = strings.clone(opt.text)
        c_opt.label = strings.clone(opt.label)
        append(&save.choice_options, c_opt)
    }

    for k, v in s.variables {
        #partial switch val in v {
        case int:    save.variables[strings.clone(k)] = i32(val)
        case string: save.variables[strings.clone(k)] = strings.clone(val)
        }
    }

    // Save character states (v4)
    for _, char in g_characters {
        if char.visible {
            c_save: sthiti.Character_Save_State
            c_save.name        = strings.clone(char.name)
            c_save.sprite_path = strings.clone(char.sprite_path)
            c_save.pos_name    = strings.clone(char.pos_name)
            c_save.z           = char.z
            append(&save.characters, c_save)
        }
    }

    path := strings.concatenate({cfg.path_saves, slot, ".sthiti"})
    defer delete(path)
    ok := sthiti.save_to_file(path, save)
    if ok {
        fmt.printf("[script] Game saved successfully to %s\n", path)
    } else {
        fmt.eprintln("[script] Save failed:", path)
    }
    return ok
}

evaluate_complex_expression :: proc(s: ^Script, expr: string) -> Value {
    trimmed := strings.trim_space(expr)
    
    // String literal
    if len(trimmed) >= 2 && trimmed[0] == '"' && trimmed[len(trimmed)-1] == '"' {
        return strings.clone(trimmed[1:len(trimmed)-1])
    }
    
    // Arithmetic: check for +, -, *, /
    ops := []string{"+", "-", "*", "/"}
    for op in ops {
        if idx := strings.index(trimmed, op); idx != -1 {
            lhs_s := strings.trim_space(trimmed[:idx])
            rhs_s := strings.trim_space(trimmed[idx + 1:])
            
            lhs_v := evaluate_complex_expression(s, lhs_s)
            rhs_v := evaluate_complex_expression(s, rhs_s)
            
            // Note: If either is a string, we can't do math (except maybe + for concat later)
            lhs, ok_l := lhs_v.(int)
            rhs, ok_r := rhs_v.(int)
            
            // Clean up temporary strings if they were produced (unlikely in math but safe)
            if s_l, ok := lhs_v.(string); ok do delete(s_l)
            if s_r, ok := rhs_v.(string); ok do delete(s_r)
            
            if ok_l && ok_r {
                switch op {
                case "+": return lhs + rhs
                case "-": return lhs - rhs
                case "*": return lhs * rhs
                case "/": return rhs != 0 ? lhs / rhs : 0
                }
            }
        }
    }
    
    // Boolean literals
    if trimmed == "true"  do return 1
    if trimmed == "false" do return 0
    
    // Variable lookup
    if val, ok := s.variables[trimmed]; ok {
        #partial switch v in val {
        case int:    return v
        case string: return strings.clone(v)
        }
    }
    
    // Integer literal
    if v, ok := strconv.parse_int(trimmed); ok {
        return v
    }
    
    return 0
}

choice_clear :: proc(state: ^Game_State) {
    for opt in state.choice.options {
        delete(opt.text)
        delete(opt.label)
    }
    clear(&state.choice.options)
}

load_game_from_slot :: proc(state: ^Game_State, slot: string) -> bool {
    if state == nil || slot == "" do return false
    path := strings.concatenate({cfg.path_saves, slot, ".sthiti"})
    defer delete(path)
    return load_game_from_path(state, &state.script, path)
}

load_game_from_path :: proc(state: ^Game_State, s: ^Script, path: string) -> bool {
    save, ok := sthiti.load_from_file(path)
    if !ok do return false
    defer sthiti.save_state_destroy(&save)

    // Restore variables
    for k, v in save.variables {
        if old, exists := s.variables[k]; exists {
            if str, ok := old.(string); ok do delete(str)
            #partial switch val in v {
            case i32:    s.variables[k] = int(val)
            case string: s.variables[k] = strings.clone(val)
            }
        } else {
            key_clone := strings.clone(k)
            #partial switch val in v {
            case i32:    s.variables[key_clone] = int(val)
            case string: s.variables[key_clone] = strings.clone(val)
            }
        }
    }
    // If script file is different, reload it
    if save.script_path != "" && save.script_path != s.path {
        fmt.printf("[script] Load jumping to file: %s\n", save.script_path)
        script_load(s, save.script_path)
        scene_system_cleanup()
        scene_init()
        g_scenes.current = scene_load_sync(save.script_path)
    }

    s.ip = int(save.script_ip)

    // Restore visual environment
    if save.bg_path != "" {
        if s.bg_path != "" do delete(s.bg_path)
        s.bg_path = strings.clone(save.bg_path)

        tex := scene_get_texture(s.bg_path)
        if tex != 0 do state.current_bg = tex
    }
    state.bg_blur_base = save.bg_blur_base
    state.bg_blur_strength = save.bg_blur_value
    state.bg_blur_override_active = save.bg_blur_override
    bg_blur_set_strength(&state.bg_blur, save.bg_blur_value)

    // Restore textbox state
    state.textbox.visible = save.textbox_vis
    if state.textbox.speaker != "" do delete(state.textbox.speaker)
    state.textbox.speaker = strings.clone(save.speaker)
    textbox_set_text(&state.textbox, strings.clone(save.textbox_text))
    textbox_reveal_all(&state.textbox)

    // Restore character positions (v4)
    character_flush_all()
    for c in save.characters {
        character_show(c.name, c.sprite_path, c.pos_name, c.z)
    }

    // Restore audio state
    audio_stop_music(&state.audio)
    audio_stop_ambience(&state.audio)
    audio_stop_voice(&state.audio)
    audio_stop_sfx_all(&state.audio)

    if save.music_path != "" {
        mpath := strings.concatenate({cfg.path_music, save.music_path})
        defer delete(mpath)
        audio_play_music(&state.audio, mpath)
    }
    if save.ambience_path != "" {
        apath := strings.concatenate({cfg.path_ambience, save.ambience_path})
        defer delete(apath)
        audio_play_ambience(&state.audio, apath)
    }
    if save.voice_path != "" {
        vpath := strings.concatenate({cfg.path_voice, save.voice_path})
        defer delete(vpath)
        audio_play_voice(&state.audio, vpath)
    }
    for sfx in save.sfx_paths {
        spath := strings.concatenate({cfg.path_sfx, sfx})
        defer delete(spath)
        audio_play_sfx(&state.audio, spath)
    }

    // Restore choice state (menu does NOT auto-select)
    choice_clear(state)
    state.choice.selected = 0
    if len(save.choice_options) > 0 {
        for opt in save.choice_options {
            append(&state.choice.options, Choice_Option{
                text  = strings.clone(opt.text),
                label = strings.clone(opt.label),
            })
        }
        max_idx := len(state.choice.options) - 1
        sel := int(save.choice_selected)
        if sel < 0 do sel = 0
        if sel > max_idx do sel = max_idx
        state.choice.selected = sel
    }
    state.choice.active = save.choice_active && len(state.choice.options) > 0
    if state.choice.active {
        s.waiting = true
    }

    if s.ip < len(s.commands) {
        cmd := s.commands[s.ip]
        if cmd.type == .Say || cmd.type == .ChoiceShow {
            s.waiting = true
        }
    }

    fmt.printf("[script] Game loaded from %s\n", path)
    return true
}

script_advance :: proc(s: ^Script, state: ^Game_State) {
    if !s.waiting do return
    
    s.waiting = false
    s.ip += 1
    
    // If next command isn't a say, hide the box
    if s.ip >= len(s.commands) || s.commands[s.ip].type != .Say {
        state.textbox.visible = false
    }
}

evaluate_expression :: proc(s: ^Script, expr: string) -> bool {
    trimmed := strings.trim_space(expr)
    
    // Check for comparisons: ==, !=, >, <, >=, <=
    ops := []string{">=", "<=", "==", "!=", ">", "<"}
    for op in ops {
        if idx := strings.index(trimmed, op); idx != -1 {
            lhs_s := strings.trim_space(trimmed[:idx])
            rhs_s := strings.trim_space(trimmed[idx + len(op):])
            
            lhs_v := evaluate_complex_expression(s, lhs_s)
            rhs_v := evaluate_complex_expression(s, rhs_s)
            defer {
                if str, ok := lhs_v.(string); ok do delete(str)
                if str, ok := rhs_v.(string); ok do delete(str)
            }
            
            // String comparison
            if l_s, ok1 := lhs_v.(string); ok1 {
                if r_s, ok2 := rhs_v.(string); ok2 {
                    if op == "==" do return l_s == r_s
                    if op == "!=" do return l_s != r_s
                    return false
                }
            }
            
            // Int comparison
            if l_i, ok1 := lhs_v.(int); ok1 {
                if r_i, ok2 := rhs_v.(int); ok2 {
                    switch op {
                    case "==": return l_i == r_i
                    case "!=": return l_i != r_i
                    case ">":  return l_i > r_i
                    case "<":  return l_i < r_i
                    case ">=": return l_i >= r_i
                    case "<=": return l_i <= r_i
                    }
                }
            }
            return false
        }
    }
    
    // Fallback to literal number or bool variable
    val := evaluate_complex_expression(s, trimmed)
    defer if str, ok := val.(string); ok do delete(str)
    
    #partial switch v in val {
    case int: return v != 0
    case string: return len(v) > 0
    }
    
    return false
}

interpolate_text :: proc(s: ^Script, input: string) -> string {
    sb := strings.builder_make()
    
    i := 0
    for i < len(input) {
        if i + 1 < len(input) && input[i] == '$' && input[i+1] == '{' {
            end := strings.index(input[i:], "}")
            if end != -1 {
                var_name := input[i+2 : i+end]
                if val, ok := s.variables[var_name]; ok {
                    #partial switch v in val {
                    case int:    fmt.sbprintf(&sb, "%d", v)
                    case string: strings.write_string(&sb, v)
                    }
                } else {
                    strings.write_string(&sb, input[i : i+end+1])
                }
                i += end + 1
                continue
            }
        }
        strings.write_byte(&sb, input[i])
        i += 1
    }
    
    return strings.to_string(sb)
}
