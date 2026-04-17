from pathlib import Path

from claude_stack_audit.checks.inventory import (
    AgentCommandInventory,
    CronInventory,
    HookInventory,
    LaunchAgentInventory,
    McpServerInventory,
    PluginInventory,
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


def test_INV005_enumerates_mcp_servers_with_transport(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(McpServerInventory().run(ctx))
    # fixture has two mcp servers
    assert len(findings) == 2
    names = {f.artifact for f in findings}
    assert names == {"mcp:test-stdio-mcp", "mcp:test-http-mcp"}
    by_name = {f.artifact: f for f in findings}
    assert "stdio" in by_name["mcp:test-stdio-mcp"].message
    assert "http" in by_name["mcp:test-http-mcp"].message


def test_INV005_no_findings_when_no_mcp_section(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    import json as _json

    settings_path = fake_dotfiles / "claude" / "settings.json"
    data = _json.loads(settings_path.read_text())
    data.pop("mcpServers", None)
    settings_path.write_text(_json.dumps(data))
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    assert list(McpServerInventory().run(ctx)) == []


def test_INV005_transport_fallback_and_non_dict_guard(  # noqa: N802
    empty_registry, fake_dotfiles: Path, fake_external_tools
):
    import json as _json

    settings_path = fake_dotfiles / "claude" / "settings.json"
    data = _json.loads(settings_path.read_text())
    # unknown transport: dict with neither command nor url
    # non-dict spec: a string
    data["mcpServers"] = {
        "no-transport": {},
        "string-spec": "bad",
    }
    settings_path.write_text(_json.dumps(data))
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(McpServerInventory().run(ctx))
    assert len(findings) == 2
    by_name = {f.artifact: f for f in findings}
    assert "unknown" in by_name["mcp:no-transport"].message
    assert "unknown" in by_name["mcp:string-spec"].message


def test_INV006_enumerates_plugin_directories_with_versions(  # noqa: N802
    empty_registry, tmp_path: Path, fake_dotfiles: Path, fake_external_tools
):
    plugins = tmp_path / "plugins"
    plugins.mkdir()
    (plugins / "alpha").mkdir()
    (plugins / "alpha" / "package.json").write_text('{"version": "1.0.0"}')
    (plugins / "beta").mkdir()
    (plugins / "gamma").mkdir()
    (plugins / "gamma" / "plugin.json").write_text('{"version": "0.2.3"}')
    (plugins / "ignored.txt").write_text("not a plugin")

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(PluginInventory(plugins_root=plugins).run(ctx))

    names = {f.artifact for f in findings}
    assert names == {"plugin:alpha", "plugin:beta", "plugin:gamma"}
    by_name = {f.artifact: f for f in findings}
    assert "1.0.0" in by_name["plugin:alpha"].message
    assert "0.2.3" in by_name["plugin:gamma"].message
    assert by_name["plugin:beta"].message == "beta"


def test_INV006_no_findings_when_plugins_root_missing(  # noqa: N802
    empty_registry, tmp_path: Path, fake_dotfiles: Path, fake_external_tools
):
    nonexistent = tmp_path / "nonexistent_plugins_root"
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    assert list(PluginInventory(plugins_root=nonexistent).run(ctx)) == []


def test_INV006_handles_malformed_manifest_gracefully(  # noqa: N802
    empty_registry, tmp_path: Path, fake_dotfiles: Path, fake_external_tools
):
    plugins = tmp_path / "plugins"
    plugins.mkdir()
    (plugins / "broken").mkdir()
    (plugins / "broken" / "package.json").write_text("{ not valid json")

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(PluginInventory(plugins_root=plugins).run(ctx))
    assert len(findings) == 1
    assert findings[0].artifact == "plugin:broken"
    assert findings[0].message == "broken"
