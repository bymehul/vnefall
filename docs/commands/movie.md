# Command: `movie`

Plays a video as an on-screen layer (background or foreground).

## Usage
```vnef
movie "intro.video"
movie "intro.video" loop
movie "intro.video" wait textbox=wait blur=0.35 layer=fg audio=off
movie "logo.webm" x=80 y=60 w=480 h=270 fit=contain align=center

movie pause
movie resume
movie stop
```

## Options
- `loop`: restarts the video when it ends.
- `hold`: keep the last frame after playback finishes.
- `wait`: block script advancement until the player clicks.
- `layer=bg` or `layer=fg`: draw behind characters (`bg`) or in front of them (`fg`).
- `blur=<0..1>`: dims the background before drawing the video (placeholder blur).
- `x=`, `y=`, `w=`, `h=`: draw the movie in a rectangular region (design-space).
- `fit=stretch|contain|cover`: scaling mode inside the rectangle.
- `align=center|top|bottom|left|right|topleft|topright|bottomleft|bottomright`: alignment inside the rectangle.
- `textbox=hide`: hide the textbox while the video plays.
- `textbox=wait`: hide the textbox and show it on the next click (also implies `wait`).
- `audio=on|off`: auto-plays a matching audio file. Default is `on`.

## Notes
- If the filename has no extension, `.video` is assumed. **Only `.video` is supported**; other extensions are rejected. Convert with `vnef-tools` first.
- Video files are loaded from `path_videos` in `config.vnef` unless an explicit path is used.
- Video audio is auto-mapped from `path_video_audio/<basename>.ogg` when `audio=on`.
- `.video` is the container produced by `vnef-tools` (WebM wrapped with a small header).
- Video audio uses the engine’s audio system (via a dedicated channel). If no matching audio file exists, it stays silent.
- Movies listed in a script are added to the scene manifest and prefetched (first frame) during `scene_next`.
- Enabling video requires the `vnef-video` library and FFmpeg runtime libs.
- Build helper expects `utils/vnef-video/build/libvnef_video.so` (or platform equivalent).
- If you see `Path does not exist: vnef_video`, build with `./build.sh` or pass `-collection:vnefvideo=./utils/vnef-video/bindings` (see `build.sh`).
