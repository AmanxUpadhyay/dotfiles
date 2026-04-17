import json
from pathlib import Path

from claude_stack_audit.checks.reliability import ErrOrExitTrap, SetEuoPipefail, ShellcheckClean
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


def test_REL002_passes_for_scripts_with_set_euo_pipefail(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    # fixture scripts (session-stop.sh, session-start.sh) all have set -euo pipefail
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(SetEuoPipefail().run(ctx))
    # No findings for fixture scripts
    for f in findings:
        assert "session-stop.sh" not in f.artifact
        assert "session-start.sh" not in f.artifact


def test_REL002_flags_script_without_set_euo_pipefail(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    bare = fake_dotfiles / "claude" / "hooks" / "no-euo.sh"
    bare.write_text("#!/bin/bash\necho hello world\n")
    bare.chmod(0o755)

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(SetEuoPipefail().run(ctx))
    flagged = [f for f in findings if "no-euo.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.HIGH


def test_REL003_passes_for_cron_with_trap(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ErrOrExitTrap().run(ctx))
    # with-trap.sh in fixture has `trap 'echo oops' ERR` → not flagged
    flagged = [f for f in findings if "with-trap.sh" in f.artifact]
    assert flagged == []


def test_REL003_flags_cron_without_trap(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ErrOrExitTrap().run(ctx))
    flagged = [f for f in findings if "no-trap.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.MEDIUM
