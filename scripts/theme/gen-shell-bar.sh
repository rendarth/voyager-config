#!/usr/bin/env bash
#
# Generate a standalone Quickshell bar and Waybar fallback for the Aether theme.
#
set -Eeuo pipefail

THEME_DIR="${1:?usage: gen-shell-bar.sh <theme-dir>}"
OUT_DIR="${2:-"$HOME/.config/quickshell"}"

accent="$(grep '^accent' "$THEME_DIR/colors.toml"        | head -1 | sed -E 's/.*#([0-9a-fA-F]{6}).*/\1/' || echo 78824b)"
bg="$(grep '^background' "$THEME_DIR/colors.toml"         | head -1 | sed -E 's/.*#([0-9a-fA-F]{6}).*/\1/' || echo 222222)"
fg="$(grep '^foreground' "$THEME_DIR/colors.toml"         | head -1 | sed -E 's/.*#([0-9a-fA-F]{6}).*/\1/' || echo c2c2b0)"
dark="$(grep '^darker_background' "$THEME_DIR/colors.toml" | head -1 | sed -E 's/.*#([0-9a-fA-F]{6}).*/\1/' || echo 121212)"

mkdir -p "$OUT_DIR"

# 1. Valid Minimal Quickshell Bar (ShellRoot + PanelWindow + Timer clock)
cat > "$OUT_DIR/bar.qml" <<EOF
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    PanelWindow {
        anchors {
            top: true
            bottom: false
            left: true
            right: true
        }
        height: 30
        color: "#$bg"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14

            Text {
                text: "Omarchy"
                color: "#$accent"
                font.bold: true
                font.family: "JetBrainsMono Nerd Font"
            }

            Item { Layout.fillWidth: true }

            Text {
                id: clockDisplay
                color: "#$fg"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                text: Qt.formatDateTime(new Date(), "ddd MMM d  h:mm AP")
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clockDisplay.text = Qt.formatDateTime(new Date(), "ddd MMM d  h:mm AP")
            }
        }
    }
}
EOF

# 2. Waybar Fallback Configuration
mkdir -p "$HOME/.config/waybar"
cat > "$HOME/.config/waybar/config.jsonc" <<EOF
{
  "layer": "top",
  "position": "top",
  "height": 28,
  "spacing": 6,
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["tray", "pulseaudio", "network", "battery"],
  "hyprland/workspaces": {
    "disable-scroll": true,
    "all-outputs": true,
    "format": "{name}"
  },
  "clock": {
    "format": "{:%a %b %d  %I:%M %p}",
    "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
  },
  "battery": {
    "format": "{capacity}% 󰂄",
    "format-charging": "{capacity}% 󰂄",
    "format-plugged": "{capacity}% ",
    "format-alt": "{time} {icon}"
  },
  "network": {
    "format-wifi": "{essid} ",
    "format-ethernet": "Ethernet 󰈀",
    "format-disconnected": "Disconnected ⚠"
  },
  "pulseaudio": {
    "format": "{volume}% 󰕾",
    "format-muted": "Muted 󰝟"
  }
}
EOF

cat > "$HOME/.config/waybar/style.css" <<EOF
* {
    font-family: "JetBrainsMono Nerd Font", monospace;
    font-size: 12px;
    color: #$fg;
}
window#waybar {
    background-color: #$bg;
    border-bottom: 2px solid #$dark;
}
#workspaces button {
    padding: 0 6px;
    background-color: transparent;
    color: #$fg;
}
#workspaces button.active {
    background-color: #$accent;
    color: #$bg;
    border-radius: 4px;
}
#clock {
    font-weight: bold;
    color: #$fg;
}
#battery, #network, #pulseaudio, #tray {
    padding: 0 8px;
}
EOF

echo "Wrote Quickshell bar to $OUT_DIR/bar.qml and Waybar fallback."
