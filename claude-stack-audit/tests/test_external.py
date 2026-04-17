from claude_stack_audit.external import ExternalTools


def test_run_captures_stdout_stderr_and_returncode():
    tools = ExternalTools()
    r = tools.run(["sh", "-c", "echo hello; echo err 1>&2; exit 3"])
    assert r.returncode == 3
    assert "hello" in r.stdout
    assert "err" in r.stderr
    assert r.duration_ms >= 0
    assert r.timed_out is False


def test_run_reports_timeout_with_str_fields_not_bytes():
    tools = ExternalTools(default_timeout=0.1)
    r = tools.run(["sh", "-c", "echo partial; sleep 2"])
    assert r.timed_out is True
    assert r.returncode == -1
    # Critical: fields must be str, not bytes, even on the timeout path.
    assert isinstance(r.stdout, str)
    assert isinstance(r.stderr, str)
    assert "[timeout after" in r.stderr


def test_run_returns_127_for_missing_binary():
    tools = ExternalTools()
    r = tools.run(["definitely-not-a-real-binary-xyz"])
    assert r.timed_out is False
    assert r.returncode == 127
    assert r.stderr


def test_run_returns_126_for_non_executable_file(tmp_path):
    script = tmp_path / "not-executable.sh"
    script.write_text("#!/bin/bash\necho hi\n")
    # Intentionally do NOT chmod +x
    script.chmod(0o644)
    tools = ExternalTools()
    r = tools.run([str(script)])
    assert r.timed_out is False
    assert r.returncode == 126
    assert r.stderr


def test_version_returns_first_line_on_success():
    tools = ExternalTools()
    v = tools.version(["sh", "-c", "echo 'tool 1.2.3'; echo extra"])
    assert v == "tool 1.2.3"


def test_version_returns_none_on_non_zero():
    tools = ExternalTools()
    v = tools.version(["sh", "-c", "exit 1"])
    assert v is None


def test_version_returns_none_on_whitespace_only_output():
    tools = ExternalTools()
    v = tools.version(["sh", "-c", "printf '   \\n   \\n'"])
    assert v is None
