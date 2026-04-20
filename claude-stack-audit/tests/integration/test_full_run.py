from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path

import jsonschema
import pytest

from claude_stack_audit.checks.base import Selection
from claude_stack_audit.config import Config
from claude_stack_audit.models import Criterion, Layer
from claude_stack_audit.reports.json_report import SCHEMA
from claude_stack_audit.reports.json_report import render as render_json
from claude_stack_audit.reports.markdown import render as render_markdown
from claude_stack_audit.runner import run

pytestmark = pytest.mark.integration


def test_full_run_on_synthetic_dotfiles_produces_valid_report(
    fake_dotfiles: Path, fake_external_tools, tmp_path
):
    config = Config(
        dotfiles_root=fake_dotfiles,
        output_dir=tmp_path / "out",
        selection=Selection(),
    )
    report = run(config, external=fake_external_tools, now=datetime(2026, 4, 17, tzinfo=UTC))

    # JSON schema-valid
    jsonschema.validate(instance=render_json(report), schema=SCHEMA)

    # Markdown non-empty
    md = render_markdown(report)
    assert "Claude Stack Audit" in md
    assert "Health score" in md

    # Each registered check ran (or emitted META)
    check_ids = {f.check_id for f in report.findings}
    # INV001 always emits (fixture has hooks)
    assert "INV001" in check_ids


def test_full_run_records_meta_finding_when_check_raises(
    empty_registry, fake_dotfiles: Path, fake_external_tools, tmp_path
):
    from claude_stack_audit.checks.base import register

    @register
    class AlwaysCrash:
        id = "TCRASH"
        name = "always crash"
        criterion = Criterion.RELIABILITY
        layer = Layer.AUTOMATION

        def run(self, ctx):
            raise RuntimeError("boom")

    config = Config(
        dotfiles_root=fake_dotfiles,
        output_dir=tmp_path / "out",
        selection=Selection(),
    )
    report = run(config, external=fake_external_tools)
    metas = [f for f in report.findings if f.check_id == "META001"]
    assert len(metas) == 1
