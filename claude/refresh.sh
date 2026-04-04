#!/bin/zsh
# refresh.sh — reload all Claude Code config changes
# Usage: source ~/.dotfiles/claude/refresh.sh
# (must be sourced, not executed, for zshrc changes to take effect)

echo "🔄 Reloading Claude Code environment...\n"

# ── 1. Shell ──────────────────────────────────────────────────────
echo "1. Sourcing ~/.zshrc..."
source ~/.zshrc
echo "   ✅ Shell environment reloaded\n"

# ── 2. Claude Code version ────────────────────────────────────────
echo "2. Checking Claude Code..."
CLAUDE_VERSION=$(claude --version 2>/dev/null)
if [ -n "$CLAUDE_VERSION" ]; then
  echo "   ✅ $CLAUDE_VERSION"
else
  echo "   ❌ claude not found in PATH"
fi
echo ""

# ── 3. Hooks ──────────────────────────────────────────────────────
echo "3. Verifying hooks (executable)..."
HOOKS_OK=true
for hook in ~/.claude/hooks/*.sh; do
  if [ -x "$hook" ]; then
    echo "   ✅ $(basename $hook)"
  else
    echo "   ❌ $(basename $hook) — not executable, fixing..."
    chmod +x "$hook"
    echo "   ✅ $(basename $hook) — fixed"
    HOOKS_OK=false
  fi
done
echo ""

# ── 4. MCP servers ────────────────────────────────────────────────
echo "4. Checking MCP servers in ~/.claude.json..."
python3 -c "
import json
with open('$HOME/.claude.json') as f:
    d = json.load(f)
servers = d.get('mcpServers', {})
for name, cfg in servers.items():
    missing = []
    env = cfg.get('env', {})
    headers = cfg.get('headers', {})
    for v in list(env.values()) + list(headers.values()):
        if isinstance(v, str) and v.startswith('\${') and not __import__('os').environ.get(v[2:-1]):
            missing.append(v[2:-1])
    if missing:
        print(f'   ⚠️  {name} — missing env vars: {\", \".join(missing)}')
    else:
        print(f'   ✅ {name}')
"
echo ""

# ── 5. claude-mem worker ──────────────────────────────────────────
echo "5. Checking claude-mem worker..."
HEALTH=$(curl -s http://127.0.0.1:37777/api/health 2>/dev/null)

if echo "$HEALTH" | grep -q '"status":"ok"'; then
  PROVIDER=$(echo "$HEALTH" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['ai']['provider'])" 2>/dev/null)
  echo "   ✅ Worker running — provider: $PROVIDER"
else
  echo "   ⚠️  Worker not running — starting..."
  PLUGIN_ROOT="$HOME/.claude/plugins/cache/thedotmack/claude-mem"
  WORKER=$(ls -d "$PLUGIN_ROOT"/*/scripts/worker-service.cjs 2>/dev/null | tail -1)
  if [ -n "$WORKER" ]; then
    bun "$WORKER" &>/tmp/claude-mem.log &
    sleep 4
    HEALTH2=$(curl -s http://127.0.0.1:37777/api/health 2>/dev/null)
    if echo "$HEALTH2" | grep -q '"status":"ok"'; then
      echo "   ✅ Worker started successfully"
    else
      echo "   ❌ Worker failed to start — check /tmp/claude-mem.log"
    fi
  else
    echo "   ❌ Worker script not found — reinstall claude-mem plugin"
  fi
fi
echo ""

# ── 6. Settings sanity check ──────────────────────────────────────
echo "6. Checking settings.json..."
python3 -c "
import json
with open('$HOME/.dotfiles/claude/settings.json') as f:
    d = json.load(f)
model = d.get('model', 'NOT SET')
subagent = d.get('env', {}).get('CLAUDE_CODE_SUBAGENT_MODEL', 'NOT SET')
thinking = d.get('showThinkingSummaries', 'NOT SET')
hooks = list(d.get('hooks', {}).keys())
print(f'   Model:              {model}')
print(f'   Subagent model:     {subagent}')
print(f'   Thinking summaries: {thinking}')
print(f'   Hooks registered:   {\", \".join(hooks)}')
"
echo ""

# ── Summary ───────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Refresh complete."
echo ""
echo "Remaining manual steps (if not done yet):"
[ -z "$GITHUB_PAT" ]        && echo "  • Set GITHUB_PAT in ~/.zshrc"
[ -z "$SENTRY_AUTH_TOKEN" ] && echo "  • Set SENTRY_AUTH_TOKEN in ~/.zshrc"
[ -z "$SENTRY_ORG" ]        && echo "  • Set SENTRY_ORG in ~/.zshrc"
echo ""
echo "Open claude-mem dashboard: http://localhost:37777"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
