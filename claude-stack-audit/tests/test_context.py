from pathlib import Path

from claude_stack_audit.context import Context, FileCache


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


def test_context_build_handles_malformed_settings_json(fake_dotfiles: Path, fake_external_tools):
    (fake_dotfiles / "claude" / "settings.json").write_text("{ not valid json")
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    assert ctx.settings.raw == {}
    assert ctx.settings.hook_events == {}
    assert ctx.settings.permissions == {}


def test_context_build_handles_non_dict_settings_json(fake_dotfiles: Path, fake_external_tools):
    (fake_dotfiles / "claude" / "settings.json").write_text("[1, 2, 3]")
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    assert ctx.settings.raw == {}
    assert ctx.settings.hook_events == {}


def test_context_build_handles_empty_env_sh(fake_dotfiles: Path, fake_external_tools):
    (fake_dotfiles / "claude" / "env.sh").write_text("")
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    assert ctx.env_vars == {}


def test_parse_env_sh_accepts_empty_export_value(fake_dotfiles: Path, fake_external_tools):
    env = fake_dotfiles / "claude" / "env.sh"
    env.write_text("#!/bin/bash\nexport EMPTY_VAR=\nexport NONEMPTY=hello\n")
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    assert ctx.env_vars.get("EMPTY_VAR") == ""
    assert ctx.env_vars.get("NONEMPTY") == "hello"


def test_file_cache_reads_with_explicit_utf8_encoding(tmp_path: Path, monkeypatch):
    # Without encoding="utf-8", Python falls back to locale.getpreferredencoding();
    # on CI Linux with LANG=C this is ASCII and crashes on non-ASCII script content.
    target = tmp_path / "unicode.sh"
    content = "#!/bin/bash\necho '— é ñ 中文'\n"
    target.write_text(content, encoding="utf-8")

    captured_kwargs: list[dict] = []
    original = Path.read_text

    def spy(self, *args, **kwargs):
        captured_kwargs.append(kwargs)
        return original(self, *args, **kwargs)

    monkeypatch.setattr(Path, "read_text", spy)
    cache = FileCache()
    result = cache.read(target)

    assert captured_kwargs, "read_text was not called"
    assert captured_kwargs[0].get("encoding") == "utf-8"
    assert result == content
