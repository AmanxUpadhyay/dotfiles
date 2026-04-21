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


def test_OBS001_skips_note_path_variable_name(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """Variable name NOTE_PATH signals product output, not a log."""
    script = fake_dotfiles / "claude" / "crons" / "note-writer.sh"
    script.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        'NOTE_PATH="$OBSIDIAN_VAULT/00-Inbox/2026-04-21-report.md"\n'
        'echo "hello" > "$NOTE_PATH"\n'
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "note-writer.sh" in f.artifact]
    assert flagged == [], f"expected no findings but got: {flagged}"


def test_OBS001_skips_note_path_variable_lowercase(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """Variable-name match is case-insensitive."""
    script = fake_dotfiles / "claude" / "crons" / "lower-note.sh"
    script.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        'local note_path="/Users/me/vault/inbox/x.md"\n'
        'cat >> "$note_path" <<EOF\nhi\nEOF\n'
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "lower-note.sh" in f.artifact]
    assert flagged == [], f"expected no findings but got: {flagged}"


def test_OBS001_skips_breadcrumb_variable_name(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """BREADCRUMB_DIR is product output."""
    script = fake_dotfiles / "claude" / "hooks" / "bc-writer.sh"
    script.parent.mkdir(parents=True, exist_ok=True)
    script.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        'BREADCRUMB_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.claude"\n'
        'cat > "$BREADCRUMB_DIR/breadcrumbs.md" <<EOF\n'
        "x\nEOF\n"
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "bc-writer.sh" in f.artifact]
    assert flagged == [], f"expected no findings but got: {flagged}"


def test_OBS001_skips_md_extension(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """Literal .md path is product output even under /tmp."""
    script = fake_dotfiles / "claude" / "crons" / "md-writer.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\necho hi > /tmp/report.md\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "md-writer.sh" in f.artifact]
    assert flagged == [], f"expected no findings but got: {flagged}"


def test_OBS001_skips_html_extension(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """Literal .html path is product output."""
    script = fake_dotfiles / "claude" / "crons" / "html-writer.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\necho hi > /tmp/index.html\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "html-writer.sh" in f.artifact]
    assert flagged == [], f"expected no findings but got: {flagged}"


def test_OBS001_skips_obsidian_vault_prefix(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """Writes rooted under $OBSIDIAN_VAULT are product output."""
    script = fake_dotfiles / "claude" / "crons" / "vault-writer.sh"
    script.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        'OUTPUT="$OBSIDIAN_VAULT/02-Projects/status.txt"\n'
        'echo x > "$OUTPUT"\n'
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "vault-writer.sh" in f.artifact]
    assert flagged == [], f"expected no findings but got: {flagged}"


def test_OBS001_escape_hatch_same_line(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """# audit-ignore: OBS001 on the redirect line suppresses the finding."""
    script = fake_dotfiles / "claude" / "crons" / "escaped-inline.sh"
    script.write_text(
        "#!/bin/bash\nset -euo pipefail\n"
        'echo x >> "$logfile"  # audit-ignore: OBS001 — caller-provided runtime log\n'
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "escaped-inline.sh" in f.artifact]
    assert flagged == [], f"expected no findings but got: {flagged}"


def test_OBS001_escape_hatch_preceding_line(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """# audit-ignore: OBS001 on the immediately preceding line also suppresses."""
    script = fake_dotfiles / "claude" / "crons" / "escaped-prev.sh"
    script.write_text(
        "#!/bin/bash\nset -euo pipefail\n"
        "# audit-ignore: OBS001 — runtime path from caller\n"
        'echo x >> "$logfile"\n'
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "escaped-prev.sh" in f.artifact]
    assert flagged == [], f"expected no findings but got: {flagged}"


def test_OBS001_escape_hatch_three_lines_back_ok_four_not(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """Lookback window is 3 lines. 3 back skips; 4 back does not."""
    # 3 lines back — should skip
    script3 = fake_dotfiles / "claude" / "crons" / "escape-3-back.sh"
    script3.write_text(
        "#!/bin/bash\nset -euo pipefail\n"
        "# audit-ignore: OBS001 — caller passes this\n"
        "echo a\n"
        "echo b\n"
        'echo x >> "$logfile"\n'
    )
    script3.chmod(0o755)
    # 4 lines back — should still flag
    script4 = fake_dotfiles / "claude" / "crons" / "escape-4-back.sh"
    script4.write_text(
        "#!/bin/bash\nset -euo pipefail\n"
        "# audit-ignore: OBS001 — too far away\n"
        "echo a\n"
        "echo b\n"
        "echo c\n"
        "echo x >> /tmp/late.log\n"
    )
    script4.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged3 = [f for f in findings if "escape-3-back.sh" in f.artifact]
    flagged4 = [f for f in findings if "escape-4-back.sh" in f.artifact]
    assert flagged3 == [], f"3-back should skip, got: {flagged3}"
    assert len(flagged4) >= 1, f"4-back should flag, got: {flagged4}"


def test_OBS001_escape_hatch_multiple_ids(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """Multiple comma-separated IDs are honoured."""
    script = fake_dotfiles / "claude" / "crons" / "multi-id.sh"
    script.write_text(
        "#!/bin/bash\nset -euo pipefail\n"
        "echo x >> /tmp/multi.log  # audit-ignore: OBS001, OBS002 — both apply\n"
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "multi-id.sh" in f.artifact]
    assert flagged == [], f"expected no findings but got: {flagged}"


def test_OBS001_escape_hatch_wrong_id_still_flags(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """# audit-ignore: OBS002 does not suppress OBS001."""
    script = fake_dotfiles / "claude" / "crons" / "wrong-id.sh"
    script.write_text(
        "#!/bin/bash\nset -euo pipefail\n"
        "echo x >> /tmp/wrong.log  # audit-ignore: OBS002 — not the right id\n"
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "wrong-id.sh" in f.artifact]
    assert len(flagged) >= 1, "OBS002 suppression must not hide OBS001"


def test_OBS001_log_variable_still_flags_to_tmp(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """LOG/LOGFILE are intentionally NOT in the skip list. Real log to /tmp stays flagged."""
    script = fake_dotfiles / "claude" / "crons" / "real-log.sh"
    script.write_text(
        '#!/bin/bash\nset -euo pipefail\nLOGFILE="/tmp/real.log"\necho x >> "$LOGFILE"\n'
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "real-log.sh" in f.artifact]
    assert len(flagged) >= 1, f"LOG variable must stay flagged, got: {flagged}"
    assert all(f.severity == Severity.HIGH for f in flagged)


def test_OBS001_log_extension_still_flags_under_tmp(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """Literal .log extension under /tmp must still flag HIGH."""
    script = fake_dotfiles / "claude" / "crons" / "tmp-log.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\necho x >> /tmp/app.log\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    flagged = [f for f in findings if "tmp-log.sh" in f.artifact]
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
