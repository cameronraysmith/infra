---
name: git-stacked-pr-integration
description: First-party policy for worker and orchestrator roles in Git-native stacked PR delivery. Maps stack authoring and publication to mergify-stack, checked landing to stack-land, and colocated-jj mechanics to jj-version-control. Use when preparing, publishing, or landing a stacked change or reviewing its ownership boundaries and evidence.
---

# Stacked PR integration policy

This skill owns the fleet policy, role contracts, VCS routing, and landing evidence for stacked changes.
The upstream `mergify-stack` skill owns Git-native stack authoring and publication mechanics.
The landed `stack-land` command owns the checked final effect.
Keep both skills separately visible and do not copy the upstream procedure into this policy.

The pattern was verified landing PRs 2738, 2739, and 2740 in cameronraysmith/vanixiets on 2026-08-18: main was fast-forwarded to fe5a4b71 and GitHub merged all three PRs by reachability within one second.
This evidence covers the observed fast-forward landing and GitHub reachability only; it does not establish Mergify stack authoring or publication.

## Role contracts

A worker prepares and verifies one independently shippable change, commits it, and returns its ref plus verification evidence to the orchestrator without publishing or landing it.
The worker follows `mergify-stack` for Git-native stack identity, commit, and rewrite mechanics while keeping the result local.

The orchestrator alone orders the returned refs, publishes their pull-request stack through `mergify-stack`, rechecks the repository mode and landing preconditions, and invokes `stack-land` to land it.

## Requirement-to-mechanism map

| Requirement | Mechanism | Owner |
| --- | --- | --- |
| Each step is independently shippable | The worker runs the relevant tests and returns the ref with that evidence. | Worker |
| Git-native stack identity remains stable across worker rewrites | Follow the `mergify-stack` skill and its `Change-Id`-based workflow without publishing. | Worker |
| Git-native PR bookkeeping and publication preserve the stack relationship | Order the refs and publish their pull-request stack through `mergify-stack`; this skill adds no parallel publication recipe. | Orchestrator |
| Returned refs form the intended reviewed stack in the intended order | Order and inspect the refs before landing. | Orchestrator |
| The final update is checked before it changes the target branch | Run `stack-land --dry-run --tip REV PR...`, then `stack-land --tip REV PR...` for the real landing. | Orchestrator |
| Colocated-jj work preserves the development join and uses jj-native local mechanics | Follow `jj-version-control`; this skill retains only the shared role and landing policy. | Worker and orchestrator |

## Checked landing boundary

`stack-land --tip REV PR...` fetches the live target, requires it to be an ancestor of `REV`, requires exactly one valid `Change-Id` on every commit in the landing range, and requires every supplied PR to report at least one check with every conclusion in `SUCCESS`, `NEUTRAL`, or `SKIPPED`.
Any pending, failing, or other conclusion blocks landing.
It fetches and checks target ancestry again immediately before a real non-force push, then requires every supplied PR to report `MERGED` with `mergedAt` set.
Its dry-run mode performs the pre-push checks without pushing and cannot perform the post-push merged-state check.

The command does not determine repository mode, order refs, prove that the supplied PR list is complete, or prove that those PRs correspond to every commit through the selected tip.
It also does not establish review approval, intended remote or target selection, or the worker's local verification evidence.
The orchestrator must discharge those obligations before invoking it.

## VCS routing

we start with git… The `Change-Id` format is shared, so switching the orchestrator or individual workers to jj changes nothing about identity, PR bookkeeping, or landing. The signal to switch is conflict volume in the orchestrator step, not preference.

Use `mergify-stack` for Git-native local authoring and publication.
When `.jj/` is present, keep local jj mechanics in `jj-version-control`, including its development-join and stacked-submission rules.
In either mode, workers return independently shippable refs and evidence, and only the orchestrator lands the ordered stack through the selected checked handler.
