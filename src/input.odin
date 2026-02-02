package vnefall

import "vendor:sdl2"

Input_State :: struct {
    advance_pressed: bool,
    up_pressed:      bool,
    down_pressed:    bool,
    select_pressed:  bool,
    mouse_x:         i32,
    mouse_y:         i32,
    mouse_clicked:   bool,
    number_pressed:  int, // 1-9 if pressed, otherwise 0
}

input_poll :: proc(input: ^Input_State, running: ^bool) {
    input.advance_pressed = false
    input.up_pressed      = false
    input.down_pressed    = false
    input.select_pressed  = false
    input.mouse_clicked   = false
    input.number_pressed  = 0
    
    sdl2.GetMouseState(&input.mouse_x, &input.mouse_y)
    
    ev: sdl2.Event
    for sdl2.PollEvent(&ev) {
        #partial switch ev.type {
        case .QUIT:
            running^ = false
            
        case .KEYDOWN:
            #partial switch ev.key.keysym.sym {
            case .SPACE, .RETURN:
                input.advance_pressed = true
                input.select_pressed  = true
            case .UP:
                input.up_pressed = true
            case .DOWN:
                input.down_pressed = true
            case .ESCAPE:
                running^ = false
            case .NUM1, .NUM2, .NUM3, .NUM4, .NUM5, .NUM6, .NUM7, .NUM8, .NUM9:
                input.number_pressed = int(ev.key.keysym.sym) - int(sdl2.Keycode.NUM1) + 1
            }
            
        case .MOUSEBUTTONDOWN:
            if ev.button.button == sdl2.BUTTON_LEFT {
                input.advance_pressed = true
                input.select_pressed  = true
                input.mouse_clicked   = true
            }
        }
    }
}
