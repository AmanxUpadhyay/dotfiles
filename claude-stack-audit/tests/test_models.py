from datetime import UTC, datetime

from claude_stack_audit.checks.base import (
    Selection,
    clear_registry_for_tests,
    enabled_checks,
    register,
)
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


def test_registry_register_and_enabled_checks():
    clear_registry_for_tests()

    @register
    class DummyInventory:
        id = "TEST_INV"
        name = "dummy inventory"
        criterion = Criterion.INVENTORY
        layer = Layer.CORE

        def run(self, ctx):
            return []

    @register
    class DummyReliability:
        id = "TEST_REL"
        name = "dummy reliability"
        criterion = Criterion.RELIABILITY
        layer = Layer.AUTOMATION

        def run(self, ctx):
            return []

    enabled = enabled_checks(Selection())
    assert len(enabled) == 2

    quick = enabled_checks(Selection(quick=True))
    assert len(quick) == 1
    assert quick[0].id == "TEST_INV"

    subset = enabled_checks(Selection(criteria={Criterion.RELIABILITY}))
    assert len(subset) == 1
    assert subset[0].id == "TEST_REL"


def test_selection_combines_quick_and_criteria_filters():
    clear_registry_for_tests()

    @register
    class A:
        id = "A"
        name = "a"
        criterion = Criterion.INVENTORY
        layer = Layer.CORE

        def run(self, ctx):
            return []

    @register
    class B:
        id = "B"
        name = "b"
        criterion = Criterion.RELIABILITY
        layer = Layer.AUTOMATION

        def run(self, ctx):
            return []

    # quick=True + criteria={RELIABILITY}: RELIABILITY is filtered out by quick,
    # so nothing passes both filters.
    assert enabled_checks(Selection(quick=True, criteria={Criterion.RELIABILITY})) == []

    # quick=True + criteria={INVENTORY}: INVENTORY passes quick AND is in the set.
    result = enabled_checks(Selection(quick=True, criteria={Criterion.INVENTORY}))
    assert len(result) == 1
    assert result[0].id == "A"
