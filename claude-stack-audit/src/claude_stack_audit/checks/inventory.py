"""Inventory checks (INV001–INV007). Phase 1 ships INV001 only."""

from __future__ import annotations

from collections.abc import Iterable

from claude_stack_audit.checks.base import register
from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer, Severity


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
