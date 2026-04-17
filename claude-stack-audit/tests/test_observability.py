from pathlib import Path

from claude_stack_audit.checks.observability import LogPathConsistency
from claude_stack_audit.context import Context
from claude_stack_audit.models import Severity


def test_OBS001_no_findings_when_scripts_use_approved_log_dirs(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    # fixture session-stop.sh logs to ~/Library/Logs/claude-crons — approved
    assert findings == []


def test_OBS001_flags_tmp_log_paths(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    bad = fake_dotfiles / "claude" / "crons" / "bad-logger.sh"
    bad.write_text("#!/bin/bash\nset -euo pipefail\necho hi >> /tmp/my.log\n")
    bad.chmod(0o755)

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))

    flagged = [f for f in findings if "bad-logger.sh" in f.artifact]
    assert len(flagged) >= 1
    assert all(f.severity == Severity.HIGH for f in flagged)
    assert all(f.check_id == "OBS001" for f in flagged)
