# Border Studio

An Omarchy plugin for window border palettes, rounded corners, adjustable border widths, bright gradient (“shining”) borders, and automatic palette cycling.

## Install from GitHub

```bash
omarchy plugin add https://github.com/zaki2993/borders.git --enable
```

The installer asks where to place the widget in the bar. With a non-interactive
install, use `--yes` and enable it afterward:

```bash
omarchy plugin add https://github.com/zaki2993/borders.git --yes
omarchy plugin enable zakarch.borders right
```

Only install plugins you trust: Omarchy plugins run as code inside the
long-running `omarchy-shell` process.

Border Studio supports automatic palette cycling every 1, 2, or 3 seconds, 30 seconds, 2 minutes, or 5 minutes. Choose **Off** to stop cycling. Border widths from 0 to 6 px, window and screen spacing from 0 to 32 px, and rounding can be selected independently.

## First start

```bash
omarchy plugin enable zakarch.borders right
```

Then click the `󰕂` icon in the bar. Changes are applied directly through
Hyprland's Lua runtime API, so no edits to `~/.config/hypr/hyprland.lua` are
required. Settings are stored in
`~/.local/state/omarchy/zakarch.borders/settings.json` and reapplied whenever
the plugin starts.

## Requirements

- Omarchy's Quickshell shell and plugin support
- Hyprland with `hyprctl` (the plugin uses `hl.config` when available and
  falls back to legacy `hyprctl keyword` commands)
- `hyprctl` and `mkdir` available on `PATH` (both are standard Omarchy tools)

The plugin has no package, Python, Node.js, or external service dependencies.

On first start, the defaults are a 3-second palette cycle, 8 px rounding,
2 px borders, and 2 px window/screen spacing. Settings are saved per user and
take precedence over these defaults on later starts.

## Remove

```bash
omarchy plugin disable zakarch.borders
rm -rf ~/.config/omarchy/plugins/zakarch.borders ~/.local/state/omarchy/zakarch.borders
hyprctl reload
```

After removal, restore the original values in `~/.config/hypr/looknfeel.lua` if you want to undo the plugin’s last applied colors or rounding.
