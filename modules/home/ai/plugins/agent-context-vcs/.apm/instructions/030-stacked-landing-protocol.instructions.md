---
description: Stacked delivery roles, the one-commit-one-pull-request unit, and the division of labour between a worker preparing a delivery commit and the orchestrator publishing and landing the stack.
---

## Stacked landing protocol

The dispatched unit remains an OpenSpec change, normally bound to one Linear story, and each independently shippable delivery step is encoded as one commit and one pull request.

A worker prepares and verifies one step, maintains its single delivery commit, and returns that commit's ref together with its evidence, without publishing or landing anything.
Corrections amend or update that same delivery commit.
That narrowly overrides the atomic-commit and never-amend rule stated in the commit-behaviour fragment beside this one, and it overrides it only for the delivery commit of a stack unit; it never permits rewriting unrelated history.

The orchestrator alone orders the returned refs, publishes their pull-request stack through `mergify-stack`, confirms the active version-control mode and the landing preconditions, and lands the stack through the selected landing mechanism.

Git is the baseline and jj is an upgrade path rather than a fork in the protocol.
The `Change-Id` trailer format is shared, so moving the orchestrator or an individual worker to jj changes nothing about stack identity, pull-request bookkeeping, or landing.
The signal to switch is conflict volume in the orchestrator's integration step, not preference.

Repository-mode detection therefore selects local authoring and working-copy mechanics only.
In a git-native repository, consult `git-stacked-pr-integration` for fleet policy and `mergify-stack` for the upstream mechanism, then run the `stack-land` handler for the final checked operation.
In a repository containing a `.jj/` directory, the development-join, shared working-copy, hazard, recovery, and worktree-interop rules remain authoritative for local operations.

A note on the two context tiers, because it constrains what a project-level file may contain.
On a machine whose user profile already supplies the fleet and repository-class tiers, a project-level context file must not repeat them: harnesses that load both levels concatenate them without de-duplicating, so a project file that is a superset of the user-level one injects the shared prose twice.
Where no user-level context exists, as in an ephemeral clone, composing every tier into the project file is correct and is what the full composition mode is for.
