#!/bin/bash

# Download a music track with yt-dlp and print its path, ready for
# create_twitter_video.sh --music.

# Usage:
#   get_music.sh <URL>            Download audio from a video/music URL
#   get_music.sh "search query"   Search and download the best match
#   get_music.sh --search "query" Same as above, explicit

# Good legal sources (all work with yt-dlp):
#   - YouTube Audio Library: https://music.youtube.com or youtube.com/audiolibrary
#   - Pixabay Music: https://pixabay.com/music
#   - Free Music Archive: https://freemusicarchive.org

set -e

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
MUSIC_DIR="$PROJECT_DIR/music"

# Default to best quality audio, embed metadata and thumbnail, convert to mp3.
YTDLP_OPTS=(-x --audio-format mp3 --audio-quality 0 --embed-metadata --embed-thumbnail)

if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  echo "Usage:"
  echo "  $0 <URL>             Download audio from a URL"
  echo "  $0 \"search query\"    Search YouTube and download the best match"
  echo "  $0 --search \"query\"  Explicit search"
  echo ""
  echo "Downloads to: $MUSIC_DIR/"
  echo "Then use with: create_twitter_video.sh --music <path>"
  exit 0
fi

mkdir -p "$MUSIC_DIR"

if [[ "$1" == "--search" ]]; then
  QUERY="${*:2}"
  if [[ -z "$QUERY" ]]; then
    echo "ERROR: --search requires a query"
    exit 1
  fi
  TARGET="ytsearch1:$QUERY"
elif [[ "$1" =~ ^https?:// ]]; then
  TARGET="$1"
else
  # Bare word(s) that don't look like a URL -> treat as search
  TARGET="ytsearch1:$*"
fi

echo "Downloading: $TARGET"
echo "Destination: $MUSIC_DIR/"
echo ""

cd "$MUSIC_DIR"
yt-dlp "${YTDLP_OPTS[@]}" -o "%(title)s.%(ext)s" "$TARGET"

# Report the newest file so the user can feed it straight into the video script
NEWEST=$(ls -t "$MUSIC_DIR"/*.mp3 2>/dev/null | head -1)
if [ -n "$NEWEST" ]; then
  echo ""
  echo "Done: $NEWEST"
  echo "Mix it in with: $PROJECT_DIR/create_twitter_video.sh --music \"$NEWEST\""
fi
