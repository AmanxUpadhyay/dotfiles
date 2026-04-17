from pathlib import Path

from claude_stack_audit.checks.inventory import (
    AgentCommandInventory,
    CronInventory,
    HookInventory,
    LaunchAgentInventory,
)
from claude_stack_audit.context import Context
from claude_stack_audit.external import ToolResult


def test_INV001_enumerates_hooks_from_settings(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(HookInventory().run(ctx))

    events = {f.artifact for f in findings}
    assert "hooks/session-stop.sh" in events or any("session-stop.sh" in e for e in events)

    assert all(f.severity.value == "info" for f in findings)
    assert all(f.check_id == "INV001" for f in findings)


def test_INV001_emits_finding_per_hook_entry(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(HookInventory().run(ctx))
    # fixture has Stop + SessionStart = 2 hook entries
    assert len(findings) == 2


def test_INV002_enumerates_crontab_entries(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(CronInventory().run(ctx))
    # fixture has 1 crontab entry (daily-retrospective.sh)
    assert len(findings) == 1
    assert findings[0].check_id == "INV002"
    assert findings[0].severity.value == "info"
    assert "daily-retrospective" in findings[0].artifact


def test_INV002_no_findings_when_crontab_empty(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    (fake_dotfiles / "claude" / "crontab.txt").unlink()
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(CronInventory().run(ctx))
    assert findings == []


def test_INV003_enumerates_plist_files(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LaunchAgentInventory().run(ctx))
    assert len(findings) == 1
    assert findings[0].check_id == "INV003"
    assert "com.test.audit" in findings[0].message
    # FakeExternalTools.run returns rc=0 stdout='' — no labels, so "unloaded"
    assert "unloaded" in findings[0].message


def test_INV003_marks_loaded_when_launchctl_reports_label(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    # Patch FakeExternalTools.run for launchctl
    original_run = fake_external_tools.run

    def patched_run(argv, **kwargs):
        if argv and argv[0] == "launchctl":
            return ToolResult(
                returncode=0,
                stdout="PID\tStatus\tLabel\n-\t0\tcom.test.audit\n",
                stderr="",
                duration_ms=1,
                timed_out=False,
            )
        return original_run(argv, **kwargs)

    fake_external_tools.run = patched_run  # type: ignore[method-assign]

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LaunchAgentInventory().run(ctx))
    assert len(findings) == 1
    assert "loaded" in findings[0].message
    assert "unloaded" not in findings[0].message


def test_INV004_enumerates_agents_and_commands(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(AgentCommandInventory().run(ctx))
    # fixture has reviewer.md + audit.md
    assert len(findings) == 2
    kinds = {f.message.split()[0] for f in findings}
    assert kinds == {"agent", "command"}
    names = {f.message.split()[1] for f in findings}
    assert names == {"reviewer", "audit"}


def test_INV004_emits_nothing_when_dirs_empty(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    (fake_dotfiles / "claude" / "agents" / "reviewer.md").unlink()
    (fake_dotfiles / "claude" / "commands" / "audit.md").unlink()
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    assert list(AgentCommandInventory().run(ctx)) == []
