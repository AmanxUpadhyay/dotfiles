# =============================================================================
# /test-all — Full Test Suite with Coverage Report
# =============================================================================
# WHY: Runs the entire test suite (not just related files like the auto-test
# hook does) and provides a coverage summary. Use before PRs, after major
# refactors, or when you want confidence that nothing is broken.
#
# Usage: /test-all
# Location: ~/.claude/commands/test-all.md
# =============================================================================

Run the complete test suite for this project and report results.

Steps:
1. Run `uv run pytest --tb=short -v --cov=app --cov-report=term-missing 2>&1` (or without --cov if pytest-cov is not installed)
2. If tests fail, analyse the failures:
   - Group failures by category (unit, integration, API)
   - Identify the root cause for each failure
   - Suggest specific fixes
3. If tests pass, report:
   - Total tests run, passed, skipped
   - Coverage percentage (if available)
   - Uncovered files or functions worth testing

Present as:
- **Result**: ✅ ALL PASSED or ❌ FAILURES
- **Stats**: X passed, Y failed, Z skipped
- **Coverage**: X% (if available)
- **Failures** (if any): file, test name, root cause, suggested fix
- **Coverage gaps** (if passing): files with <50% coverage worth improving
