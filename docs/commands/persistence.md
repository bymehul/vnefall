# Persistence Commands (Save/Load)

Vnefall v1.3.0 integrates **Sthiti-DB v6** for high-performance state persistence.

## `save "[CheckpointName]"`

Saves a full snapshot of the game state.
- **Variables**: Both **Integers** and **Strings** (e.g., `${player_name}`) are persistent.
- **Characters**: Active characters (sprite, position, Z-index) are saved and restored automatically.
- **Textbox**: The current dialogue text and speaker name are preserved.
- **Environment**: Current background and script position are saved.
- **Audio**: Current music/ambience, latest voice clip, and active SFX are restored on load.
- **Choices**: Active choice menus (options + highlighted selection) are restored on load.
- **Settings**: Volume preferences live in `settings.vnef` (not per-save).
- **Storage**: Files are stored in the folder configured by `path_saves` (default: `saves/`).

**Example:**
```vnef
save "chapter_1_end"
```
*Creates: `saves/chapter_1_end.sthiti`*

## `load "[CheckpointName]"`

Restores the game state from a previously saved checkpoint.

**Example:**
```vnef
load "chapter_1_end"
```
