#!/usr/bin/env bash
# ==============================================================================
# voyager-config: standalone app manifest installer (Tier 1/2/3 pipeline)
# Reads apps/apps.conf; requires lib/common.sh, lib/distro.sh, lib/native-probe.sh,
# lib/vendor-repos.sh already sourced.
# ==============================================================================

set -Eeuo pipefail

declare -g VOYAGER_MANIFEST="$VOYAGER_APPS/apps.conf"
declare -g VOYAGER_DISTROBOX_BOX="${VOYAGER_DISTROBOX_BOX:-omarchy-box}"

manifest_rows() {
	while IFS=$'\t' read -r app bins native dbx_pkg dbx_bin flatpak pwa; do
		[[ -z "$app" || "$app" == \#* ]] && continue
		printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			"$app" "$bins" "$native" "${dbx_pkg:-}" "${dbx_bin:-}" "${flatpak:-}" "${pwa:-}"
	done <"$VOYAGER_MANIFEST"
}

_any_bin_present() {
	local bins="$1" b
	IFS=',' read -r -a list <<<"$bins"
	for b in "${list[@]}"; do
		[[ -n "$b" ]] && in_path "$b" && return 0
	done
	return 1
}

# --- Distrobox tier ----------------------------------------------------------
_dbx_ensure_box() {
	in_path distrobox || {
		warn "distrobox not available on host; skipping Tier 2."
		return 1
	}
	in_path podman || in_path docker || { in_path distrobox-host-unshare; } || true
	if ! in_path podman && ! in_path docker; then
		warn "Neither podman nor docker available; skipping Tier 2."
		return 1
	fi
	if ! distrobox list 2>/dev/null | grep -q "$VOYAGER_DISTROBOX_BOX"; then
		log "Creating Arch distrobox container '$VOYAGER_DISTROBOX_BOX'..."
		distrobox create --name "$VOYAGER_DISTROBOX_BOX" \
			--image docker.io/library/archlinux:latest --init --yes || {
			warn "distrobox create failed."
			return 1
		}
	fi
	log "Provisioning base tools in '$VOYAGER_DISTROBOX_BOX'..."
	distrobox enter "$VOYAGER_DISTROBOX_BOX" -- bash -c '
    set -e
    command -v sudo >/dev/null 2>&1 || { echo "sudo missing in container"; exit 1; }
    sudo pacman -Syu --noconfirm base-devel git curl wget header >/dev/null 2>&1 || sudo pacman -Syu --noconfirm base-devel git curl wget
    if ! command -v yay >/dev/null 2>&1; then
      cd /tmp && rm -rf yay-bin && git clone https://aur.archlinux.org/yay-bin.git
      (cd yay-bin && makepkg -si --noconfirm) && rm -rf /tmp/yay-bin
    fi
  ' || {
		warn "distrobox provisioning failed."
		return 1
	}
	return 0
}

_dbx_install() {
	local pkg="$1" bin="${2:-}"
	distrobox enter "$VOYAGER_DISTROBOX_BOX" -- bash -c \
		"yay -S --needed --noconfirm '$pkg' 2>/dev/null || yay -S --needed --noconfirm '$pkg' || true"
	if [[ -n "$bin" ]]; then
		distrobox enter "$VOYAGER_DISTROBOX_BOX" -- bash -c \
			"[ -x /usr/bin/$bin ] && distrobox-export --bin /usr/bin/$bin 2>/dev/null || true"
	fi
}

# --- Flatpak tier ------------------------------------------------------------
_flatpak_install() {
	local id="$1"
	in_path flatpak || {
		warn "flatpak not available on host; skipping Tier 3."
		return 1
	}
	flatpak remote-add --if-not-exists flathub \
		https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
	flatpak install -y --noninteractive flathub "$id" 2>/dev/null ||
		flatpak install -y --noninteractive flathub "$id" ||
		{
			warn "flatpak install of $id failed."
			return 1
		}
}

# --- Orchestrator -------------------------------------------------------------
manifest_install() {
	local app bins native dbx_pkg dbx_bin flatpak pwa
	while IFS=$'\t' read -r app bins native dbx_pkg dbx_bin flatpak pwa; do
		[[ -z "$app" || "$app" == \#* ]] && continue

		if _any_bin_present "$bins"; then
			ok "app present: $app"
			continue
		fi

		local native_pkg=""
		apply_vendor_repo "$app"
		native_pkg="$(resolve_native "$native" 2>/dev/null || true)"
		if [[ -n "$native_pkg" ]]; then
			log "$app: installing natively via $PKGMGR ($native_pkg)"
			if ((VOYAGER_DRYRUN)); then
				ok "[dry-run] $app would install natively: $native_pkg"
			else
				if pkg_install "$native_pkg"; then
					ok "$app: native install complete"
					continue
				fi
				warn "$app: native install failed; falling through to next tier"
			fi
		fi

		if [[ -n "$dbx_pkg" ]]; then
			log "$app: trying distrobox ($dbx_pkg)"
			if ((VOYAGER_DRYRUN)); then
				ok "[dry-run] $app would install via distrobox: $dbx_pkg"
			elif _dbx_ensure_box && _dbx_install "$dbx_pkg" "$dbx_bin"; then
				ok "$app: distrobox install complete"
				continue
			else
				warn "$app: distrobox install skipped"
			fi
		fi

		if [[ -n "$flatpak" ]]; then
			log "$app: trying flatpak ($flatpak)"
			if ((VOYAGER_DRYRUN)); then
				ok "[dry-run] $app would install via flatpak: $flatpak"
			elif _flatpak_install "$flatpak"; then
				ok "$app: flatpak install complete"
				continue
			else
				warn "$app: flatpak install failed"
			fi
		fi

		warn "$app: no tier produced an install (check apps.conf or install manually)"
	done < <(manifest_rows)
}
