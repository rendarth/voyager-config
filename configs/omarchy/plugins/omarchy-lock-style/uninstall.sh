#!/bin/bash

# Uninstallation & cleanup script for Omarchy Lock Style
# Completely removes the plugin, deletes cached wallpapers and configs,
# and restores the original stock Omarchy lock screen.

set -euo pipefail

PLUGIN_ID="omarchy-lock-style"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
CONFIG_DIR="$HOME/.config/omarchy/lock-style"
CONFIG_FILE="$HOME/.config/omarchy/lock-style.json"

echo "==> 1. Disabling and removing plugin ($PLUGIN_ID)..."
omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
rm -rf "$TARGET_DIR"
rm -rf "$HOME/.config/omarchy/plugins/".omarchy-lock-style.bak.* 2>/dev/null || true
echo "    ✓ Plugin removed from $TARGET_DIR"

# Ensure stock lock service is active
omarchy plugin enable "omarchy.lock" >/dev/null 2>&1 || true
echo "    ✓ Stock lock screen service restored"

echo "==> 2. Cleaning up configuration, wallpapers, and backups..."
rm -rf "$CONFIG_DIR"
rm -f "$CONFIG_FILE"
echo "    ✓ Deleted $CONFIG_DIR (including all copied wallpapers)"
echo "    ✓ Deleted $CONFIG_FILE"

echo "==> 3. Refreshing plugins and clearing cache..."
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
rm -rf "$HOME/.cache/quickshell/qmlcache" 2>/dev/null || true
omarchy restart shell >/dev/null 2>&1 || true

echo
echo "✅ Omarchy Lock Style has been completely uninstalled."
echo "   All wallpapers, configs, and temporary files have been deleted."
echo "   Original lock screen is restored and active."
