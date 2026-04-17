from pathlib import Path

from claude_stack_audit.checks.inventory import CronInventory, HookInventory
from claude_stack_audit.context import Context


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
