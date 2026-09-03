---
title: "ADR-0023: Modular agent context fragments"
---

## Status

Accepted

Supersedes [ADR-0022](0022-committed-per-repository-agent-context/)

## Context

ADR-0022 committed a single hand-maintained `AGENTS.md` at the repository root, diagnosing three real problems: context stored outside a repository drifts unnoticed, fresh clones carry no context, and a description that lives elsewhere cannot travel with the change that caused it.
That diagnosis still holds.
Its remedy left the fleet-global tier untouched: roughly four hundred lines of agent instructions embedded in one Nix string in `modules/home/tools/agents-md.nix` remained a single hand-maintained document, subject to exactly the drift ADR-0022 diagnosed for the repository tier.

## Decision

Author agent context as `*.instructions.md` fragments in apm packages under `modules/home/ai/plugins/`, split by scope: fleet-global, git-baseline version control, jj workstation mechanics, and this repository.
Compose this repository's `AGENTS.md` and a one-line `CLAUDE.md` pointer from those fragments with `apm compile`.
Compose the user-level context surfaces in `modules/home/tools/agents-md.nix` from the same fragments.
One source feeds both consumers, so the two can no longer disagree with each other.

## Consequences

The generated `AGENTS.md` is git-ignored rather than committed; a fresh clone runs a compose recipe instead of reading a checked-in file.
A tier the user-level profile already supplies is omitted from the default repository compose, because Claude Code concatenates user-level and project-level context without de-duplication.
Compiled output carries a source comment per section naming the fragment it came from, which makes the do-not-edit instruction enforceable rather than aspirational.
The fragments are published through the vanixiets apm marketplace, so a third-party repository can depend on the fleet and class tiers instead of re-authoring them.
openwiki's planned managed-block role is unaffected, since its target region sits outside the composed context; its brief needs its authority statement re-pointed at the fragments.
