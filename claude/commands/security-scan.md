# =============================================================================
# /security-scan — Security Vulnerability & Secrets Check (calibrated)
# =============================================================================
# WHY: Automated security review. Calibrated per project type so shell-heavy
# and Python-CLI repos get vector-specific checks (subprocess injection,
# osascript injection, eval/source hygiene) instead of FastAPI-shaped
# nothings. Run before every PR — the pr-gate hook also runs a lighter
# secrets sweep.
#
# Usage: /security-scan
# Location: ~/.claude/commands/security-scan.md
# Design:   docs/superpowers/adr/2026-04-21-security-scan-calibration.md
# =============================================================================

Perform a calibrated security scan of this project.

## Step 0 — Detect project type (fingerprints)

Run these fingerprint probes first. Record which layers apply; each layer's
checks run only when its fingerprint is present. Layers are additive (a
repo can be both Python and shell, e.g. this dotfiles repo).

- **FastAPI layer** — applies if any of:
  `grep -rEn 'fastapi' pyproject.toml requirements*.txt 2>/dev/null`
  or `grep -rEn '^from fastapi|^import fastapi' --include='*.py' .`
- **Python-CLI layer** — applies if `pyproject.toml` or `setup.py` is present
  (runs regardless of FastAPI; covers shared Python vectors).
- **Shell layer** — applies if any tracked `*.sh` or shebang-shell file:
  `git ls-files | grep -E '\.(sh|bash|zsh)$'`
  or `git grep -lE '^#!/(usr/)?(bin|usr/bin)/(env )?(sh|bash|zsh)'`

Report the detected layers at the top of the findings (e.g.
`Detected layers: universal + python-cli + shell`).

## Step 1 — Universal base (always runs)

1. **Secrets in code** — search every tracked file:
   - `git grep -nE '(api[_-]?key|secret|password|token|AWS_SECRET)[[:space:]]*=[[:space:]]*["'"'"'][A-Za-z0-9_\-]{8,}'`
   - Private keys: `git grep -nE 'BEGIN (RSA|EC|OPENSSH|DSA) PRIVATE KEY'`
   - Connection strings with embedded credentials:
     `git grep -nE '(postgres|mysql|mongodb|redis)://[^:]+:[^@]+@'`
   - Hardcoded bearer tokens / auth headers: `git grep -nE 'Authorization: (Bearer|Basic) [A-Za-z0-9_\-\.=]+'`
2. **`.env` hygiene** — confirm `.env` is gitignored:
   `git check-ignore .env 2>/dev/null && echo OK || echo "MISSING .env in .gitignore"`
   and ensure `.env.example` exists if the project uses environment config.
3. **Dependency CVEs** — if `pyproject.toml` present:
   `pip-audit --strict` (falls back to `uv pip audit` or
   `uv run pip-audit --strict` if the project uses uv). If `package.json`,
   run `npm audit --production`. If neither, skip and say so.

## Step 2 — Shell layer (runs if shell fingerprint matched)

Target set: `git ls-files | grep -E '\.(sh|bash|zsh)$'` plus any shebang-shell
files. Run each check and report findings by severity.

1. **Static analysis** — `shellcheck -S warning <targets>`. Treat SC2086
   (unquoted variable expansion), SC2046 (unquoted `$()`), SC2068 (unquoted
   array expansion), and any SC20xx rule tagged *security* as 🔴 CRITICAL
   when the unquoted value comes from an env var, hook input, or command
   argument.
2. **AppleScript / osascript injection**:
   `git grep -nE 'osascript -e .*\$[A-Za-z_]'`
   For each hit, verify the interpolated variable is either (a) not
   attacker-controlled or (b) escaped via `printf '%q'` / passed as a
   separate `-e` argument. Direct `"... $var ..."` string interpolation into
   an AppleScript literal is 🔴 CRITICAL.
3. **Dynamic evaluation**:
   `git grep -nE '^(\s*)(eval|source) +"\$'`
   `git grep -nE '\beval +[^"]'` — any `eval` on a non-literal is 🔴 CRITICAL
   unless the input is provably a fixed set of strings.
4. **Piped installers / code fetches**:
   `git grep -nE 'curl [^|]*\| *(sh|bash|zsh)'`
   `git grep -nE 'wget [^|]*\| *(sh|bash|zsh)'` — 🟡 WARNING; document the
   trust boundary or pin a SHA.
5. **Hygiene**:
   - Missing `set -euo pipefail` on scripts that run anything non-trivial:
     `for f in $(git ls-files '*.sh'); do head -3 "$f" | grep -q 'set -[eu]' || echo "missing pipefail: $f"; done`
   - Predictable `/tmp/$name` paths (TOCTOU):
     `git grep -nE '/tmp/[A-Za-z0-9_.\-]+'` — prefer `mktemp`. 🟡 WARNING.
   - World-writable output (`chmod 777`, missing `umask` on secret writes):
     `git grep -nE 'chmod ([0-7]?777|a\+w)'` — 🔴 CRITICAL if the file may
     hold credentials.

## Step 3 — Python-CLI layer (runs if pyproject.toml/setup.py present)

Target set: `git ls-files '*.py'`.

1. **Subprocess / shell injection**:
   `git grep -nE 'shell=True' -- '*.py'` — 🔴 CRITICAL when the command is
   built from user/config input. List form + `shell=False` is safe.
   `git grep -nE '\bos\.(system|popen)\b' -- '*.py'` — same severity.
2. **Deserialisation foot-guns**:
   `git grep -nE '\bpickle\.loads?\(' -- '*.py'` — 🔴 CRITICAL unless input
   is provably produced by the same trust boundary.
   `git grep -nE '\byaml\.load\(' -- '*.py'` — 🟡 WARNING if not using
   `SafeLoader`; recommend `yaml.safe_load`.
3. **Dynamic evaluation**:
   `git grep -nE '\b(eval|exec)\(' -- '*.py'` — 🔴 CRITICAL unless argument
   is a hardcoded literal.
4. **Race-prone temp files**:
   `git grep -nE '\btempfile\.mktemp\(' -- '*.py'` — 🟡 WARNING; prefer
   `NamedTemporaryFile` / `mkstemp`.
5. **Path traversal**:
   `git grep -nE 'open\([^)]*(input|argv|params|request)' -- '*.py'` — 🟡
   WARNING; confirm `Path(...).resolve()` + base-dir containment.

## Step 4 — FastAPI layer (runs if FastAPI fingerprint matched)

1. **SQL injection**: f-strings in queries, `text()` without bound params:
   `git grep -nE 'execute\(f["'"'"']|text\(f["'"'"']' -- '*.py'` — 🔴 CRITICAL.
2. **Endpoint auth**: list routes without a `Depends(...)` auth dependency;
   inspect `@app.post|put|delete` handlers for missing auth.
3. **CORS**: `git grep -nE 'allow_origins\s*=\s*\[["'"'"']\*' -- '*.py'` — 🔴
   in production configs; 🟡 in dev.
4. **Rate limiting**: login / password-reset / token endpoints without a
   rate-limit decorator or middleware — 🟡 WARNING.
5. **Debug / HTTPS**: `DEBUG=True` in production env, missing
   `HTTPSRedirectMiddleware`, missing `HSTS` — 🟡 WARNING.
6. **Input validation**: endpoints typed as raw `dict` / `Any` instead of
   Pydantic models; unbounded file uploads; missing pagination on list
   endpoints — 🟡 WARNING.
7. **Auth & sessions**: JWT without `exp`, missing permission checks on
   mutating operations, session fixation — 🔴 CRITICAL for missing expiry.

## Reporting

Present findings grouped by severity:

- 🔴 **CRITICAL** — must fix before merge (secrets, shell/AppleScript/
  Python subprocess injection, `eval`/`exec` on untrusted input, SQLi,
  JWT without expiry, world-writable credential files).
- 🟡 **WARNING** — should fix soon (hygiene, validation gaps, deprecated
  APIs, predictable temp paths).
- 🔵 **INFO** — best-practice notes.

End with:

- Detected layers (universal + <layers>).
- Total findings by severity.
- PASS / FAIL verdict for PR readiness (FAIL if any 🔴).
- When running in a plan/execute workflow, also emit follow-up task IDs for
  anything not fixed in the current branch, per the session rule "don't fix
  new findings surfaced by a calibration run — track as follow-ups".
