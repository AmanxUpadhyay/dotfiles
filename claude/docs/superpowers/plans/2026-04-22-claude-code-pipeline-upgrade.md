# Claude Code Pipeline Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the four-phase tuning described in `docs/superpowers/specs/2026-04-22-claude-code-pipeline-upgrade-design.md` — fix proactive-use gaps, cut four redundancies, route quality-critical subagents to Opus 4.7, and add passive observability — without breaking the working pipeline.

**Architecture:** Every change is a local dotfiles edit or an additive user-level config. Zero plugin modifications. Ordering is: additive changes first (Phase A), deletions/switches second (Phase B), model routing last (Phase C), final verification and PR (Phase D). This lets each task ship independently and keeps regressions localized.

**Tech Stack:** bash hooks, `bats` for regression tests, JSON (`jq`/`python3 -c`) for settings validation, Markdown for CLAUDE.md rules and slash commands, YAML frontmatter for agent/command definitions.

---

## File Structure (decomposition map)

| File | Role |
|---|---|
| `~/.dotfiles/claude/CLAUDE.md` | Global rules — appended with 5 new rules for Context7, researcher, handoff, Opus-override |
| `~/.dotfiles/claude/commands/handoff-to-execute.md` | New slash command — generates hybrid handoff prompt |
| `~/.dotfiles/claude/commands/health-check.md` | New slash command — on-demand pipeline validator |
| `~/.dotfiles/claude/commands/review.md` | Modified — add `model` frontmatter |
| `~/.dotfiles/claude/commands/security-scan.md` | Modified — add `model` frontmatter |
| `~/.dotfiles/claude/commands/session-note.md` | Deleted |
| `~/.dotfiles/claude/agents/researcher.md` | Modified — description nudge + model change |
| `~/.dotfiles/claude/agents/code-reviewer.md` | Modified — model change |
| `~/.dotfiles/claude/hooks/session-start.sh` | Modified — remove §6 claude-mem curl block |
| `~/.dotfiles/claude/hooks/log-tool-failure.sh` | New — PostToolUseFailure logger |
| `~/.dotfiles/claude/hooks/log-stop-failure.sh` | New — StopFailure logger |
| `~/.dotfiles/claude/hooks/log-post-compact.sh` | New — PostCompact logger |
| `~/.claude/settings.json` | Modified — permission mode switch, env pin removal, 3 hook registrations, SessionEnd breadcrumb removal |
| `~/.claude/hooks/session-end-note.sh` | Deleted |
| `~/.dotfiles/tests/pipeline_upgrade.bats` | New — regression tests for all structural changes |

---

## Task 0: Baseline Verification

**Files:**
- Verify: `~/.dotfiles/tests/*.bats`

- [ ] **Step 1: Confirm you are on the `feat/pipeline-upgrade` branch**

Run: `cd ~/.dotfiles && git branch --show-current`
Expected: `feat/pipeline-upgrade`

- [ ] **Step 2: Run the full existing test suite to establish green baseline**

Run: `cd ~/.dotfiles && bats tests/`
Expected: All tests pass. Note the count (e.g. `104 tests, 0 failures`). If any fail, STOP and fix before continuing.

- [ ] **Step 3: Capture current settings.json as a reference snapshot**

Run: `cp ~/.claude/settings.json ~/.claude/settings.json.pre-upgrade`
Expected: file copied. This is a manual rollback point, not committed to git.

---

## Phase A — Additive, Zero-Risk Changes

### Task A1: Append five new rules to CLAUDE.md

**Files:**
- Modify: `~/.dotfiles/claude/CLAUDE.md`

- [ ] **Step 1: Append the five rules at end of file**

Add after the last existing bullet in `~/.dotfiles/claude/CLAUDE.md`:

```markdown

## Proactive tool use (added 2026-04-22)

- **Context7:** For any library, framework, SDK, API, or CLI named in any workflow phase (brainstorm, spec, plan, or implementation), invoke `mcp__context7__resolve-library-id` followed by `mcp__context7__query-docs` before committing to an API shape. Even for well-known libraries — training data may be stale.
- **Researcher on brainstorm start:** When the `superpowers:brainstorming` skill activates, dispatch the `researcher` agent in the background immediately to investigate the topic, unknowns, and relevant prior art.
- **Researcher before spec:** Before writing any spec, dispatch the `researcher` agent in the background to validate libraries and assumptions surfaced during brainstorming.
- **Handoff auto-trigger:** When `superpowers:executing-plans` reaches the decision point of "subagent-driven-development or inline implementation?", first generate the `/handoff-to-execute` prompt as part of the response, then present the two options.
- **Opus override for superpowers:code-reviewer:** When dispatching `superpowers:code-reviewer` via the Agent tool, always pass `model: "opus"`. Plan-vs-implementation review is too consequential for Sonnet.
```

- [ ] **Step 2: Verify CLAUDE.md is valid markdown and the five bullets render**

Run: `grep -c "^- \*\*" ~/.dotfiles/claude/CLAUDE.md`
Expected: Count should be at least 5 higher than before. Confirm visually that the new heading and five bullets appear at the end.

- [ ] **Step 3: Commit**

```bash
cd ~/.dotfiles
git add claude/CLAUDE.md
git commit -m "feat(claude-md): add proactive tool-use rules for Context7, researcher, handoff"
```

---

### Task A2: Create `/handoff-to-execute` slash command

**Files:**
- Create: `~/.dotfiles/claude/commands/handoff-to-execute.md`

- [ ] **Step 1: Write the command file**

Create `~/.dotfiles/claude/commands/handoff-to-execute.md` with this exact content:

```markdown
# Handoff to Execute

Generate a medium-length, hybrid prompt that a fresh Claude Code session can consume to execute the current plan without re-brainstorming.

## Instructions

1. **Identify the spec and plan files.** Most recent spec: `docs/superpowers/specs/<date>-<topic>-design.md`. Most recent plan: `docs/superpowers/plans/<date>-<topic>.md`. If ambiguous, ask the user.
2. **Capture project context:** current git repo root, current branch, and one-line summary of objective drawn from the plan file's Goal line.
3. **Draft a 3–5 line summary** of key decisions + known constraints from the spec (not the plan — the plan is exhaustive, the spec holds the judgment calls).
4. **Output the prompt verbatim** between two horizontal rules so the user can copy-paste. Do not wrap in code fences.

## Output template

Use exactly this template, filling in the variables:

---

You are starting a fresh execution session for a pre-planned task. Your job: execute the plan using `superpowers:subagent-driven-development`.

**Project:** `<git repo root>`
**Branch:** `<current branch>`
**Spec:** `<absolute path to spec>`
**Plan:** `<absolute path to plan>`

**Objective:** <one-line goal from plan>

**Key decisions (from spec):**
- <decision 1>
- <decision 2>
- <decision 3>

**Constraints:**
- <constraint 1>
- <constraint 2>

**Your task:**
1. Read the spec and plan files first.
2. Invoke `superpowers:subagent-driven-development` to execute the plan task-by-task.
3. Do NOT re-brainstorm. Do NOT modify the spec. Do NOT rewrite the plan.
4. Ask clarifying questions only when the plan is genuinely ambiguous.

**Available tooling:** `superpowers:subagent-driven-development`, `superpowers:verification-before-completion`, `researcher` agent, `code-reviewer` agent, Context7 MCP, Obsidian MCP, claude-mem MCP.

Begin by reading the spec and plan.

---

## Rules

- Never fabricate the decision/constraint bullets — pull them from the spec's "Decisions" or "Non-goals" sections.
- If the spec or plan file doesn't exist, stop and ask the user to confirm paths before generating the prompt.
- Output only the template + a one-line confirmation. No preamble, no post-commentary.
```

- [ ] **Step 2: Verify the file parses as a valid command**

Run: `head -1 ~/.dotfiles/claude/commands/handoff-to-execute.md`
Expected: `# Handoff to Execute`

Run: `wc -l ~/.dotfiles/claude/commands/handoff-to-execute.md`
Expected: Around 45–55 lines.

- [ ] **Step 3: Verify the symlink auto-surfaces in `~/.claude/commands/`**

Run: `ls -la ~/.claude/commands/handoff-to-execute.md 2>/dev/null || echo "symlink missing"`

If missing, the user's dotfiles setup uses an installer. Run:
```bash
ln -sf ~/.dotfiles/claude/commands/handoff-to-execute.md ~/.claude/commands/handoff-to-execute.md
```
Expected: `ls -la` now shows the symlink.

- [ ] **Step 4: Commit**

```bash
cd ~/.dotfiles
git add claude/commands/handoff-to-execute.md
git commit -m "feat(commands): add /handoff-to-execute for Session A→B plan handoff"
```

---

### Task A3: Update `researcher` agent description for proactive use

**Files:**
- Modify: `~/.dotfiles/claude/agents/researcher.md`

- [ ] **Step 1: Update the `description` field in frontmatter**

Replace the existing `description` line. Before:

```yaml
description: "Background researcher. Investigates libraries, patterns, and documentation while you code. Run with Ctrl+B to background."
```

After:

```yaml
description: "Background researcher. Investigates libraries, patterns, and documentation while you code. Use proactively: dispatch at the start of every superpowers:brainstorming session, and again before writing any spec, to validate libraries and assumptions. Run with Ctrl+B to background."
```

Do not change other frontmatter fields in this task — model change comes in Task C2.

- [ ] **Step 2: Verify YAML still parses**

Run: `python3 -c "import yaml,sys; print(yaml.safe_load(open('$HOME/.dotfiles/claude/agents/researcher.md').read().split('---')[1]))"`
Expected: Dict printed with updated `description`. No YAML errors.

- [ ] **Step 3: Commit**

```bash
cd ~/.dotfiles
git add claude/agents/researcher.md
git commit -m "feat(agents): make researcher description signal proactive use"
```

---

### Task A4: Create three passive failure-logging hooks

**Files:**
- Create: `~/.dotfiles/claude/hooks/log-tool-failure.sh`
- Create: `~/.dotfiles/claude/hooks/log-stop-failure.sh`
- Create: `~/.dotfiles/claude/hooks/log-post-compact.sh`

- [ ] **Step 1: Create `log-tool-failure.sh`**

Write to `~/.dotfiles/claude/hooks/log-tool-failure.sh`:

```bash
#!/bin/bash
set -euo pipefail

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "PostToolUseFailure"
fi
# =============================================================================
# log-tool-failure.sh — Log Silent Tool Failures
# =============================================================================
# purpose: records failed tool invocations so silent Write/Edit/Bash failures
#          surface in the daily hook-health digest instead of vanishing
# inputs: stdin JSON with tool_name and error/error_message from PostToolUseFailure
# outputs: exit 0 (never blocks); appends a structured line to the hooks log
# side-effects: single line append to $CLAUDE_LOG_DIR/hooks-fire.log via hooks-log.sh
# =============================================================================

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
ERR=$(echo "$INPUT" | jq -r '.error // .error_message // empty' | head -c 200)

# hooks-log.sh's log_hook_fire already wrote the bare event. Append detail as
# a second structured line so the daily digest can count tool-failure events
# by tool name.
if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]] && command -v jq &>/dev/null; then
  LOG_FILE="${CLAUDE_LOG_DIR:-$HOME/.claude/logs}/hooks-fire.log"
  mkdir -p "$(dirname "$LOG_FILE")"
  jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg event "PostToolUseFailure.detail" \
        --arg tool "$TOOL" \
        --arg err "$ERR" \
        '{ts:$ts, event:$event, tool:$tool, error:$err}' >> "$LOG_FILE" 2>/dev/null || true
fi

exit 0
```

- [ ] **Step 2: Create `log-stop-failure.sh`**

Write to `~/.dotfiles/claude/hooks/log-stop-failure.sh`:

```bash
#!/bin/bash
set -euo pipefail

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "StopFailure"
fi
# =============================================================================
# log-stop-failure.sh — Log Session Stop Failures
# =============================================================================
# purpose: records session-level failures (rate limit, auth, billing) that
#          currently fail silently; makes them visible in hook-health digest
# inputs: stdin JSON with failure category/reason from StopFailure event
# outputs: exit 0 (never blocks); appends structured detail to hooks log
# side-effects: single line append to $CLAUDE_LOG_DIR/hooks-fire.log
# =============================================================================

INPUT=$(cat)
CATEGORY=$(echo "$INPUT" | jq -r '.failure_category // .category // "unknown"')
REASON=$(echo "$INPUT" | jq -r '.reason // .error // empty' | head -c 200)

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]] && command -v jq &>/dev/null; then
  LOG_FILE="${CLAUDE_LOG_DIR:-$HOME/.claude/logs}/hooks-fire.log"
  mkdir -p "$(dirname "$LOG_FILE")"
  jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg event "StopFailure.detail" \
        --arg category "$CATEGORY" \
        --arg reason "$REASON" \
        '{ts:$ts, event:$event, category:$category, reason:$reason}' >> "$LOG_FILE" 2>/dev/null || true
fi

exit 0
```

- [ ] **Step 3: Create `log-post-compact.sh`**

Write to `~/.dotfiles/claude/hooks/log-post-compact.sh`:

```bash
#!/bin/bash
set -euo pipefail

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "PostCompact"
fi
# =============================================================================
# log-post-compact.sh — Log Context Compaction Events
# =============================================================================
# purpose: records when context compaction completes, pairing with precompact.sh
#          for before/after visibility in the daily hook-health digest
# inputs: stdin JSON with source (auto/manual), trigger, token_count from PostCompact
# outputs: exit 0 (never blocks); appends structured detail to hooks log
# side-effects: single line append to $CLAUDE_LOG_DIR/hooks-fire.log
# =============================================================================

INPUT=$(cat)
SOURCE=$(echo "$INPUT" | jq -r '.source // .trigger // "unknown"')
TOKENS=$(echo "$INPUT" | jq -r '.token_count // empty')

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]] && command -v jq &>/dev/null; then
  LOG_FILE="${CLAUDE_LOG_DIR:-$HOME/.claude/logs}/hooks-fire.log"
  mkdir -p "$(dirname "$LOG_FILE")"
  jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg event "PostCompact.detail" \
        --arg source "$SOURCE" \
        --arg tokens "$TOKENS" \
        '{ts:$ts, event:$event, source:$source, tokens:$tokens}' >> "$LOG_FILE" 2>/dev/null || true
fi

exit 0
```

- [ ] **Step 4: Make all three executable**

Run:
```bash
chmod +x ~/.dotfiles/claude/hooks/log-tool-failure.sh \
         ~/.dotfiles/claude/hooks/log-stop-failure.sh \
         ~/.dotfiles/claude/hooks/log-post-compact.sh
```
Expected: No output. Verify with `ls -la ~/.dotfiles/claude/hooks/log-*.sh` — all three should show `rwxr-xr-x`.

- [ ] **Step 5: Smoke-test each hook with a synthetic payload**

Run each with a synthetic PostToolUseFailure input:
```bash
echo '{"tool_name":"Write","error":"synthetic test"}' | bash ~/.dotfiles/claude/hooks/log-tool-failure.sh
echo '{"failure_category":"rate_limit","reason":"synthetic"}' | bash ~/.dotfiles/claude/hooks/log-stop-failure.sh
echo '{"source":"auto","token_count":125000}' | bash ~/.dotfiles/claude/hooks/log-post-compact.sh
```
Expected: All three exit 0 with no output. Then:
```bash
tail -6 "${CLAUDE_LOG_DIR:-$HOME/.claude/logs}/hooks-fire.log"
```
Expected: Six new lines (one fire + one detail for each of the three hooks).

- [ ] **Step 6: Ensure symlinks exist in `~/.claude/hooks/`**

Run:
```bash
for f in log-tool-failure log-stop-failure log-post-compact; do
  ln -sf ~/.dotfiles/claude/hooks/$f.sh ~/.claude/hooks/$f.sh
done
ls -la ~/.claude/hooks/log-*.sh
```
Expected: Three symlinks listed.

- [ ] **Step 7: Commit**

```bash
cd ~/.dotfiles
git add claude/hooks/log-tool-failure.sh \
        claude/hooks/log-stop-failure.sh \
        claude/hooks/log-post-compact.sh
git commit -m "feat(hooks): add passive loggers for PostToolUseFailure, StopFailure, PostCompact"
```

---

### Task A5: Register the three new hook events in `settings.json`

**Files:**
- Modify: `~/.claude/settings.json`

- [ ] **Step 1: Insert the three new hook blocks after the `PreCompact` block**

Open `~/.claude/settings.json`. Locate the `PreCompact` hook block (currently the last entry in the `hooks` object). After its closing `]`, add a comma, then these three new blocks before the `hooks` object's closing `}`:

```json
    ,
    "PostToolUseFailure": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/hooks/log-tool-failure.sh\"",
            "timeout": 5,
            "async": true
          }
        ]
      }
    ],
    "StopFailure": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/hooks/log-stop-failure.sh\"",
            "timeout": 5,
            "async": true
          }
        ]
      }
    ],
    "PostCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/hooks/log-post-compact.sh\"",
            "timeout": 5,
            "async": true
          }
        ]
      }
    ]
```

- [ ] **Step 2: Validate the file is still valid JSON**

Run: `python3 -c "import json; json.load(open('$HOME/.claude/settings.json')); print('valid')"`
Expected: `valid`. If it errors, read the error, fix the JSON, rerun until valid.

- [ ] **Step 3: Verify the three new events are present**

Run: `python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); print([k for k in d['hooks'] if k in ['PostToolUseFailure','StopFailure','PostCompact']])"`
Expected: `['PostToolUseFailure', 'StopFailure', 'PostCompact']`

- [ ] **Step 4: Commit (settings.json is not in dotfiles but the plan file will track this)**

`~/.claude/settings.json` lives outside the dotfiles repo. No git commit; the change is tracked by this plan's checkbox state and verified by Task D1.

---

### Task A6: Create `/health-check` slash command

**Files:**
- Create: `~/.dotfiles/claude/commands/health-check.md`

- [ ] **Step 1: Write the command file**

Write to `~/.dotfiles/claude/commands/health-check.md`:

```markdown
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
```

- [ ] **Step 2: Ensure the symlink exists**

Run: `ln -sf ~/.dotfiles/claude/commands/health-check.md ~/.claude/commands/health-check.md && ls -la ~/.claude/commands/health-check.md`
Expected: symlink listed.

- [ ] **Step 3: Commit**

```bash
cd ~/.dotfiles
git add claude/commands/health-check.md
git commit -m "feat(commands): add /health-check on-demand pipeline validator"
```

---

## Phase B — Redundancy Cut

### Task B1: Remove `SessionEnd` registration for `breadcrumb-writer.sh`

**Files:**
- Modify: `~/.claude/settings.json`

- [ ] **Step 1: Delete the `SessionEnd` hook block**

In `~/.claude/settings.json`, locate and delete this entire block (including the trailing comma if any):

```json
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/hooks/breadcrumb-writer.sh\"",
            "timeout": 5,
            "async": true
          }
        ]
      }
    ],
```

Confirm `breadcrumb-writer.sh` is still registered under `Stop` (it should be — do not touch that block).

- [ ] **Step 2: Validate JSON**

Run: `python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); print('SessionEnd present:', 'SessionEnd' in d['hooks'])"`
Expected: `SessionEnd present: False`

- [ ] **Step 3: Verify breadcrumb-writer still registered under Stop**

Run: `python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); stop=d['hooks']['Stop'][0]['hooks']; print('breadcrumb on Stop:', any('breadcrumb' in h['command'] for h in stop))"`
Expected: `breadcrumb on Stop: True`

- [ ] **Step 4: No commit** — settings.json is not in dotfiles; covered by regression test in Task D1.

---

### Task B2: Remove claude-mem curl block from `session-start.sh`

**Files:**
- Modify: `~/.dotfiles/claude/hooks/session-start.sh`

- [ ] **Step 1: Write the failing regression test first**

Create `~/.dotfiles/tests/pipeline_upgrade.bats` with this initial content:

```bash
#!/usr/bin/env bats
# =============================================================================
# pipeline_upgrade.bats — Regression tests for 2026-04-22 pipeline upgrade
# =============================================================================

SESSION_START="$BATS_TEST_DIRNAME/../claude/hooks/session-start.sh"
SETTINGS="$HOME/.claude/settings.json"

@test "session-start.sh does not contain claude-mem curl block" {
  run grep -c '/api/search?query=' "$SESSION_START"
  [ "$status" -ne 0 ] || [ "$output" -eq 0 ]
}

@test "session-start.sh does not reference CLAUDE_MEM_WORKER_PORT in a curl" {
  run grep -E 'curl.*CLAUDE_MEM_WORKER_PORT|curl.*127\.0\.0\.1:\$\{CLAUDE_MEM' "$SESSION_START"
  [ "$status" -ne 0 ]
}

@test "session-start.sh still outputs hookSpecificOutput at end" {
  run grep -F 'hookSpecificOutput' "$SESSION_START"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run the new test and confirm it fails**

Run: `cd ~/.dotfiles && bats tests/pipeline_upgrade.bats`
Expected: First test FAILS (`/api/search?query=` still present in session-start.sh). Third test passes.

- [ ] **Step 3: Delete section 6 from `session-start.sh`**

In `~/.dotfiles/claude/hooks/session-start.sh`, delete the entire block starting at the header comment:

```
# ---------------------------------------------------------------------------
# 6. claude-mem: relevant past observations for this project
# ---------------------------------------------------------------------------
```

and ending at the blank line immediately before the next section header:

```
# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
```

(Keep the `Output` section and everything after it.)

- [ ] **Step 4: Run the regression test; confirm it passes**

Run: `cd ~/.dotfiles && bats tests/pipeline_upgrade.bats`
Expected: All three tests PASS.

- [ ] **Step 5: Run session-start.sh once manually to confirm it still produces valid JSON**

Run: `bash ~/.dotfiles/claude/hooks/session-start.sh | jq .`
Expected: Valid JSON output with `hookSpecificOutput.additionalContext` present.

- [ ] **Step 6: Commit**

```bash
cd ~/.dotfiles
git add claude/hooks/session-start.sh tests/pipeline_upgrade.bats
git commit -m "refactor(session-start): remove claude-mem curl block; plugin owns injection"
```

---

### Task B3: Delete `session-end-note.sh`

**Files:**
- Delete: `~/.claude/hooks/session-end-note.sh`

- [ ] **Step 1: Verify it's not wired up in settings.json**

Run: `grep -c session-end-note ~/.claude/settings.json`
Expected: `0`

- [ ] **Step 2: Delete the file**

Run: `rm ~/.claude/hooks/session-end-note.sh`
Expected: No output. Then: `ls ~/.claude/hooks/session-end-note.sh 2>/dev/null || echo "gone"`
Expected: `gone`

- [ ] **Step 3: Add regression test to pipeline_upgrade.bats**

Append to `~/.dotfiles/tests/pipeline_upgrade.bats`:

```bash
@test "session-end-note.sh has been removed" {
  [ ! -e "$HOME/.claude/hooks/session-end-note.sh" ]
}
```

- [ ] **Step 4: Run test**

Run: `cd ~/.dotfiles && bats tests/pipeline_upgrade.bats`
Expected: All tests PASS including the new one.

- [ ] **Step 5: Commit**

```bash
cd ~/.dotfiles
git add tests/pipeline_upgrade.bats
git commit -m "test(pipeline): regression guard for removed session-end-note.sh"
```

---

### Task B4: Delete `/session-note` command

**Files:**
- Delete: `~/.dotfiles/claude/commands/session-note.md`

- [ ] **Step 1: Delete the dotfiles source file**

Run: `rm ~/.dotfiles/claude/commands/session-note.md`
Expected: No output.

- [ ] **Step 2: Remove the symlink (if present) from `~/.claude/commands/`**

Run: `rm -f ~/.claude/commands/session-note.md`
Expected: No output.

- [ ] **Step 3: Add regression test**

Append to `~/.dotfiles/tests/pipeline_upgrade.bats`:

```bash
@test "/session-note command file has been removed" {
  [ ! -e "$BATS_TEST_DIRNAME/../claude/commands/session-note.md" ]
  [ ! -e "$HOME/.claude/commands/session-note.md" ]
}
```

- [ ] **Step 4: Run test**

Run: `cd ~/.dotfiles && bats tests/pipeline_upgrade.bats`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/.dotfiles
git add -u claude/commands/session-note.md tests/pipeline_upgrade.bats
git commit -m "chore(commands): delete unused /session-note manual fallback"
```

---

### Task B5: Switch permission mode to `acceptEdits`

**Files:**
- Modify: `~/.claude/settings.json`

- [ ] **Step 1: Change `defaultMode` value**

In `~/.claude/settings.json`, find:

```json
    "defaultMode": "bypassPermissions"
```

Change to:

```json
    "defaultMode": "acceptEdits"
```

- [ ] **Step 2: Remove the `skipDangerousModePermissionPrompt` key**

In `~/.claude/settings.json`, find and delete this entire line (and the trailing comma on the preceding line if needed):

```json
  "skipDangerousModePermissionPrompt": true
```

- [ ] **Step 3: Validate JSON**

Run: `python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); print('mode:', d['permissions']['defaultMode']); print('skip flag:', d.get('skipDangerousModePermissionPrompt', 'absent'))"`
Expected:
```
mode: acceptEdits
skip flag: absent
```

- [ ] **Step 4: Add regression test**

Append to `~/.dotfiles/tests/pipeline_upgrade.bats`:

```bash
@test "settings.json permission mode is acceptEdits" {
  run python3 -c "import json,sys; d=json.load(open('$HOME/.claude/settings.json')); sys.exit(0 if d['permissions']['defaultMode']=='acceptEdits' else 1)"
  [ "$status" -eq 0 ]
}

@test "settings.json does not contain skipDangerousModePermissionPrompt" {
  run grep -c skipDangerousModePermissionPrompt "$HOME/.claude/settings.json"
  [ "$status" -ne 0 ] || [ "$output" -eq 0 ]
}
```

- [ ] **Step 5: Run test**

Run: `cd ~/.dotfiles && bats tests/pipeline_upgrade.bats`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
cd ~/.dotfiles
git add tests/pipeline_upgrade.bats
git commit -m "test(pipeline): regression guard for acceptEdits permission mode"
```

---

## Phase C — Model Routing

### Task C1: Change `code-reviewer` agent model to Opus 4.7

**Files:**
- Modify: `~/.dotfiles/claude/agents/code-reviewer.md`

- [ ] **Step 1: Change the `model` line in frontmatter**

In `~/.dotfiles/claude/agents/code-reviewer.md`, change:

```yaml
model: claude-sonnet-4-6
```

to:

```yaml
model: claude-opus-4-7
```

Leave `effort: high` unchanged.

- [ ] **Step 2: Verify YAML parses**

Run: `python3 -c "import yaml; fm=open('$HOME/.dotfiles/claude/agents/code-reviewer.md').read().split('---')[1]; d=yaml.safe_load(fm); print('model:', d['model'], 'effort:', d['effort'])"`
Expected: `model: claude-opus-4-7 effort: high`

- [ ] **Step 3: Commit**

```bash
cd ~/.dotfiles
git add claude/agents/code-reviewer.md
git commit -m "feat(agents): route code-reviewer to Opus 4.7 for pre-PR quality gate"
```

---

### Task C2: Change `researcher` agent model to Opus 4.7

**Files:**
- Modify: `~/.dotfiles/claude/agents/researcher.md`

- [ ] **Step 1: Change the `model` line in frontmatter**

In `~/.dotfiles/claude/agents/researcher.md`, change:

```yaml
model: claude-sonnet-4-6
```

to:

```yaml
model: claude-opus-4-7
```

- [ ] **Step 2: Verify YAML parses**

Run: `python3 -c "import yaml; fm=open('$HOME/.dotfiles/claude/agents/researcher.md').read().split('---')[1]; d=yaml.safe_load(fm); print('model:', d['model'])"`
Expected: `model: claude-opus-4-7`

- [ ] **Step 3: Commit**

```bash
cd ~/.dotfiles
git add claude/agents/researcher.md
git commit -m "feat(agents): route researcher to Opus 4.7 for library/assumption validation"
```

---

### Task C3: Add `model` frontmatter to `/review` command

**Files:**
- Modify: `~/.dotfiles/claude/commands/review.md`

- [ ] **Step 1: Read current frontmatter**

Run: `head -10 ~/.dotfiles/claude/commands/review.md`
Expected: Either no frontmatter (file starts with `#`), or existing `---` YAML block.

- [ ] **Step 2a: If no frontmatter exists, prepend one**

Prepend to the file:

```yaml
---
model: claude-opus-4-7
---

```

- [ ] **Step 2b: If frontmatter exists, add `model` line**

Add inside the existing `---` block:

```yaml
model: claude-opus-4-7
```

- [ ] **Step 3: Verify**

Run: `grep -E '^model:' ~/.dotfiles/claude/commands/review.md`
Expected: `model: claude-opus-4-7`

- [ ] **Step 4: Commit**

```bash
cd ~/.dotfiles
git add claude/commands/review.md
git commit -m "feat(commands): route /review to Opus 4.7"
```

---

### Task C4: Add `model` frontmatter to `/security-scan` command

**Files:**
- Modify: `~/.dotfiles/claude/commands/security-scan.md`

- [ ] **Step 1: Read current frontmatter**

Run: `head -10 ~/.dotfiles/claude/commands/security-scan.md`

- [ ] **Step 2: Add `model: claude-opus-4-7` as in Task C3 (2a or 2b depending on current state)**

- [ ] **Step 3: Verify**

Run: `grep -E '^model:' ~/.dotfiles/claude/commands/security-scan.md`
Expected: `model: claude-opus-4-7`

- [ ] **Step 4: Commit**

```bash
cd ~/.dotfiles
git add claude/commands/security-scan.md
git commit -m "feat(commands): route /security-scan to Opus 4.7"
```

---

### Task C5: Remove the global `CLAUDE_CODE_SUBAGENT_MODEL` env pin

**Files:**
- Modify: `~/.claude/settings.json`

**Important:** This task runs LAST in Phase C. All four agents/commands above now have explicit `model:` fields, so removing the global pin has zero behavioral risk.

- [ ] **Step 1: Delete the env entry**

In `~/.claude/settings.json`, find:

```json
    "CLAUDE_CODE_SUBAGENT_MODEL": "claude-sonnet-4-6",
```

Delete that entire line.

- [ ] **Step 2: Validate JSON**

Run: `python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); print('model env absent:', 'CLAUDE_CODE_SUBAGENT_MODEL' not in d.get('env',{}))"`
Expected: `model env absent: True`

- [ ] **Step 3: Add regression test**

Append to `~/.dotfiles/tests/pipeline_upgrade.bats`:

```bash
@test "settings.json does not pin subagent model globally" {
  run python3 -c "import json,sys; d=json.load(open('$HOME/.claude/settings.json')); sys.exit(0 if 'CLAUDE_CODE_SUBAGENT_MODEL' not in d.get('env',{}) else 1)"
  [ "$status" -eq 0 ]
}

@test "code-reviewer agent pinned to Opus 4.7" {
  run grep -E '^model: claude-opus-4-7' "$BATS_TEST_DIRNAME/../claude/agents/code-reviewer.md"
  [ "$status" -eq 0 ]
}

@test "researcher agent pinned to Opus 4.7" {
  run grep -E '^model: claude-opus-4-7' "$BATS_TEST_DIRNAME/../claude/agents/researcher.md"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 4: Run test**

Run: `cd ~/.dotfiles && bats tests/pipeline_upgrade.bats`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/.dotfiles
git add tests/pipeline_upgrade.bats
git commit -m "refactor(settings): remove CLAUDE_CODE_SUBAGENT_MODEL pin; agents now choose per-frontmatter"
```

---

## Phase D — Finalization

### Task D1: Add regression tests for hook registrations

**Files:**
- Modify: `~/.dotfiles/tests/pipeline_upgrade.bats`

- [ ] **Step 1: Append hook-registration tests**

```bash
@test "settings.json registers PostToolUseFailure hook" {
  run python3 -c "import json,sys; d=json.load(open('$HOME/.claude/settings.json')); sys.exit(0 if 'PostToolUseFailure' in d.get('hooks',{}) else 1)"
  [ "$status" -eq 0 ]
}

@test "settings.json registers StopFailure hook" {
  run python3 -c "import json,sys; d=json.load(open('$HOME/.claude/settings.json')); sys.exit(0 if 'StopFailure' in d.get('hooks',{}) else 1)"
  [ "$status" -eq 0 ]
}

@test "settings.json registers PostCompact hook" {
  run python3 -c "import json,sys; d=json.load(open('$HOME/.claude/settings.json')); sys.exit(0 if 'PostCompact' in d.get('hooks',{}) else 1)"
  [ "$status" -eq 0 ]
}

@test "breadcrumb-writer is NOT registered for SessionEnd" {
  run python3 -c "import json,sys; d=json.load(open('$HOME/.claude/settings.json')); se=d.get('hooks',{}).get('SessionEnd',[]); sys.exit(1 if any('breadcrumb' in h.get('command','') for block in se for h in block.get('hooks',[])) else 0)"
  [ "$status" -eq 0 ]
}

@test "all three new log hook scripts exist and are executable" {
  [ -x "$BATS_TEST_DIRNAME/../claude/hooks/log-tool-failure.sh" ]
  [ -x "$BATS_TEST_DIRNAME/../claude/hooks/log-stop-failure.sh" ]
  [ -x "$BATS_TEST_DIRNAME/../claude/hooks/log-post-compact.sh" ]
}
```

- [ ] **Step 2: Run the new tests**

Run: `cd ~/.dotfiles && bats tests/pipeline_upgrade.bats`
Expected: All tests in the file PASS.

- [ ] **Step 3: Commit**

```bash
cd ~/.dotfiles
git add tests/pipeline_upgrade.bats
git commit -m "test(pipeline): regression guards for new hook registrations"
```

---

### Task D2: Full regression suite green

**Files:**
- No file changes. Verification only.

- [ ] **Step 1: Run the entire bats suite**

Run: `cd ~/.dotfiles && bats tests/`
Expected: All existing tests still PASS. Total count should equal the baseline from Task 0 plus the new tests added in this plan (roughly +12 new tests in `pipeline_upgrade.bats`).

If any test FAILS that was green in Task 0, STOP and diagnose before proceeding. Likely culprits: a deletion broke a hook someone else depends on, or settings.json is malformed.

- [ ] **Step 2: Run manual session-start smoke test**

Run: `bash ~/.dotfiles/claude/hooks/session-start.sh | jq -r '.hookSpecificOutput.hookEventName'`
Expected: `SessionStart`. Confirms session-start.sh still produces valid output after §6 removal.

---

### Task D3: Run `/health-check` end-to-end

**Files:**
- No file changes. Verification only.

- [ ] **Step 1: Start a new Claude Code session and invoke `/health-check`**

The user runs this themselves — it's an interactive validation. Note the pass/fail results.

- [ ] **Step 2: Verify all 8 checks pass**

Expected outcome:
- Plugins ✓
- MCP servers ✓
- Critical commands exist ✓
- Removed files absent ✓
- Recent hook activity ✓
- Agents loadable ✓
- Permission mode `acceptEdits` ✓
- Subagent model pin absent ✓

If any FAIL, diagnose against this plan's tasks to identify which step was missed.

---

### Task D4: Update auto-memory breadcrumb for the new workflow

**Files:**
- Modify: `/Users/godl1ke/.claude/projects/-Users-godl1ke/memory/MEMORY.md`
- Optional: create `/Users/godl1ke/.claude/projects/-Users-godl1ke/memory/project_pipeline_upgrade.md`

- [ ] **Step 1: Add one line to MEMORY.md under existing entries**

Append:

```markdown
- [Pipeline upgrade 2026-04-22](project_pipeline_upgrade.md) — 4-phase Claude Code tuning; acceptEdits mode, Opus 4.7 for code-review/researcher, /handoff-to-execute + /health-check commands
```

- [ ] **Step 2: Create the memory file**

Write `project_pipeline_upgrade.md`:

```markdown
---
name: Pipeline upgrade 2026-04-22
description: Four-phase Claude Code + superpowers tuning — gap fixes, redundancy cut, model routing, passive self-healing
type: project
---

Four-phase improvement implemented on feat/pipeline-upgrade branch. Key behavioral changes:

**Why:** Working pipeline had redundancies (permission-mode contradiction, claude-mem double-injection, breadcrumb double-fire) and gaps (Context7 + researcher underused; no clear-context-after-plan mechanism).

**How to apply:**
- Session handoff: after plan approval, invoke `/handoff-to-execute` to get a paste-ready prompt for Session B; Session A stays alive as review seat.
- Permission prompts now appear for unknown Bash (previously bypassed). This is intentional defense-in-depth; self-teaching hook rewrite is a future follow-up.
- Code-reviewer, researcher, `/review`, `/security-scan` all run on Opus 4.7 now. Higher token cost but quality-critical paths.
- PostToolUseFailure, StopFailure, PostCompact events now log to hook-health pipeline — watch the daily digest.
- Run `/health-check` after plugin upgrades to catch breakage.
```

- [ ] **Step 3: No commit** (memory lives outside dotfiles).

---

### Task D5: Push branch and open PR

**Files:**
- No file changes. Git operations.

- [ ] **Step 1: Push the branch**

Run: `cd ~/.dotfiles && git push -u origin feat/pipeline-upgrade`
Expected: Branch pushed; URL printed for PR creation.

- [ ] **Step 2: Open the PR using the dotfiles convention**

Run:
```bash
cd ~/.dotfiles
gh pr create --title "feat: Claude Code pipeline upgrade (4-phase tuning)" --body "$(cat <<'EOF'
## Summary

Implements the four-phase design at `claude/docs/superpowers/specs/2026-04-22-claude-code-pipeline-upgrade-design.md`:

- **Phase A (additive):** 5 new CLAUDE.md rules for Context7/researcher/handoff proactive use; `/handoff-to-execute` for Session A→B plan handoff; 3 new passive hook handlers (PostToolUseFailure, StopFailure, PostCompact); `/health-check` on-demand validator.
- **Phase B (redundancy cut):** removed duplicate SessionEnd breadcrumb fire, claude-mem curl block in session-start.sh §6, unused session-end-note.sh and /session-note. Switched permission model from bypassPermissions to acceptEdits.
- **Phase C (model routing):** removed global CLAUDE_CODE_SUBAGENT_MODEL pin; code-reviewer, researcher, /review, /security-scan now use Opus 4.7 via per-agent/per-command frontmatter.
- **Phase D:** regression tests in `tests/pipeline_upgrade.bats` guard every structural change. Full bats suite green.

Zero plugin modifications; all changes in dotfiles or user-level config, preserving upstream auto-update safety.

## Test plan

- [ ] `bats tests/` all green
- [ ] `bash claude/hooks/session-start.sh | jq .` produces valid JSON
- [ ] Three new log hooks emit structured entries to hooks-fire.log on synthetic input
- [ ] `/health-check` reports 8/8 pass in a fresh session
- [ ] Next real session confirms no regression in auto-PR gate, Obsidian session-note writing, or safety-guards blocking
EOF
)"
```
Expected: PR created; URL returned.

- [ ] **Step 3: Print the PR URL for user review**

Run: `gh pr view --json url -q .url`
Expected: URL printed. User merges at their discretion.

---

## Self-Review (completed)

- **Spec coverage:** Every item in `docs/superpowers/specs/2026-04-22-claude-code-pipeline-upgrade-design.md` maps to a task above. Spec §1.1 → Task A1; §1.2 → A2; §1.3 → A3; §2.1 → B1; §2.2 → B2; §2.3 → B3–B4; §2.4 → B5; §3.1 → C5; §3.2 → C1–C2; §3.3 → C3–C4; §3.4 → A1 (covered by Opus-override rule); §4.1 → A4; §4.2 → A5; §4.3 → no task (automatic via hook-health); §4.4 → A6. Plus Task 0 baseline, D1 registration tests, D2 suite green, D3 /health-check, D4 memory, D5 PR.
- **Placeholder scan:** No TBDs, TODOs, or "implement appropriate" phrases. Every step has the exact command, file content, or decision needed.
- **Type consistency:** Model name `claude-opus-4-7` used consistently across C1–C4. Hook file names `log-tool-failure.sh`, `log-stop-failure.sh`, `log-post-compact.sh` used identically in creation (A4), registration (A5), and test (D1). Task B5 uses `acceptEdits` consistently with A6's health-check expectation.
- **Ordering sanity:** Additive tasks (A1–A6) before deletions (B1–B5) before model routing (C1–C5). C5 (env-pin removal) comes last in Phase C so all per-agent models are in place first.

No issues found; plan ready for execution.
