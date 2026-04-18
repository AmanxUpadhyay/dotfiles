import json
from pathlib import Path

from claude_stack_audit.checks.reliability import (
    ClaudeBinResolved,
    CompanionTestPresent,
    CronHealthcheckMarker,
    CronIdempotencyGuard,
    ErrOrExitTrap,
    JqDefensiveDefaults,
    LongOpTimeout,
    SetEuoPipefail,
    ShellcheckClean,
)
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


def test_REL001_skips_zsh_scripts(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    """shellcheck doesn't support zsh (SC1071) — the check should skip
    zsh-shebanged scripts rather than yield a High finding that the user
    can't fix without rewriting the script in bash."""
    script = fake_dotfiles / "claude" / "refresh.sh"
    script.write_text("#!/bin/zsh\nset -euo pipefail\necho hi\n")
    script.chmod(0o755)
    # If shellcheck WERE called on this, it would return SC1071. Register that
    # so we can assert the check never reaches the shellcheck call.
    fake_external_tools.shellcheck.register(
        "refresh.sh",
        ToolResult(
            returncode=1,
            stdout=json.dumps(
                [
                    {
                        "file": "refresh.sh",
                        "level": "error",
                        "line": 1,
                        "column": 1,
                        "code": 1071,
                        "message": "ShellCheck only supports sh/bash/dash/ksh",
                    }
                ]
            ),
            stderr="",
            duration_ms=5,
            timed_out=False,
        ),
    )
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ShellcheckClean().run(ctx))
    flagged = [f for f in findings if "refresh.sh" in f.artifact]
    assert flagged == [], f"expected zsh script to be skipped, got: {flagged}"


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


def test_REL004_passes_when_script_uses_CLAUDE_BIN(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "uses-env.sh"
    script.write_text(
        "#!/bin/bash\nset -euo pipefail\nsource $HOME/.dotfiles/claude/env.sh\n$CLAUDE_BIN --help\n"
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ClaudeBinResolved().run(ctx))
    flagged = [f for f in findings if "uses-env.sh" in f.artifact]
    assert flagged == []


def test_REL004_flags_hardcoded_npm_path(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "bad-hardcoded.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\n~/.npm-packages/bin/claude --version\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ClaudeBinResolved().run(ctx))
    flagged = [f for f in findings if "bad-hardcoded.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.HIGH
    assert "npm-packages" in flagged[0].details


def test_REL004_does_not_flag_path_prefix_to_dotfiles_claude_dir(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    """`$HOME/.dotfiles/claude/crons/X.sh` is a directory path, not a binary.
    Prior regex incorrectly matched it as a hardcoded claude path."""
    script = fake_dotfiles / "claude" / "crons" / "source-only.sh"
    script.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        'source "$HOME/.dotfiles/claude/crons/notify-failure.sh"\n'
        'echo "$HOME/.dotfiles/claude/settings.json"\n'
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ClaudeBinResolved().run(ctx))
    flagged = [f for f in findings if "source-only.sh" in f.artifact]
    assert flagged == [], f"expected no findings but got: {flagged}"


def test_REL004_does_not_flag_hyphenated_claude_name(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    """`/claude-code/` and `/claude-mem` are hyphenated names, not the claude
    binary. Prior regex matched them because `\\b` fires between 'e' and '-'."""
    script = fake_dotfiles / "claude" / "crons" / "doc-references.sh"
    script.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        "# Docs: docs.anthropic.com/en/docs/claude-code/hooks\n"
        'PLUGIN_ROOT="$HOME/.claude/plugins/cache/thedotmack/claude-mem"\n'
        'echo "check /tmp/claude-mem.log"\n'
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ClaudeBinResolved().run(ctx))
    flagged = [f for f in findings if "doc-references.sh" in f.artifact]
    assert flagged == [], f"expected no findings but got: {flagged}"


def test_REL005_passes_when_cron_has_flock(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "locked-cron.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\nflock -n /tmp/x.lock -c 'echo running'\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(CronIdempotencyGuard().run(ctx))
    flagged = [f for f in findings if "locked-cron.sh" in f.artifact]
    assert flagged == []


def test_REL005_flags_cron_without_guard(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "no-guard.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\necho running unconditionally\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(CronIdempotencyGuard().run(ctx))
    flagged = [f for f in findings if "no-guard.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.MEDIUM


def test_REL006_passes_when_tests_dir_exists(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    # Create a tests directory at the dotfiles root of the fixture
    tests_dir = fake_dotfiles / "tests"
    tests_dir.mkdir()
    (tests_dir / "placeholder.bats").write_text("# placeholder\n")
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(CompanionTestPresent().run(ctx))
    assert findings == []


def test_REL006_flags_missing_tests_dir(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    # Fixture does NOT create ~/.dotfiles/tests — so this should flag
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(CompanionTestPresent().run(ctx))
    assert len(findings) == 1
    assert findings[0].severity == Severity.MEDIUM
    assert findings[0].check_id == "REL006"


def test_REL007_passes_when_cron_writes_marker(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "marked-cron.sh"
    script.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        "echo running\n"
        'touch "$HOME/Library/Logs/claude-crons/.last-success-marked"\n'
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(CronHealthcheckMarker().run(ctx))
    flagged = [f for f in findings if "marked-cron.sh" in f.artifact]
    assert flagged == []


def test_REL007_flags_cron_without_marker(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "unmarked-cron.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\necho running\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(CronHealthcheckMarker().run(ctx))
    flagged = [f for f in findings if "unmarked-cron.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.HIGH


def test_REL007_skips_healthcheck_itself(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "healthcheck.sh"
    script.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        "echo checking\n"  # no last-success write, but this is the healthcheck itself
    )
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(CronHealthcheckMarker().run(ctx))
    flagged = [f for f in findings if "healthcheck.sh" in f.artifact]
    assert flagged == []


def test_REL008_passes_when_timeout_present(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "safe-claude-call.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\ntimeout 120s $CLAUDE_BIN --help\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LongOpTimeout().run(ctx))
    flagged = [f for f in findings if "safe-claude-call.sh" in f.artifact]
    assert flagged == []


def test_REL008_flags_claude_call_without_timeout(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "crons" / "unbounded-claude.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\n$CLAUDE_BIN --help\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LongOpTimeout().run(ctx))
    flagged = [f for f in findings if "unbounded-claude.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.MEDIUM


def test_REL009_passes_when_jq_has_defensive_default(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "hooks" / "safe-jq.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\necho '{}' | jq '.foo // empty'\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(JqDefensiveDefaults().run(ctx))
    flagged = [f for f in findings if "safe-jq.sh" in f.artifact]
    assert flagged == []


def test_REL009_flags_jq_without_default(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    script = fake_dotfiles / "claude" / "hooks" / "unsafe-jq.sh"
    script.write_text("#!/bin/bash\nset -euo pipefail\necho '{}' | jq '.foo'\n")
    script.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(JqDefensiveDefaults().run(ctx))
    flagged = [f for f in findings if "unsafe-jq.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.LOW
