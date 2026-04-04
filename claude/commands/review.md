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
