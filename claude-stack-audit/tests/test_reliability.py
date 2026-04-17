import json
from pathlib import Path

from claude_stack_audit.checks.reliability import ShellcheckClean
from claude_stack_audit.context import Context
from claude_stack_audit.external import ToolResult
from claude_stack_audit.models import Severity


def test_REL001_no_findings_when_scripts_clean(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    fake_external_tools.shellcheck.register(
        "session-stop.sh",
        ToolResult(returncode=0, stdout="[]", stderr="", duration_ms=5, timed_out=False),
    )
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ShellcheckClean().run(ctx))
    # fixture has 2 scripts; both default-clean via fake
    assert findings == []


def test_REL001_emits_high_for_errors_medium_for_warnings(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    payload = json.dumps(
        [
            {
                "file": "session-stop.sh",
                "level": "error",
                "line": 2,
                "column": 1,
                "code": 1000,
                "message": "bad",
            },
            {
                "file": "session-stop.sh",
                "level": "warning",
                "line": 4,
                "column": 1,
                "code": 2000,
                "message": "meh",
            },
        ]
    )
    fake_external_tools.shellcheck.register(
        "session-stop.sh",
        ToolResult(returncode=1, stdout=payload, stderr="", duration_ms=5, timed_out=False),
    )
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ShellcheckClean().run(ctx))

    flagged = [f for f in findings if "session-stop.sh" in f.artifact]
    severities = {f.severity for f in flagged}
    assert Severity.HIGH in severities
    assert Severity.MEDIUM in severities
