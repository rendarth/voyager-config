#!/usr/bin/env bash
# ==============================================================================
# voyager-config: native package availability probe (manifest tier 1)
# Usage: resolve_native <native-field> ; echo $? / stdout pkg
# ==============================================================================

set -Eeuo pipefail

# resolve_native <native-field> -> prints chosen package name, returns 0/1
resolve_native() {
	local field="${1:-}" cur pkglist entry
	[[ -n "$field" ]] || return 1
	if [[ "$field" == *":"* ]]; then
		local -a entries
		IFS=',' read -r -a entries <<<"$field"
		for entry in "${entries[@]}"; do
			cur="${entry%%:*}"
			pkglist="${entry#*:}"
			[[ "$cur" == "$PKGMGR" ]] || continue
			local pkg
			pkg="$(native_probe "$pkglist" 2>/dev/null)" && {
				printf '%s\n' "$pkg"
				return 0
			}
		done
	else
		# Plain package name — probe against current manager directly
		local pkg
		pkg="$(native_probe "$field" 2>/dev/null)" && {
			printf '%s\n' "$pkg"
			return 0
		}
	fi
	return 1
}

# apply_vendor_repo <app> — calls repo_<app>_<pkgmgr> if it exists
apply_vendor_repo() {
	local app="$1"
	local fn="repo_${app}_${PKGMGR}"
	if declare -F "$fn" >/dev/null 2>&1; then
		"$fn"
	fi
}
