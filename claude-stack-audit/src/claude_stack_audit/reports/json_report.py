"""Machine-facing JSON renderer. Schema-versioned; consumers refuse unknown versions."""

from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

from claude_stack_audit.models import Inventory, Report, Severity

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


def _inventory_to_dict(inv: Inventory) -> dict:
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
    path.write_text(json.dumps(render(report), indent=2) + "\n", encoding="utf-8")
