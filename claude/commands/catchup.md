# =============================================================================
# /catchup — Summarise Where Things Stand
# =============================================================================
# WHY: When you context-switch back to a project, you need to know what
# happened since you last worked here. This reads recent git history,
# MEMORY.md, and current branch state to give you a quick briefing.
#
# Usage: /catchup
# Location: ~/.claude/commands/catchup.md
# =============================================================================

Catch me up on this project. I've been away and need to know what's happening.

Steps:
1. Read the current git branch and status
2. Read the last 10 commits with `git log --oneline -10`
3. Check for any uncommitted changes or stashed work
4. Read MEMORY.md if it exists (Auto Memory notes)
5. Check for any open PRs with `gh pr list`
6. Look at any TODO or FIXME comments in recently changed files

Present a concise briefing:
- **Current branch**: what you're working on
- **Recent activity**: what was done in the last few sessions
- **Open work**: uncommitted changes, stashes, open PRs
- **Next steps**: what appears to be the logical next action

Keep it brief — this is a status check, not a deep dive.
