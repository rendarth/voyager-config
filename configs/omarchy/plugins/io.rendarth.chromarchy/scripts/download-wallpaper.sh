#!/usr/bin/env bash
# download-wallpaper.sh - Download wallpaper and optionally downscale to target resolution
# Usage:
#   download-wallpaper.sh <url> [target-path-or-dir] [target-resolution]
# Or:
#   download-wallpaper.sh --url <url> [--out <path>] [--res <WxH>] [--id <id>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/chromarchy/wallpapers"

URL=""
TARGET_PATH=""
RESOLUTION="auto"
WP_ID=""

# Parse arguments (flags or positional)
if [[ $# -gt 0 && "$1" =~ ^-- ]]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --url|-u)
        URL="$2"; shift 2 ;;
      --out|-o)
        TARGET_PATH="$2"; shift 2 ;;
      --res|-r)
        RESOLUTION="$2"; shift 2 ;;
      --id)
        WP_ID="$2"; shift 2 ;;
      -h|--help)
        echo "Usage: download-wallpaper.sh <url> [target-dir-or-file] [resolution]"
        echo "   Or: download-wallpaper.sh --url <url> [--out <dir-or-file>] [--res <WxH>]"
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
  done
else
  URL="${1:-}"
  TARGET_PATH="${2:-}"
  RESOLUTION="${3:-auto}"
fi

if [[ -z "$URL" ]]; then
  echo "Error: No URL provided to download-wallpaper.sh" >&2
  exit 1
fi

# Resolve resolution
if [[ "$RESOLUTION" == "auto" ]]; then
  if [[ -x "$SCRIPT_DIR/detect-resolution.sh" ]]; then
    RESOLUTION="$("$SCRIPT_DIR/detect-resolution.sh")"
  else
    RESOLUTION="1920x1080"
  fi
fi

# Determine filename
FILENAME=""
if [[ -n "$WP_ID" ]]; then
  EXT="${URL##*.}"
  if [[ "$EXT" != "jpg" && "$EXT" != "png" && "$EXT" != "jpeg" && "$EXT" != "webp" ]]; then
    EXT="jpg"
  fi
  FILENAME="wallhaven-${WP_ID}.${EXT}"
else
  # Extract from URL
  URL_PATH="${URL%%\?*}"
  FILENAME="$(basename "$URL_PATH")"
  if [[ -z "$FILENAME" || "$FILENAME" == "/" ]]; then
    FILENAME="wallpaper-$(date +%s).jpg"
  fi
fi

# Determine final destination file
FINAL_FILE=""
if [[ -z "$TARGET_PATH" ]]; then
  mkdir -p "$DEFAULT_CACHE_DIR"
  FINAL_FILE="$DEFAULT_CACHE_DIR/$FILENAME"
elif [[ -d "$TARGET_PATH" || "$TARGET_PATH" == */ ]]; then
  mkdir -p "$TARGET_PATH"
  FINAL_FILE="${TARGET_PATH%/}/$FILENAME"
else
  mkdir -p "$(dirname "$TARGET_PATH")"
  FINAL_FILE="$TARGET_PATH"
fi

FINAL_FILE="$(realpath -m "$FINAL_FILE")"

# Check if cached file already exists and is non-empty
if [[ -s "$FINAL_FILE" ]]; then
  # Cache hit!
  echo "$FINAL_FILE"
  exit 0
fi

# Temporary download file
TMP_DOWNLOAD=$(mktemp --suffix=".tmp-$(basename "$FINAL_FILE")")
trap 'rm -f "$TMP_DOWNLOAD"' EXIT

# Perform download with curl
if [[ "$URL" =~ ^https?:// ]]; then
  if ! curl -s -S -f -L -A "Chromarchy/1.0 (Omarchy Wallpaper Plugin)" -o "$TMP_DOWNLOAD" "$URL"; then
    echo "Error: Failed to download wallpaper from: $URL" >&2
    exit 1
  fi
elif [[ -f "$URL" ]]; then
  # Local file source
  cp "$URL" "$TMP_DOWNLOAD"
else
  echo "Error: Invalid URL or file not found: $URL" >&2
  exit 1
fi

# Validate downloaded file size
if [[ ! -s "$TMP_DOWNLOAD" ]]; then
  echo "Error: Downloaded file is empty" >&2
  exit 1
fi

# Check ImageMagick availability
IM_CMD=""
if command -v magick >/dev/null 2>&1; then
  IM_CMD="magick"
elif command -v convert >/dev/null 2>&1; then
  IM_CMD="convert"
fi

# Optional downscaling
if [[ -n "$IM_CMD" && "$RESOLUTION" =~ ^[0-9]+x[0-9]+$ ]]; then
  TARGET_WIDTH="${RESOLUTION%x*}"
  TARGET_HEIGHT="${RESOLUTION#*x}"

  # Get image dimensions
  IMG_DIMS=$($IM_CMD identify -format "%wx%h" "$TMP_DOWNLOAD" 2>/dev/null || true)
  if [[ "$IMG_DIMS" =~ ^[0-9]+x[0-9]+$ ]]; then
    IMG_W="${IMG_DIMS%x*}"
    IMG_H="${IMG_DIMS#*x}"

    if (( IMG_W > TARGET_WIDTH || IMG_H > TARGET_HEIGHT )); then
      # Downscale only if larger than target resolution
      $IM_CMD "$TMP_DOWNLOAD" -resize "${TARGET_WIDTH}x${TARGET_HEIGHT}>" "$FINAL_FILE"
      echo "$FINAL_FILE"
      exit 0
    fi
  fi
fi

# If no downscaling needed or ImageMagick unavailable
mv "$TMP_DOWNLOAD" "$FINAL_FILE"
echo "$FINAL_FILE"
exit 0
