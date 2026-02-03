# Vnefall Memory Model

Odin does not have a garbage collector. Every allocation must be manually freed. This document explains how Vnefall manages memory to ensure zero leaks.

## The Three Pillars

### 1. Global Caches (Long-Lived)
These are loaded once at startup and freed once at shutdown.

| What | File | Cleanup Procedure |
|------|------|-------------------|
| Textures | `texture.odin` | `texture_cleanup()` |
| Font Atlas | `font.odin` | `font_cleanup()` |
| Config Strings | `config.odin` | `config_cleanup()` |
| Audio Cache (Optional) | `audio.odin` | `audio_cleanup()` |

### 2. Script State (Medium-Lived)
These are loaded when a script is run and freed when the game ends.

| What | Struct Field | Cleanup Procedure |
|------|--------------|-------------------|
| Commands | `script.commands` | `script_cleanup()` / `script_destroy()` |
| Labels Map | `script.labels` | `script_cleanup()` / `script_destroy()` |
| Variables Map | `script.variables` | Freed in `script_destroy()` (End of game) |

**Note**: `script_cleanup()` clears data but keeps containers. `script_destroy()` frees everything (call at game exit).
**Note**: `script_cleanup()` clears commands and labels to prepare for a new script, but **specifically preserves** the variables map so that story flags (like `gold` or `player_name`) persist across chapter jumps.

### 3. Scene State (Per-Chapter)
Scenes manage assets for each chapter, freeing them when switching.

| What | File | Cleanup Procedure |
|------|------|-------------------|
| Per-scene textures | `scene.odin` | `scene_cleanup()` |
| Manifests | `manifest.odin` | `manifest_cleanup()` |
| Scene manager | `scene.odin` | `scene_system_cleanup()` |
| Scene audio (music/ambience/SFX/voice) | `audio.odin` | `audio_flush_scene()` |

**Shared Asset Preservation**: When switching scenes, assets that exist in both the current and next scene (textures and audio) are retained to avoid double-loading and reduce VRAM/heap spikes.

### 4. Character State (Global Cache / "Backstage")
Characters remain loaded across scene transitions using the Dharana model.

| What | File | Cleanup Procedure |
|------|------|-------------------|
| Character structs | `character.odin` | `character_cleanup()` |
| Character textures | Uses `scene.odin` cache | Freed with scene |

**Note**: `g_characters` is a global map (The "Backstage"). 
- **Auto-Flush**: When a character is hidden with `char Alice hide`, they are **immediately deleted** from RAM.
- **Chapter Purge**: All active characters are flushed when jumping to a new script file via `jump_file`. 
- **Persistence**: Visible characters are automatically snapshotted into `sthiti` save files (v6) and restored on load.

### 5. Transient Strings (Short-Lived)
These are created on-the-fly and deleted immediately after use.

| What | When Created | When Deleted |
|------|--------------|--------------|
| Textbox Text | Every `say` with `${var}` | Before the *next* `say` |
| Choice Options | Every `choice_add` | When player clicks (`choice_clear`) |

## The "Swap" Pattern

For dialogue, we use a "swap" pattern to ensure only one sentence is ever in memory:

```odin
// In script_execute, for Say:
new_text := interpolate_text(s, c.what)  // Create new
delete(state.textbox.text)               // Kill old
state.textbox.text = new_text            // Assign new
```

## The Scene System

For large games (1000+ assets), we use a **scene-based** memory model:

```
Scene 1 (Chapter 1)          Scene 2 (Chapter 2)
┌────────────────────┐       ┌────────────────────┐
│ forest.png         │       │ beach.png          │
│ alice_casual.png   │   →   │ alice_swimsuit.png │
│ forest_theme.ogg   │       │ beach_theme.ogg    │
└────────────────────┘       └────────────────────┘
        │                            ▲
        └── Freed when switching ────┘
```

**Commands**:
- `scene_next "chapter_2"` — Prefetch assets in background
- `scene "chapter_1"` — Activate a scene and free the old one

## The Leak Detector

A **Tracking Allocator** is active by default in `main.odin`. When the game exits, it prints a report:

- **Clean exit**: No output means zero leaks.
- **Leaks found**: A list of files and line numbers will be printed, showing where the unfreed memory was allocated.

Example of a clean exit:
```
Cleaning up and exiting.
```

Example of a leak:
```
=== 5 allocations not freed: ===
- 32 bytes @ /src/script.odin(70:19)
```

## Best Practices for Contributors

1.  **Every `strings.clone()` needs a `delete()`.**
2.  **Dynamic arrays (`[dynamic]T`) need `delete()` for the array itself.**
    -   If the elements are also allocated (e.g., `[dynamic]string` where strings are cloned), you must loop and delete each element first.
3.  **Use `defer` for temporary allocations** that should be freed at the end of a scope.
4.  **`strings.split()` returns slices, not clones.** You only need to `delete()` the slice itself, not the individual strings.
5.  **For multi-file scripts**, use `script_cleanup()` (keeps containers) during `jump_file`, and `script_destroy()` (frees all) at game exit.
6.  **Use scenes for large games** to control memory per chapter.
