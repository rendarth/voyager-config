#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"

echo "========================================="
echo " Restoring Configurations & Dotfiles     "
echo "========================================="

# 1. Hyprland
if [ -d "$CONFIG_DIR/hypr" ]; then
    mkdir -p "$HOME/.config/hypr"
    cp -rv "$CONFIG_DIR/hypr/"* "$HOME/.config/hypr/" 2>/dev/null || true
    echo "Hyprland configs restored."
fi

# 2. Omarchy Shell, Extensions, Hooks, Themes
if [ -d "$CONFIG_DIR/omarchy" ]; then
    mkdir -p "$HOME/.config/omarchy"
    cp -rv "$CONFIG_DIR/omarchy/"* "$HOME/.config/omarchy/" 2>/dev/null || true
    echo "Omarchy configs restored."
fi

# 3. Foot Terminal & Tmux
if [ -d "$CONFIG_DIR/foot" ]; then
    mkdir -p "$HOME/.config/foot"
    cp -rv "$CONFIG_DIR/foot/"* "$HOME/.config/foot/" 2>/dev/null || true
    echo "Foot terminal config restored."
fi
if [ -d "$CONFIG_DIR/tmux" ]; then
    mkdir -p "$HOME/.config/tmux"
    cp -rv "$CONFIG_DIR/tmux/"* "$HOME/.config/tmux/" 2>/dev/null || true
    echo "Tmux config restored."
fi

# 4. OpenCode & Antigravity
if [ -d "$CONFIG_DIR/opencode" ]; then
    mkdir -p "$HOME/.config/opencode"
    cp -rv "$CONFIG_DIR/opencode/"* "$HOME/.config/opencode/" 2>/dev/null || true
fi
if [ -d "$CONFIG_DIR/antigravity" ]; then
    mkdir -p "$HOME/.gemini/antigravity-cli"
    cp -rv "$CONFIG_DIR/antigravity/"* "$HOME/.gemini/antigravity-cli/" 2>/dev/null || true
fi

# 5. Mise
if [ -d "$CONFIG_DIR/mise" ]; then
    mkdir -p "$HOME/.config/mise"
    cp -rv "$CONFIG_DIR/mise/"* "$HOME/.config/mise/" 2>/dev/null || true
fi

# 6. Starship, Btop, Lazygit, Fastfetch, Wallpapers
[ -f "$CONFIG_DIR/starship.toml" ] && cp -v "$CONFIG_DIR/starship.toml" "$HOME/.config/"
[ -d "$CONFIG_DIR/btop" ] && mkdir -p "$HOME/.config/btop" && cp -rv "$CONFIG_DIR/btop/"* "$HOME/.config/btop/" 2>/dev/null || true
[ -d "$CONFIG_DIR/lazygit" ] && mkdir -p "$HOME/.config/lazygit" && cp -rv "$CONFIG_DIR/lazygit/"* "$HOME/.config/lazygit/" 2>/dev/null || true
[ -d "$CONFIG_DIR/fastfetch" ] && mkdir -p "$HOME/.config/fastfetch" && cp -rv "$CONFIG_DIR/fastfetch/"* "$HOME/.config/fastfetch/" 2>/dev/null || true
[ -d "$SCRIPT_DIR/wallpapers" ] && mkdir -p "$HOME/.config/wallpapers" && cp -rv "$SCRIPT_DIR/wallpapers/"* "$HOME/.config/wallpapers/" 2>/dev/null || true

# 7. Shell Functions, Aliases, Bashrc
if [ -d "$CONFIG_DIR/shell" ]; then
    mkdir -p "$HOME/.config/shell/fns"
    cp -rv "$CONFIG_DIR/shell/"* "$HOME/.config/shell/" 2>/dev/null || true
    [ -f "$CONFIG_DIR/shell/.bashrc" ] && cp -v "$CONFIG_DIR/shell/.bashrc" "$HOME/.bashrc"
fi

# 8. User Binaries (~/.local/bin)
mkdir -p "$HOME/.local/bin"
if [ -d "$SCRIPT_DIR/bin" ]; then
    cp -rv "$SCRIPT_DIR/bin/"* "$HOME/.local/bin/" 2>/dev/null || true
    chmod +x "$HOME/.local/bin/"* 2>/dev/null || true
    echo "User binaries restored to ~/.local/bin."
fi

# 9. Agent Skills
mkdir -p "$HOME/.agents/skills"
if [ -d "$SCRIPT_DIR/agents/skills" ]; then
    cp -rvL "$SCRIPT_DIR/agents/skills/"* "$HOME/.agents/skills/" 2>/dev/null || true
    echo "Agent skills restored to ~/.agents/skills."
fi

# Reload Hyprland if active
if command -v hyprctl &>/dev/null && pgrep -x Hyprland &>/dev/null; then
    echo "Reloading Hyprland..."
    hyprctl reload 2>/dev/null || true
fi

echo "========================================="
echo " Dotfiles restoration completed!        "
echo "========================================="
