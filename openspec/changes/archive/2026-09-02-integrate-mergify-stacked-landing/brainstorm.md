# Brainstorm: integrate Mergify stacked landing

## Background

CAM-41 replaces an assumed hosted merge-queue path with a repository-owned protocol for landing a Git-native stacked pull-request chain.
The repository already contains `stack-land`, which performs the checked fast-forward landing operation, and `mergify-cli-bin`, which installs the Mergify executable.
The delivered skill corpus also contains the first-party `git-stacked-pr-integration` skill and the upstream `gh-stack` skill.
The missing connection is a pinned upstream `mergify-stack` skill, a clear division between policy and mechanism, and a short role-conditioned protocol in the generated user context.

The Firstmate instruction and CAM-41 description approve the design below.
This artifact records that decision set without reopening alternatives.
The later Task 6 review-remediation decisions supersede this artifact's original four-step sequence and single-conflict inventory.
The current approved record has five independently shippable implementation steps and three deferred canonical conflicts; the design's `Deferred canonical reconciliation` section records their git provenance.

## Approved decision chain

### D1: Add the upstream skill without replacing the first-party skill

Package the `Mergifyio/mergify-cli` source tree under `pkgs/by-name/agent-plugins/mergify-cli/package.nix` at the same upstream release tag as `mergify-cli-bin`.
Declare its `mergify-stack` skill through the existing version-control-and-forge apm package and pre-warm the apm checkout cache from the Nix-pinned source.
Keep `git-stacked-pr-integration` and `mergify-stack` as distinct flat names in the composed corpus.
Do not patch, fork, rewrite, or retire the upstream skill.

### D2: Separate fleet policy from the upstream mechanism

The first-party `git-stacked-pr-integration` skill owns the fleet's requirement-to-mechanism mapping, worker and orchestrator contracts, Git-versus-jj qualification, and evidence from PRs 2738, 2739, and 2740.
The upstream `mergify-stack` skill owns stack authoring and publishing mechanics.
The first-party skill points to the upstream recipe instead of copying it.
The actual checked landing operation remains the repository's existing `stack-land` package and command rather than a planned replacement recipe.

### D3: Add a short role-conditioned user-context protocol

Add a `Stacked landing protocol` entry to the committed source in `modules/home/tools/agents-md.nix` under `Version control and work dispatch`.
The entry names the context tier and assigns independently shippable step preparation to workers while reserving stack assembly and landing for the orchestrator.
It composes with the existing OpenSpec dispatch unit, VCS detection, atomic commit override, jj working-copy hazards, and worktree constraints.
It does not make a project context a paragraph-for-paragraph superset of the user context, preserving OMP containment behavior.

### D4: Sequence the work as independent shippable steps

Step one adds the Nix-pinned upstream skill source without changing the installed binary or home-manager configuration.
Step two wires the source through apm composition and verifies that both flat skills are delivered without network access.
Step three converges the first-party skill on the upstream mechanism while preserving its fleet-specific contract and evidence.
Step four adds and evaluates the generated user-context protocol.
Step five reconciles the reviewed policy and context findings, adds the full-flake release-alignment check, corrects the ignored Task 2 report, and hands evidence to post-Task-6 verification.
Each of the five steps has its own verification and rollback boundary.

## Scope boundaries

This change does not add Cognee gates.
It does not alter the existing `mergify-cli-bin` derivation or its home-manager wiring.
It does not implement a new landing script, just recipe, nixbot setting, Mergify ruleset, or hosted merge queue.
It does not perform a real stack landing.
It does not edit `apm.lock.yaml` directly.

## Trust boundaries and known risk

The Nix source pin, apm lock entry, composed output, authored skill text, and generated context are inspectable machine interfaces.
They can establish which source and guidance the repository distributes.
They cannot guarantee that a harness selects the intended skill, that a human grants landing authority correctly, that the forge state is safe, or that an end-to-end landing succeeds.

The canonical `first-party-skill-distribution` scenario still says apm composes `agent-skills,claude,codex,hermes` directly.
The current implementation composes only `agent-skills` and `claude`, then fans the result out to other harnesses through Nix.
The same canonical specification says apm never runs outside a Nix derivation, while the repository producer installer intentionally runs apm for `just agents-install` and `just agents-relock`.
It also says roughly 70 absolute `@` references remain unchanged, while the later removal of the hand-maintained index leaves one force-load reference in the current generator.
The design records the commit and date provenance for all three conflicts.
This change keeps them as undischarged provenance risks and does not silently repair the older requirements while adding Mergify behavior.
