# Claude Code Hook Configuration

Documents each hook event wired in `claude/settings.json`. Handler purposes are drawn from the DOC001 header comments in each script.

---

## Hook Table

| Event | Matcher | Command | Handler purpose |
|---|---|---|---|
| `SessionStart` | `startup` | `session-start.sh` | Injects git context, org detection, recent Obsidian session notes, org context file, and repo breadcrumbs into the session as `additionalContext` |
| `PreToolUse` | `Bash` | `safety-guards.sh` | Pattern-matches every Bash command before execution and hard-blocks destructive operations (rm -rf, force push, hard reset, destructive SQL, curl-pipe-shell, chmod 777) via exit 2 |
| `PreToolUse` | `Bash` | `pr-gate.sh` | Blocks PR creation and remote pushes until ruff format, ruff lint, pytest, secrets scan, and pip-audit all pass |
| `PreToolUse` | `Write\|Edit\|MultiEdit` | `protect-files.sh` | Intercepts Write/Edit/MultiEdit tool calls and blocks any targeting credential files, SSH/AWS configs, or secret key material |
| `PostToolUse` | `Write\|Edit\|MultiEdit` | `auto-format.sh` | Deterministically formats every Python file Claude edits via ruff, guaranteeing formatting even if CLAUDE.md instructions are ignored |
| `PostToolUse` | `Write\|Edit\|MultiEdit` | `auto-test.sh` | Provides immediate test feedback when Claude edits a Python file by finding and running the corresponding test file; returns failures as `additionalContext` |
| `PostToolUse` | `Write\|Edit\|MultiEdit` | `test-fix-detector.sh` | Detects when Claude modifies a test or spec file and reminds it via `additionalContext` to document any bug fix in the Bug Jar at session end |
| `UserPromptSubmit` | _(any)_ | `prompt-injection-guard.sh` | Scans each user prompt against a pattern list of known injection attempts and blocks them before they reach Claude |
| `PermissionRequest` | _(any)_ | `permission-auto-approve.sh` | Intercepts PermissionRequest events and auto-approves known-safe read-only tools (Read, Glob, Grep) and safe bash commands without showing the user a dialog |
| `PermissionDenied` | _(any)_ | `permission-denied.sh` | Fires after auto mode classifier denials; logs all denials to a rotating file and returns `retry=true` for safe read-only operations that were over-denied |
| `Stop` | _(any)_ | `stop-notification.sh` | Fires a macOS notification via osascript when Claude completes a non-trivial task, providing audio and visual feedback; skips automated sessions and tool_use stops |
| `Stop` | _(any)_ | `session-stop.sh` | Fires on Stop hook and blocks Claude from finishing until it writes a session summary note to Obsidian; keeps Claude in-session so MCP tools remain authenticated |
| `SessionEnd` | _(any)_ | `breadcrumb-writer.sh` | Writes a lightweight `.claude/breadcrumbs.md` into the project repo at session end so the next session can locate relevant vault notes |
| `SessionEnd` | _(any)_ | `session-end-note.sh` | _(handler; see script for details)_ |

---

## Notes

- All hooks run as `bash` subprocesses. The command string is passed to `bash -c` by the harness.
- `async: true` hooks (auto-test, stop-notification, session-stop, breadcrumb-writer) do not block Claude's response.
- `timeout` values are set per hook; PreToolUse hooks that block (safety-guards, pr-gate, protect-files) have no explicit timeout and default to the harness global.
- Hook scripts source `$HOME/.claude/env.sh` where they need environment variables (OBSIDIAN_VAULT, ORG_MAP, CLAUDE_BIN, CLAUDE_LOG_DIR).
- `session-stop.sh` uses a `stop_hook_active` guard to prevent infinite loop when Claude is blocked by the hook itself.
