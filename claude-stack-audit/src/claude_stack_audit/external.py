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
