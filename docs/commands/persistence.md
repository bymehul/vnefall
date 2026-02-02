# Persistence Commands (Save/Load)

Vnefall v1.2.0 integrates **Sthiti-DB v4** for high-performance state persistence.

## `save "[CheckpointName]"`

Saves a full snapshot of the game state.
- **Variables**: Both **Integers** and **Strings** (e.g., `${player_name}`) are persistent.
- **Characters**: Active characters (sprite, position, Z-index) are saved and restored automatically.
- **Textbox**: The current dialogue text and speaker name are preserved.
- **Environment**: Current background, music, and script position are saved.
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
