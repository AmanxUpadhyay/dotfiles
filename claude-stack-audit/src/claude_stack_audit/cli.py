"""Typer CLI entry point."""

from __future__ import annotations

from pathlib import Path
from typing import Annotated

import typer

from claude_stack_audit import (
    __version__,
    checks,  # noqa: F401 — side-effect: registers checks
)
from claude_stack_audit.checks.base import Selection, all_registered_check_classes
from claude_stack_audit.config import Config, parse_criteria
from claude_stack_audit.external import ExternalTools
from claude_stack_audit.models import Report, Severity
from claude_stack_audit.reports import json_report, markdown
from claude_stack_audit.runner import ValidationError, validate_environment
from claude_stack_audit.runner import run as runner_run

app = typer.Typer(
    add_completion=False, help="Audit the Claude Code + dotfiles + Obsidian pipeline."
)

# Module-level sentinels avoid B008 (no Path.home() calls in function default args).
_DEFAULT_DOTFILES_ROOT: Path = Path.home() / ".dotfiles"
_DEFAULT_OUTPUT_DIR: Path = Path.home() / ".dotfiles" / "docs" / "superpowers" / "audits"


def _version_callback(value: bool) -> None:
    if value:
        typer.echo(__version__)
        raise typer.Exit()


@app.callback()
def main(
    version: Annotated[
        bool | None,
        typer.Option(
            "--version", callback=_version_callback, is_eager=True, help="Show version and exit."
        ),
    ] = None,
) -> None:
    pass


@app.command("list-checks")
def list_checks() -> None:
    """List all registered checks."""
    classes = all_registered_check_classes()
    if not classes:
        typer.echo("No checks registered.")
        return
    for cls in classes:
        typer.echo(f"{cls.id:<10} {cls.criterion.value:<14} {cls.layer.value:<11} {cls.name}")


@app.command()
def validate(
    dotfiles_root: Annotated[
        Path, typer.Option(envvar="CSTACK_DOTFILES_ROOT")
    ] = _DEFAULT_DOTFILES_ROOT,
) -> None:
    """Check that the environment is ready for an audit run."""
    try:
        validate_environment(dotfiles_root=dotfiles_root, external=ExternalTools())
    except ValidationError as exc:
        typer.echo(f"error: {exc}", err=True)
        raise typer.Exit(code=2) from None
    typer.echo("ok: environment ready")


@app.command()
def run(
    dotfiles_root: Annotated[
        Path, typer.Option(envvar="CSTACK_DOTFILES_ROOT")
    ] = _DEFAULT_DOTFILES_ROOT,
    output_dir: Annotated[Path, typer.Option(envvar="CSTACK_OUTPUT_DIR")] = _DEFAULT_OUTPUT_DIR,
    only: Annotated[
        str | None, typer.Option(help="Comma-separated criteria (e.g. reliability,docs)")
    ] = None,
    quick: Annotated[bool, typer.Option(help="Run only inventory + cross_cutting checks")] = False,
    tag: Annotated[str | None, typer.Option(help="Filename suffix for A/B tagging")] = None,
    skip_validate: Annotated[bool, typer.Option("--skip-validate", hidden=True)] = False,
) -> None:
    """Run the audit and write reports."""
    external = ExternalTools()
    if not skip_validate:
        _validate_or_exit(dotfiles_root, external)

    config = _build_config(dotfiles_root, output_dir, only, quick, tag)

    try:
        report = runner_run(config, external=external)
    except Exception as exc:  # noqa: BLE001 - top-level safety net
        typer.echo(f"error: runner failed: {exc}", err=True)
        raise typer.Exit(code=3) from None

    markdown.write(report, config.output_md)
    json_report.write(report, config.output_json)

    _emit_summary(report, config)
    _raise_for_exit_code(report)


def _validate_or_exit(dotfiles_root: Path, external: ExternalTools) -> None:
    try:
        validate_environment(dotfiles_root=dotfiles_root, external=external)
    except ValidationError as exc:
        typer.echo(f"error: {exc}", err=True)
        raise typer.Exit(code=2) from None


def _build_config(
    dotfiles_root: Path,
    output_dir: Path,
    only: str | None,
    quick: bool,
    tag: str | None,
) -> Config:
    return Config(
        dotfiles_root=dotfiles_root,
        output_dir=output_dir,
        selection=Selection(criteria=parse_criteria(only), quick=quick),
        tag=tag,
    )


def _emit_summary(report: Report, config: Config) -> None:
    c = report.scorecard.counts
    summary = (
        f"{len(report.findings)} findings "
        f"({c.get(Severity.CRITICAL, 0)} Critical, "
        f"{c.get(Severity.HIGH, 0)} High, "
        f"{c.get(Severity.MEDIUM, 0)} Medium, "
        f"{c.get(Severity.LOW, 0)} Low, "
        f"{c.get(Severity.INFO, 0)} Info). "
        f"Score: {report.scorecard.score}/1000."
    )
    typer.echo(summary, err=True)
    typer.echo(f"Markdown: {config.output_md}", err=True)
    typer.echo(f"JSON:     {config.output_json}", err=True)


def _raise_for_exit_code(report: Report) -> None:
    if any(f.check_id == "META001" for f in report.findings):
        raise typer.Exit(code=3)
    c = report.scorecard.counts
    if c.get(Severity.CRITICAL, 0) + c.get(Severity.HIGH, 0) > 0:
        raise typer.Exit(code=1)
