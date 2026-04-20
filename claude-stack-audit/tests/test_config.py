"""Tests for config module — parse_criteria behaviour and output paths."""

from __future__ import annotations

from datetime import date
from pathlib import Path

import pytest
import typer

from claude_stack_audit.config import Config, parse_criteria
from claude_stack_audit.models import Criterion


def test_parse_criteria_returns_none_for_empty_input():
    assert parse_criteria(None) is None
    assert parse_criteria("") is None
    assert parse_criteria("   ") is None
    assert parse_criteria(",,,") is None


def test_parse_criteria_parses_valid_names():
    result = parse_criteria("reliability,documentation")
    assert result == {Criterion.RELIABILITY, Criterion.DOCUMENTATION}


def test_parse_criteria_raises_bad_parameter_on_invalid_name():
    with pytest.raises(typer.BadParameter) as exc_info:
        parse_criteria("reliability,docs")
    msg = str(exc_info.value)
    assert "docs" in msg
    # Valid criteria should be listed for helpfulness
    assert "documentation" in msg
    assert "reliability" in msg


# -----------------------------------------------------------------------------
# Output-path contract — pinned by ADR 2026-04-20-audit-snapshot-policy.md
# -----------------------------------------------------------------------------


def _cfg(tmp_path: Path, *, tag: str | None = None) -> Config:
    return Config(dotfiles_root=tmp_path, output_dir=tmp_path, tag=tag)


def test_output_md_default_is_canonical_stack_audit(tmp_path: Path) -> None:
    assert _cfg(tmp_path).output_md == tmp_path / "stack-audit.md"


def test_output_json_default_is_canonical_stack_audit(tmp_path: Path) -> None:
    assert _cfg(tmp_path).output_json == tmp_path / "stack-audit.json"


def test_output_md_with_tag_uses_double_dash_tag_suffix(tmp_path: Path) -> None:
    assert _cfg(tmp_path, tag="before-fix").output_md == tmp_path / "stack-audit--before-fix.md"


def test_output_json_with_tag_uses_double_dash_tag_suffix(tmp_path: Path) -> None:
    assert _cfg(tmp_path, tag="before-fix").output_json == tmp_path / "stack-audit--before-fix.json"


def test_output_paths_have_no_date_prefix(tmp_path: Path) -> None:
    # Regression guard: the whole point of the ADR is that dates leave the
    # filename. If this test fails, someone has reverted to date-stamped paths.
    today = date.today().isoformat()
    cfg = _cfg(tmp_path)
    assert today not in cfg.output_md.name
    assert today not in cfg.output_json.name
    tagged = _cfg(tmp_path, tag="trend")
    assert today not in tagged.output_md.name
    assert today not in tagged.output_json.name
