# =============================================================================
# Project CLAUDE.md Template
# =============================================================================
# WHY: Each project gets its own CLAUDE.md (under 80 lines) with project-
# specific context. This supplements the global ~/.claude/CLAUDE.md.
# Copy to each project root and customise the placeholders.
#
# Location: <project-root>/CLAUDE.md
# =============================================================================

# PROJECT_NAME — BRIEF_DESCRIPTION

FastAPI APPLICATION_TYPE. SQLAlchemy 2.x + Alembic. PostgreSQL 16. Python 3.13.

## Commands
- `uv run fastapi dev` — development server
- `uv run pytest --tb=short -q` — run tests
- `uv run ruff format .` — format code
- `uv run ruff check --fix .` — lint + autofix
- `uv run alembic upgrade head` — apply migrations
- `uv run alembic revision --autogenerate -m "description"` — create migration
- `docker compose up -d` — start local services (PostgreSQL, Redis)
- `docker compose down` — stop local services

## Architecture
- Repository pattern: routes → services → repositories → models
- `app/api/` — route handlers (thin — delegate to services)
- `app/services/` — business logic (no direct DB access)
- `app/repositories/` — database queries (SQLAlchemy)
- `app/models/` — SQLAlchemy ORM models
- `app/schemas/` — Pydantic request/response schemas
- `app/core/` — config, security, dependencies
- `tests/` — mirrors app/ structure (test_*.py)

## Conventions
- All endpoints require Pydantic request/response schemas
- Use dependency injection for DB sessions: `Depends(get_db)`
- Async everywhere: `async def` endpoints, async SQLAlchemy sessions
- Error responses use standard schema: `{"detail": "message", "code": "ERROR_CODE"}`
- Logging via structlog — never use print() or logging.basicConfig()

## Security
- Never hardcode credentials. Use environment variables via `app/core/config.py`
- All endpoints require authentication unless explicitly marked public
- Validate all input via Pydantic — never trust raw request data
- Use parameterised queries — never string-format SQL

## Gotchas
- [Add project-specific gotchas as you discover them]
- [Example: "Auth module has retry logic — don't simplify it"]
- [Example: "Alembic env.py uses custom async engine — see comments"]
