"""Check protocol and registry."""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass, field
from typing import Protocol

from claude_stack_audit.context import Context
from claude_stack_audit.models import Criterion, Finding, Layer


class Check(Protocol):
    id: str
    name: str
    criterion: Criterion
    layer: Layer

    def run(self, ctx: Context) -> Iterable[Finding]: ...


_REGISTRY: list[type[Check]] = []


def register(cls: type[Check]) -> type[Check]:
    _REGISTRY.append(cls)
    return cls


@dataclass
class Selection:
    criteria: set[Criterion] | None = field(default=None)
    quick: bool = False

    def includes(self, check: Check) -> bool:
        if self.quick and check.criterion not in {Criterion.INVENTORY, Criterion.CROSS_CUTTING}:
            return False
        return self.criteria is None or check.criterion in self.criteria


def enabled_checks(selection: Selection) -> list[Check]:
    return [c() for c in _REGISTRY if selection.includes(c())]


def all_registered_check_classes() -> list[type[Check]]:
    return list(_REGISTRY)


def clear_registry_for_tests() -> None:
    _REGISTRY.clear()
