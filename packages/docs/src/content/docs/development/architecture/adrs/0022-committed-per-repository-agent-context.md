---
title: "ADR-0022: Committed Per-Repository Agent Context"
---

- **Status**: Accepted
- **Date**: 2026-08-18
- **Scope**: Agent context provisioning
- **Related**: [ADR-0001: Claude Code multi-profile system](0001-claude-code-multi-profile-system/)

## Context

Coding agents read a project-level context file at the root of the repository they are working in.
That file names the repository's architecture, its conventions, and the paths worth reading first, and for most agent sessions it is the only project-specific instruction they receive.

Until now these files have been kept outside the repositories they describe.
A separate planning repository holds one Markdown file per project under `contexts/`, and each working checkout carries a `CLAUDE.md` symlink pointing into that directory.
A manifest named `symlinks.conf` records which checkout points at which context file, and recipes in the planning repository's justfile reconcile manifest and filesystem: they list live symlinks, report broken links and context files with no inbound link, regenerate the manifest from what exists, and recreate missing links from the manifest.
Each symlink is excluded from its repository through `.git/info/exclude` rather than `.gitignore`, so the exclusion is machine-local and the context file never enters the repository's history.

That arrangement suited one person working in one checkout per project, where coordination across projects mattered more than context inside any one of them.
Three problems have since made it untenable.

### Context stored outside a repository drifts unnoticed

Nothing connects a context file to the tree it describes.
A change to the tree leaves the description untouched, and no check anywhere reports the resulting gap.

The vanixiets context file states that agent skills are distributed across 17 apm packages, "roughly 115 skills as of the 2026-06-30 refactor".
Those numbers described the tree accurately when they were written: commit `b13d5614` restructured the skills into apm packages on 2026-06-29.
Commit `c59fd781` added an eighteenth package the following day.
At the commit that adds this record, `modules/home/ai/plugins/` holds 18 packages and 132 skill definitions.

The file was itself edited on 2026-08-07, to correct an unrelated claim, and the stale counts survived that edit.
Six weeks of divergence passed through a maintenance pass without being noticed, which is what makes this a structural problem rather than an oversight.

### Fresh clones carry no context at all

The symlink is a property of one checkout on one machine, not of the repository.
Any clone made elsewhere, and any worktree created from an existing clone, contains no project context whatsoever.
This record was written in a worktree of vanixiets that holds neither `AGENTS.md` nor `CLAUDE.md`.

Agents running in per-task clones and worktrees are now a routine part of how work reaches this repository, and every one of them starts with whatever general-purpose instructions its harness supplies and nothing about the project.
Priming those trees by hand does not scale.
Copying the context in at task setup would only place a second uncontrolled copy on every machine that runs one.

### The description cannot travel with the change

Because the context file lives in a different repository, a change to the code and the corresponding correction to its description cannot be a single pull request.
Reviewers never see the two together, and no CI run ever evaluates the description at all.
A context file committed alongside the code rides the same review and the same checks as the change it describes, which is the mechanism that keeps every other document in this repository honest.

## Decision

Project-level agent context moves into each repository as committed files.

### File layout

`AGENTS.md` at the repository root holds the content and is the single source of truth.
`CLAUDE.md` becomes a one-line pointer, `@AGENTS.md`, so Claude Code loads the same text without a second copy to maintain.
Both files are tracked in git and reviewed like any other file in the tree.

### Maintenance

The files are maintained under the marker-block model that openwiki implements.
openwiki is a CLI that generates and refreshes a Markdown wiki for a repository; for agent instructions it rewrites only the region between `<!-- OPENWIKI:START -->` and `<!-- OPENWIKI:END -->` and leaves everything outside those markers untouched.
Hand-written material therefore survives regeneration, and generated material is replaced rather than merged into whatever preceded it.
A scheduled workflow runs the refresh and opens a pull request when the generated block changes, so divergence between tree and description surfaces as a reviewable diff instead of accumulating in silence.

### The planning repository retires

The function the planning repository still performed was coordination across projects: which repository holds which work, and what state that work is in.
The automation that now dispatches work to those repositories performs that function directly, so the repository becomes a frozen archive.
Its beads issue graph, orchestration overview, and activity logs remain readable at their current paths; nothing is deleted.
Whether the beads graph moves elsewhere, and where, is a separate decision that this record deliberately leaves open.

## Alternatives considered

### Keep the symlinks and add a drift check

A check comparing each context file against the tree it describes would address the stale counts.
It would not address the other two problems: a fresh clone would still hold no context, and the description would still be reviewed separately from the code.
The check would also need a vantage point that can see both repositories at once, which no CI runner has and which reintroduces the machine-local coupling that causes the problem.

### Vendor a snapshot into each repository at release time

Committing a generated copy while keeping the planning repository authoritative would fix clone emptiness.
It creates two files that describe the same repository and can disagree, and the copy in the repository would be the one agents read while the one under review is the other.
Two sources of truth for the same statements is the condition this decision exists to remove.

### Commit the files and maintain them entirely by hand

Committing alone fixes clone emptiness and couples the description to review.
It does not address drift: hand maintenance is what produced the divergence documented above, and moving the file does not change how it is maintained.
The marker block and the scheduled refresh are the part of this decision that addresses drift; committing is the part that addresses the other two problems.

### Generate the context from Nix, as user-level context already is

`modules/home/tools/agents-md.nix` generates the per-user context files from a Nix expression, and the same approach could generate per-repository files.
That binds a repository's context to a flake evaluation and to this repository's toolchain.
Most repositories the fleet works in are not Nix repositories, and a mechanism that only works here would leave them with the problem this decision is meant to solve everywhere.

## Consequences

### Positive

- Any clone or worktree, on any machine, carries the project's context, because the context is part of the repository.
- A change and the correction to its description are one pull request, reviewed together and checked together.
- Divergence between tree and description appears as a diff on a schedule rather than as an unmeasured gap.
- Setting up a checkout no longer requires installing a symlink from a manifest, removing a machine-local step and the failure modes that come with it.

### Negative

- **Each file needs a scrub before it can be committed.** The current context files were written for a private repository and carry operational detail that must not enter a public one, including host inventories, network topology, and the state of individual servers. Every migration begins by removing that material or relocating it somewhere private. This is a judgement call per file and cannot be automated.
- **Each file's provenance section currently forbids committing it.** Every context file carries a "File provenance" section stating that the file is a symlink into the planning repository, that it is excluded from git, and that agents must not add or commit it. Committed unchanged, that section would contradict the status of the file containing it. Rewriting it belongs to the migration of that file, not to a follow-up.
- **The user-level context generator must change in the same window.** `modules/home/tools/agents-md.nix` carries entries describing a team-orchestration session mode that no longer reflects how multi-agent work runs, and a convention that enumerates every skill as a category label paired with a delivered path. Both need retiring while the per-repository files are being written, so that user-level and project-level context do not describe the same practice in two incompatible ways.
- **Each repository gains a scheduled workflow**, with the model API credential and running cost that implies.

### Neutral

- Migration proceeds one repository at a time. The two arrangements coexist until the last repository moves, and the manifest and its recipes stay usable for whatever has not yet migrated.
- Context files become part of the public record of each repository. That is the intent, and it is also what makes the scrub non-optional rather than a matter of taste.

## Migration sequence

One repository migrates first, as a pilot: a scrubbed `AGENTS.md`, the `CLAUDE.md` pointer, and the scheduled workflow, with at least one full refresh cycle observed before the pattern is extended.
Remaining repositories follow in manifest order, each as its own pull request carrying its own scrub and its own provenance rewrite.
The user-level generator changes during that window.
When no repository depends on the planning repository, it is frozen.

This record fixes the destination and the ordering, not a schedule.
The pilot migration is tracked as a separate change and is not part of this record.

## References

### Internal

- [ADR-0001: Claude Code multi-profile system](0001-claude-code-multi-profile-system/) - profile isolation and shared configuration for the agent harnesses that read these files
- `modules/home/tools/agents-md.nix` - user-level context generator
- `modules/home/ai/plugins/` - apm skill packages whose counts are cited above

### External

- [openwiki](https://github.com/langchain-ai/openwiki) - marker-block maintenance of `AGENTS.md` and `CLAUDE.md`, and the scheduled-update workflow
