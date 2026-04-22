# Claude Code Pipeline Upgrade — Design

**Date:** 2026-04-22
**Owner:** Aman Upadhyay
**Scope:** Four-phase tuning of the Claude Code setup: gap fixes, redundancy cut, model routing, passive self-healing.

## Objective

Improve the existing Claude Code + superpowers pipeline without breaking what works. Fix proactive-tool-use gaps, eliminate four concrete redundancies, route quality-critical work to Opus 4.7, and add passive observability for upstream breakage. All changes stay in dotfiles — zero modification of plugin or Claude Code internals.

## Non-goals

- No changes to the brainstorm → spec → plan → execute flow.
- No changes to the auto-PR gate (code-review + security-scan).
- No changes to `safety-guards.sh`.
- No changes to the Obsidian second-brain pipeline.
- No hard-enforcement hooks for Context7 / researcher triggers (soft enforcement only).

## Phase 1 — Gap Fixes

### 1.1 CLAUDE.md rules

Append to `~/.dotfiles/claude/CLAUDE.md`:

- **Context7 rule:** For any library, framework, SDK, API, or CLI named in any workflow phase, invoke `mcp__context7__resolve-library-id` followed by `mcp__context7__query-docs` before committing to an API shape in brainstorm decisions, spec, plan, or implementation.
- **Researcher rule A:** When the `superpowers:brainstorming` skill activates, dispatch the `researcher` agent in the background immediately to investigate the topic, unknowns, and relevant prior art.
- **Researcher rule B:** Before writing any spec, dispatch the `researcher` agent in the background to validate libraries and assumptions surfaced during brainstorming.
- **Handoff auto-trigger rule:** When `superpowers:executing-plans` reaches the decision point of "subagent-driven-development or inline implementation?", first generate the `/handoff-to-execute` prompt as part of the response, then present the two options.
- **Opus override for superpowers:code-reviewer:** When dispatching `superpowers:code-reviewer` via the Agent tool, always pass `model: "opus"`. Plan-vs-implementation review is too consequential for Sonnet.

### 1.2 New slash command `/handoff-to-execute`

File: `~/.dotfiles/claude/commands/handoff-to-execute.md`

Generates a medium-length, hybrid handoff prompt for a fresh session. Output contains:

- Project path and current git branch.
- Paths to the spec and plan files.
- 3–5 line summary: objective, key decisions, known constraints.
- Tooling instruction: invoke `superpowers:subagent-driven-development`.
- Guardrails: do not re-brainstorm, do not re-plan, do not modify the spec.
- Available agents and skills in the environment.

User copies the output into Session B. Session A remains alive as the review seat. When Session B reports completion, Session A reviews.

### 1.3 Researcher agent frontmatter update

File: `~/.dotfiles/claude/agents/researcher.md`

Update the `description` field to include proactive-use triggers. Add a line like: "Use proactively at the start of brainstorming and before writing any spec."

## Phase 2 — Redundancy Cut

### 2.1 breadcrumb-writer double-fire

`~/.claude/settings.json`: remove the `SessionEnd` hook registration for `breadcrumb-writer.sh`. Keep the `Stop` registration.

### 2.2 claude-mem double-injection

`~/.dotfiles/claude/hooks/session-start.sh`: delete section 6 (`# 6. claude-mem: relevant past observations for this project`) — the HTTP curl block to `127.0.0.1:${CLAUDE_MEM_WORKER_PORT:-37777}/api/search`. The claude-mem plugin's own SessionStart hook already injects observations via its MCP `IMPORTANT` tool convention. Section boundaries are marked by the dash-line comment headers already in the file.

### 2.3 Stale and unused session-note paths

- Delete `~/.claude/hooks/session-end-note.sh` (11-line no-op placeholder, not wired up in settings.json).
- Delete `~/.dotfiles/claude/commands/session-note.md` (manual fallback not used in practice; `session-stop.sh` covers the automatic case).

### 2.4 Permission-mode contradiction

`~/.claude/settings.json`:

- Change `"defaultMode": "bypassPermissions"` → `"defaultMode": "acceptEdits"`.
- Remove `"skipDangerousModePermissionPrompt": true`.

Keep: `permissions.allow` list, `permission-auto-approve.sh` hook, `safety-guards.sh` hook.

Net effect: file edits still flow without prompts; Bash commands match against the allow-list first, then the auto-approve hook; unknown Bash still prompts; dangerous operations still hard-blocked by `safety-guards.sh`.

## Phase 3 — Model Routing

### 3.1 Remove the global subagent model pin

`~/.claude/settings.json`: delete the `CLAUDE_CODE_SUBAGENT_MODEL` env entry. Keep `effortLevel: high`.

### 3.2 Agent frontmatter updates

- `~/.dotfiles/claude/agents/code-reviewer.md`: change `model` from `claude-sonnet-4-6` to `claude-opus-4-7`. `effort: high` is already set; leave unchanged.
- `~/.dotfiles/claude/agents/researcher.md`: change `model` from `claude-sonnet-4-6` to `claude-opus-4-7`. `effort: high` is already set; leave unchanged.

### 3.3 Slash command frontmatter updates

- `~/.dotfiles/claude/commands/review.md`: add `model: claude-opus-4-7`.
- `~/.dotfiles/claude/commands/security-scan.md`: add `model: claude-opus-4-7`.

### 3.4 Superpowers:code-reviewer override

Handled by the CLAUDE.md rule in section 1.1. No plugin modification.

### 3.5 Defaults

All other subagents (general-purpose, Plan, Explore, implementation subagents, plugin-provided agents) inherit from session default. Main-thread model is chosen at session start: Opus for brainstorm/spec/plan/architecture; Sonnet acceptable for pure coding sessions.

## Phase 4 — Self-Healing Safety Net (Passive)

### 4.1 Three new hook handlers

All live in `~/.dotfiles/claude/hooks/`. Each sources `libs/hooks-log.sh`, calls `log_hook_fire` with the event name, and extracts relevant JSON fields for context.

- `log-tool-failure.sh` → `PostToolUseFailure`. Logs tool name, error, cwd. Catches silent Write/Edit/Bash failures not currently visible.
- `log-stop-failure.sh` → `StopFailure`. Logs failure category (rate-limit / auth / billing / other). Surfaces conditions that currently fail silently.
- `log-post-compact.sh` → `PostCompact`. Logs compaction source, token delta. Pairs with the existing `precompact.sh` for before/after visibility.

All three async, `timeout: 5`.

### 4.2 settings.json registration

Add three new hook blocks to `~/.claude/settings.json`:

```json
"PostToolUseFailure": [{"hooks": [{"type": "command", "command": "bash \"$HOME/.claude/hooks/log-tool-failure.sh\"", "timeout": 5, "async": true}]}],
"StopFailure":       [{"hooks": [{"type": "command", "command": "bash \"$HOME/.claude/hooks/log-stop-failure.sh\"", "timeout": 5, "async": true}]}],
"PostCompact":       [{"hooks": [{"type": "command", "command": "bash \"$HOME/.claude/hooks/log-post-compact.sh\"", "timeout": 5, "async": true}]}]
```

### 4.3 Daily surfacing

No changes to the existing `hook-health.md` skill. It reads from the hook log; new events appear in the daily digest automatically.

### 4.4 `/health-check` slash command

File: `~/.dotfiles/claude/commands/health-check.md`. On-demand pipeline validator. Walks through:

- Enabled plugins match expected list.
- MCP servers respond (obsidian, context7, claude-mem, etc.).
- Critical commands exist and are readable: `/review`, `/security-scan`, `/handoff-to-execute`, `/health-check`.
- Removed files are actually gone: `/session-note` command file, `session-end-note.sh` hook file.
- Recent hook activity present in log (last 24h).
- Required agents loadable.

Reports pass/fail per check. Run after plugin upgrades or when something feels off.

## Architecture principles upheld

- **Upstream safety:** every change is in dotfiles or user-level config. Zero modifications to plugin or Claude Code internals. Auto-updates cannot break these changes.
- **Defense in depth:** permission layer (allow-list + auto-approve hook + safety-guards) replaces the current single-point bypass model.
- **Passive over active:** new observability adds no behavioral risk. New triggers use soft enforcement via CLAUDE.md, not hard enforcement via hooks.
- **Quality-first on critical paths:** code review, security scan, and research all run on Opus 4.7 with max effort. Everything else stays Sonnet for cost.

## Files changed (summary)

| Path | Action |
|---|---|
| `~/.dotfiles/claude/CLAUDE.md` | Append 5 rules |
| `~/.dotfiles/claude/commands/handoff-to-execute.md` | Create |
| `~/.dotfiles/claude/commands/health-check.md` | Create |
| `~/.dotfiles/claude/commands/review.md` | Add `model:` frontmatter |
| `~/.dotfiles/claude/commands/security-scan.md` | Add `model:` frontmatter |
| `~/.dotfiles/claude/commands/session-note.md` | Delete |
| `~/.dotfiles/claude/agents/researcher.md` | Update description; set `model: claude-opus-4-7` |
| `~/.dotfiles/claude/agents/code-reviewer.md` | Set `model: claude-opus-4-7` |
| `~/.dotfiles/claude/hooks/session-start.sh` | Remove section 6 (claude-mem curl block — matches header `# 6. claude-mem: relevant past observations for this project`) |
| `~/.dotfiles/claude/hooks/log-tool-failure.sh` | Create |
| `~/.dotfiles/claude/hooks/log-stop-failure.sh` | Create |
| `~/.dotfiles/claude/hooks/log-post-compact.sh` | Create |
| `~/.claude/settings.json` | Permission mode switch; remove env pin; register 3 new hook events; remove breadcrumb SessionEnd registration |
| `~/.claude/hooks/session-end-note.sh` | Delete |

## Success criteria

- Context7 fires automatically on library mentions across phases.
- Researcher dispatches at brainstorm start and pre-spec.
- `/handoff-to-execute` generates usable fresh-session prompts at the right moment.
- Code reviews and security scans run on Opus 4.7.
- Permission prompts appear only for genuinely unknown Bash commands.
- hook-health daily digest includes tool-failure, stop-failure, post-compact events.
- `/health-check` reports all-green immediately after implementation.
- Zero regressions: brainstorm → spec → plan → execute flow works identically; auto-PR gate still runs; Obsidian notes still written; safety guards still block dangerous ops.

## Open questions / risks

- **Researcher on Opus token cost:** firing twice per brainstorm + ad-hoc, Opus is expensive. Mitigation: `background: true` means it runs in parallel without blocking work; if monthly cost spikes unacceptably, downgrade to Sonnet for this one agent.
- **Permission mode change blast radius:** switching away from bypassPermissions may surface prompts on flows that currently just work. Mitigation: self-teaching hook rewrite (deferred) reduces this over time; manually adding rules to `permissions.allow` is easy.
- **Soft-enforcement reliability for Context7:** CLAUDE.md rules get ~95% adherence, not 100%. Hard enforcement would require modifying superpowers skills, which violates the upstream-safety principle. Accepted trade-off.
