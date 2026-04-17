# Claude Stack Audit — Phase 5 Implementation Plan (Cross-cutting + Integration Surface)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** Close the 33-check catalog and ship the full integration surface: `/audit` slash command, pre-commit hook, ADR, runbook.

**Branch:** `fix/hook-audit-28-bugs-env-centralized`.

---

## Checks

### CROSS002 `BashPermissionScope`
Scan `settings.json` `permissions.allow` and `permissions.deny` arrays (if present) for overly broad Bash patterns like `Bash(bash:*)` or `Bash(*)`. Flag MEDIUM per broad pattern.

### CROSS003 `SecretsGrep`
Scan all tracked files in `~/.dotfiles/claude/` for patterns matching API keys / tokens / Bearer values. Flag HIGH per leak.
- Patterns: `sk-[A-Za-z0-9]{20,}`, `ghp_[A-Za-z0-9]{30,}`, `ghs_[A-Za-z0-9]{30,}`, `Bearer\s+[A-Za-z0-9._-]{20,}`, `xoxb-[A-Za-z0-9-]+`.
- Skip `.json` files containing `example` / `template` in path.

### CROSS004 `GitCleanStatus`
Run `git -C <claude_root> status --porcelain` (via `ctx.external.run`). Emit Info finding per uncommitted entry in `~/.dotfiles/claude/`.

---

## Integration Surface

### `/audit` slash command
- File: `~/.dotfiles/claude/commands/audit.md`
- Frontmatter: `description: Run cstack-audit and surface top findings.`
- Body: runs `cstack-audit run`, then summarises.

### Pre-commit hook
- File: Add a new executable script at `~/.dotfiles/pre-commit/cstack-critical-gate.sh`
- Runs `cstack-audit run --quick --only cross_cutting` from the staged tree. Blocks commit only on Critical findings.

### ADR
- File: `~/.dotfiles/docs/superpowers/adr/2026-04-18-python-audit-tool.md`
- Captures: decision (Python + uv + pytest over bash), context, consequences, alternatives considered.

### Runbook
- File: `~/.dotfiles/docs/superpowers/runbooks/stack-audit.md`
- Covers: what to do when each check ID fires, how to run locally, how to tag an A/B comparison, how to interpret score drops.

---

## Tasks

- **P5-1:** CROSS002 + CROSS003 (atomic Writes)
- **P5-2:** CROSS004
- **P5-3:** `/audit` slash command
- **P5-4:** Pre-commit hook
- **P5-5:** ADR + Runbook
- **P5-6:** Final baseline refresh

Each task commits separately. Coverage gate maintained.
