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
```

## `char [Name] hide`

Hides the character and **immediately flushes them from RAM**.

**Example:**
```vnef
char Alice hide
```

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
- **Flush on Hide**: When a character is hidden, they are WIPED from memory to keep the engine fast.
- **Flush on Script Switch**: When jumping between script files, all character data is cleared to prevent "ghost" sprites in new chapters.
- **Prefetching**: The engine automatically scans `char` commands in your scripts to preload sprites in the background.

### Flexible Extensions
The engine supports multiple formats:
- Default: `.png`
- Supported: `.jpg`, `.jpeg`, `.png`, `.webp`, `.bmp`, etc.
- If you omit the extension, `.png` is assumed.
