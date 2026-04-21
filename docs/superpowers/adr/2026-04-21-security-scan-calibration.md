# ADR: Calibrate /security-scan for non-FastAPI projects

**Date:** 2026-04-21
**Status:** Accepted
**Triggered by:** Recurring observation that `/security-scan` — as currently
written — assumes a FastAPI web project. When the target is a CLI tool
(`claude-stack-audit/`) or shell-heavy code (`claude/hooks/`), four of the six
steps yield zero signal (SQLAlchemy, CORS, JWT, Pydantic input validation),
while the threat vectors that actually exist in those codebases
(subprocess/shell injection, AppleScript injection via `osascript -e`,
`eval`/`source` on unvalidated input, `pickle.loads`/`yaml.load` foot-guns) are
not probed at all. The AppleScript injection caught earlier in
`stop-notification.sh` was found by hand, not by this skill — lucky, not
comprehensive.

## Decision (one sentence)

**`/security-scan` detects project type first, then layers checks:
a universal base (secrets, dependency CVEs, private keys) applies to every
project; shell, python-CLI, and FastAPI layers each add vector-specific
checks that are skipped when the layer's fingerprint files are absent.**

## Context

### Who consumes `/security-scan`

- **Pre-PR reflex** (per `~/.claude/CLAUDE.md`: "Before creating any PR: run
  code review AND security scan. Both must pass"). Triggered on every project,
  not only FastAPI.
- **The pr-gate hook** runs a lighter secrets sweep, so the interactive skill
  must add value beyond what the hook already enforces. On a FastAPI project
  it does; on a shell repo, pre-calibration, it effectively duplicates the
  hook and misses the actual risks.

### What the current skill encodes (file state, pre-change)

`claude/commands/security-scan.md` — 54 lines, six numbered steps:

| Step | Check | Universal? |
|------|-------|------------|
| 1 | Secrets / API keys / private keys | Yes |
| 2 | `pip-audit --strict` | Python-only (but universal within Python) |
| 3 | SQL injection: SQLAlchemy `text()`, f-strings in queries | FastAPI/SQLA-only |
| 4 | CORS `allow_origins=["*"]`, debug-mode, HTTPS redirect, rate limiting | FastAPI-only |
| 5 | Raw `dict`/`Any` in endpoints, file-upload validation, pagination | FastAPI-only |
| 6 | JWT expiry, permission checks, sessions | FastAPI-only |

### Threat vectors missing for non-FastAPI code

**Shell-heavy (`claude/hooks/`, install scripts, LaunchAgent wrappers):**

- `osascript -e "... $user_input ..."` — string interpolation into AppleScript.
  This is what bit `stop-notification.sh` and was caught ad-hoc, not by the skill.
- `eval "$var"`, `source "$var"` on unvalidated input.
- Unquoted variable expansion in command position (`$cmd` without `"…"`).
- `curl … | sh`, `wget … | bash` — installer pattern, unauditable blobs.
- Missing `set -euo pipefail` — latent failure-swallowing.
- Predictable `/tmp/$name` paths — TOCTOU / symlink races. Prefer `mktemp`.
- World-writable outputs, missing `umask` where secrets may be written.

**Python CLI (`claude-stack-audit/`, future Python tooling):**

- `subprocess.*(shell=True)` and `os.system` / `os.popen` with interpolated
  strings — the Python analogue of shell command injection.
- `pickle.loads` on untrusted bytes.
- `yaml.load` without `SafeLoader`.
- `eval` / `exec` on anything that is not a hardcoded literal.
- `tempfile.mktemp` (deprecated; race) — prefer `NamedTemporaryFile` / `mkstemp`.
- Path traversal — `open(user_input)` without `Path.resolve()` + base-dir check.

**Universal — already partly present but worth naming explicitly:**

- Secrets sweep (present).
- Private-key markers (present).
- `.env` gitignored check (present).
- Dependency audit via `pip-audit` / `uv pip audit` / `npm audit` / language-appropriate tool (present for Python only).

## Decision in detail

### Calibration model: project-type detection + layered checks

The skill reads a short fingerprint list at the top of the run:

- **FastAPI layer fingerprint**: `fastapi` in `pyproject.toml` / `requirements*.txt`,
  or any `from fastapi` import.
- **Python-CLI layer fingerprint**: `pyproject.toml` / `setup.py` present but
  no FastAPI fingerprint. (A project can also be *both* if a FastAPI app ships
  a CLI — in that case, both layers run.)
- **Shell layer fingerprint**: any tracked `*.sh` or file with `#!/*sh` shebang.

Layers are **additive**, not mutually exclusive. The universal base always
runs. The FastAPI layer only runs when FastAPI fingerprints are present —
removing the false-signal noise on non-web projects.

### Concrete tooling added

The skill now names specific commands rather than leaving tool choice to the
running model:

- `shellcheck -S warning <files>` — covers SC2086 (unquoted vars), SC2046
  (unquoted `$()`), SC2116 (useless echo), plus security-adjacent rules.
- `grep -rn 'osascript -e' <shell-dirs>` + inspect interpolation.
- `grep -rn -E 'eval |source "\$' <shell-dirs>`.
- `grep -rn -E 'shell=True|os\.system|os\.popen' <python-src>`.
- `grep -rn -E 'pickle\.loads|yaml\.load\(' <python-src>` (yaml without `SafeLoader`).
- `grep -rn -E 'tempfile\.mktemp\(' <python-src>`.
- `pip-audit --strict` / `uv pip audit` where `pyproject.toml` present.

### Why approach (a) — detection + branching — over (b)

Two approaches were weighed:

- **(a) Detect project type, branch the check list.** Adopted.
- **(b) Run universal checks always; treat FastAPI as an additive layer only.**

(b) is semantically close to (a) since both end in the same layered structure.
The difference is whether the skill *says* "detect, then branch" out loud.
For a markdown prompt artefact that a human reads and a model executes,
making the detection step explicit is clearer and more auditable — a reader
can see whether detection is correct, separate from whether each layer's
checks are correct. (b) buries detection implicitly inside each layer's
"skip if fingerprint absent" conditional, which is harder to audit.

Both approaches produce the same findings on the same tree. (a) is chosen for
prompt clarity, not for any behavioural difference.

### Non-goals for this ADR

- **Not replacing the pr-gate secrets sweep.** The hook is the hard gate; the
  skill is the interactive deeper scan. The skill may re-run the secrets grep
  for consistency, but the canonical enforcement remains in `pr-gate.sh`.
- **Not adding SAST tools (`bandit`, `semgrep`).** Those are a separate
  follow-up decision — adding them would require agreeing on an enforcement
  mode (warn vs block) and CI integration. This ADR only calibrates the
  interactive skill's coverage to match the project types we actually ship.
- **Not fixing any findings this calibration surfaces.** Per the session's
  operating rules, new findings are tracked as follow-ups; this change is a
  pure tooling calibration.

## Alternatives considered

- **(c) Split into three skills** (`/security-scan-web`, `/security-scan-cli`,
  `/security-scan-shell`). Rejected: user would have to know the project type
  and pick the right command. Auto-detection inside one command is lower
  friction and matches the "just run it" ergonomic the skill already has.
- **(d) Keep FastAPI-only and rely on `bandit`/`shellcheck` run separately.**
  Rejected: fragments the pre-PR reflex into N commands; the global preference
  says "run code review AND security scan" — one command, one verdict.
- **(e) Auto-infer layer from file-extension counts** (e.g. >60% `.sh` → shell
  mode). Rejected: brittle for mixed repos like `.dotfiles` itself, where
  shell and Python coexist and both layers should run. Explicit fingerprints
  are more robust.

## Consequences

### Positive

- **Signal-to-noise improves on non-FastAPI projects.** Shell and CLI repos
  now receive vector-specific checks instead of six FastAPI-shaped nothings.
- **Coverage gap closed for the osascript/eval/`shell=True` vectors** that
  caused the earlier `stop-notification.sh` near-miss.
- **Skill stays one command**, preserving the pre-PR ergonomic.
- **FastAPI coverage unchanged.** The layered design means every FastAPI
  check in the previous skill still runs when the FastAPI fingerprint is
  present.

### Negative

- **Longer skill file** (~120 lines vs 54). Mitigated by the layered structure
  being easy to navigate; each layer is a self-contained section.
- **Shellcheck dependency assumption.** The skill assumes `shellcheck` is on
  PATH; if absent, the shell layer prints a note and continues. Already true
  on this machine (`brew install shellcheck`), so no regression.
- **Potential false positives from broad greps** (`eval`, `yaml.load`).
  Accepted: triage is the intended workflow; the skill presents findings by
  severity, not as automated blockers.

## Implementation notes

Changes landing in the same PR as this ADR:

- `claude/commands/security-scan.md` — rewritten against the layered model
  above; adds the detection step, shell and python-CLI sections with the
  explicit tool commands listed in *Concrete tooling added*.
- This ADR at `docs/superpowers/adr/2026-04-21-security-scan-calibration.md`.
- No code changes; no test/hook changes. Calibration is tested by running the
  scan procedure against `claude/` (shell-heavy) and `claude-stack-audit/`
  (Python CLI); literal tool output is pasted in the PR body.

## Related

- ADR `2026-04-20-pre-pr-gate-consistency.md` — PR #111; the pr-gate hook is
  the hard gate upstream of this skill.
- ADR `2026-04-20-subagent-self-verification.md` — PR #112; the "paste literal
  output" discipline applied in this PR's body.
- `claude/hooks/stop-notification.sh` — the osascript-injection near-miss
  that motivated widening the skill's shell coverage.
