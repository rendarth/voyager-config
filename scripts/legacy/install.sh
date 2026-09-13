#!/bin/bash
# ==============================================================================
# Universal System & Dotfiles Installer
# Supports: Omarchy, Arch Linux, CachyOS, Fedora, Bazzite, Ubuntu/Debian, openSUSE & Distrobox
# ==============================================================================
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

# If running via curl or external path, ensure repo is cloned to ~/dotfiles
if [ ! -f "$DOTFILES_DIR/install.sh" ]; then
    echo "Cloning dotfiles repository to $DOTFILES_DIR..."
    if ! command -v git &>/dev/null; then
        if command -v pacman &>/dev/null; then sudo pacman -Sy --noconfirm git;
        elif command -v dnf &>/dev/null; then sudo dnf install -y git;
        elif command -v apt-get &>/dev/null; then sudo apt-get update && sudo apt-get install -y git;
        elif command -v zypper &>/dev/null; then sudo zypper install -y git;
        fi
    fi
    git clone https://github.com/rendarth/dotfiles.git "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"

echo "========================================================"
echo "    Starting Universal System & Config Installation     "
echo "========================================================"

# Detect OS
OS_ID="unknown"
OS_LIKE=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
fi

echo "Detected OS: $OS_ID (Like: $OS_LIKE)"

install_arch() {
    echo "=== Provisioning Arch / Omarchy Linux System ==="
    sudo pacman -Syu --needed --noconfirm base-devel git curl wget

    # Ensure AUR helper
    if ! command -v yay &>/dev/null; then
        echo "Installing yay AUR helper..."
        git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
        (cd /tmp/yay-bin && makepkg -si --noconfirm)
        rm -rf /tmp/yay-bin
    fi

    # Install native Arch packages
    if [ -f "$DOTFILES_DIR/packages/arch-packages.txt" ]; then
        echo "Installing official repository packages..."
        sudo pacman -S --needed --noconfirm - < "$DOTFILES_DIR/packages/arch-packages.txt" 2>/dev/null || true
    fi

    # Install AUR packages
    if [ -f "$DOTFILES_DIR/packages/aur-packages.txt" ]; then
        echo "Installing AUR packages..."
        yay -S --needed --noconfirm - < "$DOTFILES_DIR/packages/aur-packages.txt" 2>/dev/null || true
    fi
}

install_generic() {
    echo "=== Provisioning Non-Arch / Atomic System ($OS_ID) ==="
    
    # 1. Install container engines and base tools via native package manager
    if command -v dnf &>/dev/null; then
        sudo dnf install -y git curl wget podman distrobox flatpak || true
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y git curl wget podman distrobox flatpak || true
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y git curl wget podman distrobox flatpak || true
    elif command -v rpm-ostree &>/dev/null; then
        echo "Atomic / OSTree system detected (e.g. Bazzite/Silverblue). Using Flatpak and Distrobox directly..."
    fi

    # 2. Install Flatpaks for desktop applications
    if command -v flatpak &>/dev/null && [ -f "$DOTFILES_DIR/packages/flatpak-packages.txt" ]; then
        echo "Installing Flatpaks..."
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
        while IFS= read -r app || [ -n "$app" ]; do
            [[ "$app" =~ ^#.*$ ]] && continue
            [ -z "$app" ] && continue
            flatpak install -y flathub "$app" || true
        done < "$DOTFILES_DIR/packages/flatpak-packages.txt"
    fi

    # 3. Setup Distrobox Arch container for Arch-specific tools & Foot terminal
    echo "Setting up Arch container in Distrobox for Arch/AUR exclusive apps..."
    bash "$DOTFILES_DIR/scripts/setup-distrobox.sh"
}

# Run distribution-specific provisioning
case "$OS_ID" in
    arch|omarchy|endeavouros|manjaro|cachyos)
        install_arch
        ;;
    *)
        if [[ "$OS_LIKE" =~ arch ]]; then
            install_arch
        else
            install_generic
        fi
        ;;
esac

# Common modular setup steps
echo "=== Step 1: Deploying User Configurations ==="
bash "$DOTFILES_DIR/restore.sh"

echo "=== Step 2: Setting up MISE & Polyglot Runtimes ==="
bash "$DOTFILES_DIR/scripts/setup-mise.sh"

echo "=== Step 3: Setting up AI Tools (OpenCode, Claude, Antigravity) ==="
bash "$DOTFILES_DIR/scripts/setup-ai-tools.sh"

echo "=== Step 4: Setting up Gaming, NTFS Mounts & Proton Tweaks ==="
bash "$DOTFILES_DIR/scripts/setup-gaming.sh"

echo "=== Step 5: Setting up Webapp Installer ==="
bash "$DOTFILES_DIR/scripts/setup-webapps.sh"

if [[ "$OS_ID" =~ arch|omarchy|cachyos|endeavouros ]] || [[ "$OS_LIKE" =~ arch ]]; then
    echo "=== Step 6: Setting up Omarchy Shell Plugins ==="
    bash "$DOTFILES_DIR/scripts/setup-omarchy-plugins.sh" || true
    
    echo "=== Step 7: Setting up Limine Bootloader & Snapshot Sync ==="
    bash "$DOTFILES_DIR/scripts/setup-limine.sh" || true
    
    echo "=== Step 8: Enabling System Services ==="
    bash "$DOTFILES_DIR/scripts/setup-services.sh" || true
fi

if [[ "$OS_ID" =~ arch|omarchy|cachyos|endeavouros|fedora ]] || [[ "$OS_LIKE" =~ arch ]]; then
    echo "=== Step 9: Setting up CachyOS Kernel & Tweaks ==="
    bash "$DOTFILES_DIR/scripts/setup-cachyos.sh" || true
fi

echo "========================================================"
echo "  Universal System & Config Installation Complete!      "
echo "========================================================"
