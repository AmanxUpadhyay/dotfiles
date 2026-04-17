"""Cross-cutting checks (CROSS001–CROSS004). Phase 1 ships CROSS001 only."""

from __future__ import annotations

import re
from collections.abc import Iterable
from pathlib import Path

from claude_stack_audit.checks.base import register
from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer, Severity

_SYMLINKS = ("settings.json", "env.sh", "org-map.json")

_BROAD_BASH_RE = re.compile(r"^Bash\((?:\*|bash:\*|\*:\*)\)$", re.IGNORECASE)


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


@register
class BashPermissionScope:
    id = "CROSS002"
    name = "bash permission scope"
    criterion = Criterion.CROSS_CUTTING
    layer = Layer.CORE

    def run(self, ctx: Context) -> Iterable[Finding]:
        for section in ("allow", "deny"):
            patterns = ctx.settings.permissions.get(section, []) or []
            if not isinstance(patterns, list):
                continue
            for entry in patterns:
                if not isinstance(entry, str):
                    continue
                if _BROAD_BASH_RE.match(entry):
                    yield Finding(
                        check_id=self.id,
                        severity=Severity.MEDIUM,
                        layer=self.layer,
                        criterion=self.criterion,
                        artifact=f"settings.json:permissions.{section}",
                        message=f"overly broad bash pattern: {entry}",
                        details=None,
                        fix_hint=(
                            "Narrow the pattern to specific commands: "
                            "Bash(npm:*), Bash(git status:*), etc."
                        ),
                    )
