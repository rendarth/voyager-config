#!/usr/bin/env bash
# ==============================================================================
# voyager-config: gaming stage
# - Steam / Gamescope / mangohud / umu-launcher
# - Steam Proton ext4 compatdata redirection for NTFS game libraries
# - Battle.net launchers + desktop entries + icon
# - Heroic config deployment (from configs/heroic, path-rewritten)
# - LAMZU high-polling udev fix
# ==============================================================================
set -Eeuo pipefail

VOYAGER_ROOT="${VOYAGER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export VOYAGER_ROOT
# shellcheck source=lib/common.sh
source "$VOYAGER_ROOT/lib/common.sh"
# shellcheck source=lib/distro.sh
source "$VOYAGER_ROOT/lib/distro.sh"
detect_distro

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_gaming_packages() {
	log "Ensuring Steam, Gamescope, mangohud, and runner tools ($PKGMGR)..."
	case "$PKGMGR" in
	pacman)
		pkg_install steam gamescope mangohud umu-launcher
		;;
	dnf)
		pkg_install steam gamescope mangohud
		;;
	zypper)
		pkg_install steam gamescope mangohud
		;;
	*)
		warn "no native gaming packages for $PKGMGR; relying on apps manifest tiers"
		;;
	esac
	if ! command -v steam >/dev/null 2>&1 && command -v flatpak >/dev/null 2>&1; then
		flatpak install -y --noninteractive flathub com.valvesoftware.Steam 2>/dev/null || true
	fi
}

setup_steam_storage() {
	log "Configuring Steam Proton ext4 redirection..."
	local steam="$HOME/.local/share/Steam"
	mkdir -p "$steam/steamapps/compatdata" "$steam/compatibilitytools.d"
	local lib
	for lib in /mnt/enterprise/SteamLibrary /mnt/rocinante/SteamLibrary /mnt/*/SteamLibrary; do
		if [[ -d "$lib/steamapps" ]]; then
			if [[ -d "$lib/steamapps/compatdata" ]] && [[ ! -L "$lib/steamapps/compatdata" ]]; then
				mv "$lib/steamapps/compatdata" "$lib/steamapps/compatdata.bak.$(date +%s)" 2>/dev/null || true
			fi
			if [[ ! -L "$lib/steamapps/compatdata" ]]; then
				ln -sfn "$steam/steamapps/compatdata" "$lib/steamapps/compatdata" 2>/dev/null || true
				log "Linked $lib/steamapps/compatdata -> $steam/steamapps/compatdata"
			fi
		fi
	done
}

setup_battlenet() {
	log "Deploying Battle.net launchers and desktop entries..."
	mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/256x256/apps"

	((VOYAGER_DRYRUN)) || {
		deploy_executable "$SCRIPT_DIR/battlenet-launcher.sh" "$HOME/.local/bin/omarchy-launch-battlenet"
		deploy_executable "$SCRIPT_DIR/battlenet-gamescope.sh" "$HOME/.local/bin/omarchy-launch-battlenet-gamescope"
		deploy_executable "$SCRIPT_DIR/install-battlenet.sh" "$HOME/.local/bin/omarchy-install-gaming-battlenet"
	}
	if [[ -f "$VOYAGER_ROOT/icons/battle-net.png" ]]; then
		install -m 644 "$VOYAGER_ROOT/icons/battle-net.png" "$HOME/.local/share/icons/hicolor/256x256/apps/battle-net.png"
	fi

	# Desktop launcher (absolute Exec, PATH-independent)
	if [[ ! -f "$HOME/.local/share/applications/battlenet.desktop" ]]; then
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
	fi
	update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

	if ((!VOYAGER_DRYRUN)) && [[ ! -d "$HOME/Games/battlenet" ]]; then
		log "Bootstrapping initial Battle.net installation in the background..."
		mkdir -p "$HOME/.local/log"
		"$HOME/.local/bin/omarchy-install-gaming-battlenet" \
			>"$HOME/.local/log/install-battlenet.log" 2>&1 &
		disown 2>/dev/null || true
	fi
}

setup_heroic() {
	mkdir -p "$HOME/.config/heroic"
	[[ -f "$VOYAGER_CONFIGS/heroic/config.json" ]] || return 0

	local tmp
	tmp="$(mktemp)" || {
		warn "heroic: could not create temp file; skipping config rewrite"
		return 1
	}
	trap 'rm -f "$tmp"' RETURN
	sed "s#/home/[^/]*#$HOME#g" "$VOYAGER_CONFIGS/heroic/config.json" >"$tmp"
	deploy_file "$tmp" "$HOME/.config/heroic/config.json"
	rm -f "$tmp"

	if [[ -d "$VOYAGER_CONFIGS/heroic/GamesConfig" ]]; then
		deploy_tree "$VOYAGER_CONFIGS/heroic/GamesConfig" "$HOME/.config/heroic/GamesConfig"
	else
		warn "heroic: GamesConfig source missing; skipping"
	fi
}

setup_udev() {
	log "Configuring LAMZU mouse high-polling rate udev fix..."
	if [[ ! -f /etc/udev/rules.d/95-lamzu-fix.rules ]]; then
		{
			printf 'SUBSYSTEM=="input", ATTRS{name}=="*LAMZU*", ATTRS{phys}=="*/input1", ENV{LIBINPUT_IGNORE_DEV}="1"\n'
		} | elevate tee /etc/udev/rules.d/95-lamzu-fix.rules >/dev/null
		elevate udevadm control --reload-rules 2>/dev/null || true
	fi
}

install_gaming_packages
setup_steam_storage
setup_battlenet
setup_heroic
setup_udev

ok "Steam and Battle.net out-of-the-box configuration complete."
