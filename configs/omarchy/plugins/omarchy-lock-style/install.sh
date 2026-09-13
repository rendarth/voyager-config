#!/bin/bash

# Installation script for Omarchy Lock Style
# Installs, enables, and manages the lock screen customizer bar widget.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="omarchy-lock-style"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
BACKUP_DIR="$HOME/.config/omarchy/lock-style/backup"
STOCK_LOCKVIEW="/usr/share/omarchy/shell/plugins/lock/LockView.qml"

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  -e, --enable       Enable the widget on Omarchy bar after installation
  -r, --restart      Restart omarchy-shell immediately to apply changes
  -u, --uninstall    Completely uninstall plugin, delete wallpapers and restore stock lock
  -h, --help         Show this help message

Examples:
  ./install.sh --enable --restart
  ./install.sh --uninstall
  ./uninstall.sh
EOF
}

ENABLE=0
RESTART=0
UNINSTALL=0

while (( $# > 0 )); do
  case "$1" in
    -e|--enable) ENABLE=1; shift ;;
    -r|--restart) RESTART=1; shift ;;
    -u|--uninstall) UNINSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ $UNINSTALL -eq 1 ]]; then
  exec "$SCRIPT_DIR/uninstall.sh"
fi

echo "==> 1. Securing initial backup of stock LockView.qml..."
mkdir -p "$BACKUP_DIR"
if [ ! -f "$BACKUP_DIR/LockView.original.qml" ]; then
  if [ -f "$STOCK_LOCKVIEW" ]; then
    cp "$STOCK_LOCKVIEW" "$BACKUP_DIR/LockView.original.qml"
    echo "    ✓ Original LockView.qml saved to $BACKUP_DIR/LockView.original.qml"
  else
    echo "    ! Warning: Stock $STOCK_LOCKVIEW not found directly"
  fi
else
  echo "    ✓ Original backup already present at $BACKUP_DIR/LockView.original.qml"
fi

echo "==> 2. Validating plugin..."
omarchy plugin validate "$SCRIPT_DIR"

echo "==> 3. Copying plugin files to $TARGET_DIR..."
# Remove any previous installation and stale .bak directories to ensure a clean overwrite
rm -rf "$TARGET_DIR"
rm -rf "$HOME/.config/omarchy/plugins/".omarchy-lock-style.bak.* 2>/dev/null || true
mkdir -p "$TARGET_DIR"
cp -f "$SCRIPT_DIR/manifest.json" "$TARGET_DIR/"
cp -f "$SCRIPT_DIR/LockStyle.qml" "$TARGET_DIR/"
cp -f "$SCRIPT_DIR/Service.qml" "$TARGET_DIR/"
cp -f "$SCRIPT_DIR/LockView.qml" "$TARGET_DIR/"
cp -f "$SCRIPT_DIR/LockStyleHelper.js" "$TARGET_DIR/"
cp -f "$SCRIPT_DIR/LockViewGenerator.js" "$TARGET_DIR/"
cp -f "$SCRIPT_DIR/uninstall.sh" "$TARGET_DIR/"
cp -f "$SCRIPT_DIR/README.md" "$TARGET_DIR/" 2>/dev/null || true
cp -f "$SCRIPT_DIR/LICENSE" "$TARGET_DIR/" 2>/dev/null || true

echo "==> 4. Requesting plugin rescan from omarchy-shell..."
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

if [[ $ENABLE -eq 1 ]]; then
  echo "==> 5. Enabling widget in the bar layout..."
  if omarchy plugin enable "$PLUGIN_ID" --before omarchy.power 2>/dev/null; then
    echo "    Plugin placed before omarchy.power"
  elif omarchy plugin enable "$PLUGIN_ID" --section right 2>/dev/null; then
    echo "    Plugin placed in the right section of the bar"
  else
    omarchy plugin enable "$PLUGIN_ID" || true
  fi
fi

if [[ $RESTART -eq 1 || $ENABLE -eq 1 ]]; then
  echo "==> 6. Restarting omarchy-shell..."
  rm -rf "$HOME/.cache/quickshell/qmlcache" 2>/dev/null || true
  omarchy restart shell || echo "Note: run 'omarchy restart shell' to reload the interface."
fi

echo
echo "✅ Lock Style installed successfully."
echo "   Plugin ID: $PLUGIN_ID"
echo "   To configure: Click the 󰌾 icon on your bar"
echo "   To remove:    ./uninstall.sh (or ./install.sh --uninstall)"
