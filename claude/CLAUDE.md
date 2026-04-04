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
