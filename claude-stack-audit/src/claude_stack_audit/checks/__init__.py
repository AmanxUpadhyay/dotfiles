"""Check implementations. Importing this module populates the check registry."""

from claude_stack_audit.checks import (
    cross_cutting,  # noqa: F401
    documentation,  # noqa: F401
    inventory,  # noqa: F401
    observability,  # noqa: F401
    reliability,  # noqa: F401
)
