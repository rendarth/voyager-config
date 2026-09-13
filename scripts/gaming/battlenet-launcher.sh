#!/usr/bin/env bash
#
# Launch the installed Battle.net client via umu-launcher + GE-Proton + Gamescope.
# Matches Omarchy gaming launcher implementation.
#
set -euo pipefail

PREFIX="$HOME/Games/battlenet"
LAUNCHER="$PREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"

with_mangohud=0
for arg in "$@"; do
	case "$arg" in
	--with-mangohud) with_mangohud=1 ;;
	-h | --help)
		cat <<'EOF'
Usage: omarchy-launch-battlenet [--with-mangohud]

Options:
  --with-mangohud   Enable the MangoHud FPS overlay for games launched from
                    Battle.net. Toggle perf logging in-game with Shift_L+F2.
EOF
		exit 0
		;;
	esac
done

if [[ ! -f "$LAUNCHER" ]]; then
	echo "Battle.net is not installed at $LAUNCHER" >&2
	echo "Running installer..."
	if command -v omarchy-install-gaming-battlenet &>/dev/null; then
		exec omarchy-install-gaming-battlenet
	fi
	exit 1
fi

WIDTH="${GSC_WIDTH:-2560}"
HEIGHT="${GSC_HEIGHT:-1440}"
REFRESH="${GSC_REFRESH:-165}"
GSC_OPTS=(-W "$WIDTH" -H "$HEIGHT" -r "$REFRESH" -f)
if [[ -n "${GSC_OUTPUT:-}" ]]; then
	GSC_OPTS+=(-O "$GSC_OUTPUT")
fi

env_args=(
	WINEPREFIX="$PREFIX"
	PROTONPATH=GE-Proton
	GAMEID=umu-battlenet
	PROTON_VERB=run
	DXVK_STATE_CACHE_PATH="$PREFIX/drive_c/users/steamuser/AppData/Local/dxvk"
)

if command -v nvidia-smi &>/dev/null; then
	env_args+=(
		__NV_PRIME_RENDER_OFFLOAD=1
		__GLX_VENDOR_LIBRARY_NAME=nvidia
		__VK_LAYER_NV_optimus=NVIDIA_only
		VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
	)
fi

((with_mangohud)) && env_args+=(MANGOHUD=1)

# Run under Gamescope if available, otherwise run directly under umu-run
if command -v gamescope >/dev/null 2>&1; then
	exec gamescope "${GSC_OPTS[@]}" -- env "${env_args[@]}" umu-run "$LAUNCHER"
else
	exec env "${env_args[@]}" umu-run "$LAUNCHER"
fi
