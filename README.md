# voyager-config

Single, public, self-fetching dotfiles + provisioning repo that reproduces a
full Omarchy desktop plus a portable fallback across six Linux families.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/rendarth/voyager-config/master/spin.sh)
```

Installer (`spin.sh`) detects your distro and runs the 7-stage bootstrap:
**deps → configs → agents → gaming → apps → webapps → bootloader**.

| Target              | Status |
|---------------------|--------|
| Arch / Omarchy      | full repro (canonical 14 plugins / 12 themes) |
| Fedora (incl. Atomic) | yes (rpm-ostree intercept) |
| Debian / Ubuntu     | yes (portable path) |
| openSUSE            | yes (portable path) |
| Alpine              | experimental (minimal deps) |

## Features

- **Configs** — Hyprland (Lua), sway/waybar/quickshell fallback, foot/Alacritty,
  tmux, btop, lazygit, starship, fastfetch, mise toolchain
  (`codex,gh,node,opencode` + `claude,python,rust`), Git (sanitized
  `gh auth git-credential`), environment.d, browser flags.
- **Agents** — OpenCode (+ **405 skills**), Claude/Antigravity, `~/.agents/skills`
  (99 system skills).
- **Apps** — Tiered installer from `apps/apps.conf`: Tier 1 native
  (pacman/yay, dnf repoquery, zypper, apt, apk) → Tier 2 distrobox
  (`omarchy-box` = Arch + AUR) → Tier 3 flatpak → PWA.
  Steam, Discord, Obsidian, Bitwarden, Spotify, Heroic, Brave, Zen, gamescope, lazygit, lazydocker.
- **Gaming** — Steam Proton NTFS compatdata redirection, Battle.net via
  umu-launcher + GE-Proton, Heroic config, LAMZU udev fix.
- **Webapps** — `omarchy-launch-webapp` / `omarchy-webapp-install` launchers.
- **Bootloader** — Limine UEFI entry (guarded: root + ESP detected).

## Safety

- Never overwrites existing config without first backing it up to
  `~/.voyager-config-backup/<timestamp>`.
- Idempotent: unchanged files are skipped on re-run.
- Privilege escalation uses `pkexec` (explicit sudo only with
  `VOYAGER_ALLOW_SUDO=1`).
- Verified end-to-end against five distro containers in CI
  (`make test-matrix`), plus canonical-tree assertions
  (`scripts/verify/verify-session.sh --repo`).

## Usage

```bash
# dev (local checkout)
./spin.sh                        # local mode (bootstrap.sh adjacent)
./bootstrap.sh --stage apps      # run a single stage
./bootstrap.sh --stage configs --dry-run

# release pinning
bash <(curl -fsSL .../spin.sh) --tag v1.0.0   # verifies sha256sum.txt + tarball
```

To work from an opened `~/voyager-config` checkout: clone anywhere, run
`./spin.sh`. To rebuild a machine from the public repo: run the curl one-liner.

## Development

```bash
make setup-test    # fetch bats, check shellcheck/shfmt
make lint          # shellcheck + shfmt + bash -n
make test          # bats suite
make verify        # canonical-tree assertions
make test-matrix   # container matrix (docker)
make tarball sha256  # tagged-release artifacts (sha256sum.txt for spin.sh pinning)
```

Weekly local backup (`scripts/backup/backup.sh`) syncs the live machine back
into this checkout and auto-commits; `VOYAGER_DIR` overrides the expected path.

## License

The user's personal configuration; see repository history / user for licensing.