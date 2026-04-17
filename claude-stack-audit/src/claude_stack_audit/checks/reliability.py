"""Reliability checks (REL001–REL009)."""

from __future__ import annotations

import json
import re
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


@register
class ErrOrExitTrap:
    id = "REL003"
    name = "cron scripts have ERR or EXIT trap"
    criterion = Criterion.RELIABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        crons_dir = ctx.claude_root / "crons"
        if not crons_dir.is_dir():
            return
        for script in sorted(crons_dir.glob("*.sh")):
            body = ctx.file_cache.read(script)
            if "trap " in body and ("ERR" in body or "EXIT" in body):
                continue
            yield Finding(
                check_id=self.id,
                severity=Severity.MEDIUM,
                layer=self.layer,
                criterion=self.criterion,
                artifact=str(script.relative_to(ctx.claude_root.parent)),
                message="cron script has no ERR or EXIT trap",
                details=None,
                fix_hint="Add `trap 'notify-failure.sh' ERR` near the top of the script.",
            )


_HARDCODED_CLAUDE_RE = re.compile(
    r"(?P<path>(?:/[\w.-]+)+/claude|~/[\w./-]+/claude|\$HOME/[\w./-]+/claude)\b"
)


@register
class ClaudeBinResolved:
    id = "REL004"
    name = "no hardcoded claude path"
    criterion = Criterion.RELIABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            body = ctx.file_cache.read(script)
            if "$CLAUDE_BIN" in body or "${CLAUDE_BIN" in body:
                continue
            match = _HARDCODED_CLAUDE_RE.search(body)
            if not match:
                continue
            yield Finding(
                check_id=self.id,
                severity=Severity.HIGH,
                layer=self.layer,
                criterion=self.criterion,
                artifact=str(script.relative_to(ctx.claude_root.parent)),
                message="hardcoded claude binary path",
                details=f"found: {match.group('path')}",
                fix_hint=(
                    "Replace with $CLAUDE_BIN and source env.sh so the dynamic "
                    "resolution chain (~/.local/bin → ~/.npm-packages/bin → "
                    "/opt/homebrew/bin) handles installer changes."
                ),
            )


_IDEMPOTENCY_MARKERS = ("flock", "last-success", "last-run", "skip-if-done")


@register
class CronIdempotencyGuard:
    id = "REL005"
    name = "cron idempotency guard"
    criterion = Criterion.RELIABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        crons_dir = ctx.claude_root / "crons"
        if not crons_dir.is_dir():
            return
        for script in sorted(crons_dir.glob("*.sh")):
            body = ctx.file_cache.read(script)
            if any(marker in body for marker in _IDEMPOTENCY_MARKERS):
                continue
            yield Finding(
                check_id=self.id,
                severity=Severity.MEDIUM,
                layer=self.layer,
                criterion=self.criterion,
                artifact=str(script.relative_to(ctx.claude_root.parent)),
                message="cron script has no idempotency guard",
                details=None,
                fix_hint=(
                    "Add a guard: flock to prevent concurrent runs, or "
                    "check a last-success marker to skip redundant runs."
                ),
            )


@register
class CompanionTestPresent:
    id = "REL006"
    name = "companion test directory present"
    criterion = Criterion.RELIABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        tests_dir = ctx.dotfiles_root / "tests"
        if tests_dir.is_dir():
            return
        yield Finding(
            check_id=self.id,
            severity=Severity.MEDIUM,
            layer=self.layer,
            criterion=self.criterion,
            artifact=str(tests_dir),
            message="no tests directory for dotfiles hook/cron scripts",
            details=None,
            fix_hint=(
                "Create ~/.dotfiles/tests/ with bats or pytest suites covering "
                "hook and cron scripts."
            ),
        )


@register
class CronHealthcheckMarker:
    id = "REL007"
    name = "cron healthcheck marker"
    criterion = Criterion.RELIABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        crons_dir = ctx.claude_root / "crons"
        if not crons_dir.is_dir():
            return
        for script in sorted(crons_dir.glob("*.sh")):
            # Skip the healthcheck itself — it READS markers, not writes them
            if script.stem == "healthcheck":
                continue
            body = ctx.file_cache.read(script)
            if "last-success" in body:
                continue
            yield Finding(
                check_id=self.id,
                severity=Severity.HIGH,
                layer=self.layer,
                criterion=self.criterion,
                artifact=str(script.relative_to(ctx.claude_root.parent)),
                message="cron script missing last-success marker write",
                details=None,
                fix_hint=(
                    "On successful completion, touch "
                    "~/Library/Logs/claude-crons/.last-success-<name> so the "
                    "healthcheck can detect staleness."
                ),
            )


@register
class LongOpTimeout:
    id = "REL008"
    name = "long-running ops have timeouts"
    criterion = Criterion.RELIABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            body = ctx.file_cache.read(script)
            invokes_claude = "$CLAUDE_BIN" in body or "${CLAUDE_BIN" in body
            if not invokes_claude:
                continue
            if "timeout " in body:
                continue
            yield Finding(
                check_id=self.id,
                severity=Severity.MEDIUM,
                layer=self.layer,
                criterion=self.criterion,
                artifact=str(script.relative_to(ctx.claude_root.parent)),
                message="claude invocation without timeout",
                details=None,
                fix_hint=(
                    "Wrap long-running claude calls with `timeout <N>s "
                    "$CLAUDE_BIN ...` so a hung process can't wedge the cron."
                ),
            )
