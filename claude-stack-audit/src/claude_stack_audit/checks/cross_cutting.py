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

_SECRET_PATTERNS = (
    ("openai_key", re.compile(r"sk-[A-Za-z0-9]{20,}")),
    ("github_pat", re.compile(r"ghp_[A-Za-z0-9]{30,}")),
    ("github_server", re.compile(r"ghs_[A-Za-z0-9]{30,}")),
    ("bearer", re.compile(r"Bearer\s+[A-Za-z0-9._-]{20,}")),
    ("slack_bot", re.compile(r"xoxb-[A-Za-z0-9-]+")),
)

_SKIP_PATH_HINTS = ("example", "template", ".sample")


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


@register
class SecretsGrep:
    id = "CROSS003"
    name = "secrets grep"
    criterion = Criterion.CROSS_CUTTING
    layer = Layer.CORE

    def run(self, ctx: Context) -> Iterable[Finding]:
        for path in sorted(ctx.claude_root.rglob("*")):
            if not path.is_file():
                continue
            rel = str(path.relative_to(ctx.claude_root))
            if any(hint in rel for hint in _SKIP_PATH_HINTS):
                continue
            try:
                body = ctx.file_cache.read(path)
            except (OSError, UnicodeDecodeError):
                continue
            for label, pattern in _SECRET_PATTERNS:
                if pattern.search(body):
                    yield Finding(
                        check_id=self.id,
                        severity=Severity.HIGH,
                        layer=self.layer,
                        criterion=self.criterion,
                        artifact=str(path.relative_to(ctx.claude_root.parent)),
                        message=f"possible {label} in tracked file",
                        details=None,
                        fix_hint=(
                            "Rotate the leaked credential immediately. Move "
                            "secrets to env vars or a secret manager."
                        ),
                    )


@register
class GitCleanStatus:
    id = "CROSS004"
    name = "git status clean in claude/"
    criterion = Criterion.CROSS_CUTTING
    layer = Layer.CORE

    def run(self, ctx: Context) -> Iterable[Finding]:
        result = ctx.external.run(
            [
                "git",
                "-C",
                str(ctx.dotfiles_root),
                "status",
                "--porcelain",
                "--",
                str(ctx.claude_root),
            ],
            timeout=5.0,
        )
        if result.returncode != 0:
            return
        for line in result.stdout.splitlines():
            line = line.strip()
            if not line:
                continue
            # Format: "XY path" where XY is 2-char status code
            parts = line.split(maxsplit=1)
            if len(parts) != 2:
                continue
            status, path = parts
            yield Finding(
                check_id=self.id,
                severity=Severity.INFO,
                layer=self.layer,
                criterion=self.criterion,
                artifact=path,
                message=f"uncommitted change ({status}): {path}",
                details=None,
                fix_hint="Commit or stash the change to keep the dotfiles tree clean.",
            )
