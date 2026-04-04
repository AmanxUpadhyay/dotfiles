# =============================================================================
# /deploy-check — Pre-Deployment Verification
# =============================================================================
# WHY: Before deploying to staging or production, run this checklist to
# catch issues that would cause deployment failures or runtime errors.
# Covers tests, migrations, env vars, Docker, and dependency security.
#
# Usage: /deploy-check
# Location: ~/.claude/commands/deploy-check.md
# =============================================================================

Run a comprehensive pre-deployment check for this project.

Steps:
1. **Tests**: Run the full test suite with `uv run pytest --tb=short -q`. ALL tests must pass
2. **Lint**: Run `ruff check .` — zero errors allowed
3. **Format**: Run `ruff format --check .` — verify all code is formatted
4. **Migrations**: Check Alembic for pending migrations with `uv run alembic check` or review migration history
5. **Environment variables**: Compare `.env.example` against actual usage in code — flag any missing vars
6. **Docker**: If docker-compose.yml exists, verify it builds with `docker compose config`
7. **Dependencies**: Run `pip-audit` if available to check for known vulnerabilities
8. **Git status**: Ensure working directory is clean — no uncommitted changes
9. **Branch**: Confirm you're on the correct branch for deployment (not main unless intentional)

Present results as a checklist:
- ✅ or ❌ for each check
- Details on any failures
- Clear GO / NO-GO verdict at the end

If ANY check fails, the verdict is NO-GO with specific remediation steps.
