# ADR: Pre-PR gate silently bypassed 4 of 5 checks

**Date:** 2026-04-20
**Status:** Accepted — fix in same PR
**Triggered by:** PR #109 hotfix (missing `from pathlib import Path` slipped past #108's
gate despite the PR body asserting `ruff check` clean)

## Context

Every PR's body asserts "gates passed" (ruff format, ruff lint, pytest, secrets scan,
pip-audit). These assertions are load-bearing: the methodology's assurance layer relies
on the gate actually running what it claims. When #108's gate reported clean but the
final tree had `F821 Undefined name 'Path'` in `reliability.py:70`, the failure mode
was not caught by Batch 1 until a follow-up ruff run hit it. This ADR captures the
root-cause investigation.

## Root cause — bash `set -e` + command substitution

`claude/hooks/pr-gate.sh` line 2 sets `set -euo pipefail`. Checks 2–5 (ruff lint,
pytest, secrets scan, pip-audit) use this pattern:

```bash
LINT_OUTPUT=$(ruff check . 2>&1)
if [ $? -ne 0 ]; then
  ERRORS="${ERRORS}\n❌ LINT: ..."
fi
```

Under `set -e`, a bare variable assignment `VAR=$(cmd)` exits the script immediately
when `cmd` fails. The subsequent `if [ $? -ne 0 ]` never runs, `$ERRORS` is never
populated, and the final `if [ -n "$ERRORS" ]` verdict (line 88) never executes —
so the `🚫 PR GATE BLOCKED` stderr message is never printed.

Empirical reproduction:

```bash
bash -c '
  set -euo pipefail
  echo "step 1"
  VAR=$(bash -c "exit 1" 2>&1)
  echo "step 2 (never prints)"
'
# Prints: step 1
# Exits:  1
```

End-to-end reproduction against pr-gate.sh itself: feeding it a test repo with a
file containing `F821`, the script exits `1` after printing only the first (safe)
check's output. The final `BLOCKED` verdict never prints.

## Blast radius

| # | Check | Pattern | Status |
|---|-------|---------|--------|
| 1 | `ruff format --check` | `if ! cmd; then` | ✅ Safe |
| 2 | `ruff check` | `VAR=$(cmd); if [ $? -ne 0 ]` | ❌ Silent bypass on failure |
| 3 | `pytest` / `npm test` | `VAR=$(cmd); if [ $? -ne 0 ]` | ❌ Silent bypass on failure |
| 4 | Secrets scan via `grep -l` | `VAR=$(pipeline)` | ❌ Silent bypass even on clean branches (`grep -l` exits 1 when no matches → `pipefail` trips → `set -e` exits) |
| 5 | `pip-audit --strict` | `VAR=$(cmd); if [ $? -ne 0 ]` | ❌ Silent bypass on findings |

**Only `ruff format` was ever truly gated.** Every PR merged since pr-gate.sh was
installed has had a silent free pass on lint, tests, secrets, and deps. #108 is
representative, not exceptional.

### Hook-system interaction

PreToolUse hooks block only on exit code **2** + stderr. The broken pattern exits
with the underlying command's code (typically 1), which the hook system treats as
a hook error (logged) rather than a block. The invoking command (`gh pr create`,
`git push`) proceeds.

## Secondary cause — Layer 1 (why the F821 was introduced in the first place)

`claude/hooks/auto-format.sh` runs `ruff check --fix` on every Python file Claude
edits. `ruff check --fix` silently:
- **Auto-fixes** fixable violations (F401 unused import → import removed)
- **Skips** non-fixable violations (F821 undefined name → no signal)
- Emits nothing to Claude either way (stderr is `2>/dev/null`)

So the sequence that introduced #108's bug was plausibly:

1. Subagent edits `reliability.py`, `Path` imported and used.
2. Subagent removes the method that used `Path`. Import becomes unused.
3. `auto-format.sh` fires → `ruff check --fix` → **silently removes** `from pathlib import Path`.
4. Subagent adds a new method whose signature uses `Path`. With `from __future__ import annotations` active, the annotation is a string at runtime — tests pass.
5. `auto-format.sh` fires → F821 is not fix-able → **silently skipped**. Claude gets no error.
6. Subagent's final self-verification (if any) would have had to run `ruff check`
   explicitly — which it may not have, trusting the PostEdit hook's silent fixes.
7. Push → pr-gate.sh → silently dies on check #2 → PR proceeds.

Both layers need addressing, but Layer 2 (pr-gate.sh) is the critical load-bearing
one. Layer 1 has real benefits (auto-removing genuinely unused imports is usually
desired); the right layer to catch F821 is pre-PR lint — which is Layer 2.

## Decision

### Fix Layer 2 (in this PR)

Rewrite every `VAR=$(cmd); if [ $? -ne 0 ]` pattern in pr-gate.sh to `if ! VAR=$(cmd); then`.
Inside `if` conditions, `set -e` is explicitly disabled for the tested command, and
the assignment still captures stdout. This is the same pattern check #1 already uses.

Add an EXIT trap as defense in depth: if the script exits without having reached
the final verdict, emit a clear "PR GATE INTERNAL ERROR" and exit **2** (block).
This ensures that any future bug in the gate's internals fails loud rather than silent.

Add a bats regression test (`tests/pr_gate.bats`) that exercises each check's
failure path:
- Feed a repo with F821 → expect exit 2 + `BLOCKED` + `LINT` in output
- Feed a repo with a failing test → expect exit 2 + `BLOCKED` + `TESTS`
- Feed a clean repo (no findings) → expect exit 0

### Layer 1 — defer as follow-up

Options for improving `auto-format.sh` signal:
- (a) Capture non-fixable ruff errors from `ruff check --fix` and surface them to
  stderr so Claude sees them between edits.
- (b) Disable F401 auto-fix: `ruff check --fix --unfixable F401`. Keeps unused
  imports visible as lint errors until resolved.
- (c) Leave as-is and rely on Layer 2 as the single-source-of-truth gate.

Recommendation: (a), but it needs its own brainstorm + test matrix. Out of scope
for this PR.

### Subagent self-verification — policy, not code

Subagent prompts that produce "gates passed" claims in PR bodies should include an
explicit verification step: `uv run ruff check .` from the package root + capture
the exit code + only claim "clean" if exit is 0. This is a prompt discipline issue
tracked as a separate follow-up.

## Consequences

- Positive: the 4 broken checks now actually block PRs. The "performative assurance"
  layer becomes real assurance. Regression test fixes the pattern in place so it
  can't silently regress again.
- Negative: PRs that would have previously slipped through with lint/test issues
  will now be blocked. This is the desired behavior, but may surface existing
  latent issues in the tree; budget a short session post-merge to clean those up.
- Follow-up: three items now tracked — Layer 1 auto-format signal, subagent prompt
  discipline, full bats regression coverage for the EXIT trap path.

## References

- Bash reference manual, `set -e` rules: "The shell does not exit if the command
  that fails is part of the command list immediately following a `while` or `until`
  keyword, part of the test following the `if` or `elif` reserved words…"
- Git blame: `claude/hooks/pr-gate.sh` introduced in PR #107 (`cb108d0` series).
