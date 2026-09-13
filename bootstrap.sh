#!/usr/bin/env bash
# ==============================================================================
# voyager-config — universal desktop bootstrap
# Supports: Arch (incl. Omarchy), Fedora (+Atomic), Debian, Ubuntu, openSUSE, Alpine
#
# Usage:
#   bootstrap.sh [--stage NAME] [--dry-run] [--verify] [--yes] [--help]
#
# Stages:
#   deps       core desktop + system dependencies (per package manager)
#   configs    deploy configs, dotfiles, bin, skills, themes
#   agents     mise toolchain + AI agent wrappers
#   gaming     Steam/Proton, Battle.net, Heroic, udev fixes
#   apps       standalone apps (native -> distrobox -> flatpak -> pwa)
#   webapps    chromium app-mode webapp engine
#   bootloader Limine EFI boot entry (guarded)
#   verify     post-flight session checks
# ==============================================================================
set -Eeuo pipefail

VOYAGER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VOYAGER_ROOT

# shellcheck source=lib/common.sh
source "$VOYAGER_ROOT/lib/common.sh"

ARG_STAGE="" ARG_VERIFY=0 ARG_YES=0

while [[ $# -gt 0 ]]; do
	case "$1" in
	--stage)
		[[ -n "${2+x}" ]] || die "--stage requires a stage name: deps|configs|agents|gaming|apps|webapps|bootloader|verify"
		ARG_STAGE="$2"
		shift 2
		;;
	--stage=*)
		ARG_STAGE="${1#*=}"
		shift
		;;
	--dry-run)
		VOYAGER_DRYRUN=1
		shift
		;;
	--verify)
		ARG_VERIFY=1
		shift
		;;
	--yes)
		ARG_YES=1
		shift
		;;
	--help | -h)
		sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,\}//'
		exit 0
		;;
	*) die "Unknown argument: $1 (try --help)" ;;
	esac
done
export VOYAGER_DRYRUN

# shellcheck source=lib/distro.sh
source "$VOYAGER_ROOT/lib/distro.sh"
detect_distro
# shellcheck source=lib/native-probe.sh
source "$VOYAGER_ROOT/lib/native-probe.sh"
# shellcheck source=lib/vendor-repos.sh
source "$VOYAGER_ROOT/lib/vendor-repos.sh"
# shellcheck source=lib/manifest.sh
source "$VOYAGER_ROOT/lib/manifest.sh"

if ((IS_ATOMIC)) && [[ "$ARG_STAGE" == "deps" ]]; then
	log "Atomic host (rpm-ostree) detected — queueing base layer via scripts/setup-atomic.sh."
	bash "$VOYAGER_SCRIPTS/setup-atomic.sh"
	exit 0
fi

# --- Stage: deps -------------------------------------------------------------
stage_deps() {
	log "Installing core desktop + system dependencies ($PKGMGR)..."
	case "$PKGMGR" in
	dnf)
		# RPM Fusion for multimedia/codecs used by desktop apps
		elevate dnf install -y \
			"https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
			"https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" 2>/dev/null || true
		pkg_install \
			git curl wget unzip file xdg-utils tar \
			gcc gcc-c++ make cmake ninja-build pkg-config \
			wayland-devel wayland-protocols-devel libinput-devel libxkbcommon-devel \
			pixman-devel cairo-devel pango-devel \
			xdg-desktop-portal xdg-desktop-portal-hyprland libsecret gnome-keyring \
			thunar foot foot-terminfo distrobox podman docker-compose tmux \
			hyprland waybar rofi-wayland grim slurp wl-clipboard cliphist flatpak swaybg \
			starship btop fastfetch efibootmgr eza fzf bat zoxide gum mpv topgrade flatseal
		;;
	apt)
		pkg_install \
			git curl wget unzip file xdg-utils tar \
			gcc g++ make cmake ninja-build pkg-config \
			libwayland-dev wayland-protocols libinput-dev libxkbcommon-dev \
			libpixman-1-dev libcairo2-dev libpango1.0-dev \
			xdg-desktop-portal xdg-desktop-portal-hyprland libsecret-1-dev gnome-keyring \
			thunar foot distrobox podman docker-compose tmux \
			hyprland waybar rofi-wayland grim slurp wl-clipboard flatpak swaybg \
			starship btop fastfetch efibootmgr eza fzf bat zoxide mpv topgrade flatseal
		;;
	zypper)
		pkg_install \
			git curl wget unzip file xdg-utils tar \
			gcc gcc-c++ make cmake ninja pkg-config \
			wayland-devel wayland-protocols-devel libinput-devel libxkbcommon-devel \
			pixman-devel cairo-devel pango-devel \
			xdg-desktop-portal xdg-desktop-portal-hyprland libsecret gnome-keyring \
			thunar foot distrobox podman docker tmux \
			hyprland waybar grim slurp wl-clipboard cliphist flatpak swaybg \
			starship btop efibootmgr eza fzf bat zoxide gum mpv topgrade flatseal
		;;
	pacman)
		# Enable multilib (32-bit Steam libraries) when gaming is wanted
		if ! grep -q "^\[multilib\]" /etc/pacman.conf 2>/dev/null; then
			elevate sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf 2>/dev/null || true
			elevate pacman -Sy >/dev/null 2>&1 || true
		fi
		pkg_install \
			git curl wget unzip file xdg-utils tar base-devel \
			cmake ninja meson pkgconf \
			wayland wayland-protocols libxkbcommon libinput pixman cairo pango \
			xdg-desktop-portal xdg-desktop-portal-hyprland libsecret gnome-keyring \
			thunar foot distrobox podman docker docker-compose waybar tmux \
			grim slurp wl-clipboard cliphist swaybg eza fzf bat zoxide gum mpv flatseal
		if ((IS_OMARCHY)); then
			ok "Omarchy desktop detected — Hyprland stack managed by the omarchy package; skipping duplicate system packages."
		else
			pkg_install hyprland rofi-wayland starship btop fastfetch efibootmgr
		fi
		;;
	apk)
		pkg_install \
			git curl wget file xdg-utils tar build-base cmake ninja pkgconf \
			distrobox podman docker-cli tmux \
			starship btop fastfetch eza fzf bat zoxide topgrade flatseal
		;;
	esac
	ok "Core dependencies installed."
}

# --- Stages wrappers ---------------------------------------------------------
stage_configs() { bash "$VOYAGER_SCRIPTS/deploy/deploy-configs.sh"; }
stage_agents() { bash "$VOYAGER_SCRIPTS/agents/setup-agents.sh"; }
stage_gaming() { bash "$VOYAGER_SCRIPTS/gaming/setup-gaming.sh"; }
stage_webapps() { bash "$VOYAGER_SCRIPTS/webapps/setup-webapps.sh"; }
stage_bootloader() { bash "$VOYAGER_SCRIPTS/bootloader/setup-limine.sh"; }
stage_verify() { bash "$VOYAGER_SCRIPTS/verify/verify-session.sh"; }

stage_apps() {
	bash "$VOYAGER_SCRIPTS/apps/setup-apps.sh"
}

run_all() {
	stage_deps
	stage_configs
	stage_agents
	stage_gaming
	stage_apps
	stage_webapps
	stage_bootloader
}

# --- Confirmation gate -----------------------------------------------------
confirm_mutation() {
	if ((VOYAGER_DRYRUN)); then
		warn "--dry-run enabled: printing actions only."
		return 0
	fi
	if ((ARG_YES)); then
		return 0
	fi
	warn "This will install packages and deploy configs to \$HOME."
	local answer=""
	read -r -n1 -p "Continue? [y/N] " answer </dev/tty || answer="n"
	echo
	[[ "$answer" == "y" || "$answer" == "Y" ]]
}

# --- Dispatch ----------------------------------------------------------------
if [[ -n "$ARG_STAGE" ]]; then
	if [[ "$ARG_STAGE" != "verify" ]]; then
		confirm_mutation || die "Aborted (use --yes to skip confirmation)."
	fi
	case "$ARG_STAGE" in
	deps) stage_deps ;;
	configs) stage_configs ;;
	agents) stage_agents ;;
	gaming) stage_gaming ;;
	apps) stage_apps ;;
	webapps) stage_webapps ;;
	bootloader) stage_bootloader ;;
	verify) stage_verify ;;
	*) die "Unknown stage: $ARG_STAGE" ;;
	esac
else
	confirm_mutation || die "Aborted (use --yes to skip confirmation)."
	run_all
fi

if ((ARG_VERIFY)) && [[ "$ARG_STAGE" != "verify" ]]; then
	stage_verify
fi

log "done. Start a new shell (or Hyprland session) to pick up PATH/PROMPT settings."
