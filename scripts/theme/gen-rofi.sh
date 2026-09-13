#!/usr/bin/env bash
#
# Generate a standalone Rofi theme (config.rasi) from an Omarchy theme dir.
#
set -Eeuo pipefail

THEME_DIR="${1:?usage: gen-rofi.sh <theme-dir>}"
OUT_DIR="${2:-"$HOME/.config/rofi"}"

accent="$(grep '^accent' "$THEME_DIR/colors.toml" | head -1 | sed -E 's/.*#([0-9a-fA-F]{6}).*/\1/' || echo 78824b)"
bg="$(grep '^background' "$THEME_DIR/colors.toml" | head -1 | sed -E 's/.*#([0-9a-fA-F]{6}).*/\1/' || echo 222222)"
dark="$(grep '^darker_background' "$THEME_DIR/colors.toml" | head -1 | sed -E 's/.*#([0-9a-fA-F]{6}).*/\1/' || echo 121212)"
fg="$(grep '^foreground' "$THEME_DIR/colors.toml" | head -1 | sed -E 's/.*#([0-9a-fA-F]{6}).*/\1/' || echo c2c2b0)"
sel="$(grep '^selection' "$THEME_DIR/colors.toml" | head -1 | sed -E 's/.*#([0-9a-fA-F]{6}).*/\1/' || echo 383838)"

mkdir -p "$OUT_DIR"

cat > "$OUT_DIR/config.rasi" <<EOF
configuration {
    modi: "drun,run,window";
    icon-theme: "Papirus";
    show-icons: true;
    terminal: "foot";
    drun-display-format: "{icon} {name}";
    location: 0;
    disable-history: false;
    hide-scrollbar: true;
    display-drun: "   Apps ";
    display-run: "   Run ";
    display-window: " 󰕰  Window ";
}

* {
    bg-col: #${dark};
    bg-col-light: #${bg};
    border-col: #${accent};
    selected-col: #${sel};
    blue: #${accent};
    fg-col: #${fg};
    fg-col2: #${accent};
    grey: #666666;
    width: 600;
    font: "JetBrainsMono Nerd Font 12";
}

element-text, element-icon , mode-switcher {
    background-color: inherit;
    text-color:       inherit;
}

window {
    height: 400px;
    border: 2px;
    border-color: @border-col;
    background-color: @bg-col;
    border-radius: 10px;
}

mainbox {
    background-color: @bg-col;
}

inputbar {
    children: [prompt,entry];
    background-color: @bg-col;
    border-radius: 5px;
    padding: 2px;
}

prompt {
    background-color: @blue;
    padding: 6px;
    text-color: @bg-col;
    border-radius: 5px;
    margin: 10px 0px 0px 10px;
}

textbox-prompt-colon {
    expand: false;
    str: ":";
}

entry {
    padding: 6px;
    margin: 10px 0px 0px 10px;
    text-color: @fg-col;
    background-color: @bg-col;
}

listview {
    border: 0px 0px 0px;
    padding: 6px 0px 0px;
    margin: 10px 10px 0px 10px;
    columns: 1;
    lines: 8;
    background-color: @bg-col;
}

element {
    padding: 8px;
    background-color: @bg-col;
    text-color: @fg-col;
    border-radius: 6px;
}

element-icon {
    size: 24px;
}

element selected {
    background-color:  @selected-col;
    text-color: @fg-col2;
}

mode-switcher {
    spacing: 0;
}

button {
    padding: 10px;
    background-color: @bg-col-light;
    text-color: @grey;
    vertical-align: 0.5; 
    horizontal-align: 0.5;
}

button selected {
  background-color: @bg-col;
  text-color: @blue;
}
EOF

echo "Wrote Rofi Aether theme to $OUT_DIR/config.rasi"
