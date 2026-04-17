from pathlib import Path

from claude_stack_audit.checks.documentation import ScriptHeaderPresent
from claude_stack_audit.context import Context
from claude_stack_audit.models import Severity


def test_DOC001_passes_when_header_fields_present(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    # fixture session-stop.sh has purpose/inputs/outputs/side-effects header
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ScriptHeaderPresent().run(ctx))
    flagged = [f for f in findings if "session-stop.sh" in f.artifact]
    assert flagged == []


def test_DOC001_flags_script_with_no_header(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    bare = fake_dotfiles / "claude" / "hooks" / "bare.sh"
    bare.write_text("#!/bin/bash\nset -euo pipefail\necho nothing to see\n")
    bare.chmod(0o755)

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ScriptHeaderPresent().run(ctx))
    flagged = [f for f in findings if "bare.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.HIGH
    assert flagged[0].check_id == "DOC001"
