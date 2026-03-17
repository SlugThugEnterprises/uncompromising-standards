# OpenCode Integration

OpenCode loads global plugins from `~/.config/opencode/plugins/`.

The installer writes:

- `~/.config/opencode/opencode.json` if it does not already exist
- `~/.config/opencode/plugins/uncompromising-standards.js`

## What the Plugin Does

The plugin subscribes to `tool.execute.before` and routes OpenCode file modifications through the same `hooks/pre-write.sh` checker used by Claude Code.

Current coverage:

- `write`
- `edit`
- `multiedit`

## Notes

- The plugin reconstructs the candidate file contents before the tool runs, then asks the existing pre-write hook to allow or block the change.
- OpenCode automatically loads local plugin files placed in `~/.config/opencode/plugins/`.
