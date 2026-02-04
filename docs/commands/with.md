# Command: `with`

Applies a **one-shot transition** to the very next **background change OR character show/hide** (whichever comes next).

## Usage
```vnef
with fade 400
bg night.png
```

## Parameters
- `fade | wipe | slide | dissolve | zoom | blur | flash | shake | none`: Transition type.
- `ms` (optional): Duration in milliseconds.  
  If omitted, it uses `bg_transition_ms` (for `bg`) or the matching character default (`char_fade_ms`, `char_slide_ms`, `char_shake_ms`) from `demo/ui.vnef`.

## Examples
```vnef
with fade 600
bg street.png

with wipe 400
bg station.png

with dissolve 500
bg apartment_night.png

with zoom 300
bg bedroom.png

with blur 400
bg bedroom_night.png

with flash 120
bg night.png

with shake 180
bg room.png

with none
bg room.png
```

## Notes
- `with` is **one-shot**. It applies to the next `bg` or `char` command only, then resets.
- Character transitions are visually distinct for `fade`, `slide`, `shake`, and `none`. Other types fall back to a fade for characters.
- `blur` is a soft placeholder until a real blur shader is implemented.
- If you don’t use `with`, the engine uses the defaults in `demo/ui.vnef`.
- You can also inline it on character commands: `char Alice show happy at left with slide 250`.
- Shake strength is controlled by `bg_shake_px` and `char_shake_px` in `demo/ui.vnef`.
