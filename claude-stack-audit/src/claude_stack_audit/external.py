"""Subprocess adapter. Wraps subprocess.run with timeouts and returns ToolResult.
Never raises on non-zero, missing binaries, permission errors, or timeouts —
check code reads ToolResult fields and classifies outcomes."""

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


def _decode(val: bytes | str | None) -> str:
    if val is None:
        return ""
    if isinstance(val, bytes):
        return val.decode(errors="replace")
    return val


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
        effective_timeout = self.default_timeout if timeout is None else timeout
        try:
            proc = subprocess.run(
                argv,
                capture_output=True,
                text=True,
                timeout=effective_timeout,
                cwd=cwd,
                check=False,
            )
            return ToolResult(
                returncode=proc.returncode,
                stdout=proc.stdout,
                stderr=proc.stderr,
                duration_ms=_elapsed_ms(start),
                timed_out=False,
            )
        except subprocess.TimeoutExpired as exc:
            return ToolResult(
                returncode=-1,
                stdout=_decode(exc.stdout),
                stderr=_decode(exc.stderr) + f"\n[timeout after {exc.timeout}s]",
                duration_ms=_elapsed_ms(start),
                timed_out=True,
            )
        except OSError as exc:
            # Covers FileNotFoundError (127), PermissionError (126),
            # NotADirectoryError (126), and similar OS-level failures.
            returncode = 127 if isinstance(exc, FileNotFoundError) else 126
            return ToolResult(
                returncode=returncode,
                stdout="",
                stderr=str(exc),
                duration_ms=_elapsed_ms(start),
                timed_out=False,
            )

    def shellcheck(self, path: str | Path) -> ToolResult:
        return self.run(["shellcheck", "--format=json", str(path)])

    def version(self, argv: list[str]) -> str | None:
        r = self.run(argv, timeout=5.0)
        if r.returncode != 0:
            return None
        combined = (r.stdout or r.stderr).strip()
        lines = combined.splitlines()
        return lines[0] if lines else None


def _elapsed_ms(start: float) -> int:
    return int((time.monotonic() - start) * 1000)
