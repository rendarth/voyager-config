#!/usr/bin/env bash
# ==============================================================================
# voyager-config: shared shell helpers
# Source me:  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# Expects VOYAGER_ROOT exported by the entrypoint (spin.sh / bootstrap.sh).
# ==============================================================================

set -Eeuo pipefail

declare -g VOYAGER_ROOT="${VOYAGER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC2034 # cross-file via export
declare -g VOYAGER_CONFIGS="$VOYAGER_ROOT/configs"
# shellcheck disable=SC2034 # cross-file via export
declare -g VOYAGER_APPS="$VOYAGER_ROOT/apps"
# shellcheck disable=SC2034 # cross-file via export
declare -g VOYAGER_LIB="$VOYAGER_ROOT/lib"
# shellcheck disable=SC2034 # cross-file via export
declare -g VOYAGER_SCRIPTS="$VOYAGER_ROOT/scripts"
# shellcheck disable=SC2034 # cross-file via export
declare -g VOYAGER_THEMES="$VOYAGER_ROOT/themes"
declare -g VOYAGER_DRYRUN="${VOYAGER_DRYRUN:-0}"

# --- logging -----------------------------------------------------------------
log() { printf '\e[36m[voyager]\e[0m %s\n' "$*"; }
ok() { printf '\e[32m[ ok ]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[warn]\e[0m %s\n' "$*"; }
die() {
	printf '\e[31m[FAIL]\e[0m %s\n' "$*" >&2
	exit 1
}

# --- misc --------------------------------------------------------------------
require_cmds() {
	local missing=()
	local c
	for c in "$@"; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
	((${#missing[@]} == 0)) || die "Missing required command(s): ${missing[*]}"
}

in_path() { command -v "$1" >/dev/null 2>&1; }

ts() { date +%s; }

# --- privilege escalation ----------------------------------------------------
# System preference: pkexec first. Falls back to sudo ONLY when explicitly
# enabled via VOYAGER_ALLOW_SUDO=1. Root processes call through directly.
elevate() {
	if [[ $EUID -eq 0 ]]; then
		"$@"
		return $?
	fi
	if command -v pkexec >/dev/null 2>&1; then
		pkexec "$@"
		return $?
	fi
	if [[ "${VOYAGER_ALLOW_SUDO:-0}" == "1" ]] && command -v sudo >/dev/null 2>&1; then
		warn "pkexec unavailable; using sudo (VOYAGER_ALLOW_SUDO=1)."
		sudo "$@"
		return $?
	fi
	warn "Root required for: $*"
	warn "Privilege escalation: pkexec is not available here."
	warn "Re-run as root (sudo -i / su) or install polkit and retry."
	return 1
}

# --- idempotent config deployment -------------------------------------------
# Every overwrite is preceded by a timestamped backup into
# ~/.vosyager-config-backup.<ts> so re-runs never destroy data silently.

_backup_root_default="$HOME/.voyager-config-backup"

backup_timestamped() {
	# usage: backup_timestamped <src-path>
	local src="$1"
	[[ -e "$src" ]] || return 0
	local ts_dir
	ts_dir="${VOYAGER_BACKUP_ROOT:-$_backup_root_default}/$(ts)"
	mkdir -p "$ts_dir"
	mkdir -p "$(dirname "$ts_dir/$src")"
	mv "$src" "$ts_dir/$src"
	warn "backed up $src -> $ts_dir/$src"
}

deploy_file() {
	# usage: deploy_file <src> <dst>  (idempotent, backs up on change)
	local src="$1" dst="$2"
	[[ -f "$src" ]] || die "deploy_file: source missing: $src"
	mkdir -p "$(dirname "$dst")"
	if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
		log "unchanged: $dst"
		return 0
	fi
	if [[ -f "$dst" ]]; then
		backup_timestamped "$dst"
	fi
	install -m 644 "$src" "$dst"
	log "deployed: $dst"
}

deploy_executable() {
	local src="$1" dst="$2"
	[[ -f "$src" ]] || die "deploy_executable: source missing: $src"
	mkdir -p "$(dirname "$dst")"
	if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
		log "unchanged: $dst"
		return 0
	fi
	if [[ -f "$dst" ]]; then
		backup_timestamped "$dst"
	fi
	install -m 755 "$src" "$dst"
	log "deployed: $dst"
}

deploy_tree() {
	# usage: deploy_tree <src-dir> <dst-dir> [--exec] [exclude-glob...]
	# idempotent; top-level overwrites backed up first; recurses with cp -f.
	local src="$1" dst="$2"
	shift 2
	local mode="normal"
	[[ "${1:-}" == "--exec" ]] && {
		mode="exec"
		shift
	}
	local excludes=("$@")

	[[ -d "$src" ]] || die "deploy_tree: source missing: $src"
	mkdir -p "$dst"

	local entry
	for entry in "$src"/*; do
		[[ -e "$entry" ]] || continue
		local name base
		base="$(basename "$entry")"
		for name in "${excludes[@]:-}"; do
			[[ -n "$name" ]] && [[ "$base" == "$name" ]] && continue 2
		done
		if [[ -d "$entry" ]]; then
			local sub
			for sub in "${excludes[@]:-}"; do
				[[ -n "$sub" ]] && [[ "$base" == "$sub" ]] && continue 2
			done
			deploy_tree "$entry" "$dst/$base" "$@"
		else
			if [[ "$mode" == "exec" ]]; then
				deploy_executable "$entry" "$dst/$base"
			else
				deploy_file "$entry" "$dst/$base"
			fi
		fi
	done
}

# deploy_one_level: like deploy_tree but only direct children of src (no recurse)
deploy_files() {
	local src="$1" dst="$2"
	[[ -d "$src" ]] || die "deploy_files: source missing: $src"
	mkdir -p "$dst"
	local f
	for f in "$src"/*; do
		[[ -f "$f" ]] || continue
		deploy_file "$f" "$dst/$(basename "$f")"
	done
}
