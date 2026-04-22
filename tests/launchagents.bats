#!/usr/bin/env bats
# =============================================================================
# launchagents.bats — Regression tests for launchd plist configuration
# =============================================================================
# Narrow-scope successor to PR #128. Only plists whose target script actually
# uses bash 4+ features are required to point at Homebrew bash — the rest
# stay on /bin/bash to avoid unnecessary Homebrew dependency and FDA re-grants
# on every `brew upgrade bash`.
#
# Currently the only bash-4-dependent script is mac-cleanup-scan.sh
# (uses `declare -A`). If another cron adds bash 4+ features later, add it
# to the BASH4_SCRIPTS list below.
#
# Run with: bats tests/launchagents.bats

DOTFILES="$BATS_TEST_DIRNAME/.."
LAUNCHAGENTS_SRC="$DOTFILES/claude/launchagents"

# Basenames (without .sh) of scripts that REQUIRE bash 4+ features.
BASH4_SCRIPTS=("mac-cleanup-scan.sh")

fail() {
  echo "$@" >&2
  return 1
}

@test "mac-cleanup-scan.plist points at a bash 4+ binary (declare -A dependency)" {
  local plist="$LAUNCHAGENTS_SRC/com.godl1ke.claude.mac-cleanup-scan.plist"
  [[ -f "$plist" ]] || fail "plist missing: $plist"

  local bash_bin
  bash_bin=$(plutil -extract ProgramArguments.0 raw "$plist" 2>/dev/null)
  [[ -n "$bash_bin" ]] || fail "could not parse bash binary from $plist"

  # Must NOT be /bin/bash (Apple 3.2)
  [[ "$bash_bin" != "/bin/bash" ]] \
    || fail "mac-cleanup-scan.plist still uses /bin/bash — mac-cleanup-scan.sh's \`declare -A\` will crash under Apple bash 3.2"

  # Binary must exist and be executable
  [[ -x "$bash_bin" ]] \
    || fail "declared bash binary '$bash_bin' is not executable"

  # Must report bash major version >= 4
  local version
  version=$("$bash_bin" --version 2>&1 | head -1 | grep -oE 'version [0-9]+' | grep -oE '[0-9]+')
  [[ -n "$version" ]] || fail "could not parse version from '$bash_bin --version'"
  [[ "$version" -ge 4 ]] \
    || fail "bash at '$bash_bin' is version $version (need >= 4 for declare -A)"
}

@test "mac-cleanup-scan.sh actually uses declare -A (justifies bash 4+ requirement)" {
  # Guard against future refactors that remove the declare -A usage — if the
  # dependency goes away, we can revert the plist to /bin/bash and drop the
  # Homebrew dep. This test fails loudly in that case, prompting the revert.
  run grep -n "declare -A" "$DOTFILES/claude/crons/mac-cleanup-scan.sh"
  [ "$status" -eq 0 ] \
    || fail "mac-cleanup-scan.sh no longer uses \`declare -A\` — Homebrew bash dependency is now unnecessary; consider reverting the plist to /bin/bash"
}

@test "other live plists can safely stay on /bin/bash (no bash 4 features)" {
  # Static check: for every live plist that isn't mac-cleanup-scan, confirm
  # its target script has no bash 4+ features. Keeps the narrow-scope
  # promise: we only pay the Homebrew dep cost where the feature is used.
  local bash4_needles=("declare -A" "\\*\\*" "readarray" "mapfile")
  for plist in "$LAUNCHAGENTS_SRC"/com.godl1ke.*.plist; do
    [[ -f "$plist" ]] || continue
    local name
    name=$(basename "$plist" .plist)
    [[ "$name" == "com.godl1ke.claude.mac-cleanup-scan" ]] && continue

    # Extract the target script path (ProgramArguments.1)
    local script
    script=$(plutil -extract ProgramArguments.1 raw "$plist" 2>/dev/null)
    [[ -f "$script" ]] || continue

    for needle in "${bash4_needles[@]}"; do
      if grep -qE "$needle" "$script" 2>/dev/null; then
        fail "$(basename "$plist"): target '$script' uses bash 4+ feature '$needle' — add its script basename to the BASH4_SCRIPTS list and patch the plist"
      fi
    done
  done
}

@test "all live plists have StandardErrorPath set (errors never silent)" {
  for plist in "$LAUNCHAGENTS_SRC"/com.godl1ke.*.plist; do
    [[ -f "$plist" ]] || continue
    grep -q '<key>StandardErrorPath</key>' "$plist" \
      || fail "$(basename "$plist"): missing StandardErrorPath — launchd errors would go nowhere"
  done
}
