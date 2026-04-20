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
            self._cache[key] = path.read_text(encoding="utf-8")
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

        bash_scripts = sorted(p for p in claude_root.rglob("*.sh") if p.is_file())
        python_scripts = sorted(p for p in claude_root.rglob("*.py") if p.is_file())

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
    empty = Settings(raw={}, hook_events={}, permissions={})
    if not path.exists():
        return empty
    try:
        raw = json.loads(path.read_text())
    except json.JSONDecodeError:
        return empty
    if not isinstance(raw, dict):
        return empty
    return Settings(
        raw=raw,
        hook_events=raw.get("hooks", {}),
        permissions=raw.get("permissions", {}),
    )


_EXPORT_RE = re.compile(
    r'^\s*export\s+([A-Z_][A-Z0-9_]*)=(?:"([^"]*)"|\'([^\']*)\'|(\S+)|(?=\s|$))'
)


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
    empty = OrgMap(default_org="", orgs={})
    if not path.exists():
        return empty
    try:
        raw = json.loads(path.read_text())
    except json.JSONDecodeError:
        return empty
    if not isinstance(raw, dict):
        return empty
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
