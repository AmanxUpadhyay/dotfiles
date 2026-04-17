"""Documentation checks (DOC001–DOC007). Phase 1 ships DOC001 only."""

from __future__ import annotations

import re
from collections.abc import Iterable

from claude_stack_audit.checks.base import register
from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer, Severity

_REQUIRED_FIELDS = ("purpose", "inputs", "outputs", "side-effects")
_HEADER_LINES = 20
_FIELD_RE = re.compile(r"^\s*#\s*(purpose|inputs|outputs|side-?effects)\s*:", re.IGNORECASE)


@register
class ScriptHeaderPresent:
    id = "DOC001"
    name = "script header present"
    criterion = Criterion.DOCUMENTATION
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            body = ctx.file_cache.read(script)
            head = body.splitlines()[:_HEADER_LINES]
            seen = set()
            for line in head:
                m = _FIELD_RE.match(line)
                if m:
                    key = m.group(1).lower().replace("sideeffects", "side-effects")
                    seen.add(key)
            missing = [f for f in _REQUIRED_FIELDS if f not in seen]
            if missing:
                yield Finding(
                    check_id=self.id,
                    severity=Severity.HIGH,
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(script.relative_to(ctx.claude_root.parent)),
                    message=f"script header missing: {', '.join(missing)}",
                    details=None,
                    fix_hint=(
                        "Add a 4-line comment block at the top of the script listing "
                        "purpose, inputs, outputs, and side-effects."
                    ),
                )


@register
class EnvVarCommented:
    id = "DOC002"
    name = "env var has preceding comment"
    criterion = Criterion.DOCUMENTATION
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        env_sh = ctx.claude_root / "env.sh"
        if not env_sh.is_file():
            return
        lines = env_sh.read_text().splitlines()
        for i, line in enumerate(lines):
            stripped = line.strip()
            if not stripped.startswith("export "):
                continue
            # Look up to 3 non-blank lines back for a comment (shebang excluded)
            has_comment = False
            for j in range(max(0, i - 3), i):
                prev = lines[j].strip()
                if prev.startswith("#") and not prev.startswith("#!"):
                    has_comment = True
                    break
            if has_comment:
                continue
            var_match = re.match(r"export\s+([A-Z_][A-Z0-9_]*)", stripped)
            var_name = var_match.group(1) if var_match else "?"
            yield Finding(
                check_id=self.id,
                severity=Severity.MEDIUM,
                layer=self.layer,
                criterion=self.criterion,
                artifact=f"env.sh:{i + 1}",
                message=f"export {var_name} has no preceding comment",
                details=None,
                fix_hint="Add a `# purpose: ...` comment immediately above the export.",
            )


@register
class ClaudeReadmePresent:
    id = "DOC003"
    name = "claude/ has README"
    criterion = Criterion.DOCUMENTATION
    layer = Layer.CORE

    def run(self, ctx: Context) -> Iterable[Finding]:
        readme = ctx.claude_root / "README.md"
        if readme.is_file():
            return
        yield Finding(
            check_id=self.id,
            severity=Severity.HIGH,
            layer=self.layer,
            criterion=self.criterion,
            artifact=str(readme.relative_to(ctx.claude_root.parent)),
            message="claude/ directory missing README.md",
            details=None,
            fix_hint=(
                "Create claude/README.md documenting install flow, component map, "
                "hooks/crons inventory, and common troubleshooting."
            ),
        )
