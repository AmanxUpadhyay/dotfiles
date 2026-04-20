# Claude Stack Audit — Phase 2 Implementation Plan (Inventory INV002–INV007)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add 6 inventory checks (INV002–INV007) to `cstack-audit`. All Info-severity; they populate the report's inventory section and surface enumeration drift.

**Architecture:** Each check is a new `@register`ed class in `src/claude_stack_audit/checks/inventory.py` (or split into sub-modules if it grows). Each check emits zero or many Info findings (non-scoring). Some checks need external tools (`launchctl`) or filesystem reads; handled via existing `ExternalTools` and filesystem APIs.

**Tech Stack:** Same as phase 1 (Python 3.11+, uv, pytest, ruff). No new dependencies.

**Scope:**
- INV002: Cron job inventory (parse `ctx.crontab`)
- INV003: LaunchAgent inventory (plist files + `launchctl list`)
- INV004: Agent + slash command inventory (dotfiles-provided)
- INV005: MCP server inventory (settings.json `mcpServers`)
- INV006: Plugin inventory (walk `~/.claude/plugins/`)
- INV007: Env-var inventory (parse `env.sh` exports; flag unused)

**Out of scope:** Plugin-provided agents/commands (walks `~/.claude/plugins/` — defer to phase 2.5 if needed); fine-grained MCP-server probing.

**Branch:** `fix/hook-audit-28-bugs-env-centralized` (same as phase 1).

---

## Files

| Path | Change |
|------|--------|
| `src/claude_stack_audit/checks/inventory.py` | Add 6 new `@register`ed classes |
| `tests/test_inventory.py` | Add 6+ new tests (minimum one per check) |
| `tests/conftest.py` | Extend `fake_dotfiles` fixture minimally (e.g. plist files, plugin dirs, mcp_servers section in settings.json) |

---

## Tasks

### Task P2-1: INV002 — CronInventory

**Logic:** Iterate `ctx.crontab` (already parsed), emit one Info finding per entry. `artifact = script`, `message = f"{schedule} → {script}"`.

```python
@register
class CronInventory:
    id = "INV002"
    name = "cron inventory"
    criterion = Criterion.INVENTORY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for entry in ctx.crontab:
            yield Finding(
                check_id=self.id, severity=Severity.INFO,
                layer=self.layer, criterion=self.criterion,
                artifact=entry.script,
                message=f"cron {entry.schedule} → {entry.script}",
            )
```

**Test:** Fixture already has 1 crontab entry. Assert 1 finding, `schedule` in message.

- [ ] Write test, run FAIL
- [ ] Implement `CronInventory`
- [ ] Run tests, commit `feat(claude-stack-audit): add INV002 cron inventory check`

### Task P2-2: INV003 — LaunchAgentInventory

**Logic:** List `.plist` files in `claude/launchagents/`; call `ctx.external.run(["launchctl", "list"])` once and parse the output to determine `loaded` state (best-effort: match the plist's `Label` key against the `launchctl list` output). Emit Info finding per plist with `loaded=True/False` in message/details.

**Fixture extension:** Add 1 plist file with a `<key>Label</key><string>com.test.audit</string>` to `claude/launchagents/` in `fake_dotfiles`.

**Test:** Assert 1 finding for the fake plist. `launchctl list` mock via `FakeExternalTools.run` returning canned stdout (optional — safe default is "loaded=unknown" if `launchctl` isn't mocked).

- [ ] Extend `fake_dotfiles` with 1 plist file
- [ ] Write test, run FAIL
- [ ] Implement `LaunchAgentInventory` — parse plist Label via regex, check launchctl output for the label
- [ ] Run tests, commit `feat(claude-stack-audit): add INV003 launchagent inventory check`

### Task P2-3: INV004 — AgentCommandInventory

**Logic:** Enumerate `.md` files in `claude/agents/` and `claude/commands/`. Emit Info finding per file with `kind` (agent|command) in message.

**Test:** Fixture `claude/agents/` and `claude/commands/` are empty by default. Add 1 agent.md + 1 command.md to the fixture. Assert 2 findings.

- [ ] Extend `fake_dotfiles` with `agents/reviewer.md` and `commands/audit.md`
- [ ] Write test, run FAIL
- [ ] Implement `AgentCommandInventory`
- [ ] Run tests, commit `feat(claude-stack-audit): add INV004 agents and commands inventory check`

### Task P2-4: INV005 — McpServerInventory

**Logic:** Read `ctx.settings.raw.get("mcpServers", {})` (Claude Code conventional key). Emit Info per server with `name` and `transport` (stdio/http).

**Fixture extension:** Add `mcpServers` block to the fixture's `settings.json`.

**Test:** Assert 1 finding for the single fixture mcp server.

- [ ] Extend `fake_dotfiles` settings.json with `mcpServers: {"test-mcp": {"command": "node", "args": ["server.js"]}}`
- [ ] Write test, run FAIL
- [ ] Implement `McpServerInventory` — transport inferred from shape (`command` → stdio; `url` → http)
- [ ] Run tests, commit `feat(claude-stack-audit): add INV005 mcp server inventory check`

### Task P2-5: INV006 — PluginInventory

**Logic:** Walk `~/.claude/plugins/` (pass via `plugins_root` param to mirror `SymlinkIntegrity` pattern; default `Path.home() / ".claude" / "plugins"`). Enumerate directories; try to read `package.json` or `plugin.json` for version. Emit Info per plugin.

**Test:** Build a fake plugins dir in `tmp_path` with 2 fake plugin dirs (one with `package.json` containing `{"version":"1.0.0"}`, one without).

- [ ] Write test, run FAIL
- [ ] Implement `PluginInventory` with `plugins_root` parameter
- [ ] Run tests, commit `feat(claude-stack-audit): add INV006 plugin inventory check`

### Task P2-6: INV007 — EnvVarInventory

**Logic:** For each var in `ctx.env_vars`, search all `ctx.bash_scripts` (excluding `env.sh` itself) for `$VAR_NAME` or `${VAR_NAME}`. Emit Info per var with `referenced=True/False` in message. Unused vars get a Low severity escalation (not Info) — this is one Info-category check that also emits Low to flag drift.

Actually for consistency keep it all Info; the report shows counts and the user can action.

**Test:** Fixture has `OBSIDIAN_VAULT` and `CLAUDE_LOG_DIR` exports; session-stop.sh references `$HOME/Library/Logs/claude-crons/...` (not the env vars directly). Assert 2 findings emitted with both vars marked unreferenced (adjust if fixture already references one).

- [ ] Write test, run FAIL
- [ ] Implement `EnvVarInventory`
- [ ] Run tests, commit `feat(claude-stack-audit): add INV007 env var inventory check`

### Task P2-7: Re-run baseline + commit

- [ ] Run `cstack-audit run` on real dotfiles
- [ ] Inspect new findings — expect the Info count to grow substantially (crons, launchagents, plugins, env vars)
- [ ] Commit the updated report: `docs(claude-stack-audit): refresh baseline after phase 2 inventory`
