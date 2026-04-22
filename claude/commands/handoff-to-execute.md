# Handoff to Execute

Generate a medium-length, hybrid prompt that a fresh Claude Code session can consume to execute the current plan without re-brainstorming.

## Instructions

1. **Identify the spec and plan files.** Most recent spec: `docs/superpowers/specs/<date>-<topic>-design.md`. Most recent plan: `docs/superpowers/plans/<date>-<topic>.md`. If ambiguous, ask the user.
2. **Capture project context:** current git repo root, current branch, and one-line summary of objective drawn from the plan file's Goal line.
3. **Draft a 3–5 line summary** of key decisions + known constraints from the spec (not the plan — the plan is exhaustive, the spec holds the judgment calls).
4. **Output the prompt verbatim** between two horizontal rules so the user can copy-paste. Do not wrap in code fences.

## Output template

Use exactly this template, filling in the variables:

---

You are starting a fresh execution session for a pre-planned task. Your job: execute the plan using `superpowers:subagent-driven-development`.

**Project:** `<git repo root>`
**Branch:** `<current branch>`
**Spec:** `<absolute path to spec>`
**Plan:** `<absolute path to plan>`

**Objective:** <one-line goal from plan>

**Key decisions (from spec):**
- <decision 1>
- <decision 2>
- <decision 3>

**Constraints:**
- <constraint 1>
- <constraint 2>

**Your task:**
1. Read the spec and plan files first.
2. Invoke `superpowers:subagent-driven-development` to execute the plan task-by-task.
3. Do NOT re-brainstorm. Do NOT modify the spec. Do NOT rewrite the plan.
4. Ask clarifying questions only when the plan is genuinely ambiguous.

**Available tooling:** `superpowers:subagent-driven-development`, `superpowers:verification-before-completion`, `researcher` agent, `code-reviewer` agent, Context7 MCP, Obsidian MCP, claude-mem MCP.

Begin by reading the spec and plan.

---

## Rules

- Never fabricate the decision/constraint bullets — pull them from the spec's "Decisions" or "Non-goals" sections.
- If the spec or plan file doesn't exist, stop and ask the user to confirm paths before generating the prompt.
- Output only the template + a one-line confirmation. No preamble, no post-commentary.
