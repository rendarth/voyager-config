#!/usr/bin/env bash
# ==============================================================================
# voyager-config: webapp engine stage
# The launchers live in configs/bin (deployed by the configs stage):
#   omarchy-launch-webapp <url>           — chromium app-mode launcher
#   omarchy-webapp-install <Name> <URL>   — .desktop-entry generator
# This stage ensures the convenience alias + default webapp cleanup.
# ==============================================================================
set -Eeuo pipefail

VOYAGER_ROOT="${VOYAGER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export VOYAGER_ROOT
# shellcheck source=lib/common.sh
source "$VOYAGER_ROOT/lib/common.sh"

log() { printf '\e[36m[webapps]\e[0m %s\n' "$*"; }

BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
mkdir -p "$BIN_DIR" "$APPS_DIR"

# Convenience aliases (bindings reference omarchy-webapp / omarchy-webapp-install)
for alias_name in "omarchy-webapp:omarchy-launch-webapp" "omarchy-webapp-install:omarchy-webapp-install"; do
	link="${alias_name%%:*}"
	target="${alias_name##*:}"
	if [[ -x "$BIN_DIR/$target" ]]; then
		ln -sfn "$BIN_DIR/$target" "$BIN_DIR/$link"
	fi
done

# Clean up unwanted default webapp shortcuts that ship with some images
for webapp in "WhatsApp" "YouTube" "Basecamp" "Google Mail" "Google Maps" \
	"Google Contacts" "Google Messages" "Google Photos" "X"; do
	rm -f "$APPS_DIR/$webapp.desktop" 2>/dev/null || true
done

ok "Webapp engine ready (omarchy-launch-webapp / omarchy-webapp-install)."
