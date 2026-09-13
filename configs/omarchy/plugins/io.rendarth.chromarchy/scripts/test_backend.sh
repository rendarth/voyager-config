#!/usr/bin/env bash
# test_backend.sh - Automated unit & integration tests for Chromarchy backend scripts

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="$SCRIPT_DIR/fixtures/mock_wallhaven.json"
PASS=0
FAIL=0

run_test() {
  local desc="$1"
  shift
  echo -n "Testing $desc... "
  if output=$("$@" 2>&1); then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL"
    echo "  Command: $*"
    echo "  Output: $output"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Chromarchy Backend Test Suite ==="

# 1. get-theme-colors.sh
run_test "get-theme-colors.sh JSON output" bash -c \
  "$SCRIPT_DIR/get-theme-colors.sh --json | jq -e '.accent and .background'"

run_test "get-theme-colors.sh single color key" bash -c \
  "val=\$($SCRIPT_DIR/get-theme-colors.sh accent); [[ \$val =~ ^#[0-9a-fA-F]{6}$ ]]"

run_test "get-theme-colors.sh --keys array" bash -c \
  "$SCRIPT_DIR/get-theme-colors.sh --keys | jq -e 'length > 5 and .[0]'"

# 2. detect-resolution.sh
run_test "detect-resolution.sh standard output" bash -c \
  "res=\$($SCRIPT_DIR/detect-resolution.sh); [[ \$res =~ ^[0-9]+x[0-9]+$ ]]"

run_test "detect-resolution.sh --json output" bash -c \
  "$SCRIPT_DIR/detect-resolution.sh --json | jq -e '.[0].width and .[0].height'"

# 3. score-wallpapers.sh Unit Tests (Mock Data)
run_test "score-wallpapers.sh Delta-E scoring (mock)" bash -c \
  "$SCRIPT_DIR/score-wallpapers.sh '$FIXTURE' '#5a7a7a,#1a1e1e' --metric delta-e | \
   jq -e 'length == 3 and (.[0].id == \"mock01\" or .[0].id == \"mock03\") and (.[0].score < .[2].score)'"

run_test "score-wallpapers.sh RGB scoring (mock)" bash -c \
  "$SCRIPT_DIR/score-wallpapers.sh '$FIXTURE' '#5a7a7a,#1a1e1e' --metric rgb | \
   jq -e 'length == 3 and .[0].score_details.metric == \"rgb\"'"

run_test "score-wallpapers.sh complementary scoring (mock)" bash -c \
  "$SCRIPT_DIR/score-wallpapers.sh '$FIXTURE' '#ff0000' --complementary | \
   jq -e 'length == 3 and .[0].score_details.matches[0].theme_color == \"#00ffff\"'"

run_test "score-wallpapers.sh deduplication via --exclude-ids" bash -c \
  "$SCRIPT_DIR/score-wallpapers.sh '$FIXTURE' '#5a7a7a' --exclude-ids 'mock01' | \
   jq -e 'length == 2 and all(.[]; .id != \"mock01\")'"

run_test "score-wallpapers.sh --top limit" bash -c \
  "$SCRIPT_DIR/score-wallpapers.sh '$FIXTURE' '#5a7a7a' --top 2 | \
   jq -e 'length == 2'"

# 4. fetch-wallpapers.sh Live Queries
run_test "fetch-wallpapers.sh theme-color snapping & search (live)" bash -c \
  "$SCRIPT_DIR/fetch-wallpapers.sh '#5a7a7a' 'nature' 100 100 1920x1080 1 | jq -e '.data | length > 0'"

run_test "fetch-wallpapers.sh flags mode with auto resolution (live)" bash -c \
  "$SCRIPT_DIR/fetch-wallpapers.sh --color 663399 --keywords space --atleast auto | jq -e '.data | length > 0'"

# 5. Pipeline: fetch | score (live integration)
run_test "Pipeline: fetch | score Delta-E (live)" bash -c \
  "$SCRIPT_DIR/fetch-wallpapers.sh 663399 space 100 100 1920x1080 1 | \
   $SCRIPT_DIR/score-wallpapers.sh - '#663399,#000000' --top 3 --metric delta-e | \
   jq -e 'length == 3 and (.[0].score <= .[1].score)'"

# 6. download-wallpaper.sh
run_test "download-wallpaper.sh download and resize" bash -c \
  "file=\$($SCRIPT_DIR/download-wallpaper.sh 'https://w.wallhaven.cc/full/wy/wallhaven-wyy73x.jpg' '' '1920x1080'); \
   [[ -s \$file ]]"

run_test "download-wallpaper.sh cache hit fast path" bash -c \
  "file=\$($SCRIPT_DIR/download-wallpaper.sh 'https://w.wallhaven.cc/full/wy/wallhaven-wyy73x.jpg' '' '1920x1080'); \
   [[ -s \$file ]]"

# 7. save-wallpaper.sh
run_test "save-wallpaper.sh save-and-rotate" bash -c \
  "saved=\$($SCRIPT_DIR/save-wallpaper.sh '${XDG_CACHE_HOME:-$HOME/.cache}/chromarchy/wallpapers/wallhaven-wyy73x.jpg' 'rotate' 'test-theme'); \
   [[ -f \$saved && \$saved == *'/backgrounds/test-theme/'* ]]; \
   rm -rf ${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/backgrounds/test-theme"

run_test "save-wallpaper.sh save-only" bash -c \
  "saved=\$($SCRIPT_DIR/save-wallpaper.sh '${XDG_CACHE_HOME:-$HOME/.cache}/chromarchy/wallpapers/wallhaven-wyy73x.jpg' 'save-only' 'test-theme'); \
   [[ -f \$saved && \$saved == *'/saved-wallpapers/test-theme/'* ]]; \
   rm -rf ${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/saved-wallpapers/test-theme"

echo "-------------------------------------"
echo "Results: $PASS passed, $FAIL failed"
if (( FAIL == 0 )); then
  echo "All tests PASSED successfully!"
  exit 0
else
  exit 1
fi
