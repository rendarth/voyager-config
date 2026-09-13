#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

node "$repo_dir/test/logic.test.mjs"
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell "$repo_dir/Service.qml"
omarchy plugin validate "$repo_dir"
jq empty "$repo_dir/manifest.json"
git -C "$repo_dir" diff --check
git -C "$repo_dir" diff --cached --check
