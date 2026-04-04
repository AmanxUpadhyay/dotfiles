# =============================================================================
# /security-scan — Security Vulnerability & Secrets Check
# =============================================================================
# WHY: Automated security review. Checks for leaked credentials, known
# dependency vulnerabilities, SQL injection patterns, and common FastAPI
# security misconfigurations. Run before every PR (the PR gate hook also
# does a lighter version of this automatically).
#
# Usage: /security-scan
# Location: ~/.claude/commands/security-scan.md
# =============================================================================

Perform a comprehensive security scan of this project.

Steps:

1. **Secrets in code**: Search ALL files for:
   - API keys, tokens, passwords (patterns: api_key=, secret=, password=, token=, AWS_SECRET)
   - Private keys (BEGIN RSA PRIVATE KEY, BEGIN EC PRIVATE KEY)
   - Connection strings with embedded credentials
   - Hardcoded URLs with auth tokens
   Use `grep -rn` across the codebase. Check .env files are gitignored.

2. **Dependency vulnerabilities**: Run `pip-audit --strict` if available, or check requirements against known CVE databases

3. **SQL injection**: Search for:
   - Raw SQL strings concatenated with variables (f-strings in queries)
   - `text()` calls in SQLAlchemy without bound parameters
   - Any direct string formatting in database queries

4. **FastAPI security**:
   - Endpoints missing authentication dependencies
   - CORS configured with `allow_origins=["*"]` in production
   - Missing rate limiting on sensitive endpoints (login, password reset)
   - Debug mode enabled in production configs
   - Missing HTTPS redirect

5. **Input validation**:
   - Endpoints accepting raw dict/Any instead of Pydantic models
   - File upload without size/type validation
   - Missing pagination on list endpoints (DoS risk)

6. **Authentication & authorisation**:
   - JWT without expiration
   - Missing permission checks on sensitive operations
   - Session management issues

Present findings as:
- 🔴 **CRITICAL**: Must fix before deployment (secrets, SQL injection, auth bypass)
- 🟡 **WARNING**: Should fix soon (missing validation, CORS issues)
- 🔵 **INFO**: Best practice recommendations

End with: total findings by severity and a PASS/FAIL verdict for PR readiness.
