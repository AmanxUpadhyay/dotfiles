from claude_stack_audit.external import ExternalTools


def test_run_captures_stdout_stderr_and_returncode():
    tools = ExternalTools()
    r = tools.run(["sh", "-c", "echo hello; echo err 1>&2; exit 3"])
    assert r.returncode == 3
    assert "hello" in r.stdout
    assert "err" in r.stderr
    assert r.duration_ms >= 0
    assert r.timed_out is False


def test_run_reports_timeout_without_raising():
    tools = ExternalTools(default_timeout=0.1)
    r = tools.run(["sh", "-c", "sleep 2"])
    assert r.timed_out is True
    assert r.returncode != 0


def test_run_handles_missing_executable_without_raising():
    tools = ExternalTools()
    r = tools.run(["definitely-not-a-real-binary-xyz"])
    assert r.timed_out is False
    assert r.returncode != 0
    assert r.stderr  # some error text present
