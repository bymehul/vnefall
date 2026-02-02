# Scene Commands

Scene commands control asset loading and memory management for large games.

## Commands

### `scene_next "scene_name"`

Prefetches the next scene's assets in the background while the player continues reading.

```vnef
say Alice "Let's head to the beach tomorrow."
scene_next "chapter_2"   # Start loading chapter_2 assets
say Alice "Get some rest."
```

#### Clearing the Cache
If a player picks a choice that stays in the current script, you should manually clear the prefetch cache to save GPU memory:
```vnef
scene_next "none"
```

### `scene "scene_name"`

Immediately loads a scene and makes it active. Use this at the start of a chapter.

```vnef
scene "chapter_2"
bg beach.png       # Loaded from chapter_2's manifest
say Alice "What a beautiful day!"
```

## How It Works

1. **Auto-Generated Manifests**: When a scene is first loaded, the engine scans the script for `bg`, `sprite`, and `music` commands and creates a `.manifest` file listing all required assets.

2. **Prefetching**: `scene_next` loads the manifest and prepares assets while the player is still reading. This eliminates loading screens.

3. **Memory Management**: Each scene owns its textures. When you switch scenes, the old scene's assets are freed automatically.

## Example: Multi-Chapter Game

```vnef
# chapter_1.vnef
scene "chapter_1"
bg forest.png
say Alice "Welcome to the forest."

# Near the end, prefetch chapter 2
scene_next "chapter_2"
say Alice "Let's head to the beach!"

# The player would jump to chapter_2.vnef here
jump_file "chapter_2.vnef"
```

## Manifest File Format

Manifests are auto-generated, but you can edit them manually for optimization:

```text
# chapter_2.manifest
bg beach.png
bg sunset.png
sprite alice_swimsuit.png
music beach_theme.ogg
```

## Best Practices

1. **Prefetch Early**: Call `scene_next` several dialogue boxes before the scene ends to give time for loading.

2. **One Scene Per Chapter**: Each major chapter should be its own scene to control memory.

3. **Shared Assets**: If two scenes share assets (e.g., character sprites), they'll be loaded twice. Future versions may add shared asset pools.
