import json as _json
from pathlib import Path

from claude_stack_audit.checks.cross_cutting import (
    BashPermissionScope,
    SecretsGrep,
    SymlinkIntegrity,
)
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


def test_CROSS002_passes_when_permissions_are_narrow(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    settings_path = fake_dotfiles / "claude" / "settings.json"
    data = _json.loads(settings_path.read_text())
    data["permissions"] = {"allow": ["Bash(npm:*)", "Read"], "deny": []}
    settings_path.write_text(_json.dumps(data))
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    assert list(BashPermissionScope().run(ctx)) == []


def test_CROSS002_flags_broad_bash_wildcard(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    settings_path = fake_dotfiles / "claude" / "settings.json"
    data = _json.loads(settings_path.read_text())
    data["permissions"] = {"allow": ["Bash(bash:*)", "Bash(*)"], "deny": []}
    settings_path.write_text(_json.dumps(data))
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(BashPermissionScope().run(ctx))
    assert len(findings) == 2
    assert all(f.severity == Severity.MEDIUM for f in findings)
    assert all(f.check_id == "CROSS002" for f in findings)


def test_CROSS003_flags_leaked_openai_key(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    bad = fake_dotfiles / "claude" / "hooks" / "leaky.sh"
    bad.write_text(
        '#!/bin/bash\nset -euo pipefail\nexport KEY="sk-abcdefghijklmnopqrstuvwxyz123456"\n'
    )
    bad.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(SecretsGrep().run(ctx))
    flagged = [f for f in findings if "leaky.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.HIGH
    assert "openai" in flagged[0].message.lower()


def test_CROSS003_skips_example_paths(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    example = fake_dotfiles / "claude" / "env.example.sh"
    example.write_text('export KEY="sk-abcdefghijklmnopqrstuvwxyz123456"\n')
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(SecretsGrep().run(ctx))
    flagged = [f for f in findings if "env.example.sh" in f.artifact]
    assert flagged == []


def test_CROSS003_silent_on_clean_tree(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(SecretsGrep().run(ctx))
    assert findings == []
