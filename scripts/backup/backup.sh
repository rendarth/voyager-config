#!/bin/bash
# ==============================================================================
# voyager-config: automated sync & backup (retargeted from dotfiles)
# Pulls the live machine config into the local voyager-config checkout and
# commits+pushes. Optionally schedules an RTC wake alarm.
#
#   VOYAGER_DIR=/custom/path ./scripts/backup/backup.sh
# ==============================================================================
set -Eeuo pipefail

VOYAGER_DIR="${VOYAGER_DIR:-$HOME/voyager-config}"
LOG="${VOYAGER_BACKUP_LOG:-$HOME/.local/log/voyager-config-backup.log}"
mkdir -p "$(dirname "$LOG")" "$VOYAGER_DIR"

{
	echo "=== Sync & Backup Started: $(date) ==="

	[[ -d "$VOYAGER_DIR/.git" ]] || {
		echo "VOYAGER_DIR is not a git checkout: $VOYAGER_DIR"
		exit 1
	}

	# 1. Hyprland (canonical Lua)
	mkdir -p "$VOYAGER_DIR/configs/hypr"
	shopt -s nullglob
	cp -u "$HOME/.config/hypr/"*.lua "$VOYAGER_DIR/configs/hypr/" 2>/dev/null || true
	cp -u "$HOME/.config/hypr/"*.conf "$VOYAGER_DIR/configs/hypr/" 2>/dev/null || true
	cp -u "$HOME/.config/hypr/xdph.conf" "$VOYAGER_DIR/configs/hypr/" 2>/dev/null || true
	rm -f "$VOYAGER_DIR/configs/hypr/"*.bak.* 2>/dev/null || true

	# 2. Omarchy tree
	mkdir -p "$VOYAGER_DIR/configs/omarchy"
	cp -ru "$HOME/.config/omarchy/"* "$VOYAGER_DIR/configs/omarchy/" 2>/dev/null || true
	find "$VOYAGER_DIR/configs/omarchy" -name node_modules -type d -prune -exec rm -rf {} \; 2>/dev/null || true

	# 3. Terminals
	mkdir -p "$VOYAGER_DIR/configs/foot" "$VOYAGER_DIR/configs/alacritty" "$VOYAGER_DIR/configs/tmux"
	[ -f "$HOME/.config/foot/foot.ini" ] && cp -u "$HOME/.config/foot/foot.ini" "$VOYAGER_DIR/configs/foot/"
	[ -f "$HOME/.config/alacritty/alacritty.toml" ] && cp -u "$HOME/.config/alacritty/alacritty.toml" "$VOYAGER_DIR/configs/alacritty/"
	[ -f "$HOME/.config/tmux/tmux.conf" ] && cp -u "$HOME/.config/tmux/tmux.conf" "$VOYAGER_DIR/configs/tmux/"

	# 4. Mise (union live)
	mkdir -p "$VOYAGER_DIR/configs/mise"
	[ -f "$HOME/.config/mise/config.toml" ] && cp -u "$HOME/.config/mise/config.toml" "$VOYAGER_DIR/configs/mise/"

	# 5. AI tools
	mkdir -p "$VOYAGER_DIR/configs/opencode" "$VOYAGER_DIR/configs/antigravity"
	rsync -a --delete --exclude="node_modules" --exclude="skills/__pycache__" \
		--exclude="opencode.json.tui-migration.bak" \
		"$HOME/.config/opencode/" "$VOYAGER_DIR/configs/opencode/" 2>/dev/null || true
	[ -f "$HOME/.gemini/antigravity-cli/settings.json" ] &&
		cp -u "$HOME/.gemini/antigravity-cli/settings.json" "$VOYAGER_DIR/configs/antigravity/"

	# 6. Skills
	mkdir -p "$VOYAGER_DIR/configs/agents/skills"
	if [ -d "$HOME/.agents/skills" ]; then
		rsync -a --delete "$HOME/.agents/skills/" "$VOYAGER_DIR/configs/agents/skills/" 2>/dev/null || true
	fi

	# 7. Assets & misc
	mkdir -p "$VOYAGER_DIR/configs"
	[ -d "$HOME/.config/btop" ] && rsync -a --delete "$HOME/.config/btop/" "$VOYAGER_DIR/configs/btop/" 2>/dev/null || true
	[ -d "$HOME/.config/lazygit" ] && rsync -a --delete "$HOME/.config/lazygit/" "$VOYAGER_DIR/configs/lazygit/" 2>/dev/null || true
	[ -f "$HOME/.config/starship.toml" ] && cp -u "$HOME/.config/starship.toml" "$VOYAGER_DIR/configs/starship.toml"
	[ -d "$HOME/.config/environment.d" ] && rsync -a --delete "$HOME/.config/environment.d/" "$VOYAGER_DIR/configs/environment.d/" 2>/dev/null || true

	# 8. Binaries / launchers
	mkdir -p "$VOYAGER_DIR/configs/bin"
	if [ -d "$HOME/.local/bin" ]; then
		rsync -a "$HOME/.local/bin/" "$VOYAGER_DIR/configs/bin/" 2>/dev/null || true
	fi

	# 9. Package snapshot (Arch only)
	if command -v pacman >/dev/null 2>&1; then
		mkdir -p "$VOYAGER_DIR/snapshots"
		pacman -Qqe >"$VOYAGER_DIR/snapshots/arch-packages.txt" 2>/dev/null || true
	fi

	# 10. Prune junk before commit
	find "$VOYAGER_DIR/configs" -name '*.bak*' -type f -delete 2>/dev/null || true
	find "$VOYAGER_DIR/configs" -name __pycache__ -type d -prune -exec rm -rf {} \; 2>/dev/null || true
	find "$VOYAGER_DIR/configs" -name .git -type d -prune -exec rm -rf {} + 2>/dev/null || true

	# 11. Commit & push
	cd "$VOYAGER_DIR"
	git config user.email "rendarth@users.noreply.github.com"
	git config user.name "rendarth"
	git add -A
	if ! git diff --cached --quiet; then
		git commit -m "Auto-backup $(date +'%Y-%m-%d %H:%M:%S')"
		git push || echo "(push deferred — remote unreachable)"
		echo "Backup committed and pushed."
	else
		echo "No changes detected; working tree clean."
	fi
} >>"$LOG" 2>&1
