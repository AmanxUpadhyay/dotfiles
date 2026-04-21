import inspect
import json
from pathlib import Path

from claude_stack_audit.context import Context, FileCache


def _resolve_encoding(original, path_instance, args, kwargs):
    """Normalize positional + keyword args into the effective encoding requested.

    Path.read_text signature: read_text(encoding=None, errors=None, newline=None).
    Without binding, positional calls like read_text("utf-8") slip past spies
    that only inspect kwargs — they'd see encoding as None and falsely pass.
    """
    sig = inspect.signature(original)
    bound = sig.bind_partial(path_instance, *args, **kwargs)
    return bound.arguments.get("encoding")


def _make_spy(original, captured: list):
    def spy(self, *args, **kwargs):
        captured.append(_resolve_encoding(original, self, args, kwargs))
        return original(self, *args, **kwargs)

    return spy


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

    encodings: list = []
    original = Path.read_text
    monkeypatch.setattr(Path, "read_text", _make_spy(original, encodings))

    cache = FileCache()
    result = cache.read(target)

    assert encodings == ["utf-8"]
    assert result == content


def test_load_settings_reads_with_explicit_utf8(
    fake_dotfiles: Path, fake_external_tools, monkeypatch
):
    settings_path = fake_dotfiles / "claude" / "settings.json"
    settings_path.write_text(
        json.dumps(
            {
                "hooks": {"Stop": [{"matcher": "—", "hooks": []}]},
                "permissions": {"allow": ["Read"], "deny": []},
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )

    encodings: list = []
    original = Path.read_text
    monkeypatch.setattr(Path, "read_text", _make_spy(original, encodings))

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)

    assert "Stop" in ctx.settings.hook_events
    assert ctx.settings.hook_events["Stop"][0]["matcher"] == "—"
    assert all(e == "utf-8" for e in encodings), f"non-utf8 read_text calls: {encodings}"


def test_parse_env_sh_reads_with_explicit_utf8(
    fake_dotfiles: Path, fake_external_tools, monkeypatch
):
    env = fake_dotfiles / "claude" / "env.sh"
    env.write_text(
        '#!/bin/bash\n# comment with unicode: — é ñ 中文\nexport GREETING="héllo wörld"\n',
        encoding="utf-8",
    )

    encodings: list = []
    original = Path.read_text
    monkeypatch.setattr(Path, "read_text", _make_spy(original, encodings))

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)

    assert ctx.env_vars["GREETING"] == "héllo wörld"
    assert all(e == "utf-8" for e in encodings), f"non-utf8 read_text calls: {encodings}"


def test_load_org_map_reads_with_explicit_utf8(
    fake_dotfiles: Path, fake_external_tools, monkeypatch
):
    org_map = fake_dotfiles / "claude" / "org-map.json"
    org_map.write_text(
        json.dumps(
            {
                "default_org": "Persönal",
                "orgs": {"Persönal": {"wikilink": "[[Persönal]]", "vault_folder": "Persönal"}},
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )

    encodings: list = []
    original = Path.read_text
    monkeypatch.setattr(Path, "read_text", _make_spy(original, encodings))

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)

    assert ctx.org_map.default_org == "Persönal"
    assert all(e == "utf-8" for e in encodings), f"non-utf8 read_text calls: {encodings}"


def test_parse_crontab_reads_with_explicit_utf8(
    fake_dotfiles: Path, fake_external_tools, monkeypatch
):
    crontab = fake_dotfiles / "claude" / "crontab.txt"
    crontab.write_text(
        "# cron with non-ascii comment: — é ñ 中文\n"
        "30 7 * * * /bin/bash $HOME/.dotfiles/claude/crons/daily-retrospective.sh\n",
        encoding="utf-8",
    )

    encodings: list = []
    original = Path.read_text
    monkeypatch.setattr(Path, "read_text", _make_spy(original, encodings))

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)

    assert len(ctx.crontab) == 1
    assert ctx.crontab[0].script.endswith("daily-retrospective.sh")
    assert all(e == "utf-8" for e in encodings), f"non-utf8 read_text calls: {encodings}"


def test_spy_helper_catches_positional_encoding_arg():
    """Harness self-test: positional encoding args must be resolved by the spy.

    Regression guard: a naive spy that only reads kwargs would miss
    read_text("utf-8") and silently let the assertion pass with encoding=None.
    """
    original = Path.read_text
    assert _resolve_encoding(original, Path("/tmp/x"), ("utf-8",), {}) == "utf-8"
    assert _resolve_encoding(original, Path("/tmp/x"), (), {"encoding": "utf-8"}) == "utf-8"
    assert _resolve_encoding(original, Path("/tmp/x"), (), {}) is None


def test_spy_helper_detects_locale_default_call(tmp_path: Path, monkeypatch):
    """Harness self-test via a stub that calls read_text() with no encoding.

    Verifies the spy records None for a truly locale-dependent call, so a
    genuine regression in context.py would be caught.
    """
    target = tmp_path / "plain.txt"
    target.write_text("hello", encoding="utf-8")

    encodings: list = []
    original = Path.read_text
    monkeypatch.setattr(Path, "read_text", _make_spy(original, encodings))

    target.read_text()

    assert encodings == [None]
