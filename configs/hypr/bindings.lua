-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Replace Nautilus with Thunar as file manager
hl.unbind("SUPER + SHIFT + F")
o.bind("SUPER + SHIFT + F", "File manager", "thunar")
hl.unbind("SUPER + ALT + SHIFT + F")
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", "thunar")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")



-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Added by the xadacka.window-switcher plugin.
o.bind("SUPER + GRAVE", "Window switcher", "/home/pat/.config/omarchy/plugins/io.github.xadacka.window-switcher/bin/omarchy-window-switcher")

-- Stage workspace overview
o.bind("ALT + TAB", "Stage overview", "omarchy-shell shell toggle zzwong.stage")

-- Keybindings for AI Agents (AGY & Opencode)
hl.unbind("SUPER + SHIFT + A")
o.bind("SUPER + SHIFT + A", "AGY Agent", "omarchy-launch-tui --app-id=org.omarchy.agy agy")

hl.unbind("SUPER + SHIFT + CTRL + A")
o.bind("SUPER + SHIFT + CTRL + A", "Opencode Agent", "omarchy-launch-tui --app-id=org.omarchy.opencode opencode")

-- App launchers
o.bind("SUPER + M", "Spotify", "omarchy-launch-spotify")
o.bind("SUPER + D", "Discord", "discord")
o.bind("SUPER + E", "Steam", "steam")
o.bind("SUPER + H", "Heroic Games Launcher", "heroic")



-- Keybindings overlay menu
hl.unbind("SUPER + K")
o.bind("SUPER + K", "Keybindings", "omarchy-menu-keybindings")

-- System power / suspend (Lock is default: SUPER + CTRL + L)
o.bind("SUPER + SHIFT + ESCAPE", "Suspend system", "systemctl suspend")




