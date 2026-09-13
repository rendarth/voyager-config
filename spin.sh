#!/usr/bin/env bash
# ==============================================================================
# voyager-config — one-line bootstrap entrypoint
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/rendarth/voyager-config/master/spin.sh)
#   bash <(curl -fsSL https://raw.githubusercontent.com/rendarth/voyager-config/master/spin.sh) --stage configs
#
# Local checkout (repo present): spin.sh runs ./bootstrap.sh directly.
# Remote (pipd one-liner):       fetches a tarball + sha256, extracts, runs.
# ==============================================================================
set -Eeuo pipefail

SPIN_REF="master"
SPIN_ARGS=()
SPIN_VERIFY_SHA=1

while [[ $# -gt 0 ]]; do
	case "$1" in
	--tag)
		SPIN_REF="v$2"
		shift 2
		;;
	--ref)
		SPIN_REF="$2"
		shift 2
		;;
	--no-verify)
		SPIN_VERIFY_SHA=0
		shift
		;;
	*)
		SPIN_ARGS+=("$1")
		shift
		;;
	esac
done

# --- local mode --------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/bootstrap.sh" ]]; then
	exec bash "$SCRIPT_DIR/bootstrap.sh" "${SPIN_ARGS[@]}"
fi

# --- fetch mode --------------------------------------------------------------
log() { printf '\e[36m[spin]\e[0m %s\n' "$*"; }
die() {
	printf '\e[31m[spin][FAIL]\e[0m %s\n' "$*" >&2
	exit 1
}

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/voyager-config"
mkdir -p "$CACHE"

BASE="https://github.com/rendarth/voyager-config/archive/refs"
case "$SPIN_REF" in
v*)
	REF_SPEC="refs/tags/$SPIN_REF"
	ARCHIVE_SUFFIX="$SPIN_REF"
	;;
*)
	REF_SPEC="refs/heads/$SPIN_REF"
	ARCHIVE_SUFFIX="$SPIN_REF"
	;;
esac

TARBALL="$CACHE/voyager-config-$ARCHIVE_SUFFIX.tar.gz"
SHAURL="https://raw.githubusercontent.com/rendarth/voyager-config/$SPIN_REF/sha256sum.txt"

log "Fetching voyager-config@$SPIN_REF ..."
curl -fsSL "$BASE/$REF_SPEC.tar.gz" -o "$TARBALL" || die "download failed: $BASE/$REF_SPEC.tar.gz"

if ((SPIN_VERIFY_SHA)); then
	if SHA256="$(curl -fsSL "$SHAURL" 2>/dev/null)"; then
		EXPECTED="$(printf '%s\n' "$SHA256" | awk -F'  *' '{print $1; exit}')"
		ACTUAL="$(sha256sum "$TARBALL" | awk '{print $1}')"
		if [[ -n "$EXPECTED" && "$ACTUAL" != "$EXPECTED" ]]; then
			die "sha256 mismatch for $TARBALL (expected $EXPECTED, got $ACTUAL). Refusing to run."
		fi
		log "sha256 verified."
	else
		warn_sha() { printf '\e[33m[spin][warn]\e[0m %s\n' "no pinned sha256sum.txt for ref $SPIN_REF; continuing unverified (HEAD ref)."; }
		warn_sha
	fi
fi

WORK="$(mktemp -d "/tmp/voyager-config.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

tar -xzf "$TARBALL" -C "$WORK"
BOOTSTRAP="$(find "$WORK" -maxdepth 2 -name bootstrap.sh -print -quit)"
[[ -n "$BOOTSTRAP" ]] || die "bootstrap.sh not found in archive"

exec bash "$BOOTSTRAP" "${SPIN_ARGS[@]}"
