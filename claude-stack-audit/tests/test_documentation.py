from pathlib import Path

from claude_stack_audit.checks.documentation import (
    AdrCoverage,
    ClaudeReadmePresent,
    CrontabCommentsPresent,
    EnvVarCommented,
    HookSettingsDocumented,
    RunbookPresent,
    ScriptHeaderPresent,
)
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


def test_DOC002_passes_when_export_has_comment(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    env = fake_dotfiles / "claude" / "env.sh"
    env.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        "# purpose: where the Obsidian vault lives\n"
        'export OBSIDIAN_VAULT="$HOME/vault"\n'
    )
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(EnvVarCommented().run(ctx))
    assert findings == []


def test_DOC002_flags_export_without_comment(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    env = fake_dotfiles / "claude" / "env.sh"
    env.write_text('#!/bin/bash\nset -euo pipefail\nexport CLAUDE_LOG_DIR="/tmp/logs"\n')
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(EnvVarCommented().run(ctx))
    assert len(findings) == 1
    assert findings[0].severity == Severity.MEDIUM
    assert "CLAUDE_LOG_DIR" in findings[0].message


def test_DOC003_passes_when_readme_exists(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    (fake_dotfiles / "claude" / "README.md").write_text("# claude setup\n")
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ClaudeReadmePresent().run(ctx))
    assert findings == []


def test_DOC003_flags_missing_readme(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    # Fixture doesn't create README.md
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ClaudeReadmePresent().run(ctx))
    assert len(findings) == 1
    assert findings[0].severity == Severity.HIGH


def test_DOC004_passes_when_adr_exists(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    adr_dir = fake_dotfiles / "docs" / "superpowers" / "adr"
    adr_dir.mkdir(parents=True)
    (adr_dir / "2026-04-17-first.md").write_text("# ADR-0001\n")
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(AdrCoverage().run(ctx))
    assert findings == []


def test_DOC004_flags_when_no_adrs(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    # Fixture has no docs/superpowers/adr by default
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(AdrCoverage().run(ctx))
    assert len(findings) == 1
    assert findings[0].severity == Severity.MEDIUM
    assert findings[0].check_id == "DOC004"


def test_DOC005_passes_when_runbook_exists(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    cron = fake_dotfiles / "claude" / "crons" / "my-cron.sh"
    cron.write_text("#!/bin/bash\nset -euo pipefail\necho hi\n")
    cron.chmod(0o755)
    runbooks = fake_dotfiles / "docs" / "superpowers" / "runbooks"
    runbooks.mkdir(parents=True)
    (runbooks / "my-cron.md").write_text("# my-cron runbook\n")
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(RunbookPresent().run(ctx))
    flagged = [f for f in findings if "my-cron.sh" in f.artifact]
    assert flagged == []


def test_DOC005_flags_cron_without_runbook(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    cron = fake_dotfiles / "claude" / "crons" / "unfdocumented-cron.sh"
    cron.write_text("#!/bin/bash\nset -euo pipefail\necho hi\n")
    cron.chmod(0o755)
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(RunbookPresent().run(ctx))
    flagged = [f for f in findings if "unfdocumented-cron.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.HIGH


def test_DOC006_passes_when_entry_has_comment(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    # Fixture crontab.txt already has a `# daily retrospective` comment above its entry
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(CrontabCommentsPresent().run(ctx))
    assert findings == []


def test_DOC006_flags_entry_without_comment(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    crontab = fake_dotfiles / "claude" / "crontab.txt"
    crontab.write_text("0 9 * * * /bin/bash $HOME/.dotfiles/claude/crons/morning.sh\n")
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(CrontabCommentsPresent().run(ctx))
    assert len(findings) == 1
    assert findings[0].severity == Severity.MEDIUM


def test_DOC007_passes_when_doc_exists(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    doc = fake_dotfiles / "docs" / "settings.hooks.md"
    doc.parent.mkdir(parents=True, exist_ok=True)
    doc.write_text("# hook documentation\n")
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(HookSettingsDocumented().run(ctx))
    assert findings == []


def test_DOC007_flags_when_no_doc(  # noqa: N802
    empty_registry, fake_dotfiles, fake_external_tools
):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(HookSettingsDocumented().run(ctx))
    assert len(findings) == 1
    assert findings[0].severity == Severity.MEDIUM
