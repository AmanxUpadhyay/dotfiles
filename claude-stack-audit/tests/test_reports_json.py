from datetime import UTC, datetime

import jsonschema

from claude_stack_audit.models import (
    Criterion,
    Finding,
    HookRecord,
    Inventory,
    Layer,
    Report,
    Scorecard,
    Severity,
)
from claude_stack_audit.reports.json_report import SCHEMA, render


def _sample_report():
    findings = [
        Finding(
            check_id="CROSS001",
            severity=Severity.CRITICAL,
            layer=Layer.CORE,
            criterion=Criterion.CROSS_CUTTING,
            artifact="~/.claude/env.sh",
            message="Symlink broken",
            details="ENOENT",
            fix_hint="ln -sf ...",
        ),
    ]
    inventory = Inventory(hooks=[HookRecord(path="hooks/foo.sh", events=["Stop"])])
    return Report(
        generated_at=datetime(2026, 4, 17, 14, 30, tzinfo=UTC),
        tool_version="0.1.0",
        findings=findings,
        inventory=inventory,
        scorecard=Scorecard.from_findings(findings),
        external_tool_versions={"shellcheck": "0.9.0"},
    )


def test_render_includes_schema_version_and_score():
    out = render(_sample_report())
    assert out["schema_version"] == "1"
    assert out["score"] == 990  # 1000 - 10
    assert out["tool_version"] == "0.1.0"


def test_render_findings_structure():
    out = render(_sample_report())
    f = out["findings"][0]
    assert f["check_id"] == "CROSS001"
    assert f["severity"] == "critical"
    assert f["layer"] == "core"
    assert f["criterion"] == "cross_cutting"


def test_render_validates_against_schema():
    out = render(_sample_report())
    jsonschema.validate(instance=out, schema=SCHEMA)
