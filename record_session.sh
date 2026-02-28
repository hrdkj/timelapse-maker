#!/bin/bash

# Wrapper script for recording study/work sessions with optimized settings
# - 720p resolution
# - 30-second intervals
# - Timestamp overlay (HH:MM)
# - Uses virtual webcam at /dev/video20 (IP Webcam)

set -e

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Default values optimized for study/work sessions
HOURS=8
INTERVAL=30
WIDTH=1280
HEIGHT=720
OUTPUT_DIR="$PROJECT_DIR/timelapse_imgs"
PHONE_IP=""
PHONE_PORT=8080

# Parse optional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --hours|-H)
      HOURS="$2"
      shift 2
      ;;
    --interval|-i)
      INTERVAL="$2"
      shift 2
      ;;
    --output-dir|-o)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --phone-ip|-p)
      PHONE_IP="$2"
      shift 2
      ;;
    --phone-port)
      PHONE_PORT="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --hours, -H <hours>        Duration in hours (default: 8)"
      echo "  --interval, -i <seconds>   Interval between frames (default: 30)"
      echo "  --output-dir, -o <dir>     Output directory (default: timelapse_imgs)"
      echo "  --phone-ip, -p <ip>        IP address of phone running IP Webcam app"
      echo "                             (efficient snapshot mode - saves battery/network)"
      echo "  --phone-port <port>        IP Webcam port (default: 8080)"
      echo "  --help, -h                 Show this help message"
      echo ""
      echo "Optimized settings for study/work timelapses:"
      echo "  - Resolution: 1280x720 (720p)"
      echo "  - Timestamp overlay: HH:MM (military time, top-left)"
      echo "  - Uses virtual webcam at /dev/video20 (IP Webcam)"
      echo ""
      echo "Example: $0 --hours 6 --interval 45"
      echo "Example: $0 --phone-ip 192.168.1.100 --hours 4  (uses efficient snapshot mode)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run '$0 --help' for usage information"
      exit 1
      ;;
  esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Calculate expected output
TOTAL_SECONDS=$((HOURS * 3600))
NUM_FRAMES=$((TOTAL_SECONDS / INTERVAL))
VIDEO_DURATION_24FPS=$(echo "scale=1; $NUM_FRAMES / 24" | bc)

echo "=== Study/Work Session Recording ==="
echo "Duration: $HOURS hours"
echo "Interval: $INTERVAL seconds"
echo "Resolution: ${WIDTH}x${HEIGHT}"
echo "Output: $OUTPUT_DIR"
echo ""
echo "Expected: ~$NUM_FRAMES frames → ~${VIDEO_DURATION_24FPS}s video at 24fps"
echo ""

# Check if virtual webcam exists (only if not using phone snapshot mode)
if [ -z "$PHONE_IP" ] && [ ! -e /dev/video20 ]; then
  echo "WARNING: Virtual webcam /dev/video20 not found!"
  echo "Make sure to run './start_phone_stream.sh' first to set up IP Webcam"
  echo "OR use --phone-ip to capture directly from the phone (more efficient)"
  echo ""
  read -p "Do you want to continue anyway? (y/n): " CONTINUE
  if [[ ! $CONTINUE =~ ^[Yy] ]]; then
    exit 1
  fi
fi

if [ -n "$PHONE_IP" ]; then
  echo "Using efficient snapshot mode: http://$PHONE_IP:$PHONE_PORT/shot.jpg"
  echo "(No continuous streaming - saves battery and network bandwidth)"
  echo ""
fi

# Check for existing images
RESUME=false
if [ -n "$(find "$OUTPUT_DIR" -maxdepth 1 -name "*.jpg" -type f 2>/dev/null)" ]; then
  echo "Found existing images in $OUTPUT_DIR"
  echo "Do you want to:"
  echo "  1) Remove them and start fresh"
  echo "  2) Resume from last frame"
  echo "  3) Cancel"
  read -p "Choose (1/2/3): " choice
  case $choice in
    1)
      rm -f "$OUTPUT_DIR"/*.jpg
      echo "Cleanup complete. Starting fresh."
      ;;
    2)
      RESUME=true
      echo "Continuing from last frame..."
      ;;
    3)
      echo "Cancelled."
      exit 0
      ;;
    *)
      echo "Invalid choice. Cancelling."
      exit 1
      ;;
  esac
fi

# Build command
CMD="uv run capture_timelapse.py --hours $HOURS --interval $INTERVAL --output-dir \"$OUTPUT_DIR\" --width $WIDTH --height $HEIGHT --add-timestamp"

# Add phone IP if specified (efficient snapshot mode)
if [ -n "$PHONE_IP" ]; then
  CMD="$CMD --phone-ip $PHONE_IP --phone-port $PHONE_PORT"
fi

# Add resume flag if needed
if [ "$RESUME" = true ]; then
  CMD="$CMD --resume"
fi

echo ""
echo "Starting recording..."
echo "Press Ctrl+C to stop early"
echo ""

# Run the capture
cd "$PROJECT_DIR" && eval $CMD

echo ""
echo "Recording completed!"
echo "Frames saved to: $OUTPUT_DIR"
echo ""
echo "To create a video, run:"
echo "  ./create_twitter_video.sh"
