"""Inventory checks (INV001–INV007). Phase 1 ships INV001. Phase 2 adds INV002–INV007."""

from __future__ import annotations

import re
from collections.abc import Iterable

from claude_stack_audit.checks.base import register
from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer, Severity

_LABEL_RE = re.compile(r"<key>\s*Label\s*</key>\s*<string>([^<]+)</string>", re.IGNORECASE)


@register
class HookInventory:
    id = "INV001"
    name = "hook inventory"
    criterion = Criterion.INVENTORY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        hooks = ctx.settings.hook_events or {}
        for event_name, entries in hooks.items():
            for entry in entries or []:
                for hook in entry.get("hooks", []) or []:
                    cmd = hook.get("command", "")
                    yield Finding(
                        check_id=self.id,
                        severity=Severity.INFO,
                        layer=self.layer,
                        criterion=self.criterion,
                        artifact=cmd or f"<event:{event_name}>",
                        message=f"{event_name} hook → {cmd}",
                        details=None,
                        fix_hint=None,
                    )


@register
class CronInventory:
    id = "INV002"
    name = "cron inventory"
    criterion = Criterion.INVENTORY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for entry in ctx.crontab:
            yield Finding(
                check_id=self.id,
                severity=Severity.INFO,
                layer=self.layer,
                criterion=self.criterion,
                artifact=entry.script,
                message=f"cron {entry.schedule} → {entry.script}",
                details=None,
                fix_hint=None,
            )


@register
class LaunchAgentInventory:
    id = "INV003"
    name = "launchagent inventory"
    criterion = Criterion.INVENTORY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        launchagents_dir = ctx.claude_root / "launchagents"
        if not launchagents_dir.is_dir():
            return
        loaded_labels = self._loaded_labels(ctx)
        for plist in sorted(launchagents_dir.glob("*.plist")):
            body = plist.read_text()
            m = _LABEL_RE.search(body)
            label = m.group(1) if m else plist.stem
            state = "loaded" if label in loaded_labels else "unloaded"
            yield Finding(
                check_id=self.id,
                severity=Severity.INFO,
                layer=self.layer,
                criterion=self.criterion,
                artifact=str(plist.relative_to(ctx.claude_root.parent)),
                message=f"launchagent {label} ({state})",
                details=None,
                fix_hint=None,
            )

    def _loaded_labels(self, ctx: Context) -> set[str]:
        r = ctx.external.run(["launchctl", "list"], timeout=5.0)
        if r.returncode != 0:
            return set()
        labels: set[str] = set()
        for line in r.stdout.splitlines()[1:]:  # skip header row
            parts = line.split("\t")
            if len(parts) >= 3:
                labels.add(parts[2].strip())
        return labels


@register
class AgentCommandInventory:
    id = "INV004"
    name = "agent and command inventory"
    criterion = Criterion.INVENTORY
    layer = Layer.AUTOMATION

    def run(self, ctx: Context) -> Iterable[Finding]:
        for kind, subdir in (("agent", "agents"), ("command", "commands")):
            directory = ctx.claude_root / subdir
            if not directory.is_dir():
                continue
            for md in sorted(directory.glob("*.md")):
                yield Finding(
                    check_id=self.id,
                    severity=Severity.INFO,
                    layer=self.layer,
                    criterion=self.criterion,
                    artifact=str(md.relative_to(ctx.claude_root.parent)),
                    message=f"{kind} {md.stem}",
                    details=None,
                    fix_hint=None,
                )


@register
class McpServerInventory:
    id = "INV005"
    name = "mcp server inventory"
    criterion = Criterion.INVENTORY
    layer = Layer.CORE

    def run(self, ctx: Context) -> Iterable[Finding]:
        servers = ctx.settings.raw.get("mcpServers", {}) or {}
        if not isinstance(servers, dict):
            return
        for name, spec in servers.items():
            transport = self._transport(spec)
            yield Finding(
                check_id=self.id,
                severity=Severity.INFO,
                layer=self.layer,
                criterion=self.criterion,
                artifact=f"mcp:{name}",
                message=f"{name} ({transport})",
                details=None,
                fix_hint=None,
            )

    @staticmethod
    def _transport(spec: object) -> str:
        if not isinstance(spec, dict):
            return "unknown"
        if "command" in spec:
            return "stdio"
        if "url" in spec:
            return "http"
        return "unknown"
