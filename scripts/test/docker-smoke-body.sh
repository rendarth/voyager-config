#!/usr/bin/env bash
# ==============================================================================
# voyager-config: container-side smoke body (executed inside each matrix image).
# Requires: bash, repo mounted at /repo, ${HOME} redirectable.
# Exercise: bash -n → configs stage (portable path) → spot checks →
#           self-fetch (best-effort; needs pushed master) → repo verify.
# ==============================================================================
set -Eeuo pipefail

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
{
  HOME=/smoke-fetch bash <<"SPIN"
    set -Eeuo pipefail
    mkdir -p /smoke-fetch
    curl -fsSL "https://raw.githubusercontent.com/rendarth/voyager-config/master/spin.sh" -o /tmp/spin.sh 2>/dev/null || exit 3
    chmod +x /tmp/spin.sh
    bash /tmp/spin.sh --no-verify --stage configs
SPIN
} >/tmp/sf.log 2>&1 && echo "  self-fetch PASS" || { echo "  self-fetch skipped:"; tail -3 /tmp/sf.log; }

echo ">> repo-tree verify"
bash /repo/scripts/verify/verify-session.sh --repo

echo "PASS: $SMOKE_IMG"