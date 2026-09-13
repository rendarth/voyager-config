#!/usr/bin/env bats
# Unit tests for lib/common.sh deploy helpers (sandboxed HOME).
# Run with: make test

ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SANDBOX="$BATS_TMPDIR/vg-common"
export HOME="$SANDBOX/home"

setup() {
  rm -rf "$SANDBOX"
  mkdir -p "$HOME/.config"
  export VOYAGER_DRYRUN=0
}

# shellcheck source=lib/common.sh
teardown() { :; }

@test "log/deploy helpers source cleanly" {
  # shellcheck source=lib/common.sh
  source "$ROOT/lib/common.sh"
  ok "hello"
}

@test "deploy_file is idempotent and backup-aware" {
  # shellcheck source=lib/common.sh
  source "$ROOT/lib/common.sh"
  local dst="$HOME/.config/test.conf"
  echo "v1" > "$SANDBOX/src.conf"
  deploy_file "$SANDBOX/src.conf" "$dst"
  [[ -f "$dst" ]]
  [[ ! -d "$HOME/.voyager-config-backup" ]]  # first deploy, nothing to back up

  echo "v2" > "$SANDBOX/src.conf"
  deploy_file "$SANDBOX/src.conf" "$dst"
  [[ -f "$dst" ]]
  [[ "$(cat "$dst")" == "v2" ]]
  # original was backed up once
  local n
  n="$(find "$HOME/.voyager-config-backup" -type f -name '*test.conf*' | wc -l)"
  [[ "$n" -ge 1 ]]
}

@test "unchanged file deploy skips backup" {
  # shellcheck source=lib/common.sh
  source "$ROOT/lib/common.sh"
  local dst="$HOME/.config/same.conf"
  echo "S" > "$SANDBOX/s.conf"
  deploy_file "$SANDBOX/s.conf" "$dst"
  deploy_file "$SANDBOX/s.conf" "$dst"
  [[ "$(cat "$dst")" == "S" ]]
}

@test "deploy_files handles directory source (each file deployed flat)" {
  # shellcheck source=lib/common.sh
  source "$ROOT/lib/common.sh"
  local src="$SANDBOX/envdir"
  mkdir -p "$src"
  echo "A=1" > "$src/a.conf"
  echo "B=2" > "$src/b.conf"
  deploy_files "$src" "$HOME/.config/envdir"
  [[ -f "$HOME/.config/envdir/a.conf" ]]
  [[ -f "$HOME/.config/envdir/b.conf" ]]
}

@test "deploy_tree recursion + excludes + exec mode" {
  # shellcheck source=lib/common.sh
  source "$ROOT/lib/common.sh"
  local src="$SANDBOX/tree"
  mkdir -p "$src/sub" "$src/junk" "$src/bins"
  echo "x" > "$src/f.txt"
  echo "y" > "$src/sub/g.txt"
  echo "j" > "$src/junk/jj.txt"
  echo "#!/bin/sh" > "$src/bins/run.sh"

  deploy_tree "$src" "$HOME/.config/tree" junk
  [[ -f "$HOME/.config/tree/f.txt" ]]
  [[ -f "$HOME/.config/tree/sub/g.txt" ]]
  [[ ! -e "$HOME/.config/tree/junk" ]]

  deploy_tree "$src/bins" "$HOME/.local/bin" --exec
  [[ -x "$HOME/.local/bin/run.sh" ]]
}