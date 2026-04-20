"""Audit runner. Validates the environment, builds the Context, iterates checks,
emits META findings on crashes, and returns a sorted Report."""

from __future__ import annotations

from collections.abc import Iterable
from datetime import UTC, datetime
from pathlib import Path

from claude_stack_audit import __version__
from claude_stack_audit.checks.base import Check, enabled_checks
from claude_stack_audit.config import Config
from claude_stack_audit.context import Context
from claude_stack_audit.external import ExternalTools
from claude_stack_audit.models import (
    Criterion,
    Finding,
    Inventory,
    Layer,
    Report,
    Scorecard,
    Severity,
)

_SEVERITY_ORDER = {
    Severity.CRITICAL: 0,
    Severity.HIGH: 1,
    Severity.MEDIUM: 2,
    Severity.LOW: 3,
    Severity.INFO: 4,
}


class ValidationError(RuntimeError):
    """Raised when the environment can't support an audit run."""


def validate_environment(*, dotfiles_root: Path, external: ExternalTools) -> None:
    if not dotfiles_root.exists():
        raise ValidationError(f"dotfiles root does not exist: {dotfiles_root}")
    result = external.run(["shellcheck", "--version"], timeout=5.0)
    if result.returncode != 0:
        raise ValidationError(
            "shellcheck not found or not executable. Install via: brew install shellcheck"
        )
    result = external.run(["jq", "--version"], timeout=5.0)
    if result.returncode != 0:
        raise ValidationError("jq not found or not executable. Install via: brew install jq")


def run(
    config: Config,
    *,
    external: ExternalTools | None = None,
    now: datetime | None = None,
) -> Report:
    external = external or ExternalTools()
    now = now or datetime.now(UTC)
    context = Context.build(dotfiles_root=config.dotfiles_root, external=external)

    findings = _collect_findings(enabled_checks(config.selection), context)
    _sort_findings(findings)

    return Report(
        generated_at=now,
        tool_version=__version__,
        findings=findings,
        # phase 1: Inventory stays empty; INV checks will populate it in phase 2.
        inventory=Inventory(),
        scorecard=Scorecard.from_findings(findings),
        external_tool_versions={
            "shellcheck": external.version(["shellcheck", "--version"]) or "unknown",
            "jq": external.version(["jq", "--version"]) or "unknown",
        },
    )


def _collect_findings(checks: Iterable[Check], context: Context) -> list[Finding]:
    """Run each check; exceptions become META001 findings so the runner never crashes."""
    findings: list[Finding] = []
    for check in checks:
        try:
            findings.extend(check.run(context))
        except Exception as exc:  # noqa: BLE001 - checks are arbitrary code; we classify, never crash
            findings.append(_meta_finding(check, exc))
    return findings


def _meta_finding(check: Check, exc: Exception) -> Finding:
    return Finding(
        check_id="META001",
        severity=Severity.HIGH,
        layer=Layer.CORE,
        criterion=Criterion.CROSS_CUTTING,
        artifact=f"check:{check.id}",
        message=f"check {check.id} crashed",
        details=f"{check.id} raised {type(exc).__name__}: {exc}",
        fix_hint=f"See logs; fix the check implementation for {check.id}.",
    )


def _sort_findings(findings: list[Finding]) -> None:
    findings.sort(
        key=lambda f: (
            _SEVERITY_ORDER[f.severity],
            f.layer.value,
            f.criterion.value,
            f.check_id,
            f.artifact,
        )
    )
