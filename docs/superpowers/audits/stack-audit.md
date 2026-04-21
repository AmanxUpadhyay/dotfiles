# Claude Stack Audit — 2026-04-21

**Health score: 969 / 1000**

## Summary

| Severity | Count |
|----------|------:|
| Critical | 0 |
| High | 0 |
| Medium | 1 |
| Low | 29 |
| Info | 41 |

## Medium findings

| ID | Layer | Criterion | Artifact | Message | Fix hint |
|----|-------|-----------|----------|---------|----------|
| OBS001 | automation | observability | `claude/hooks/auto-format.sh` | log write to non-approved path: $DRIFT_LOG | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. If this write is product output, rename the variable to include NOTE/BREADCRUMB/DOC, use a .md/.html extension, or add \`# audit-ignore: OBS001 <reason>\` on the redirect line. |

## Low findings

| ID | Layer | Criterion | Artifact | Message | Fix hint |
|----|-------|-----------|----------|---------|----------|
| REL001 | automation | reliability | `claude/crons/claude-mem-worker.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/claude-mem-worker.sh` | SC1091: Not following: ./.dotfiles/claude/crons/notify-failure.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/claude-mem-worker.sh` | SC2012: Use find instead of ls to better handle non-alphanumeric filenames. | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/daily-retro-evening.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/daily-retro-evening.sh` | SC1091: Not following: ./.dotfiles/claude/crons/notify-failure.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/daily-retrospective.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/daily-retrospective.sh` | SC1091: Not following: ./.dotfiles/claude/crons/notify-failure.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/healthcheck.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/healthcheck.sh` | SC1091: Not following: ./.dotfiles/claude/crons/notify-failure.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/healthcheck.sh` | SC2129: Consider using { cmd1; cmd2; } >> file instead of individual redirects. | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/log-rotate.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/log-rotate.sh` | SC1091: Not following: ./.dotfiles/claude/crons/notify-failure.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/mac-cleanup-scan.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/mac-cleanup-scan.sh` | SC1091: Not following: ./.dotfiles/claude/crons/notify-failure.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/weekly-finalize.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/weekly-finalize.sh` | SC1091: Not following: ./.dotfiles/claude/crons/notify-failure.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/weekly-report-gen.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/weekly-report-gen.sh` | SC1091: Not following: ./.dotfiles/claude/crons/notify-failure.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/auto-test.sh` | SC2295: Expansions inside ${..} need to be quoted separately, otherwise they match as patterns. | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/breadcrumb-writer.sh` | SC1091: Not following: ./.claude/hooks/detect-org.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/detect-org.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-start.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-start.sh` | SC2012: Use find instead of ls to better handle non-alphanumeric filenames. | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-start.sh` | SC1091: Not following: ./.claude/hooks/detect-org.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-start.sh` | SC2012: Use find instead of ls to better handle non-alphanumeric filenames. | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-stop.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-stop.sh` | SC1091: Not following: ./.claude/hooks/detect-org.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/test-fix-detector.sh` | SC1091: Not following: ./.claude/hooks/detect-org.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL009 | automation | reliability | `claude/hooks/session-start.sh` | jq used without defensive default | Use \`jq '.foo // empty'\` or \`// []\` so jq doesn't fail on unexpected shapes. |

---
_Generated by cstack-audit 0.1.0 at 2026-04-21T10:25+00:00 · tools: jq jq-1.8.1, shellcheck ShellCheck - shell script analysis tool_