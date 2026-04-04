# =============================================================================
# GODL1KE Obsidian Vault Setup
# =============================================================================
# WHY: Obsidian is your second brain — meeting notes, architecture decisions,
# client knowledge, and learning notes all live here. The MCP server lets
# Claude Code read and search your vault during sessions.
#
# Vault location: ~/Library/Mobile Documents/iCloud~md~obsidian/Documents/GODL1KE
# =============================================================================

## Folder Structure

Create these folders in the GODL1KE vault:

```
GODL1KE/
├── 00-Inbox/                      # Quick capture — unsorted notes, voice memos
├── 01-LXS/                        # LXS Consulting (employer)
│   ├── Persimmon Homes/            # Current client
│   │   ├── meetings/
│   │   ├── decisions/
│   │   └── architecture/
│   └── _new-client-template/       # Copy for future LXS clients
│       ├── meetings/
│       ├── decisions/
│       └── architecture/
├── 02-Startups/
│   ├── AdTecher/                   # Co-founder — AdTech
│   │   ├── meetings/
│   │   ├── decisions/
│   │   ├── architecture/
│   │   └── roadmap/
│   └── Ledgx/                     # Co-founder — FinTech
│       ├── meetings/
│       ├── decisions/
│       ├── architecture/
│       └── compliance/             # FinTech compliance notes
├── 03-Clients/
│   ├── Wayv Telcom/                # Manager role
│   │   ├── meetings/
│   │   └── decisions/
│   └── ClubRevAI/                  # Friend's project
│       └── notes/
├── 04-Knowledge/                   # Learning & reference
│   ├── architecture-patterns/      # Design patterns you're learning
│   ├── fastapi/                    # FastAPI tips and patterns
│   ├── claude-code/                # Claude Code workflows and tricks
│   ├── sqlalchemy/                 # ORM patterns
│   └── devops/                     # Infrastructure knowledge
├── 05-Templates/                   # Reusable note templates
└── 06-Personal/                    # Non-work notes
```

## Templates

Create these files in `05-Templates/`:

### meeting-note.md
```markdown
---
date: {{date}}
project: 
attendees: 
type: meeting
---

# Meeting: {{title}}

## Agenda
- 

## Notes
- 

## Action Items
- [ ] 

## Decisions Made
- 
```

### decision-record.md
```markdown
---
date: {{date}}
project: 
status: proposed | accepted | rejected
type: decision
---

# Decision: {{title}}

## Context
What is the issue we're deciding on?

## Options Considered
1. **Option A**: 
2. **Option B**: 

## Decision
What was decided and why?

## Consequences
What are the trade-offs?
```

### architecture-decision.md
```markdown
---
date: {{date}}
project: 
status: proposed | accepted
type: adr
---

# ADR: {{title}}

## Status
Proposed

## Context
What architectural problem are we solving?

## Decision
What approach are we taking?

## Pattern
What design pattern does this follow? (e.g., Repository, CQRS, Event Sourcing)

## Consequences
### Positive
- 

### Negative
- 

### Trade-offs
- 
```

## Setup Commands

Run these after creating the vault in Obsidian:

```bash
VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/GODL1KE"

# Create folder structure
mkdir -p "$VAULT"/{00-Inbox,01-LXS/{Persimmon\ Homes/{meetings,decisions,architecture},_new-client-template/{meetings,decisions,architecture}},02-Startups/{AdTecher/{meetings,decisions,architecture,roadmap},Ledgx/{meetings,decisions,architecture,compliance}},03-Clients/{Wayv\ Telcom/{meetings,decisions},ClubRevAI/notes},04-Knowledge/{architecture-patterns,fastapi,claude-code,sqlalchemy,devops},05-Templates,06-Personal}

echo "GODL1KE vault structure created at: $VAULT"
```

## MCP Server Connection

After creating the vault, update `~/.claude.json` to replace `VAULT_PATH_PLACEHOLDER` with:
```
~/Library/Mobile Documents/iCloud~md~obsidian/Documents/GODL1KE
```

Then test in a Claude Code session:
```
Search my Obsidian vault for "architecture"
```
