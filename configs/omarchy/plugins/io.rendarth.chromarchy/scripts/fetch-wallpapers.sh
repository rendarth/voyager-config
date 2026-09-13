#!/usr/bin/env bash
# fetch-wallpapers.sh - Query Wallhaven API for wallpapers
# Usage:
#   fetch-wallpapers.sh <color> [keywords] [categories] [purity] [atleast] [page]
# Or using flags:
#   fetch-wallpapers.sh --color <hex> --keywords <kw> --categories <cat> --purity <purity> --atleast <res> --page <p> --seed <s>

set -euo pipefail

WALLHAVEN_API_BASE="https://wallhaven.cc/api/v1/search"

# Supported Wallhaven palette hex codes (29 colors)
# Wallhaven API returns 0 results if an unindexed hex is sent to &colors=
WALLHAVEN_COLORS=(
  "660000" "990000" "cc0000" "cc3333" "ea4c88" "993399" "663399" "333399"
  "0066cc" "0099cc" "66cccc" "77cc33" "669900" "336600" "666600" "999900"
  "cccc33" "ffff00" "ffcc33" "ff9900" "ff6600" "cc6633" "996633" "663300"
  "000000" "999999" "cccccc" "ffffff" "424153"
)

# Snap hex to nearest supported Wallhaven color
snap_to_wallhaven_color() {
  local target="${1#"#"}"
  target="${target,,}" # lowercase

  # If empty or none, return empty
  if [[ -z "$target" || "$target" == "none" ]]; then
    return 0
  fi

  # Validate 6 hex chars
  if [[ ! "$target" =~ ^[0-9a-f]{6}$ ]]; then
    echo "$target"
    return 0
  fi

  # Check if already exact match
  for c in "${WALLHAVEN_COLORS[@]}"; do
    if [[ "$target" == "$c" ]]; then
      echo "$target"
      return 0
    fi
  done

  # Find closest via Euclidean distance in RGB
  local r_t=$((16#${target:0:2}))
  local g_t=$((16#${target:2:2}))
  local b_t=$((16#${target:4:2}))

  local best_color="${WALLHAVEN_COLORS[0]}"
  local min_dist=999999999

  for c in "${WALLHAVEN_COLORS[@]}"; do
    local r_c=$((16#${c:0:2}))
    local g_c=$((16#${c:2:2}))
    local b_c=$((16#${c:4:2}))

    local dr=$((r_t - r_c))
    local dg=$((g_t - g_c))
    local db=$((b_t - b_c))
    local dist=$((dr*dr + dg*dg + db*db))

    if (( dist < min_dist )); then
      min_dist=$dist
      best_color="$c"
    fi
  done

  echo "$best_color"
}

# Normalize categories to 3-digit bitmask
normalize_categories() {
  local val="${1:-100}"
  case "${val,,}" in
    "general") echo "100" ;;
    "anime") echo "010" ;;
    "people") echo "001" ;;
    "general+anime"|"anime+general") echo "110" ;;
    "all"|"111") echo "111" ;;
    *)
      if [[ "$val" =~ ^[01]{3}$ ]]; then
        echo "$val"
      else
        echo "100"
      fi
      ;;
  esac
}

# Normalize purity to 3-digit bitmask
normalize_purity() {
  local val="${1:-100}"
  case "${val,,}" in
    "sfw") echo "100" ;;
    "sketchy") echo "010" ;;
    "sfw+sketchy"|"sketchy+sfw") echo "110" ;;
    "all"|"111"|"nsfw") echo "111" ;;
    *)
      if [[ "$val" =~ ^[01]{3}$ ]]; then
        echo "$val"
      else
        echo "100"
      fi
      ;;
  esac
}

# Default variables
COLOR=""
KEYWORDS=""
CATEGORIES="100"
PURITY="100"
ATLEAST="1920x1080"
PAGE="1"
SEED=""
SORTING="random"

# Parse CLI arguments (support flags or positional)
if [[ $# -gt 0 && "$1" =~ ^-- ]]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --color|-c)
        COLOR="$2"; shift 2 ;;
      --keywords|-q)
        KEYWORDS="$2"; shift 2 ;;
      --categories)
        CATEGORIES="$2"; shift 2 ;;
      --purity)
        PURITY="$2"; shift 2 ;;
      --atleast)
        ATLEAST="$2"; shift 2 ;;
      --page|-p)
        PAGE="$2"; shift 2 ;;
      --seed|-s)
        SEED="$2"; shift 2 ;;
      --sorting)
        SORTING="$2"; shift 2 ;;
      -h|--help)
        echo "Usage: fetch-wallpapers.sh [color] [keywords] [categories] [purity] [atleast] [page]"
        echo "   Or: fetch-wallpapers.sh --color <hex> --keywords <kw> --categories <100> --purity <100> --atleast <WxH> --page <n>"
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
  done
else
  COLOR="${1:-}"
  KEYWORDS="${2:-}"
  CATEGORIES="${3:-100}"
  PURITY="${4:-100}"
  ATLEAST="${5:-1920x1080}"
  PAGE="${6:-1}"
  SEED="${7:-}"
fi

# Auto-detect resolution if specified as auto
if [[ "$ATLEAST" == "auto" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -x "$SCRIPT_DIR/detect-resolution.sh" ]]; then
    ATLEAST="$("$SCRIPT_DIR/detect-resolution.sh")"
  else
    ATLEAST="1920x1080"
  fi
fi

# Clean color input and snap to Wallhaven palette
SNAPPED_COLOR=""
if [[ -n "$COLOR" && "$COLOR" != "none" ]]; then
  CLEAN_COLOR="${COLOR#"#"}"
  SNAPPED_COLOR=$(snap_to_wallhaven_color "$CLEAN_COLOR")
fi

CATEGORIES=$(normalize_categories "$CATEGORIES")
PURITY=$(normalize_purity "$PURITY")

# Build query URL
QUERY_PARAMS="sorting=${SORTING}&categories=${CATEGORIES}&purity=${PURITY}&atleast=${ATLEAST}&page=${PAGE}"

if [[ -n "$SNAPPED_COLOR" ]]; then
  QUERY_PARAMS="${QUERY_PARAMS}&colors=${SNAPPED_COLOR}"
fi

if [[ -n "$KEYWORDS" ]]; then
  ENCODED_KW=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$KEYWORDS")
  QUERY_PARAMS="${QUERY_PARAMS}&q=${ENCODED_KW}"
fi

if [[ -n "$SEED" ]]; then
  QUERY_PARAMS="${QUERY_PARAMS}&seed=${SEED}"
fi

URL="${WALLHAVEN_API_BASE}?${QUERY_PARAMS}"

# Execute curl request with retry on transient 5xx errors
TMP_BODY=$(mktemp)
TMP_HEADER=$(mktemp)
trap 'rm -f "$TMP_BODY" "$TMP_HEADER"' EXIT

MAX_ATTEMPTS=3
ATTEMPT=1
HTTP_CODE=""

while (( ATTEMPT <= MAX_ATTEMPTS )); do
  HTTP_CODE=$(curl -s -S -w "%{http_code}" -o "$TMP_BODY" -D "$TMP_HEADER" "$URL" || echo "CURL_ERROR")

  if [[ "$HTTP_CODE" == "200" ]]; then
    break
  fi

  # Retry on 502, 503, 504
  if [[ "$HTTP_CODE" =~ ^(502|503|504)$ ]] && (( ATTEMPT < MAX_ATTEMPTS )); then
    sleep 1
    ATTEMPT=$((ATTEMPT + 1))
    continue
  fi

  break
done

if [[ "$HTTP_CODE" == "CURL_ERROR" ]]; then
  echo "Error: Network connectivity failure contacting Wallhaven" >&2
  exit 2
fi

if [[ "$HTTP_CODE" == "429" ]]; then
  echo "Error: Wallhaven rate limit exceeded (HTTP 429). Max 45 req/min." >&2
  cat "$TMP_BODY" >&2
  exit 42
fi

if [[ "$HTTP_CODE" -ge 400 ]]; then
  echo "Error: Wallhaven API error (HTTP $HTTP_CODE)" >&2
  cat "$TMP_BODY" >&2
  exit 1
fi

# Validate output is valid JSON
if ! jq empty "$TMP_BODY" 2>/dev/null; then
  echo "Error: Received invalid JSON response from Wallhaven" >&2
  exit 1
fi

# If both color and keywords were specified and returned 0 results, retry without color restriction
# (local Delta-E scoring will still pick the closest theme-matching results from the keyword matches)
if [[ -n "$SNAPPED_COLOR" && -n "$KEYWORDS" ]]; then
  DATA_LEN=$(jq '.data | length' "$TMP_BODY" 2>/dev/null || echo "0")
  if [[ "$DATA_LEN" -eq 0 ]]; then
    FALLBACK_PARAMS="sorting=${SORTING}&categories=${CATEGORIES}&purity=${PURITY}&atleast=${ATLEAST}&page=${PAGE}&q=${ENCODED_KW}"
    if [[ -n "$SEED" ]]; then
      FALLBACK_PARAMS="${FALLBACK_PARAMS}&seed=${SEED}"
    fi
    FALLBACK_URL="${WALLHAVEN_API_BASE}?${FALLBACK_PARAMS}"
    curl -s -S "$FALLBACK_URL" -o "$TMP_BODY" 2>/dev/null || true
  fi
fi

# Output JSON to stdout
cat "$TMP_BODY"
exit 0
