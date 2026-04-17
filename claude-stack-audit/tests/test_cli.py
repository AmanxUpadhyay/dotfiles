from __future__ import annotations

from pathlib import Path

from typer.testing import CliRunner

from claude_stack_audit.cli import app


def test_version_flag():
    runner = CliRunner()
    result = runner.invoke(app, ["--version"])
    assert result.exit_code == 0
    assert "0.1.0" in result.stdout


def test_list_checks_empty(empty_registry, tmp_path):
    runner = CliRunner()
    result = runner.invoke(app, ["list-checks"])
    assert result.exit_code == 0
    assert "No checks registered" in result.stdout


def test_run_writes_reports_to_output_dir(
    empty_registry, fake_dotfiles: Path, tmp_path, monkeypatch
):
    # Skip env validation for this test
    monkeypatch.setattr("claude_stack_audit.cli.validate_environment", lambda **_: None)
    runner = CliRunner()
    out = tmp_path / "out"
    result = runner.invoke(
        app,
        [
            "run",
            "--dotfiles-root",
            str(fake_dotfiles),
            "--output-dir",
            str(out),
        ],
    )
    assert result.exit_code in (0, 1), result.stdout
    mds = list(out.glob("*.md"))
    jsons = list(out.glob("*.json"))
    assert len(mds) == 1
    assert len(jsons) == 1
