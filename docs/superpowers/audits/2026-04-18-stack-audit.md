# Claude Stack Audit — 2026-04-18

**Health score: 862 / 1000**

## Summary

| Severity | Count |
|----------|------:|
| Critical | 0 |
| High | 0 |
| Medium | 54 |
| Low | 30 |
| Info | 39 |

## Medium findings

| ID | Layer | Criterion | Artifact | Message | Fix hint |
|----|-------|-----------|----------|---------|----------|
| DOC007 | automation | documentation | `/Users/godl1ke/.dotfiles/docs/settings.hooks.md` | no settings.hooks.md found | Create docs/settings.hooks.md explaining each hook event wired in settings.json (matcher, command, purpose). |
| OBS001 | automation | observability | `claude/crons/daily-retro-evening.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/daily-retro-evening.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/daily-retro-evening.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/daily-retro-evening.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/daily-retro-evening.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/daily-retro-evening.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/daily-retrospective.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/daily-retrospective.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/daily-retrospective.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/daily-retrospective.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/daily-retrospective.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/daily-retrospective.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/healthcheck.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/healthcheck.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/healthcheck.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/healthcheck.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/mac-cleanup-scan.sh` | log write to non-approved path: $NOTE_PATH | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/notify-failure.sh` | log write to non-approved path: $note_path | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/weekly-finalize.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/weekly-finalize.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/weekly-finalize.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/weekly-finalize.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/weekly-finalize.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/weekly-finalize.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/weekly-report-gen.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/weekly-report-gen.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/weekly-report-gen.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/weekly-report-gen.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/weekly-report-gen.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/crons/weekly-report-gen.sh` | log write to non-approved path: $LOGFILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/hooks/breadcrumb-writer.sh` | log write to non-approved path: $BREADCRUMB_DIR/breadcrumbs.md | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/hooks/permission-denied.sh` | log write to non-approved path: $LOG_FILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/hooks/permission-denied.sh` | log write to non-approved path: $LOG_FILE.tmp | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS004 | automation | observability | `claude/crons/claude-mem-worker.sh` | cron does not emit duration/status markers | Log lines like \`duration_ms=1234 status=ok\` on completion so metrics scrapers can track runs. |
| OBS004 | automation | observability | `claude/crons/daily-retro-evening.sh` | cron does not emit duration/status markers | Log lines like \`duration_ms=1234 status=ok\` on completion so metrics scrapers can track runs. |
| OBS004 | automation | observability | `claude/crons/daily-retrospective.sh` | cron does not emit duration/status markers | Log lines like \`duration_ms=1234 status=ok\` on completion so metrics scrapers can track runs. |
| OBS004 | automation | observability | `claude/crons/healthcheck.sh` | cron does not emit duration/status markers | Log lines like \`duration_ms=1234 status=ok\` on completion so metrics scrapers can track runs. |
| OBS004 | automation | observability | `claude/crons/mac-cleanup-scan.sh` | cron does not emit duration/status markers | Log lines like \`duration_ms=1234 status=ok\` on completion so metrics scrapers can track runs. |
| OBS004 | automation | observability | `claude/crons/notify-failure.sh` | cron does not emit duration/status markers | Log lines like \`duration_ms=1234 status=ok\` on completion so metrics scrapers can track runs. |
| OBS004 | automation | observability | `claude/crons/weekly-finalize.sh` | cron does not emit duration/status markers | Log lines like \`duration_ms=1234 status=ok\` on completion so metrics scrapers can track runs. |
| OBS004 | automation | observability | `claude/crons/weekly-report-gen.sh` | cron does not emit duration/status markers | Log lines like \`duration_ms=1234 status=ok\` on completion so metrics scrapers can track runs. |
| OBS005 | automation | observability | `/Users/godl1ke/.dotfiles/claude` | no log rotation script found in dotfiles | Add a cron script that rotates logs in ~/Library/Logs/claude-crons/ (e.g. \`find -mtime +30 -delete\` or gzip/logrotate). |
| REL001 | automation | reliability | `claude/crons/healthcheck.sh` | SC2034: MARKER_DIR appears unused. Verify use (or export if used externally). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-start.sh` | SC2034: plugin appears unused. Verify use (or export if used externally). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL005 | automation | reliability | `claude/crons/healthcheck.sh` | cron script has no idempotency guard | Add a guard: flock to prevent concurrent runs, or check a last-success marker to skip redundant runs. |
| REL006 | automation | reliability | `/Users/godl1ke/.dotfiles/tests` | no tests directory for dotfiles hook/cron scripts | Create ~/.dotfiles/tests/ with bats or pytest suites covering hook and cron scripts. |
| REL008 | automation | reliability | `claude/crons/daily-retro-evening.sh` | claude invocation without timeout | Wrap long-running claude calls with \`timeout <N>s $CLAUDE_BIN ...\` so a hung process can't wedge the cron. |
| REL008 | automation | reliability | `claude/crons/daily-retrospective.sh` | claude invocation without timeout | Wrap long-running claude calls with \`timeout <N>s $CLAUDE_BIN ...\` so a hung process can't wedge the cron. |
| REL008 | automation | reliability | `claude/crons/healthcheck.sh` | claude invocation without timeout | Wrap long-running claude calls with \`timeout <N>s $CLAUDE_BIN ...\` so a hung process can't wedge the cron. |
| REL008 | automation | reliability | `claude/crons/weekly-finalize.sh` | claude invocation without timeout | Wrap long-running claude calls with \`timeout <N>s $CLAUDE_BIN ...\` so a hung process can't wedge the cron. |
| REL008 | automation | reliability | `claude/crons/weekly-report-gen.sh` | claude invocation without timeout | Wrap long-running claude calls with \`timeout <N>s $CLAUDE_BIN ...\` so a hung process can't wedge the cron. |
| REL008 | automation | reliability | `claude/env.sh` | claude invocation without timeout | Wrap long-running claude calls with \`timeout <N>s $CLAUDE_BIN ...\` so a hung process can't wedge the cron. |
| DOC004 | core | documentation | `/Users/godl1ke/.dotfiles` | no ADRs found under docs/superpowers/adr or docs/decisions | Capture architectural decisions as dated markdown files in docs/superpowers/adr/YYYY-MM-DD-<topic>.md. |

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
| REL001 | automation | reliability | `claude/crons/mac-cleanup-scan.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/mac-cleanup-scan.sh` | SC1091: Not following: ./.dotfiles/claude/crons/notify-failure.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/weekly-finalize.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/weekly-finalize.sh` | SC1091: Not following: ./.dotfiles/claude/crons/notify-failure.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/weekly-report-gen.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/crons/weekly-report-gen.sh` | SC1091: Not following: ./.dotfiles/claude/crons/notify-failure.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/auto-test.sh` | SC2295: Expansions inside ${..} need to be quoted separately, otherwise they match as patterns. | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/breadcrumb-writer.sh` | SC1091: Not following: ./.claude/hooks/detect-org.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/detect-org.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/pr-gate.sh` | SC2181: Check exit code directly with e.g. 'if ! mycmd;', not indirectly with $?. | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/pr-gate.sh` | SC2181: Check exit code directly with e.g. 'if ! mycmd;', not indirectly with $?. | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/pr-gate.sh` | SC2181: Check exit code directly with e.g. 'if ! mycmd;', not indirectly with $?. | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/pr-gate.sh` | SC2181: Check exit code directly with e.g. 'if ! mycmd;', not indirectly with $?. | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-start.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-start.sh` | SC2012: Use find instead of ls to better handle non-alphanumeric filenames. | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-start.sh` | SC1091: Not following: ./.claude/hooks/detect-org.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-start.sh` | SC2012: Use find instead of ls to better handle non-alphanumeric filenames. | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-stop.sh` | SC1091: Not following: ./.claude/env.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-stop.sh` | SC1091: Not following: ./.claude/hooks/detect-org.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/test-fix-detector.sh` | SC1091: Not following: ./.claude/hooks/detect-org.sh was not specified as input (see shellcheck -x). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL009 | automation | reliability | `claude/hooks/session-start.sh` | jq used without defensive default | Use \`jq '.foo // empty'\` or \`// []\` so jq doesn't fail on unexpected shapes. |

---
_Generated by cstack-audit 0.1.0 at 2026-04-18T18:18+00:00 · tools: shellcheck ShellCheck - shell script analysis tool_