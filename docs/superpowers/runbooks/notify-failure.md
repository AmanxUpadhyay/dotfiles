# Runbook: notify-failure

## What this is

Shared library sourced by every other cron script. It is not a scheduled job — it has no launchd plist and no crontab entry. The audit tool counts it as a cron because it lives in `claude/crons/` and has a last-success marker requirement.

## Schedule

Not scheduled. `notify-failure.sh` is sourced, not executed directly. Every cron does:

```bash
source "$HOME/.dotfiles/claude/crons/notify-failure.sh"
trap 'notify_failure <script-name> "$LOGFILE"' ERR
```

## Purpose / inputs / outputs / side-effects

| Field | Detail |
|---|---|
| Purpose | Library sourced by other cron scripts; provides `notify_failure()` to send macOS notifications and write error notes to Obsidian inbox |
| Inputs | Sourced by caller scripts; `notify_failure` takes `$1=script_name` `$2=logfile_path` |
| Outputs | macOS notification dialog; markdown error note appended to `OBSIDIAN_VAULT/00-Inbox/YYYY-MM-DD-cron-error.md` |
| Side-effects | Calls `osascript` for desktop notification; writes to Obsidian vault filesystem; touches `.last-success-notify-failure` inside the function |

The `.last-success-notify-failure` marker is touched every time `notify_failure` is called successfully — semantically it marks "the notification was delivered without crashing", not "a cron succeeded".

## Failure modes

1. **`osascript` unavailable** — the notification silently fails (`|| true`). The Obsidian note is still written.
2. **`OBSIDIAN_VAULT` not set or not mounted** — the `cat >>` write to `00-Inbox/…-cron-error.md` fails. The error is swallowed; no secondary notification is sent (to avoid recursion).
3. **`notify-failure.sh` itself has an unexpected error** — its own ERR trap logs to stderr and exits 1 without calling `notify_failure` recursively.

## Recovery steps

Since this is a library, "recovery" means fixing the calling cron. To test the library in isolation:

```bash
# Source and call manually
source ~/.claude/env.sh
source ~/.dotfiles/claude/crons/notify-failure.sh
notify_failure test-script ""

# Verify the Obsidian error note was written
ls "$OBSIDIAN_VAULT/00-Inbox/"*cron-error.md

# Check last-success marker
ls -la ~/Library/Logs/claude-crons/.last-success-notify-failure
```

If a cron is failing silently (no notification arriving), check that:
1. `source …/notify-failure.sh` precedes the `trap` line in the cron script.
2. `$OBSIDIAN_VAULT` is set (run `source ~/.claude/env.sh && echo $OBSIDIAN_VAULT`).
3. The `00-Inbox/` directory exists in the vault.

## Related

- Script: `~/.dotfiles/claude/crons/notify-failure.sh`
- Used by: all other cron scripts in `claude/crons/`
- Error notes written to: `$OBSIDIAN_VAULT/00-Inbox/YYYY-MM-DD-cron-error.md`
