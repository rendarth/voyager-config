#!/usr/bin/env bash
# ==============================================================================
# voyager-config: vendor repository provisioning (apt/dnf/zypper)
# Each function name is referenced from apps/apps.conf. Idempotent.
# ==============================================================================

set -Eeuo pipefail

# --- Spotify -----------------------------------------------------------
repo_spotify_apt() {
	# Official Spotify APT repository (Debian/Ubuntu)
	if [[ -f /etc/apt/sources.list.d/spotify.list ]]; then return 0; fi
	log "Adding official Spotify APT repository..."
	elevate apt-get install -y curl gpg >/dev/null 2>&1 || true
	curl -sS https://download.spotify.com/debian/pubkey_C62284B7EBFF1694.gpg |
		gpg --dearmor --yes -o /dev/stdout 2>/dev/null |
		elevate tee /usr/share/keyrings/spotify-archive-keyring.gpg >/dev/null
	printf 'deb [signed-by=/usr/share/keyrings/spotify-archive-keyring.gpg] https://repository.spotify.com/debian stable non-free\n' |
		elevate tee /etc/apt/sources.list.d/spotify.list >/dev/null
	pkg_refresh
}

repo_spotify_dnf() {
	# Spotify isn't shipped via an official Fedora repo; leave to AUR/distrobox/flatpak tiers.
	warn "No official Spotify DNF repo; falling through to distrobox/flatpak tiers."
}

# --- Brave Browser -----------------------------------------------------
repo_brave_apt() {
	if [[ -f /etc/apt/sources.list.d/brave-browser-release.list ]]; then return 0; fi
	log "Adding official Brave APT repository..."
	elevate apt-get install -y curl gpg >/dev/null 2>&1 || true
	curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-core.asc |
		gpg --dearmor --yes -o /dev/stdout 2>/dev/null |
		elevate tee /usr/share/keyrings/brave-browser-archive-keyring.gpg >/dev/null
	printf 'deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main\n' |
		elevate tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
	pkg_refresh
}

repo_brave_dnf() {
	if [[ -f /etc/yum.repos.d/brave-browser-rpm.repo ]]; then return 0; fi
	log "Adding official Brave DNF repository..."
	elevate dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || true
	curl -fsSL https://brave-browser-rpm-release.s3.brave.com/brave-core.asc | elevate rpm --import - || true
}

repo_brave_zypper() {
	if zypper lr --uri 2>/dev/null | grep -q brave-browser; then return 0; fi
	log "Adding official Brave repository for openSUSE..."
	curl -fsSL https://brave-browser-rpm-release.s3.brave.com/brave-core.asc | elevate rpm --import - || true
	elevate zypper --non-interactive addrepo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || true
}

# --- Zen Browser -------------------------------------------------------
repo_zen_dnf() {
	if rpm -qa 2>/dev/null | grep -q zen-browser; then return 0; fi
	log "Enabling Zen Browser COPR (Fedora)..."
	elevate dnf copr enable -y sneexy/zen-browser 2>/dev/null || true
}

# --- lazydocker --------------------------------------------------------
repo_lazydocker_dnf() {
	if dnf repolist 2>/dev/null | grep -qi atim/lazydocker; then return 0; fi
	log "Enabling lazydocker COPR (Fedora)..."
	elevate dnf copr enable -y atim/lazydocker 2>/dev/null || true
}
