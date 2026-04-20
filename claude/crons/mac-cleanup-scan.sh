#!/bin/bash
set -euo pipefail
# =============================================================================
# mac-cleanup-scan.sh — Weekly Mac disk cleanup scanner
# =============================================================================
# purpose: scans known cleanup targets every Sunday at 10:00 AM; writes an Obsidian report if recoverable space >= 1 GB
# inputs: CLAUDE_LOG_DIR, OBSIDIAN_VAULT from env.sh; optional THRESHOLD_BYTES env override (default 1 GB)
# outputs: 04-Knowledge/Mac-Maintenance/YYYY-MM-DD-cleanup-scan.md written to Obsidian vault when threshold met; .last-success marker touched on success
# side-effects: no automatic deletion; notifies on failure via notify_failure
# =============================================================================

source "$HOME/.claude/env.sh"
source "$HOME/.dotfiles/claude/crons/notify-failure.sh"

_START_EPOCH=$(date +%s)
LOGFILE="$CLAUDE_LOG_DIR/mac-cleanup-scan-$(date +%Y-%m-%d).log"
trap 'notify_failure mac-cleanup-scan "${LOGFILE:-}"' ERR

if ! preflight_check "mac-cleanup-scan"; then
    notify_failure "mac-cleanup-scan-preflight" ""
    _DURATION_MS=$(( ($(date +%s) - _START_EPOCH) * 1000 ))
    echo "duration_ms=$_DURATION_MS status=fail" >> "$LOGFILE"
    exit 1
fi

DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)
NOTE_DIR="$OBSIDIAN_VAULT/04-Knowledge/Mac-Maintenance"
NOTE_PATH="$NOTE_DIR/${DATE}-cleanup-scan.md"
THRESHOLD_BYTES="${THRESHOLD_BYTES:-$(( 1 * 1024 * 1024 * 1024 ))}"  # 1 GB (overrideable via env for testing)

# ---------------------------------------------------------------------------
# dir_bytes PATH — returns size of directory in bytes, 0 if not found
# ---------------------------------------------------------------------------
dir_bytes() {
    local path="$1"
    if [[ -d "$path" ]]; then
        du -sk "$path" 2>/dev/null | awk '{print $1 * 1024; f=1} END {if (!f) print 0}' || echo 0
    else
        echo 0
    fi
}

# ---------------------------------------------------------------------------
# format_bytes N — formats bytes as "X.X GB" / "X MB" / "X KB"
# ---------------------------------------------------------------------------
format_bytes() {
    local bytes="$1"
    awk -v b="$bytes" 'BEGIN {
        if (b >= 1073741824)      printf "%.1f GB", b / 1073741824
        else if (b >= 1048576)    printf "%.0f MB",  b / 1048576
        else                      printf "%.0f KB",  b / 1024
    }'
}

# ---------------------------------------------------------------------------
# Scan targets — collect sizes and generate commands
# ---------------------------------------------------------------------------

declare -a KEYS=()
declare -A SIZES=()
declare -A LABELS=()
declare -A CMDS=()

add_target() {
    local key="$1" label="$2" bytes="$3" cmd="$4"
    if (( bytes > 0 )); then
        KEYS+=("$key")
        SIZES[$key]=$bytes
        LABELS[$key]="$label"
        CMDS[$key]="$cmd"
    fi
}

# 1. Claude VM bundle (scan full vm_bundles/ dir — auto-regenerates on next Claude desktop launch)
VM_BYTES=$(dir_bytes "$HOME/Library/Application Support/Claude/vm_bundles")
add_target "vm_bundle" "Claude VM bundle" "$VM_BYTES" \
    "rm -rf ~/Library/Application\\ Support/Claude/vm_bundles/"

# 2. Claude transcripts (JSONL only, excluding memory/)
TRANSCRIPT_BYTES=0
while IFS= read -r -d '' f; do
    sz=$(stat -f%z "$f" 2>/dev/null || echo 0)
    TRANSCRIPT_BYTES=$(( TRANSCRIPT_BYTES + sz ))
done < <(find "$HOME/.claude/projects" \
    -name "*.jsonl" \
    -not -path "*/memory/*" \
    -print0 2>/dev/null)
add_target "transcripts" "Claude transcripts (.jsonl)" "$TRANSCRIPT_BYTES" \
    "find ~/.claude/projects -name '*.jsonl' -not -path '*/memory/*' -delete"

# 3. uv cache
UV_BYTES=$(dir_bytes "$HOME/.cache/uv")
add_target "uv_cache" "uv package cache" "$UV_BYTES" "uv cache clean"

# 4. npm cache
NPM_BYTES=$(dir_bytes "$HOME/.npm")
add_target "npm_cache" "npm cache (~/.npm)" "$NPM_BYTES" \
    "npm cache clean --force && rm -rf ~/.npm"

# 5. Stale claude-mem plugin versions (all but highest semver)
PLUGIN_DIR="$HOME/.claude/plugins/cache/thedotmack/claude-mem"
STALE_BYTES=0
STALE_CMD_LINES=""
if [[ -d "$PLUGIN_DIR" ]]; then
    CURRENT_VER=$(for p in "$PLUGIN_DIR"/*/; do [[ -d "$p" ]] && basename "$p"; done 2>/dev/null | sort -V | tail -1)
    if [[ -n "$CURRENT_VER" ]]; then
        for ver_path in "$PLUGIN_DIR"/*/; do
            [[ -d "$ver_path" ]] || continue
            ver=$(basename "$ver_path")
            [[ "$ver" == "$CURRENT_VER" ]] && continue
            sz=$(dir_bytes "$ver_path")
            STALE_BYTES=$(( STALE_BYTES + sz ))
            STALE_CMD_LINES+="rm -rf ~/.claude/plugins/cache/thedotmack/claude-mem/${ver}"$'\n'
        done
    fi
fi
if (( STALE_BYTES > 0 )); then
    add_target "stale_plugins" "Stale claude-mem plugin versions" "$STALE_BYTES" \
        "${STALE_CMD_LINES%$'\n'}"
fi

# 6. Known-safe system caches
SYS_BYTES=0
SYS_CMD_LINES=""
for cache_name in SiriTTS GeoServices Homebrew com.apple.helpd; do
    p="$HOME/Library/Caches/$cache_name"
    sz=$(dir_bytes "$p")
    if (( sz > 0 )); then
        SYS_BYTES=$(( SYS_BYTES + sz ))
        SYS_CMD_LINES+="rm -rf ~/Library/Caches/${cache_name}"$'\n'
    fi
done
if (( SYS_BYTES > 0 )); then
    add_target "sys_caches" "System caches (SiriTTS, GeoServices, Homebrew, helpd)" \
        "$SYS_BYTES" "${SYS_CMD_LINES%$'\n'}"
fi

# 7. Puppeteer
PUPPET_BYTES=$(dir_bytes "$HOME/.cache/puppeteer")
add_target "puppeteer" "Puppeteer headless Chrome" "$PUPPET_BYTES" \
    "rm -rf ~/.cache/puppeteer"

# ---------------------------------------------------------------------------
# Compute total — exit silently if below threshold
# ---------------------------------------------------------------------------
TOTAL_BYTES=0
for key in "${KEYS[@]+"${KEYS[@]}"}"; do
    TOTAL_BYTES=$(( TOTAL_BYTES + SIZES[$key] ))
done

if (( TOTAL_BYTES < THRESHOLD_BYTES )); then
    touch "$CLAUDE_LOG_DIR/.last-success-mac-cleanup-scan"
    _DURATION_MS=$(( ($(date +%s) - _START_EPOCH) * 1000 ))
    echo "duration_ms=$_DURATION_MS status=ok" >> "$LOGFILE"
    exit 0
fi

TOTAL_HUMAN=$(format_bytes "$TOTAL_BYTES")

# ---------------------------------------------------------------------------
# Write Obsidian note
# ---------------------------------------------------------------------------
mkdir -p "$NOTE_DIR"

{
    cat <<FRONTMATTER
---
date: ${DATE}
type: maintenance
tags: [maintenance, mac-cleanup]
---

# Mac Cleanup Scan — ${DATE}

**Total recoverable:** ${TOTAL_HUMAN}
**Scan time:** ${DATE} ${TIME}

## What Was Found

| Category | Size | Safe to delete? |
|---|---|---|
FRONTMATTER

    for key in "${KEYS[@]}"; do
        human=$(format_bytes "${SIZES[$key]}")
        echo "| ${LABELS[$key]} | ${human} | ✅ Auto-regenerates |"
    done

    cat <<COMMANDS_HEADER

## Ready-to-Run Commands

Copy-paste each block into your terminal:

\`\`\`bash
COMMANDS_HEADER

    for key in "${KEYS[@]}"; do
        human=$(format_bytes "${SIZES[$key]}")
        echo "# ${LABELS[$key]} (${human})"
        echo "${CMDS[$key]}"
        echo ""
    done

    cat <<FOOTER
\`\`\`

## Last Cleaned
<!-- Update this line after running the commands above -->
Last cleaned: never
FOOTER
} > "$NOTE_PATH"

touch "$CLAUDE_LOG_DIR/.last-success-mac-cleanup-scan"

_DURATION_MS=$(( ($(date +%s) - _START_EPOCH) * 1000 ))
echo "duration_ms=$_DURATION_MS status=ok" >> "$LOGFILE"
exit 0
