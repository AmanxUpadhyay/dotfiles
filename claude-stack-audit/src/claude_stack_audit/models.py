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
