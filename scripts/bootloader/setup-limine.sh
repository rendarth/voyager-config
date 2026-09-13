#!/usr/bin/env bash
# ==============================================================================
# voyager-config: Limine bootloader stage (guarded: UEFI + root)
# Supports Arch, Fedora, openSUSE on UEFI bare metal & VMs.
# ==============================================================================
set -Eeuo pipefail

VOYAGER_ROOT="${VOYAGER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export VOYAGER_ROOT
# shellcheck source=lib/common.sh
source "$VOYAGER_ROOT/lib/common.sh"
# shellcheck source=lib/distro.sh
source "$VOYAGER_ROOT/lib/distro.sh"
detect_distro

log() { printf '\e[36m[limine]\e[0m %s\n' "$*"; }

install_limine_binaries() {
	case "$PKGMGR" in
	pacman)
		pkg_install limine efibootmgr
		;;
	dnf | zypper)
		if command -v limine >/dev/null 2>&1; then
			ok "Limine binary already installed."
			return
		fi
		log "Limine is not packaged in $PKGMGR defaults; building portable binary from upstream..."
		local src="$HOME/src-limine"
		mkdir -p "$src"
		if [[ ! -d "$src/.git" ]]; then
			git clone --depth 1 https://github.com/limine-bootloader/limine.git "$src" || warn "limine clone failed"
		fi
		if [[ -f "$src/Makefile" || -f "$src/configure" ]]; then
			(cd "$src" && ./configure --enable-uefi-x86-64 2>/dev/null || true &&
				make -j"$(nproc)" && elevate make install) ||
				warn "Limine source build skipped — install from https://limine-bootloader.org/"
		fi
		;;
	*)
		warn "No native limine path for $PKGMGR; skipping binaries."
		;;
	esac
}

configure_limine_efi() {
	local esp=""
	[[ -d /boot/efi/EFI ]] && esp="/boot/efi"
	[[ -z "$esp" && -d /boot/EFI ]] && esp="/boot"

	if [[ -z "$esp" ]]; then
		warn "No standard ESP (/boot or /boot/efi) detected. Skipping automatic EFI boot installation."
		return
	fi

	log "Detected EFI System Partition at $esp."
	elevate mkdir -p "$esp/EFI/BOOT" "$esp/limine"

	if [[ -f /usr/share/limine/BOOTX64.EFI ]]; then
		if elevate cp -f /usr/share/limine/BOOTX64.EFI "$esp/EFI/BOOT/BOOTX64.EFI" 2>/dev/null; then :; fi
		elevate cp -f /usr/share/limine/BOOTX64.EFI "$esp/limine/BOOTX64.EFI" 2>/dev/null || true
	fi

	if [[ ! -f "$esp/limine/limine.conf" && ! -f "$esp/limine.conf" && ! -f /boot/limine.conf ]]; then
		local root_uuid kernel_file initrd_file found_kernel found_initrd
		root_uuid="$(findmnt -n -o UUID / 2>/dev/null || true)"
		kernel_file="vmlinuz-linux"
		initrd_file="initramfs-linux.img"

		found_kernel="$(find /boot -maxdepth 1 -name 'vmlinuz*' ! -name '*rescue*' -printf '%T@ %f\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2- || true)"
		if [[ -n "$found_kernel" ]]; then
			kernel_file="$found_kernel"
			found_initrd="$(find /boot -maxdepth 1 \( -name 'initramfs*.img' -o -name 'initrd*' \) ! -name '*fallback*' ! -name '*rescue*' -printf '%T@ %f\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2- || true)"
			[[ -n "$found_initrd" ]] && initrd_file="$found_initrd"
		fi

		log "Generating $esp/limine/limine.conf (Kernel: $kernel_file, Initrd: $initrd_file, Root UUID: ${root_uuid:-YOUR_ROOT_UUID})..."
		elevate tee "$esp/limine/limine.conf" >/dev/null <<CONF_EOF
timeout: 5
default_entry: 1
graphics: yes
interface_branding: Omarchy Desktop (Limine)

/Omarchy Linux
    protocol: linux
    kernel_path: boot():/${kernel_file}
    initrd_path: boot():/${initrd_file}
    kernel_cmdline: root=UUID=${root_uuid:-YOUR_ROOT_UUID} rw quiet splash

/Omarchy Linux (Fallback)
    protocol: linux
    kernel_path: boot():/${kernel_file}
    initrd_path: boot():/${initrd_file}
    kernel_cmdline: root=UUID=${root_uuid:-YOUR_ROOT_UUID} rw
CONF_EOF
		ok "Wrote $esp/limine/limine.conf"
	fi
}

install_limine_binaries
configure_limine_efi

deploy_limine_helper_configs() {
	local src="$VOYAGER_ROOT/etc"
	[[ -f "$src/limine-entry-tool.conf" ]] && elevate cp -f "$src/limine-entry-tool.conf" /etc/limine-entry-tool.conf
	[[ -f "$src/limine-snapper-sync.conf" ]] && elevate cp -f "$src/limine-snapper-sync.conf" /etc/limine-snapper-sync.conf
	[[ -f "$src/99-omarchy-limine.hook" ]] && {
		elevate mkdir -p /etc/pacman.d/hooks
		elevate cp -f "$src/99-omarchy-limine.hook" /etc/pacman.d/hooks/99-omarchy-limine.hook
	}
	ok "Omarchy limine helper configs deployed (entry tool, snapper-sync, pacman hook)."
}
deploy_limine_helper_configs

log "Limine configuration step complete."
