from datetime import UTC, datetime

from claude_stack_audit.models import (
    Criterion,
    Finding,
    Inventory,
    Layer,
    Report,
    Scorecard,
    Severity,
)
from claude_stack_audit.reports.markdown import render


def _mk(sev: Severity, check_id: str = "REL001", message: str = "bad thing") -> Finding:
    return Finding(
        check_id=check_id,
        severity=sev,
        layer=Layer.AUTOMATION,
        criterion=Criterion.RELIABILITY,
        artifact="hooks/foo.sh",
        message=message,
        details=None,
        fix_hint="fix it",
    )


def _report(findings):
    return Report(
        generated_at=datetime(2026, 4, 17, 14, 30, tzinfo=UTC),
        tool_version="0.1.0",
        findings=findings,
        inventory=Inventory(),
        scorecard=Scorecard.from_findings(findings),
        external_tool_versions={"shellcheck": "0.9.0"},
    )


def test_renders_score_and_severity_counts():
    out = render(_report([_mk(Severity.CRITICAL), _mk(Severity.HIGH), _mk(Severity.HIGH)]))
    assert "Health score: 980" in out  # 1000 - 10 - 10 = 980
    assert "Critical" in out
    assert "High" in out


def test_renders_critical_section_when_present():
    out = render(_report([_mk(Severity.CRITICAL, check_id="CROSS001", message="broken symlink")]))
    assert "## Critical findings" in out
    assert "CROSS001" in out
    assert "broken symlink" in out


def test_renders_no_findings_happy_path():
    out = render(_report([]))
    assert "Health score: 1000" in out
    assert "No findings" in out


def test_finding_table_escapes_pipe_characters():
    finding_with_pipe = _mk(
        Severity.HIGH,
        check_id="REL001",
        message="run `shellcheck | grep error` locally",
    )
    out = render(_report([finding_with_pipe]))
    # The pipe inside the message must be escaped so it doesn't create extra columns.
    assert r"\|" in out
    # The backticks in the message must be escaped so they don't collide with artifact backticks.
    assert r"\`" in out


def test_info_only_findings_render_no_actionable_message():
    info = _mk(Severity.INFO, check_id="INV001", message="hook X bound to Stop")
    out = render(_report([info]))
    # Summary still shows the Info count.
    assert "| Info | 1 |" in out
    # But body shows the happy-path message because nothing is actionable.
    assert "_No findings. The stack is clean._" in out
    # And no High/Medium/Low sections appear.
    assert "## High findings" not in out
    assert "## Medium findings" not in out
    assert "## Low findings" not in out
