# ARCHITECTURE

A single-page orientation to how this dotfiles repo is shaped and why. Optimised for you-in-six-months opening the repo and needing to remember how it fits together. For the "how do I add X" runbooks see [CONTRIBUTING.md](CONTRIBUTING.md). For initial setup see [INSTALL.md](INSTALL.md).

---

## Component diagram

```
        ┌──────────────────────────────────────────────────────────────┐
        │                         YOUR TERMINAL                        │
        │                                                              │
        │     $ claude                                                 │
        └────────────────────────────┬─────────────────────────────────┘
                                     │
                                     ▼
        ┌──────────────────────────────────────────────────────────────┐
        │                      CLAUDE CODE SESSION                     │
        │                                                              │
        │   Reads ~/.claude/settings.json (hooks, plugins, env, allow) │
        │   Reads ~/.claude/CLAUDE.md   (global rules + proactive use) │
        │                                                              │
        └──┬──────┬─────────────────────────────┬────────────┬─────────┘
           │      │                             │            │
           │      │ emits lifecycle events      │ invokes    │ reads
           │      ▼                             ▼            ▼
           │  ┌─────────────┐          ┌──────────────┐  ┌────────────┐
           │  │  HOOKS      │          │  MCP SERVERS │  │  SUBAGENTS │
           │  │ (19 bash    │          │              │  │            │
           │  │  scripts)   │          │  context7    │  │  code-     │
           │  │             │          │  obsidian    │  │  reviewer  │
           │  │  source     │          │  linear      │  │  researcher│
           │  │  env.sh     │          │  sequential- │  │            │
           │  │  + libs/    │          │  thinking    │  │  (Opus 4.7)│
           │  │             │          │  claude-mem  │  │            │
           │  └──────┬──────┘          │  episodic-   │  └────────────┘
           │         │                 │  memory      │
           │         │ writes          │  ...         │
           │         ▼                 └──────┬───────┘
           │  ┌─────────────┐                 │
           │  │  OBSIDIAN   │◀────────────────┘
           │  │   VAULT     │
           │  │             │
           │  │ 06-Sessions │◀── session-stop.sh, checkpoint.md
           │  │ 04-Knowledge│◀── test-fix-detector.sh, hook-health.md
           │  │ 00-Inbox    │◀── notify-failure.sh
           │  └─────────────┘
           │
           │ scheduled (not event-driven)
           ▼
        ┌─────────────────────────────────┐
        │  LAUNCHD AGENTS                 │
        │                                 │
        │  claude-mem-worker  (KeepAlive) │
        │  log-rotate         (Sun 11:00) │
        │  mac-cleanup-scan   (Sun 10:00) │
        │                                 │
        │  (retros/weekly migrated to     │
        │  Claude Desktop Scheduled Tasks)│
        └─────────────────────────────────┘
```

The three independent concerns — **event-driven hooks**, **MCP servers**, **scheduled crons** — are deliberately separate. Hooks run because Claude Code did something; crons run because a clock said so; MCP servers run because a tool was invoked. They never call each other directly; they meet at the Obsidian vault and the hook-fire log.

---

## Hook lifecycle

Hooks are the deterministic layer. They enforce rules the LLM is advised to follow, so rule compliance doesn't depend on the LLM's attention budget.

Events fire in this order for a typical turn:

1. **`SessionStart`** (on `claude` startup)
   - `session-start.sh` — injects git context, org detection, recent Obsidian session note, org context file, and repo breadcrumbs as `additionalContext`
2. **`UserPromptSubmit`** (each user message)
   - `prompt-injection-guard.sh` — pattern-matches against known injection payloads; blocks via exit 2
3. **`PreToolUse`** (before any tool runs)
   - `Bash` matcher: `safety-guards.sh` (blocks destructive commands), `pr-gate.sh` (gates `gh pr create` + `git push`)
   - `Write|Edit|MultiEdit` matcher: `protect-files.sh` (blocks writes to secrets/creds)
4. **`PostToolUse`** (after a tool completes)
   - `Write|Edit|MultiEdit` matcher: `auto-format.sh` (ruff), `auto-test.sh` (async pytest feedback), `test-fix-detector.sh` (bug-jar reminder)
   - `Bash|Task` matcher: `smart-checkpoint.sh` (detects milestone moments)
5. **`PostToolUseFailure`** (when a tool call errors)
   - `log-tool-failure.sh` — passive logger for silent failures
6. **`PermissionRequest`** (when Claude asks for permission)
   - `permission-auto-approve.sh` — auto-allows Read/Glob/Grep and safe read-only Bash
7. **`PermissionDenied`** (after auto-mode classifier denies)
   - `permission-denied.sh` — logs denials, retries safe ops
8. **`PreCompact`** (before context compaction)
   - `precompact.sh` — ensures session note is current before summary loses it
9. **`PostCompact`** (after compaction)
   - `log-post-compact.sh` — passive logger paired with precompact
10. **`Stop`** (Claude finishes its turn)
    - `stop-notification.sh` — macOS notification (async)
    - `breadcrumb-writer.sh` — writes `.claude/breadcrumbs.md` in the repo (async)
    - `session-stop.sh` — **sync** — blocks Claude via `decision: block` until it writes the session note
11. **`StopFailure`** (rate-limit / auth / billing errors)
    - `log-stop-failure.sh` — passive logger

Hooks that are not in the main flow:
- **`detect-org.sh`** — library, sourced by others; maps CWD to org name via `org-map.json` with longest-match-wins

The canonical event-to-handler catalog is in [settings.hooks.md](settings.hooks.md).

---

## Cron pipeline

Scheduled jobs run as **user LaunchAgents**, not crontab entries (see [Design principles](#design-principles)). All LaunchAgents live in `~/.dotfiles/claude/launchagents/` — active plists at the top, retired/migrated ones in `archived/`.

### Live agents (3)

| Agent | Schedule | Purpose |
|---|---|---|
| `com.godl1ke.claude-mem-worker` | On login + KeepAlive | Resolves and launches the claude-mem `worker-service.cjs` via bun; keeps the memory MCP server running |
| `com.godl1ke.claude.log-rotate` | Sundays 11:00 | Deletes cron/hook logs older than 30 days, gzips `hooks-fire.log` if > 10 MB |
| `com.godl1ke.claude.mac-cleanup-scan` | Sundays 10:00 | Scans disk cleanup targets, writes an Obsidian report if ≥ 1 GB recoverable |

### Archived agents (6)

All reasons are documented in `claude/launchagents/archived/README.md`. Summary:

| Agent | Archived | Replacement |
|---|---|---|
| `daily-retrospective` | 2026-04-07 | Claude Desktop Scheduled Tasks (cron `57 8 * * *`) |
| `daily-retro-evening` | 2026-04-07 | Claude Desktop Scheduled Tasks (cron `30 22 * * *`) |
| `weekly-report-gen` | 2026-04-07 | Claude Desktop Scheduled Tasks (cron `2 17 * * 5`) |
| `weekly-finalize` | 2026-04-07 | Claude Desktop Scheduled Tasks (cron `3 9 * * 1`) |
| `healthcheck-preflight` | 2026-04-22 | Retired — was guarding the retros that now run via Desktop |
| `healthcheck-postrun` | 2026-04-22 | Same — retired |

### Shared library

`claude/crons/notify-failure.sh` provides `notify_failure()` — used by every cron as an `ERR` trap. It fires a macOS notification via `terminal-notifier` (preferred, auto-replaces) or `osascript` (fallback), and appends a failure note to `$OBSIDIAN_VAULT/00-Inbox/<date>-cron-error.md`.

---

## MCP server stack

### Manually wired (in `claude-json/claude.json`)

| Server | What it provides |
|---|---|
| `context7` | Fetches current documentation for any library, framework, SDK, API, or CLI. Used under the Proactive tool-use rule in `CLAUDE.md` — invoked before committing to an API shape. |
| `obsidian` | Read/write/search notes in the Obsidian vault. Every session note, bug-jar entry, and daily retro flows through this. |
| `linear` | Linear issue tracker integration |
| `sequential-thinking` | Multi-step reasoning tool |

### Plugin-provided (installed via `enabledPlugins` in `~/.claude/settings.json`)

| Plugin | MCP/skill contribution |
|---|---|
| `superpowers` | Core skills: brainstorming, writing-plans, executing-plans, subagent-driven-development, verification-before-completion, etc. + `code-reviewer` agent |
| `superpowers-chrome` | `chrome` browser automation via CDP + `browser-user` agent |
| `episodic-memory` | `episodic-memory` MCP — semantic search over past conversation transcripts |
| `claude-mem` | `mcp-search` — cross-session memory via a local HTTP worker. Paired with the `claude-mem-worker` LaunchAgent. |
| `claude-session-driver` | Session-driver orchestration skill |
| `elements-of-style` | Strunk & White writing clarity skill |
| `superpowers-developing-for-claude-code` | Plugin + hook development helpers |
| `ui-ux-pro-max` | UI/UX design intelligence |

The split between manual and plugin-based MCP config is deliberate — manually wired servers are project-agnostic utilities; plugins are opt-in behaviour packages.

---

## Org-awareness

The repo runs across six parallel organisations. Every session note, retro, weekly report, and bug-jar entry is routed to a different Obsidian vault folder based on which org the current working directory belongs to.

The routing is one function: `detect-org.sh`.

1. Sources `org-map.json` — a JSON map of `keyword → {org name, vault folder, wikilink}`.
2. Walks the current working directory components.
3. Scores each org by longest keyword match (not first match — longest). Case-insensitive.
4. Falls back to `default` (`Personal`) if nothing matches.
5. Exports `DETECTED_ORG`, `DETECTED_ORG_FOLDER`, `DETECTED_WIKILINK` for downstream consumers.

Consumers: `session-start.sh`, `session-stop.sh`, `breadcrumb-writer.sh`, `test-fix-detector.sh`, and the `/checkpoint` and (retired) `/session-note` slash commands.

Adding a new org = editing `org-map.json`. Nothing else needs to change.

---

## Design principles

These are load-bearing — every other choice in the repo follows from them.

### 1. Hooks over instructions

Safety guards, formatting, and test-on-save are enforced by hooks, not CLAUDE.md. The LLM's attention budget is finite; if a behaviour has to happen, it's enforced deterministically.

**Where this shows up:** `safety-guards.sh`, `auto-format.sh`, `pr-gate.sh`, `protect-files.sh`, `session-stop.sh`.

### 2. Soft enforcement for LLM behaviour

The *opposite* of principle 1 applies when what you want to enforce is judgment, not action. Context7 use, researcher dispatch at brainstorm, plan handoffs at `executing-plans` decision points — these are enforced via CLAUDE.md rules, not hard-blocking hooks.

**Why the split:** hard-enforcing LLM judgment would require modifying superpowers skills, which violates principle 4. Soft enforcement gets ~95% adherence at zero upstream risk.

### 3. Passive observability

New hooks log failures; they don't modify behaviour. `/health-check` is on-demand, not scheduled. The daily `hook-health` digest reads from the log; it doesn't intervene.

**Where this shows up:** `log-tool-failure.sh`, `log-stop-failure.sh`, `log-post-compact.sh`, `/hook-health`, `hooks-log.sh`.

### 4. Upstream safety

Zero modifications to plugins or Claude Code internals. Every customisation lives in this repo. Plugin auto-updates cannot break the pipeline.

**Where this shows up:** `enabledPlugins` + `extraKnownMarketplaces` in `settings.json` with `autoUpdate: true`. The Proactive tool-use CLAUDE.md rules override plugin skills without modifying the plugins themselves.

### 5. Per-agent model routing

Critical-path subagents run Opus 4.7; cost-sensitive ones stay on Sonnet. Decided per-agent via frontmatter, not pinned globally.

**Where this shows up:** `code-reviewer.md`, `researcher.md`, and `/review` + `/security-scan` commands all declare `model: claude-opus-4-7`. The global `CLAUDE_CODE_SUBAGENT_MODEL` env pin was removed precisely so per-agent routing works.

### 6. Defense in depth on permissions

Four overlapping layers guard tool invocations:
1. `permissions.allow` list (settings.json) — auto-allows Read, Grep, Glob, Agent
2. `defaultMode: acceptEdits` — file edits don't prompt, but unknown Bash does
3. `permission-auto-approve.sh` — auto-allows safe read-only Bash commands
4. `safety-guards.sh` — hard-blocks destructive Bash regardless of anything above

**Why not just bypassPermissions:** it removes the safety net entirely, and layer 4 then has to catch literally everything.

### 7. Obsidian as a second brain

Session notes, bug fixes, architectural decisions, project context — all persisted automatically via MCP. Nothing is written by hand in Obsidian from a Claude Code session.

**Why:** retrospective visibility. Every decision and bug has a timestamped record, searchable across sessions. `claude-mem` adds semantic search on top.

### 8. launchd over crontab

Every scheduled job runs as a user LaunchAgent. crontab is kept only as a retired reference (`claude/crontab.txt`).

**Why:** launchd gives per-job stdout/stderr capture, env var injection, and explicit domain control (`gui/<uid>`). crontab inherits a minimal env that doesn't know about Homebrew paths, `CLAUDE_BIN`, or `OBSIDIAN_VAULT`. Debugging a failed cron in launchd takes minutes; in crontab it takes hours.

### 9. TDD on shell

Every hook has a bats regression suite. `pr-gate.sh` rejects a PR that breaks one.

**Why:** hooks run on every turn and a buggy hook can block all work. Shell is notoriously fragile. bats with `$BATS_TEST_TMPDIR` stubs catches regressions cheaply.

---

## Where to find X (quick reference)

| I need... | Look at... |
|---|---|
| The event → handler mapping | `docs/settings.hooks.md` |
| A hook implementation | `claude/hooks/<name>.sh` |
| A cron implementation | `claude/crons/<name>.sh` |
| A slash command | `claude/commands/<name>.md` |
| A subagent | `claude/agents/<name>.md` |
| MCP server config | `claude-json/claude.json` |
| Enabled plugins | `~/.claude/settings.json` → `enabledPlugins` |
| Org-to-vault-folder mapping | `claude/org-map.json` |
| Global Claude Code rules | `claude/CLAUDE.md` |
| Env vars (OBSIDIAN_VAULT, CLAUDE_BIN, ...) | `claude/env.sh` |
| Shared hook library | `claude/libs/hooks-log.sh` |
| Shared cron library | `claude/crons/notify-failure.sh` |
| Tests for hook X | `tests/<name>.bats` (underscore not hyphen) |
| Archived LaunchAgent reasoning | `claude/launchagents/archived/README.md` |
| How to add a new hook/command/agent | `docs/CONTRIBUTING.md` |
| How to install on a fresh Mac | `docs/INSTALL.md` |
| Design reasoning | This file |

---

## What's NOT here

Deliberate omissions worth knowing about:

- **ADR tree** — The repo had a `docs/superpowers/adr/` tree that was removed on 2026-04-22. Past decision records are recoverable via `git log --diff-filter=D -- docs/superpowers/adr/`. The reasoning that was load-bearing is captured inline above (see [Design principles](#design-principles)); rationale that only mattered once is in the git history if you need it.
- **Per-cron runbooks** — Previously in `docs/superpowers/runbooks/`. Removed in the same sweep. For cron ops, read the cron script itself — each has a header block covering `purpose / schedule / inputs / outputs / side-effects`.
- **Plugin internals** — This repo doesn't document what `superpowers`, `claude-mem`, etc. do internally. See the upstream plugin repos.
- **Per-project CLAUDE.md** — Those live in the individual project repos, not here. The template is at `templates/project-CLAUDE.md`.
