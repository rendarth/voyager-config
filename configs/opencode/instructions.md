# System Preferences

## Privilege Escalation

Always use `pkexec` instead of `sudo` when a command requires root privileges. This user does not use `sudo` directly — use `pkexec` for all privilege escalation needs.

Examples:
- `pkexec pacman -Rns <package>`
- `pkexec systemctl restart <service>`
- `pkexec <any-command-requiring-root>`

If `pkexec` fails (e.g., in a non-graphical context or piped input), inform the user rather than falling back to `sudo`.

## Model Escalation Protocol

When running on local models (e.g. 7B models via Ollama):
- **Escalation Triggers:** If a task takes longer than **5 minutes**, requires more than **4 failed tool-execution attempts**, or involves complex architectural multi-file refactoring / deep reasoning that exceeds local model capacity:
- **Action:** Stop trial-and-error loops. Use the **`escalate`** skill to generate a structured escalation package containing:
  1. The reason for escalation.
  2. The recommended target model (e.g., Claude 3.7 Sonnet for complex coding/refactoring, Gemini 3.7 Pro for deep reasoning/Omarchy tasks, o3-mini for math/algorithms).
  3. Optimized hand-off context (goal, files modified, blocker/logs).
  4. A copy-pasteable CLI command (e.g., `claude --prompt "..."` or `agy --prompt-interactive "..."`) to immediately resume with the target model.
