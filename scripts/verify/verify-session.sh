#!/usr/bin/env bash
# ==============================================================================
# voyager-config: post-flight session verification
#   verify-session.sh            — deployed-system checks
#   verify-session.sh --repo     — repository canonical-tree checks (CI)
# Exits non-zero if anything is missing.
# ==============================================================================
set -Eeuo pipefail
# shellcheck disable=SC2016 # chk() eval's the quoted expressions on purpose

VOYAGER_ROOT="${VOYAGER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export VOYAGER_ROOT
# shellcheck source=lib/common.sh
source "$VOYAGER_ROOT/lib/common.sh"
# shellcheck source=lib/distro.sh
source "$VOYAGER_ROOT/lib/distro.sh"
detect_distro

PASS=0 FAIL=0
chk() { if eval "$2"; then
	PASS=$((PASS + 1))
	ok "$1"
else
	FAIL=$((FAIL + 1))
	warn "MISSING: $1"
fi; }

if [[ "${1:-}" == "--repo" ]]; then
	echo "== Repository canonical-tree checks =="
	chk "spin.sh present" '[[ -f "$VOYAGER_ROOT/spin.sh" ]]'
	chk "bootstrap.sh present" '[[ -f "$VOYAGER_ROOT/bootstrap.sh" ]]'
	chk "apps/apps.conf present" '[[ -f "$VOYAGER_APPS/apps.conf" ]]'
	chk "omarchy themes == 12" '[[ $(find "$VOYAGER_CONFIGS/omarchy/themes" -mindepth 1 -maxdepth 1 -type d | wc -l) -eq 12 ]]'
	chk "omarchy plugins == 14" '[[ $(find "$VOYAGER_CONFIGS/omarchy/plugins" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l) -eq 14 ]]'
	chk "opencode skills == 405" '[[ $(find "$VOYAGER_CONFIGS/opencode/skills" -mindepth 1 -maxdepth 1 | wc -l) -eq 405 ]]'
	chk "agents skills == 99" '[[ $(find "$VOYAGER_CONFIGS/agents/skills" -mindepth 1 -maxdepth 1 | wc -l) -eq 99 ]]'
	chk "no output/ build dir" '[[ ! -d "$VOYAGER_ROOT/output" ]]'
	chk "no node_modules vendored" '[[ -z "$(find "$VOYAGER_ROOT" -type d -name node_modules -not -path "*/.git/*" | head -1)" ]]'
	chk "no .git nested" '[[ -z "$(find "$VOYAGER_ROOT/configs" -name .git -type d | head -1)" ]]'
	chk "no *.bak.*" '[[ -z "$(find "$VOYAGER_ROOT/configs" -name '*.bak*' -type f | head -1)" ]]'
	chk "openode instructions vendored" '[[ -f "$VOYAGER_CONFIGS/opencode/instructions.md" ]]'
	chk "git config sanitized" '! grep -qE "mise/installs/gh/" "$VOYAGER_CONFIGS/git/config"'
	echo
	echo "RESULT: $PASS passed, $FAIL failed"
	((FAIL == 0))
	exit $?
fi

echo "== Deployed-system checks (user $USER, distro $DISTRO_ID) =="
chk "mise binary" 'in_path mise'
chk "configs/mise deployed" '[[ -f "$HOME/.config/mise/config.toml" ]]'
chk "opencode config deployed" '[[ -f "$HOME/.config/opencode/opencode.json" ]]'
chk "instructions.md deployed" '[[ -f "$HOME/.config/opencode/instructions.md" ]]'
chk "agents skills deployed" '[[ -d "$HOME/.agents/skills/diagnose-crash" ]]'
chk "bin/omarchy-agent deployed" '[[ -x "$HOME/.local/bin/omarchy-agent" ]]'
chk "bin/antigravity deployed" '[[ -x "$HOME/.local/bin/antigravity" ]]'
chk "wallpapers deployed" '[[ -f "$HOME/.config/wallpapers/aether-dark-4k.jpg" ]]'
chk "browser flags deployed" '[[ -f "$HOME/.config/brave-origin-flags.conf" ]]'
chk "environment.d deployed" '[[ -f "$HOME/.config/environment.d/terminal.conf" ]]'
chk "shell aliases deployed" '[[ -f "$HOME/.config/shell/aliases" ]]'
if ((IS_OMARCHY)); then
	chk "omarchy plugins == 14" '[[ $(find "$HOME/.config/omarchy/plugins" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l) -eq 14 ]]'
	chk "omarchy themes == 12" '[[ $(find "$HOME/.config/omarchy/themes" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l) -eq 12 ]]'
	chk "hypr lua deployed" '[[ -f "$HOME/.config/hypr/hyprland.lua" ]]'
	chk "fastfetch config deployed" '[[ -f "$HOME/.config/fastfetch/config.jsonc" ]]'
else
	chk "standalone hyprland.conf" '[[ -f "$HOME/.config/hypr/hyprland.conf" ]]'
	chk "rofi theme deployed" '[[ -f "$HOME/.config/rofi/config.rasi" ]]'
fi

echo
echo "RESULT: $PASS passed, $FAIL failed"
((FAIL == 0))
exit $?
