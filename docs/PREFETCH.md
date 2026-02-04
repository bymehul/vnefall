# 🚀 Vnefall Prefetching Guide

Prefetching allows your game to load assets for the next script in the background, ensuring a zero-stutter transition when you eventually jump.

## 🧠 How it Works
When you call `scene_next "my_next_script"`, the engine:
1.  Generates/Loads a **Manifest** for that script.
2.  Loads all **Textures** (backdrops and sprites) into GPU memory.
3.  Prefetches **Audio** (music, ambience, SFX, voice) into memory.
4.  Holds them in a "Ready" state until a `jump_file` command is triggered.

## 🖼️ Optional Loading Screen
If the next script doesn’t immediately set a `bg`, the engine can show a loading screen instead of a black flash.

Add this to `demo/ui.vnef` (relative to `demo/assets/images/`):
```text
loading_image = "loading.png"
```
If `loading_image` is empty, the engine falls back to a simple “Loading...” screen.

## 💾 Memory Management
Vnefall is designed to be efficient with memory:
- **One at a time**: The engine only keeps **one** prefetched scene at a time.
- **Auto-Cleanup**: If you call `scene_next "FileA"` and then `scene_next "FileB"`, FileA is **automatically freed** before FileB starts loading. You don't have to worry about multiple prefetches piling up.

## 🛑 Manual Cleanup
If you prefetch a file before a branching choice, but the player picks a path that **stays** in the current file, that prefetched data will linger in memory.

To clear it manually, use:
```vnef
scene_next "none"
```
Prefetch cleared: **textures + audio freed** (current scene remains active).

## 🏆 Best Practices
1.  **Branch Prefetching**: Instead of prefetching *before* a choice, prefetch **immediately after** the choice is made inside the branch label.
    ```vnef
    choice_add "Go to Mars" go_mars
    choice_add "Stay on Earth" stay_earth
    choice_show
    
    label go_mars:
        scene_next "mars_script" # Start loading while Emi speaks!
        say Emi "Buckle up, Zen. It's a long trip."
        jump_file "mars_script.vnef"
    ```
2.  **Scene Size**: Try to keep your `scene_next` calls at least 1-2 dialogue lines before the actual `jump_file`. This gives the CPU/GPU time to finish loading large assets.
