"""Observability checks (OBS001–OBS006). Phase 1 ships OBS001 only."""

from __future__ import annotations

import os
import re
import shlex
from collections.abc import Iterable
from pathlib import Path

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

# Rule 1 — variable-name intent signals. Writes whose target variable
# matches any of these tokens (case-insensitive word-boundary) are
# product output, not logs. LOG is deliberately excluded.
_PRODUCT_VAR_TOKENS_RE = re.compile(r"\b(NOTE|BREADCRUMB|DOC|VAULT_NOTE)\b", re.IGNORECASE)

# Rule 2 — document/product file extensions on the resolved path.
_PRODUCT_EXTENSIONS = (".md", ".html", ".htm")

# Rule 3 — known product-root prefixes (Obsidian / iCloud vaults).
_PRODUCT_ROOT_PREFIXES = (
    "$OBSIDIAN_VAULT",
    "${OBSIDIAN_VAULT",
    "~/Library/Mobile Documents/",
    "$HOME/Library/Mobile Documents/",
    "iCloud Drive",
)

# Rule 4 — inline escape hatch: `# audit-ignore: OBS001[, OBS002[, ...]]`
# The ID block must be the FIRST IDs after the colon (optionally followed
# by `—`/`-`/any free-text reason). Reason is not parser-enforced — see
# spec 2026-04-21-obs001-heuristic-upgrade.md.
_ESCAPE_HATCH_RE = re.compile(
    r"#\s*audit-ignore:\s*(?P<ids>[A-Z]{3,5}\d{3}(?:[\s,]+[A-Z]{3,5}\d{3})*)"
)

# Match redirects or tee into files: > /path, >> /path, 2> /path, tee /path
_LOG_WRITE_RE = re.compile(r"""(?:>>?|2>>?|\|\s*tee(?:\s+-a)?)\s+("?)(?P<path>\S+?)\1(?:\s|$)""")

# Extract the leading $VAR / ${VAR} name from a raw path (no resolution).
_LEADING_VAR_RE = re.compile(
    r"^\$(?:\{([A-Za-z_][A-Za-z0-9_]*)(?::-|:=|\})|([A-Za-z_][A-Za-z0-9_]*))"
)


_VAR_ASSIGN_RE = re.compile(
    r"""^\s*(?:export\s+|local\s+|readonly\s+)?([A-Za-z_][A-Za-z0-9_]*)=(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'|(\S+))""",
    re.MULTILINE,
)
_VAR_REF_RE = re.compile(r"^\$(?:\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))")


def _collect_script_vars(body: str) -> dict[str, str]:
    """Build a dict of VAR → raw RHS from `VAR=value` / `VAR="value"` lines."""
    vars_: dict[str, str] = {}
    for m in _VAR_ASSIGN_RE.finditer(body):
        name = m.group(1)
        value = m.group(2) or m.group(3) or m.group(4) or ""
        vars_[name] = value
    return vars_


def _resolve_path_vars(path: str, script_vars: dict[str, str], depth: int = 0) -> str:
    """Replace the leading `$VAR` / `${VAR}` with its RHS; iterate up to depth 5.
    Only substitutes the prefix — the rest of the path is preserved."""
    if depth > 5:
        return path
    m = _VAR_REF_RE.match(path)
    if m is None:
        return path
    var_name = m.group(1) or m.group(2)
    if var_name not in script_vars:
        return path
    resolved = script_vars[var_name] + path[m.end() :]
    return _resolve_path_vars(resolved, script_vars, depth + 1)


def _leading_var_name(raw_path: str) -> str | None:
    m = _LEADING_VAR_RE.match(raw_path)
    if m is None:
        return None
    return m.group(1) or m.group(2)


def _escape_hatch_applies(lines: list[str], line_idx: int, check_id: str) -> bool:
    """Return True when `# audit-ignore: <check_id>` sits on the redirect
    line or within the 3 preceding lines. Comma/whitespace-separated IDs
    are honoured; unrelated IDs do not suppress."""
    start = max(0, line_idx - 3)
    for i in range(start, line_idx + 1):
        m = _ESCAPE_HATCH_RE.search(lines[i])
        if m is None:
            continue
        ids = re.split(r"[\s,]+", m.group("ids").strip())
        if check_id in ids:
            return True
    return False


@register
class LogPathConsistency:
    """OBS001 — flag shell redirects/tees that write to non-approved log paths.

    The check filters out product-output writes (notes, breadcrumbs, HTML)
    before classifying severity. Four rules apply in order:

    1. Variable-name intent signals (`NOTE`, `BREADCRUMB`, `DOC`, `VAULT_NOTE`).
    2. Document extensions on the resolved path (`.md`, `.html`, `.htm`).
    3. Product-root prefixes (`$OBSIDIAN_VAULT`, iCloud).
    4. Inline escape hatch: `# audit-ignore: OBS001 <reason>` on the
       redirect line or up to 3 lines above it. Reason is a convention,
       not parser-enforced.

    See `docs/superpowers/specs/2026-04-21-obs001-heuristic-upgrade.md`."""

    id = "OBS001"
    name = "log path consistency"
    criterion = Criterion.OBSERVABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            body = ctx.file_cache.read(script)
            script_vars = _collect_script_vars(body)
            lines = body.splitlines()
            # Precompute cumulative line-start offsets for match-to-line mapping.
            line_starts: list[int] = [0]
            for ln in lines:
                line_starts.append(line_starts[-1] + len(ln) + 1)
            for m in _LOG_WRITE_RE.finditer(body):
                raw_path = m.group("path")
                path = _resolve_path_vars(raw_path, script_vars)
                if path.startswith(_APPROVED_PREFIXES):
                    continue

                # Rule 1: variable-name intent signal.
                var_name = _leading_var_name(raw_path)
                if var_name and _PRODUCT_VAR_TOKENS_RE.search(var_name):
                    continue

                # Rule 2: document/product extension on resolved path.
                if path.lower().endswith(_PRODUCT_EXTENSIONS):
                    continue

                # Rule 3: product-root prefix.
                if path.startswith(_PRODUCT_ROOT_PREFIXES):
                    continue

                # Rule 4: inline escape hatch.
                line_idx = _offset_to_line_idx(m.start(), line_starts)
                if _escape_hatch_applies(lines, line_idx, self.id):
                    continue

                if path.startswith(("/tmp/", "/var/tmp/")):
                    severity = Severity.HIGH
                elif path.startswith(("$", "~")) or path.startswith("/"):
                    severity = Severity.MEDIUM
                else:
                    continue  # relative path; skip (probably not a log file)
                yield Finding(
                    check_id=self.id,
                    severity=severity,
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(script.relative_to(ctx.claude_root.parent)),
                    message=f"log write to non-approved path: {raw_path}",
                    details=f"resolved: {path}" if path != raw_path else None,
                    fix_hint=(
                        "Use one of: $CLAUDE_LOG_DIR, ~/Library/Logs/claude-crons/, "
                        "or ~/.claude/logs/ instead of ad-hoc paths. "
                        "If this write is product output, rename the variable "
                        "to include NOTE/BREADCRUMB/DOC, use a .md/.html "
                        "extension, or add `# audit-ignore: OBS001 <reason>` "
                        "on the redirect line."
                    ),
                )


def _offset_to_line_idx(offset: int, line_starts: list[int]) -> int:
    """Binary-search the 0-based line index containing `offset` in a body
    whose `line_starts` is the cumulative per-line byte offsets."""
    lo, hi = 0, len(line_starts) - 1
    while lo < hi:
        mid = (lo + hi) // 2
        if line_starts[mid + 1] <= offset:
            lo = mid + 1
        else:
            hi = mid
    return lo


@register
class StdoutCaptureWithTimestamp:
    id = "OBS002"
    name = "stdout capture with timestamp"
    criterion = Criterion.OBSERVABILITY
    layer = Layer.AUTOMATION

    _TIMESTAMP_MARKERS = ("date ", "%F", "%T", "%s", " ts ", " ts\n", "iso")

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            body = ctx.file_cache.read(script)
            if "$CLAUDE_BIN" not in body and "${CLAUDE_BIN" not in body:
                continue
            if any(m in body for m in self._TIMESTAMP_MARKERS):
                continue
            yield Finding(
                check_id=self.id,
                severity=Severity.MEDIUM,
                layer=self.layer,
                criterion=self.criterion,
                artifact=str(script.relative_to(ctx.claude_root.parent)),
                message="claude invocation without timestamped output capture",
                details=None,
                fix_hint=(
                    "Pipe stdout/stderr through `ts '%Y-%m-%dT%H:%M:%S%z'` "
                    "(moreutils) or prepend `date -u +%FT%TZ` to log lines."
                ),
            )


@register
class NotifyFailureSourced:
    id = "OBS003"
    name = "cron sources notify-failure"
    criterion = Criterion.OBSERVABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        crons_dir = ctx.claude_root / "crons"
        if not crons_dir.is_dir():
            return
        for script in sorted(crons_dir.glob("*.sh")):
            body = ctx.file_cache.read(script)
            if "notify-failure" in body:
                continue
            yield Finding(
                check_id=self.id,
                severity=Severity.HIGH,
                layer=self.layer,
                criterion=self.criterion,
                artifact=str(script.relative_to(ctx.claude_root.parent)),
                message="cron does not source notify-failure.sh",
                details=None,
                fix_hint=(
                    'Add `source "$HOME/.dotfiles/claude/crons/notify-failure.sh"` '
                    "near the top and call `notify_failure` from an ERR trap."
                ),
            )


@register
class DurationStatusMarkers:
    id = "OBS004"
    name = "cron emits duration/status markers"
    criterion = Criterion.OBSERVABILITY
    layer = Layer.AUTOMATION

    _MARKERS = ("duration_ms", "duration=", "status=done", "status=ok", "status=fail")

    def run(self, ctx: Context) -> Iterable[Finding]:
        crons_dir = ctx.claude_root / "crons"
        if not crons_dir.is_dir():
            return
        for script in sorted(crons_dir.glob("*.sh")):
            body = ctx.file_cache.read(script)
            if any(marker in body for marker in self._MARKERS):
                continue
            yield Finding(
                check_id=self.id,
                severity=Severity.MEDIUM,
                layer=self.layer,
                criterion=self.criterion,
                artifact=str(script.relative_to(ctx.claude_root.parent)),
                message="cron does not emit duration/status markers",
                details=None,
                fix_hint=(
                    "Log lines like `duration_ms=1234 status=ok` on completion "
                    "so metrics scrapers can track runs."
                ),
            )


@register
class LogRotationPolicy:
    id = "OBS005"
    name = "log rotation policy exists"
    criterion = Criterion.OBSERVABILITY
    layer = Layer.AUTOMATION

    _ROTATION_MARKERS = ("logrotate", "rotate_logs", "-mtime", "gzip")

    def run(self, ctx: Context) -> Iterable[Finding]:
        for script in ctx.bash_scripts:
            body = ctx.file_cache.read(script)
            if any(m in body for m in self._ROTATION_MARKERS):
                return  # at least one script handles rotation; no finding
        yield Finding(
            check_id=self.id,
            severity=Severity.MEDIUM,
            layer=self.layer,
            criterion=self.criterion,
            artifact=str(ctx.claude_root),
            message="no log rotation script found in dotfiles",
            details=None,
            fix_hint=(
                "Add a cron script that rotates logs in "
                "~/Library/Logs/claude-crons/ (e.g. `find -mtime +30 -delete` "
                "or gzip/logrotate)."
            ),
        )


@register
class HookHandlerExists:
    id = "OBS006"
    name = "hook handler resolves"
    criterion = Criterion.OBSERVABILITY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for event_name, entries in (ctx.settings.hook_events or {}).items():
            for entry in entries or []:
                for hook in entry.get("hooks", []) or []:
                    cmd = hook.get("command", "")
                    if not cmd:
                        continue
                    resolved = self._resolve(cmd, ctx)
                    if resolved is None or resolved.is_file():
                        continue
                    yield Finding(
                        check_id=self.id,
                        severity=Severity.HIGH,
                        layer=self.layer,
                        criterion=self.criterion,
                        artifact=cmd,
                        message=f"{event_name} hook command does not resolve",
                        details=f"expected: {resolved}",
                        fix_hint=(
                            "Fix the command path in settings.json or create the handler script."
                        ),
                    )

    @staticmethod
    def _resolve(cmd: str, ctx: Context) -> Path | None:
        """Extract the script path from a hook command and resolve it.

        Claude Code settings.json stores the full shell invocation, e.g.
        `bash "$HOME/.claude/hooks/X.sh"`. We extract the .sh argument, expand
        $HOME/~ vars, and return the resolved Path. Returns None when the
        command doesn't invoke a .sh script (inline bash — nothing to verify)."""
        try:
            parts = shlex.split(cmd)
        except ValueError:
            parts = [cmd]
        script_arg = next((p for p in reversed(parts) if p.endswith(".sh")), None)
        if script_arg is None:
            return None
        expanded = os.path.expandvars(os.path.expanduser(script_arg))
        if expanded.startswith("/"):
            return Path(expanded)
        return ctx.claude_root / expanded
