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
