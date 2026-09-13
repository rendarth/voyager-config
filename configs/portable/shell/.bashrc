# ==============================================================================
# Universal Portable Shell Configuration
# ==============================================================================

# Sourcing non-interactive environment
[[ $- != *i* ]] && return

# Ensure paths
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

# Source aliases
if [ -f "$HOME/.config/shell/aliases" ]; then
    source "$HOME/.config/shell/aliases"
fi

# Source functions
if [ -d "$HOME/.config/shell/fns" ]; then
    for fn in "$HOME/.config/shell/fns"/*; do
        [ -f "$fn" ] && source "$fn"
    done
fi

# Prompt / Tools integration
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi

if command -v zoxide &>/dev/null; then
    eval "$(zoxide init bash)"
fi

if command -v mise &>/dev/null; then
    eval "$(mise activate bash)"
fi
