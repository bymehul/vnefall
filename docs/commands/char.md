# Character System Commands

As of v1.2.0, characters use a **Simplified Single-Sprite System** with responsive scaling, flexible extensions, and Z-indexing.

## `char [Name] show [Sprite] at [Position] (z [Value])`

Shows a character sprite.

- **[Name]**: The character folder in `assets/images/characters/` (e.g., `Alice`).
- **[Sprite]**: The name of the image file. Defaults to `.png` if no extension is provided. (e.g., `happy`, `casual.jpg`).
- **[Position]**: Responsive named positions (`left`, `center`, `right`) or a raw X coordinate.
- **z [Value]** (Optional): Controls stacking order. Higher values draw in front of lower values.

**Examples:**
```vnef
# Basic show
char Alice show happy at center

# Showing with Z-index (Alice in front of Bob)
char Bob show casual at center z 5
char Alice show happy at center z 10

# Using different extensions
char Alice show "photo.jpg" at left

# Inline transition override
char Alice show happy at left with slide 250
```

## `char [Name] hide`

Hides the character. By default, it uses the transition duration from `demo/ui.vnef` (`char_fade_ms`).  
You can override the next show/hide with `with <type> [ms]` (e.g., `with slide 250`).  
All `with` transition types are supported for characters (fade, wipe, slide, dissolve, zoom, blur, flash, shake, none).

Default character transition type comes from `char_transition` in `demo/ui.vnef`.
Transition durations come from `char_fade_ms`, `char_slide_ms`, and `char_shake_ms` in `demo/ui.vnef`.
Shake strength comes from `char_shake_px` in `demo/ui.vnef`.

**Example:**
```vnef
with slide 250
char Alice hide
```

---

## Character Registry (demo/char.vnef)

You can set per-character UI colors in `demo/char.vnef`.  
These override the defaults from `demo/ui.vnef`.

```
[Alice]
name_color = 0xFFD700FF
text_color = 0xF5F5F5FF

[Bob]
name_color = 0x7ACBFFFF
text_color = 0xE6F2FFFF
```

If a character is missing here, the engine falls back to:
- `speaker_color` (name) from `demo/ui.vnef`
- `text_color` (dialogue) from `demo/ui.vnef`

---

## Technical Features

### Responsive Scaling
The engine automatically scales sprites to fit within **80% of the screen height** while maintaining their original aspect ratio. Characters are always bottom-aligned (feet touch the bottom of the screen).

### Named Positions
Positions are calculated as percentages of `design_width`:
- `left`: 25%
- `center`: 50%
- `right`: 75%

### Automatic Memory Management (Dharana)
- **Flush on Hide**: When a character is hidden, they are removed after any active transition completes.
- **Flush on Script Switch**: When jumping between script files, all character data is cleared to prevent "ghost" sprites in new chapters.
- **Prefetching**: The engine automatically scans `char` commands in your scripts to preload sprites in the background.

### Flexible Extensions
The engine supports multiple formats:
- Default: `.png`
- Supported: `.jpg`, `.jpeg`, `.png`, `.webp`, `.bmp`, etc.
- If you omit the extension, `.png` is assumed.
