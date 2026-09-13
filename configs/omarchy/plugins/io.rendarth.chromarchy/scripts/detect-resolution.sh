#!/usr/bin/env bash
# detect-resolution.sh - Detect display resolutions under Hyprland / Wayland
# Usage:
#   detect-resolution.sh          # Outputs primary/focused monitor resolution (e.g. 2560x1440)
#   detect-resolution.sh --json   # Outputs JSON array of all active monitors
#   detect-resolution.sh --all    # Outputs all monitor resolutions line by line
#   detect-resolution.sh -h       # Show help

set -euo pipefail

MODE="${1:-}"

if [[ "$MODE" == "-h" || "$MODE" == "--help" ]]; then
  echo "Usage: detect-resolution.sh [--json | --all]"
  exit 0
fi

# Try hyprctl monitors -j
if command -v hyprctl >/dev/null 2>&1; then
  MONITORS_JSON=$(hyprctl monitors -j 2>/dev/null || echo "[]")
  if [[ "$MONITORS_JSON" != "[]" && "$MONITORS_JSON" != "" ]]; then
    if [[ "$MODE" == "--json" ]]; then
      echo "$MONITORS_JSON" | jq -c '
        map({
          id: .id,
          name: .name,
          width: .width,
          height: .height,
          resolution: "\(.width)x\(.height)",
          focused: .focused,
          scale: .scale
        })
      '
      exit 0
    elif [[ "$MODE" == "--all" ]]; then
      echo "$MONITORS_JSON" | jq -r '.[] | "\(.name):\(.width)x\(.height)"'
      exit 0
    else
      PRIMARY_RES=$(echo "$MONITORS_JSON" | jq -r '(map(select(.focused == true))[0] // .[0]) | "\(.width)x\(.height)"' 2>/dev/null || true)
      if [[ -n "$PRIMARY_RES" && "$PRIMARY_RES" != "null" && "$PRIMARY_RES" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo "$PRIMARY_RES"
        exit 0
      fi
    fi
  fi
fi

# Fallback: wlr-randr
if command -v wlr-randr >/dev/null 2>&1; then
  WLR_OUT=$(wlr-randr --json 2>/dev/null || true)
  if [[ -n "$WLR_OUT" ]]; then
    if [[ "$MODE" == "--json" ]]; then
      echo "$WLR_OUT" | jq -c '
        map({
          name: .name,
          width: (.modes[] | select(.current == true).width),
          height: (.modes[] | select(.current == true).height),
          resolution: "\((.modes[] | select(.current == true).width))x\((.modes[] | select(.current == true).height))",
          focused: false
        })
      '
      exit 0
    fi
    WLR_RES=$(echo "$WLR_OUT" | jq -r '.[0].modes[] | select(.current == true) | "\(.width)x\(.height)"' 2>/dev/null || true)
    if [[ -n "$WLR_RES" && "$WLR_RES" =~ ^[0-9]+x[0-9]+$ ]]; then
      echo "$WLR_RES"
      exit 0
    fi
  fi
fi

# Ultimate fallback
if [[ "$MODE" == "--json" ]]; then
  echo '[{"name":"default","width":1920,"height":1080,"resolution":"1920x1080","focused":true}]'
elif [[ "$MODE" == "--all" ]]; then
  echo "default:1920x1080"
else
  echo "1920x1080"
fi
exit 0
