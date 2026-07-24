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
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --input, -i <dir>          Input image folder (default: timelapse_imgs)"
      echo "  --output, -o <file>        Output video file (default: auto-generated)"
      echo "  --framerate, -f <fps>      Video framerate (default: 24)"
      echo "  --interval <seconds>       Capture interval used for the images (default: 30)"
      echo "  --help, -h                 Show this help message"
      echo ""
      echo "Example: $0 --input timelapse_imgs --interval 30 --output my_session.mp4"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run '$0 --help' for usage information"
      exit 1
      ;;
  esac
done

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
VIDEO_DURATION=$(echo "scale=2; $NUM_IMAGES / $FRAMERATE" | bc)

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
echo "Creating video with optimized settings for Twitter..."

# Use create_timelapse.py but with modified settings for 24fps
cd "$PROJECT_DIR"

# Create frames list
FRAMES_LIST="$PROJECT_DIR/frames_twitter.txt"
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

# Clean up
rm -f "$FRAMES_LIST"

# Get file size
FILE_SIZE=$(du -h "$OUTPUT_VIDEO" | cut -f1)

echo ""
echo "=== Video Created Successfully ==="
echo "Output: $OUTPUT_VIDEO"
echo "Total recording time: $RECORDING_ELAPSED_TIME"
echo "Video duration: ${VIDEO_DURATION}s"
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
