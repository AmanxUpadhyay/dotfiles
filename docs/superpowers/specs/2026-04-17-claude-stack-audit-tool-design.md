# Claude Stack Audit Tool: Design

**Date**: 2026-04-17
**Status**: Draft
**Scope**: Design a reusable Python audit tool (`cstack-audit`) that inspects the Claude Code + dotfiles + Obsidian-pipeline stack against reliability, observability, and documentation criteria, and emits a prioritised report + machine-readable JSON.

---

## 1. Context

The Claude-Code/dotfiles/Obsidian pipeline has grown into 30+ moving artefacts: 14 hook scripts, 8 cron scripts, 4 LaunchAgents, 6 slash commands, 2 local agents, plus numerous MCP-server plugins. Most of it has been hardened reactively — the April 2026 `CLAUDE_BIN` incident (2-day silent cron failure) and the subsequent 28-issue hook audit both happened *after* things broke.

To move from reactive hardening to enterprise-grade operation, we need a repeatable, testable mechanism that inspects the stack and surfaces gaps in three areas the user ranked as top concerns:

1. **Reliability / testing** — scripts lack unit tests, some lack `set -euo pipefail`, error traps, idempotency guards.
2. **Observability** — log paths are consistent but metrics, structured logging, and failure-alert wiring are uneven.
3. **Documentation** — script headers, runbooks, and ADR coverage are partial.

A one-shot audit document would rot. An automated inspection tool that emits a structured, versioned report makes the audit *reruneable* and turns the report into the change log (via git diff on the report file).

**Goal**: Ship a Python package `claude-stack-audit` exposing a `cstack-audit` CLI that inspects the stack, emits a human-readable markdown report and a schema-versioned JSON report, and can be run locally, from a slash command, or from a pre-commit hook. Each finding carries a `fix_hint` so the report directly seeds subsequent brainstorming/spec cycles.

**Non-goals for v1**:
- Recurring/scheduled execution (v1.2).
- CI integration (v1.1).
- Vault-content audits (vault structure is stable).
- Full security scanner beyond symlink/secret checks.
- MCP server health probes.

---

## 2. Architecture & Project Layout

### Location

`~/.dotfiles/claude-stack-audit/` — sibling of `claude/`, tracked in the dotfiles git repo.

Rationale: the tool *inspects* the claude setup; it is not part of it. A sibling directory makes the observer/subject boundary obvious and lets the audit run even when `claude/` is mid-refactor.

### Package layout

```
~/.dotfiles/claude-stack-audit/
├── pyproject.toml                  # uv-managed; ruff + pytest + coverage config
├── uv.lock
├── README.md
├── src/claude_stack_audit/
│   ├── __init__.py
│   ├── __main__.py                 # python -m claude_stack_audit
│   ├── cli.py                      # Typer-based CLI
│   ├── config.py                   # paths, env loading, selection, severity overrides
│   ├── models.py                   # Finding, Severity, Layer, Criterion, Report, Context
│   ├── runner.py                   # orchestrates checks, aggregates findings, scorecard
│   ├── external.py                 # subprocess adapter with timeout + ToolResult
│   ├── checks/
│   │   ├── base.py                 # Check protocol + register decorator
│   │   ├── inventory.py            # INV001–INV007
│   │   ├── reliability.py          # REL001–REL009
│   │   ├── observability.py        # OBS001–OBS006
│   │   ├── documentation.py        # DOC001–DOC007
│   │   └── cross_cutting.py        # CROSS001–CROSS004
│   └── reports/
│       ├── markdown.py
│       └── json_report.py
└── tests/
    ├── conftest.py                 # fake_dotfiles + fake_external_tools fixtures
    ├── fixtures/
    ├── integration/test_full_run.py
    ├── test_cli.py
    ├── test_inventory.py
    ├── test_reliability.py
    ├── test_observability.py
    ├── test_documentation.py
    └── test_cross_cutting.py
```

### Toolchain

- **Package manager**: `uv` (never `pip`, per user preference).
- **Test runner**: `pytest` (no `httpx` — this is not a FastAPI project).
- **Coverage**: `pytest-cov`, enforced at `--cov-fail-under=90` for `src/claude_stack_audit/checks/`.
- **Formatter/linter**: `ruff` (`ruff check` + `ruff format`).
- **CLI framework**: `typer` (better help generation than argparse; dataclass-friendly).
- **External tools** (subprocess): `shellcheck`, `jq`, `launchctl`. Added to `~/.dotfiles/Brewfile`.

### Entry points

```
cstack-audit run                          # full audit
cstack-audit run --only reliability,docs  # subset
cstack-audit run --tag <slug>             # A/B tag for report filename
cstack-audit run --quick                  # inventory + cross_cutting only (sub-second)
cstack-audit list-checks                  # enumerate registered checks
cstack-audit validate                     # env preflight; exit 2 if tools missing
cstack-audit --version
```

Installed globally via `uv tool install -e ~/.dotfiles/claude-stack-audit`, putting `cstack-audit` at `~/.local/bin/cstack-audit`.

### What it inspects (read-only)

- `~/.dotfiles/claude/{hooks,crons,agents,commands,launchagents,prompts,templates}`
- `~/.dotfiles/claude/{settings.json, env.sh, org-map.json, crontab.txt}`
- `~/.dotfiles/docs/superpowers/` (ADR/runbook presence)
- `~/.claude/plugins/` (plugin and MCP-server manifests, version discovery)
- Symlink integrity: `~/.claude/{settings.json, env.sh, org-map.json}`

Reports written to: `~/.dotfiles/docs/superpowers/audits/YYYY-MM-DD-stack-audit.{md,json}`. Same-day reruns overwrite; `--tag <slug>` appends for A/B comparison.

---

## 3. Data Model

```python
class Severity(StrEnum):
    CRITICAL = "critical"   # weight 10
    HIGH = "high"           # weight 5
    MEDIUM = "medium"       # weight 2
    LOW = "low"             # weight 1
    INFO = "info"           # weight 0

class Layer(StrEnum):
    CORE = "core"               # settings, plugins, MCP
    AUTOMATION = "automation"   # hooks, crons, launchagents, commands
    OBSIDIAN = "obsidian"       # vault-pipeline integration

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
    artifact: str           # path or symbolic name
    message: str
    details: str | None
    fix_hint: str | None

@dataclass
class Context:
    dotfiles_root: Path
    claude_root: Path
    settings: Settings           # parsed settings.json
    env_vars: dict[str, str]     # parsed from env.sh
    org_map: OrgMap              # parsed org-map.json
    crontab: list[CronEntry]
    bash_scripts: list[Path]
    python_scripts: list[Path]
    file_cache: FileCache        # read-once LRU
    external: ExternalTools      # shellcheck, jq, launchctl adapters

@dataclass
class Report:
    generated_at: datetime
    tool_version: str
    findings: list[Finding]
    inventory: Inventory
    scorecard: Scorecard
    external_tool_versions: dict[str, str]
```

**Score formula**: `score = max(0, 1000 - Σ(severity_weight × finding_count))`. Info findings do not affect score. The scorecard gives a stable health metric whose drift is visible in `git diff` on the report.

---

## 4. Check Catalogue (MVP)

### Inventory — INV (Info severity, feeds report's "Current State" section)

| ID | Artifact | What it does |
|----|----------|--------------|
| INV001 | `hooks/*.sh` + `settings.json` | Enumerate hook scripts and event bindings |
| INV002 | `crontab.txt` | Parse schedule → script mapping |
| INV003 | `launchagents/*.plist` + `launchctl list` | Enumerate LaunchAgents and loaded state |
| INV004 | `agents/*.md` + `commands/*.md` + plugin dir | Enumerate local vs plugin-provided agents/commands |
| INV005 | `settings.json` + plugin MCP manifests | Enumerate MCP servers |
| INV006 | `~/.claude/plugins/` | Enumerate plugins with discoverable versions |
| INV007 | `env.sh` | Enumerate exported vars; flag unused vars |

### Reliability — REL

| ID | Default severity | What it checks |
|----|:----------------:|----------------|
| REL001 | High (errors) / Medium (warnings) | `shellcheck` clean on every bash script |
| REL002 | High | Every bash script has `set -euo pipefail` within lines 1–10 |
| REL003 | Medium | Every script in `~/.dotfiles/claude/crons/` has an `ERR` or `EXIT` trap |
| REL004 | High | No hardcoded `claude` path; `$CLAUDE_BIN` resolves via the April 2026 chain |
| REL005 | Medium | Cron scripts have an idempotency guard (`flock` / marker / `--skip-if-done`) |
| REL006 | Medium | Each hook/cron script has a companion test (`tests/<name>.bats` or pytest) |
| REL007 | High | Each cron job has a `.last-success-*` marker + matching healthcheck rule |
| REL008 | Medium | `subprocess`/long-running ops have explicit timeouts |
| REL009 | Low | `jq` calls use defensive defaults (`// empty`, `// []`) |

### Observability — OBS

| ID | Default severity | What it checks |
|----|:----------------:|----------------|
| OBS001 | High | All scripts log to `~/Library/Logs/claude-crons/` or `~/.claude/logs/` — none to `/tmp` |
| OBS002 | Medium | Scripts invoking `claude` capture stdout+stderr with ISO8601 timestamps |
| OBS003 | High | Every cron script sources `notify-failure.sh` (or equivalent) |
| OBS004 | Medium | Scripts emit `duration_ms=` / `status=` markers for later metric scraping |
| OBS005 | Medium | Log directories have a rotation policy (explicit script or documented manual step) |
| OBS006 | High | Every `hooks.*.command` path in `settings.json` resolves to an existing, executable file |

### Documentation — DOC

| ID | Default severity | What it checks |
|----|:----------------:|----------------|
| DOC001 | High | Every script has a header block: purpose, inputs, outputs, side-effects |
| DOC002 | Medium | `env.sh` — each exported var commented with purpose |
| DOC003 | High | `~/.dotfiles/claude/README.md` exists, explains install + component map |
| DOC004 | Medium | ADR coverage: major decisions have an ADR in `Personal/Decisions/` or `docs/superpowers/adr/` |
| DOC005 | High | Every cron job has a runbook in `docs/superpowers/runbooks/` |
| DOC006 | Medium | `crontab.txt` has per-entry comments |
| DOC007 | Medium | `settings.json` hook entries documented inline or in `docs/settings.hooks.md` |

### Cross-cutting — CROSS

| ID | Default severity | What it checks |
|----|:----------------:|----------------|
| CROSS001 | Critical | Symlinks `~/.claude/{settings.json, env.sh, org-map.json}` resolve to real files |
| CROSS002 | Medium | `settings.json` Bash permission patterns aren't overly broad (e.g. `Bash(bash:*)`) |
| CROSS003 | High | No secrets in tracked files (regex scan: `sk-`, `ghp_`, `Bearer `, etc.) |
| CROSS004 | Info | `git status --porcelain` on `~/.dotfiles/claude/` clean (flags uncommitted drift) |

**Total MVP checks**: 33 (7 inventory + 9 reliability + 6 observability + 7 documentation + 4 cross-cutting). Inventory checks emit Info-severity findings that feed the report's "Current State" section and do not affect the scorecard.

**Layer attribution**: `Layer` is a property of the *finding*, not the check class. A single check such as `REL001` (`shellcheck`) can emit findings across multiple layers depending on which script is flagged (a cron script sits in `Automation`; a cron script that writes to the vault contributes to the `Obsidian` layer when the finding is vault-related). The check decides per-finding.

---

## 5. Check Contract & Registration

```python
# checks/base.py
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

def enabled_checks(selection: Selection) -> list[Check]:
    return [c() for c in _REGISTRY if selection.includes(c)]
```

Each check is a decorated class, with one responsibility and a stable ID. Checks are pure functions of `Context`: build a fake `Context` → call `.run()` → assert findings. No filesystem mocking, no subprocess patching — the `Context` abstracts all I/O.

---

## 6. Execution Flow

```
cli.py run
  └─ config.load(args) → Config
  └─ runner.run(config)
       ├─ validate_environment()        # shellcheck/jq/launchctl present, paths readable
       ├─ Context.build(config)         # parse settings.json, env.sh, org-map.json once
       ├─ for check in enabled_checks(config.selection):
       │     try:
       │         findings += check.run(context)
       │     except Exception as exc:
       │         findings.append(META001(check.id, exc))
       ├─ sort findings (severity desc → layer → criterion → check_id → artifact)
       ├─ compute scorecard
       └─ return Report(findings, inventory, scorecard, meta)
  └─ reporters: markdown.write(report, out_md)
                json_report.write(report, out_json)
  └─ print stderr summary + report paths
```

---

## 7. Report Formats

### Markdown (human-facing)

```markdown
# Claude Stack Audit — 2026-04-17

**Health score: 823 / 1000**   *(track drift via git diff on this file)*

## Summary
| Severity | Count |
|----------|------:|
| Critical | 2 |
| High     | 12 |
| Medium   | 18 |
| Low      | 15 |
| Info     | 63 |

## Critical findings
_(table: ID, Layer, Artifact, Message, Fix hint)_

## High findings — grouped by criterion
### Reliability · 5
### Observability · 4
### Documentation · 3

## Medium / Low
_(collapsible `<details>` sections per criterion)_

## Inventory
### Hooks (14)
### Cron jobs (8)
### LaunchAgents (4)
### Slash commands (6)
### MCP servers / plugins

## Top-10 fix list
_(ordered by severity × likelihood-of-silent-failure)_

---
*cstack-audit 0.1.0 · run 2026-04-17 14:32 BST · tools: shellcheck 0.9.0, jq 1.7*
```

### JSON (machine-facing, schema-versioned)

```json
{
  "schema_version": "1",
  "generated_at": "2026-04-17T14:32:00+01:00",
  "tool_version": "0.1.0",
  "score": 823,
  "severity_counts": {"critical": 2, "high": 12, "medium": 18, "low": 15, "info": 63},
  "inventory": {
    "hooks": [{"path": "hooks/session-stop.sh", "events": ["Stop"]}],
    "crons": [{"schedule": "30 7 * * *", "script": "crons/daily-retrospective.sh"}],
    "launchagents": [{"label": "com.godl1ke.claude.healthcheck-preflight", "loaded": true}],
    "plugins": [{"name": "superpowers", "version": "5.0.7"}],
    "mcp_servers": [{"name": "obsidian", "transport": "stdio"}]
  },
  "findings": [
    {
      "check_id": "CROSS001",
      "severity": "critical",
      "layer": "core",
      "criterion": "cross_cutting",
      "artifact": "~/.claude/env.sh",
      "message": "Symlink target missing",
      "details": "readlink -> /Users/godl1ke/.dotfiles/claude/env.sh (ENOENT)",
      "fix_hint": "ln -sf ~/.dotfiles/claude/env.sh ~/.claude/env.sh"
    }
  ]
}
```

`schema_version` is explicit from v1. Later consumers (scorecard cron, dashboard) refuse unknown versions rather than silently misread.

---

## 8. Error Handling

Four layers, designed so the audit never leaves you worse off than no audit.

**Startup (`validate_environment`)** — exit 2 with actionable message if external tools missing or dotfiles root unreadable.

**`Context.build`** — malformed settings/org-map emits a Critical finding (`CROSS001` variant) *and* continues with a minimal Context so other checks still run.

**Inside checks** — subprocess never raises. `ExternalTools` wraps `subprocess.run` with `timeout=30` and returns `ToolResult(returncode, stdout, stderr, duration_ms, timed_out)`. Check classifies the result. If a check itself raises, runner emits `META001: check {id} crashed: {exc}` as a High finding and continues.

**CLI exit codes**:

| Code | Meaning |
|-----:|---------|
| 0 | Ran; no Critical/High |
| 1 | Ran; has Critical or High findings |
| 2 | Failed to run (validate) |
| 3 | One or more checks crashed (`META001`) |

---

## 9. Testing Strategy

**Framework**: `pytest` only. No `httpx` — not a FastAPI project.

**Test pyramid**:

1. **Unit (≈70%)** — one test file per criterion. Each test builds a minimal `Context` via `context_factory`, calls `check.run(ctx)`, asserts findings. `ExternalTools` injected as `FakeExternalTools` returning canned `ToolResult`s.
2. **Integration (≈20%)** — `tests/integration/test_full_run.py`. `fake_dotfiles` fixture builds a synthetic `~/.dotfiles/claude/` tree in `tmp_path` (some parts deliberately broken). Runs full `runner.run()`; asserts counts, top-N content, report-file creation, JSON-schema validity.
3. **Real smoke (≈10%, `@pytest.mark.real`, default-skipped)** — runs `cstack-audit validate` on the user's real dotfiles. Catches environment drift.

**Core fixtures (`conftest.py`)**:

```python
@pytest.fixture
def fake_dotfiles(tmp_path):
    """Build a minimal synthetic dotfiles tree.
    Scenario via marker: @pytest.mark.scenario('broken_symlink')"""
    ...

@pytest.fixture
def fake_external_tools(request):
    """Inject canned ToolResults for shellcheck/jq/launchctl."""
    ...

@pytest.fixture
def context_factory(fake_dotfiles, fake_external_tools):
    def _build(**overrides):
        return Context.build(
            dotfiles_root=fake_dotfiles,
            external=fake_external_tools,
            **overrides,
        )
    return _build
```

**Representative tests**:

```python
def test_REL001_shellcheck_clean_emits_findings_per_issue(context_factory, fake_external_tools):
    fake_external_tools.shellcheck.register(
        "hooks/foo.sh",
        ToolResult(returncode=1,
                   stdout='[{"file":"foo.sh","level":"error","message":"..."}]',
                   stderr="", duration_ms=42, timed_out=False),
    )
    ctx = context_factory(bash_scripts=[Path("hooks/foo.sh")])
    findings = list(ShellcheckClean().run(ctx))
    assert len(findings) == 1
    assert findings[0].severity == Severity.HIGH

def test_CROSS001_broken_symlink(context_factory, tmp_path):
    target = tmp_path / "missing.sh"            # deliberately absent
    link = tmp_path / ".claude/env.sh"; link.parent.mkdir()
    link.symlink_to(target)
    ctx = context_factory(claude_root=tmp_path / ".claude")
    findings = list(SymlinkIntegrity().run(ctx))
    assert findings[0].severity == Severity.CRITICAL
```

**TDD workflow** (per user's global preference): test first, check implementation after. No check lands without its test.

**Coverage target**: `--cov-fail-under=90` for `src/claude_stack_audit/checks/`.

**Linting**: `ruff check` + `ruff format` enforced via pre-commit.

---

## 10. Integration Surface

| Integration | MVP? | Why |
|-------------|:----:|-----|
| CLI (`cstack-audit`) | Yes | Primary entry point |
| Slash command `/audit` | Yes | Keeps audit in-flow during Claude Code sessions |
| Pre-commit hook (Critical-only gate) | Yes | Blocks broken symlinks / leaked secrets at commit time |
| Addition to `Brewfile` (`shellcheck`, `jq`) | Yes | Declares the tool's system dependencies |
| Addition to `refresh.sh` / `install.sh` (`uv tool install -e ...`) | Yes | Idempotent install |
| GitHub Actions CI | v1.1 | Ship tool first |
| Scheduled cron + scorecard note to vault | v1.2 | Ship tool, then automate |
| HTML dashboard | v1.3 | JSON history enables this when needed |

### Slash command `/audit`

New file `~/.dotfiles/claude/commands/audit.md`. Runs `cstack-audit run`, prints the summary line + report path, and suggests top-3 findings as seeds for `/ultraplan` or brainstorming sessions.

### Pre-commit hook

Runs `cstack-audit run --quick --only cross_cutting`. Blocks commit only on Critical findings. Opt-out via `SKIP_CSTACK=1 git commit`. Medium and Low never block — that path leads to hating the tool.

### How findings become future specs

```
cstack-audit run
  → review report; pick 3–5 High/Critical findings
  → for each finding group:
       brainstorming skill   → spec
       writing-plans skill   → implementation plan
       TDD execution         → fix lands, commit, rerun audit
  → score goes up; git diff on report IS the change log
```

---

## 11. Files to Create

| File | Purpose |
|------|---------|
| `~/.dotfiles/claude-stack-audit/pyproject.toml` | uv project config, ruff config, pytest config |
| `~/.dotfiles/claude-stack-audit/README.md` | Install, quickstart, CLI reference, contribution guide |
| `~/.dotfiles/claude-stack-audit/src/claude_stack_audit/*.py` | Package source (see layout §2) |
| `~/.dotfiles/claude-stack-audit/tests/**/*.py` | Test suite |
| `~/.dotfiles/claude/commands/audit.md` | `/audit` slash command |
| `~/.dotfiles/docs/superpowers/adr/2026-04-17-python-audit-tool.md` | ADR: why Python + uv over bash |
| `~/.dotfiles/docs/superpowers/runbooks/stack-audit.md` | Runbook: what to do when a finding fires |
| `~/.dotfiles/docs/superpowers/audits/` | Directory for generated reports |

## 12. Files to Modify

| File | Change |
|------|--------|
| `~/.dotfiles/Brewfile` | Add `brew "shellcheck"` and `brew "jq"` if absent |
| `~/.dotfiles/install.sh` or `~/.dotfiles/claude/refresh.sh` | Append idempotent `uv tool install -e ~/.dotfiles/claude-stack-audit` |
| `~/.dotfiles/pre-commit/` (or equivalent) | Add `cstack-audit run --quick --only cross_cutting` step |

---

## 13. Out of Scope / Future Upgrades

- **v1.1** — GitHub Actions workflow in dotfiles: run `pytest` on PR, full audit on `main` merge, optional drift gate on score regression.
- **v1.2** — Scheduled execution: LaunchAgent runs `cstack-audit run` weekly, writes a summary note to `06-Sessions/Personal/` with score trend.
- **v1.3** — Static HTML dashboard from the JSON-report history (`cstack-audit dashboard`); no server, renders via `file://` + Chart.js.
- **v2** — Extract check catalogue as YAML so non-Python contributors can add checks declaratively.

Each upgrade is additive — the `Context → checks → Report → reporters` spine does not change.

---

## 14. Open Questions

None remaining at spec stage. Resolved during brainstorming:

- Audit form: reusable tool with baseline report (not one-shot, not recurring — yet).
- Language: Python + `uv` + `pytest` (testability decisive over bash's proximity).
- Location: sibling `~/.dotfiles/claude-stack-audit/` (observer/subject boundary).
- Report home: `~/.dotfiles/docs/superpowers/audits/` (git-tracked, diff = change log).
- Overwrite policy: same-day overwrite default; `--tag <slug>` for A/B.
- Pre-commit gate: Critical-only (High would be too noisy for day-one adoption).
- Secrets grep: in scope as a basic regex check (`CROSS003`); full security scanner deferred to a separate tool.
- CI: v1.1, not MVP.
- Vault write: not in v1; reports live in dotfiles git.

---

## 15. Success Criteria

1. `uv run pytest` passes locally with coverage ≥ 90% on `src/claude_stack_audit/checks/`.
2. `cstack-audit run` on the real dotfiles produces a markdown report + JSON report at the expected path.
3. Baseline report shows the stack's current score; all 33 checks execute without crashing and emit at least one finding (including Info) across the real-artefact set.
4. The report's Top-10 fix list can seed at least 3 follow-up brainstorming cycles without additional investigation.
5. `/audit` slash command works from a Claude Code session.
6. Pre-commit hook blocks a test commit that contains a deliberate broken symlink or leaked secret.
