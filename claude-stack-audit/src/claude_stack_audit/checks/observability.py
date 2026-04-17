"""Observability checks (OBS001–OBS006). Phase 1 ships OBS001 only."""

from __future__ import annotations

import re
from collections.abc import Iterable
from pathlib import Path

from claude_stack_audit.checks.base import register
from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer, Severity

_APPROVED_PREFIXES = (
    "$HOME/Library/Logs/claude-crons",
    "~/Library/Logs/claude-crons",
    "$HOME/.claude/logs",
    "~/.claude/logs",
    "$CLAUDE_LOG_DIR",
)

# Match redirects or tee into files: > /path, >> /path, 2> /path, tee /path
_LOG_WRITE_RE = re.compile(r"""(?:>>?|2>>?|\|\s*tee(?:\s+-a)?)\s+("?)(?P<path>\S+?)\1(?:\s|$)""")


@register
class LogPathConsistency:
    id = "OBS001"
    name = "log path consistency"
    criterion = Criterion.OBSERVABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            body = ctx.file_cache.read(script)
            for m in _LOG_WRITE_RE.finditer(body):
                path = m.group("path")
                if path.startswith(_APPROVED_PREFIXES):
                    continue
                if path.startswith(("/tmp/", "/var/tmp/")):
                    severity = Severity.HIGH
                elif path.startswith(("$", "~")) or path.startswith("/"):
                    severity = Severity.MEDIUM
                else:
                    continue  # relative path; skip (probably not a log file)
                yield Finding(
                    check_id=self.id,
                    severity=severity,
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(script.relative_to(ctx.claude_root.parent)),
                    message=f"log write to non-approved path: {path}",
                    details=None,
                    fix_hint=(
                        "Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, "
                        "or ~/.claude/logs/ instead of ad-hoc paths."
                    ),
                )


@register
class StdoutCaptureWithTimestamp:
    id = "OBS002"
    name = "stdout capture with timestamp"
    criterion = Criterion.OBSERVABILITY
    layer = Layer.AUTOMATION

    _TIMESTAMP_MARKERS = ("date ", "%F", "%T", "%s", " ts ", " ts\n", "iso")

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            body = ctx.file_cache.read(script)
            if "$CLAUDE_BIN" not in body and "${CLAUDE_BIN" not in body:
                continue
            if any(m in body for m in self._TIMESTAMP_MARKERS):
                continue
            yield Finding(
                check_id=self.id,
                severity=Severity.MEDIUM,
                layer=self.layer,
                criterion=self.criterion,
                artifact=str(script.relative_to(ctx.claude_root.parent)),
                message="claude invocation without timestamped output capture",
                details=None,
                fix_hint=(
                    "Pipe stdout/stderr through `ts '%Y-%m-%dT%H:%M:%S%z'` "
                    "(moreutils) or prepend `date -u +%FT%TZ` to log lines."
                ),
            )


@register
class NotifyFailureSourced:
    id = "OBS003"
    name = "cron sources notify-failure"
    criterion = Criterion.OBSERVABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        crons_dir = ctx.claude_root / "crons"
        if not crons_dir.is_dir():
            return
        for script in sorted(crons_dir.glob("*.sh")):
            body = ctx.file_cache.read(script)
            if "notify-failure" in body:
                continue
            yield Finding(
                check_id=self.id,
                severity=Severity.HIGH,
                layer=self.layer,
                criterion=self.criterion,
                artifact=str(script.relative_to(ctx.claude_root.parent)),
                message="cron does not source notify-failure.sh",
                details=None,
                fix_hint=(
                    'Add `source "$HOME/.dotfiles/claude/crons/notify-failure.sh"` '
                    "near the top and call `notify_failure` from an ERR trap."
                ),
            )


@register
class DurationStatusMarkers:
    id = "OBS004"
    name = "cron emits duration/status markers"
    criterion = Criterion.OBSERVABILITY
    layer = Layer.AUTOMATION

    _MARKERS = ("duration_ms", "duration=", "status=done", "status=ok", "status=fail")

    def run(self, ctx: Context) -> Iterable[Finding]:
        crons_dir = ctx.claude_root / "crons"
        if not crons_dir.is_dir():
            return
        for script in sorted(crons_dir.glob("*.sh")):
            body = ctx.file_cache.read(script)
            if any(marker in body for marker in self._MARKERS):
                continue
            yield Finding(
                check_id=self.id,
                severity=Severity.MEDIUM,
                layer=self.layer,
                criterion=self.criterion,
                artifact=str(script.relative_to(ctx.claude_root.parent)),
                message="cron does not emit duration/status markers",
                details=None,
                fix_hint=(
                    "Log lines like `duration_ms=1234 status=ok` on completion "
                    "so metrics scrapers can track runs."
                ),
            )


@register
class LogRotationPolicy:
    id = "OBS005"
    name = "log rotation policy exists"
    criterion = Criterion.OBSERVABILITY
    layer = Layer.AUTOMATION

    _ROTATION_MARKERS = ("logrotate", "rotate_logs", "-mtime", "gzip")

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            body = ctx.file_cache.read(script)
            if any(m in body for m in self._ROTATION_MARKERS):
                return  # at least one script handles rotation; no finding
        yield Finding(
            check_id=self.id,
            severity=Severity.MEDIUM,
            layer=self.layer,
            criterion=self.criterion,
            artifact=str(ctx.claude_root),
            message="no log rotation script found in dotfiles",
            details=None,
            fix_hint=(
                "Add a cron script that rotates logs in "
                "~/Library/Logs/claude-crons/ (e.g. `find -mtime +30 -delete` "
                "or gzip/logrotate)."
            ),
        )


@register
class HookHandlerExists:
    id = "OBS006"
    name = "hook handler resolves"
    criterion = Criterion.OBSERVABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for event_name, entries in (ctx.settings.hook_events or {}).items():
            for entry in entries or []:
                for hook in entry.get("hooks", []) or []:
                    cmd = hook.get("command", "")
                    if not cmd:
                        continue
                    # Resolve relative paths against claude_root
                    path = ctx.claude_root / cmd if not cmd.startswith("/") else Path(cmd)
                    if path.is_file():
                        continue
                    yield Finding(
                        check_id=self.id,
                        severity=Severity.HIGH,
                        layer=self.layer,
                        criterion=self.criterion,
                        artifact=cmd,
                        message=f"{event_name} hook command does not resolve",
                        details=f"expected: {path}",
                        fix_hint=(
                            "Fix the command path in settings.json or create the handler script."
                        ),
                    )
