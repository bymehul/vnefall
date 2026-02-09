package vnefall

/*
    gaussian_blur.odin
    Placeholder for a full Gaussian blur implementation.
    This keeps the blur work isolated so we can swap approaches later
    (CPU, GPU, multi-pass, etc.) without touching game code.
*/

Gaussian_Blur :: struct {
    ready: bool,
    radius: i32,
    sigma: f32,
}

gaussian_blur_init :: proc(b: ^Gaussian_Blur, radius: i32, sigma: f32) {
    if b == nil do return
    b.ready = true
    b.radius = radius
    b.sigma = sigma
}

gaussian_blur_apply :: proc(b: ^Gaussian_Blur) {
    // TODO: implement GPU/CPU blur here.
    _ = b
}

gaussian_blur_cleanup :: proc(b: ^Gaussian_Blur) {
    if b == nil do return
    b.ready = false
}
