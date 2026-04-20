"""Tests for config module — parse_criteria behaviour."""

from __future__ import annotations

import pytest
import typer

from claude_stack_audit.config import parse_criteria
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
