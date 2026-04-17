"""Shared pytest fixtures: synthetic dotfiles trees + fake external tools."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

import pytest

from claude_stack_audit.external import ToolResult


@dataclass
class FakeShellcheck:
    """Registers canned ToolResults per script path."""

    _results: dict[str, ToolResult] = field(default_factory=dict)

    def register(self, path: str, result: ToolResult) -> None:
        self._results[path] = result

    def __call__(self, path: str | Path) -> ToolResult:
        key = str(path)
        if key in self._results:
            return self._results[key]
        p = Path(path)
        for k, v in self._results.items():
            if "/" in k:
                if key == k or key.endswith("/" + k):
                    return v
            elif p.name == k:
                return v
        return ToolResult(returncode=0, stdout="[]", stderr="", duration_ms=1, timed_out=False)


@dataclass
class FakeExternalTools:
    shellcheck: FakeShellcheck = field(default_factory=FakeShellcheck)

    def run(self, argv: list[str], **_):  # pragma: no cover - not exercised in unit tests
        return ToolResult(returncode=0, stdout="", stderr="", duration_ms=0, timed_out=False)

    def version(self, argv: list[str]) -> str:
        return "fake"


@pytest.fixture
def fake_external_tools() -> FakeExternalTools:
    return FakeExternalTools()


@pytest.fixture
def fake_dotfiles(tmp_path: Path) -> Path:
    """Build a minimal synthetic dotfiles tree.

    Returns the dotfiles root (equivalent of ~/.dotfiles)."""
    dot = tmp_path / ".dotfiles"
    claude = dot / "claude"
    (claude / "hooks").mkdir(parents=True)
    (claude / "crons").mkdir()
    (claude / "agents").mkdir()
    (claude / "commands").mkdir()
    (claude / "launchagents").mkdir()

    (claude / "settings.json").write_text(
        json.dumps(
            {
                "hooks": {
                    "Stop": [
                        {
                            "matcher": "",
                            "hooks": [{"type": "command", "command": "hooks/session-stop.sh"}],
                        }
                    ],
                    "SessionStart": [
                        {
                            "matcher": "",
                            "hooks": [{"type": "command", "command": "hooks/session-start.sh"}],
                        }
                    ],
                },
                "permissions": {"allow": ["Read"], "deny": []},
                "mcpServers": {
                    "test-stdio-mcp": {"command": "node", "args": ["server.js"]},
                    "test-http-mcp": {"url": "http://localhost:3000"},
                },
            }
        )
    )
    (claude / "env.sh").write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        'export OBSIDIAN_VAULT="$HOME/vault"\n'
        'export CLAUDE_LOG_DIR="$HOME/Library/Logs/claude-crons"\n'
    )
    (claude / "org-map.json").write_text(
        json.dumps(
            {
                "default_org": "Personal",
                "orgs": {"Personal": {"wikilink": "[[Personal]]", "vault_folder": "Personal"}},
            }
        )
    )
    (claude / "crontab.txt").write_text(
        "# daily retrospective\n"
        "30 7 * * * /bin/bash $HOME/.dotfiles/claude/crons/daily-retrospective.sh\n"
    )

    # A well-formed hook script
    good = claude / "hooks" / "session-stop.sh"
    good.write_text(
        "#!/bin/bash\n"
        "# purpose: handle session stop\n"
        "# inputs: JSON on stdin\n"
        "# outputs: writes session note\n"
        "# side-effects: filesystem writes to vault\n"
        "set -euo pipefail\n"
        'echo hi >> "$HOME/Library/Logs/claude-crons/session-stop.log"\n'
    )
    good.chmod(0o755)

    start = claude / "hooks" / "session-start.sh"
    start.write_text("#!/bin/bash\nset -euo pipefail\necho start\n")
    start.chmod(0o755)

    (claude / "agents" / "reviewer.md").write_text(
        "---\nname: reviewer\n---\n\nReview code quality.\n"
    )
    (claude / "commands" / "audit.md").write_text("---\nname: audit\n---\n\nRun the audit tool.\n")

    (claude / "launchagents" / "com.test.audit.plist").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        '<plist version="1.0">\n'
        "<dict>\n"
        "  <key>Label</key>\n"
        "  <string>com.test.audit</string>\n"
        "  <key>ProgramArguments</key>\n"
        "  <array><string>/bin/echo</string><string>hi</string></array>\n"
        "</dict>\n"
        "</plist>\n"
    )

    return dot


@pytest.fixture
def empty_registry():
    """Clear the check registry for a test, then restore it via module reload.

    Without restore, a test that clears the registry would pollute every
    subsequent test in the same pytest session, because checks register
    only at import time.
    """
    import importlib

    from claude_stack_audit import checks as _checks
    from claude_stack_audit.checks.base import clear_registry_for_tests

    clear_registry_for_tests()
    try:
        yield
    finally:
        importlib.reload(_checks)
