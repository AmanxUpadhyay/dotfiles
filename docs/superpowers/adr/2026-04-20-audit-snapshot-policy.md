# ADR: Audit snapshot policy — canonical single file on main

**Date:** 2026-04-20
**Status:** Accepted
**Triggered by:** PR #107 and PR #108 both committed
`docs/superpowers/audits/2026-04-18-stack-audit.{md,json}` with different
content, producing an add/add merge conflict resolved manually. The broader
issue: audit snapshots are work-in-progress artefacts treated as canonical
shared state.

## Decision (one sentence)

**Audit reports are written to a single canonical path — `docs/superpowers/audits/stack-audit.{md,json}` — always overwritten, never dated; tagged runs use `stack-audit--<tag>.{md,json}` with the same overwrite semantics.**

## Context

The collision vector is the date in the filename. `Config.output_md`
(pre-change) produced `f"{date.today().isoformat()}-stack-audit{suffix}.md"`.
Any two branches running the tool on the same day produced filename-identical
snapshots — add/add on merge was guaranteed whenever both branches committed
the output.

Before this change the repo carried four dated snapshots
(`2026-04-17`..`2026-04-20`), each with 1-4 commits in its history. The
"trend" everyone assumes is there was thin: most entries were mid-development
baselines, not a steady-state signal.

### Who actually consumes audit files

- **`/audit` slash command and ad-hoc `cstack-audit run`**: want a stable
  output path so the command's "read the latest markdown" step is trivial.
- **Future-self checking trend**: wants dense history on a single file
  (`git log -p` on one path) rather than sparse history across N dated files.
- **PR reviewers on GitHub**: in practice rarely inspect the audit diff.
  The 2026-04-18 incident was a **merge** problem, not a review problem.
- **v1.2 scheduled scorecard cron**: wants one deterministic path to write
  to; date-stamped paths create filename explosion across its lifetime.

None of these consumers benefit from per-branch or per-run artefacts. The
date in the filename was serving no audience.

## Decision in detail

### Path policy

- **Default run (`cstack-audit run`)**: writes
  `docs/superpowers/audits/stack-audit.{md,json}`. Always overwritten.
- **Tagged run (`cstack-audit run --tag <tag>`)**: writes
  `docs/superpowers/audits/stack-audit--<tag>.{md,json}`. Also always
  overwritten (within that tag). The `--tag` mechanism keeps its
  A/B-comparison purpose: `cstack-audit run --tag before` → fix → `cstack-audit run`
  → diff the two files.
- **No date anywhere in the filename.** Date is git metadata; putting it in
  the filename duplicates state and creates the collision surface.

### History strategy

The single canonical file captures trend via `git log -p docs/superpowers/audits/stack-audit.md`.
Commits that intentionally refresh the baseline should say so in the
commit message. Ad-hoc PR-triggered refreshes are fine but not required —
the file's value is the **current** audit state plus the historical
delta-chain, not per-PR staleness.

### Collision handling

Add/add is impossible on a single-path file. The remaining failure mode is
a content merge conflict when two branches both modify `stack-audit.md`.
Resolution is trivial: take either side (or `git checkout --theirs`), then
run `cstack-audit run` on the merged tree to produce the post-merge truth.
The report is deterministic from tree state, so no information is lost.

### Migration

All four pre-existing dated snapshots are removed in the same PR:

- `docs/superpowers/audits/2026-04-17-stack-audit.{md,json}`
- `docs/superpowers/audits/2026-04-18-stack-audit.{md,json}`
- `docs/superpowers/audits/2026-04-19-stack-audit.{md,json}`
- `docs/superpowers/audits/2026-04-20-stack-audit.{md,json}`

They are recoverable for archaeology via `git log -p --follow` pre-dating
the deletion commit. Re-running `cstack-audit run` on main after merge
produces the first canonical `stack-audit.{md,json}` under the new policy.

## Consequences

### Positive

- **Zero collision surface.** Add/add cannot occur on a fixed path. Content
  conflicts are trivially resolvable (deterministic re-run).
- **Denser trend.** `git log -p docs/superpowers/audits/stack-audit.md`
  walks every refresh commit in one view. Blame on severity-count regressions
  becomes directly navigable.
- **Cleaner PR diffs.** When a PR re-runs the tool, the reviewer sees a
  single unified diff on one file, not a new dated file plus deleting old.
- **v1.2 cron gets a clean write path** for free — no further design.
- **Reduces cognitive load.** One file, one path, one policy. No questions
  about "which date is the current truth?".

### Negative

- **Loses the "specific day" framing** in the filename. Not material; commit
  dates cover this.
- **Single file is large in blame view.** The `.md` is ~20KB; `git blame`
  works but a tree-of-files would be smaller per-file. Traded for the
  denser trend this enables.
- **Archived dated files are lost from the tree.** Intentional: they were
  not a steady-state artefact and their value is retrievable via git history
  if ever needed.

## Alternatives considered

- **(b) Branch-slug filenames** (`YYYY-MM-DD-stack-audit--<branch>.{md,json}`).
  Rejected: zero-collision by construction, but creates an ongoing cleanup
  burden (delete-on-merge hook? prune cron?) — itself a design decision
  we would forever tweak. The marginal review benefit of per-branch
  snapshots does not justify the clutter.
- **(c) Gitignore audits entirely.** Rejected: loses reviewer visibility
  and leaves the future scorecard cron with nowhere to write, without
  delivering a working replacement sink. Premature given no existing
  dashboard or external store.
- **(d) Hybrid: gitignore on feature branches, canonical file on main,
  written by a post-merge hook or cron.** Rejected: adds automation glue
  (hook or cron) for marginal benefit over (a). (a) already lets any branch
  commit to the canonical file directly; the merge conflict path is trivial.

## Assumptions

Chosen without explicit user confirmation per the session's operating rules
("If I haven't responded to the recommendation before you move on, assume
my answer is whichever option you judged best"). Recommendation recorded
above under **Alternatives considered**; this ADR documents the choice as
Accepted so future readers have the trail.

## Implementation notes

Changes landing in the same PR as this ADR (separate commit):

- `claude-stack-audit/src/claude_stack_audit/config.py` — `Config.output_md`
  / `output_json` properties drop the date prefix; tagged output keeps the
  `--<tag>` suffix.
- `claude-stack-audit/tests/test_config.py` — new tests pinning the
  filename shape under both default and tagged runs.
- `docs/superpowers/runbooks/stack-audit.md` — update "Reports land in…"
  line to reflect the new path and the trend-via-`git log -p` guidance.
- `claude/commands/audit.md` — update the `/audit` slash command's
  "read the latest markdown report at …" step to the new canonical path.
- Delete the four historical dated snapshot pairs above; the post-merge
  `cstack-audit run` produces the first canonical file under the new
  policy.

## Related

- ADR `2026-04-18-python-audit-tool.md` — tool design; this ADR refines its
  output-path decision.
- ADR `2026-04-20-pre-pr-gate-consistency.md` — PR #111; same incident
  family (methodology self-consistency).
- ADR `2026-04-20-subagent-self-verification.md` — PR #112; design
  principle 4 from `runbooks/stack-audit.md` ("snapshots should be
  git-tracked, not ephemeral") is respected by this ADR — the canonical
  file is still git-tracked; only the per-date framing is removed.
- Runbook: `docs/superpowers/runbooks/stack-audit.md` (updated by the
  implementation commit).
