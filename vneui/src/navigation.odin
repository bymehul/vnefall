package vneui

ui_focus_apply_nav :: proc(ctx: ^UI_Context) {
    if ctx.input.nav_cancel {
        ctx.focus_id = 0
        return
    }
    if !ctx.input.nav_next && !ctx.input.nav_prev do return
    if len(ctx.focus_order_prev) == 0 do return

    idx := -1
    for id, i in ctx.focus_order_prev {
        if id == ctx.focus_id {
            idx = i
            break
        }
    }

    if idx < 0 {
        if ctx.input.nav_prev {
            ctx.focus_id = ctx.focus_order_prev[len(ctx.focus_order_prev)-1]
        } else {
            ctx.focus_id = ctx.focus_order_prev[0]
        }
        return
    }

    if ctx.input.nav_next {
        idx = (idx + 1) % len(ctx.focus_order_prev)
    } else if ctx.input.nav_prev {
        idx = idx - 1
        if idx < 0 do idx = len(ctx.focus_order_prev) - 1
    }
    ctx.focus_id = ctx.focus_order_prev[idx]
}

ui_focus_register :: proc(ctx: ^UI_Context, id: u64) -> bool {
    if id == 0 do return false
    append(&ctx.focus_order, id)
    return ctx.focus_id == id
}

ui_focus_set :: proc(ctx: ^UI_Context, id: u64) {
    if id == 0 do return
    ctx.focus_id = id
}

ui_focus_clear :: proc(ctx: ^UI_Context) {
    ctx.focus_id = 0
}
