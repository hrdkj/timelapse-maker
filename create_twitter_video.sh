#!/bin/bash

# Create Twitter-optimized timelapse video from captured images
# - 24fps for smooth playback
# - H.264 codec for maximum compatibility
# - Optimized compression for Twitter

set -e

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
VIDEO_DIR="$PROJECT_DIR/videos"

format_elapsed_time() {
  local total_seconds=$1
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))
  local decimal_hours

  decimal_hours=$(awk "BEGIN { printf \"%.2f\", $total_seconds / 3600 }")
  printf '%s hours (%dh %dm %ds)' "$decimal_hours" "$hours" "$minutes" "$seconds"
}

# Default values
IMAGE_FOLDER="$PROJECT_DIR/timelapse_imgs"
OUTPUT_VIDEO=""
FRAMERATE=24
INTERVAL=30
MUSIC_FILE=""
DEFLICKER=1
STABILIZE=1

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --input|-i)
      IMAGE_FOLDER="$2"
      shift 2
      ;;
    --output|-o)
      OUTPUT_VIDEO="$2"
      shift 2
      ;;
    --framerate|-f)
      FRAMERATE="$2"
      shift 2
      ;;
    --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --music|-m)
      MUSIC_FILE="$2"
      shift 2
      ;;
    --no-deflicker)
      DEFLICKER=0
      shift
      ;;
    --no-stabilize)
      STABILIZE=0
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --input, -i <dir>          Input image folder (default: timelapse_imgs)"
      echo "  --output, -o <file>        Output video file (default: auto-generated)"
      echo "  --framerate, -f <fps>      Video framerate (default: 24)"
      echo "  --interval <seconds>       Capture interval used for the images (default: 30)"
      echo "  --music, -m <file>         Audio file to mix in (looped/trimmed to fit video,"
      echo "                             normalized, with a 2s fade-out). Tip: grab one with"
      echo "                             $PROJECT_DIR/get_music.sh"
      echo "  --no-deflicker             Skip auto-exposure flicker removal (on by default"
      echo "                             via deflicker_frames.py)"
      echo "  --no-stabilize             Skip camera-jitter removal (on by default via"
      echo "                             stabilize_frames.py)"
      echo "  --help, -h                 Show this help message"
      echo ""
      echo "Example: $0 --input timelapse_imgs --interval 30 --music ~/Music/track.mp3"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run '$0 --help' for usage information"
      exit 1
      ;;
  esac
done

# Check music file if provided
if [ -n "$MUSIC_FILE" ] && [ ! -f "$MUSIC_FILE" ]; then
  echo "ERROR: Music file not found: $MUSIC_FILE"
  exit 1
fi

# Check if image folder exists
if [ ! -d "$IMAGE_FOLDER" ]; then
  echo "ERROR: Image folder not found: $IMAGE_FOLDER"
  exit 1
fi

# Count images
NUM_IMAGES=$(find "$IMAGE_FOLDER" -name "*.jpg" | wc -l)
if [ "$NUM_IMAGES" -eq 0 ]; then
  echo "ERROR: No images found in $IMAGE_FOLDER"
  exit 1
fi

# Each frame represents one capture interval, regardless of breaks between sessions.
RECORDING_ELAPSED_SECONDS=$((NUM_IMAGES * INTERVAL))
RECORDING_ELAPSED_TIME=$(format_elapsed_time "$RECORDING_ELAPSED_SECONDS")

# Calculate video duration
VIDEO_DURATION=$(awk "BEGIN { printf \"%.2f\", $NUM_IMAGES / $FRAMERATE }")

echo "=== Creating Twitter-Optimized Video ==="
echo "Input: $IMAGE_FOLDER"
echo "Images: $NUM_IMAGES frames"
echo "Capture interval: ${INTERVAL}s"
echo "Framerate: ${FRAMERATE}fps"
echo "Total recording time: $RECORDING_ELAPSED_TIME"
echo "Expected duration: ${VIDEO_DURATION}s"
echo ""

# Create videos directory
mkdir -p "$VIDEO_DIR"

# Generate output filename if not specified
if [ -z "$OUTPUT_VIDEO" ]; then
  # Use the calculated capture time in the filename and image dates for its date part.
  DURATION_H=$((RECORDING_ELAPSED_SECONDS / 3600))
  REMAINDER_S=$((RECORDING_ELAPSED_SECONDS % 3600))
  DURATION_M=$((REMAINDER_S / 60))

  if [ "$DURATION_H" -gt 0 ]; then
    RECORDING_DURATION="${DURATION_H}h${DURATION_M}m"
  else
    RECORDING_DURATION="${DURATION_M}m"
  fi

  FIRST_IMG=$(find "$IMAGE_FOLDER" -name "*.jpg" | sort -V | head -1)
  LAST_IMG=$(find "$IMAGE_FOLDER" -name "*.jpg" | sort -V | tail -1)
  FIRST_TS=$(stat -c %Y "$FIRST_IMG")
  LAST_TS=$(stat -c %Y "$LAST_IMG")
  FIRST_DATE=$(date -d "@$FIRST_TS" +%Y_%b%d | tr '[:upper:]' '[:lower:]')
  LAST_DATE=$(date -d "@$LAST_TS" +%Y_%b%d | tr '[:upper:]' '[:lower:]')

  if [ "$FIRST_DATE" = "$LAST_DATE" ]; then
    DATE_PART="$FIRST_DATE"
  else
    # Multi-day: session_2024_feb21-22_29h0m.mp4
    LAST_DAY=$(date -d "@$LAST_TS" +%d | tr '[:upper:]' '[:lower:]')
    DATE_PART="$(date -d "@$FIRST_TS" +%Y_%b%d | tr '[:upper:]' '[:lower:]')-${LAST_DAY}"
  fi

  # Format: session_YYYY_monDD_XhYm.mp4 or session_YYYY_monDD-DD_monDD_XhYm.mp4
  OUTPUT_VIDEO="$VIDEO_DIR/session_${DATE_PART}_${RECORDING_DURATION}.mp4"
fi

# Ensure output has .mp4 extension
if [[ ! "$OUTPUT_VIDEO" =~ \.mp4$ ]]; then
  OUTPUT_VIDEO="${OUTPUT_VIDEO}.mp4"
fi

# If output doesn't have a path, put it in videos dir
if [[ ! "$OUTPUT_VIDEO" =~ / ]]; then
  OUTPUT_VIDEO="$VIDEO_DIR/$OUTPUT_VIDEO"
fi

echo "Output: $OUTPUT_VIDEO"
echo ""

# Remove auto-exposure flicker (frame-to-frame brightness jitter) before
# encoding. The phone's AE/AWB varies per snapshot, so neighbor frames can
# differ by 10-20% brightness; deflicker_frames.py smooths each frame
# toward a short-term average while preserving real day/night changes.
DEFLICKER_DIR=""
STABILIZE_DIR=""
if [ "$DEFLICKER" -eq 1 ] || [ "$STABILIZE" -eq 1 ]; then
  PYTHON_BIN="$PROJECT_DIR/.venv/bin/python"
  [ -x "$PYTHON_BIN" ] || PYTHON_BIN="python3"
fi
if [ "$DEFLICKER" -eq 1 ]; then
  DEFLICKER_DIR=$(mktemp -d "${VIDEO_DIR}/deflicker_XXXXXX")
  echo "=== Deflickering $NUM_IMAGES frames (auto-exposure flicker removal) ==="
  "$PYTHON_BIN" "$PROJECT_DIR/deflicker_frames.py" "$IMAGE_FOLDER" "$DEFLICKER_DIR"
  IMAGE_FOLDER="$DEFLICKER_DIR"
  echo ""
fi
if [ "$STABILIZE" -eq 1 ]; then
  STABILIZE_DIR=$(mktemp -d "${VIDEO_DIR}/stabilize_XXXXXX")
  echo "=== Stabilizing $NUM_IMAGES frames (camera-jitter removal) ==="
  "$PYTHON_BIN" "$PROJECT_DIR/stabilize_frames.py" "$IMAGE_FOLDER" "$STABILIZE_DIR"
  IMAGE_FOLDER="$STABILIZE_DIR"
  echo ""
fi

echo "Creating video with optimized settings for Twitter..."

# Create frames list
FRAMES_LIST="$PROJECT_DIR/frames_twitter.txt"
: > "$FRAMES_LIST"
trap 'rm -f "$FRAMES_LIST"; rm -rf "$DEFLICKER_DIR" "$STABILIZE_DIR"' EXIT
find "$IMAGE_FOLDER" -name "*.jpg" | sort -V | while read img; do
  echo "file '$img'" >> "$FRAMES_LIST"
done

# Create video with Twitter-optimized settings
ffmpeg -y \
  -f concat \
  -safe 0 \
  -i "$FRAMES_LIST" \
  -framerate "$FRAMERATE" \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -preset medium \
  -crf 23 \
  -movflags +faststart \
  "$OUTPUT_VIDEO"

# Mix in music if provided: loop if shorter, trim if longer, normalize loudness,
# and fade out over the last 2 seconds.
if [ -n "$MUSIC_FILE" ]; then
  echo "Mixing in music: $MUSIC_FILE"
  FINAL_VIDEO="$OUTPUT_VIDEO"
  OUTPUT_VIDEO="${OUTPUT_VIDEO%.mp4}_with_music.mp4"

  FADE_START=$(echo "scale=2; $VIDEO_DURATION - 2" | bc)
  # Only fade out if the video is long enough to make a fade meaningful.
  if [ "$(echo "$VIDEO_DURATION > 3" | bc)" -eq 1 ]; then
    AUDIO_FILTER="loudnorm,afade=t=out:st=${FADE_START}:d=2"
  else
    AUDIO_FILTER="loudnorm"
  fi

  ffmpeg -y \
    -i "$FINAL_VIDEO" \
    -stream_loop -1 \
    -i "$MUSIC_FILE" \
    -filter_complex "[1:a]${AUDIO_FILTER}[a]" \
    -map 0:v -map "[a]" \
    -t "$VIDEO_DURATION" \
    -c:v copy \
    -c:a aac \
    -b:a 192k \
    -movflags +faststart \
    "$OUTPUT_VIDEO"
  rm -f "$FINAL_VIDEO"
fi

# Get file size
FILE_SIZE=$(du -h "$OUTPUT_VIDEO" | cut -f1)

echo ""
echo "=== Video Created Successfully ==="
echo "Output: $OUTPUT_VIDEO"
echo "Total recording time: $RECORDING_ELAPSED_TIME"
echo "Video duration: ${VIDEO_DURATION}s"
[ "$DEFLICKER" -eq 1 ] && echo "Deflicker: enabled (auto-exposure flicker removed)"
[ "$STABILIZE" -eq 1 ] && echo "Stabilization: enabled (camera jitter removed)"
[ -n "$MUSIC_FILE" ] && echo "Music: $MUSIC_FILE (normalized, 2s fade-out)"
echo "File size: $FILE_SIZE"
echo ""

# Check Twitter limits
VIDEO_SIZE_MB=$(du -m "$OUTPUT_VIDEO" | cut -f1)
if [ "$VIDEO_SIZE_MB" -gt 512 ]; then
  echo "WARNING: File size exceeds Twitter's 512MB limit!"
  echo "Current size: ${VIDEO_SIZE_MB}MB"
  echo ""
fi

DURATION_INT=${VIDEO_DURATION%%.*}
DURATION_INT=${DURATION_INT:-0}
if [ "$DURATION_INT" -gt 140 ]; then
  echo "WARNING: Video duration exceeds Twitter's 140s (2:20) limit!"
  echo "Current duration: ${VIDEO_DURATION}s"
  echo "Consider reducing the recording duration or increasing the interval."
  echo ""
fi

echo "Twitter upload tips:"
echo "  - Max duration: 140 seconds (2:20)"
echo "  - Max file size: 512MB"
echo "  - Supported formats: MP4, MOV"
echo "  - This video is optimized for Twitter with H.264 codec"
echo ""
echo "Ready to upload to Twitter!"
