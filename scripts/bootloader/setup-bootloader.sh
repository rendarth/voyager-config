#!/usr/bin/env bash
# ==============================================================================
# voyager-config: bootloader stage (default: leave the OS bootloader alone)
# The distribution's bootloader already manages kernels and boot entries on
# its own (systemd-boot scans /boot, GRUB regenerates via update-grub/mkconfig,
# rpm-ostree writes GRUB entries, etc). By default we detect what is in use
# and do NOT touch it — voyager does not take over boot management.
#
# Explicitly opt in to managed Limine (canonical limine.conf + EFI install):
#   VOYAGER_MANAGE_BOOTLOADER=limine ./bootstrap.sh --stage bootloader
# ==============================================================================
set -Eeuo pipefail

VOYAGER_ROOT="${VOYAGER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export VOYAGER_ROOT
# shellcheck source=lib/common.sh
source "$VOYAGER_ROOT/lib/common.sh"
# shellcheck source=lib/distro.sh
source "$VOYAGER_ROOT/lib/distro.sh"
detect_distro

detect_bootloader() {
	# systemd-boot: loader config on the ESP or /boot
	[[ -f /boot/loader/loader.conf || -d /boot/loader/entries || -f /efi/loader/loader.conf ||
		-d /efi/EFI/systemd || -d /boot/efi/EFI/systemd || -d /boot/EFI/systemd ]] &&
		{
			echo "systemd-boot"
			return 0
		}
	# GRUB (openSUSE keeps GRUB2 at /boot/grub2)
	[[ -f /boot/grub/grub.cfg || -f /boot/grub2/grub.cfg || -d /boot/grub || -d /boot/grub2 ||
		-d /efi/EFI/grub || -d /boot/efi/EFI/grub || -d /boot/EFI/grub ]] &&
		{
			echo "GRUB"
			return 0
		}
	# Limine
	[[ -f /boot/limine.conf || -d /efi/limine || -d /boot/efi/limine || -d /boot/EFI/limine ]] &&
		{
			echo "Limine"
			return 0
		}
	echo "unknown/none detected"
	return 0
}

log "Bootloader stage: default policy is to leave the OS bootloader alone."
if [[ -d /run/ostree-booted ]] || command -v rpm-ostree >/dev/null 2>&1; then
	log "Host is rpm-ostree based — boot management is owned by ostree; leaving it untouched."
fi

MANAGE="${VOYAGER_MANAGE_BOOTLOADER:-}"

case "$MANAGE" in
limine)
	log "VOYAGER_MANAGE_BOOTLOADER=limine: delegating to the managed Limine stage."
	bash "$VOYAGER_SCRIPTS/bootloader/setup-limine.sh"
	;;
"")
	detected="$(detect_bootloader)"
	if [[ "$detected" == "unknown/none detected" ]]; then
		log "Detected bootloader: none visible to this user (ESP may be root-only or unmounted)."
		log "Leaving boot management to the OS as-is. No changes made."
	else
		log "Detected bootloader: $detected."
		log "Leaving boot management to $detected as the OS configured it. No changes made."
	fi
	ok "Bootloader left as-is (OS-managed)."
	;;
*)
	warn "Unknown VOYAGER_MANAGE_BOOTLOADER value '$MANAGE' (supported: limine). Leaving boot management alone."
	ok "Bootloader left as-is (OS-managed)."
	;;
esac

log "Bootloader stage complete."
