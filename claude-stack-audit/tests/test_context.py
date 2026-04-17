from pathlib import Path

from claude_stack_audit.context import Context


def test_context_build_parses_settings_and_env_and_orgmap(fake_dotfiles: Path, fake_external_tools):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)

    assert ctx.claude_root == fake_dotfiles / "claude"
    assert "Stop" in ctx.settings.hook_events
    assert "SessionStart" in ctx.settings.hook_events
    assert ctx.env_vars["OBSIDIAN_VAULT"] == "$HOME/vault"
    assert ctx.org_map.default_org == "Personal"
    assert len(ctx.crontab) == 1
    assert ctx.crontab[0].script.endswith("daily-retrospective.sh")


def test_context_enumerates_bash_scripts(fake_dotfiles: Path, fake_external_tools):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    names = {p.name for p in ctx.bash_scripts}
    assert "session-stop.sh" in names
    assert "session-start.sh" in names


def test_file_cache_reads_once(fake_dotfiles: Path, fake_external_tools):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    script = fake_dotfiles / "claude" / "hooks" / "session-stop.sh"
    first = ctx.file_cache.read(script)
    second = ctx.file_cache.read(script)
    assert first is second  # same cached str object


def test_context_build_survives_missing_crontab(fake_dotfiles: Path, fake_external_tools):
    (fake_dotfiles / "claude" / "crontab.txt").unlink()
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    assert ctx.crontab == []
