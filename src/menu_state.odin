package vnefall

Menu_Page :: enum {
    None,
    Main,
    Pause,
    Settings,
    Save,
}

Menu_State :: struct {
    active: bool,
    page:   Menu_Page,
    save_page: int,
}

menu_open_pause :: proc(g: ^Game_State) {
    if g == nil do return
    g.menu.active = true
    g.menu.page = .Pause
}

menu_open_main :: proc(g: ^Game_State) {
    if g == nil do return
    g.menu.active = true
    g.menu.page = .Main
}

menu_open_settings :: proc(g: ^Game_State) {
    if g == nil do return
    g.menu.active = true
    g.menu.page = .Settings
}

menu_open_save :: proc(g: ^Game_State) {
    if g == nil do return
    g.menu.active = true
    g.menu.page = .Save
}

menu_close :: proc(g: ^Game_State) {
    if g == nil do return
    g.menu.active = false
    g.menu.page = .None
}

menu_toggle :: proc(g: ^Game_State) {
    if g == nil do return
    if g.menu_intro_active do return
    if !g.menu.active {
        menu_open_pause(g)
        return
    }
    if g.menu.page == .Settings || g.menu.page == .Save {
        g.menu.page = .Pause
        return
    }
    if g.menu.page == .Main {
        menu_close(g)
        return
    }
    menu_close(g)
}

menu_intro_update :: proc(g: ^Game_State, dt: f32) {
    if g == nil || !g.menu_intro_active do return
    if menu_cfg.menu_intro_image == "" || g.menu_intro_tex == 0 {
        g.menu_intro_active = false
        g.menu_intro_timer = 0
        return
    }

    if menu_cfg.menu_intro_skip && (g.input.advance_pressed || g.input.menu_pressed || g.input.mouse_pressed) {
        g.menu_intro_active = false
        g.menu_intro_timer = 0
        // Consume the input so it doesn't click through the menu.
        g.input.advance_pressed = false
        g.input.select_pressed = false
        g.input.mouse_pressed = false
        g.input.menu_pressed = false
        return
    }

    if menu_cfg.menu_intro_ms <= 0 do return
    g.menu_intro_timer += dt * 1000.0
    if g.menu_intro_timer >= menu_cfg.menu_intro_ms {
        g.menu_intro_active = false
        g.menu_intro_timer = 0
    }
}
