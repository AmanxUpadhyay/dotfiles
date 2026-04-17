# ADR — Python + uv for the claude-stack-audit tool (not bash)

**Date**: 2026-04-18
**Status**: Accepted
**Deciders**: Aman

---

## Context

The dotfiles ecosystem is almost entirely bash (hooks, cron scripts, install
scripts, healthchecks). A new tool was needed to audit that ecosystem against
reliability, observability, and documentation criteria — emitting a
prioritised report and machine-readable JSON.

The natural first instinct was "more bash." Two options were evaluated:

**A. Lean bash script (`audit.sh`)** — one script that greps for patterns and
dumps markdown.

**B. Python package (`claude-stack-audit`) with `uv` + `pytest` + `ruff`.**

---

## Decision

Python. Specifically: a `uv`-managed package at `~/.dotfiles/claude-stack-audit/`
exposing a `cstack-audit` CLI, with `pytest` for tests and `ruff` for lint/format.

## Rationale

1. **Testability is the decisive factor.** The tool itself should meet the
   testing standard it enforces on hook/cron scripts. Bash is notoriously hard
   to unit-test without adding another framework (bats). Python + pytest is
   trivial. The tool has 108+ tests at the time of v1 shipping; an equivalent
   bash implementation would have ~0 — a credibility gap we refused to create.

2. **Structured data output is a requirement.** The tool must emit schema-versioned
   JSON alongside markdown so future consumers (scorecard cron, dashboards,
   CI gates) can read it without re-parsing prose. bash + jq assembly of the
   full Report shape is fragile; Python dataclasses + `json.dumps` with a
   `jsonschema` validator is direct.

3. **Extensibility matters.** The catalogue started at 5 checks and grew to 33
   in four phases. Each new check is a class implementing a `Check` protocol
   that registers itself. Adding a check in bash would have required growing
   one monolithic file; Python gives us one module per check with isolated
   tests.

4. **The subprocess boundary is the right place for a typed wrapper.** The
   tool shells out to `shellcheck`, `jq`, `launchctl`, and `git`. A central
   `ExternalTools` adapter with timeout + typed `ToolResult` catches the
   timeout-bytes and permission-error classes of bug that surface once and
   cost hours; equivalent defensive patterns in bash are copy-pasted per
   script and go stale.

5. **The wider dotfiles stack already uses Python for anything non-trivial**
   (via `uv`). Adding this tool doesn't introduce a new toolchain.

## Consequences

**Positive**
- Test-driven development on a central quality tool.
- Coverage gate (currently 90% on `checks/`) is enforced in CI-reachable form.
- JSON output enables the v1.2 scorecard cron and the v1.3 HTML dashboard
  without rewriting the spine.
- Pre-commit gate gets a dependable fast-path.

**Negative**
- External dependency chain: `uv` must be installed. `install.sh` guards this
  with `command -v uv`, but the tool is absent on any machine without uv.
- Python start-up cost: a few hundred ms per invocation. For a quick
  pre-commit gate this was measured at < 400ms end-to-end and deemed
  acceptable.
- One more boundary between the shell ecosystem and the auditor. Mitigated by
  `ExternalTools`: shelling out stays testable via `FakeExternalTools`.

## Alternatives considered

- **Pure bash (`audit.sh`)** — rejected: untestable in the relevant sense,
  fragile JSON assembly, O(n) complexity growth as checks are added.
- **Hybrid (bash dispatcher + Python analyser)** — rejected: two build/test
  stories, two dependency surfaces, no clear win over Python.

## Related

- Spec: `docs/superpowers/specs/2026-04-17-claude-stack-audit-tool-design.md`
- Phase plans: `docs/superpowers/plans/2026-04-*-claude-stack-audit-*.md`
- Runbook: `docs/superpowers/runbooks/stack-audit.md`
