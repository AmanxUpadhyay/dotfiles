from pathlib import Path

from claude_stack_audit.checks.cross_cutting import SymlinkIntegrity
from claude_stack_audit.context import Context
from claude_stack_audit.models import Severity


def _prepare_dotclaude(tmp_path: Path, dotfiles: Path) -> Path:
    """Create a simulated ~/.claude directory with three symlinks."""
    dotclaude = tmp_path / ".claude"
    dotclaude.mkdir()
    (dotclaude / "settings.json").symlink_to(dotfiles / "claude" / "settings.json")
    (dotclaude / "env.sh").symlink_to(dotfiles / "claude" / "env.sh")
    (dotclaude / "org-map.json").symlink_to(dotfiles / "claude" / "org-map.json")
    return dotclaude


def test_CROSS001_passes_when_all_symlinks_valid(  # noqa: N802
    empty_registry, tmp_path: Path, fake_dotfiles: Path, fake_external_tools
):
    dotclaude = _prepare_dotclaude(tmp_path, fake_dotfiles)

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(SymlinkIntegrity(dotclaude_root=dotclaude).run(ctx))
    assert findings == []


def test_CROSS001_emits_critical_for_broken_symlink(  # noqa: N802
    empty_registry, tmp_path: Path, fake_dotfiles: Path, fake_external_tools
):
    dotclaude = _prepare_dotclaude(tmp_path, fake_dotfiles)
    # Break env.sh symlink by deleting the target
    (fake_dotfiles / "claude" / "env.sh").unlink()

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(SymlinkIntegrity(dotclaude_root=dotclaude).run(ctx))
    assert len(findings) == 1
    assert findings[0].severity == Severity.CRITICAL
    assert "env.sh" in findings[0].artifact
    assert findings[0].check_id == "CROSS001"
