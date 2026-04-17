"""Observability checks (OBS001–OBS006). Phase 1 ships OBS001 only."""

from __future__ import annotations

import re
from collections.abc import Iterable

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
