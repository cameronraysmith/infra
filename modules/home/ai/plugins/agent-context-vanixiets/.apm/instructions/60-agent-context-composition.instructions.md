---
description: vanixiets agent context composition — how the generated AGENTS.md and CLAUDE.md come to exist, and where to actually make an edit.
---

## Agent context composition

The repository-root `AGENTS.md` and `CLAUDE.md` are generated files, git-ignored, and not committed.
The source of truth for their content is the committed instruction fragments under `modules/home/ai/plugins/agent-context-*/.apm/instructions/` — this package's own fragments plus its sibling `agent-context-core`, `agent-context-vcs`, and `agent-context-vcs-jj` packages.
Editing the generated `AGENTS.md` directly is pointless: the next composition run overwrites it, discarding the edit without warning.
The generated file carries a source comment above each section identifying the exact fragment that section came from, so the correction always belongs in that fragment, not in the generated output.

Two `just` recipes drive the two consumers of these same fragments.
`just agents-install` materializes this repository's own apm skill and instructions packages from the committed `apm.lock.yaml`, delivering the skills half into a git-ignored `.agents/skills/` tree.
`just agents-context` composes the instruction fragments into the repository-root `AGENTS.md` (and the `CLAUDE.md` pointer alongside it).
Run `just agents-install` before `just agents-context` after any fragment change whose package dependencies moved; otherwise `just agents-context` alone is enough to see a fragment edit reflected.

The same fragments are also composed a second way, by Nix, into the eight user-level harness surfaces (`~/.claude/CLAUDE.md` and its counterparts for the other agent tools); that composition is unrelated to this repository's own `AGENTS.md` and is documented in `agent-context-core`, not here.
