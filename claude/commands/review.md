# =============================================================================
# /review — Code Review Current Changes
# =============================================================================
# WHY: Triggers a comprehensive code review of all uncommitted changes.
# Uses the code-reviewer agent (read-only) to catch bugs, security issues,
# and architectural problems before you create a PR.
#
# Usage: /review
# Location: ~/.claude/commands/review.md
# =============================================================================

Review all uncommitted changes in this repository using the code-reviewer agent.

Steps:
1. Run `git diff` to see all changes
2. Run `git diff --cached` to see staged changes
3. For each changed file, review for:
   - Correctness (logic errors, async issues, SQLAlchemy session management)
   - Security (SQL injection, auth gaps, secrets in code, input validation)
   - Architecture (repository pattern compliance, error handling, logging)
   - Performance (N+1 queries, blocking I/O in async, missing pagination)
4. Present findings with severity (🔴 Critical / 🟡 Warning / 🔵 Suggestion)
5. Give a clear verdict: SAFE TO MERGE or NEEDS FIXES

Be thorough. This is the last check before code reaches a PR.

---

## Self-verification — mandatory before reporting

Before returning your final verdict, re-run the project gates against the
**final staged state** (post any edits you made during the review) and paste
the **literal output** — not a summary. This makes the report tamper-evident.

Run and paste the last ~20 lines of each, including exit code:

```
$ uv run ruff check .
<literal output>
```

```
$ uv run pytest -q
<literal output>
```

```
$ git status --short
<literal output>
```

**Rules:**

- Literal output, not paraphrase. "All checks passed" without the pasted
  output is not acceptable.
- Run **after** the last edit. Any edit invalidates the previous run —
  re-run and re-paste.
- If output says "unchanged" or is implausibly fast, cache-bust with
  `--no-cache` (ruff) or `--cache-clear` (pytest) and paste that output.
- Never edit the pasted output. Truncating past 20 lines is fine;
  redacting error lines is not.

If you skip this section, the orchestrator must reject the report and
re-request verification. See
`docs/superpowers/adr/2026-04-20-subagent-self-verification.md` for the
full pattern and rationale.
