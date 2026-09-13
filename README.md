# voyager-config

[![ci](https://github.com/rendarth/voyager-config/actions/workflows/test.yml/badge.svg)](https://github.com/rendarth/voyager-config/actions/workflows/test.yml)

A single, public, self-fetching dotfiles + provisioning repository that
reproduces a full **Omarchy desktop** on Arch, and a **portable Hyprland
fallback** on Debian, Ubuntu, Fedora, openSUSE and Alpine. Everything is
idempotent, backed up before it overwrites, and verified against container
matrix in CI.

## One-and-done copy/paste command

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/rendarth/voyager-config/master/spin.sh)
```

That single command: downloads the repo tarball (sha256-verified when a pinned
hash exists), runs all seven stages (**deps → configs → agents → gaming →
apps → webapps → bootloader**), and asks for one confirmation at the end.
Rebuild any machine with it.

Variants:

```bash
# run one stage (prompts for confirmation unless --yes)
bash <(curl -fsSL https://raw.githubusercontent.com/rendarth/voyager-config/master/spin.sh) --stage configs

# pin a tagged release (verifies sha256sum.txt before running)
bash <(curl -fsSL https://raw.githubusercontent.com/rendarth/voyager-config/master/spin.sh) --tag v1.0.0

# skip the sha256 gate (branch head has no pinned hash)
bash <(curl -fsSL https://raw.githubusercontent.com/rendarth/voyager-config/master/spin.sh) --no-verify
```

Working from an existing checkout instead: `./spin.sh` runs `bootstrap.sh`
next to it directly (no fetch, no verify).

## What this does — the seven stages

| Stage | What it does |
|-------|--------------|
| `deps` | Core desktop + system dependencies per package manager (pacman/apt/dnf/zypper/apk). Enables `[multilib]` on Arch, RPM Fusion on Fedora. On rpm-ostree hosts it hands off to `scripts/setup-atomic.sh`. |
| `configs` | Deploys dotfiles, desktop configs, launchers, skills, themes and wallpapers. **Omarchy hosts** get the canonical tree (`configs/`); **everyone else** gets the portable tree (`configs/portable/`) plus generated theme assets. Every overwrite is first backed up. |
| `agents` | Installs `mise` and the vendored toolchain (`claude, codex, gh, node 26.7.0, opencode, pi, python 3.12, rust`), sets the Omarchy default agent, and adds the user to `docker`/`wheel`. |
| `gaming` | Steam, Gamescope, mangohud, umu-launcher (+ GE-Proton); Steam Proton **ext4 compatdata redirection** for NTFS game libraries; Battle.net launchers + desktop entry + icon; Heroic config deploy (home path rewritten); LAMZU high-polling udev fix. |
| `apps` | Standalone apps via the **Tier 1/2/3 manifest pipeline** (see below). Enables the `docker` service/group. |
| `webapps` | Chromium app-mode webapp engine: `omarchy-launch-webapp <url>` and `omarchy-webapp-install <Name> <url>`, plus cleanup of pre-baked image webapp shortcuts. |
| `bootloader` | **Default: leaves the OS bootloader alone** (it already manages kernels/entries). Optional managed Limine via `VOYAGER_MANAGE_BOOTLOADER=limine`. |
| `verify` | Post-flight session checks (`verify-session.sh`) or repository canonical-tree assertions (`--repo`). |

Run the whole thing or single stages from a checkout:

```bash
./bootstrap.sh --stage deps                          # one stage
./bootstrap.sh --stage configs --dry-run             # print, don't touch
./bootstrap.sh --stage apps --yes                    # skip the confirmation
./bootstrap.sh --verify                              # run everything + verify
./bootstrap.sh --help                                # list stages/flags
```

## Supported platforms

| Target | Path | Notes |
|--------|------|-------|
| Arch (incl. Omarchy) | full repro | canonical 14 plugins / 11 themes, Hyprland Lua |
| Fedora (incl. Atomic / bootc) | yes | rpm-ostree layer + user stages via `setup-atomic.sh`; `Containerfile.atomic` for bootc images |
| Debian / Ubuntu | yes | portable path |
| openSUSE (Tumbleweed/Leap) | yes | portable path; bootloader left OS-managed (systemd-boot or GRUB as YaST chose) |
| Alpine | experimental | minimal deps (portable path) |

Unknown distros fall back to package-manager detection (`apt`, `dnf`, `zypper`,
`pacman`, `apk`); unsupported ones refuse cleanly.

## Repo layout

```
spin.sh                    one-line entrypoint (local mode or fetch + sha256)
bootstrap.sh               7-stage orchestrator (CLI + confirmation gate)
lib/common.sh              shared helpers: logging, elevate, idempotent deploy
lib/distro.sh              distro/pkgmgr detection, native probes, pkg_install
lib/native-probe.sh        availability probe that resolves native candidates
lib/vendor-repos.sh        vendor repo provisioning (Spotify/Brave/Zen/lazydocker)
lib/manifest.sh            Tier 1/2/3 app orchestrator reading apps/apps.conf
apps/apps.conf             app manifest (one row per app + per-tier fallbacks)
configs/                   canonical tree (Omarchy hosts)
configs/portable/          portable fallback tree (non-Omarchy hosts)
configs/bin/               launcher wrappers (opencode, claude, agy, webapps, ...)
configs/mise/config.toml   vendored AI toolchain manifest
configs/opencode/          opencode config + 405 skills + instructions
configs/agents/skills/     99 agent skills (~/.agents/skills)
configs/omarchy/           canonical shell + plugins (14) + themes (11)
themes/aether/             generative theme assets (hypr/rofi/shell generators)
etc/                       vendored Limine helper configs + pacman hook
scripts/bootloader/        setup-bootloader.sh (leave-alone default) + setup-limine.sh
scripts/backup/            sync live machine config back into the repo + auto-push
scripts/deploy/            configs stage implementation
scripts/theme/             Hyprland / rofi / shell-bar generators
scripts/verify/            deployed + repo assertions
scripts/test/              container smoke matrix (docker)
scripts/setup-atomic.sh    Fedora Atomic (rpm-ostree) provisioning
Containerfile.atomic       bootc image builder (Landfall)
snapshots/                 arch-packages.txt (written by backup)
```

## App provisioning (apps/apps.conf)

Per app, the manifest tries tiers in order until one succeeds:

1. **Tier 1 — native:** probe the distro's manager (`pacman` incl. `yay`,
   `dnf repoquery`, `zypper info`, `apt-cache`, `apk search`). An optional
   `repo_<app>_<pkgmgr>` function in `lib/vendor-repos.sh` wires up vendor
   repos automatically (Spotify APT, Brave APT/DNF/zypper, Zen COPR,
   lazydocker COPR).
2. **Tier 2 — distrobox:** an Arch container (`omarchy-box`, `archlinux:latest`)
   with `yay` provisioning lets any AUR package install on non-Arch hosts.
3. **Tier 3 — flatpak:** Flathub fallback.
4. **pwa:** reserved column for curated webapps.

Current manifest rows:

| App | Tier 1 (native) | Tier 2 (distrobox/AUR) | Tier 3 (flatpak) |
|-----|-----------------|------------------------|------------------|
| steam | pacman/dnf/zypper `steam` | — | com.valvesoftware.Steam |
| discord | pacman/dnf `discord` | discord | com.discordapp.Discord |
| obsidian | pacman `obsidian` | obsidian | md.obsidian.Obsidian |
| bitwarden | pacman `bitwarden` | bitwarden | com.bitwarden.desktop |
| bitwarden-cli | pacman `bitwarden-cli` | bitwarden-cli | — |
| spotify | pacman `spotify` / apt `spotify-client` (vendor repo) | spotify | com.spotify.Client |
| heroic | pacman `heroic-games-launcher-bin` | heroic-games-launcher-bin | com.heroicgameslauncher.hgl |
| brave | brave-browser (vendor repo on dnf/apt/zypper, AUR on arch) | brave-bin | com.brave.Browser |
| zen-browser | pacman `zen-browser-bin` / COPR `zen-browser` | zen-browser-bin | app.zen_browser.zen |
| antigravity-cli | pacman `antigravity-cli` | antigravity-cli | — |
| gamescope | pacman/dnf/zypper `gamescope` | — | — |
| lazygit | pacman/dnf `lazygit` | lazygit | — |
| lazydocker | pacman `lazydocker` | lazydocker-bin | — |

## AI / agents

- **mise** installed on first run; the toolchain from `configs/mise/config.toml`
  is installed (`claude, codex, gh, node 26.7.0, opencode, pi, python 3.12, rust`).
- Wrappers in `~/.local/bin` (deployed by `configs`): `opencode`, `claude`,
  `antigravity`/`agy`, `gh`, `omarchy-agent`, plus per-tool helpers.
- **405 opencode skills** and **99 agent skills** are vendored and deployed with
  the configs stage.
- Default Omarchy agent marker written to
  `~/.config/omarchy/defaults/agent` (override: `OMARCHY_DEFAULT_AGENT`).

## Themes, wallpapers, webapps

- Portables get generated theme assets from `themes/aether` via
  `scripts/theme/gen-{hyprland,rofi,shell-bar}.sh`.
- Wallpapers deployed to `~/.config/wallpapers`.
- Webapp engine: `omarchy-launch-webapp` (chromium app-mode) +
  `omarchy-webapp-install` (.desktop generator), cleaned of image pre-bakes.

## Bootloader policy

`bootloader` stage **does not take over boot management**. It detects what the
OS uses (systemd-boot, GRUB, rpm-ostree, or Limine — note the ESP may be
root-only) and leaves it exactly as the distribution configured it.
If you want voyager to manage Limine on a UEFI host, opt in:

```bash
VOYAGER_MANAGE_BOOTLOADER=limine ./bootstrap.sh --stage bootloader
```

Managed mode installs the Limine binary (native on pacman; source build for
dnf/zypper), writes a generated `limine.conf`, copies `BOOTX64.EFI` to the ESP,
and deploys the vendored `etc/limine-{entry-tool,snapper-sync}.conf` +
`99-omarchy-limine.hook`. It is guarded: it refuses when no ESP is present.

## Configuration knobs

| Variable | Effect | Default |
|----------|--------|---------|
| `VOYAGER_DRYRUN` | print actions, change nothing | `0` |
| `VOYAGER_ALLOW_SUDO` | allow `sudo` fallback when `pkexec` is unavailable | `0` |
| `VOYAGER_MANAGE_BOOTLOADER` | `limine` to opt into managed Limine | unset |
| `VOYAGER_DISTROBOX_BOX` | distrobox container name for Tier 2 apps | `omarchy-box` |
| `OMARCHY_DEFAULT_AGENT` | default agent written to omarchy defaults | `opencode` |
| `VOYAGER_DIR` | backup script target checkout | `$HOME/voyager-config` |
| `VOYAGER_BACKUP_LOG` | backup log path | `$HOME/.local/log/voyager-config-backup.log` |
| `VOYAGER_MATRIX_IMAGES` | container matrix image list for smoke tests | 5 distro images |

## Safety

- **Nothing is overwritten blind.** Every changed file is moved to
  `~/.voyager-config-backup/<timestamp>/` first (`backup_timestamped` /
  `deploy_file` keep identical files untouched).
- **Idempotent:** re-runs skip unchanged files (`cmp` on content).
- **Privilege escalation is `pkexec` first**; `sudo` only with
  `VOYAGER_ALLOW_SUDO=1`. Root processes call through directly.
- **`--dry-run`** prints every action without mutating the host.
- **Atomic hosts** (rpm-ostree/bootc) are intercepted up front and layered via
  `rpm-ostree install`, never by mixing system package managers.

## Sync & backup loop

`scripts/backup/backup.sh` pulls the live machine back into the repo checkout
and auto-commits + pushes:

- copies Hyprland Lua, the Omarchy tree, terminals, mise, AI tooling, skills,
  btop/lazygit/starship/environment.d, `~/.local/bin`, and a `pacman -Qqe`
  snapshot;
- prunes junk that would break repo invariants (`.bak*`, `node_modules`,
  nested `.git`, `__pycache__`);
- commits `Auto-backup <timestamp>` and pushes (deferred cleanly if the remote
  is unreachable).

Schedule it however you like (the machine runs it from a systemd user timer at
`Sun 05:00`). `VOYAGER_DIR` points it at any checkout.

## Development, testing & CI

```bash
make setup-test    # fetch bats, check shellcheck/shfmt availability
make lint          # shellcheck + shfmt diff + bash -n
make test          # bats suite (repo-tree, lib-common)
make verify        # canonical-tree assertions (verify-session.sh --repo)
make test-matrix   # container smoke matrix (docker)
make tarball       # tagged-release tarball (git archive)
make sha256        # sha256sum.txt for spin.sh pinning
make ci            # lint + test + verify
make clean         # remove .tools + dist
```

GitHub Actions runs three jobs on push to `master` and on PRs:
**lint-test** (shellcheck, shfmt v3.13.1, bats), **verify-tree** (canonical repo
assertions: 14 plugins, 11 themes, 405 opencode skills, 99 agent skills, no
`.git`/`node_modules`/`.bak*` in the tree), and **matrix-smoke** (configs stage
+ spot checks + real GitHub self-fetch inside debian/ubuntu/archlinux/fedora
/alpine containers).

## License

The user's personal configuration; see repository history for attribution.