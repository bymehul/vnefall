# Vnefall

Vnefall is a simple, no-nonsense visual novel engine. It's built in Odin using SDL2 and OpenGL 3.3.

![Vnefall Demo](demo_vnefall.gif)

## Features
- **Branching Dialogue**: Full support for labels, jumps, and player choices.
- **Configuration System**: Portable `config.vnef` file for resolution, colors, and paths.
- **Virtual Resolution**: Design once, it scales automatically to any screen.
- **Simple Syntax**: Commands like `say`, `bg`, `char`, `choice`, `set`, and `if`.
- **Audio Support**: Background music with looping support.
- **Sthiti Persistence**: Fast, native Save/Load system for story progress.
- **Character Stacking**: Responsive scaling and Z-index control for sprites.

## How to get started

### Just want to run it? (Linux)
If you're on Linux, grab the `vnefall` binary from the [Releases](https://github.com/bymehul/vnefall/releases) page. Run the new high-quality demo:
```bash
chmod +x vnefall
./vnefall assets/scripts/demo_game.vnef
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
./vnefall assets/scripts/v120_char_pro.vnef
```

**Windows:**
Install Odin, download the SDL2 development libs, and run:
```powershell
odin build src -out:vnefall.exe
./vnefall.exe assets/scripts/demo.vnef
```

**Mac:**
```bash
brew install sdl2 sdl2_mixer
odin build src -out:vnefall
./vnefall assets/scripts/demo.vnef
```

## Writing your own story

Scripts are just simple text files ending in `.vnef`. You can change backgrounds, play music, and write dialogue without touching a single line of code.

See the [detailed command guide](docs/commands/) for all available commands.

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
- **Escape**: Quit.

## Contributing
Check out [CONTRIBUTING.md](CONTRIBUTING.md) for the guide. We like clean, readable code with simple logic.

## License
This project is licensed under the [MIT License](LICENSE). 

I am also planning to transition to a **dual-licensing** model in the future to support long-term development.
