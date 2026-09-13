#!/usr/bin/env bash
# ==============================================================================
# voyager-config: AI coding agents stage
# - installs mise and installs the vendored toolchain from configs/mise/config.toml
# - ensures the omarchy default agent marker
# - adds the user to docker/wheel where present
# Bin wrappers (antigravity, claude, gh, opencode, omarchy-agent, ...) are
# deployed from configs/bin by the configs stage.
# ==============================================================================
set -Eeuo pipefail

VOYAGER_ROOT="${VOYAGER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export VOYAGER_ROOT
# shellcheck source=lib/common.sh
source "$VOYAGER_ROOT/lib/common.sh"

log() { printf '\e[36m[agents]\e[0m %s\n' "$*"; }

# --- 1. mise --------------------------------------------------------------
if ! command -v mise >/dev/null 2>&1; then
	log "Installing mise..."
	curl -fsSL https://mise.run | bash || die "mise installation failed (curl https://mise.run | bash)"
fi
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

# Deploy vendored toolchain manifest (union of claude/codex/gh/node/opencode/python/rust)
mkdir -p "$HOME/.config/mise"
deploy_file "$VOYAGER_CONFIGS/mise/config.toml" "$HOME/.config/mise/config.toml"

log "Installing toolchain from mise config.toml..."
export MISE_MINIMUM_RELEASE_AGE=0
if ((VOYAGER_DRYRUN)); then
	ok "[dry-run] would run: mise install"
else
	mise install || warn "some mise tools failed to install; run 'mise install' to retry"
fi

# --- 2. default agent -----------------------------------------------------
DEFAULT_AGENT="${OMARCHY_DEFAULT_AGENT:-opencode}"
mkdir -p "$HOME/.config/omarchy/defaults"
printf '%s\n' "$DEFAULT_AGENT" >"$HOME/.config/omarchy/defaults/agent"
log "default agent set: $DEFAULT_AGENT"

# --- 3. groups ------------------------------------------------------------
if command -v groupadd >/dev/null 2>&1 && [[ $EUID -ne 0 ]]; then
	for g in docker wheel; do
		if getent group "$g" >/dev/null; then
			if elevate usermod -aG "$g" "$(whoami)" 2>/dev/null; then
				log "added $(whoami) to $g."
			else
				warn "could not add $(whoami) to $g (needs root)."
			fi
		fi
	done
fi

ok "AI coding agents configured (OpenCode, Claude, Antigravity). Default: $DEFAULT_AGENT"
