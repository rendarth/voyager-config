#!/usr/bin/env bash
# ==============================================================================
# voyager-config: Fedora Atomic (Silverblue, Kinoite, Bazzite, universal-blue)
# rpm-ostree layered host + user-space bootstrap stages.
# ==============================================================================
set -Eeuo pipefail

VOYAGER_ROOT="${VOYAGER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export VOYAGER_ROOT

log() { printf '\e[36m[voyager-atomic]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[warn]\e[0m %s\n' "$*"; }
die() {
	printf '\e[31m[FAIL]\e[0m %s\n' "$*" >&2
	exit 1
}
ok() { printf '\e[32m[ ok ]\e[0m %s\n' "$*"; }

command -v rpm-ostree >/dev/null 2>&1 || die "rpm-ostree not found — intended for Fedora Atomic systems."

log "Fedora Atomic system detected (rpm-ostree)."

ATOMIC_PACKAGES=(
	hyprland waybar foot thunar xdg-desktop-portal-hyprland
	grim slurp wl-clipboard cliphist swaybg fastfetch btop lazygit
	distrobox podman flatpak eza fzf bat zoxide starship git
	gamescope steam mangohud
)

log "Checking missing packages for rpm-ostree layering..."
MISSING=()
for pkg in "${ATOMIC_PACKAGES[@]}"; do
	rpm -q "$pkg" >/dev/null 2>&1 || MISSING+=("$pkg")
done

if ((${#MISSING[@]} > 0)); then
	log "Layering: ${MISSING[*]}"
	if rpm-ostree install --apply-live "${MISSING[@]}" 2>/dev/null; then
		ok "Packages layered live."
	else
		rpm-ostree install "${MISSING[@]}" || warn "Some packages could not be layered via rpm-ostree."
		warn "Package layering requires a reboot to take full effect on host."
	fi
else
	ok "All core desktop packages are already layered."
fi

log "Executing user-space stage(s): ${*:-configs agents webapps apps}"
STAGES="${1:-configs agents webapps apps}"
for s in $STAGES; do
	log "-- stage $s (atomic)"
	bash "$VOYAGER_ROOT/bootstrap.sh" --stage "$s"
done

ok "Fedora Atomic provisioning complete!"
log "If packages were newly layered, run 'sudo reboot' when convenient."
