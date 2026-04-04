# =============================================================================
# GODL1KE Install Checklist — Format Day Guide
# =============================================================================
# WHY: This is your step-by-step guide for format day. Follow it in order.
# Each phase builds on the previous one. The install.sh script automates
# most of this, but some steps need manual input.
#
# ESTIMATED TIME: 30-45 minutes (plus download times)
# =============================================================================

## Before You Format

- [ ] Back up SSH keys: `cp -r ~/.ssh /Volumes/USB/ssh-backup/`
- [ ] Back up any local .env files you need
- [ ] Note down GitHub PATs / API keys stored only locally
- [ ] Export browser bookmarks (Safari + Chrome)
- [ ] Ensure all code is pushed to GitHub (check `git status` in every project)
- [ ] Download the latest macOS installer

---

## Phase 1: macOS Foundation (5 min)

- [ ] Fresh macOS install complete
- [ ] Sign into Apple ID
- [ ] Open Terminal.app (we'll switch to Ghostty after install)
- [ ] Install Xcode Command Line Tools: `xcode-select --install`
- [ ] Install Homebrew: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- [ ] Add Homebrew to PATH: `eval "$(/opt/homebrew/bin/brew shellenv)"`
- [ ] Clone dotfiles: `git clone <your-dotfiles-repo> ~/.dotfiles`
- [ ] Run Brewfile: `cd ~/.dotfiles && brew bundle`

## Phase 2: Shell & Terminal (2 min)

- [ ] Run `./install.sh` (automates symlinks)
- [ ] Open Ghostty (installed by Brewfile)
- [ ] Close Terminal.app — use Ghostty from now on
- [ ] Verify Starship prompt loads: open new Ghostty tab
- [ ] Verify tmux works: `tmux new -s test` then `exit`

## Phase 3: Git (5 min)

- [ ] Restore SSH keys from backup OR generate new: `ssh-keygen -t ed25519 -C "your-email"`
- [ ] Update `~/.gitconfig` with your real name and email
- [ ] Authenticate GitHub CLI: `gh auth login` (choose SSH)
- [ ] Add SSH key to GitHub: `gh ssh-key add ~/.ssh/id_ed25519.pub --title "GODL1KE M2 Max"`
- [ ] Enable SSH commit signing on GitHub (Settings → SSH keys → Signing keys)
- [ ] Test: `ssh -T git@github.com` (should say "Hi username!")

## Phase 4: Python (2 min)

- [ ] Verify Python: `python3 --version` (should be 3.13.x)
- [ ] Verify uv: `uv --version`
- [ ] Verify ruff: `ruff --version`
- [ ] Install pip-audit globally: `uv tool install pip-audit`

## Phase 5: Claude Code (5 min)

- [ ] Install Claude Code: `curl -fsSL https://claude.ai/install.sh | bash`
- [ ] Verify: `claude --version`
- [ ] Verify hooks linked: `ls -la ~/.claude/hooks/` (should show 6 .sh files)
- [ ] Verify agents linked: `ls -la ~/.claude/agents/` (should show 2 .md files)
- [ ] Verify commands linked: `ls -la ~/.claude/commands/` (should show 5 .md files)
- [ ] Make hooks executable: `chmod +x ~/.claude/hooks/*.sh`
- [ ] Set up MCP servers in `~/.claude.json`:
  - Copy from `~/.dotfiles/claude-json/claude.json`
  - Remove all `_comment` and `_note` fields
  - Replace `VAULT_PATH_PLACEHOLDER` with actual Obsidian path
- [ ] Add Linear MCP: `claude mcp add --transport http linear https://mcp.linear.app/mcp`

## Phase 6: Plugins (5 min, inside a Claude Code session)

- [ ] Start Claude Code: `claude`
- [ ] Install claude-mem:
  ```
  /plugin marketplace add thedotmack/claude-mem
  /plugin install claude-mem
  ```
- [ ] Configure claude-mem provider:
  - Open `~/.claude-mem/settings.json`
  - Set `CLAUDE_MEM_PROVIDER` to `"openrouter"` (or `"gemini"`)
  - Set API key for chosen provider
- [ ] Install superpowers:
  ```
  /plugin marketplace add obra/superpowers-marketplace
  /plugin install superpowers@superpowers-marketplace
  ```
- [ ] Install UI/UX skill:
  ```
  /plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
  ```
- [ ] Install Emil Kowalski skill:
  ```
  npx skills add emilkowalski/skill
  ```

## Phase 7: Docker & Databases (2 min)

- [ ] Open OrbStack (installs Docker automatically)
- [ ] Verify Docker: `docker run --rm hello-world`
- [ ] Start a local PostgreSQL for testing:
  ```bash
  docker run -d --name postgres-dev \
    -e POSTGRES_PASSWORD=postgres \
    -p 5432:5432 \
    postgres:16
  ```
- [ ] Verify: `docker exec -it postgres-dev psql -U postgres -c "SELECT 1"`

## Phase 8: Obsidian (2 min)

- [ ] Open Obsidian
- [ ] Create new vault named "GODL1KE" (stored in iCloud)
- [ ] Vault structure was created by install.sh — verify folders exist
- [ ] Copy templates from `~/.dotfiles/templates/obsidian-setup.md`
- [ ] Install Obsidian plugins: Daily Notes, Templates, Dataview (optional)

## Phase 9: Raycast (3 min)

- [ ] Open Raycast
- [ ] Configure window management hotkeys (Settings → Extensions → Window Management)
- [ ] Add script commands directory: Settings → Extensions → Script Commands → Add Directory → `~/.dotfiles/raycast/`
- [ ] Test: open Raycast, type "Switch Project", select a project

## Phase 10: Clone Projects (5 min)

- [ ] Create projects directory: `mkdir -p ~/projects`
- [ ] Clone each repo:
  ```bash
  cd ~/projects
  gh repo clone <lxs-org>/repo lxs
  gh repo clone <persimmon-org>/repo persimmon-homes
  gh repo clone <adtecher-org>/repo adtecher
  gh repo clone <wayv-org>/repo wayv
  gh repo clone <clubrevai-org>/repo clubrevai
  gh repo clone <ledgx-org>/repo ledgx
  ```
- [ ] For each project:
  ```bash
  cd ~/projects/<project>
  cp ~/.dotfiles/pre-commit/.pre-commit-config.yaml .
  cp ~/.dotfiles/templates/project-CLAUDE.md CLAUDE.md  # Customise!
  cp ~/.dotfiles/templates/.env.example .
  uv venv && source .venv/bin/activate
  pre-commit install
  ```

## Phase 11: Verify Everything (5 min)

- [ ] Start Claude Code in a project: `cd ~/projects/lxs && claude`
- [ ] Verify session-start hook: Claude should mention current branch
- [ ] Test safety guard: ask Claude to run `rm -rf /` (should be BLOCKED)
- [ ] Test file protection: ask Claude to edit `.env` (should be BLOCKED)
- [ ] Test auto-format: ask Claude to write a messy Python file (should auto-format)
- [ ] Test PR gate: ask Claude to create a PR (should run checks first)
- [ ] Test slash commands: `/review`, `/catchup`
- [ ] Test code-reviewer agent: `@code-reviewer review the last commit`
- [ ] Verify claude-mem is capturing: check `http://localhost:37777`
- [ ] Verify MCP servers: ask Claude "use Context7 to find FastAPI docs"

## Phase 12: Dotfiles Repo (2 min)

- [ ] Push dotfiles to GitHub:
  ```bash
  cd ~/.dotfiles
  git init
  git add .
  git commit -m "feat: initial GODL1KE dotfiles setup"
  gh repo create dotfiles --private --source=. --push
  ```

---

## Post-Install: Ongoing Maintenance

- **When Claude makes a mistake**: Add the correction to project CLAUDE.md
- **When you learn a new pattern**: Add to `04-Knowledge/` in Obsidian
- **When you add a new tool**: Add to Brewfile, commit, push
- **When dotfiles change**: Commit and push (symlinks mean changes auto-apply)
- **claude-mem maintenance**: Check `http://localhost:37777` weekly for memory health
- **Auto Memory cleanup**: `/memory` in Claude Code to review and prune
