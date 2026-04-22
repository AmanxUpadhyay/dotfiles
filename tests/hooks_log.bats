#!/usr/bin/env bats
# Tests for claude/libs/hooks-log.sh — NDJSON hook-fire logger.

setup() {
  TMPLOG="$(mktemp -d)"
  export CLAUDE_LOG_DIR="$TMPLOG"
  unset _HOOKS_LOG_SOURCED
  source "${BATS_TEST_DIRNAME}/../claude/libs/hooks-log.sh"
}

teardown() {
  rm -rf "$TMPLOG"
  unset _HOOKS_LOG_SOURCED
  unset HOOKS_FIRE_LOG
}

@test "log_hook_fire writes exactly one NDJSON line" {
  log_hook_fire "TestEvent"
  [ -f "$TMPLOG/hooks-fire.log" ]
  run wc -l < "$TMPLOG/hooks-fire.log"
  [ "$output" -eq 1 ]
}

@test "log_hook_fire emits valid JSON with required fields" {
  log_hook_fire "TestEvent"

  run jq -r '.event' "$TMPLOG/hooks-fire.log"
  [ "$status" -eq 0 ]
  [ "$output" = "TestEvent" ]

  run jq -r '.pid | type' "$TMPLOG/hooks-fire.log"
  [ "$output" = "number" ]

  run jq -r '.ts' "$TMPLOG/hooks-fire.log"
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]

  run jq -r '.hook' "$TMPLOG/hooks-fire.log"
  [[ -n "$output" ]]
}

@test "log_hook_fire accepts an extra JSON object" {
  log_hook_fire "TestEvent" '{"count":5,"label":"x"}'
  run jq -r '.extra.count' "$TMPLOG/hooks-fire.log"
  [ "$output" = "5" ]
  run jq -r '.extra.label' "$TMPLOG/hooks-fire.log"
  [ "$output" = "x" ]
}

@test "default extra is an empty object when omitted" {
  log_hook_fire "TestEvent"
  run jq -r '.extra' "$TMPLOG/hooks-fire.log"
  [ "$output" = "{}" ]
}

@test "log_hook_exit suffixes the event with .exit and records exit code" {
  log_hook_exit "TestEvent" 0
  run jq -r '.event' "$TMPLOG/hooks-fire.log"
  [ "$output" = "TestEvent.exit" ]
  run jq -r '.exit_code' "$TMPLOG/hooks-fire.log"
  [ "$output" = "0" ]
}

@test "log_hook_exit records non-zero exit codes" {
  log_hook_exit "TestEvent" 127
  run jq -r '.exit_code' "$TMPLOG/hooks-fire.log"
  [ "$output" = "127" ]
}

@test "double-sourcing is idempotent (no duplicate writes)" {
  source "${BATS_TEST_DIRNAME}/../claude/libs/hooks-log.sh"
  source "${BATS_TEST_DIRNAME}/../claude/libs/hooks-log.sh"
  log_hook_fire "TestEvent"
  run wc -l < "$TMPLOG/hooks-fire.log"
  [ "$output" -eq 1 ]
}

@test "missing CLAUDE_LOG_DIR falls back to default" {
  unset _HOOKS_LOG_SOURCED
  unset CLAUDE_LOG_DIR
  source "${BATS_TEST_DIRNAME}/../claude/libs/hooks-log.sh"
  [ -n "$HOOKS_FIRE_LOG" ]
  [[ "$HOOKS_FIRE_LOG" =~ hooks-fire\.log$ ]]
}

@test "unwritable log dir does not crash the caller" {
  export CLAUDE_LOG_DIR="/var/empty/cannot-write-here-$$"
  unset _HOOKS_LOG_SOURCED
  source "${BATS_TEST_DIRNAME}/../claude/libs/hooks-log.sh"
  run log_hook_fire "TestEvent"
  [ "$status" -eq 0 ]
}

@test "NDJSON output is single-line per call (no embedded newlines)" {
  log_hook_fire "TestEvent" '{"note":"line1\nline2"}'
  run wc -l < "$TMPLOG/hooks-fire.log"
  [ "$output" -eq 1 ]
}
