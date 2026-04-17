from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path

import pytest

from claude_stack_audit.checks.base import (
    Selection,
    clear_registry_for_tests,
    register,
)
from claude_stack_audit.config import Config
from claude_stack_audit.models import Criterion, Finding, Layer, Severity
from claude_stack_audit.runner import ValidationError, run, validate_environment


def _mk_config(root: Path, out: Path) -> Config:
    return Config(dotfiles_root=root, output_dir=out, selection=Selection())


def test_runner_collects_findings_from_all_checks(fake_dotfiles, fake_external_tools, tmp_path):
    clear_registry_for_tests()

    @register
    class EmitsOne:
        id = "T01"
        name = "emits one"
        criterion = Criterion.RELIABILITY
        layer = Layer.AUTOMATION

        def run(self, ctx):
            yield Finding(
                check_id=self.id,
                severity=Severity.HIGH,
                layer=self.layer,
                criterion=self.criterion,
                artifact="x",
                message="x",
            )

    cfg = _mk_config(fake_dotfiles, tmp_path / "out")
    report = run(cfg, external=fake_external_tools, now=datetime(2026, 4, 17, tzinfo=UTC))
    assert len(report.findings) == 1
    assert report.findings[0].check_id == "T01"


def test_runner_emits_meta_finding_on_check_crash(fake_dotfiles, fake_external_tools, tmp_path):
    clear_registry_for_tests()

    @register
    class Crashes:
        id = "T02"
        name = "crashes"
        criterion = Criterion.RELIABILITY
        layer = Layer.AUTOMATION

        def run(self, ctx):
            raise RuntimeError("boom")

    cfg = _mk_config(fake_dotfiles, tmp_path / "out")
    report = run(cfg, external=fake_external_tools)
    meta = [f for f in report.findings if f.check_id == "META001"]
    assert len(meta) == 1
    assert "T02" in meta[0].details
    assert meta[0].severity == Severity.HIGH


def test_validate_environment_raises_when_shellcheck_missing(tmp_path):
    class NoTools:
        def run(self, argv, **_):
            from claude_stack_audit.external import ToolResult

            return ToolResult(
                returncode=127, stdout="", stderr="not found", duration_ms=0, timed_out=False
            )

    with pytest.raises(ValidationError):
        validate_environment(dotfiles_root=tmp_path, external=NoTools())


def test_runner_sorts_findings_by_severity_desc(fake_dotfiles, fake_external_tools, tmp_path):
    clear_registry_for_tests()

    @register
    class Many:
        id = "T03"
        name = "many"
        criterion = Criterion.RELIABILITY
        layer = Layer.AUTOMATION

        def run(self, ctx):
            for sev in [Severity.LOW, Severity.CRITICAL, Severity.MEDIUM, Severity.HIGH]:
                yield Finding(
                    check_id=self.id,
                    severity=sev,
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(sev),
                    message="x",
                )

    cfg = _mk_config(fake_dotfiles, tmp_path / "out")
    report = run(cfg, external=fake_external_tools)
    severities = [f.severity for f in report.findings]
    assert severities == [Severity.CRITICAL, Severity.HIGH, Severity.MEDIUM, Severity.LOW]
