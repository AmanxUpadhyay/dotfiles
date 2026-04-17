"""Reliability checks (REL001–REL009)."""

from __future__ import annotations

import json
from collections.abc import Iterable

from claude_stack_audit.checks.base import register
from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer, Severity

_LEVEL_TO_SEVERITY = {
    "error": Severity.HIGH,
    "warning": Severity.MEDIUM,
    "info": Severity.LOW,
    "style": Severity.LOW,
}


@register
class ShellcheckClean:
    id = "REL001"
    name = "shellcheck clean"
    criterion = Criterion.RELIABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            result = ctx.external.shellcheck(script)
            if result.timed_out:
                yield Finding(
                    check_id=self.id,
                    severity=Severity.MEDIUM,
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(script.relative_to(ctx.claude_root.parent)),
                    message="shellcheck timed out",
                    details=None,
                    fix_hint="Increase timeout or inspect script for infinite loops.",
                )
                continue
            if not result.stdout.strip():
                continue
            try:
                issues = json.loads(result.stdout)
            except json.JSONDecodeError:
                continue
            for issue in issues:
                level = issue.get("level", "warning")
                yield Finding(
                    check_id=self.id,
                    severity=_LEVEL_TO_SEVERITY.get(level, Severity.MEDIUM),
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(script.relative_to(ctx.claude_root.parent)),
                    message=f"SC{issue.get('code', '?')}: {issue.get('message', '')}",
                    details=f"line {issue.get('line', '?')}, column {issue.get('column', '?')}",
                    fix_hint=(
                        "Run `shellcheck <file>` locally to see context; fix per shellcheck wiki."
                    ),
                )


@register
class SetEuoPipefail:
    id = "REL002"
    name = "set -euo pipefail present"
    criterion = Criterion.RELIABILITY
    layer = Layer.AUTOMATION

    _ACCEPTABLE_PATTERNS = (
        "set -euo pipefail",
        "set -eou pipefail",
        "set -e -u -o pipefail",
    )

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            body = ctx.file_cache.read(script)
            head = "\n".join(body.splitlines()[:10])
            if any(p in head for p in self._ACCEPTABLE_PATTERNS):
                continue
            yield Finding(
                check_id=self.id,
                severity=Severity.HIGH,
                layer=self.layer,
                criterion=self.criterion,
                artifact=str(script.relative_to(ctx.claude_root.parent)),
                message="missing `set -euo pipefail` in first 10 lines",
                details=None,
                fix_hint="Add `set -euo pipefail` as the second line after the shebang.",
            )
