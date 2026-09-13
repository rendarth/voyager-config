#!/usr/bin/env bash
# save-wallpaper.sh - Save wallpaper from cache into Omarchy backgrounds or saved-wallpapers
# Usage:
#   save-wallpaper.sh <source-image-path> [behavior: rotate|save-only] [theme-name]
# Or:
#   save-wallpaper.sh --file <path> [--behavior rotate|save-only] [--theme <name>]

set -euo pipefail

SOURCE_FILE=""
BEHAVIOR="rotate"
THEME_NAME=""

# Parse flags or positional arguments
if [[ $# -gt 0 && "$1" =~ ^-- ]]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file|-f)
        SOURCE_FILE="$2"; shift 2 ;;
      --behavior|-b)
        BEHAVIOR="$2"; shift 2 ;;
      --theme|-t)
        THEME_NAME="$2"; shift 2 ;;
      -h|--help)
        echo "Usage: save-wallpaper.sh <file> [rotate|save-only] [theme]"
        echo "   Or: save-wallpaper.sh --file <path> [--behavior rotate|save-only] [--theme <name>]"
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
  done
else
  SOURCE_FILE="${1:-}"
  BEHAVIOR="${2:-rotate}"
  THEME_NAME="${3:-}"
fi

if [[ -z "$SOURCE_FILE" ]]; then
  echo "Error: No source wallpaper path specified" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "Error: Source wallpaper file does not exist: $SOURCE_FILE" >&2
  exit 1
fi

# Detect theme name if not specified
if [[ -z "$THEME_NAME" ]]; then
  THEME_FILE="$HOME/.local/state/omarchy/current/theme.name"
  if [[ -f "$THEME_FILE" ]]; then
    THEME_NAME=$(cat "$THEME_FILE" 2>/dev/null | tr -d '\r\n')
  fi
fi

if [[ -z "$THEME_NAME" ]]; then
  THEME_NAME="default"
fi

# Sanitize theme slug to prevent path traversal
THEME_SLUG=$(echo "$THEME_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]_.-')
if [[ -z "$THEME_SLUG" || "$THEME_SLUG" == "." || "$THEME_SLUG" == ".." ]]; then
  THEME_SLUG="default"
fi

# Determine target directory based on behavior
BASE_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
case "${BEHAVIOR,,}" in
  "save-only"|"save_only"|"only"|"saved")
    TARGET_DIR="$BASE_CONFIG/saved-wallpapers/$THEME_SLUG"
    ;;
  "rotate"|"save-and-rotate"|"save_and_rotate"|"backgrounds"|*)
    TARGET_DIR="$BASE_CONFIG/backgrounds/$THEME_SLUG"
    ;;
esac

mkdir -p "$TARGET_DIR"

FILENAME="$(basename "$SOURCE_FILE")"
DEST_FILE="$TARGET_DIR/$FILENAME"

# If already identical or same file
if [[ -e "$DEST_FILE" ]]; then
  if [[ "$SOURCE_FILE" -ef "$DEST_FILE" ]]; then
    # Already hardlinked to same file
    echo "$DEST_FILE"
    exit 0
  fi
  rm -f "$DEST_FILE"
fi

# Try hardlink, fallback to copy if cross-filesystem or unsupported
if ! ln "$SOURCE_FILE" "$DEST_FILE" 2>/dev/null; then
  cp "$SOURCE_FILE" "$DEST_FILE"
fi

echo "$DEST_FILE"
exit 0
