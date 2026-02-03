# Audio Commands

Audio is split into four types so you can control volumes independently and keep behavior predictable.

**Types**
- `music`: Looping background tracks (one at a time).
- `ambience`: Looping environmental bed (rain, wind, crowd).
- `sfx`: Short one-shot effects (door, UI click).
- `voice`: One-shot voice clips (latest voice interrupts the previous).

## `music <filename>` / `play <filename>`
Plays looping background music.

```vnef
music theme.ogg
```

## `music_fade <filename> <ms>`
Cross-fades to a new track over `<ms>` milliseconds.

```vnef
music_fade calm_theme.ogg 1500
```

## `music_stop`
Stops the current music immediately.

```vnef
music_stop
```

## `music_stop_fade <ms>`
Fades out the current music over `<ms>` milliseconds.

```vnef
music_stop_fade 1200
```

## `ambience <filename>`
Plays a looping ambience track on its own channel.

```vnef
ambience rain.ogg
```

## `ambience_fade <filename> <ms>`
Fades ambience to a new track over `<ms>` milliseconds.

```vnef
ambience_fade night_city.ogg 1500
```

## `ambience_stop`
Stops the current ambience loop immediately.

```vnef
ambience_stop
```

## `sfx <filename>`
Plays a one-shot sound effect.

```vnef
sfx door_open.ogg
```

## `voice <filename>`
Plays a one-shot voice clip and stops any currently playing voice.

```vnef
voice alice_intro.ogg
```

## `volume <channel> <value>`
Sets a channel volume (0.0 to 1.0).

Channels: `master`, `music`, `ambience`, `sfx`, `voice`.

```vnef
volume master 0.8
volume music 0.6
volume ambience 0.5
volume sfx 0.9
```

## Asset Paths
- Music: `assets/music/`
- Ambience: `assets/ambience/`
- SFX: `assets/sfx/`
- Voice: `assets/voice/`
