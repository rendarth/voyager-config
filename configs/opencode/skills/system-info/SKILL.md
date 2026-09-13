---
name: system-info
description: System specifications and environment details for firefly. Use when the user asks about hardware, system specs, drivers, or when diagnosing hardware-related issues.
---

# System: firefly

## OS
- **Distro:** Omarchy 4.0.2 (Arch-based)
- **Kernel:** 7.1.9-arch1-2
- **Hostname:** firefly

## CPU
- Intel Core Ultra 7 155H
- 16 cores / 22 threads (1 socket)
- Meteor Lake architecture

## GPU
- **Integrated:** Intel Arc Graphics (Meteor Lake-P)
- **Discrete:** NVIDIA GeForce RTX 4060 Max-Q / Mobile (AD107M, rev a1)

## Memory
- 30 GiB RAM
- 30.7 GiB zram (compressed swap)

## Storage
- NVMe 0: INTEL SSDPEKNW020T8 (1.9T)
- NVMe 1: HP SSD EX900 1TB (931.5G)
- NVMe 2: HFS001TEJ9X101N (953.9G)

## Desktop
- **WM:** Hyprland (via Omarchy)
- **Shell:** omarchy-shell (Quickshell/QML)
- **Terminal:** Alacritty (default)
- **Display:** Wayland

## Notes
- NVIDIA driver is installed; `nvidia-powerd` runs but reports battery errors (expected on desktop/laptop without battery via NVIDIA power management)
- Uses UFW firewall
- Package manager: pacman + yay (AUR)
- Requires `pkexec` (not `sudo`) for privilege escalation in GUI contexts
