# Aman — Global Preferences

- Always explain your approach before writing code. Name the design pattern and explain trade-offs
- Follow superpowers methodology strictly: brainstorm → spec → plan → execute. Never skip steps
- Write tests BEFORE implementation (TDD). Use pytest + httpx for async FastAPI tests
- Use Conventional Commits: feat:, fix:, chore:, docs:, refactor:, test:
- GitHub Flow: feature branches off main, squash-merge via PR. Never push to main directly
- Use async/await throughout FastAPI. Repository pattern: routes → services → repositories → models
- Use structlog for logging — never print(). Use Pydantic error schemas for API errors
- Keep functions under 30 lines. Extract complex logic into well-named helpers
- Before creating any PR: run code review AND security scan. Both must pass
- Use ruff for formatting — never manually format. Use uv for package management — never pip
- Never commit .env files. Reference .env.example for required variables

## Proactive tool use (added 2026-04-22)

- **Context7:** For any library, framework, SDK, API, or CLI named in any workflow phase (brainstorm, spec, plan, or implementation), invoke `mcp__context7__resolve-library-id` followed by `mcp__context7__query-docs` before committing to an API shape. Even for well-known libraries — training data may be stale.
- **Researcher on brainstorm start:** When the `superpowers:brainstorming` skill activates, dispatch the `researcher` agent in the background immediately to investigate the topic, unknowns, and relevant prior art.
- **Researcher before spec:** Before writing any spec, dispatch the `researcher` agent in the background to validate libraries and assumptions surfaced during brainstorming.
- **Handoff auto-trigger:** When `superpowers:executing-plans` reaches the decision point of "subagent-driven-development or inline implementation?", first generate the `/handoff-to-execute` prompt as part of the response, then present the two options.
- **Opus override for superpowers:code-reviewer:** When dispatching `superpowers:code-reviewer` via the Agent tool, always pass `model: "opus"`. Plan-vs-implementation review is too consequential for Sonnet.
