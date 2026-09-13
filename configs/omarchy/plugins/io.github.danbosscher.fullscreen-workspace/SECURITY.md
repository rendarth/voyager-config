# Security

## Runtime access

Fullscreen Workspace runs as unsandboxed QML inside `omarchy-shell`, as all
Omarchy shell plugins do. It reads only:

- Hyprland's public toplevel, workspace, class, address, and fullscreen state
- its own settings injected through Omarchy's `shell.json`

It sends only window-move dispatches to the running Hyprland compositor. It
does not execute subprocesses, access the network, inspect window contents, use
privilege escalation, or write files directly.

## Reporting a vulnerability

Please open a private GitHub security advisory for the repository rather than
publishing exploitable details in a public issue.
