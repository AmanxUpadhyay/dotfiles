# Claude Stack Audit — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a working `cstack-audit` CLI with the full `Context → checks → Report` infrastructure and one end-to-end check per criterion (5 checks total), so `cstack-audit run` on the real dotfiles produces a scored markdown + JSON report.

**Architecture:** Python 3.11+ package managed by `uv`. A Typer-based CLI invokes a `Runner` that builds a `Context` (parsing `settings.json`, `env.sh`, `org-map.json` once), iterates registered `Check` instances, and aggregates `Finding` objects. Two reporters (Markdown for humans, JSON with a versioned schema for machines) consume a `Report` dataclass. Subprocess calls go through a central `ExternalTools` adapter that wraps `subprocess.run` with a timeout and returns `ToolResult` objects — so checks classify failures rather than crash. All checks are pure functions of `Context`, enabling trivial pytest unit tests via injected fakes.

**Tech Stack:** Python 3.11+, `uv` (packaging & tool install), Typer (CLI), pytest + pytest-cov (tests), ruff (lint + format), `shellcheck` + `jq` + `launchctl` (external subprocess tools, Brewfile-managed).

**Scope of this plan (Phase 1 of 5 planned phases):**

| Phase | Contents | Plan status |
|------:|----------|-------------|
| **1** | Scaffolding + core abstractions + reporters + CLI + 5 representative checks (one per criterion) + Brewfile/install updates + baseline audit | **This plan** |
| 2 | Remaining Inventory checks (INV002–INV007) | Future plan |
| 3 | Remaining Reliability checks (REL002–REL009) | Future plan |
| 4 | Remaining Observability + Documentation checks (OBS002–006, DOC002–007) | Future plan |
| 5 | Remaining Cross-cutting (CROSS002–CROSS004) + slash command + pre-commit hook + ADR + runbook | Future plan |

**Out of scope for this plan** (tracked above):
- 28 of the 33 spec'd checks (added incrementally in phases 2–5 once the pipeline is proven).
- `/audit` slash command (phase 5).
- Pre-commit hook (phase 5).
- ADR + runbook documents (phase 5).
- GitHub Actions CI (spec v1.1 — not yet planned).

**Rationale for this scope:** Prove the spine end-to-end before replicating the check pattern 28 more times. Each subsequent phase becomes a mechanical "add check + add tests" loop once phase 1 lands.

**Branch:** Work continues on `fix/hook-audit-28-bugs-env-centralized` (the branch the spec was committed to). The user explicitly chose this path during brainstorming to avoid disturbing 17 modified in-progress files. Revisit branch strategy once that work lands.

**Spec reference:** `docs/superpowers/specs/2026-04-17-claude-stack-audit-tool-design.md` (commit `698c714`).

---

## File Structure

### New package (all under `~/.dotfiles/claude-stack-audit/`)

| Path | Responsibility |
|------|----------------|
| `pyproject.toml` | uv project metadata, ruff + pytest + coverage config, Typer dependency, CLI script entry |
| `README.md` | Install, quickstart, CLI reference |
| `src/claude_stack_audit/__init__.py` | Version string |
| `src/claude_stack_audit/__main__.py` | `python -m claude_stack_audit` → `cli.app()` |
| `src/claude_stack_audit/models.py` | `Severity`, `Layer`, `Criterion`, `Finding`, `ExternalToolVersion`, `Inventory`, `Scorecard`, `Report` |
| `src/claude_stack_audit/context.py` | `Context` dataclass, `Context.build()`, `FileCache`, parsers for `settings.json`, `env.sh`, `org-map.json`, `crontab.txt` |
| `src/claude_stack_audit/external.py` | `ExternalTools`, `ToolResult`, subprocess wrapper with timeout |
| `src/claude_stack_audit/config.py` | `Config`, `Selection`, CLI-argument loading |
| `src/claude_stack_audit/runner.py` | `validate_environment`, `run(config)` → `Report`, META-finding emission on check crashes |
| `src/claude_stack_audit/cli.py` | Typer app with `run`, `list-checks`, `validate`, `--version` |
| `src/claude_stack_audit/checks/__init__.py` | Imports all check modules so `@register` decorators populate the registry |
| `src/claude_stack_audit/checks/base.py` | `Check` protocol, `_REGISTRY`, `register`, `enabled_checks` |
| `src/claude_stack_audit/checks/inventory.py` | `INV001 HookInventory` |
| `src/claude_stack_audit/checks/reliability.py` | `REL001 ShellcheckClean` |
| `src/claude_stack_audit/checks/observability.py` | `OBS001 LogPathConsistency` |
| `src/claude_stack_audit/checks/documentation.py` | `DOC001 ScriptHeaderPresent` |
| `src/claude_stack_audit/checks/cross_cutting.py` | `CROSS001 SymlinkIntegrity` |
| `src/claude_stack_audit/reports/__init__.py` | Package marker |
| `src/claude_stack_audit/reports/markdown.py` | `render(report) -> str`, `write(report, path)` |
| `src/claude_stack_audit/reports/json_report.py` | `render(report) -> dict`, `write(report, path)`, v1 schema |

### Tests (all under `~/.dotfiles/claude-stack-audit/tests/`)

| Path | Responsibility |
|------|----------------|
| `__init__.py` | Package marker |
| `conftest.py` | `fake_dotfiles`, `fake_external_tools`, `context_factory` fixtures |
| `test_models.py` | Models and scorecard math |
| `test_context.py` | `Context.build` parsing `settings.json`/`env.sh`/`org-map.json` |
| `test_external.py` | `ExternalTools` subprocess wrapper (timeout, error classification) |
| `test_runner.py` | Check ordering, META-finding emission on crashes |
| `test_cli.py` | CLI commands + exit codes |
| `test_reports_markdown.py` | Markdown report rendering |
| `test_reports_json.py` | JSON report rendering + schema validity |
| `test_inventory.py` | `INV001` |
| `test_reliability.py` | `REL001` |
| `test_observability.py` | `OBS001` |
| `test_documentation.py` | `DOC001` |
| `test_cross_cutting.py` | `CROSS001` |
| `integration/__init__.py` | Package marker |
| `integration/test_full_run.py` | End-to-end `runner.run()` on synthetic dotfiles |

### Files to modify

| Path | Change |
|------|--------|
| `~/.dotfiles/Brewfile` | Add `brew "shellcheck"` and `brew "jq"` if absent |
| `~/.dotfiles/install.sh` | Append idempotent `uv tool install -e "$HOME/.dotfiles/claude-stack-audit"` step |

### Files generated at the end (by running the tool)

| Path | Source |
|------|--------|
| `~/.dotfiles/docs/superpowers/audits/2026-04-17-stack-audit.md` | `cstack-audit run` — baseline report |
| `~/.dotfiles/docs/superpowers/audits/2026-04-17-stack-audit.json` | `cstack-audit run` — baseline JSON |

---

## Tasks

### Task 1: Scaffold the package with `uv`

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/pyproject.toml`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/README.md`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/__init__.py`

- [ ] **Step 1: Create the directory and scaffold with uv**

```bash
mkdir -p /Users/godl1ke/.dotfiles/claude-stack-audit
cd /Users/godl1ke/.dotfiles/claude-stack-audit
uv init --package --lib --name claude-stack-audit --python 3.11
```

Expected output: creates `pyproject.toml`, `README.md`, and `src/claude_stack_audit/__init__.py`.

- [ ] **Step 2: Replace `pyproject.toml` with the full configuration**

Overwrite `/Users/godl1ke/.dotfiles/claude-stack-audit/pyproject.toml`:

```toml
[project]
name = "claude-stack-audit"
version = "0.1.0"
description = "Audit the Claude Code + dotfiles + Obsidian pipeline against reliability, observability, and documentation criteria."
readme = "README.md"
requires-python = ">=3.11"
authors = [{ name = "Aman Upadhyay" }]
dependencies = [
    "typer>=0.12.0",
]

[project.scripts]
cstack-audit = "claude_stack_audit.cli:app"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.uv]
dev-dependencies = [
    "pytest>=8.0",
    "pytest-cov>=5.0",
    "jsonschema>=4.20",
    "ruff>=0.6.0",
]

[tool.hatch.build.targets.wheel]
packages = ["src/claude_stack_audit"]

[tool.pytest.ini_options]
minversion = "8.0"
addopts = "-ra --strict-markers --strict-config"
testpaths = ["tests"]
markers = [
    "real: runs against real ~/.dotfiles (default-skipped; opt-in with --real)",
    "integration: integration tests that build a synthetic dotfiles tree",
]

[tool.coverage.run]
branch = true
source = ["src/claude_stack_audit"]

[tool.coverage.report]
fail_under = 90
exclude_lines = [
    "pragma: no cover",
    "raise NotImplementedError",
    "if TYPE_CHECKING:",
]

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP", "B", "SIM", "PT", "RET"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
```

- [ ] **Step 3: Replace `src/claude_stack_audit/__init__.py`**

Overwrite with:

```python
"""claude-stack-audit — inspect Claude Code + dotfiles + Obsidian pipeline."""

__version__ = "0.1.0"
```

- [ ] **Step 4: Write a minimal README**

Overwrite `/Users/godl1ke/.dotfiles/claude-stack-audit/README.md`:

```markdown
# claude-stack-audit

Read-only inspection tool for the Claude Code + dotfiles + Obsidian pipeline.
Emits a prioritised markdown report plus machine-readable JSON.

## Install

```bash
brew bundle --file ~/.dotfiles/Brewfile   # shellcheck, jq
uv tool install -e ~/.dotfiles/claude-stack-audit
```

## Usage

```bash
cstack-audit run                             # full audit
cstack-audit run --only reliability,docs     # subset
cstack-audit run --quick                     # inventory + cross_cutting only
cstack-audit list-checks                     # enumerate registered checks
cstack-audit validate                        # env preflight
```

Reports land in `~/.dotfiles/docs/superpowers/audits/YYYY-MM-DD-stack-audit.{md,json}`.

## Design

See `~/.dotfiles/docs/superpowers/specs/2026-04-17-claude-stack-audit-tool-design.md`.
```

- [ ] **Step 5: Sync and verify the package builds**

```bash
cd /Users/godl1ke/.dotfiles/claude-stack-audit
uv sync
uv run python -c "import claude_stack_audit; print(claude_stack_audit.__version__)"
```

Expected: `0.1.0`

- [ ] **Step 6: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/pyproject.toml claude-stack-audit/README.md claude-stack-audit/src/claude_stack_audit/__init__.py claude-stack-audit/uv.lock
git commit -m "feat(claude-stack-audit): scaffold uv package"
```

---

### Task 2: Models (Severity, Layer, Criterion, Finding, Report)

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/models.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/__init__.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/test_models.py`

- [ ] **Step 1: Create `tests/__init__.py`**

```python
```

(Empty file; marks `tests` as a package.)

- [ ] **Step 2: Write the failing test for the scorecard formula**

Create `tests/test_models.py`:

```python
from datetime import datetime, timezone

from claude_stack_audit.models import (
    Criterion,
    Finding,
    Inventory,
    Layer,
    Report,
    Scorecard,
    Severity,
)


def _f(severity: Severity) -> Finding:
    return Finding(
        check_id="TEST",
        severity=severity,
        layer=Layer.CORE,
        criterion=Criterion.RELIABILITY,
        artifact="x",
        message="x",
        details=None,
        fix_hint=None,
    )


def test_severity_weights_sum_correctly():
    findings = [
        _f(Severity.CRITICAL),
        _f(Severity.HIGH),
        _f(Severity.HIGH),
        _f(Severity.MEDIUM),
        _f(Severity.LOW),
        _f(Severity.INFO),
    ]
    sc = Scorecard.from_findings(findings)
    # critical=10, high*2=10, medium=2, low=1, info=0 → total penalty 23
    assert sc.score == 1000 - 23
    assert sc.counts == {
        Severity.CRITICAL: 1,
        Severity.HIGH: 2,
        Severity.MEDIUM: 1,
        Severity.LOW: 1,
        Severity.INFO: 1,
    }


def test_score_never_below_zero():
    findings = [_f(Severity.CRITICAL)] * 200  # 2000 penalty
    sc = Scorecard.from_findings(findings)
    assert sc.score == 0


def test_report_carries_generated_at_and_version():
    r = Report(
        generated_at=datetime(2026, 4, 17, tzinfo=timezone.utc),
        tool_version="0.1.0",
        findings=[],
        inventory=Inventory(),
        scorecard=Scorecard.from_findings([]),
        external_tool_versions={},
    )
    assert r.tool_version == "0.1.0"
    assert r.scorecard.score == 1000
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd /Users/godl1ke/.dotfiles/claude-stack-audit
uv run pytest tests/test_models.py -v
```

Expected: FAIL (`ModuleNotFoundError: No module named 'claude_stack_audit.models'`)

- [ ] **Step 4: Implement `models.py`**

Create `src/claude_stack_audit/models.py`:

```python
"""Data model: severities, layers, criteria, Finding, Inventory, Scorecard, Report."""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum


class Severity(StrEnum):
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
    INFO = "info"


SEVERITY_WEIGHTS: dict[Severity, int] = {
    Severity.CRITICAL: 10,
    Severity.HIGH: 5,
    Severity.MEDIUM: 2,
    Severity.LOW: 1,
    Severity.INFO: 0,
}


class Layer(StrEnum):
    CORE = "core"
    AUTOMATION = "automation"
    OBSIDIAN = "obsidian"


class Criterion(StrEnum):
    INVENTORY = "inventory"
    RELIABILITY = "reliability"
    OBSERVABILITY = "observability"
    DOCUMENTATION = "documentation"
    CROSS_CUTTING = "cross_cutting"


@dataclass(frozen=True)
class Finding:
    check_id: str
    severity: Severity
    layer: Layer
    criterion: Criterion
    artifact: str
    message: str
    details: str | None = None
    fix_hint: str | None = None


@dataclass
class HookRecord:
    path: str
    events: list[str]


@dataclass
class CronRecord:
    schedule: str
    script: str


@dataclass
class LaunchAgentRecord:
    label: str
    loaded: bool


@dataclass
class PluginRecord:
    name: str
    version: str | None


@dataclass
class McpServerRecord:
    name: str
    transport: str


@dataclass
class Inventory:
    hooks: list[HookRecord] = field(default_factory=list)
    crons: list[CronRecord] = field(default_factory=list)
    launchagents: list[LaunchAgentRecord] = field(default_factory=list)
    slash_commands: list[str] = field(default_factory=list)
    agents: list[str] = field(default_factory=list)
    plugins: list[PluginRecord] = field(default_factory=list)
    mcp_servers: list[McpServerRecord] = field(default_factory=list)


@dataclass
class Scorecard:
    score: int
    counts: dict[Severity, int]

    @classmethod
    def from_findings(cls, findings: list[Finding]) -> Scorecard:
        counts = Counter(f.severity for f in findings)
        penalty = sum(SEVERITY_WEIGHTS[sev] * n for sev, n in counts.items())
        score = max(0, 1000 - penalty)
        return cls(
            score=score,
            counts={sev: counts.get(sev, 0) for sev in Severity},
        )


@dataclass
class Report:
    generated_at: datetime
    tool_version: str
    findings: list[Finding]
    inventory: Inventory
    scorecard: Scorecard
    external_tool_versions: dict[str, str]
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
uv run pytest tests/test_models.py -v
```

Expected: 3 passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/src/claude_stack_audit/models.py claude-stack-audit/tests/__init__.py claude-stack-audit/tests/test_models.py
git commit -m "feat(claude-stack-audit): add core data models and scorecard"
```

---

### Task 3: `ExternalTools` subprocess adapter

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/external.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/test_external.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_external.py`:

```python
from claude_stack_audit.external import ExternalTools, ToolResult


def test_run_captures_stdout_stderr_and_returncode():
    tools = ExternalTools()
    r = tools.run(["sh", "-c", "echo hello; echo err 1>&2; exit 3"])
    assert r.returncode == 3
    assert "hello" in r.stdout
    assert "err" in r.stderr
    assert r.duration_ms >= 0
    assert r.timed_out is False


def test_run_reports_timeout_without_raising():
    tools = ExternalTools(default_timeout=0.1)
    r = tools.run(["sh", "-c", "sleep 2"])
    assert r.timed_out is True
    assert r.returncode != 0


def test_run_handles_missing_executable_without_raising():
    tools = ExternalTools()
    r = tools.run(["definitely-not-a-real-binary-xyz"])
    assert r.timed_out is False
    assert r.returncode != 0
    assert r.stderr  # some error text present
```

- [ ] **Step 2: Run to verify it fails**

```bash
uv run pytest tests/test_external.py -v
```

Expected: FAIL (module not found).

- [ ] **Step 3: Implement `external.py`**

Create `src/claude_stack_audit/external.py`:

```python
"""Subprocess adapter. Wraps subprocess.run with timeouts and returns ToolResult.
Never raises on non-zero or missing binaries — check code reads ToolResult fields."""

from __future__ import annotations

import subprocess
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ToolResult:
    returncode: int
    stdout: str
    stderr: str
    duration_ms: int
    timed_out: bool


class ExternalTools:
    """Wraps subprocess.run with a default timeout and safe error handling."""

    def __init__(self, default_timeout: float = 30.0) -> None:
        self.default_timeout = default_timeout

    def run(
        self,
        argv: list[str],
        *,
        timeout: float | None = None,
        cwd: str | Path | None = None,
    ) -> ToolResult:
        start = time.monotonic()
        try:
            proc = subprocess.run(
                argv,
                capture_output=True,
                text=True,
                timeout=timeout or self.default_timeout,
                cwd=cwd,
                check=False,
            )
            return ToolResult(
                returncode=proc.returncode,
                stdout=proc.stdout,
                stderr=proc.stderr,
                duration_ms=int((time.monotonic() - start) * 1000),
                timed_out=False,
            )
        except subprocess.TimeoutExpired as exc:
            return ToolResult(
                returncode=-1,
                stdout=exc.stdout or "",
                stderr=(exc.stderr or "") + f"\n[timeout after {exc.timeout}s]",
                duration_ms=int((time.monotonic() - start) * 1000),
                timed_out=True,
            )
        except FileNotFoundError as exc:
            return ToolResult(
                returncode=127,
                stdout="",
                stderr=str(exc),
                duration_ms=int((time.monotonic() - start) * 1000),
                timed_out=False,
            )

    def shellcheck(self, path: str | Path) -> ToolResult:
        return self.run(["shellcheck", "--format=json", str(path)])

    def version(self, argv: list[str]) -> str | None:
        r = self.run(argv, timeout=5.0)
        if r.returncode != 0:
            return None
        return (r.stdout or r.stderr).strip().splitlines()[0] if (r.stdout or r.stderr) else None
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
uv run pytest tests/test_external.py -v
```

Expected: 3 passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/src/claude_stack_audit/external.py claude-stack-audit/tests/test_external.py
git commit -m "feat(claude-stack-audit): add ExternalTools subprocess adapter"
```

---

### Task 4: `Context` with parsers for settings/env/org-map

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/context.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/test_context.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/conftest.py`

- [ ] **Step 1: Create `conftest.py` with the `fake_dotfiles` fixture**

Create `tests/conftest.py`:

```python
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
        for k, v in self._results.items():
            if key.endswith(k):
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

    (claude / "settings.json").write_text(json.dumps({
        "hooks": {
            "Stop": [{"matcher": "", "hooks": [{"type": "command", "command": "hooks/session-stop.sh"}]}],
            "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "hooks/session-start.sh"}]}],
        },
        "permissions": {"allow": ["Read"], "deny": []},
    }))
    (claude / "env.sh").write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        "export OBSIDIAN_VAULT=\"$HOME/vault\"\n"
        "export CLAUDE_LOG_DIR=\"$HOME/Library/Logs/claude-crons\"\n"
    )
    (claude / "org-map.json").write_text(json.dumps({
        "default_org": "Personal",
        "orgs": {"Personal": {"wikilink": "[[Personal]]", "vault_folder": "Personal"}},
    }))
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
        "echo hi >> \"$HOME/Library/Logs/claude-crons/session-stop.log\"\n"
    )
    good.chmod(0o755)

    start = claude / "hooks" / "session-start.sh"
    start.write_text("#!/bin/bash\nset -euo pipefail\necho start\n")
    start.chmod(0o755)

    return dot
```

- [ ] **Step 2: Write failing tests for `Context.build`**

Create `tests/test_context.py`:

```python
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
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
uv run pytest tests/test_context.py -v
```

Expected: FAIL (module not found).

- [ ] **Step 4: Implement `context.py`**

Create `src/claude_stack_audit/context.py`:

```python
"""Context: one-time-parsed view of the stack that all checks read from."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from claude_stack_audit.external import ExternalTools


@dataclass
class Settings:
    raw: dict
    hook_events: dict[str, list[dict]]
    permissions: dict


@dataclass
class CronEntry:
    schedule: str
    script: str
    raw_line: str


@dataclass
class OrgMap:
    default_org: str
    orgs: dict[str, dict]


@dataclass
class FileCache:
    _cache: dict[Path, str] = field(default_factory=dict)

    def read(self, path: Path) -> str:
        key = path.resolve()
        if key not in self._cache:
            self._cache[key] = path.read_text()
        return self._cache[key]


@dataclass
class Context:
    dotfiles_root: Path
    claude_root: Path
    settings: Settings
    env_vars: dict[str, str]
    org_map: OrgMap
    crontab: list[CronEntry]
    bash_scripts: list[Path]
    python_scripts: list[Path]
    file_cache: FileCache
    external: ExternalTools

    @classmethod
    def build(cls, *, dotfiles_root: Path, external: ExternalTools) -> Context:
        claude_root = dotfiles_root / "claude"
        settings = _load_settings(claude_root / "settings.json")
        env_vars = _parse_env_sh(claude_root / "env.sh")
        org_map = _load_org_map(claude_root / "org-map.json")
        crontab = _parse_crontab(claude_root / "crontab.txt")

        bash_scripts = sorted(
            p for p in claude_root.rglob("*.sh") if p.is_file()
        )
        python_scripts = sorted(
            p for p in claude_root.rglob("*.py") if p.is_file()
        )

        return cls(
            dotfiles_root=dotfiles_root,
            claude_root=claude_root,
            settings=settings,
            env_vars=env_vars,
            org_map=org_map,
            crontab=crontab,
            bash_scripts=bash_scripts,
            python_scripts=python_scripts,
            file_cache=FileCache(),
            external=external,
        )


def _load_settings(path: Path) -> Settings:
    if not path.exists():
        return Settings(raw={}, hook_events={}, permissions={})
    try:
        raw = json.loads(path.read_text())
    except json.JSONDecodeError:
        return Settings(raw={}, hook_events={}, permissions={})
    return Settings(
        raw=raw,
        hook_events=raw.get("hooks", {}),
        permissions=raw.get("permissions", {}),
    )


_EXPORT_RE = re.compile(r'^\s*export\s+([A-Z_][A-Z0-9_]*)=(?:"([^"]*)"|\'([^\']*)\'|(\S+))')


def _parse_env_sh(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    result: dict[str, str] = {}
    for line in path.read_text().splitlines():
        m = _EXPORT_RE.match(line)
        if not m:
            continue
        name = m.group(1)
        value = m.group(2) or m.group(3) or m.group(4) or ""
        result[name] = value
    return result


def _load_org_map(path: Path) -> OrgMap:
    if not path.exists():
        return OrgMap(default_org="", orgs={})
    try:
        raw = json.loads(path.read_text())
    except json.JSONDecodeError:
        return OrgMap(default_org="", orgs={})
    return OrgMap(
        default_org=raw.get("default_org", ""),
        orgs=raw.get("orgs", {}),
    )


_CRON_RE = re.compile(r"^(\S+\s+\S+\s+\S+\s+\S+\s+\S+)\s+(.+)$")


def _parse_crontab(path: Path) -> list[CronEntry]:
    if not path.exists():
        return []
    entries: list[CronEntry] = []
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        m = _CRON_RE.match(stripped)
        if not m:
            continue
        entries.append(CronEntry(schedule=m.group(1), script=m.group(2), raw_line=stripped))
    return entries
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
uv run pytest tests/test_context.py -v
```

Expected: 4 passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/src/claude_stack_audit/context.py claude-stack-audit/tests/conftest.py claude-stack-audit/tests/test_context.py
git commit -m "feat(claude-stack-audit): add Context with settings/env/org-map parsers"
```

---

### Task 5: Check protocol, registry, and `Config`

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/checks/__init__.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/checks/base.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/config.py`

- [ ] **Step 1: Create `checks/__init__.py`** (empty — populated by later tasks)

```python
"""Check implementations. Importing this module populates the check registry."""
```

- [ ] **Step 2: Implement `checks/base.py`**

Create `src/claude_stack_audit/checks/base.py`:

```python
"""Check protocol and registry."""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass, field
from typing import Protocol

from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer


class Check(Protocol):
    id: str
    name: str
    criterion: Criterion
    layer: Layer

    def run(self, ctx: Context) -> Iterable[Finding]: ...


_REGISTRY: list[type[Check]] = []


def register(cls: type[Check]) -> type[Check]:
    _REGISTRY.append(cls)
    return cls


@dataclass
class Selection:
    criteria: set[Criterion] | None = field(default=None)
    quick: bool = False

    def includes(self, check: Check) -> bool:
        if self.quick and check.criterion not in {Criterion.INVENTORY, Criterion.CROSS_CUTTING}:
            return False
        if self.criteria is not None and check.criterion not in self.criteria:
            return False
        return True


def enabled_checks(selection: Selection) -> list[Check]:
    return [c() for c in _REGISTRY if selection.includes(c())]


def all_registered_check_classes() -> list[type[Check]]:
    return list(_REGISTRY)


def clear_registry_for_tests() -> None:
    _REGISTRY.clear()
```

- [ ] **Step 3: Implement `config.py`**

Create `src/claude_stack_audit/config.py`:

```python
"""Config loader. Maps CLI arguments to the Config dataclass consumed by the runner."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from claude_stack_audit.checks.base import Selection
from claude_stack_audit.models import Criterion


@dataclass
class Config:
    dotfiles_root: Path
    output_dir: Path
    selection: Selection = field(default_factory=Selection)
    tag: str | None = None

    @property
    def output_md(self) -> Path:
        from datetime import date
        suffix = f"--{self.tag}" if self.tag else ""
        return self.output_dir / f"{date.today().isoformat()}-stack-audit{suffix}.md"

    @property
    def output_json(self) -> Path:
        from datetime import date
        suffix = f"--{self.tag}" if self.tag else ""
        return self.output_dir / f"{date.today().isoformat()}-stack-audit{suffix}.json"


def parse_criteria(s: str | None) -> set[Criterion] | None:
    if not s:
        return None
    return {Criterion(x.strip()) for x in s.split(",")}
```

- [ ] **Step 4: Add a smoke test for registry + selection**

Append to `tests/test_models.py`:

```python
from claude_stack_audit.checks.base import (
    Selection,
    clear_registry_for_tests,
    enabled_checks,
    register,
)


def test_registry_register_and_enabled_checks():
    clear_registry_for_tests()

    @register
    class DummyInventory:
        id = "TEST_INV"
        name = "dummy inventory"
        criterion = Criterion.INVENTORY
        layer = Layer.CORE

        def run(self, ctx):
            return []

    @register
    class DummyReliability:
        id = "TEST_REL"
        name = "dummy reliability"
        criterion = Criterion.RELIABILITY
        layer = Layer.AUTOMATION

        def run(self, ctx):
            return []

    enabled = enabled_checks(Selection())
    assert len(enabled) == 2

    quick = enabled_checks(Selection(quick=True))
    assert len(quick) == 1
    assert quick[0].id == "TEST_INV"

    subset = enabled_checks(Selection(criteria={Criterion.RELIABILITY}))
    assert len(subset) == 1
    assert subset[0].id == "TEST_REL"
```

- [ ] **Step 5: Run tests**

```bash
uv run pytest tests/test_models.py -v
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/src/claude_stack_audit/config.py claude-stack-audit/src/claude_stack_audit/checks/__init__.py claude-stack-audit/src/claude_stack_audit/checks/base.py claude-stack-audit/tests/test_models.py
git commit -m "feat(claude-stack-audit): add Check protocol, registry, and Config"
```

---

### Task 6: Runner orchestration + `validate_environment`

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/runner.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/test_runner.py`

- [ ] **Step 1: Write failing tests for runner behaviour**

Create `tests/test_runner.py`:

```python
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

import pytest

from claude_stack_audit.checks.base import (
    Selection,
    clear_registry_for_tests,
    register,
)
from claude_stack_audit.config import Config
from claude_stack_audit.models import Criterion, Finding, Layer, Severity
from claude_stack_audit.runner import ValidationError, run, validate_environment


def _mk_config(root: Path, out: Path) -> Config:
    return Config(dotfiles_root=root, output_dir=out, selection=Selection())


def test_runner_collects_findings_from_all_checks(fake_dotfiles, fake_external_tools, tmp_path):
    clear_registry_for_tests()

    @register
    class EmitsOne:
        id = "T01"
        name = "emits one"
        criterion = Criterion.RELIABILITY
        layer = Layer.AUTOMATION

        def run(self, ctx):
            yield Finding(
                check_id=self.id,
                severity=Severity.HIGH,
                layer=self.layer,
                criterion=self.criterion,
                artifact="x",
                message="x",
            )

    cfg = _mk_config(fake_dotfiles, tmp_path / "out")
    report = run(cfg, external=fake_external_tools, now=datetime(2026, 4, 17, tzinfo=timezone.utc))
    assert len(report.findings) == 1
    assert report.findings[0].check_id == "T01"


def test_runner_emits_meta_finding_on_check_crash(fake_dotfiles, fake_external_tools, tmp_path):
    clear_registry_for_tests()

    @register
    class Crashes:
        id = "T02"
        name = "crashes"
        criterion = Criterion.RELIABILITY
        layer = Layer.AUTOMATION

        def run(self, ctx):
            raise RuntimeError("boom")

    cfg = _mk_config(fake_dotfiles, tmp_path / "out")
    report = run(cfg, external=fake_external_tools)
    meta = [f for f in report.findings if f.check_id == "META001"]
    assert len(meta) == 1
    assert "T02" in meta[0].details
    assert meta[0].severity == Severity.HIGH


def test_validate_environment_raises_when_shellcheck_missing(monkeypatch, tmp_path):
    from claude_stack_audit import runner as r

    def no_shellcheck(argv, **_):
        return type("X", (), {"returncode": 127, "stdout": "", "stderr": "not found", "timed_out": False, "duration_ms": 0})()

    class NoTools:
        def run(self, argv, **_):
            return no_shellcheck(argv)

    with pytest.raises(ValidationError):
        validate_environment(dotfiles_root=tmp_path, external=NoTools())


def test_runner_sorts_findings_by_severity_desc(fake_dotfiles, fake_external_tools, tmp_path):
    clear_registry_for_tests()

    @register
    class Many:
        id = "T03"
        name = "many"
        criterion = Criterion.RELIABILITY
        layer = Layer.AUTOMATION

        def run(self, ctx):
            for sev in [Severity.LOW, Severity.CRITICAL, Severity.MEDIUM, Severity.HIGH]:
                yield Finding(
                    check_id=self.id,
                    severity=sev,
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(sev),
                    message="x",
                )

    cfg = _mk_config(fake_dotfiles, tmp_path / "out")
    report = run(cfg, external=fake_external_tools)
    severities = [f.severity for f in report.findings]
    assert severities == [Severity.CRITICAL, Severity.HIGH, Severity.MEDIUM, Severity.LOW]
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
uv run pytest tests/test_runner.py -v
```

Expected: FAIL (module not found).

- [ ] **Step 3: Implement `runner.py`**

Create `src/claude_stack_audit/runner.py`:

```python
"""Audit runner. Validates the environment, builds the Context, iterates checks,
emits META findings on crashes, and returns a sorted Report."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from claude_stack_audit import __version__
from claude_stack_audit.checks.base import enabled_checks
from claude_stack_audit.config import Config
from claude_stack_audit.context import Context
from claude_stack_audit.external import ExternalTools
from claude_stack_audit.models import (
    Criterion,
    Finding,
    Inventory,
    Layer,
    Report,
    Scorecard,
    Severity,
)

_SEVERITY_ORDER = {
    Severity.CRITICAL: 0,
    Severity.HIGH: 1,
    Severity.MEDIUM: 2,
    Severity.LOW: 3,
    Severity.INFO: 4,
}


class ValidationError(RuntimeError):
    """Raised when the environment can't support an audit run."""


def validate_environment(*, dotfiles_root: Path, external: ExternalTools) -> None:
    if not dotfiles_root.exists():
        raise ValidationError(f"dotfiles root does not exist: {dotfiles_root}")
    result = external.run(["shellcheck", "--version"], timeout=5.0)
    if result.returncode != 0:
        raise ValidationError(
            "shellcheck not found or not executable. Install via: brew install shellcheck"
        )


def run(
    config: Config,
    *,
    external: ExternalTools | None = None,
    now: datetime | None = None,
) -> Report:
    external = external or ExternalTools()
    now = now or datetime.now(timezone.utc)
    context = Context.build(dotfiles_root=config.dotfiles_root, external=external)

    findings: list[Finding] = []
    inventory = Inventory()

    for check in enabled_checks(config.selection):
        try:
            for f in check.run(context):
                findings.append(f)
        except Exception as exc:  # noqa: BLE001 - intentional: never crash the runner
            findings.append(
                Finding(
                    check_id="META001",
                    severity=Severity.HIGH,
                    layer=Layer.CORE,
                    criterion=Criterion.CROSS_CUTTING,
                    artifact=f"check:{check.id}",
                    message=f"check {check.id} crashed",
                    details=f"{check.id} raised {type(exc).__name__}: {exc}",
                    fix_hint=f"See logs; fix the check implementation for {check.id}.",
                )
            )

    findings.sort(
        key=lambda f: (
            _SEVERITY_ORDER[f.severity],
            f.layer.value,
            f.criterion.value,
            f.check_id,
            f.artifact,
        )
    )

    return Report(
        generated_at=now,
        tool_version=__version__,
        findings=findings,
        inventory=inventory,
        scorecard=Scorecard.from_findings(findings),
        external_tool_versions={
            "shellcheck": external.version(["shellcheck", "--version"]) or "unknown",
        },
    )
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
uv run pytest tests/test_runner.py -v
```

Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/src/claude_stack_audit/runner.py claude-stack-audit/tests/test_runner.py
git commit -m "feat(claude-stack-audit): add runner orchestration + env validation"
```

---

### Task 7: Markdown reporter

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/reports/__init__.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/reports/markdown.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/test_reports_markdown.py`

- [ ] **Step 1: Create the empty `reports/__init__.py`**

```python
"""Report renderers."""
```

- [ ] **Step 2: Write failing tests for the markdown reporter**

Create `tests/test_reports_markdown.py`:

```python
from datetime import datetime, timezone

from claude_stack_audit.models import (
    Criterion,
    Finding,
    Inventory,
    Layer,
    Report,
    Scorecard,
    Severity,
)
from claude_stack_audit.reports.markdown import render


def _mk(sev: Severity, check_id: str = "REL001", message: str = "bad thing") -> Finding:
    return Finding(
        check_id=check_id,
        severity=sev,
        layer=Layer.AUTOMATION,
        criterion=Criterion.RELIABILITY,
        artifact="hooks/foo.sh",
        message=message,
        details=None,
        fix_hint="fix it",
    )


def _report(findings):
    return Report(
        generated_at=datetime(2026, 4, 17, 14, 30, tzinfo=timezone.utc),
        tool_version="0.1.0",
        findings=findings,
        inventory=Inventory(),
        scorecard=Scorecard.from_findings(findings),
        external_tool_versions={"shellcheck": "0.9.0"},
    )


def test_renders_score_and_severity_counts():
    out = render(_report([_mk(Severity.CRITICAL), _mk(Severity.HIGH), _mk(Severity.HIGH)]))
    assert "Health score: 980" in out  # 1000 - 10 - 10 = 980
    assert "Critical" in out
    assert "High" in out


def test_renders_critical_section_when_present():
    out = render(_report([_mk(Severity.CRITICAL, check_id="CROSS001", message="broken symlink")]))
    assert "## Critical findings" in out
    assert "CROSS001" in out
    assert "broken symlink" in out


def test_renders_no_findings_happy_path():
    out = render(_report([]))
    assert "Health score: 1000" in out
    assert "No findings" in out
```

- [ ] **Step 3: Run to verify failure**

```bash
uv run pytest tests/test_reports_markdown.py -v
```

Expected: FAIL.

- [ ] **Step 4: Implement `markdown.py`**

Create `src/claude_stack_audit/reports/markdown.py`:

```python
"""Human-facing markdown renderer for the audit Report."""

from __future__ import annotations

from pathlib import Path

from claude_stack_audit.models import Finding, Report, Severity

_SEV_LABEL = {
    Severity.CRITICAL: "Critical",
    Severity.HIGH: "High",
    Severity.MEDIUM: "Medium",
    Severity.LOW: "Low",
    Severity.INFO: "Info",
}


def render(report: Report) -> str:
    lines: list[str] = []
    lines.append(f"# Claude Stack Audit — {report.generated_at.date().isoformat()}")
    lines.append("")
    lines.append(f"**Health score: {report.scorecard.score} / 1000**")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append("| Severity | Count |")
    lines.append("|----------|------:|")
    for sev in Severity:
        lines.append(f"| {_SEV_LABEL[sev]} | {report.scorecard.counts.get(sev, 0)} |")
    lines.append("")

    if not report.findings:
        lines.append("_No findings. The stack is clean._")
        lines.append("")
        lines.append(_footer(report))
        return "\n".join(lines)

    crit = [f for f in report.findings if f.severity is Severity.CRITICAL]
    if crit:
        lines.append("## Critical findings")
        lines.append("")
        lines.extend(_finding_table(crit))

    for sev in (Severity.HIGH, Severity.MEDIUM, Severity.LOW):
        bucket = [f for f in report.findings if f.severity is sev]
        if not bucket:
            continue
        lines.append(f"## {_SEV_LABEL[sev]} findings")
        lines.append("")
        lines.extend(_finding_table(bucket))

    lines.append(_footer(report))
    return "\n".join(lines)


def _finding_table(findings: list[Finding]) -> list[str]:
    out = [
        "| ID | Layer | Criterion | Artifact | Message | Fix hint |",
        "|----|-------|-----------|----------|---------|----------|",
    ]
    for f in findings:
        out.append(
            f"| {f.check_id} | {f.layer.value} | {f.criterion.value} | `{f.artifact}` | {f.message} | {f.fix_hint or ''} |"
        )
    out.append("")
    return out


def _footer(report: Report) -> str:
    ts = report.generated_at.isoformat(timespec="minutes")
    tools = ", ".join(f"{k} {v}" for k, v in sorted(report.external_tool_versions.items()))
    return f"\n---\n_Generated by cstack-audit {report.tool_version} at {ts} · tools: {tools}_\n"


def write(report: Report, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(render(report))
```

- [ ] **Step 5: Run tests**

```bash
uv run pytest tests/test_reports_markdown.py -v
```

Expected: 3 passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/src/claude_stack_audit/reports/__init__.py claude-stack-audit/src/claude_stack_audit/reports/markdown.py claude-stack-audit/tests/test_reports_markdown.py
git commit -m "feat(claude-stack-audit): add markdown report renderer"
```

---

### Task 8: JSON reporter (v1 schema)

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/reports/json_report.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/test_reports_json.py`

- [ ] **Step 1: Write failing tests**

Create `tests/test_reports_json.py`:

```python
from datetime import datetime, timezone

import jsonschema

from claude_stack_audit.models import (
    Criterion,
    Finding,
    HookRecord,
    Inventory,
    Layer,
    Report,
    Scorecard,
    Severity,
)
from claude_stack_audit.reports.json_report import SCHEMA, render


def _sample_report():
    findings = [
        Finding(
            check_id="CROSS001",
            severity=Severity.CRITICAL,
            layer=Layer.CORE,
            criterion=Criterion.CROSS_CUTTING,
            artifact="~/.claude/env.sh",
            message="Symlink broken",
            details="ENOENT",
            fix_hint="ln -sf ...",
        ),
    ]
    inventory = Inventory(hooks=[HookRecord(path="hooks/foo.sh", events=["Stop"])])
    return Report(
        generated_at=datetime(2026, 4, 17, 14, 30, tzinfo=timezone.utc),
        tool_version="0.1.0",
        findings=findings,
        inventory=inventory,
        scorecard=Scorecard.from_findings(findings),
        external_tool_versions={"shellcheck": "0.9.0"},
    )


def test_render_includes_schema_version_and_score():
    out = render(_sample_report())
    assert out["schema_version"] == "1"
    assert out["score"] == 990  # 1000 - 10
    assert out["tool_version"] == "0.1.0"


def test_render_findings_structure():
    out = render(_sample_report())
    f = out["findings"][0]
    assert f["check_id"] == "CROSS001"
    assert f["severity"] == "critical"
    assert f["layer"] == "core"
    assert f["criterion"] == "cross_cutting"


def test_render_validates_against_schema():
    out = render(_sample_report())
    jsonschema.validate(instance=out, schema=SCHEMA)
```

- [ ] **Step 2: Run to verify failure**

```bash
uv run pytest tests/test_reports_json.py -v
```

Expected: FAIL.

- [ ] **Step 3: Implement `json_report.py`**

Create `src/claude_stack_audit/reports/json_report.py`:

```python
"""Machine-facing JSON renderer. Schema-versioned; consumers refuse unknown versions."""

from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

from claude_stack_audit.models import Report, Severity

SCHEMA_VERSION = "1"

SCHEMA: dict[str, Any] = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "required": [
        "schema_version",
        "generated_at",
        "tool_version",
        "score",
        "severity_counts",
        "inventory",
        "findings",
        "external_tool_versions",
    ],
    "properties": {
        "schema_version": {"const": SCHEMA_VERSION},
        "generated_at": {"type": "string"},
        "tool_version": {"type": "string"},
        "score": {"type": "integer", "minimum": 0, "maximum": 1000},
        "severity_counts": {
            "type": "object",
            "required": ["critical", "high", "medium", "low", "info"],
            "additionalProperties": {"type": "integer", "minimum": 0},
        },
        "inventory": {"type": "object"},
        "findings": {
            "type": "array",
            "items": {
                "type": "object",
                "required": [
                    "check_id",
                    "severity",
                    "layer",
                    "criterion",
                    "artifact",
                    "message",
                ],
                "properties": {
                    "check_id": {"type": "string"},
                    "severity": {"enum": ["critical", "high", "medium", "low", "info"]},
                    "layer": {"enum": ["core", "automation", "obsidian"]},
                    "criterion": {
                        "enum": [
                            "inventory",
                            "reliability",
                            "observability",
                            "documentation",
                            "cross_cutting",
                        ]
                    },
                    "artifact": {"type": "string"},
                    "message": {"type": "string"},
                    "details": {"type": ["string", "null"]},
                    "fix_hint": {"type": ["string", "null"]},
                },
            },
        },
        "external_tool_versions": {
            "type": "object",
            "additionalProperties": {"type": "string"},
        },
    },
}


def render(report: Report) -> dict:
    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at": report.generated_at.isoformat(),
        "tool_version": report.tool_version,
        "score": report.scorecard.score,
        "severity_counts": {sev.value: report.scorecard.counts.get(sev, 0) for sev in Severity},
        "inventory": _inventory_to_dict(report.inventory),
        "findings": [
            {
                "check_id": f.check_id,
                "severity": f.severity.value,
                "layer": f.layer.value,
                "criterion": f.criterion.value,
                "artifact": f.artifact,
                "message": f.message,
                "details": f.details,
                "fix_hint": f.fix_hint,
            }
            for f in report.findings
        ],
        "external_tool_versions": dict(report.external_tool_versions),
    }


def _inventory_to_dict(inv) -> dict:
    return {
        "hooks": [asdict(h) for h in inv.hooks],
        "crons": [asdict(c) for c in inv.crons],
        "launchagents": [asdict(la) for la in inv.launchagents],
        "slash_commands": list(inv.slash_commands),
        "agents": list(inv.agents),
        "plugins": [asdict(p) for p in inv.plugins],
        "mcp_servers": [asdict(m) for m in inv.mcp_servers],
    }


def write(report: Report, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(render(report), indent=2) + "\n")
```

- [ ] **Step 4: Run tests**

```bash
uv run pytest tests/test_reports_json.py -v
```

Expected: 3 passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/src/claude_stack_audit/reports/json_report.py claude-stack-audit/tests/test_reports_json.py
git commit -m "feat(claude-stack-audit): add JSON reporter with v1 schema"
```

---

### Task 9: Typer CLI (`run`, `list-checks`, `validate`)

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/cli.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/__main__.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/test_cli.py`

- [ ] **Step 1: Write failing tests**

Create `tests/test_cli.py`:

```python
from __future__ import annotations

from pathlib import Path

from typer.testing import CliRunner

from claude_stack_audit.checks.base import clear_registry_for_tests
from claude_stack_audit.cli import app


def test_version_flag():
    runner = CliRunner()
    result = runner.invoke(app, ["--version"])
    assert result.exit_code == 0
    assert "0.1.0" in result.stdout


def test_list_checks_empty(tmp_path):
    clear_registry_for_tests()
    runner = CliRunner()
    result = runner.invoke(app, ["list-checks"])
    assert result.exit_code == 0
    assert "No checks registered" in result.stdout


def test_run_writes_reports_to_output_dir(fake_dotfiles: Path, tmp_path, monkeypatch):
    clear_registry_for_tests()
    # Skip env validation for this test
    monkeypatch.setattr(
        "claude_stack_audit.cli.validate_environment", lambda **_: None
    )
    runner = CliRunner()
    out = tmp_path / "out"
    result = runner.invoke(
        app,
        [
            "run",
            "--dotfiles-root", str(fake_dotfiles),
            "--output-dir", str(out),
        ],
    )
    assert result.exit_code in (0, 1), result.stdout
    mds = list(out.glob("*.md"))
    jsons = list(out.glob("*.json"))
    assert len(mds) == 1
    assert len(jsons) == 1
```

- [ ] **Step 2: Implement `cli.py`**

Create `src/claude_stack_audit/cli.py`:

```python
"""Typer CLI entry point."""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Annotated

import typer

from claude_stack_audit import __version__
from claude_stack_audit import checks  # noqa: F401 — side-effect: registers checks
from claude_stack_audit.checks.base import Selection, all_registered_check_classes
from claude_stack_audit.config import Config, parse_criteria
from claude_stack_audit.models import Severity
from claude_stack_audit.reports import json_report, markdown
from claude_stack_audit.runner import ValidationError, run as runner_run, validate_environment

app = typer.Typer(add_completion=False, help="Audit the Claude Code + dotfiles + Obsidian pipeline.")


def _version_callback(value: bool) -> None:
    if value:
        typer.echo(__version__)
        raise typer.Exit()


@app.callback()
def main(
    version: Annotated[
        bool | None,
        typer.Option("--version", callback=_version_callback, is_eager=True, help="Show version and exit."),
    ] = None,
) -> None:
    pass


@app.command("list-checks")
def list_checks() -> None:
    """List all registered checks."""
    classes = all_registered_check_classes()
    if not classes:
        typer.echo("No checks registered.")
        return
    for cls in classes:
        typer.echo(f"{cls.id:<10} {cls.criterion.value:<14} {cls.layer.value:<11} {cls.name}")


@app.command()
def validate(
    dotfiles_root: Annotated[Path, typer.Option(envvar="CSTACK_DOTFILES_ROOT")] = Path.home() / ".dotfiles",
) -> None:
    """Check that the environment is ready for an audit run."""
    from claude_stack_audit.external import ExternalTools

    try:
        validate_environment(dotfiles_root=dotfiles_root, external=ExternalTools())
    except ValidationError as exc:
        typer.echo(f"error: {exc}", err=True)
        raise typer.Exit(code=2) from None
    typer.echo("ok: environment ready")


@app.command()
def run(
    dotfiles_root: Annotated[Path, typer.Option(envvar="CSTACK_DOTFILES_ROOT")] = Path.home() / ".dotfiles",
    output_dir: Annotated[
        Path, typer.Option(envvar="CSTACK_OUTPUT_DIR")
    ] = Path.home() / ".dotfiles" / "docs" / "superpowers" / "audits",
    only: Annotated[str | None, typer.Option(help="Comma-separated criteria (e.g. reliability,docs)")] = None,
    quick: Annotated[bool, typer.Option(help="Run only inventory + cross_cutting checks")] = False,
    tag: Annotated[str | None, typer.Option(help="Filename suffix for A/B tagging")] = None,
    skip_validate: Annotated[bool, typer.Option("--skip-validate", hidden=True)] = False,
) -> None:
    """Run the audit and write reports."""
    from claude_stack_audit.external import ExternalTools

    external = ExternalTools()
    if not skip_validate:
        try:
            validate_environment(dotfiles_root=dotfiles_root, external=external)
        except ValidationError as exc:
            typer.echo(f"error: {exc}", err=True)
            raise typer.Exit(code=2) from None

    config = Config(
        dotfiles_root=dotfiles_root,
        output_dir=output_dir,
        selection=Selection(criteria=parse_criteria(only), quick=quick),
        tag=tag,
    )

    crashed = False
    try:
        report = runner_run(config, external=external)
    except Exception as exc:  # noqa: BLE001 - top-level safety net
        typer.echo(f"error: runner failed: {exc}", err=True)
        raise typer.Exit(code=3) from None

    markdown.write(report, config.output_md)
    json_report.write(report, config.output_json)

    for f in report.findings:
        if f.check_id == "META001":
            crashed = True
            break

    summary = (
        f"{len(report.findings)} findings "
        f"({report.scorecard.counts.get(Severity.CRITICAL, 0)} Critical, "
        f"{report.scorecard.counts.get(Severity.HIGH, 0)} High, "
        f"{report.scorecard.counts.get(Severity.MEDIUM, 0)} Medium, "
        f"{report.scorecard.counts.get(Severity.LOW, 0)} Low, "
        f"{report.scorecard.counts.get(Severity.INFO, 0)} Info). "
        f"Score: {report.scorecard.score}/1000."
    )
    typer.echo(summary, err=True)
    typer.echo(f"Markdown: {config.output_md}", err=True)
    typer.echo(f"JSON:     {config.output_json}", err=True)

    if crashed:
        raise typer.Exit(code=3)
    has_block = report.scorecard.counts.get(Severity.CRITICAL, 0) + report.scorecard.counts.get(Severity.HIGH, 0) > 0
    if has_block:
        raise typer.Exit(code=1)
```

- [ ] **Step 3: Create `__main__.py`**

Create `src/claude_stack_audit/__main__.py`:

```python
from claude_stack_audit.cli import app

if __name__ == "__main__":
    app()
```

- [ ] **Step 4: Run tests**

```bash
uv run pytest tests/test_cli.py -v
```

Expected: 3 passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/src/claude_stack_audit/cli.py claude-stack-audit/src/claude_stack_audit/__main__.py claude-stack-audit/tests/test_cli.py
git commit -m "feat(claude-stack-audit): add Typer CLI (run, list-checks, validate)"
```

---

### Task 10: INV001 — Hook inventory

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/checks/inventory.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/test_inventory.py`
- Modify: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/checks/__init__.py` (import new module)

- [ ] **Step 1: Write the failing tests**

Create `tests/test_inventory.py`:

```python
from pathlib import Path

from claude_stack_audit.checks.inventory import HookInventory
from claude_stack_audit.context import Context


def test_INV001_enumerates_hooks_from_settings(fake_dotfiles: Path, fake_external_tools):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(HookInventory().run(ctx))

    events = {f.artifact for f in findings}
    assert "hooks/session-stop.sh" in events or any("session-stop.sh" in e for e in events)

    assert all(f.severity.value == "info" for f in findings)
    assert all(f.check_id == "INV001" for f in findings)


def test_INV001_emits_finding_per_hook_entry(fake_dotfiles: Path, fake_external_tools):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(HookInventory().run(ctx))
    # fixture has Stop + SessionStart = 2 hook entries
    assert len(findings) == 2
```

- [ ] **Step 2: Run to verify failure**

```bash
uv run pytest tests/test_inventory.py -v
```

Expected: FAIL.

- [ ] **Step 3: Implement `checks/inventory.py`**

Create `src/claude_stack_audit/checks/inventory.py`:

```python
"""Inventory checks (INV001–INV007). Phase 1 ships INV001 only."""

from __future__ import annotations

from collections.abc import Iterable

from claude_stack_audit.checks.base import register
from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer, Severity


@register
class HookInventory:
    id = "INV001"
    name = "hook inventory"
    criterion = Criterion.INVENTORY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        hooks = ctx.settings.hook_events or {}
        for event_name, entries in hooks.items():
            for entry in entries or []:
                for hook in entry.get("hooks", []) or []:
                    cmd = hook.get("command", "")
                    yield Finding(
                        check_id=self.id,
                        severity=Severity.INFO,
                        layer=self.layer,
                        criterion=self.criterion,
                        artifact=cmd or f"<event:{event_name}>",
                        message=f"{event_name} hook → {cmd}",
                        details=None,
                        fix_hint=None,
                    )
```

- [ ] **Step 4: Register the check by importing in `checks/__init__.py`**

Overwrite `src/claude_stack_audit/checks/__init__.py`:

```python
"""Check implementations. Importing this module populates the check registry."""

from claude_stack_audit.checks import inventory  # noqa: F401
```

- [ ] **Step 5: Run tests**

```bash
uv run pytest tests/test_inventory.py -v
```

Expected: 2 passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/src/claude_stack_audit/checks/inventory.py claude-stack-audit/src/claude_stack_audit/checks/__init__.py claude-stack-audit/tests/test_inventory.py
git commit -m "feat(claude-stack-audit): add INV001 hook inventory check"
```

---

### Task 11: REL001 — shellcheck clean

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/checks/reliability.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/test_reliability.py`
- Modify: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/checks/__init__.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_reliability.py`:

```python
import json
from pathlib import Path

from claude_stack_audit.checks.reliability import ShellcheckClean
from claude_stack_audit.context import Context
from claude_stack_audit.external import ToolResult
from claude_stack_audit.models import Severity


def test_REL001_no_findings_when_scripts_clean(fake_dotfiles: Path, fake_external_tools):
    fake_external_tools.shellcheck.register(
        "session-stop.sh",
        ToolResult(returncode=0, stdout="[]", stderr="", duration_ms=5, timed_out=False),
    )
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ShellcheckClean().run(ctx))
    # fixture has 2 scripts; both default-clean via fake
    assert findings == []


def test_REL001_emits_high_for_errors_medium_for_warnings(fake_dotfiles: Path, fake_external_tools):
    payload = json.dumps([
        {"file": "session-stop.sh", "level": "error", "line": 2, "column": 1, "code": 1000, "message": "bad"},
        {"file": "session-stop.sh", "level": "warning", "line": 4, "column": 1, "code": 2000, "message": "meh"},
    ])
    fake_external_tools.shellcheck.register(
        "session-stop.sh",
        ToolResult(returncode=1, stdout=payload, stderr="", duration_ms=5, timed_out=False),
    )
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ShellcheckClean().run(ctx))

    flagged = [f for f in findings if "session-stop.sh" in f.artifact]
    severities = {f.severity for f in flagged}
    assert Severity.HIGH in severities
    assert Severity.MEDIUM in severities
```

- [ ] **Step 2: Run to verify failure**

```bash
uv run pytest tests/test_reliability.py -v
```

Expected: FAIL.

- [ ] **Step 3: Implement `checks/reliability.py`**

Create `src/claude_stack_audit/checks/reliability.py`:

```python
"""Reliability checks (REL001–REL009). Phase 1 ships REL001 only."""

from __future__ import annotations

import json
from collections.abc import Iterable

from claude_stack_audit.checks.base import register
from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer, Severity

_LEVEL_TO_SEVERITY = {
    "error": Severity.HIGH,
    "warning": Severity.MEDIUM,
    "info": Severity.LOW,
    "style": Severity.LOW,
}


@register
class ShellcheckClean:
    id = "REL001"
    name = "shellcheck clean"
    criterion = Criterion.RELIABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            result = ctx.external.shellcheck(script)
            if result.timed_out:
                yield Finding(
                    check_id=self.id,
                    severity=Severity.MEDIUM,
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(script.relative_to(ctx.claude_root.parent)),
                    message="shellcheck timed out",
                    details=None,
                    fix_hint="Increase timeout or inspect script for infinite loops.",
                )
                continue
            if not result.stdout.strip():
                continue
            try:
                issues = json.loads(result.stdout)
            except json.JSONDecodeError:
                continue
            for issue in issues:
                level = issue.get("level", "warning")
                yield Finding(
                    check_id=self.id,
                    severity=_LEVEL_TO_SEVERITY.get(level, Severity.MEDIUM),
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(script.relative_to(ctx.claude_root.parent)),
                    message=f"SC{issue.get('code', '?')}: {issue.get('message', '')}",
                    details=f"line {issue.get('line', '?')}, column {issue.get('column', '?')}",
                    fix_hint="Run `shellcheck <file>` locally to see context; fix per shellcheck wiki.",
                )
```

- [ ] **Step 4: Update `checks/__init__.py`**

Overwrite:

```python
"""Check implementations. Importing this module populates the check registry."""

from claude_stack_audit.checks import inventory  # noqa: F401
from claude_stack_audit.checks import reliability  # noqa: F401
```

- [ ] **Step 5: Run tests**

```bash
uv run pytest tests/test_reliability.py -v
```

Expected: 2 passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/src/claude_stack_audit/checks/reliability.py claude-stack-audit/src/claude_stack_audit/checks/__init__.py claude-stack-audit/tests/test_reliability.py
git commit -m "feat(claude-stack-audit): add REL001 shellcheck-clean check"
```

---

### Task 12: OBS001 — Log-path consistency

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/checks/observability.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/test_observability.py`
- Modify: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/checks/__init__.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_observability.py`:

```python
from pathlib import Path

from claude_stack_audit.checks.observability import LogPathConsistency
from claude_stack_audit.context import Context
from claude_stack_audit.models import Severity


def test_OBS001_no_findings_when_scripts_use_approved_log_dirs(fake_dotfiles: Path, fake_external_tools):
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))
    # fixture session-stop.sh logs to ~/Library/Logs/claude-crons — approved
    assert findings == []


def test_OBS001_flags_tmp_log_paths(fake_dotfiles: Path, fake_external_tools):
    bad = fake_dotfiles / "claude" / "crons" / "bad-logger.sh"
    bad.write_text(
        "#!/bin/bash\n"
        "set -euo pipefail\n"
        "echo hi >> /tmp/my.log\n"
    )
    bad.chmod(0o755)

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(LogPathConsistency().run(ctx))

    flagged = [f for f in findings if "bad-logger.sh" in f.artifact]
    assert len(flagged) >= 1
    assert all(f.severity == Severity.HIGH for f in flagged)
    assert all(f.check_id == "OBS001" for f in flagged)
```

- [ ] **Step 2: Run to verify failure**

```bash
uv run pytest tests/test_observability.py -v
```

Expected: FAIL.

- [ ] **Step 3: Implement `checks/observability.py`**

Create `src/claude_stack_audit/checks/observability.py`:

```python
"""Observability checks (OBS001–OBS006). Phase 1 ships OBS001 only."""

from __future__ import annotations

import re
from collections.abc import Iterable

from claude_stack_audit.checks.base import register
from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer, Severity

_APPROVED_PREFIXES = (
    "$HOME/Library/Logs/claude-crons",
    "~/Library/Logs/claude-crons",
    "$HOME/.claude/logs",
    "~/.claude/logs",
    "$CLAUDE_LOG_DIR",
)

# Match redirects or tee into files: > /path, >> /path, 2> /path, tee /path
_LOG_WRITE_RE = re.compile(
    r"""(?:>>?|2>>?|\|\s*tee(?:\s+-a)?)\s+("?)(?P<path>\S+?)\1(?:\s|$)"""
)


@register
class LogPathConsistency:
    id = "OBS001"
    name = "log path consistency"
    criterion = Criterion.OBSERVABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            body = ctx.file_cache.read(script)
            for m in _LOG_WRITE_RE.finditer(body):
                path = m.group("path")
                if path.startswith(_APPROVED_PREFIXES):
                    continue
                if path.startswith(("/tmp/", "/var/tmp/")):
                    severity = Severity.HIGH
                elif path.startswith(("$", "~")):
                    # env-var-based or home-ish but not approved — warn
                    severity = Severity.MEDIUM
                elif path.startswith("/"):
                    severity = Severity.MEDIUM
                else:
                    continue  # relative path; skip (probably not a log file)
                yield Finding(
                    check_id=self.id,
                    severity=severity,
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(script.relative_to(ctx.claude_root.parent)),
                    message=f"log write to non-approved path: {path}",
                    details=None,
                    fix_hint=(
                        "Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, "
                        "or ~/.claude/logs/ instead of ad-hoc paths."
                    ),
                )
```

- [ ] **Step 4: Update `checks/__init__.py`**

Overwrite:

```python
"""Check implementations. Importing this module populates the check registry."""

from claude_stack_audit.checks import inventory  # noqa: F401
from claude_stack_audit.checks import reliability  # noqa: F401
from claude_stack_audit.checks import observability  # noqa: F401
```

- [ ] **Step 5: Run tests**

```bash
uv run pytest tests/test_observability.py -v
```

Expected: 2 passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/src/claude_stack_audit/checks/observability.py claude-stack-audit/src/claude_stack_audit/checks/__init__.py claude-stack-audit/tests/test_observability.py
git commit -m "feat(claude-stack-audit): add OBS001 log-path consistency check"
```

---

### Task 13: DOC001 — Script header presence

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/checks/documentation.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/test_documentation.py`
- Modify: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/checks/__init__.py`

- [ ] **Step 1: Write failing tests**

Create `tests/test_documentation.py`:

```python
from pathlib import Path

from claude_stack_audit.checks.documentation import ScriptHeaderPresent
from claude_stack_audit.context import Context
from claude_stack_audit.models import Severity


def test_DOC001_passes_when_header_fields_present(fake_dotfiles: Path, fake_external_tools):
    # fixture session-stop.sh has purpose/inputs/outputs/side-effects header
    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ScriptHeaderPresent().run(ctx))
    flagged = [f for f in findings if "session-stop.sh" in f.artifact]
    assert flagged == []


def test_DOC001_flags_script_with_no_header(fake_dotfiles: Path, fake_external_tools):
    bare = fake_dotfiles / "claude" / "hooks" / "bare.sh"
    bare.write_text("#!/bin/bash\nset -euo pipefail\necho nothing to see\n")
    bare.chmod(0o755)

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(ScriptHeaderPresent().run(ctx))
    flagged = [f for f in findings if "bare.sh" in f.artifact]
    assert len(flagged) == 1
    assert flagged[0].severity == Severity.HIGH
    assert flagged[0].check_id == "DOC001"
```

- [ ] **Step 2: Run to verify failure**

```bash
uv run pytest tests/test_documentation.py -v
```

Expected: FAIL.

- [ ] **Step 3: Implement `checks/documentation.py`**

Create `src/claude_stack_audit/checks/documentation.py`:

```python
"""Documentation checks (DOC001–DOC007). Phase 1 ships DOC001 only."""

from __future__ import annotations

import re
from collections.abc import Iterable

from claude_stack_audit.checks.base import register
from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer, Severity

_REQUIRED_FIELDS = ("purpose", "inputs", "outputs", "side-effects")
_HEADER_LINES = 20
_FIELD_RE = re.compile(r"^\s*#\s*(purpose|inputs|outputs|side-?effects)\s*:", re.IGNORECASE)


@register
class ScriptHeaderPresent:
    id = "DOC001"
    name = "script header present"
    criterion = Criterion.DOCUMENTATION
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            body = ctx.file_cache.read(script)
            head = body.splitlines()[:_HEADER_LINES]
            seen = set()
            for line in head:
                m = _FIELD_RE.match(line)
                if m:
                    key = m.group(1).lower().replace("sideeffects", "side-effects")
                    seen.add(key)
            missing = [f for f in _REQUIRED_FIELDS if f not in seen]
            if missing:
                yield Finding(
                    check_id=self.id,
                    severity=Severity.HIGH,
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(script.relative_to(ctx.claude_root.parent)),
                    message=f"script header missing: {', '.join(missing)}",
                    details=None,
                    fix_hint=(
                        "Add a 4-line comment block at the top of the script listing "
                        "purpose, inputs, outputs, and side-effects."
                    ),
                )
```

- [ ] **Step 4: Update `checks/__init__.py`**

Overwrite:

```python
"""Check implementations. Importing this module populates the check registry."""

from claude_stack_audit.checks import inventory  # noqa: F401
from claude_stack_audit.checks import reliability  # noqa: F401
from claude_stack_audit.checks import observability  # noqa: F401
from claude_stack_audit.checks import documentation  # noqa: F401
```

- [ ] **Step 5: Run tests**

```bash
uv run pytest tests/test_documentation.py -v
```

Expected: 2 passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/src/claude_stack_audit/checks/documentation.py claude-stack-audit/src/claude_stack_audit/checks/__init__.py claude-stack-audit/tests/test_documentation.py
git commit -m "feat(claude-stack-audit): add DOC001 script-header check"
```

---

### Task 14: CROSS001 — Symlink integrity

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/checks/cross_cutting.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/test_cross_cutting.py`
- Modify: `/Users/godl1ke/.dotfiles/claude-stack-audit/src/claude_stack_audit/checks/__init__.py`

- [ ] **Step 1: Write failing tests**

Create `tests/test_cross_cutting.py`:

```python
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


def test_CROSS001_passes_when_all_symlinks_valid(tmp_path: Path, fake_dotfiles: Path, fake_external_tools):
    dotclaude = _prepare_dotclaude(tmp_path, fake_dotfiles)

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(SymlinkIntegrity(dotclaude_root=dotclaude).run(ctx))
    assert findings == []


def test_CROSS001_emits_critical_for_broken_symlink(tmp_path: Path, fake_dotfiles: Path, fake_external_tools):
    dotclaude = _prepare_dotclaude(tmp_path, fake_dotfiles)
    # Break env.sh symlink by deleting the target
    (fake_dotfiles / "claude" / "env.sh").unlink()

    ctx = Context.build(dotfiles_root=fake_dotfiles, external=fake_external_tools)
    findings = list(SymlinkIntegrity(dotclaude_root=dotclaude).run(ctx))
    assert len(findings) == 1
    assert findings[0].severity == Severity.CRITICAL
    assert "env.sh" in findings[0].artifact
    assert findings[0].check_id == "CROSS001"
```

- [ ] **Step 2: Run to verify failure**

```bash
uv run pytest tests/test_cross_cutting.py -v
```

Expected: FAIL.

- [ ] **Step 3: Implement `checks/cross_cutting.py`**

Create `src/claude_stack_audit/checks/cross_cutting.py`:

```python
"""Cross-cutting checks (CROSS001–CROSS004). Phase 1 ships CROSS001 only."""

from __future__ import annotations

from collections.abc import Iterable
from pathlib import Path

from claude_stack_audit.checks.base import register
from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer, Severity

_SYMLINKS = ("settings.json", "env.sh", "org-map.json")


@register
class SymlinkIntegrity:
    id = "CROSS001"
    name = "symlink integrity"
    criterion = Criterion.CROSS_CUTTING
    layer = Layer.CORE

    def __init__(self, dotclaude_root: Path | None = None) -> None:
        self.dotclaude_root = dotclaude_root or (Path.home() / ".claude")

    def run(self, ctx: Context) -> Iterable[Finding]:
        for name in _SYMLINKS:
            link = self.dotclaude_root / name
            if not link.is_symlink():
                # A file that exists but is NOT a symlink is a deviation too,
                # but emit only if the expected symlink location has nothing.
                if not link.exists():
                    yield Finding(
                        check_id=self.id,
                        severity=Severity.CRITICAL,
                        layer=self.layer,
                        criterion=self.criterion,
                        artifact=str(link),
                        message=f"expected symlink missing: {name}",
                        details=None,
                        fix_hint=(
                            f"ln -sf {ctx.claude_root / name} {link}"
                        ),
                    )
                continue
            target = link.resolve()
            if not target.exists():
                yield Finding(
                    check_id=self.id,
                    severity=Severity.CRITICAL,
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(link),
                    message=f"symlink target missing: {name}",
                    details=f"readlink -> {target}",
                    fix_hint=(
                        f"ln -sf {ctx.claude_root / name} {link}"
                    ),
                )
```

- [ ] **Step 4: Update `checks/__init__.py`**

Overwrite:

```python
"""Check implementations. Importing this module populates the check registry."""

from claude_stack_audit.checks import inventory  # noqa: F401
from claude_stack_audit.checks import reliability  # noqa: F401
from claude_stack_audit.checks import observability  # noqa: F401
from claude_stack_audit.checks import documentation  # noqa: F401
from claude_stack_audit.checks import cross_cutting  # noqa: F401
```

- [ ] **Step 5: Run tests**

```bash
uv run pytest tests/test_cross_cutting.py -v
```

Expected: 2 passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/src/claude_stack_audit/checks/cross_cutting.py claude-stack-audit/src/claude_stack_audit/checks/__init__.py claude-stack-audit/tests/test_cross_cutting.py
git commit -m "feat(claude-stack-audit): add CROSS001 symlink-integrity check"
```

---

### Task 15: Integration test — full run on synthetic dotfiles

**Files:**
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/integration/__init__.py`
- Create: `/Users/godl1ke/.dotfiles/claude-stack-audit/tests/integration/test_full_run.py`

- [ ] **Step 1: Create `tests/integration/__init__.py`**

```python
```

- [ ] **Step 2: Write the integration test**

Create `tests/integration/test_full_run.py`:

```python
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

import jsonschema
import pytest

from claude_stack_audit.checks.base import Selection
from claude_stack_audit.config import Config
from claude_stack_audit.reports.json_report import SCHEMA, render as render_json
from claude_stack_audit.reports.markdown import render as render_markdown
from claude_stack_audit.runner import run


pytestmark = pytest.mark.integration


def test_full_run_on_synthetic_dotfiles_produces_valid_report(
    fake_dotfiles: Path, fake_external_tools, tmp_path
):
    config = Config(
        dotfiles_root=fake_dotfiles,
        output_dir=tmp_path / "out",
        selection=Selection(),
    )
    report = run(config, external=fake_external_tools, now=datetime(2026, 4, 17, tzinfo=timezone.utc))

    # JSON schema-valid
    jsonschema.validate(instance=render_json(report), schema=SCHEMA)

    # Markdown non-empty
    md = render_markdown(report)
    assert "Claude Stack Audit" in md
    assert "Health score" in md

    # Each registered check ran (or emitted META)
    check_ids = {f.check_id for f in report.findings}
    # INV001 always emits (fixture has hooks)
    assert "INV001" in check_ids


def test_full_run_records_meta_finding_when_check_raises(
    fake_dotfiles: Path, fake_external_tools, tmp_path, monkeypatch
):
    from claude_stack_audit.checks.base import register, clear_registry_for_tests
    from claude_stack_audit.models import Criterion, Layer

    clear_registry_for_tests()

    @register
    class AlwaysCrash:
        id = "TCRASH"
        name = "always crash"
        criterion = Criterion.RELIABILITY
        layer = Layer.AUTOMATION

        def run(self, ctx):
            raise RuntimeError("boom")

    config = Config(
        dotfiles_root=fake_dotfiles,
        output_dir=tmp_path / "out",
        selection=Selection(),
    )
    report = run(config, external=fake_external_tools)
    metas = [f for f in report.findings if f.check_id == "META001"]
    assert len(metas) == 1
```

- [ ] **Step 3: Run**

```bash
uv run pytest tests/integration/ -v
```

Expected: 2 passed.

- [ ] **Step 4: Run the full test suite**

```bash
uv run pytest --cov=claude_stack_audit --cov-report=term-missing
```

Expected: all tests pass, coverage on `checks/` ≥ 90%. If coverage is under 90%, inspect missing branches and add targeted tests before proceeding.

- [ ] **Step 5: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add claude-stack-audit/tests/integration/__init__.py claude-stack-audit/tests/integration/test_full_run.py
git commit -m "test(claude-stack-audit): add full-run integration tests"
```

---

### Task 16: Brewfile + install.sh updates

**Files:**
- Modify: `/Users/godl1ke/.dotfiles/Brewfile`
- Modify: `/Users/godl1ke/.dotfiles/install.sh`

- [ ] **Step 1: Inspect `Brewfile` for existing entries**

```bash
grep -E '^brew "(shellcheck|jq)"' /Users/godl1ke/.dotfiles/Brewfile || echo "neither present"
```

- [ ] **Step 2: Add missing entries**

If `shellcheck` is absent, append `brew "shellcheck"` to the appropriate section of `/Users/godl1ke/.dotfiles/Brewfile`. If `jq` is absent, append `brew "jq"`. Use the Edit tool — do not blindly echo — to place them near other CLI tool entries.

- [ ] **Step 3: Inspect `install.sh`**

```bash
cat /Users/godl1ke/.dotfiles/install.sh
```

Look for the existing install flow. Find an appropriate place (typically after brew bundle and before the Claude symlink setup) for the audit tool install step.

- [ ] **Step 4: Append the audit-tool install step**

Add a block like this near the end of `install.sh`, using the Edit tool:

```bash
# ---------- claude-stack-audit ----------
if command -v uv >/dev/null 2>&1; then
  if [[ -d "$HOME/.dotfiles/claude-stack-audit" ]]; then
    uv tool install -e "$HOME/.dotfiles/claude-stack-audit" --force
  fi
else
  echo "warning: uv not found; skipping claude-stack-audit install" >&2
fi
```

(Use the Edit tool with the matching surrounding context — do not overwrite the whole file.)

- [ ] **Step 5: Run the install locally to verify**

```bash
uv tool install -e /Users/godl1ke/.dotfiles/claude-stack-audit --force
which cstack-audit
cstack-audit --version
```

Expected: `cstack-audit` resolves in `$PATH` (likely `~/.local/bin/cstack-audit`) and prints `0.1.0`.

- [ ] **Step 6: Commit**

```bash
cd /Users/godl1ke/.dotfiles
git add Brewfile install.sh
git commit -m "chore(claude-stack-audit): wire into Brewfile + install.sh"
```

---

### Task 17: Baseline audit on real dotfiles

**Files:**
- Will create (via tool run): `/Users/godl1ke/.dotfiles/docs/superpowers/audits/2026-04-17-stack-audit.md`
- Will create (via tool run): `/Users/godl1ke/.dotfiles/docs/superpowers/audits/2026-04-17-stack-audit.json`

- [ ] **Step 1: Run `validate`**

```bash
cstack-audit validate
```

Expected: `ok: environment ready`. If `shellcheck` or `jq` is missing, run `brew bundle --file ~/.dotfiles/Brewfile` and retry.

- [ ] **Step 2: Run `list-checks`**

```bash
cstack-audit list-checks
```

Expected output lists the 5 MVP checks:

```
INV001     inventory      automation  hook inventory
REL001     reliability    automation  shellcheck clean
OBS001     observability  automation  log path consistency
DOC001     documentation  automation  script header present
CROSS001   cross_cutting  core        symlink integrity
```

- [ ] **Step 3: Run the baseline audit**

```bash
mkdir -p /Users/godl1ke/.dotfiles/docs/superpowers/audits
cstack-audit run
```

Expected:
- Exit code 0, 1, or 3 (not 2).
- Two files written under `~/.dotfiles/docs/superpowers/audits/2026-04-17-stack-audit.*`.
- Summary printed to stderr with finding counts and score.

- [ ] **Step 4: Sanity-check the baseline report**

```bash
cat /Users/godl1ke/.dotfiles/docs/superpowers/audits/2026-04-17-stack-audit.md | head -60
jq '.schema_version, .score, (.findings | length)' /Users/godl1ke/.dotfiles/docs/superpowers/audits/2026-04-17-stack-audit.json
```

Expected: markdown rendered correctly; JSON has `schema_version == "1"`, an integer score, and an integer finding count.

- [ ] **Step 5: Commit the baseline report to git**

```bash
cd /Users/godl1ke/.dotfiles
git add docs/superpowers/audits/2026-04-17-stack-audit.md docs/superpowers/audits/2026-04-17-stack-audit.json
git commit -m "docs(claude-stack-audit): capture baseline audit report"
```

- [ ] **Step 6: Review findings + plan next phase**

Read the top of the markdown report. Expect Critical/High findings — these are real issues, not tool bugs. Pick 3 High findings to seed the next phase plan (phase 2 starts with INV002–INV007; fixes come from their own brainstorming cycles).

---

## Self-Review

**1. Spec coverage** — mapping each spec section to tasks:

| Spec section | Covered by |
|--------------|-----------|
| §1 Context | Plan header (goal + scope) |
| §2 Architecture & Project Layout | Task 1, "File Structure" section |
| §3 Data Model | Task 2 |
| §4 Check Catalogue (MVP subset: 5 checks) | Tasks 10–14 |
| §4 Full catalogue (remaining 28) | Out of scope this plan — phases 2–5 |
| §5 Check Contract & Registration | Task 5 |
| §6 Execution Flow | Task 6 |
| §7 Report Formats | Tasks 7 (markdown) + 8 (JSON) |
| §8 Error Handling | Task 3 (ExternalTools), Task 6 (META findings), Task 9 (CLI exit codes) |
| §9 Testing Strategy | Tasks 2–15 all TDD; Task 15 integration; coverage gate in Task 15 step 4 |
| §10 Integration Surface | Task 16 (Brewfile + install.sh); slash command + pre-commit deferred to phase 5 |
| §11 Files to Create | Task 1 and all following |
| §12 Files to Modify | Task 16 |
| §13 Out of Scope / Future Upgrades | Header scope table |
| §14 Open Questions | None — spec resolved them all |
| §15 Success Criteria | Tasks 15 (criteria 1), 17 (criteria 2, 3, 4) |

**Gap noted:** Spec success criterion 5 (slash command) and 6 (pre-commit) are correctly deferred to phase 5 and marked as such in the scope table.

**2. Placeholder scan** — searched the plan for red-flag patterns (TBD, TODO, "implement later", "add appropriate error handling", "similar to Task N"). None present. Every code step shows the actual code.

**3. Type consistency check** — spot-verified across tasks:

- `Finding` fields used consistently: `check_id`, `severity`, `layer`, `criterion`, `artifact`, `message`, `details`, `fix_hint`. ✓
- `Context` fields used consistently across Task 4 (definition) and Tasks 10–14 (consumers): `claude_root`, `bash_scripts`, `settings.hook_events`, `file_cache`, `external`. ✓
- `Severity`, `Layer`, `Criterion` enum members match between `models.py` and all check implementations. ✓
- `ToolResult` shape consistent between `external.py` (Task 3) and `test_reliability.py` fake registration (Task 11). ✓
- `Selection.quick` semantics (Task 5) match `--quick` CLI option (Task 9). ✓
- CLI exit codes (Task 9) match spec §8. ✓

**4. Ambiguity check** — one wording improvement made inline during review:

- Task 12 OBS001 originally conflated "unapproved absolute path" with "non-`/tmp` absolute path." Clarified: `/tmp`/`/var/tmp` is High (explicit data-loss risk on reboot), other unapproved paths are Medium.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-17-claude-stack-audit-foundation.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Each subagent gets the task's section + the spec. Best for 17 tasks of this size.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints for review. Uses more of your context window but you see every step directly.

**Which approach?**
