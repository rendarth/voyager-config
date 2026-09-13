#!/usr/bin/env bash
# ==============================================================================
# voyager-config: container-side smoke body (executed inside each matrix image).
# Requires: bash, repo mounted at /repo, ${HOME} redirectable.
# Exercise: bash -n → configs stage (portable path) → spot checks →
#           self-fetch (best-effort; needs pushed master) → repo verify.
# ==============================================================================
set -Eeuo pipefail

ensure_tool() {
	local tool="$1"
	command -v "$tool" >/dev/null 2>&1 && return 0
	echo "  installing $tool ..."
	if command -v apt-get >/dev/null 2>&1; then
		apt-get update -qq && apt-get install -y -qq --no-install-recommends "$tool" ca-certificates
	elif command -v dnf >/dev/null 2>&1; then
		dnf install -y -q "$tool"
	elif command -v pacman >/dev/null 2>&1; then
		pacman -Sy --noconfirm "$tool"
	elif command -v apk >/dev/null 2>&1; then
		apk add --no-cache "$tool"
	else
		echo "  NO package manager known for $tool on $SMOKE_IMG"
		return 1
	fi
}
ensure_tool bash
ensure_tool curl

export HOME=${SMOKE_HOME:-/smoke-home}
export VOYAGER_ROOT=/repo
rm -rf "$HOME" /smoke-fetch /tmp/sf.log
mkdir -p "$HOME" /smoke-fetch /tmp

echo ">> bash -n on all scripts"
while IFS= read -r -d "" f; do bash -n "$f"; done < <(find /repo -name "*.sh" -not -path "*/.git/*" -not -path "*/.tools/*" -not -path "*/scripts/legacy/*" -print0)

echo ">> configs stage (portable path) into isolated HOME"
bash /repo/bootstrap.sh --stage configs --yes

echo ">> spot checks"
test -f "$HOME/.config/shell/aliases"
test -f "$HOME/.config/opencode/opencode.json"
test -d "$HOME/.config/environment.d"
test -x "$HOME/.local/bin/omarchy-agent"
test -f "$HOME/.config/starship.toml"
test -f "$HOME/.config/wallpapers/crowned.jpg"
printf "config dirs deployed: %s\n" "$(find "$HOME/.config" -mindepth 1 -maxdepth 1 -type d | wc -l)"

echo ">> self-fetch install (real GitHub master, best-effort)"
if command -v curl >/dev/null 2>&1; then
	{
		printf 'self-fetch start (%s)\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
		HOME=/smoke-fetch bash <<"SPIN"
set -Eeuo pipefail
mkdir -p /smoke-fetch
curl -fsSL "https://raw.githubusercontent.com/rendarth/voyager-config/master/spin.sh" -o /tmp/spin.sh
chmod +x /tmp/spin.sh
bash /tmp/spin.sh --no-verify --stage configs --yes
SPIN
	} >/tmp/sf.log 2>&1 && echo "  self-fetch PASS" || {
		echo "  self-fetch FAILED (log below):"
		tail -5 /tmp/sf.log
	}
else
	echo "  self-fetch SKIPPED: curl unavailable"
fi

echo ">> repo-tree verify"
bash /repo/scripts/verify/verify-session.sh --repo

echo "PASS: $SMOKE_IMG"