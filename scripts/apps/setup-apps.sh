#!/usr/bin/env bash
# ==============================================================================
# voyager-config: standalone apps stage
# Delegate to the Tier 1/2/3 manifest pipeline defined in apps/apps.conf.
#   Tier 1: native package manager (probe: pacman/yay, dnf repoquery, zypper, apt, apk)
#   Tier 2: distrobox (Arch container + AUR via yay)
#   Tier 3: flatpak (Flathub)
# ==============================================================================
set -Eeuo pipefail

VOYAGER_ROOT="${VOYAGER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export VOYAGER_ROOT
# shellcheck source=lib/common.sh
source "$VOYAGER_ROOT/lib/common.sh"
# shellcheck source=lib/distro.sh
source "$VOYAGER_ROOT/lib/distro.sh"
detect_distro
# shellcheck source=lib/native-probe.sh
source "$VOYAGER_ROOT/lib/native-probe.sh"
# shellcheck source=lib/vendor-repos.sh
source "$VOYAGER_ROOT/lib/vendor-repos.sh"
# shellcheck source=lib/manifest.sh
source "$VOYAGER_ROOT/lib/manifest.sh"

manifest_install

if ! ((VOYAGER_DRYRUN)); then
	if command -v systemctl >/dev/null 2>&1 && ! ((IS_ATOMIC)); then
		elevate systemctl enable --now docker 2>/dev/null || warn "docker service enable skipped"
	fi
	if command -v groupadd >/dev/null 2>&1; then
		elevate groupadd -f docker 2>/dev/null || true
		elevate usermod -aG docker "$USER" 2>/dev/null || warn "could not add $USER to docker group"
	fi
fi

ok "Application provisioning completed (Tier 1 Native -> Tier 2 Distrobox -> Tier 3 Flatpak)."
