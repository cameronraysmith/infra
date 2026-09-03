---
linear_story_id: fcadf1d7-8022-413a-b907-eae9bd7c14f9
linear_story_identifier: CAM-41
linear_story_title: Land changes through a git-native stacked-PR protocol instead of a hosted merge queue
linear_story_url: https://linear.app/cameronraysmith/issue/CAM-41/land-changes-through-a-git-native-stacked-pr-protocol-instead-of-a
linear_story_state: In Progress
linear_team: CAM
linear_project: nixbot-herculesci-cicd
last_synced_state: In Progress
last_synced_at: 2026-09-03T00:37:42Z
review_round: 0
attempt_log: []
---

## Why

The repository can prepare and check a Git-native stacked pull-request landing, but its distributed guidance does not yet connect the fleet's role and safety policy to Mergify's upstream stack mechanism.
Pinning and composing the upstream skill while retaining the first-party policy skill gives workers and orchestrators one explicit route from independently shippable changes to the existing checked `stack-land` operation.

## What Changes

**Mergify skill distribution**

- From: the repository installs `mergify-cli-bin`, but the composed skill corpus does not include the upstream `mergify-stack` skill.
- To: a Nix-pinned `Mergifyio/mergify-cli` source at the binary package's release tag feeds an offline apm dependency that delivers `mergify-stack` alongside `git-stacked-pr-integration`, and a structure check fails if those package versions diverge.
- Reason: make the upstream stack authoring and publication mechanism available through the same reproducible skill-distribution path as other remote skills.
- Impact: additive in the Nix-composed corpus; the first-party skill and upstream source retain separate names and ownership.
  The root `apm.lock.yaml` remains unchanged, so a fresh frozen `just agents-install` before the generated post-main relock would materialize the pre-change skill set.
  The contents of any existing ignored repository-local `.agents/` tree are unspecified.

**Stacked landing guidance**

- From: `git-stacked-pr-integration` contains a complete plain-Git recipe but does not assign worker and orchestrator responsibilities or route execution to the upstream Mergify mechanism and existing `stack-land` command.
- To: the first-party skill owns the requirement-to-mechanism mapping, role contracts, Git-versus-jj qualification, and fleet evidence while referring to `mergify-stack` for mechanism detail and `stack-land` for the checked landing operation.
  A worker prepares and verifies one change and returns its ref and evidence; the orchestrator alone orders and publishes the pull-request stack and alone lands it.
- Reason: keep policy in first-party guidance and mechanism detail at its maintained source.
- Impact: the PR 2738, 2739, and 2740 evidence sentence remains byte-identical from the base revision, with adjacent prose limiting it to the observed fast-forward landing and GitHub reachability.
  The transcript-prescribed soft Git-versus-jj note is added verbatim by this change rather than presented as pre-existing text.
  The documented landing gate accepts reported `SUCCESS`, `NEUTRAL`, and `SKIPPED` check conclusions and blocks pending, failing, or other conclusions, matching the merged `stack-land` handler.

**Generated user context**

- From: the `Version control and work dispatch` section does not state who prepares a stack step or who may assemble and land the stack.
- To: a short, role-conditioned `Stacked landing protocol` entry assigns preparation and verification to workers while reserving pull-request stack publication and landing for the orchestrator, preserving the surrounding VCS, commit, jj, worktree, and OMP containment contracts.
- Reason: make the authority boundary visible before a task is dispatched.
- Impact: all generated user-level agent context files receive the same protocol from the committed generator.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `first-party-skill-distribution` (`interface`): deliver the first-party policy skill and upstream Mergify mechanism skill as distinct flat corpus entries without retirement or overwrite.
  Trust boundary: the composed output establishes availability and distinct names, but it does not establish harness selection or correct use.
- `third-party-plugin-dependency` (`interface`): pin the upstream Mergify skill source to the executable release, enforce that alignment through a full-flake structure check, resolve it offline, detect declaration drift, and preserve upstream content unchanged.
  Trust boundary: source and Nix-generated lock evidence establish provenance and build resolution only for the composed output; they do not establish the upstream skill's correctness or delivery through the root lock and repository-local `.agents/` path.
- `skill-corpus-interface` (`interface`): expose role-conditioned stacked-landing ownership and route the first-party requirements to the upstream mechanism and existing checked landing command.
  Trust boundary: the delivered text establishes the documented contract, but it does not grant authority or guarantee repository topology, forge state, or a successful landing.

## Impact

- Add `pkgs/by-name/agent-plugins/mergify-cli/package.nix` at the same release tag as `pkgs/by-name/mergify-cli-bin/package.nix`.
- Update `pkgs/by-name/apm-skills-compose/package.nix` and `modules/home/ai/plugins/version-control-and-forge/apm.yml` to compose `mergify-stack` offline and assert its delivery.
- Add `modules/checks/structure/mergify-release-alignment.nix` to enforce release alignment from the fully evaluated per-system package outputs.
- Update `modules/home/ai/plugins/version-control-and-forge/.apm/skills/git-stacked-pr-integration/SKILL.md` and `modules/home/ai/plugins/README.md` without editing upstream content.
- Update `modules/home/tools/agents-md.nix` as the source for generated user-level agent context.
- Retain `pkgs/by-name/stack-land/`, `modules/home/tools/stack-land.nix`, and the existing binary and home-manager wiring unchanged.
- Leave the root `apm.lock.yaml` unchanged and require a generated `just agents-relock` follow-up after this change reaches `main`; before that relock, a fresh frozen `just agents-install` would materialize the pre-change set, while the contents of any existing ignored repository-local `.agents/` tree remain unspecified.
- Exclude Cognee gates, a new landing script or recipe, nixbot and ruleset settings, and a real stack landing.
