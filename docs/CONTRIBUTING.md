# CONTRIBUTING

This guide covers the patterns you need to know to add a new hook, slash command, subagent, or cron without breaking anything. It assumes the repo already installed (see [INSTALL.md](INSTALL.md)) and that you can run `bats tests/` green from the root.

If you just want to understand the architecture first, read [ARCHITECTURE.md](ARCHITECTURE.md). This file is the "how do I do X" runbook.

---

## Development environment

You need:

- The repo checked out at `~/.dotfiles`
- `bash 4+`, `bats-core`, `jq`, `gh` all on PATH (verify with `which bash bats jq gh`)
- A Claude Code session running somewhere (most changes are testable only when Claude Code is actively using them)
- `~/.claude/` populated with the symlinks from `install.sh` — verify with `ls -la ~/.claude/hooks/ | head` and confirm you see symlinks pointing into `~/.dotfiles/claude/hooks/`

---

## Repo layout

For the reasoning behind each directory, see [ARCHITECTURE.md](ARCHITECTURE.md). For the bare structure:

```
~/.dotfiles/
├── claude/
│   ├── hooks/          # Event-triggered bash scripts (19 hooks)
│   ├── crons/          # Scheduled automation + shared libraries
│   ├── agents/         # Custom subagent definitions (.md with YAML frontmatter)
│   ├── commands/       # Slash command definitions (.md)
│   ├── launchagents/   # LaunchAgent plists (live + archived/)
│   ├── libs/           # Shared shell libraries (hooks-log.sh)
│   ├── prompts/        # Prompt templates consumed by cron scripts
│   ├── CLAUDE.md       # Global Claude Code rules (symlinked to ~/.claude/CLAUDE.md)
│   └── env.sh          # Single source of truth for env vars
├── claude-json/        # MCP server configuration
├── tests/              # bats regression suites (13 files)
├── docs/               # Audience-facing docs (you are here)
└── install.sh          # Idempotent installer
```

---

## Runbook: adding a new hook

A hook is a bash script that runs when Claude Code fires a specific lifecycle event. The full event catalog lives in [settings.hooks.md](settings.hooks.md).

### Step 1. Pick your event

Decide which event should trigger your hook. The most common ones and when they're appropriate:

| Event | Use when |
|---|---|
| `PreToolUse` | You want to block or modify a tool call before it runs |
| `PostToolUse` | You want to react after a tool call completes (format, test, log) |
| `PostToolUseFailure` | You want to log/react when a tool call errored |
| `UserPromptSubmit` | You want to inspect or block the user's prompt before Claude sees it |
| `SessionStart` | You want to inject context when a session boots |
| `Stop` | You want to do something when Claude finishes its turn (block, log, notify) |
| `PreCompact` / `PostCompact` | You want visibility into context reductions |
| `PermissionRequest` / `PermissionDenied` | You want to auto-approve or log permission flow |

`PreToolUse` can also specify a `matcher` to filter by tool name (e.g. `Bash`, `Write|Edit|MultiEdit`). `PostToolUse` supports the same.

### Step 2. Create the hook file

Path: `~/.dotfiles/claude/hooks/<your-hook-name>.sh`. Naming convention: kebab-case, verb-first when possible (e.g. `log-tool-failure.sh`, `auto-format.sh`).

Start with the canonical header block. Every hook in the repo follows this format — do not skip it:

```bash
#!/bin/bash
set -euo pipefail

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "<EventName>"
fi
# =============================================================================
# your-hook-name.sh — One-line Title
# =============================================================================
# purpose: what this hook exists to do, in a single sentence
# inputs: stdin JSON fields this hook reads; env vars it needs from env.sh
# outputs: what it prints to stdout (if anything — often JSON); exit code contract
# side-effects: anything it writes or mutates (log files, vault notes, etc.)
# =============================================================================
```

The header is load-bearing — `/hook-health` and the staleness-audit tool read these fields to catalog hooks.

### Step 3. Read stdin JSON

Claude Code passes a JSON payload on stdin. Extract what you need with `jq`:

```bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
```

Always guard against missing fields with `// empty` or `// "unknown"`.

### Step 4. Honour the exit-code contract

| Exit code | Meaning |
|---|---|
| `0` | Allow / pass through |
| `2` | Block (PreToolUse) or fail (other events) — stderr is surfaced to Claude |

For blocking `Stop` specifically, use JSON output instead of exit code:

```bash
cat <<EOF
{"decision": "block", "reason": "Your reason here"}
EOF
```

Returning `decision: block` on Stop requires the hook to be registered with `async: false` — otherwise Claude Code ignores it.

### Step 5. Register the hook in settings.json

`~/.claude/settings.json` → `hooks` object. Add a block for your event if it doesn't exist yet:

```json
"PostToolUseFailure": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash \"$HOME/.claude/hooks/your-hook-name.sh\"",
        "timeout": 5,
        "async": true
      }
    ]
  }
]
```

`timeout` is seconds. Keep it tight (`5` for logging, `10–30` for anything that does I/O). `async: true` means the hook can't block Claude's response — use it for anything that doesn't need to gate behaviour.

### Step 6. Create the symlink

`~/.claude/hooks/` holds symlinks into `~/.dotfiles/claude/hooks/`. Either re-run the installer or manually symlink:

```bash
ln -sf ~/.dotfiles/claude/hooks/your-hook-name.sh ~/.claude/hooks/your-hook-name.sh
chmod +x ~/.dotfiles/claude/hooks/your-hook-name.sh
```

### Step 7. Write the bats test

Create `tests/<your_hook_name>.bats` (underscores, not hyphens, in filename). Minimum test cases:

- Happy path — hook receives valid input and exits 0 or produces expected output
- Empty/missing input — hook handles gracefully
- Failure mode specific to your hook — e.g. if you block, assert exit 2 and stderr message

See [Testing pattern](#testing-pattern) below for the exact stub-via-PATH idioms.

### Step 8. Run the test

```bash
cd ~/.dotfiles && bats tests/<your_hook_name>.bats
```

All green before committing.

---

## Runbook: adding a new slash command

A slash command is a Markdown file with instructions to Claude. When the user types `/<name>`, Claude reads the file and follows it.

### Step 1. Create the file

Path: `~/.dotfiles/claude/commands/<name>.md`. Naming: kebab-case. No extension in the command itself (`/health-check` reads `health-check.md`).

### Step 2. Use frontmatter

Minimum frontmatter:

```markdown
---
description: One-line summary shown in command palette
---
```

Additional fields:

| Field | Purpose |
|---|---|
| `model` | Override the session default (e.g. `claude-opus-4-7` for `/review` and `/security-scan`) |
| `allowed-tools` | Restrict which tools Claude can use while running this command |
| `disable-model-invocation` | Prevent models from invoking the command mid-message |

### Step 3. Write the body

Markdown instructions for Claude. Conventions observed in the repo:

- Structure: `## What the user wants` → `## Steps` → `## Rules`
- Reference `$ARGUMENTS` for the text after the slash-command name
- Keep it dumb-explicit — Claude follows literally, so vague instructions produce vague output
- End with a Rules section that enumerates "never do X" constraints

### Step 4. Symlink + test

Symlink into `~/.claude/commands/` (the installer does this; do it manually if you skip the installer). Then invoke the command in a Claude Code session and verify behaviour.

Slash commands don't have bats tests — they're prompts, not code. Verification is interactive.

---

## Runbook: adding a new subagent

A subagent is a specialised Claude worker with its own model, tools, and permission scope. Agents live in `~/.dotfiles/claude/agents/` as `.md` files with YAML frontmatter.

### Step 1. Write the frontmatter

Minimum:

```yaml
---
name: my-agent-name
description: What this agent does. Used by Claude to decide when to dispatch.
model: claude-sonnet-4-6
tools: Read, Grep, Glob
---
```

All supported fields:

| Field | Purpose |
|---|---|
| `name` | Agent identifier (kebab-case) |
| `description` | Routing signal — when should Claude dispatch this agent? |
| `model` | Model pin. `claude-opus-4-7` for quality-critical work, `claude-sonnet-4-6` for cost-sensitive |
| `tools` | Comma-separated tool allow-list |
| `disallowedTools` | Comma-separated tool deny-list (useful when agent should be read-only) |
| `permissionMode` | `default`, `acceptEdits`, `plan`, or `bypassPermissions` — scoped to just this agent |
| `isolation` | `worktree` runs the agent in an isolated git worktree |
| `background` | `true` means the agent runs in parallel without blocking the user |
| `maxTurns` | Limit agent conversation turns |
| `effort` | `high` for max-reasoning work; overrides the session-level `effortLevel` |
| `initialPrompt` | Auto-submit a first turn (rarely needed) |
| `mcpServers` | Per-agent MCP server list (limit MCP scope to what the agent needs) |
| `hooks` | Per-agent hook overrides |

### Step 2. Write the system prompt

After the closing `---`, write the agent's system prompt. Keep it under ~50 lines unless the agent needs extensive knowledge.

Pattern seen in `code-reviewer.md`:

```
You are a senior X for this project. You know the project's conventions from CLAUDE.md.

When reviewing code:
1. ...
2. ...
3. ...

Format:
**Critical** (blocks merge): ...
**Important** (should fix): ...
**Minor** (optional): ...

One sentence per issue. Include file + line reference. No line-by-line narration.
```

### Step 3. Symlink and test

Symlink into `~/.claude/agents/`. Invoke the agent via the Agent tool in a Claude Code session — verify it follows its system prompt and respects its tool/permission constraints.

No bats tests for agents (they're prompts).

---

## Runbook: adding a new cron job

If your automation should run on a schedule rather than on a Claude Code event, it's a cron, not a hook. Crons live as shell scripts in `~/.dotfiles/claude/crons/` and are scheduled via launchd plists in `~/.dotfiles/claude/launchagents/`.

### Step 1. Write the cron script

Path: `~/.dotfiles/claude/crons/<cron-name>.sh`. Use the same header block as hooks but with `purpose / schedule / inputs / outputs / side-effects` where `schedule` replaces the stdin contract.

The first line of the script body should source `env.sh` and `notify-failure.sh`:

```bash
source "$HOME/.dotfiles/claude/env.sh"
source "$HOME/.dotfiles/claude/crons/notify-failure.sh"
```

Then wrap your logic in a trap that routes failures through `notify_failure`:

```bash
trap 'notify_failure "<cron-name>" "$LOG_FILE"' ERR
```

### Step 2. Write the LaunchAgent plist

Path: `~/.dotfiles/claude/launchagents/com.godl1ke.claude.<cron-name>.plist`. Follow the format in `mac-cleanup-scan.plist` — it's the canonical example for `declare -A`-safe bash invocation and env-var setup.

### Step 3. Install and verify

```bash
./claude/install-launchagents.sh
launchctl list | grep <cron-name>
```

Optionally, kickstart it manually to verify the first run:

```bash
launchctl kickstart gui/$(id -u)/com.godl1ke.claude.<cron-name>
tail ~/Library/Logs/claude-crons/<cron-name>-launchd.log
```

### Step 4. Write the bats regression

Path: `tests/<cron_name>.bats` or add cases to `crons_smoke.bats` if the test is small. Most cron tests cover: header-block presence, exit-0 on happy path, `notify_failure` fires on synthetic failure, env vars respected.

---

## Testing pattern

bats tests live in `tests/*.bats`. The repo's idiomatic patterns:

### Stubbing external binaries via PATH

When your code-under-test calls `osascript`, `terminal-notifier`, `gh`, or similar, stub them by placing a fake binary in `$BATS_TEST_TMPDIR` and prepending it to PATH:

```bash
setup() {
  cat > "$BATS_TEST_TMPDIR/osascript" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "$CAPTURE_FILE"
exit 0
EOF
  chmod +x "$BATS_TEST_TMPDIR/osascript"
  export CAPTURE_FILE="$BATS_TEST_TMPDIR/captured-args"
  export PATH="$BATS_TEST_TMPDIR:$PATH"
}
```

Canonical examples: `tests/notify_failure.bats` (stubs osascript) and `tests/env_preflight.bats` (stubs multiple binaries).

**Gotcha:** if your hook prefers binary A but falls back to binary B, stub *both*. This is the bug that leaked real notifications in `notify_failure.bats` after `terminal-notifier` was added as a preferred path.

### Sandboxing filesystem writes

`setup()` should sandbox `OBSIDIAN_VAULT` and `CLAUDE_LOG_DIR` to `$BATS_TEST_TMPDIR`:

```bash
export OBSIDIAN_VAULT="$BATS_TEST_TMPDIR/vault"
mkdir -p "$OBSIDIAN_VAULT/00-Inbox"
export CLAUDE_LOG_DIR="$BATS_TEST_TMPDIR/logs"
mkdir -p "$CLAUDE_LOG_DIR"
```

This ensures nothing leaks into the real vault or real log directory.

### Synthetic hook input

Construct the stdin JSON Claude Code would send:

```bash
run bash "$HOME/.claude/hooks/my-hook.sh" <<< '{"tool_name":"Write","file_path":"/tmp/foo.py"}'
[ "$status" -eq 0 ]
```

### Running the suite

```bash
cd ~/.dotfiles
bats tests/                      # all suites
bats tests/my_hook.bats          # one file
bats -f "specific test name" tests/my_hook.bats   # one case
```

`pr-gate.sh` runs the full suite — a broken bats run will block PR creation.

---

## Commit and PR workflow

### Conventional commits

Every commit message must use the Conventional Commits format:

```
<type>(<scope>): <subject>

<optional body>
```

Types used in this repo:

| Type | Use for |
|---|---|
| `feat` | New user-facing functionality (new hook, new command, new agent) |
| `fix` | Bug fix |
| `docs` | Documentation-only changes |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or fixing tests |
| `chore` | Tooling, dependencies, config — anything not user-visible |

Scopes observed in this repo: `hook`, `cron`, `command`, `agent`, `readme`, `install`, `contributing`, `architecture`, `launchagent`, `test`, `settings`, and module names like `checkpoint`, `session-start`, `pr-gate`, `claude-mem`.

### Branch + PR

The repo uses GitHub Flow:

1. Branch off `main`: `git checkout -b feat/my-feature`
2. Commit atomically — one logical change per commit
3. Push: `git push -u origin feat/my-feature`
4. Open PR: `gh pr create`
5. `pr-gate.sh` runs: ruff format, ruff lint, pytest, bats, secrets scan, pip-audit. All must pass.
6. Merge via squash: `gh pr merge --squash`
7. Branch auto-deletes on merge (if that setting is enabled)

### Before opening a PR

Self-review checklist:

- [ ] `bats tests/` green
- [ ] Any new hook has a header docstring
- [ ] Any new hook is registered in `~/.claude/settings.json` AND has a symlink in `~/.claude/hooks/`
- [ ] Any new slash command has a symlink in `~/.claude/commands/`
- [ ] Any doc changes are reflected in both the primary file and any cross-reference (README, ARCHITECTURE, INSTALL)
- [ ] No references to deleted files or retired hooks
- [ ] Commit messages follow Conventional Commits

### What `pr-gate.sh` actually checks

The pre-PR gate runs automatically when you invoke `gh pr create` via Claude Code (via the `pr-gate.sh` hook on `PreToolUse` matching Bash). It:

1. Runs `ruff format` + `ruff check` on Python files
2. Runs `pytest` if a pyproject.toml is found
3. Runs `bats tests/` if the tests directory exists
4. Scans for obvious secrets (API keys, tokens)
5. Runs `pip-audit` on Python dependencies

A failure in any step blocks the `gh pr create` command with exit 2. Fix the failure and retry.
