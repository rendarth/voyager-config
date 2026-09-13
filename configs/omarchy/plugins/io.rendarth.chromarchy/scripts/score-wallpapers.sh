#!/usr/bin/env bash
# score-wallpapers.sh - Score Wallhaven wallpaper results against Omarchy theme colors
# Usage:
#   score-wallpapers.sh <wallhaven-json-file> <theme-colors-comma-separated> [options]
#   cat wallhaven.json | score-wallpapers.sh - <theme-colors-comma-separated> [options]
#   cat wallhaven.json | score-wallpapers.sh <theme-colors-comma-separated> [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/score_wallpapers.py" "$@"
