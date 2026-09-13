#!/usr/bin/env bash
# ==============================================================================
# voyager-config: distribution / package-manager detection + primitives
# Source me after lib/common.sh. Reads /etc/os-release.
# Exports: PKGMGR DISTRO_ID IS_OMARCHY IS_ARCH IS_DEBIAN IS_RHEL IS_SUSE IS_FEDORA IS_ATOMIC IS_ALPINE
# ==============================================================================

set -Eeuo pipefail

declare -g PKGMGR="" DISTRO_ID="" DISTRO_LIKE=""
declare -g IS_OMARCHY=0 IS_ARCH=0 IS_DEBIAN=0 IS_RHEL=0 IS_SUSE=0 IS_FEDORA=0 IS_ATOMIC=0 IS_ALPINE=0

detect_distro() {
	local osr="/etc/os-release"
	if [[ -f "$osr" ]]; then
		# shellcheck disable=SC1090
		DISTRO_ID="$(. "$osr" && echo "${ID:-unknown}")"
		# shellcheck disable=SC1090
		# shellcheck disable=SC2034 # exported for sub-scripts invoked via bash
		DISTRO_LIKE="$(. "$osr" && echo "${ID_LIKE:-}")"
	fi
	[[ -n "$DISTRO_ID" ]] || DISTRO_ID="unknown"

	IS_ATOMIC=0
	command -v rpm-ostree >/dev/null 2>&1 && IS_ATOMIC=1

	case "$DISTRO_ID" in
	arch | endeavouros | cachyos)
		IS_ARCH=1
		PKGMGR="pacman"
		if command -v omarchy-shell >/dev/null 2>&1 || [[ -d /usr/share/omarchy ]] || [[ -f /usr/share/omarchy/WELCOME ]]; then
			IS_OMARCHY=1
		fi
		;;
	debian | ubuntu | linuxmint | pop)
		IS_DEBIAN=1
		PKGMGR="apt"
		;;
	fedora)
		IS_FEDORA=1
		IS_RHEL=1
		PKGMGR="dnf"
		;;
	rhel | centos | rocky | almalinux)
		IS_RHEL=1
		PKGMGR="dnf"
		;;
	opensuse* | sles*)
		IS_SUSE=1
		PKGMGR="zypper"
		;;
	alpine)
		IS_ALPINE=1
		PKGMGR="apk"
		;;
	*)
		# Fall back to package-manager detection
		if command -v apt-get >/dev/null 2>&1; then
			PKGMGR="apt"
			IS_DEBIAN=1
		elif command -v dnf >/dev/null 2>&1; then
			PKGMGR="dnf"
			IS_RHEL=1
			IS_FEDORA=1
		elif command -v zypper >/dev/null 2>&1; then
			PKGMGR="zypper"
			IS_SUSE=1
		elif command -v pacman >/dev/null 2>&1; then
			PKGMGR="pacman"
			IS_ARCH=1
		elif command -v apk >/dev/null 2>&1; then
			PKGMGR="apk"
			IS_ALPINE=1
		else
			die "Unsupported distribution ($DISTRO_ID). Requires apt, dnf, zypper, pacman, or apk."
		fi
		;;
	esac

	export PKGMGR DISTRO_ID DISTRO_LIKE IS_OMARCHY IS_ARCH IS_DEBIAN IS_RHEL IS_SUSE IS_FEDORA IS_ATOMIC IS_ALPINE
	log "Detected: $DISTRO_ID (pkgmgr=$PKGMGR, omarchy=$IS_OMARCHY)"
}

# --- read-only availability probes -------------------------------------------
native_available() {
	# usage: native_available <pkg>  -> boolean. Never mutates host.
	local pkg="$1"
	[[ -n "$pkg" ]] || return 1
	case "$PKGMGR" in
	pacman)
		if pacman -Si "$pkg" >/dev/null 2>&1; then return 0; fi
		if command -v yay >/dev/null 2>&1 && yay -Si "$pkg" >/dev/null 2>&1; then return 0; fi
		return 1
		;;
	dnf)
		dnf repoquery --available --quiet "$pkg" >/dev/null 2>&1
		;;
	zypper)
		zypper info -t package "$pkg" >/dev/null 2>&1
		;;
	apt)
		apt-cache show "$pkg" >/dev/null 2>&1
		;;
	apk)
		apk search -x "$pkg" >/dev/null 2>&1
		;;
	*)
		return 1
		;;
	esac
}

native_probe() {
	# usage: native_probe <comma-separated-pkgs> -> prints first available pkg
	local list="$1" pkg
	IFS=',' read -r -a candidates <<<"$list"
	for pkg in "${candidates[@]}"; do
		if native_available "$pkg"; then
			printf '%s\n' "$pkg"
			return 0
		fi
	done
	return 1
}

# --- package operations -------------------------------------------------------
pkg_refresh() {
	case "$PKGMGR" in
	apt) elevate apt-get update --quiet=2 ;;
	pacman) true ;;
	*) true ;;
	esac
}

pkg_install() {
	# usage: pkg_install <pkg> [pkg...]   (skips already-installed packages)
	local todo=() pkg
	for pkg in "$@"; do
		case "$PKGMGR" in
		pacman)
			pacman -Q "$pkg" >/dev/null 2>&1 && continue
			;;
		dnf)
			rpm -q "$pkg" >/dev/null 2>&1 && continue
			;;
		zypper)
			rpm -q "$pkg" >/dev/null 2>&1 && continue
			;;
		apt)
			dpkg -s "$pkg" >/dev/null 2>&1 && continue
			;;
		apk)
			apk info -e "$pkg" >/dev/null 2>&1 && continue
			;;
		esac
		todo+=("$pkg")
	done
	((${#todo[@]} == 0)) && return 0
	log "Installing: ${todo[*]}"
	case "$PKGMGR" in
	pacman)
		elevate pacman -S --noconfirm --needed "${todo[@]}"
		;;
	dnf)
		elevate dnf install -y "${todo[@]}"
		;;
	zypper)
		elevate zypper install -y "${todo[@]}"
		;;
	apt)
		elevate env DEBIAN_FRONTEND=noninteractive apt-get install -y "${todo[@]}"
		;;
	apk)
		elevate apk add --no-progress "${todo[@]}"
		;;
	*)
		die "pkg_install: unsupported pkgmgr $PKGMGR"
		;;
	esac
}

ensure_group() {
	# usage: ensure_group <group> <user>
	local group="$1" user="${2:-$USER}"
	if getent group "$group" >/dev/null 2>&1; then
		elevate groupadd -f "$group" 2>/dev/null || true
		elevate usermod -aG "$group" "$user" 2>/dev/null || warn "could not add $user to $group"
	else
		warn "group '$group' does not exist; skipping"
	fi
}
