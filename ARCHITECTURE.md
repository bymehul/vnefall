# Vnefall Architecture

This document explains how the engine is put together, so you don't have to guess when you want to add new features.

## Core Flow
Vnefall uses a simple "State" pattern. Everything is held in a global `g` (Game_State) in `main.odin`.

1. **Init**: Set up SDL, OpenGL, Audio, and Load the script.
2. **Poll**: Check for clicks or keypresses.
3. **Update**: Advance the script instruction pointer (IP) if the user clicked.
4. **Draw**: Clear the screen, draw the current background, then draw the text box on top.

## Adding a New Script Command
If you want to add a command like `shake_screen` or `show_character`:

1. **`src/script.odin`**: 
   - Add the new command to the `Command_Type` enum.
   - Update `parse_line` to recognize the command in a text file.
   - Update `script_execute` to handle what the command actually does (e.g., setting a flag).

2. **`src/config.odin`**:
   - If the command needs a new path or global setting, add it to the `Config` struct.

3. **`src/main.odin`**:
   - If the command needs to change something on screen (like a shake), add a field to `Game_State`.
   - Update the drawing logic in the main loop to react to that state.

## Systems
- **Virtual Resolution**: The engine uses a "design resolution" for coordinate math (e.g. 1280x720). This is automatically scaled to the actual window size using a fixed orthographic projection.
- **Config-Driven**: Almost all engine constants (resolution, colors, paths) are loaded from `config.vnef` at runtime.
- **Branching Logic**: Scripts support labels, jumps, and player choices. A pre-processing step builds a label-to-index map for instant navigation.
- **Renderer (`renderer.odin`)**: Uses a single shader and a single buffer. We draw everything as textured quads (2 triangles, 6 vertices).
- **Text (`font.odin`)**: Uses `stb_truetype` to bake a font into a single atlas texture.
- **Audio (`audio.odin`)**: A thin wrapper around `SDL_mixer`.
- **Scene System (`scene.odin`, `manifest.odin`)**: Manages asset loading per-scene. Automatically generates manifests and supports background prefetching for zero-stutter transitions.
- **Character System (`character.odin`)**: A singleton-style manager for sprites. Supports **Scale-to-Fit** (80% vertical height) and **Z-Order** sorted drawing.
- **Persistence (`sthiti/`)**: Uses Sthiti-DB v4 for binary state serialization. Saves all global variables (integers and strings), current textbox text, active character states, script position, and environment.

## Graphics API Strategy
We use **OpenGL 3.3** for its high compatibility and simplicity. While Apple has deprecated OpenGL, it remains the most portable "starter" API for 2D engines.
- **Future-Proofing**: The engine is designed with a separate `renderer.odin`. If OpenGL is ever removed from a major platform, we can implement a `wgpu` or `sokol_gfx` backend without touching the `script.odin` or `main.odin` logic.

## Folder Structure
- `src/`: All Odin source code.
- `assets/images/`: Put your `.png` or `.jpg` backgrounds here.
- `assets/music/`: Put your `.mp3` or `.ogg` tracks here.
- `assets/scripts/`: This is where the `.vnef` story files live.

## Maintenance & Debugging

- **Logging**: Use `fmt.printf` sparingly for debug logs. For v1, we keep things quiet unless there's an error (`fmt.eprintln`).
- **Memory**: Most assets are loaded into caches (see `texture.odin`). If you add new asset types, ensure you add them to the `cleanup_game` proc in `main.odin`.
- **Coordinate System**: We use top-left (0,0). If the screen looks flipped, check `ortho_matrix` in `renderer.odin`.

## Known Constraints
- **VBO Size**: The engine uses a **512KB Vertex Buffer**, providing a massive "sweet spot" headroom for mobile and mid-range devices. While we currently draw images one-by-one, this headroom allows for easy implementation of a Batching Renderer in the future.
- **Script Buffer**: We read the entire `.vnef` file into memory. For massive stories, we might eventually need a streaming parser.

## Troubleshooting
- **No Sound**: Ensure `SDL2_mixer` is installed and the file path starts with `assets/music/`.
- **Corrupted Textures**: OpenGL needs correct pixel alignment. We use `gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)` to handle non-power-of-two widths.

## V1.1.0+ Features

### The Choice System ("add -> show")
Vnefall uses a "staged" choice system to allow dynamic menus:
1.  **Stage**: `choice_add` clones strings into a `[dynamic]Choice_Option` list in `Game_State`.
2.  **Display**: `choice_show` sets `active = true` and pauses the script.
3.  **Clean**: Once selected, `choice_clear` is called to free the strings and clear the list.

### Variable Interpolation
Dialogue and choices are scanned for `${var_name}`. The engine looks up the integer value in the `variables` map and replaces it using a string builder at runtime. These strings are treated as transient and are freed immediately after use or when the textbox advances.

### Multi-File Support
Scripts can jump to other `.vnef` files using `jump_file "other.vnef"`. Variables are preserved when jumping to a new file to allow for persistent story state. The `script_cleanup()` procedure clears commands but keeps containers and variables for reuse, while `script_destroy()` frees everything at game exit.

### Scene-Based Asset Loading
For large games, the engine uses a scene system:
- **Manifests**: Auto-generated lists of assets per script file.
- **Prefetching**: `scene_next` loads next chapter's assets in background.
- **Per-Scene Memory**: Each scene owns its textures, freed on switch.

### Memory Management (Manual)
Odin requires manual memory management. See [docs/memory.md](docs/memory.md) for the full model.

**Quick Summary**:
- **Global Caches**: Textures, fonts, config. Freed at shutdown.
- **Script State**: Commands, labels, variables. Freed when game ends.
- **Scene State**: Per-chapter assets. Freed when switching scenes.
- **Transient Strings**: Dialogue text, choices. Freed immediately after use.

A **Tracking Allocator** is active by default. If any memory is leaked, it will be printed to the console on exit.
