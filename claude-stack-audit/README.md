# claude-stack-audit

Read-only inspection tool for the Claude Code + dotfiles + Obsidian pipeline.
Emits a prioritised markdown report plus machine-readable JSON.

## Install

```bash
brew bundle --file ~/.dotfiles/Brewfile   # shellcheck, jq
uv tool install -e ~/.dotfiles/claude-stack-audit
```

## Usage

```bash
cstack-audit run                             # full audit
cstack-audit run --only reliability,docs     # subset
cstack-audit run --quick                     # inventory + cross_cutting only
cstack-audit list-checks                     # enumerate registered checks
cstack-audit validate                        # env preflight
```

Reports land in `~/.dotfiles/docs/superpowers/audits/stack-audit.{md,json}` — single canonical path, always overwritten. `--tag <slug>` writes `stack-audit--<slug>.{md,json}` for A/B comparison. See `docs/superpowers/adr/2026-04-20-audit-snapshot-policy.md`.

## Design

See `~/.dotfiles/docs/superpowers/specs/2026-04-17-claude-stack-audit-tool-design.md`.
