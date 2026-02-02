# Vnefall — Future Roadmap

> Features planned for v1.x releases
>
> **Technical Philosophy**: "High-Spirit, Low-Spec." 🚀🥔
> We prioritize OpenGL 3.3 compatibility to ensure beautiful effects run on everything from modern rigs to decade-old laptops.

---

## v1.1.0: Scenes & Multi-File ✅ COMPLETE

- [x] **External Configuration**: A `config.vnef` file to remove hardcoded values.
- [x] **Labels & Jumps**: Organize scripts with labels and non-linear navigation.
- [x] **Choice Menus**: Simple choices for the player to influence the story.
- [x] **Flags & Logic**: Boolean flags, integers, and `if/else` blocks.
- [x] **Variable Interpolation**: `${var}` syntax in dialogue.
- [x] **Scene System**: Per-chapter asset management with manifests.
- [x] **Background Prefetching**: Zero-stutter chapter transitions.
- [x] **Multi-File Scripts**: `jump_file` to load different `.vnef` files.
- [x] **Memory Safety**: Tracking allocator, zero leaks verified.

---

## v1.2.0: The "Stability & Presence" Update ✅ COMPLETE

This update combines a simplified character system, Sthiti-DB persistence, and hybrid variables.

### 🎭 Characters (Simplified System)
- [x] **Single-Sprite Model**: Characters use one sprite at a time (layering deferred to v2).
- [x] **`char` Commands**: `char <name> show <sprite> at <pos>`, `char <name> hide`.
- [x] **Responsive Positions**: `left` (25%), `center` (50%), `right` (75%) of screen.
- [x] **Dharana Retention**: Characters stay in global cache across scene jumps.
- [x] **Scale-to-Fit**: Automatically fit sprites to 80% screen height.
- [x] **Character Z-Index**: Stacking order control via `z [value]`.
- [x] **Flexible Extensions**: Support for `.jpg`, `.png`, and default formats.

### 💾 Persistence (Sthiti-DB Integration)
- [x] **Native Save/Load**: `save` and `load` commands using Sthiti-DB protocol.
- [x] **Configurable Save Path**: `path_saves` in `config.vnef`.
- [x] **Variable Retention**: All story flags saved (integers only; strings deferred).
- [x] **Timestamp Support**: Save files include timestamp metadata.

### 🔢 Logic & Strings
- [x] **String Variables**: Support `set name = "Alice"` and interpolation.
- [x] **Arithmetic**: Basic math in scripts (e.g., `set gold = gold + 50`).
- [x] **String Comparison**: `if (name == "Alice")` and `if (name == "")` work.
- [x] **Type-Safe Comparison**: Comparing int to string returns `false` (no crash).

### 🖱️ UI Enhancement
- [x] **Keyboard Shortcuts**: Number keys (1-9) for selecting choices instantly.

---

## v1.3.0: Audio Expansion (Sound & Voice)

- [ ] **SFX & Voices**: Support for per-character voice clips and sound effect triggers.
- [ ] **Audio Mixer**: Global, Music, and SFX volume channels.
- [ ] **Volume Persistence**: Save volume levels in `config.vnef` or a separate settings file.
- [ ] **Music Fades**: Smooth volume cross-fading when switching tracks.

---

## v1.4.0: Visual & Interface Polish (Transitions & UI)

- [ ] **Cinematic Transitions**: Fades and wipes for backgrounds and character sprites.
- [ ] **Custom Textbox**: Support for custom PNG backgrounds and transparency controls for the dialogue box.
- [ ] **UI Customization**: Fully customizable Choice buttons (PNG textures, hover effects).
- [ ] **Text Effects**: Typewriter speed control, text shaking, and color tags.

---

## v1.5.0: System & Settings (Preferences Menu)

- [ ] **Settings Menu**: A pre-built, high-quality menu for Volume, Text Speed, and Display Mode.
- [ ] **Menu Logic**: Handling settings changes instantly without restarting the engine.
- [ ] **Backlog**: A scrollable history window for reviewing previously read text.
- [ ] **Auto-Advance**: Toggleable mode for automatic reading progression.

---

## v1.6.0: Tooling & Performance Optimizer

- [ ] **Global Texture Registry**: Prevent duplicate assets from being loaded into VRAM. Deduplicates shared backgrounds across scripts.
- [ ] **LRU Cache (Least Recently Used)**: Automatically evict old textures when reaching a memory limit, rather than manual `scene_next none`.
- [ ] **Intelligent Streaming**: Predict upcoming assets by scanning the script ahead of the player (Ren'Py-style prediction).
- [ ] **Script Linter**: Check `.vnef` files for syntax errors or broken jumps.
- [ ] **Debug Console**: Runtime variable viewer and command executor (F3).
- [ ] **Hot Reload**: Live script reloading while the engine is running.

---

## v2: Future Horizons

- [ ] **Layered Sprite Model**: Full `base` + `outfit` + `expression` compositing.
- [ ] **WGPU Port**: Move to `wgpu` or `sokol_gfx` for Web (WASM) and Mobile support.
- [ ] **Live2D / Mesh Warp**: Support for subtle breathing/blink animations.
- [ ] **Rollback System**: Full state "Back" command (Rewind time).
- [ ] **Mini-game Framework**: Native support for simple interactive puzzles.
