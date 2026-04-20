# ADR: Subagent self-verification discipline — literal output, not summaries

**Date:** 2026-04-20
**Status:** Accepted
**Triggered by:** PR #108 audit (PR #111's investigation closed the
narrow `pr-gate.sh` bypass; this ADR closes the wider class — how the
orchestrator trusted an unverifiable subagent claim in the first place)

## Context

The dotfiles methodology uses subagents (via `superpowers:subagent-driven-development`)
to parallelise implementation work. Each subagent returns a summary to the
orchestrator, which then commits and opens a PR on behalf of the batch.

In PR #108, a subagent summary stated "all gates passed" after its implementation
step. The orchestrator trusted the summary and merged. The final state carried
an F821 `Undefined name 'Path'` in `reliability.py:70`. Two defects conspired:

1. **The gate itself was silently bypassed** — fixed in PR #111 (`if ! VAR=$(cmd)`
   pattern + EXIT-trap sentinel). See ADR `2026-04-20-pre-pr-gate-consistency.md`.
2. **The subagent's self-report was unverifiable** — the orchestrator saw "gates
   passed" but no evidence. Even had the gate worked, a future subagent could
   still fabricate a summary, misread output, or report against an earlier
   state than what it finally staged.

This ADR addresses defect (2). It is the **wider** fix: no matter what the
next bypass mechanism is, tamper-evident reports prevent the orchestrator from
trusting unverifiable claims.

## Decision

**Subagent reports must paste the literal output of verification commands,
captured against the final staged state, not a summary.** The pattern is
mechanical, not judgment-based.

### The pattern

Every subagent whose output the orchestrator will act on (merge, commit,
open PR, mark task complete) must end its report with a **Verification**
section structured as:

````markdown
## Verification

Commands re-run against final staged state (after all edits applied):

```
$ uv run ruff check .
<last 20 lines of literal output, including exit code>
```

```
$ uv run pytest -q
<last 20 lines of literal output, including exit code>
```

```
$ git status --short
<literal output showing the files actually staged>
```

If any output looks cached or stale (e.g. "X files unchanged"), I re-ran
with cache-busting flags (`--no-cache`, `--cache-clear`) and pasted that
output instead.
````

### Rules for the subagent

1. **Literal output, not paraphrase.** "All checks passed" is never
   acceptable on its own. The orchestrator needs the exit code and the
   last ~20 lines of stdout/stderr.
2. **Against final staged state.** Verification commands run **after** the
   last edit is applied, not mid-execution. Any edit made after the
   verification block invalidates it — re-run and re-paste.
3. **Cache-bust on suspicion.** Ruff and pytest both cache. If output
   says "unchanged" or the timing is implausibly fast, re-run with
   `--no-cache` (ruff) or `--cache-clear` (pytest) and paste that.
4. **Never edit the pasted output.** Copy verbatim. Truncating past the
   last 20 lines is fine; redacting error lines is not.

### Rules for the orchestrator

1. **Reject reports without a Verification section.** Do not commit, merge,
   or mark a task complete based on a summary alone.
2. **Spot-check staleness.** If the pasted `git status --short` doesn't
   match the orchestrator's own pre-merge `git diff`, the subagent verified
   against a different state — reject and request re-verification.
3. **Eat the dog food.** The orchestrator itself must paste literal output
   in its final PR body. The pattern applies to every layer.

## Consequences

### Positive

- **Tamper-evident.** A fabricated or stale summary becomes obviously
  malformed (wrong file count, missing exit code, absent command).
- **Auditable post-hoc.** The PR body itself carries the proof; reviewers
  don't need to re-run the gates to know they passed.
- **Bypass-resistant.** Future defects in gate scripts (or ruff, or pytest)
  don't auto-silence: the literal output will show the symptom even if
  the exit code is wrong.

### Negative

- **Verbose reports.** Reports grow by ~40-60 lines. Trade-off accepted:
  verifiability beats brevity for load-bearing claims.
- **Slightly slower subagents.** Each subagent re-runs gates once more at
  the end (they likely ran them at least once already). Marginal cost.
- **Doesn't help non-subagent work.** Orchestrator-direct work must adopt
  the same pattern manually; no automated enforcement.

## Implementation

Scope of this ADR's first-pass rollout:

1. **`claude/commands/review.md`** — updated as the canonical exemplar
   (this repo's own gate-running prompt). New "Self-verification"
   footer demonstrates the pattern for any Claude session running
   `/review` on uncommitted changes.
2. **`docs/superpowers/runbooks/stack-audit.md`** — new "Design principles"
   section captures the general rule ("transcript-visible verification
   beats unseen checks") so the principle is discoverable from the
   audit tool that polices it.

### Deferred — upstream skill templates

The subagent dispatch templates live in the `superpowers:subagent-driven-development`
skill, installed read-only under `~/.claude/plugins/cache/`. Updating those
templates requires a change upstream (at the skill marketplace level), which
is outside this repo's scope.

**The needed upstream change:** the implementer and spec-reviewer prompt
templates shipped by the `superpowers:subagent-driven-development` skill
should carry the Verification section pattern above as a mandatory
report footer. Suggested prompt addition, to be proposed upstream:

> Before returning your final report, re-run the verification commands
> against the final staged state of your work and paste the literal last
> ~20 lines of output for each. A summary is never sufficient. If any
> output looks cached, cache-bust and re-paste. See
> `docs/superpowers/adr/2026-04-20-subagent-self-verification.md` for
> the full pattern.

Until that lands, orchestrators using superpowers subagents in this
repo must append the Verification requirement to their dispatch prompt
explicitly. Exemplar: the implementer prompt should include:

```
After completing your changes, and before reporting back, append a
## Verification section to your report that pastes the literal output
of `uv run ruff check`, `uv run pytest -q`, and `git status --short`
against your final staged state. Summaries are not acceptable.
```

## Validation

This ADR itself is committed alongside the first rollout (`review.md`
update + runbook principles section). The orchestrator's own PR body
for `chore/close-gate-causal-chain` pastes literal gate output —
eating the dog food in the same session the rule is written.

## Related

- ADR `2026-04-20-pre-pr-gate-consistency.md` — the narrow `pr-gate.sh`
  bypass (defect 1 above).
- PR #111 — narrow fix merged.
- `docs/superpowers/runbooks/stack-audit.md` § Design principles — the
  general principle captured in the runbook.
- Upstream skill: `superpowers:subagent-driven-development`.
