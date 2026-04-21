#!/usr/bin/env bats
# =============================================================================
# launchagents.bats — Regression tests for launchd plist configuration
# =============================================================================
# Run with: bats tests/launchagents.bats
#
# Ensures all com.godl1ke.*.plist files use a bash 4+ binary rather than
# Apple's frozen bash 3.2 (/bin/bash), which breaks declare -A and other
# bash 4/5 features. See: fix/launchd-bash-version (PR #128).

DOTFILES="$BATS_TEST_DIRNAME/.."
LAUNCHAGENTS_SRC="$DOTFILES/claude/launchagents"

fail() {
  echo "$@" >&2
  return 1
}

@test "launchd plists do not use Apple bash 3.2 (/bin/bash)" {
  local found_any=0
  for plist in "$LAUNCHAGENTS_SRC"/com.godl1ke.*.plist; do
    [[ -f "$plist" ]] || continue
    found_any=1
    if grep -q '<string>/bin/bash</string>' "$plist"; then
      fail "$(basename "$plist") uses /bin/bash (Apple 3.2); switch to /opt/homebrew/opt/bash/bin/bash or similar bash 4+"
    fi
  done
  [[ "$found_any" -eq 1 ]] || fail "No com.godl1ke.*.plist files found under $LAUNCHAGENTS_SRC"
}

@test "launchd plists use a bash binary that exists on disk" {
  for plist in "$LAUNCHAGENTS_SRC"/com.godl1ke.*.plist; do
    [[ -f "$plist" ]] || continue
    # Use plutil to extract the first ProgramArguments entry (the interpreter)
    bash_bin=$(plutil -extract ProgramArguments.0 raw "$plist" 2>/dev/null)
    [[ -n "$bash_bin" ]] || fail "$(basename "$plist"): could not parse bash binary from ProgramArguments"
    [[ -x "$bash_bin" ]] \
      || fail "$(basename "$plist"): declared bash binary '$bash_bin' is not executable (does it exist?)"
  done
}

@test "launchd plists use bash 4+ (version check)" {
  for plist in "$LAUNCHAGENTS_SRC"/com.godl1ke.*.plist; do
    [[ -f "$plist" ]] || continue
    bash_bin=$(plutil -extract ProgramArguments.0 raw "$plist" 2>/dev/null)
    [[ -x "$bash_bin" ]] || continue  # already caught by previous test
    version=$("$bash_bin" --version 2>&1 | head -1 | grep -oE 'version [0-9]+' | grep -oE '[0-9]+')
    [[ -n "$version" ]] || fail "$(basename "$plist"): could not parse version from '$bash_bin --version'"
    [[ "$version" -ge 4 ]] \
      || fail "$(basename "$plist"): bash_bin '$bash_bin' is version $version (need 4+)"
  done
}

@test "launchd plists all have StandardErrorPath set" {
  for plist in "$LAUNCHAGENTS_SRC"/com.godl1ke.*.plist; do
    [[ -f "$plist" ]] || continue
    grep -q '<key>StandardErrorPath</key>' "$plist" \
      || fail "$(basename "$plist"): missing StandardErrorPath — errors will be silent"
  done
}
