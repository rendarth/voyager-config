#!/usr/bin/env bash
# ==============================================================================
# voyager-config: container smoke matrix (CI + local)
# For each distro image: ensure bash, mount repo + smoke body, run.
#   VOYAGER_MATRIX_IMAGES overrides the image list.
# ==============================================================================
set -Eeuo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
IMAGES="${VOYAGER_MATRIX_IMAGES:-debian:12 ubuntu:24.04 archlinux fedora:42 alpine:3.21}"

echo "== container smoke matrix =="
for img in $IMAGES; do
	echo "--- smoke: $img ---"
	# pull so the inner run is a plain exec
	docker pull -q "$img" >/dev/null
	docker run --rm \
		-e SMOKE_IMG="$img" \
		-e SMOKE_HOME=/smoke-home \
		-v "$ROOT:/repo:ro" \
		"$img" \
		sh -c 'command -v bash >/dev/null 2>&1 || { command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1 || echo "cannot install bash on '"'"'$img'"'"'"; }; exec bash /repo/scripts/test/docker-smoke-body.sh'
done
echo "== matrix complete =="
