#!/usr/bin/env bash
# get-theme-colors.sh - Wrapper around omarchy-theme-color
# Usage:
#   get-theme-colors.sh [--json]          # Output all colors as JSON object (default)
#   get-theme-colors.sh --raw|--all       # Output all colors as tab-separated key-values
#   get-theme-colors.sh --keys            # Output all available color keys as JSON array
#   get-theme-colors.sh <key> [fallback]  # Output single resolved color value

set -euo pipefail

if ! command -v omarchy-theme-color >/dev/null 2>&1; then
  echo "Error: omarchy-theme-color not found in PATH" >&2
  exit 1
fi

MODE="${1:-}"

case "$MODE" in
  ""|"--json")
    omarchy-theme-color --all | jq -R -s -c '
      split("\n")
      | map(select(length > 0) | split("\t"))
      | map(select(length >= 2) | { (.[0]): .[1] })
      | add // {}
    '
    ;;
  "--raw"|"--all")
    omarchy-theme-color --all
    ;;
  "--keys")
    omarchy-theme-color --all | jq -R -s -c '
      split("\n")
      | map(select(length > 0) | split("\t"))
      | map(select(length >= 2) | .[0])
    '
    ;;
  "-h"|"--help")
    echo "Usage: get-theme-colors.sh [--json | --raw | --keys | <key> [fallback]]"
    exit 0
    ;;
  *)
    KEY="$1"
    FALLBACK="${2:-}"
    if [[ -n "$FALLBACK" ]]; then
      omarchy-theme-color "$KEY" "$FALLBACK"
    else
      omarchy-theme-color "$KEY"
    fi
    ;;
esac
