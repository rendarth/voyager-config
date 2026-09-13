# Fullscreen Workspace for Omarchy

Fullscreen Workspace is a headless Omarchy service plugin that gives true
fullscreen windows a workspace of their own. When a game, video, presentation,
or other application enters fullscreen, the plugin moves that exact window to
a configurable dedicated workspace. It can move the window back when
fullscreen ends.

Maximized windows are not affected.

## Requirements

- Omarchy 4.0 or newer with the Quattro shell plugin system
- Hyprland 0.56 or newer

There are no additional packages, background daemons, network requests, or
privileged setup steps.

## Install

```sh
omarchy plugin add https://github.com/danbosscher/omarchy-fullscreen-workspace.git --enable
```

The defaults are intentionally ready to use:

- dedicated workspace: `9`
- return to the original workspace when fullscreen ends: enabled
- follow the window when it enters and exits fullscreen: enabled
- move windows that were already fullscreen when the plugin starts: disabled
- move windows out of special workspaces: disabled
- Omarchy's screensaver is always excluded

If you previously added a fullscreen event handler to
`~/.config/hypr/hyprland.lua`, remove it before enabling this plugin so the two
implementations do not both move the same window.

## Configure

Settings are stored inline on the plugin entry in
`~/.config/omarchy/shell.json`. The plugin provides IPC commands so the file
does not need to be edited by hand:

```sh
# Use workspace 8 instead of 9 (valid range: 1-10).
omarchy-shell fullscreen-workspace setWorkspace 8

# Leave windows on the dedicated workspace after fullscreen ends.
omarchy-shell fullscreen-workspace setReturnOnExit false

# Move without changing focus when entering or exiting fullscreen.
omarchy-shell fullscreen-workspace setFollowOnEnter false
omarchy-shell fullscreen-workspace setFollowOnExit false

# On the next shell/plugin start, also move windows already fullscreen.
omarchy-shell fullscreen-workspace setMoveExistingOnStart true

# Allow fullscreen windows to move out of special workspaces such as scratchpads.
omarchy-shell fullscreen-workspace setMoveFromSpecialWorkspaces true

# Add application classes that should never move (comma-separated).
omarchy-shell fullscreen-workspace setExcludedClasses "org.example.presenter,mpv"

# Show effective settings and runtime state.
omarchy-shell fullscreen-workspace status

# Restore every setting to its default.
omarchy-shell fullscreen-workspace reset
```

The equivalent `shell.json` entry is:

```json
{
  "id": "io.github.danbosscher.fullscreen-workspace",
  "workspace": 8,
  "returnOnExit": true,
  "followOnEnter": true,
  "followOnExit": true,
  "moveExistingOnStart": false,
  "moveFromSpecialWorkspaces": false,
  "excludedClasses": ["org.example.presenter", "mpv"]
}
```

Keep that object inside the top-level `plugins` array. Omitted settings use the
defaults listed above.

## Behavior and edge cases

- The original workspace is remembered separately for each fullscreen window.
- If fullscreen starts on the dedicated workspace, the window stays there and
  no return workspace is recorded.
- Closing a fullscreen window clears its remembered state.
- Restarting or disabling the Omarchy shell clears in-memory return state. By
  default, already-fullscreen windows are left where they are after a restart.
- Named source workspaces are preserved when a window returns.
- Special workspaces are ignored by default because moving a fullscreen
  scratchpad is usually surprising.
- `org.omarchy.screensaver` is always excluded so idle and lock behavior is not
  disrupted.

## Disable or remove

```sh
omarchy plugin disable io.github.danbosscher.fullscreen-workspace
omarchy plugin remove io.github.danbosscher.fullscreen-workspace
```

Disabling or removing the plugin stops future moves and removes its entry from
`shell.json`. It does not edit Hyprland configuration or move existing windows.

## Security and privacy

Omarchy plugins run unsandboxed inside `omarchy-shell`. This plugin only reads
Hyprland's public window metadata and its own injected `shell.json` settings.
It sends bounded window-move dispatches to Hyprland. It does not inspect window
contents, access the network, execute subprocesses, or modify files directly.

## Development

```sh
bash test/check.sh
```

The checks cover the JavaScript logic, QML imports and types, Omarchy manifest,
JSON syntax, and whitespace errors.

## License

MIT — see [LICENSE](LICENSE).
