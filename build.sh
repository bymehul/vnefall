#!/bin/bash
# Vnefall build script

set -e

usage() {
  cat <<'USAGE'
Usage:
  ./build.sh [--prep-videos <src> <out> [video-options]]

Options:
  --prep-videos <src> <out>   Run the Odin video builder before compiling.
  --recursive                Scan input directory recursively
  --keep-webm                 Keep intermediate .webm files
  --force                     Overwrite outputs if they exist
  --audio                     Keep audio (Opus)
  --audio-bitrate <k>         Opus bitrate in kbps
  --crf <n>                   VP9 quality (lower=better)
  --deadline <mode>           realtime|good|best
  --cpu-used <n>              VP9 speed/quality tradeoff (0-8)
  --ffmpeg <path>             Path to ffmpeg binary
USAGE
}

PREP_VIDEOS=0
VIDEO_SRC=""
VIDEO_OUT=""
VIDEO_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prep-videos)
      PREP_VIDEOS=1
      VIDEO_SRC="$2"
      VIDEO_OUT="$3"
      shift 3
      ;;
    --recursive|--keep-webm|--force|--audio)
      VIDEO_ARGS+=("$1")
      shift
      ;;
    --audio-bitrate|--crf|--deadline|--cpu-used|--ffmpeg)
      VIDEO_ARGS+=("$1" "$2")
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$PREP_VIDEOS" == "1" ]]; then
  if [[ -z "$VIDEO_SRC" || -z "$VIDEO_OUT" ]]; then
    echo "Error: --prep-videos requires <src> and <out>."
    usage
    exit 1
  fi
  echo "Preparing videos..."
  odin run utils/vnef-tools/build_videos.odin -- "$VIDEO_SRC" "$VIDEO_OUT" "${VIDEO_ARGS[@]}"
fi

echo "Building Vnefall..."
if [ ! -f ./utils/vnef-video/build/libvnef_video.so ]; then
  echo "Building vnef-video (requires FFmpeg dev libs)..."
  cmake -S ./utils/vnef-video -B ./utils/vnef-video/build
  cmake --build ./utils/vnef-video/build
fi

if [ -f ./utils/vnef-video/build/libvnef_video.so ]; then
  cp ./utils/vnef-video/build/libvnef_video.so ./libvnef_video.so
fi
odin build src -out:vnefall -debug \
  -collection:vneui=./vneui \
  -collection:vnefvideo=./utils/vnef-video/bindings \
  -extra-linker-flags:"-L./utils/vnef-video/build -lvnef_video"

echo "Done. Run with: ./vnefall demo/assets/scripts/demo_game.vnef"
