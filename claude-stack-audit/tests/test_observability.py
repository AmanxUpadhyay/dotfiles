from pathlib import Path

from claude_stack_audit.checks.observability import (
    LogPathConsistency,
    StdoutCaptureWithTimestamp,
)
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


def test_OBS002_passes_when_script_uses_date(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "timestamped.sh"
    script.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        'echo "$(date -u +%FT%TZ) running" >> log\n'
        "$CLAUDE_BIN --help\n"
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(StdoutCaptureWithTimestamp().run(ctx))
    flagged = [f for f in findings if "timestamped.sh" in f.artifact]
    assert flagged == []


def test_OBS002_flags_claude_call_without_timestamp(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "no-timestamp.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\n$CLAUDE_BIN --help\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(StdoutCaptureWithTimestamp().run(ctx))
    flagged = [f for f in findings if "no-timestamp.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.MEDIUM
