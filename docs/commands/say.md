# Command: `say`

Displays dialogue on the screen with an optional speaker name.

## Usage
```vnef
say <speaker> "<text>"
say <speaker> [speed=0.02] "<text>"
```

## Parameters
- `<speaker>`: The name of the character speaking. If empty, the textbox will only show the dialogue.
- `"<text>"`: The dialogue text, wrapped in double quotes.
- `[speed=...]` (optional): Override the typewriter speed for this line only.

## Variable Interpolation
You can include variables in the dialogue using the `${var}` syntax.
```vnef
set gold = 100
say Alice "You have ${gold} gold pieces."
```

## Example
```vnef
say Alice "Hello there!"
say "..." # Narrator style
say Alice [speed=0.02] "This line types slower."
```

## Text Effects (Tags)
You can add lightweight tags inside the dialogue string:

```vnef
say Alice "This is {color=0xFF66CCFF}pink{/color} text."
say Alice "{shake}This line shakes{/shake}"
```

## Notes
- Text automatically wraps based on the `textbox_padding` and `textbox_margin` in `demo/ui.vnef`.
- The speaker name is styled using `speaker_color` from `demo/ui.vnef` (or per-character overrides in `demo/char.vnef`).
- If `speed` is omitted, it uses `text_speed` from `demo/ui.vnef`.
- `speed` is measured in **seconds per character** (lower = faster).
