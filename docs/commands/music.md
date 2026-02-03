# Commands: `music` / `play` / `music_stop` / `music_stop_fade`

Plays background music. For full audio controls, see `docs/commands/audio.md`.

## Usage
```vnef
music <filename>
play <filename>
music_stop
music_stop_fade <ms>
```

## Parameters
- `<filename>`: The name of the audio file in the music directory.
  - Default directory: `assets/music/`
- `<ms>`: Fade time in milliseconds.

## Example
```vnef
music dungeon_theme.ogg
say Alice "It's cold in here..."
music_stop_fade 1200
```

## Notes
- `music` and `play` behave the same, looping the track until changed.
- Supported formats: `.ogg`, `.mp3`, `.wav`.
