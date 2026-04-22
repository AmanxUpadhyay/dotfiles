# Pipeline Health Check

On-demand validation of the Claude Code + superpowers pipeline. Run after plugin upgrades or when something feels off.

## Instructions

Run each check below in order. For each, report `✓ PASS` or `✗ FAIL: <reason>`. At the end, print a one-line summary: `Health check: N/M passed`.

### Checks

1. **Enabled plugins match expected list.** Read `~/.claude/settings.json`, extract `enabledPlugins`, verify all expected plugins are `true`:
   - `superpowers@superpowers-marketplace`
   - `superpowers-chrome@superpowers-marketplace`
   - `superpowers-developing-for-claude-code@superpowers-marketplace`
   - `episodic-memory@superpowers-marketplace`
   - `claude-session-driver@superpowers-marketplace`
   - `elements-of-style@superpowers-marketplace`
   - `claude-mem@thedotmack`
   - `ui-ux-pro-max@ui-ux-pro-max-skill`

2. **MCP servers respond.** Run (via Bash):
   ```bash
   curl -s --max-time 2 "http://127.0.0.1:${CLAUDE_MEM_WORKER_PORT:-37701}/api/health" | jq -r '.status // "down"'
   ```
   PASS if output is `"ok"` or includes `mcpReady:true`.

3. **Critical slash commands exist and are readable.** Verify these files exist and are symlinks:
   - `~/.claude/commands/review.md`
   - `~/.claude/commands/security-scan.md`
   - `~/.claude/commands/handoff-to-execute.md`
   - `~/.claude/commands/health-check.md`

4. **Removed files are actually gone.** These should NOT exist (deleted in Phase B):
   - `~/.claude/commands/session-note.md`
   - `~/.claude/hooks/session-end-note.sh`

5. **Recent hook activity (last 24h).** Run:
   ```bash
   find "${CLAUDE_LOG_DIR:-$HOME/.claude/logs}/hooks-fire.log" -mtime -1 | wc -l
   ```
   PASS if result is `1` (file modified within last day).

6. **Required agents loadable.** Verify these files parse as valid YAML frontmatter:
   - `~/.claude/agents/code-reviewer.md`
   - `~/.claude/agents/researcher.md`

7. **Permission mode is `acceptEdits` (not `bypassPermissions`).** Read `~/.claude/settings.json`, check `permissions.defaultMode == "acceptEdits"`.

8. **Subagent model pin is absent.** Read `~/.claude/settings.json`, verify `env.CLAUDE_CODE_SUBAGENT_MODEL` is unset (not present in the env object).

## Rules

- Run all checks even if one fails — report full results, not just first failure.
- Do not modify anything; this is a read-only validator.
- If a check's underlying file is missing but it's not required at this moment in the plan's rollout, note `N/A (not yet implemented)` instead of FAIL.
