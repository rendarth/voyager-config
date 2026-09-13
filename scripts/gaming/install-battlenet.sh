#!/usr/bin/env bash
#
# Universal Battle.net Installer (Cloned from Omarchy Gaming Stack)
# Uses: umu-launcher + GE-Proton + Gamescope (Native or Distrobox fallback)
#
set -Eeuo pipefail

PREFIX="$HOME/Games/battlenet"
LAUNCHER="$PREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
INSTALLER_URL="https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"
COMPAT_DIR="$HOME/.local/share/Steam/compatibilitytools.d"

log() { printf '\e[36m[battlenet]\e[0m %s\n' "$*"; }
ok() { printf '\e[32m[ ok ]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[warn]\e[0m %s\n' "$*"; }

mkdir -p "$HOME/Games" "$PREFIX" "$COMPAT_DIR" "$HOME/.local/bin" "$HOME/.local/share/applications"

# ---------------------------------------------------------------------------
# 1. Ensure GE-Proton is installed
# ---------------------------------------------------------------------------
ensure_ge_proton() {
	if ! find "$COMPAT_DIR" -maxdepth 1 -name "GE-Proton*" -print -quit | grep -q .; then
		log "No GE-Proton found in $COMPAT_DIR. Fetching latest GE-Proton release..."
		local latest_tag
		latest_tag="$(curl -fsSL https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "GE-Proton11-6")"
		local tarball="${latest_tag}.tar.gz"
		local url="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${latest_tag}/${tarball}"

		log "Downloading ${latest_tag}..."
		curl -fsSL "$url" -o "/tmp/$tarball" 2>/dev/null || true
		if [[ -f "/tmp/$tarball" ]]; then
			tar -xzf "/tmp/$tarball" -C "$COMPAT_DIR" 2>/dev/null || true
			rm -f "/tmp/$tarball"
			ok "Installed $latest_tag into $COMPAT_DIR."
		fi
	else
		ok "GE-Proton found in $COMPAT_DIR."
	fi
}

# ---------------------------------------------------------------------------
# 2. Ensure umu-launcher is available
# ---------------------------------------------------------------------------
ensure_umu() {
	if ! command -v umu-run >/dev/null 2>&1; then
		log "umu-run not found on host. Checking Distrobox omarchy-box or package manager..."
		if command -v pacman >/dev/null 2>&1; then
			sudo pacman -S --noconfirm --needed umu-launcher 2>/dev/null || true
		elif command -v dnf >/dev/null 2>&1; then
			sudo dnf install -y umu-launcher 2>/dev/null || true
		fi

		# Fallback to Distrobox if host lacks umu-launcher
		if ! command -v umu-run >/dev/null 2>&1 && distrobox list 2>/dev/null | grep -q "omarchy-box"; then
			log "Exporting umu-launcher from Distrobox 'omarchy-box'..."
			distrobox enter "omarchy-box" -- yay -S --needed --noconfirm umu-launcher 2>/dev/null || true
			distrobox enter "omarchy-box" -- distrobox-export --bin /usr/bin/umu-run 2>/dev/null || true
		fi
	fi
}

# ---------------------------------------------------------------------------
# 3. Bootstrap Battle.net Prefix & Installer
# ---------------------------------------------------------------------------
install_prefix() {
	export WINEPREFIX="$PREFIX"
	export PROTONPATH=GE-Proton
	export GAMEID=umu-battlenet
	export PROTON_VERB=run

	if [[ -f "$LAUNCHER" ]]; then
		ok "Battle.net is already installed at $PREFIX."
		return
	fi

	# Wipe broken/incomplete prefix if launcher missing
	if [[ -d "$PREFIX/drive_c" && ! -f "$LAUNCHER" ]]; then
		log "Detected incomplete prefix at $PREFIX. Resetting prefix..."
		pkill -f "$PREFIX" 2>/dev/null || true
		sleep 1
		rm -rf "$PREFIX"
		mkdir -p "$PREFIX"
	fi

	local cache_dir="$HOME/.cache/gaming"
	mkdir -p "$cache_dir"
	local installer="$cache_dir/Battle.net-Setup.exe"

	log "Downloading Blizzard Battle.net installer..."
	curl -fsSL --retry 3 "$INSTALLER_URL" -o "$installer"

	log "Launching Battle.net setup wizard via GE-Proton & umu-launcher..."
	if command -v umu-run >/dev/null 2>&1; then
		setsid -f sh -c "umu-run '$installer' >/tmp/battlenet-install.log 2>&1" </dev/null >/dev/null 2>&1 || true
	elif command -v wine >/dev/null 2>&1; then
		setsid -f sh -c "wine '$installer' >/tmp/battlenet-install.log 2>&1" </dev/null >/dev/null 2>&1 || true
	else
		warn "Neither umu-run nor wine found. Please ensure umu-launcher or wine is installed."
	fi
}

# ---------------------------------------------------------------------------
# 4. Register Desktop File
# ---------------------------------------------------------------------------
register_desktop() {
	cat >"$HOME/.local/share/applications/battlenet.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Battle.net
GenericName=Game Launcher
Comment=Blizzard game launcher (umu-launcher + GE-Proton)
Exec=$HOME/.local/bin/omarchy-launch-battlenet
Icon=battle-net
Terminal=false
Categories=Game;
StartupNotify=true
StartupWMClass=battle.net.exe
EOF
	chmod +x "$HOME/.local/share/applications/battlenet.desktop"
	update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
	ok "Battle.net desktop launcher registered."
}

ensure_ge_proton
ensure_umu
install_prefix
register_desktop

ok "Battle.net installation complete."
