package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:math"
import "core:c"
import sdl2 "vendor:sdl2"
import gl "vendor:OpenGL"
import stbtt "vendor:stb/truetype"
import vneui "vneui:src"

// Run with:
//   odin run vneui/demo_window -collection:vneui=./vneui

WINDOW_W :: 1280
WINDOW_H :: 720

FONT_SIZE       :: 32
FONT_ATLAS_SIZE :: 512
FONT_FIRST_CHAR :: 32
FONT_NUM_CHARS  :: 96

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

Window :: struct {
    handle:     ^sdl2.Window,
    gl_context: sdl2.GLContext,
    width, height: i32,
}

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

Font :: struct {
    texture:   u32,
    char_data: [FONT_NUM_CHARS]stbtt.bakedchar,
    loaded:    bool,
    ascent:    f32,
    descent:   f32,
    line_gap:  f32,
}

Demo_State :: struct {
    master_vol: f32,
    music_vol:  f32,
    text_speed: f32,
    auto_advance: bool,
    skip_unread: bool,
    save_state: vneui.UI_Save_List_State,
    transition: vneui.UI_Transition,
    toasts_seeded: bool,
    show_confirm: bool,
    player_name: string,
    name_input: vneui.UI_Text_Input_State,
    difficulty_index: int,
    difficulty_select: vneui.UI_Select_State,
    main_scroll: vneui.UI_Scroll_State,
}

g_font: Font

main :: proc() {
    ctx: vneui.UI_Context
    vneui.ui_init(&ctx)
    defer vneui.ui_shutdown(&ctx)

    ctx.measure_text = measure_text

    win: Window
    if !window_create(&win, "VNEUI Demo Window", WINDOW_W, WINDOW_H) do return
    defer window_destroy(&win)
    sdl2.StartTextInput()
    defer sdl2.StopTextInput()

    renderer: Renderer
    if !renderer_init(&renderer) do return
    defer renderer_cleanup(&renderer)

    if !font_load("assets/fonts/default.ttf") {
        fmt.eprintln("Warning: Could not load default font.")
    }
    defer font_cleanup()

    theme := vneui.ui_theme_default(0, 18)
    theme.panel_color = vneui.ui_color_rgba8(30, 32, 38, 255)
    theme.accent_color = vneui.ui_color_rgba8(100, 190, 255, 255)
    theme.shadow_enabled = true
    theme.text_line_height = 22

    accent_style := vneui.ui_style_from_theme(theme)
    accent_style.panel_color = vneui.ui_color_rgba8(24, 26, 32, 255)
    accent_style.accent_color = vneui.ui_color_rgba8(255, 168, 88, 255)
    accent_style.text_color = vneui.ui_color_rgba8(250, 240, 220, 255)
    accent_style.border_color = vneui.ui_color_rgba8(16, 16, 20, 255)
    accent_style.border_width = 1.5
    accent_style.corner_radius = 10
    accent_style.shadow_offset = vneui.Vec2{0, 3}

    state := Demo_State{
        master_vol = 80,
        music_vol = 65,
        text_speed = 5,
        auto_advance = false,
        skip_unread = true,
        save_state = vneui.UI_Save_List_State{scroll_y = 0, selected_index = 1},
        show_confirm = true,
        player_name = strings.clone("Alex"),
        difficulty_index = 1,
    }
    defer delete(state.player_name)

    last_ticks := sdl2.GetTicks()
    running := true
    for running {
        input, text_input := poll_input(&running, &win)
        now := sdl2.GetTicks()
        dt := f32(now - last_ticks) / 1000.0
        last_ticks = now
        input.delta_time = dt
        input.text_input = text_input

        vneui.ui_begin_frame(&ctx, input, theme)
        build_demo(&ctx, &state, theme, accent_style, f32(win.width), f32(win.height))
        commands := vneui.ui_end_frame(&ctx)
        if text_input != "" {
            delete(text_input)
        }

        renderer_begin(&renderer, win.width, win.height)
        render_commands(&renderer, commands, f32(win.height))
        renderer_end(&renderer, &win)
    }
}

poll_input :: proc(running: ^bool, win: ^Window) -> (vneui.UI_Input, string) {
    input := vneui.UI_Input{}
    input.scroll_y = 0

    mouse_pressed := false
    mouse_released := false
    scroll: f32 = 0
    sb := strings.builder_make()
    defer strings.builder_destroy(&sb)

    ev: sdl2.Event
    for sdl2.PollEvent(&ev) {
        #partial switch ev.type {
        case .QUIT:
            running^ = false
        case .MOUSEBUTTONDOWN:
            if ev.button.button == sdl2.BUTTON_LEFT {
                mouse_pressed = true
            }
        case .MOUSEBUTTONUP:
            if ev.button.button == sdl2.BUTTON_LEFT {
                mouse_released = true
            }
        case .KEYDOWN:
            if ev.key.repeat != 0 do break
            sym := ev.key.keysym.sym
            mod := ev.key.keysym.mod
            shift := (.LSHIFT in mod) || (.RSHIFT in mod)
            #partial switch sym {
            case .TAB:
                if shift {
                    input.nav_prev = true
                } else {
                    input.nav_next = true
                }
            case .RETURN, .KP_ENTER:
                input.key_enter = true
                input.nav_activate = true
            case .SPACE:
                input.nav_activate = true
            case .ESCAPE:
                input.nav_cancel = true
            case .BACKSPACE:
                input.key_backspace = true
            case .DELETE:
                input.key_delete = true
            case .LEFT:
                input.key_left = true
            case .RIGHT:
                input.key_right = true
            case .UP:
                input.key_up = true
            case .DOWN:
                input.key_down = true
            case .HOME:
                input.key_home = true
            case .END:
                input.key_end = true
            }
        case .MOUSEWHEEL:
            scroll = f32(ev.wheel.y)
        case .TEXTINPUT:
            text := string(cstring(&ev.text.text[0]))
            if text != "" {
                strings.write_string(&sb, text)
            }
        }
    }

    mx, my: i32
    buttons := sdl2.GetMouseState(&mx, &my)
    input.mouse_pos = vneui.Vec2{f32(mx), f32(my)}
    input.mouse_down = (buttons & sdl2.BUTTON_LMASK) != 0
    input.mouse_pressed = mouse_pressed
    input.mouse_released = mouse_released
    input.scroll_y = scroll
    text_input := ""
    if strings.builder_len(sb) > 0 {
        text_input = strings.clone(strings.to_string(sb))
    }
    return input, text_input
}

calc_menu_height :: proc(theme: vneui.UI_Theme, layout: vneui.UI_Menu_Layout, item_count: int, has_title: bool) -> f32 {
    lay := layout
    if lay.padding <= 0 do lay.padding = theme.padding
    if lay.gap <= 0 do lay.gap = theme.padding * 0.6
    if lay.button_h <= 0 do lay.button_h = theme.text_line_height + theme.padding * 1.2

    total := lay.padding * 2 + f32(item_count) * lay.button_h
    total_items := item_count

    if has_title {
        total += theme.text_line_height + theme.padding * 0.5
        total += theme.padding * 0.6
        total_items += 2
    }

    if total_items > 1 {
        total += f32(total_items-1) * lay.gap
    }
    return total
}

calc_preferences_height :: proc(theme: vneui.UI_Theme, layout: vneui.UI_Preferences_Layout, menu: vneui.UI_Preferences_Menu) -> f32 {
    lay := layout
    if lay.padding <= 0 do lay.padding = theme.padding
    if lay.gap <= 0 do lay.gap = theme.padding * 0.6
    if lay.row_h <= 0 do lay.row_h = theme.text_line_height + theme.padding * 1.2
    if lay.button_h <= 0 do lay.button_h = theme.text_line_height + theme.padding * 1.1

    total := lay.padding * 2
    items := 0

    if menu.title != "" {
        total += theme.text_line_height + theme.padding * 0.5
        total += theme.padding * 0.6
        items += 2
    }

    for i := 0; i < len(menu.sections); i += 1 {
        section := menu.sections[i]
        if i > 0 {
            total += theme.padding * 0.6
            items += 1
        }
        if section.title != "" {
            total += theme.text_line_height + theme.padding * 0.4
            items += 1
        }
        rows := len(section.sliders) + len(section.toggles)
        if rows > 0 {
            total += f32(rows) * lay.row_h
            items += rows
        }
    }

    if menu.show_back || menu.show_reset {
        total += theme.padding * 0.4
        total += lay.button_h
        items += 1
    }

    if items > 1 {
        total += f32(items-1) * lay.gap
    }
    return total
}

calc_inputs_height :: proc(theme: vneui.UI_Theme) -> f32 {
    gap := theme.padding * 0.6
    title_h := theme.text_line_height + theme.padding * 0.4
    sep_h := theme.padding * 0.5
    label_h := theme.text_line_height + theme.padding * 0.2
    row_h := theme.text_line_height + theme.padding * 1.1
    nine_h := theme.text_line_height * 2.2
    space := theme.padding * 0.3

    total := theme.padding * 2
    total += title_h + sep_h
    total += label_h + row_h
    total += label_h + row_h
    total += label_h + nine_h
    total += space * 2
    items := 8
    if items > 1 {
        total += f32(items-1) * gap
    }
    return total
}

calc_save_list_height :: proc(theme: vneui.UI_Theme, layout: vneui.UI_Save_List_Layout, visible_slots: int, show_back: bool) -> f32 {
    lay := layout
    if lay.padding <= 0 do lay.padding = theme.padding
    if lay.gap <= 0 do lay.gap = theme.padding * 0.6
    if lay.slot_h <= 0 do lay.slot_h = theme.text_line_height * 2.4 + theme.padding * 1.2
    if lay.button_h <= 0 do lay.button_h = theme.text_line_height + theme.padding * 1.1

    title_h := theme.text_line_height + theme.padding * 1.1
    sep_h := theme.padding * 0.6
    list_h := f32(visible_slots) * lay.slot_h
    if visible_slots > 1 {
        list_h += f32(visible_slots-1) * lay.gap
    }

    total := lay.padding * 2 + title_h + sep_h + list_h
    items := 3
    if show_back {
        total += lay.button_h
        items += 1
    }
    if items > 1 {
        total += f32(items-1) * lay.gap
    }
    return total
}

calc_advanced_height :: proc(theme: vneui.UI_Theme) -> f32 {
    gap := theme.padding * 0.6
    title_h := theme.text_line_height + theme.padding * 0.4
    sep_h := theme.padding * 0.5
    label_h := theme.text_line_height + theme.padding * 0.2
    transition_h := theme.text_line_height * 2.4
    desc_h := theme.text_line_height * 2.2
    space := theme.padding * 0.4

    total := theme.padding * 2
    total += title_h + sep_h + label_h + transition_h + desc_h
    total += space
    items := 5
    if items > 1 {
        total += f32(items-1) * gap
    }
    return total
}

build_demo :: proc(ctx: ^vneui.UI_Context, state: ^Demo_State, theme: vneui.UI_Theme, accent_style: vneui.UI_Style, view_w, view_h: f32) {
    margin := f32(28)
    root := vneui.Rect{margin, margin, view_w - margin*2, view_h - margin*2}

    modal_w := root.w * 0.44
    modal_h := root.h * 0.28
    modal_rect := vneui.Rect{
        x = root.x + (root.w - modal_w) * 0.5,
        y = root.y + (root.h - modal_h) * 0.5,
        w = modal_w,
        h = modal_h,
    }

    if !state.toasts_seeded || len(ctx.toasts) == 0 {
        vneui.ui_toast_push(ctx, "Settings saved successfully.", 2.4, .Success)
        vneui.ui_toast_push(ctx, "New entry unlocked in the gallery.", 2.6, .Info)
        vneui.ui_toast_push(ctx, "Connection lost. Retrying...", 2.2, .Warning)
        state.toasts_seeded = true
    }

    show_modal := state.show_confirm
    if show_modal {
        vneui.ui_input_scope_begin(ctx, modal_rect)
    }

    root_pad := theme.padding + 2
    root_gap := theme.padding * 0.7
    vneui.ui_panel_begin(ctx, root, .Column, root_pad, root_gap)

    title_h := theme.text_line_height + theme.padding * 0.6
    sep_h := theme.padding * 0.6
    desc_h := theme.text_line_height * 2.2

    vneui.ui_label_layout(ctx, "VNEUI Demo - Menus + Overlays", 0, title_h)
    vneui.ui_separator_layout(ctx, 2, 0, sep_h)
    vneui.ui_label_wrap_layout(ctx, "This demo exercises the roadmap features: menu helpers, preferences, save/load UI, confirm dialogs, toasts, tooltips, and transitions.", 0, desc_h)

    content_h := root.h - root_pad*2 - title_h - sep_h - desc_h - root_gap*3
    if content_h < theme.text_line_height * 8 do content_h = theme.text_line_height * 8
    content_rect := vneui.ui_layout_next(ctx, 0, content_h)

    main_labels := vneui.UI_Main_Menu_Labels{
        start = "Start",
        continue_label = "Continue",
        load = "Load",
        preferences = "Preferences",
        quit = "Quit",
    }
    main_cfg := vneui.UI_Main_Menu_Config{
        title = "Main Menu",
        show_continue = true,
        show_load = true,
        show_quit = true,
        labels = main_labels,
    }

    audio_sliders := []vneui.UI_Pref_Slider_Item{
        {label = "Master", value = &state.master_vol, min = 0, max = 100, format = "%.0f%%"},
        {label = "Music", value = &state.music_vol, min = 0, max = 100, format = "%.0f%%"},
    }
    text_sliders := []vneui.UI_Pref_Slider_Item{
        {label = "Speed", value = &state.text_speed, min = 1, max = 10, format = "%.0f"},
    }
    text_toggles := []vneui.UI_Pref_Toggle_Item{
        {label = "Auto-Advance", value = &state.auto_advance},
        {label = "Skip Unread", value = &state.skip_unread},
    }
    prefs_sections := []vneui.UI_Preferences_Section{
        {title = "Audio", sliders = audio_sliders, toggles = nil},
        {title = "Text", sliders = text_sliders, toggles = text_toggles},
    }
    prefs_menu := vneui.UI_Preferences_Menu{
        title = "Preferences",
        sections = prefs_sections,
        show_back = true,
        show_reset = true,
    }

    save_cfg := vneui.UI_Save_List_Config{
        title = "Save / Load",
        mode = .Load,
        show_back = true,
        back_label = "Back",
    }

    menu_layout := vneui.ui_menu_layout_default(ctx)
    prefs_layout := vneui.ui_preferences_layout_default(ctx)
    prefs_layout.label_w = 0
    save_layout := vneui.ui_save_list_layout_default(ctx)

    menu_items := 2
    if main_cfg.show_continue do menu_items += 1
    if main_cfg.show_load do menu_items += 1
    if main_cfg.show_quit do menu_items += 1
    menu_h := calc_menu_height(theme, menu_layout, menu_items, main_cfg.title != "")
    prefs_h := calc_preferences_height(theme, prefs_layout, prefs_menu)
    inputs_h := calc_inputs_height(theme)

    visible_slots := 3
    save_h := calc_save_list_height(theme, save_layout, visible_slots, save_cfg.show_back)
    adv_h := calc_advanced_height(theme)

    left_pad := theme.padding
    left_gap := theme.padding * 0.7
    right_pad := theme.padding
    right_gap := theme.padding * 0.7

    left_total_h := left_pad*2 + menu_h + prefs_h + inputs_h + left_gap*2
    right_total_h := right_pad*2 + save_h + adv_h + right_gap
    content_row_h := left_total_h
    if right_total_h > content_row_h do content_row_h = right_total_h

    scroll_opts := vneui.ui_scroll_options_default()
    scroll_opts.scrollbar_thickness = 8
    scroll_opts.scrollbar_min_size = 32
    vneui.ui_scroll_begin_state(ctx, content_rect, &state.main_scroll, 0, root_gap)

    row_rect := vneui.ui_layout_next(ctx, 0, content_row_h)
    vneui.ui_layout_begin(ctx, row_rect, .Row, 0, root_gap)
    col_w := (row_rect.w - root_gap) * 0.5
    left_col := vneui.ui_layout_next(ctx, col_w, row_rect.h)
    right_col := vneui.ui_layout_next(ctx, col_w, row_rect.h)
    vneui.ui_layout_end(ctx)

    vneui.ui_layout_begin(ctx, left_col, .Column, left_pad, left_gap)
    menu_rect := vneui.ui_layout_next(ctx, 0, menu_h)
    prefs_rect := vneui.ui_layout_next(ctx, 0, prefs_h)
    inputs_rect := vneui.ui_layout_next(ctx, 0, inputs_h)
    vneui.ui_layout_end(ctx)
    vneui.ui_panel(ctx, menu_rect)
    _ = vneui.ui_main_menu_layout(ctx, menu_rect, main_cfg, menu_layout)

    vneui.ui_panel(ctx, prefs_rect)
    _ = vneui.ui_preferences_menu(ctx, prefs_rect, prefs_menu, prefs_layout)

    vneui.ui_panel_begin(ctx, inputs_rect, .Column, theme.padding, theme.padding * 0.6)
    vneui.ui_label_layout(ctx, "Inputs", 0, theme.text_line_height + theme.padding * 0.4)
    vneui.ui_separator_layout(ctx, 2, 0, theme.padding * 0.5)

    vneui.ui_label_layout(ctx, "Player Name", 0, theme.text_line_height + theme.padding * 0.2)
    input_rect := vneui.ui_layout_next(ctx, 0, theme.text_line_height + theme.padding * 1.1)
    input_opts := vneui.UI_Text_Input_Options{placeholder = "Enter name"}
    _ , _ = vneui.ui_text_input_style(ctx, input_rect, "player_name", &state.player_name, &state.name_input, accent_style, input_opts)

    vneui.ui_layout_space(ctx, theme.padding * 0.3)
    vneui.ui_label_layout(ctx, "Nine-slice (debug)", 0, theme.text_line_height + theme.padding * 0.2)
    nine_rect := vneui.ui_layout_next(ctx, 0, theme.text_line_height * 2.2)
    vneui.ui_image_nine_slice(ctx, nine_rect, -1, 32, 32, vneui.ui_insets(8, 8, 8, 8), vneui.ui_color_scale(theme.accent_color, 0.9))

    if state.difficulty_select.open {
        dim := vneui.ui_color(0, 0, 0, 0.18)
        vneui.ui_push_rect(ctx, inputs_rect, dim)
    }

    vneui.ui_layout_space(ctx, theme.padding * 0.3)
    vneui.ui_label_layout(ctx, "Difficulty", 0, theme.text_line_height + theme.padding * 0.2)
    select_rect := vneui.ui_layout_next(ctx, 0, theme.text_line_height + theme.padding * 1.1)
    difficulties := []string{"Easy", "Normal", "Hard"}
    state.difficulty_index, _ = vneui.ui_select(ctx, select_rect, "difficulty", difficulties, state.difficulty_index, &state.difficulty_select)

    vneui.ui_panel_end(ctx)

    vneui.ui_layout_begin(ctx, right_col, .Column, right_pad, right_gap)
    save_rect := vneui.ui_layout_next(ctx, 0, save_h)
    adv_rect := vneui.ui_layout_next(ctx, 0, adv_h)
    vneui.ui_layout_end(ctx)

    save_slots := []vneui.UI_Save_Slot{
        {
            id = vneui.ui_id_from_string("slot_1"),
            title = "Prologue - Rainy Night",
            subtitle = "Street 7",
            timestamp = "00:12:45",
            thumbnail_id = 0,
            disabled = false,
        },
        {
            id = vneui.ui_id_from_string("slot_2"),
            title = "Chapter 1 - Rooftop",
            subtitle = "Cityline",
            timestamp = "00:48:02",
            thumbnail_id = 0,
            disabled = false,
        },
        {
            id = vneui.ui_id_from_string("slot_3"),
            title = "Chapter 2 - Silent Room",
            subtitle = "Dormitory",
            timestamp = "01:15:10",
            thumbnail_id = 0,
            disabled = true,
        },
        {
            id = vneui.ui_id_from_string("slot_4"),
            title = "Chapter 3 - Coastal Dawn",
            subtitle = "Seaside",
            timestamp = "01:48:34",
            thumbnail_id = 0,
            disabled = false,
        },
        {
            id = vneui.ui_id_from_string("slot_5"),
            title = "Interlude - City Lights",
            subtitle = "Downtown",
            timestamp = "02:05:12",
            thumbnail_id = 0,
            disabled = false,
        },
        {
            id = vneui.ui_id_from_string("slot_6"),
            title = "Chapter 4 - Rain Echoes",
            subtitle = "Alleyway",
            timestamp = "02:42:09",
            thumbnail_id = 0,
            disabled = false,
        },
        {
            id = vneui.ui_id_from_string("slot_7"),
            title = "Chapter 5 - Sunlit Room",
            subtitle = "Apartment 12B",
            timestamp = "03:15:44",
            thumbnail_id = 0,
            disabled = false,
        },
        {
            id = vneui.ui_id_from_string("slot_8"),
            title = "Chapter 6 - Evening Market",
            subtitle = "West Street",
            timestamp = "03:40:08",
            thumbnail_id = 0,
            disabled = false,
        },
    }
    vneui.ui_panel(ctx, save_rect)
    _ = vneui.ui_save_list_menu(ctx, save_rect, save_slots, save_cfg, save_layout, &state.save_state)

    vneui.ui_panel_begin(ctx, adv_rect, .Column, theme.padding, theme.padding * 0.6)
    vneui.ui_label_layout(ctx, "Advanced UI", 0, theme.text_line_height + theme.padding * 0.4)
    vneui.ui_separator_layout(ctx, 2, 0, theme.padding * 0.5)

    vneui.ui_label_layout(ctx, "Transition Preview", 0, theme.text_line_height + theme.padding * 0.2)
    transition_rect := vneui.ui_layout_next(ctx, 0, theme.text_line_height * 2.4)
    vneui.ui_panel_color(ctx, transition_rect, vneui.ui_color_scale(theme.panel_color, 0.92))

    if !state.transition.active {
        vneui.ui_transition_begin(&state.transition, .Slide_Right, 1.2, false)
    }
    _ = vneui.ui_transition_update(&state.transition, ctx.input.delta_time)

    card_pad := theme.padding * 0.5
    card_rect := vneui.Rect{
        x = transition_rect.x + card_pad,
        y = transition_rect.y + card_pad,
        w = transition_rect.w * 0.48,
        h = transition_rect.h - card_pad*2,
    }
    card_rect = vneui.ui_transition_apply_rect(card_rect, state.transition.kind, state.transition.progress)
    vneui.ui_panel_color(ctx, card_rect, vneui.ui_color_scale(theme.accent_color, 1.0))
    vneui.ui_push_text_aligned(ctx, card_rect, "Slide", theme.font_id, theme.font_size * 0.9, theme.text_color, .Center, .Center)
    vneui.ui_transition_draw_fade(ctx, transition_rect, vneui.ui_color(0, 0, 0, 0.25), 1 - state.transition.progress)

    vneui.ui_layout_space(ctx, theme.padding * 0.4)
    vneui.ui_label_wrap_layout(ctx, "Modal dialogs trap input. Tooltips and toasts are layered above the main layout.", 0, theme.text_line_height * 2.2)
    vneui.ui_panel_end(ctx)

    state.main_scroll.scroll_y = vneui.ui_scroll_end_state(ctx, content_rect, &state.main_scroll, scroll_opts)

    vneui.ui_panel_end(ctx)

    if show_modal {
        confirm_cfg := vneui.UI_Confirm_Config{
            title = "Overwrite Slot 3?",
            message = "This modal blocks background input until you confirm or cancel. The tooltip is anchored near the cursor.",
            confirm_label = "Overwrite",
            cancel_label = "Cancel",
            overlay_alpha = 0.5,
        }
        result := vneui.ui_confirm_dialog(ctx, root, modal_rect, confirm_cfg, accent_style)
        if result != .None {
            state.show_confirm = false
        }

        vneui.ui_tooltip_register(ctx, modal_rect, "Tooltip: modal input is trapped to this dialog.")
        vneui.ui_tooltip_draw(ctx, root, accent_style, root.w * 0.38)

        vneui.ui_input_scope_end(ctx)
    }

    toast_layout := vneui.UI_Toast_Layout{
        padding = theme.padding * 0.8,
        gap = theme.padding * 0.5,
        max_width = root.w * 0.38,
        anchor_h = .End,
        anchor_v = .Start,
    }
    vneui.ui_toasts_draw(ctx, root, accent_style, toast_layout)
}

render_commands :: proc(r: ^Renderer, commands: []vneui.Draw_Command, view_h: f32) {
    scissor_stack := make([dynamic]vneui.Rect)
    defer delete(scissor_stack)

    for cmd in commands {
        switch cmd.kind {
        case .Rect:
            renderer_draw_rect(r, cmd.rect, color_to_rgba(cmd.color))
        case .Rounded_Rect:
            renderer_draw_rect(r, cmd.rect, color_to_rgba(cmd.color))
        case .Line:
            renderer_draw_line(r, cmd.p0, cmd.p1, cmd.thickness, color_to_rgba(cmd.color))
        case .Text:
            renderer_draw_text_aligned(r, cmd.rect, cmd.text, cmd.font_size, color_to_rgba(cmd.color), cmd.align_h, cmd.align_v)
        case .Image:
            if cmd.image_id < 0 {
                renderer_draw_rect(r, cmd.rect, color_to_rgba(cmd.color))
            } else {
                renderer_draw_image_placeholder(r, cmd.rect)
            }
        case .Scissor_Push:
            scissor_push(&scissor_stack, cmd.rect, view_h)
        case .Scissor_Pop:
            scissor_pop(&scissor_stack, view_h)
        }
    }

    if len(scissor_stack) == 0 {
        gl.Disable(gl.SCISSOR_TEST)
    }
}

color_to_rgba :: proc(c: vneui.Color) -> [4]f32 {
    return {c.r, c.g, c.b, c.a}
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
}

renderer_begin :: proc(r: ^Renderer, w, h: i32) {
    r.width = f32(w)
    r.height = f32(h)

    gl.Viewport(0, 0, w, h)
    gl.ClearColor(0.05, 0.05, 0.08, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    gl.UseProgram(r.shader)
    proj := ortho_matrix(0, r.width, r.height, 0)
    gl.UniformMatrix4fv(r.u_proj, 1, false, &proj[0, 0])
}

renderer_end :: proc(r: ^Renderer, w: ^Window) {
    window_swap(w)
}

renderer_draw_rect :: proc(r: ^Renderer, rect: vneui.Rect, color: [4]f32) {
    x := rect.x
    y := rect.y
    w := rect.w
    h := rect.h
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

renderer_draw_quad :: proc(r: ^Renderer, p0, p1, p2, p3: vneui.Vec2, color: [4]f32) {
    verts := [6][4]f32{
        {p0.x, p0.y, 0, 0},
        {p1.x, p1.y, 0, 0},
        {p2.x, p2.y, 0, 0},
        {p0.x, p0.y, 0, 0},
        {p2.x, p2.y, 0, 0},
        {p3.x, p3.y, 0, 0},
    }

    gl.BindVertexArray(r.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, r.vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(verts), &verts)
    gl.Uniform1i(r.u_use_tex, 0)
    gl.Uniform4f(r.u_color, color[0], color[1], color[2], color[3])
    gl.DrawArrays(gl.TRIANGLES, 0, 6)
}

renderer_draw_line :: proc(r: ^Renderer, p0, p1: vneui.Vec2, thickness: f32, color: [4]f32) {
    dx := p1.x - p0.x
    dy := p1.y - p0.y
    len := math.sqrt(dx*dx + dy*dy)
    if len <= 0 do return
    t := thickness
    if t <= 0 do t = 1
    nx := -dy / len
    ny := dx / len
    half := t * 0.5

    a := vneui.Vec2{p0.x + nx*half, p0.y + ny*half}
    b := vneui.Vec2{p1.x + nx*half, p1.y + ny*half}
    c := vneui.Vec2{p1.x - nx*half, p1.y - ny*half}
    d := vneui.Vec2{p0.x - nx*half, p0.y - ny*half}
    renderer_draw_quad(r, a, b, c, d, color)
}

renderer_draw_rect_outline :: proc(r: ^Renderer, rect: vneui.Rect, thickness: f32, color: [4]f32) {
    t := thickness
    if t <= 0 do t = 1
    top := vneui.Rect{rect.x, rect.y, rect.w, t}
    bottom := vneui.Rect{rect.x, rect.y + rect.h - t, rect.w, t}
    left := vneui.Rect{rect.x, rect.y + t, t, rect.h - t*2}
    right := vneui.Rect{rect.x + rect.w - t, rect.y + t, t, rect.h - t*2}
    renderer_draw_rect(r, top, color)
    renderer_draw_rect(r, bottom, color)
    renderer_draw_rect(r, left, color)
    renderer_draw_rect(r, right, color)
}

renderer_draw_image_placeholder :: proc(r: ^Renderer, rect: vneui.Rect) {
    outline: [4]f32 = {0.42, 0.44, 0.48, 1.0}
    renderer_draw_rect_outline(r, rect, 1, outline)
    renderer_draw_line(r, vneui.Vec2{rect.x, rect.y}, vneui.Vec2{rect.x + rect.w, rect.y + rect.h}, 1, outline)
    renderer_draw_line(r, vneui.Vec2{rect.x + rect.w, rect.y}, vneui.Vec2{rect.x, rect.y + rect.h}, 1, outline)
}

renderer_draw_text_aligned :: proc(r: ^Renderer, rect: vneui.Rect, text: string, font_size: f32, color: [4]f32, align_h, align_v: vneui.UI_Align) {
    if text == "" do return
    scale := font_size / f32(FONT_SIZE)
    text_w := font_text_width(text) * scale

    x := rect.x
    switch align_h {
    case .Center:
        x = rect.x + (rect.w - text_w) * 0.5
    case .End:
        x = rect.x + rect.w - text_w
    case .Start:
        x = rect.x
    }

    ascent := font_size * 0.8
    descent := -font_size * 0.2
    if g_font.loaded && (g_font.ascent != 0 || g_font.descent != 0) {
        ascent = g_font.ascent * scale
        descent = g_font.descent * scale
    }
    text_h := ascent - descent

    y := rect.y + ascent
    switch align_v {
    case .Center:
        y = rect.y + (rect.h - text_h) * 0.5 + ascent
    case .End:
        y = rect.y + rect.h - descent
    case .Start:
        y = rect.y + ascent
    }

    renderer_draw_text(r, text, x, y, font_size, color)
}

renderer_draw_text :: proc(r: ^Renderer, text: string, x, y: f32, font_size: f32, color: [4]f32) {
    if !g_font.loaded do return
    scale := font_size / f32(FONT_SIZE)

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, g_font.texture)
    gl.Uniform1i(r.u_tex, 0)
    gl.Uniform1i(r.u_use_tex, 1)
    gl.Uniform1i(r.u_is_font, 1)
    gl.Uniform4f(r.u_color, color[0], color[1], color[2], color[3])

    cx := x
    cy := y
    for char in text {
        if char < FONT_FIRST_CHAR || char >= FONT_FIRST_CHAR + FONT_NUM_CHARS do continue
        q := font_get_glyph_scaled(u8(char), &cx, &cy, scale)
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

font_load :: proc(path: string) -> bool {
    data, ok := os.read_entire_file(path)
    if !ok do return false
    defer delete(data)

    pixels := make([]u8, FONT_ATLAS_SIZE * FONT_ATLAS_SIZE)
    defer delete(pixels)

    bake_res := stbtt.BakeFontBitmap(
        raw_data(data), 0, FONT_SIZE,
        raw_data(pixels), FONT_ATLAS_SIZE, FONT_ATLAS_SIZE,
        FONT_FIRST_CHAR, FONT_NUM_CHARS,
        &g_font.char_data[0],
    )
    if bake_res <= 0 do return false

    info: stbtt.fontinfo
    if stbtt.InitFont(&info, raw_data(data), 0) {
        ascent_i, descent_i, line_gap_i: c.int
        stbtt.GetFontVMetrics(&info, &ascent_i, &descent_i, &line_gap_i)
        scale := stbtt.ScaleForPixelHeight(&info, f32(FONT_SIZE))
        g_font.ascent = f32(ascent_i) * scale
        g_font.descent = f32(descent_i) * scale
        g_font.line_gap = f32(line_gap_i) * scale
    }

    gl.GenTextures(1, &g_font.texture)
    gl.BindTexture(gl.TEXTURE_2D, g_font.texture)
    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RED, FONT_ATLAS_SIZE, FONT_ATLAS_SIZE, 0, gl.RED, gl.UNSIGNED_BYTE, raw_data(pixels))

    g_font.loaded = true
    return true
}

font_cleanup :: proc() {
    if g_font.loaded {
        gl.DeleteTextures(1, &g_font.texture)
        g_font.loaded = false
        g_font.ascent = 0
        g_font.descent = 0
        g_font.line_gap = 0
    }
}

font_get_glyph_scaled :: proc(char: u8, x, y: ^f32, scale: f32) -> (quad: stbtt.aligned_quad) {
    if char < FONT_FIRST_CHAR || char >= FONT_FIRST_CHAR + FONT_NUM_CHARS do return
    temp_x := x^ / scale
    temp_y := y^ / scale
    stbtt.GetBakedQuad(&g_font.char_data[0], FONT_ATLAS_SIZE, FONT_ATLAS_SIZE, i32(char - FONT_FIRST_CHAR), &temp_x, &temp_y, &quad, true)
    quad.x0 *= scale
    quad.x1 *= scale
    quad.y0 *= scale
    quad.y1 *= scale
    x^ = temp_x * scale
    y^ = temp_y * scale
    return
}

font_text_width :: proc(text: string) -> (w: f32) {
    x, y: f32
    for char in text {
        if char >= FONT_FIRST_CHAR && char < FONT_FIRST_CHAR + FONT_NUM_CHARS {
            _ = font_get_glyph_scaled(u8(char), &x, &y, 1)
        }
    }
    return x
}

measure_text :: proc(text: string, font_id: int, font_size: f32) -> f32 {
    if font_size <= 0 do return 0
    scale := font_size / f32(FONT_SIZE)
    return font_text_width(text) * scale
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

window_create :: proc(w: ^Window, title: string, width, height: i32) -> bool {
    if sdl2.Init(sdl2.INIT_VIDEO) != 0 {
        fmt.eprintln("SDL2 init failed:", sdl2.GetError())
        return false
    }

    sdl2.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 3)
    sdl2.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 3)
    sdl2.GL_SetAttribute(.CONTEXT_PROFILE_MASK, cast(i32)sdl2.GLprofile.CORE)
    sdl2.GL_SetAttribute(.CONTEXT_FLAGS, cast(i32)sdl2.GLcontextFlag.FORWARD_COMPATIBLE_FLAG)

    title_c := strings.clone_to_cstring(title)
    defer delete(title_c)
    w.handle = sdl2.CreateWindow(
        title_c,
        sdl2.WINDOWPOS_CENTERED, sdl2.WINDOWPOS_CENTERED,
        width, height,
        sdl2.WINDOW_OPENGL | sdl2.WINDOW_SHOWN,
    )
    if w.handle == nil {
        fmt.eprintln("Couldn't create window:", sdl2.GetError())
        return false
    }

    w.gl_context = sdl2.GL_CreateContext(w.handle)
    if w.gl_context == nil {
        fmt.eprintln("GL context creation failed:", sdl2.GetError())
        return false
    }

    gl.load_up_to(3, 3, proc(p: rawptr, name: cstring) {
        ptr := sdl2.GL_GetProcAddress(name)
        (cast(^rawptr)p)^ = ptr
    })

    sdl2.GL_SetSwapInterval(1)
    w.width = width
    w.height = height
    return true
}

window_destroy :: proc(w: ^Window) {
    if w.gl_context != nil do sdl2.GL_DeleteContext(w.gl_context)
    if w.handle != nil do sdl2.DestroyWindow(w.handle)
    sdl2.Quit()
}

window_swap :: proc(w: ^Window) {
    sdl2.GL_SwapWindow(w.handle)
}

scissor_push :: proc(stack: ^[dynamic]vneui.Rect, rect: vneui.Rect, view_h: f32) {
    r := rect
    if len(stack^) > 0 {
        prev := stack^[len(stack^) - 1]
        r = rect_intersect(prev, rect)
    }
    append(stack, r)
    apply_scissor(r, view_h)
}

scissor_pop :: proc(stack: ^[dynamic]vneui.Rect, view_h: f32) {
    if len(stack^) == 0 do return
    _ = pop(stack)
    if len(stack^) == 0 {
        gl.Disable(gl.SCISSOR_TEST)
        return
    }
    apply_scissor(stack^[len(stack^) - 1], view_h)
}

apply_scissor :: proc(rect: vneui.Rect, view_h: f32) {
    gl.Enable(gl.SCISSOR_TEST)
    sx := i32(rect.x)
    sy := i32(view_h - (rect.y + rect.h))
    sw := i32(rect.w)
    sh := i32(rect.h)
    if sw < 0 do sw = 0
    if sh < 0 do sh = 0
    gl.Scissor(sx, sy, sw, sh)
}

rect_intersect :: proc(a, b: vneui.Rect) -> vneui.Rect {
    x0 := a.x
    if b.x > x0 do x0 = b.x
    y0 := a.y
    if b.y > y0 do y0 = b.y
    x1 := a.x + a.w
    bx1 := b.x + b.w
    if bx1 < x1 do x1 = bx1
    y1 := a.y + a.h
    by1 := b.y + b.h
    if by1 < y1 do y1 = by1
    w := x1 - x0
    h := y1 - y0
    if w < 0 do w = 0
    if h < 0 do h = 0
    return vneui.Rect{x0, y0, w, h}
}
