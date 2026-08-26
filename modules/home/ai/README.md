---
title: AI agent configuration
created: 2026-08-25
---

## AI agent configuration

Home-manager aspects for AI coding agents: the harnesses themselves, the skill corpus they load, and the context files they read.

Two boundaries here account for most wrong edits in this subtree, and neither is visible from a directory listing.

**Generated outputs versus their generators.** `../tools/agents-md.nix` is the single source for every user-level agent context file — `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`, and the rest, plus pi's `context` option, which is also what serves atomic through its legacy scan. Those destination files are nix-managed outputs. Edit the generator, never the generated file.

**Source versus delivered.** Skills are authored under `plugins/<group>/.apm/skills/<skill>/` and delivered to `~/.claude/skills/`, `~/.factory/skills/`, and the codex and opencode equivalents as read-only nix-store symlinks. A delivered copy changes only when the build reruns, so it holds pre-change content indefinitely after the source is edited, and a nix store path reports a 1970 mtime whatever it contains. Verify an edit against the source tree; treat the delivered path as a read-only artifact.

## Children

- `plugins/` — the first-party skill corpus, eighteen apm packages; indexed by its own README.
- `skills/` — composition and delivery of the corpus to each harness's skill directory.
- `openspec/` — the OpenSpec CLI, its schema bundles, and vendored artifact refresh.
- `agent-settings.nix` — settings shared across harnesses.

Harness-specific modules, each configuring one agent's settings, hooks, MCP servers, and wrappers: `atomic/`, `claude-code/`, `codex/`, `firstmate/`, `omp/`, `opencode/`, `pi/`.

Supporting tools these harnesses invoke: `cognee/` (memory layer), `herdr/` and `moshi/` (session multiplexing), `hunk/` and `tuicr/` (interactive diff review), `worktrunk/` (worktree management).
