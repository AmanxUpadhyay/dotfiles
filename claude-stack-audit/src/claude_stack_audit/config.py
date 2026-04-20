"""Config loader. Maps CLI arguments to the Config dataclass consumed by the runner."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import typer

from claude_stack_audit.checks.base import Selection
from claude_stack_audit.models import Criterion


@dataclass
class Config:
    dotfiles_root: Path
    output_dir: Path
    selection: Selection = field(default_factory=Selection)
    tag: str | None = None

    # Filename policy pinned by docs/superpowers/adr/2026-04-20-audit-snapshot-policy.md:
    # single canonical path, always overwritten, no date prefix. Date is git metadata.
    @property
    def output_md(self) -> Path:
        suffix = f"--{self.tag}" if self.tag else ""
        return self.output_dir / f"stack-audit{suffix}.md"

    @property
    def output_json(self) -> Path:
        suffix = f"--{self.tag}" if self.tag else ""
        return self.output_dir / f"stack-audit{suffix}.json"


def parse_criteria(s: str | None) -> set[Criterion] | None:
    if not s:
        return None
    parts = [x.strip() for x in s.split(",") if x.strip()]
    if not parts:
        return None
    valid = {c.value for c in Criterion}
    invalid = [p for p in parts if p not in valid]
    if invalid:
        raise typer.BadParameter(
            f"unknown criterion(s): {', '.join(invalid)}. Valid names: {', '.join(sorted(valid))}."
        )
    return {Criterion(p) for p in parts}
