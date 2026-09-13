#!/usr/bin/env bats
# Repository canonical-tree + vendoring-fidelity checks (no machine deps).
# Run with: make test

ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
CFGS="$ROOT/configs"

@test "core entrypoints exist" {
  [[ -f "$ROOT/spin.sh" ]]
  [[ -f "$ROOT/bootstrap.sh" ]]
  [[ -f "$ROOT/apps/apps.conf" ]]
  [[ -x "$ROOT/spin.sh" ]]
  [[ -x "$ROOT/bootstrap.sh" ]]
}

@test "all shell scripts parse cleanly (bash -n)" {
  local f
  while IFS= read -r -d '' f; do
    bash -n "$f"
  done < <(find "$ROOT" -name '*.sh' -not -path '*/.git/*' -print0)
}

@test "canonical omarchy tree: 14 plugins / 12 themes" {
  [ "$(find "$CFGS/omarchy/plugins" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 14 ]
  [ "$(find "$CFGS/omarchy/themes" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 12 ]
}

@test "skill trees match machine canonical counts (405 opencode / 99 agents)" {
  [ "$(find "$CFGS/opencode/skills" -mindepth 1 -maxdepth 1 | wc -l)" -eq 405 ]
  [ "$(find "$CFGS/agents/skills" -mindepth 1 -maxdepth 1 | wc -l)" -eq 99 ]
}

@test "skill symlinks are preserved (machine-faithful)" {
  [ "$(find "$CFGS/opencode/skills" -type l | wc -l)" -eq 95 ]
  [ "$(find "$CFGS/agents/skills" -type l | wc -l)" -eq 97 ]
}

@test "no build junk or big generated dirs in tree" {
  [[ ! -d "$ROOT/output" ]]
  [[ -z "$(find "$ROOT" -type d -name node_modules -not -path '*/.git/*' | head -1)" ]]
  [[ -z "$(find "$CFGS" -name .git -type d | head -1)" ]]
  [[ -z "$(find "$CFGS" -name '*.bak*' -type f | head -1)" ]]
  [[ -z "$(find "$CFGS" -name '.DS_Store' | head -1)" ]]
}

@test "git config was sanitized (no hardcoded mise path)" {
  ! grep -qE 'mise/installs/gh/' "$CFGS/git/config"
  grep -q 'gh auth git-credential' "$CFGS/git/config"
}

@test "opencode tui migration backup excluded" {
  [[ ! -e "$CFGS/opencode/opencode.json.tui-migration.bak" ]]
  [[ -f "$CFGS/opencode/opencode.json" ]]
  [[ -f "$CFGS/opencode/tui.json" ]]
  [[ -f "$CFGS/opencode/instructions.md" ]]
}

@test "mise config union contains python+rust and no pi" {
  grep -q 'python' "$CFGS/mise/config.toml"
  grep -q 'rust' "$CFGS/mise/config.toml"
  grep -q 'auto_prune' "$CFGS/mise/config.toml"
  run grep -q '\bpi\b' "$CFGS/mise/config.toml"
  [ "$status" -eq 1 ]
}

@test "wallpapers = canonical 9-file aether set" {
  [ "$(find "$CFGS/wallpapers" -maxdepth 1 -type f | wc -l)" -eq 9 ]
  [[ -f "$CFGS/wallpapers/aether-dark-4k.jpg" ]]
}

@test "apps.conf has exactly 13 app rows" {
  [ "$(grep -cP '^[a-z0-9-]+\t' "$ROOT/apps/apps.conf")" -eq 13 ]
}

@test "bootstrap.sh exposes all 7 stages + backup helper" {
  for stage in deps configs agents gaming apps webapps bootloader; do
    grep -q "stage_$stage" "$ROOT/bootstrap.sh"
  done
  grep -q '"$HOME/.voyager-config-backup"' "$ROOT/lib/common.sh"
}