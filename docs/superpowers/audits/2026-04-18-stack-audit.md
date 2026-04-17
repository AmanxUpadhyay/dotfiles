# Claude Stack Audit — 2026-04-17

**Health score: 567 / 1000**

## Summary

| Severity | Count |
|----------|------:|
| Critical | 0 |
| High | 59 |
| Medium | 55 |
| Low | 28 |
| Info | 39 |

## High findings

| ID | Layer | Criterion | Artifact | Message | Fix hint |
|----|-------|-----------|----------|---------|----------|
| DOC001 | automation | documentation | `claude/crons/claude-mem-worker.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/crons/daily-retro-evening.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/crons/daily-retrospective.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/crons/healthcheck.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/crons/mac-cleanup-scan.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/crons/notify-failure.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/crons/weekly-finalize.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/crons/weekly-report-gen.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/env.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/auto-format.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/auto-test.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/breadcrumb-writer.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/detect-org.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/permission-auto-approve.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/permission-denied.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/pr-gate.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/prompt-injection-guard.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/protect-files.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/safety-guards.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/session-start.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/session-stop.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/stop-notification.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/hooks/test-fix-detector.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/install-launchagents.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| DOC001 | automation | documentation | `claude/refresh.sh` | script header missing: purpose, inputs, outputs, side-effects | Add a 4-line comment block at the top of the script listing purpose, inputs, outputs, and side-effects. |
| REL001 | automation | reliability | `claude/refresh.sh` | SC1071: ShellCheck only supports sh/bash/dash/ksh/'busybox sh' scripts. Sorry! | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL002 | automation | reliability | `claude/crons/claude-mem-worker.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/crons/daily-retro-evening.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/crons/daily-retrospective.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/crons/healthcheck.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/crons/mac-cleanup-scan.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/crons/notify-failure.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/crons/weekly-finalize.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/crons/weekly-report-gen.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/env.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/auto-format.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/auto-test.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/breadcrumb-writer.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/detect-org.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/permission-auto-approve.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/permission-denied.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/pr-gate.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/prompt-injection-guard.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/protect-files.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/safety-guards.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/session-start.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/session-stop.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/stop-notification.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/hooks/test-fix-detector.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL002 | automation | reliability | `claude/refresh.sh` | missing \`set -euo pipefail\` in first 10 lines | Add \`set -euo pipefail\` as the second line after the shebang. |
| REL004 | automation | reliability | `claude/crons/claude-mem-worker.sh` | hardcoded claude binary path | Replace with $CLAUDE_BIN and source env.sh so the dynamic resolution chain (~/.local/bin → ~/.npm-packages/bin → /opt/homebrew/bin) handles installer changes. |
| REL004 | automation | reliability | `claude/crons/mac-cleanup-scan.sh` | hardcoded claude binary path | Replace with $CLAUDE_BIN and source env.sh so the dynamic resolution chain (~/.local/bin → ~/.npm-packages/bin → /opt/homebrew/bin) handles installer changes. |
| REL004 | automation | reliability | `claude/hooks/permission-auto-approve.sh` | hardcoded claude binary path | Replace with $CLAUDE_BIN and source env.sh so the dynamic resolution chain (~/.local/bin → ~/.npm-packages/bin → /opt/homebrew/bin) handles installer changes. |
| REL004 | automation | reliability | `claude/hooks/permission-denied.sh` | hardcoded claude binary path | Replace with $CLAUDE_BIN and source env.sh so the dynamic resolution chain (~/.local/bin → ~/.npm-packages/bin → /opt/homebrew/bin) handles installer changes. |
| REL004 | automation | reliability | `claude/install-launchagents.sh` | hardcoded claude binary path | Replace with $CLAUDE_BIN and source env.sh so the dynamic resolution chain (~/.local/bin → ~/.npm-packages/bin → /opt/homebrew/bin) handles installer changes. |
| REL004 | automation | reliability | `claude/refresh.sh` | hardcoded claude binary path | Replace with $CLAUDE_BIN and source env.sh so the dynamic resolution chain (~/.local/bin → ~/.npm-packages/bin → /opt/homebrew/bin) handles installer changes. |
| REL007 | automation | reliability | `claude/crons/claude-mem-worker.sh` | cron script missing last-success marker write | On successful completion, touch ~/Library/Logs/claude-crons/.last-success-<name> so the healthcheck can detect staleness. |
| REL007 | automation | reliability | `claude/crons/mac-cleanup-scan.sh` | cron script missing last-success marker write | On successful completion, touch ~/Library/Logs/claude-crons/.last-success-<name> so the healthcheck can detect staleness. |
| REL007 | automation | reliability | `claude/crons/notify-failure.sh` | cron script missing last-success marker write | On successful completion, touch ~/Library/Logs/claude-crons/.last-success-<name> so the healthcheck can detect staleness. |

## Medium findings

| ID | Layer | Criterion | Artifact | Message | Fix hint |
|----|-------|-----------|----------|---------|----------|
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
| OBS001 | automation | observability | `claude/env.sh` | log write to non-approved path: ~/.dotfiles/claude/env.sh | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/hooks/breadcrumb-writer.sh` | log write to non-approved path: $BREADCRUMB_DIR/breadcrumbs.md | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/hooks/permission-denied.sh` | log write to non-approved path: $LOG_FILE | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| OBS001 | automation | observability | `claude/hooks/permission-denied.sh` | log write to non-approved path: $LOG_FILE.tmp | Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, or ~/.claude/logs/ instead of ad-hoc paths. |
| REL001 | automation | reliability | `claude/crons/healthcheck.sh` | SC2034: MARKER_DIR appears unused. Verify use (or export if used externally). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL001 | automation | reliability | `claude/hooks/session-start.sh` | SC2034: plugin appears unused. Verify use (or export if used externally). | Run \`shellcheck <file>\` locally to see context; fix per shellcheck wiki. |
| REL003 | automation | reliability | `claude/crons/claude-mem-worker.sh` | cron script has no ERR or EXIT trap | Add \`trap 'notify-failure.sh' ERR\` near the top of the script. |
| REL003 | automation | reliability | `claude/crons/daily-retro-evening.sh` | cron script has no ERR or EXIT trap | Add \`trap 'notify-failure.sh' ERR\` near the top of the script. |
| REL003 | automation | reliability | `claude/crons/daily-retrospective.sh` | cron script has no ERR or EXIT trap | Add \`trap 'notify-failure.sh' ERR\` near the top of the script. |
| REL003 | automation | reliability | `claude/crons/healthcheck.sh` | cron script has no ERR or EXIT trap | Add \`trap 'notify-failure.sh' ERR\` near the top of the script. |
| REL003 | automation | reliability | `claude/crons/mac-cleanup-scan.sh` | cron script has no ERR or EXIT trap | Add \`trap 'notify-failure.sh' ERR\` near the top of the script. |
| REL003 | automation | reliability | `claude/crons/notify-failure.sh` | cron script has no ERR or EXIT trap | Add \`trap 'notify-failure.sh' ERR\` near the top of the script. |
| REL003 | automation | reliability | `claude/crons/weekly-finalize.sh` | cron script has no ERR or EXIT trap | Add \`trap 'notify-failure.sh' ERR\` near the top of the script. |
| REL003 | automation | reliability | `claude/crons/weekly-report-gen.sh` | cron script has no ERR or EXIT trap | Add \`trap 'notify-failure.sh' ERR\` near the top of the script. |
| REL005 | automation | reliability | `claude/crons/claude-mem-worker.sh` | cron script has no idempotency guard | Add a guard: flock to prevent concurrent runs, or check a last-success marker to skip redundant runs. |
| REL005 | automation | reliability | `claude/crons/healthcheck.sh` | cron script has no idempotency guard | Add a guard: flock to prevent concurrent runs, or check a last-success marker to skip redundant runs. |
| REL005 | automation | reliability | `claude/crons/mac-cleanup-scan.sh` | cron script has no idempotency guard | Add a guard: flock to prevent concurrent runs, or check a last-success marker to skip redundant runs. |
| REL005 | automation | reliability | `claude/crons/notify-failure.sh` | cron script has no idempotency guard | Add a guard: flock to prevent concurrent runs, or check a last-success marker to skip redundant runs. |
| REL006 | automation | reliability | `/Users/godl1ke/.dotfiles/tests` | no tests directory for dotfiles hook/cron scripts | Create ~/.dotfiles/tests/ with bats or pytest suites covering hook and cron scripts. |
| REL008 | automation | reliability | `claude/crons/daily-retro-evening.sh` | claude invocation without timeout | Wrap long-running claude calls with \`timeout <N>s $CLAUDE_BIN ...\` so a hung process can't wedge the cron. |
| REL008 | automation | reliability | `claude/crons/daily-retrospective.sh` | claude invocation without timeout | Wrap long-running claude calls with \`timeout <N>s $CLAUDE_BIN ...\` so a hung process can't wedge the cron. |
| REL008 | automation | reliability | `claude/crons/healthcheck.sh` | claude invocation without timeout | Wrap long-running claude calls with \`timeout <N>s $CLAUDE_BIN ...\` so a hung process can't wedge the cron. |
| REL008 | automation | reliability | `claude/crons/weekly-finalize.sh` | claude invocation without timeout | Wrap long-running claude calls with \`timeout <N>s $CLAUDE_BIN ...\` so a hung process can't wedge the cron. |
| REL008 | automation | reliability | `claude/crons/weekly-report-gen.sh` | claude invocation without timeout | Wrap long-running claude calls with \`timeout <N>s $CLAUDE_BIN ...\` so a hung process can't wedge the cron. |
| REL008 | automation | reliability | `claude/env.sh` | claude invocation without timeout | Wrap long-running claude calls with \`timeout <N>s $CLAUDE_BIN ...\` so a hung process can't wedge the cron. |

## Low findings

| ID | Layer | Criterion | Artifact | Message | Fix hint |
|----|-------|-----------|----------|---------|----------|
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
_Generated by cstack-audit 0.1.0 at 2026-04-17T23:07+00:00 · tools: shellcheck ShellCheck - shell script analysis tool_