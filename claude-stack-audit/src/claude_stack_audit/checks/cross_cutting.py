"""Cross-cutting checks (CROSS001–CROSS004). Phase 1 ships CROSS001 only."""

from __future__ import annotations

from collections.abc import Iterable
from pathlib import Path

from claude_stack_audit.checks.base import register
from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer, Severity

_SYMLINKS = ("settings.json", "env.sh", "org-map.json")


@register
class SymlinkIntegrity:
    id = "CROSS001"
    name = "symlink integrity"
    criterion = Criterion.CROSS_CUTTING
    layer = Layer.CORE

    def __init__(self, dotclaude_root: Path | None = None) -> None:
        self.dotclaude_root = dotclaude_root or (Path.home() / ".claude")

    def run(self, ctx: Context) -> Iterable[Finding]:
        for name in _SYMLINKS:
            link = self.dotclaude_root / name
            if not link.is_symlink():
                if not link.exists():
                    yield Finding(
                        check_id=self.id,
                        severity=Severity.CRITICAL,
                        layer=self.layer,
                        criterion=self.criterion,
                        artifact=str(link),
                        message=f"expected symlink missing: {name}",
                        details=None,
                        fix_hint=f"ln -sf {ctx.claude_root / name} {link}",
                    )
                continue
            target = link.resolve()
            if not target.exists():
                yield Finding(
                    check_id=self.id,
                    severity=Severity.CRITICAL,
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(link),
                    message=f"symlink target missing: {name}",
                    details=f"readlink -> {target}",
                    fix_hint=f"ln -sf {ctx.claude_root / name} {link}",
                )
