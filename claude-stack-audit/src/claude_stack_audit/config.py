"""Config loader. Maps CLI arguments to the Config dataclass consumed by the runner."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from claude_stack_audit.checks.base import Selection
from claude_stack_audit.models import Criterion


@dataclass
class Config:
    dotfiles_root: Path
    output_dir: Path
    selection: Selection = field(default_factory=Selection)
    tag: str | None = None

    @property
    def output_md(self) -> Path:
        from datetime import date

        suffix = f"--{self.tag}" if self.tag else ""
        return self.output_dir / f"{date.today().isoformat()}-stack-audit{suffix}.md"

    @property
    def output_json(self) -> Path:
        from datetime import date

        suffix = f"--{self.tag}" if self.tag else ""
        return self.output_dir / f"{date.today().isoformat()}-stack-audit{suffix}.json"


def parse_criteria(s: str | None) -> set[Criterion] | None:
    if not s:
        return None
    return {Criterion(x.strip()) for x in s.split(",")}
