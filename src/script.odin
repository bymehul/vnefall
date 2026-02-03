package vnefall

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
import "sthiti"

Command_Type :: enum {
    None,
    Bg,
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
        cmd.who = strings.clone(strings.trim(rest, "\""))
        return
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
        cmd.who  = strings.clone(strings.trim_space(rest[:q1]))
        
        q2_part := rest[q1+1:]
        q2 := strings.index(q2_part, "\"")
        if q2 < 0 {
            cmd.what = strings.clone(q2_part)
        } else {
            cmd.what = strings.clone(q2_part[:q2])
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
    case .Bg:
        if s.bg_path != "" do delete(s.bg_path)
        s.bg_path = strings.clone(c.who)
        
        tex := scene_get_texture(c.who)
        if tex != 0 do state.current_bg = tex
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
        state.textbox.visible = true
        state.textbox.speaker = c.who
        
        // Handle interpolation
        text := interpolate_text(s, c.what)
        fmt.printf("[script] Say %s: %s\n", c.who, text)
        delete(state.textbox.text)
        state.textbox.text = text 
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
        if c.what == "show" {
             sprite := ""
             pos    := "center"
             z      := i32(0)
             
             if len(c.args) > 0 do sprite = c.args[0]
             if len(c.args) > 1 do pos    = c.args[1]
             
             // Check for 'z' in arguments
             for i := 0; i < len(c.args); i += 1 {
                 if c.args[i] == "z" && i + 1 < len(c.args) {
                     val, ok := strconv.parse_int(c.args[i+1])
                     if ok do z = i32(val)
                     break
                 }
             }
             
             character_show(c.who, sprite, pos, z)
        } else if c.what == "hide" {
             character_hide(c.who)
        }
        s.ip += 1

    case .Save:
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
        
        
        path := strings.concatenate({cfg.path_saves, c.who, ".sthiti"})
        defer delete(path)
        sthiti.save_to_file(path, save)
        fmt.printf("[script] Game saved successfully to %s\n", path)
        s.ip += 1

    case .Load:
        path := strings.concatenate({cfg.path_saves, c.who, ".sthiti"})
        defer delete(path)
        
        save, ok := sthiti.load_from_file(path)
        if ok {
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
            // If script file is different, we need to reload it
            if save.script_path != "" && save.script_path != s.path {
                fmt.printf("[script] Load jumping to file: %s\n", save.script_path)
                script_load(s, save.script_path)
                
                // Reload scene system for this script
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
            
            // Restore textbox state
            state.textbox.visible = save.textbox_vis
            if state.textbox.speaker != "" do delete(state.textbox.speaker)
            state.textbox.speaker = strings.clone(save.speaker)
            
            if state.textbox.text != "" do delete(state.textbox.text)
            state.textbox.text = strings.clone(save.textbox_text)
            
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
            
            // If we loaded onto a 'waiting' command (like say), we should be waiting
            // This prevents the next execute frame from immediately skipping it
            if s.ip < len(s.commands) {
                cmd := s.commands[s.ip]
                if cmd.type == .Say || cmd.type == .ChoiceShow {
                    s.waiting = true
                }
            }
            
            fmt.printf("[script] Game loaded from %s\n", path)
        } else {
            fmt.eprintln("[script] Failed to load save:", path)
            s.ip += 1
        }

    case .End:
        state.running = false
    }
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
