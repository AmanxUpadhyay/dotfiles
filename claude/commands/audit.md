---
description: Run the cstack-audit tool and surface top findings from the dotfiles stack audit.
---

# /audit — Claude Code + dotfiles + Obsidian Stack Audit

Run the stack audit and summarise findings.

## Steps

1. Run the audit on the real dotfiles:

   ```bash
   cstack-audit run
   ```

   Exit codes: 0 = clean, 1 = Critical/High present, 2 = env validation failed, 3 = check crashed.

2. Read the top of the latest markdown report at `~/.dotfiles/docs/superpowers/audits/YYYY-MM-DD-stack-audit.md` to get the score, severity counts, and the Critical/High findings tables.

3. Summarise for the user:
   - Health score out of 1000 (include delta vs previous report via `git diff` on the report file if one exists)
   - Severity breakdown
   - Top 3 Critical (if any), then top 3 High findings with `artifact`, `message`, `fix_hint`
   - Suggest 2-3 of those findings as candidates for the next brainstorming/spec cycle

4. If exit code was 2, surface the validation error and suggest `brew bundle --file ~/.dotfiles/Brewfile` + `cstack-audit validate` as the recovery path.

5. If exit code was 3, note which check crashed (META001 in findings) and suggest opening an issue in the claude-stack-audit project.

## Notes

- The tool writes both `.md` and `.json` reports to `~/.dotfiles/docs/superpowers/audits/`. Git-tracked, so the score trend is visible via `git log --oneline -- docs/superpowers/audits/`.
- Use `cstack-audit run --quick` for a subset (inventory + cross_cutting only, sub-second).
- Use `cstack-audit run --only reliability,documentation` to narrow by criterion.
- Use `cstack-audit run --tag before-fix` for A/B tagged filenames.

## Related

- Tool source: `~/.dotfiles/claude-stack-audit/`
- Design spec: `~/.dotfiles/docs/superpowers/specs/2026-04-17-claude-stack-audit-tool-design.md`
- Phase plans: `~/.dotfiles/docs/superpowers/plans/2026-04-*-claude-stack-audit-*.md`
