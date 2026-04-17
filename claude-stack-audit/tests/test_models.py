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


def _f(severity: Severity) -> Finding:
    return Finding(
        check_id="TEST",
        severity=severity,
        layer=Layer.CORE,
        criterion=Criterion.RELIABILITY,
        artifact="x",
        message="x",
        details=None,
        fix_hint=None,
    )


def test_severity_weights_sum_correctly():
    findings = [
        _f(Severity.CRITICAL),
        _f(Severity.HIGH),
        _f(Severity.HIGH),
        _f(Severity.MEDIUM),
        _f(Severity.LOW),
        _f(Severity.INFO),
    ]
    sc = Scorecard.from_findings(findings)
    # critical=10, high*2=10, medium=2, low=1, info=0 → total penalty 23
    assert sc.score == 1000 - 23
    assert sc.counts == {
        Severity.CRITICAL: 1,
        Severity.HIGH: 2,
        Severity.MEDIUM: 1,
        Severity.LOW: 1,
        Severity.INFO: 1,
    }


def test_score_never_below_zero():
    findings = [_f(Severity.CRITICAL)] * 200  # 2000 penalty
    sc = Scorecard.from_findings(findings)
    assert sc.score == 0


def test_report_carries_generated_at_and_version():
    r = Report(
        generated_at=datetime(2026, 4, 17, tzinfo=UTC),
        tool_version="0.1.0",
        findings=[],
        inventory=Inventory(),
        scorecard=Scorecard.from_findings([]),
        external_tool_versions={},
    )
    assert r.tool_version == "0.1.0"
    assert r.scorecard.score == 1000
