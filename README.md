# Vnefall

Vnefall is a simple, no-nonsense visual novel engine. It's built in Odin using SDL2 and OpenGL 3.3.

**Status: Under development. Not recommended for production yet; updates may be less frequent due to studies.**

![Vnefall Demo](demo_vnefall.gif)

## Features
- **Branching Dialogue**: Full support for labels, jumps, and player choices.
- **Configuration System**: `demo/config.vnef` for engine settings, `demo/ui.vnef` for UI styling + transitions, and `demo/char.vnef` for per-character colors.
- **Virtual Resolution**: Design once, it scales automatically to any screen.
- **Simple Syntax**: Commands like `say`, `bg`, `char`, `choice`, `set`, and `if`.
- **Audio Support**: Background music with looping support.
- **Sthiti Persistence**: Fast, native Save/Load system for story progress.
- **Character Stacking**: Responsive scaling and Z-index control for sprites.
- **Cinematic Transitions**: `with fade|wipe|slide|dissolve|zoom|blur|flash|shake|none` for backgrounds + character fades/slides.
- **Text Effects**: Inline `{color=...}` tags, `{shake}`, and per-line `[speed=...]` overrides.
- **Movie Playback**: `movie` command for `.video` cutscenes with textbox control.
- **Video Pipeline**: Source videos live in `assets/videos_src/`, build step generates runtime `.video` + optional `.ogg` audio.

## How to get started

### Just want to run it? (Linux)
If you're on Linux, grab the `vnefall` binary from the [Releases](https://github.com/bymehul/vnefall/releases) page. Run the new high-quality demo:
```bash
chmod +x vnefall
./vnefall demo/assets/scripts/demo_game.vnef
```

### Want to build from source?
*(Note: Windows and Mac versions are currently untested).*

You'll need the [Odin Compiler](https://odin-lang.org/) and SDL2 libraries.

**Linux (Ubuntu/Debian):**
```bash
# Install dependencies
sudo apt install libsdl2-dev libsdl2-mixer-dev libsdl2-ttf-dev

# Build (v1.2.0)
./build.sh
./vnefall demo/assets/scripts/v120_char_pro.vnef
```

**Windows:**
Install Odin, download the SDL2 development libs, and run:
```powershell
odin build src -out:vnefall.exe
./vnefall.exe demo/assets/scripts/demo.vnef
```

**Mac:**
```bash
brew install sdl2 sdl2_mixer
./build.sh
./vnefall demo/assets/scripts/demo.vnef
```

If you enable `movie`, `build.sh` will also build `utils/vnef-video` (requires FFmpeg dev libs).
To prep videos, you also need a working `ffmpeg` binary in PATH (or pass `--ffmpeg /path/to/ffmpeg`).

Prepare videos (example):
```bash
./build.sh --prep-videos demo/assets/videos_src demo/runtime/videos --force --audio --audio-out demo/runtime/video_audio
```

## Writing your own story

Scripts are just simple text files ending in `.vnef`. You can change backgrounds, play music, and write dialogue without touching a single line of code.

See the [detailed command guide](docs/commands/) for all available commands.
If you see `Path does not exist: vnef_video`, use `./build.sh` or pass the `-collection:vnefvideo=...` flags shown in `build.sh`.

Project layout (demo-style):
- `demo/config.vnef` (engine paths, entry script, resolution, `bg_blur_quality`)
- `demo/ui.vnef` (textbox, choice UI, transitions)
- `demo/char.vnef` (per-character name/text colors)
- `demo/assets/` (images, audio, scripts)
- `demo/assets/videos_src/` (source videos: `.mp4/.webm`, tooling only)
- `demo/runtime/videos/` (generated `.video` artifacts, do not edit/commit)
- `demo/runtime/video_audio/` (auto-mapped `.ogg` audio for movies, generated)

Note: If you pass a script path on the command line, the Start menu will launch that script instead of `entry_script`.

Here's what a script looks like:
```vnef
bg room.png
say Alice "Welcome to the new Vnefall!"

choice_add "Go to the Night" see_night
choice_add "Stay in Day" stay_day
choice_show

label see_night:
    bg night.png
    say Alice "The night is cool."
    jump end_story

label stay_day:
    say Alice "Sunlight is nice too."

label end_story:
    say Alice "Thanks for playing!"
    end
```

## Controls
- **Click / Space / Enter**: Next line.
- **Escape**: Open/close the pause menu.

## Roadmap
See `future.md` for the full roadmap. v1.5.x includes menu UI polish and quality-of-life reading features.

## Contributing
Check out [CONTRIBUTING.md](CONTRIBUTING.md) for the guide. We like clean, readable code with simple logic.

## License
This project is licensed under the [MIT License](LICENSE). 

I am also planning to transition to a **dual-licensing** model in the future to support long-term development.
