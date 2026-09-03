---
description: File edits under an edit-gate dispatch to subagent Tasks rather than landing inline from the orchestrator.
---

## Orchestrators do not edit files inline

Orchestrators do not edit files inline.
This is the binding form of the Session Protocol's orchestrator-mode discipline: when subject to an edit-gate — background sessions, agent-team teammates, or any future harness-level isolation requirement — file edits dispatch to subagent Tasks.
The subagent inherits the orchestrator's working directory and operates against the same working copy, so the gate is satisfied without creating any worktree.
