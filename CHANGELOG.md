# Changelog

All notable changes to Vnefall will be documented in this file.

## [1.2.0] - 2026-02-03
### Added
- **Character Snapshots**: Full persistence for characters (sprite, position, Z-index) via Sthiti-DB v4.
- **Stutter-Free Transitions**: Intelligent background maintenance and pre-loading across script files.
- **Resource Control**: New `scene_next "none"` command to manually clear the prefetch cache.
- **Sthiti-DB v4**: Added support for string variables, textbox text, and active character lists.
- **Precise Input**: Choice selection is now strictly bounded to button rectangles.
- **Logic Expansion**: Basic math support and string comparison (`if name == "Alice"`).
- **Keyboard Shortcuts**: Use number keys `1-9` for instant choice selection.
- **Extension-Agnostic Assets**: Automatic resolution of `.png`, `.jpg`, etc., if extension is omitted.

### Changed
- **Memory Model**: Prefetching now loads textures immediately on the main thread.
- **Scene System**: Transition logic now preserves visual continuity across `jump_file`.

### Fixed
- Fixed black screen flicker during script-to-script jumps.
- Fixed mouse clicks triggering choices from anywhere on screen.
- Fixed instructions skipping when loading saves from different files.
- Fixed memory leaks in variable key persistence.

## [1.1.0] - 2026-02-02
### Added
- **Scene System**: Per-chapter asset management with auto-generated manifests (`scene.odin`, `manifest.odin`).
- **Background Prefetching**: `scene_next` command preloads next scene's assets while player reads.
- **Multi-File Support**: `jump_file` command loads and executes a different `.vnef` script file.
- **Branching**: Labels, jumps, choices, variables, and `if/else` blocks (`choice_add`, `choice_show`).
- **Variable Interpolation**: `${var}` syntax in dialogue and choices.
- **Roadmap**: Added persistence to disk (Save/Load system) to `future.md`.
- **Memory Optimization**: `script_cleanup()` for reuse, `script_destroy()` for final cleanup.
- **Documentation**: New docs for `scenes.md`, `flow.md`, expanded `memory.md`.

### Changed
- **Script Loader**: Now supports reloading without memory leaks.
- **ARCHITECTURE.md**: Added Scene System to systems list.

### Fixed
- Use-after-free bug when jumping between script files.
- Memory leaks in config string handling.

---

## [1.0.0] - 2026-02-01
### Added
- **Core Engine**: Initial release of the Vnefall engine.
- **Rendering**: OpenGL 3.3 Core Profile renderer with support for textured quads.
- **Text System**: Bitmap font rendering using `stb_truetype` with automated word wrapping.
- **Script Engine**: Support for `bg`, `say`, `music`, `play`, `title`, `wait`, and `end` commands.
- **Audio**: Background music support with looping via `SDL_mixer`.
- **Polish**: Full code refactor for organic, human-readable style.
- **Documentation**: Comprehensive README, CONTRIBUTING, technical ARCHITECTURE guide, and detailed Command Documentation.
