from pathlib import Path

from claude_stack_audit.checks.observability import (
    DurationStatusMarkers,
    HookHandlerExists,
    LogPathConsistency,
    LogRotationPolicy,
    NotifyFailureSourced,
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


def test_OBS001_resolves_script_local_var_assignments(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """Real crons write to `$LOGFILE` where LOGFILE is assigned to an
    approved path at the top of the script (e.g. `$CLAUDE_LOG_DIR/<name>.log`).
    The check must resolve the assignment and see that the resolved path is
    approved — otherwise 30+ legitimate log writes get flagged as ad-hoc."""
    good = fake_dotfiles / "claude" / "crons" / "resolved-logger.sh"
    good.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        'LOGFILE="$CLAUDE_LOG_DIR/my-cron.log"\n'
        'echo hi >> "$LOGFILE"\n'
        'echo again >> "$LOGFILE.tmp"\n'
    )
    good.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "resolved-logger.sh" in f.artifact]
    assert flagged == [], f"expected no findings but got: {flagged}"


def test_OBS001_still_flags_var_resolving_to_bad_path(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """If the resolved variable points at /tmp or /var/tmp, still flag it."""
    bad = fake_dotfiles / "claude" / "crons" / "bad-resolved.sh"
    bad.write_text(
        '#!/bin/bash\nset -euo pipefail\nLOGFILE="/tmp/sneaky.log"\necho hi >> "$LOGFILE"\n'
    )
    bad.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "bad-resolved.sh" in f.artifact]
    assert len(flagged) >= 1
    assert all(f.severity == Severity.HIGH for f in flagged)


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


def test_OBS003_passes_when_cron_sources_notify(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "notifies.sh"
    script.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        'source "$HOME/.dotfiles/claude/crons/notify-failure.sh"\n'
        "trap notify_failure ERR\n"
        "echo running\n"
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(NotifyFailureSourced().run(ctx))
    flagged = [f for f in findings if "notifies.sh" in f.artifact]
    assert flagged == []


def test_OBS003_flags_cron_without_notify(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "silent.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\necho running\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(NotifyFailureSourced().run(ctx))
    flagged = [f for f in findings if "silent.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.HIGH


def test_OBS004_passes_when_cron_emits_duration(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "with-metrics.sh"
    script.write_text(
        "#!/bin/bash\nset -euo pipefail\nstart=$(date +%s)\necho duration_ms=100 status=done\n"
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(DurationStatusMarkers().run(ctx))
    flagged = [f for f in findings if "with-metrics.sh" in f.artifact]
    assert flagged == []


def test_OBS004_flags_cron_without_metrics(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "no-metrics.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\necho just running\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(DurationStatusMarkers().run(ctx))
    flagged = [f for f in findings if "no-metrics.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.MEDIUM


def test_OBS005_passes_when_rotation_script_exists(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "rotate-logs.sh"
    script.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        'find "$HOME/Library/Logs/claude-crons" -mtime +30 -delete\n'
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogRotationPolicy().run(ctx))
    assert findings == []


def test_OBS005_flags_when_no_rotation_exists(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    # Fixture has no rotation markers
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogRotationPolicy().run(ctx))
    assert len(findings) == 1
    assert findings[0].severity == Severity.MEDIUM
    assert findings[0].check_id == "OBS005"


def test_OBS006_passes_when_hook_commands_exist(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    # Fixture settings.json points at hooks/session-stop.sh and hooks/session-start.sh,
    # both of which exist.
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(HookHandlerExists().run(ctx))
    assert findings == []


def test_OBS006_flags_missing_hook_handler(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    import json as _json

    settings_path = fake_dotfiles / "claude" / "settings.json"
    data = _json.loads(settings_path.read_text())
    data["hooks"]["Stop"] = [
        {
            "matcher": "",
            "hooks": [{"type": "command", "command": "hooks/does-not-exist.sh"}],
        }
    ]
    settings_path.write_text(_json.dumps(data))

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(HookHandlerExists().run(ctx))
    flagged = [f for f in findings if "does-not-exist.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.HIGH


def test_OBS006_accepts_production_command_format(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools, monkeypatch
):
    """Real Claude Code settings.json wraps the path in a bash command with $HOME, like
    `bash "$HOME/.claude/hooks/X.sh"`. The check must strip the wrapper, expand $HOME,
    and verify the underlying script exists."""
    import json as _json

    fake_home = fake_dotfiles.parent
    monkeypatch.setenv("HOME", str(fake_home))

    dotclaude_hooks = fake_home / ".claude" / "hooks"
    dotclaude_hooks.mkdir(parents=True)
    script = dotclaude_hooks / "session-end-note.sh"
    script.write_text("#!/bin/bash\necho hi\n")
    script.chmod(0o755)

    settings_path = fake_dotfiles / "claude" / "settings.json"
    data = _json.loads(settings_path.read_text())
    data["hooks"]["SessionEnd"] = [
        {
            "matcher": "",
            "hooks": [
                {
                    "type": "command",
                    "command": 'bash "$HOME/.claude/hooks/session-end-note.sh"',
                }
            ],
        }
    ]
    settings_path.write_text(_json.dumps(data))

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(HookHandlerExists().run(ctx))
    flagged = [f for f in findings if "session-end-note.sh" in f.artifact]
    assert flagged == [], f"expected no findings but got: {flagged}"


def test_OBS006_flags_missing_production_command(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools, monkeypatch
):
    import json as _json

    monkeypatch.setenv("HOME", str(fake_dotfiles.parent))

    settings_path = fake_dotfiles / "claude" / "settings.json"
    data = _json.loads(settings_path.read_text())
    data["hooks"]["SessionEnd"] = [
        {
            "matcher": "",
            "hooks": [{"type": "command", "command": 'bash "$HOME/.claude/hooks/nope.sh"'}],
        }
    ]
    settings_path.write_text(_json.dumps(data))

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(HookHandlerExists().run(ctx))
    flagged = [f for f in findings if "nope.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.HIGH
