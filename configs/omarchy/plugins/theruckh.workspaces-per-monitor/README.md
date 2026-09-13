# Workspaces Per Monitor

A Hyprland workspace switcher for the Omarchy Quattro bar that is aware of
multiple monitors.

On a typical two-monitor Omarchy setup the default `omarchy.workspaces` widget
shows the same numbered workspaces (1-10) on **both** screens. This plugin
keeps each bar tidy by showing **only the workspaces that belong to that
monitor's bar**, and it can additionally collapse a range of workspaces into a
single compact slot.

## Install

```sh
omarchy plugin add https://github.com/<yourname>/workspaces-per-monitor.git --enable
```

## Usage

Add the widget to the bar and replace the built-in `omarchy.workspaces` entry
in `~/.config/omarchy/shell.json`:

```jsonc
{
  "bar": {
    "layout": {
      "left": [
        { "id": "omarchy.menu" },
        { "id": "theruckh.workspaces-per-monitor" }
      ]
    }
  }
}
```

## Configure

All behavior is controlled by the widget's `settings` block in
`shell.json`:

```jsonc
{
  "id": "theruckh.workspaces-per-monitor",
  "settings": {
    "perMonitor": true,
    "limit": 0,
    "dynamicStart": 0
  }
}
```

| Setting         | Default | Purpose |
|-----------------|---------|---------|
| `perMonitor`    | `true`  | Show only the workspaces of the monitor this bar is on. Set `false` to list all workspaces on every screen (built-in behavior). |
| `limit`         | `0`     | Maximum number of workspace buttons in the fixed list. `0` means no limit. |
| `dynamicStart`  | `0`     | Collapse workspaces with id >= this value into a single trailing button. `0` disables the collapse. |

### Example: compact 1-5 + a single 6-9 slot

Show the first five workspaces as buttons and collapse 6-9 into one button
that follows you to whichever of them is active:

```jsonc
{
  "id": "theruckh.workspaces-per-monitor",
  "settings": {
    "perMonitor": true,
    "dynamicStart": 6
  }
}
```

## How per-monitor detection works

The widget has no direct window handle from the shell, so it resolves the
monitor of the active bar surface by matching the widget's global position
against each `Quickshell` screen's geometry. It then lists the workspaces that
Hyprland reports on that monitor (each `HyprlandWorkspace` carries its
`monitor`), instead of repeating the same id list on every screen.

## Remove

```sh
omarchy plugin remove theruckh.workspaces-per-monitor
```

## License

MIT
