## Context

CAM-41 connects three existing surfaces rather than introducing a second landing system.
`mergify-cli-bin` supplies the Mergify executable at release `2026.8.31.1`.
`stack-land` checks target ancestry, Change-Id trailers, a nonempty pull-request check set whose reported conclusions are `SUCCESS`, `NEUTRAL`, or `SKIPPED`, a fresh target fetch, the fast-forward push, and the resulting merged state.
Pending, failing, and any other reported check conclusion block the handler.
`git-stacked-pr-integration` records the fleet's Git-native stacked-base policy and the observed PR 2738, 2739, and 2740 landing.

The missing surface is the upstream `mergify-stack` skill from the same Mergify release, delivered through the existing offline apm composition.
The first-party skill and generated user context must then assign policy and authority without copying the upstream mechanism.

The source-versus-delivered boundary is explicit.
Source skills and dependency declarations live under `modules/home/ai/plugins/`, the Nix build composes `agent-skills` and `claude`, and later Nix modules fan that output out to the other harnesses.
Reading an authored source file does not verify its delivered form.

## Goals / Non-Goals

**Goals:**

- Pin the `Mergifyio/mergify-cli` source that contains `mergify-stack` to the same upstream release as `mergify-cli-bin`, and make a full-flake structure check fail if the two package versions diverge.
- Resolve and compose the upstream skill without network access or upstream modification.
- Deliver `mergify-stack` and `git-stacked-pr-integration` as distinct flat skills.
- Make the first-party skill the owner of fleet policy, role contracts, VCS routing, and retained empirical evidence.
- Keep Mergify command mechanics in the upstream skill while reserving pull-request stack publication and landing for the orchestrator.
- Add a concise role-conditioned protocol to the generated user context.
- Produce five independently shippable implementation steps with explicit verification and rollback.

**Non-Goals:**

- Cognee-backed planning or review gates.
- Changes to `mergify-cli-bin` or its home-manager installation.
- A new landing script, just recipe, or replacement for `stack-land`.
- Nixbot configuration, repository rulesets, or hosted merge-queue policy.
- A real stack landing during this change.
- Manual edits to `apm.lock.yaml`.
- Delivery of `mergify-stack` through the root lock and repository-local git-ignored `.agents/` tree before a generated post-merge relock.
- Repair of the older canonical direct-target, apm-execution, or absolute-autoload-reference requirements.

## Decisions

### D1: Pin a source-only Mergify package beside the existing binary package

- **Boundary**: upstream source versus first-party packaging.
- **Choice**: add `pkgs/by-name/agent-plugins/mergify-cli/package.nix` as a `fetchFromGitHub` source package for the release represented by `mergify-cli-bin` version `2026.8.31.1`, then add `modules/checks/structure/mergify-release-alignment.nix` to compare the two versions from the fully evaluated per-system package outputs.
- **Rationale**: the apm cache needs the upstream tree that contains the skill, while the existing binary derivation remains the executable source.
- **Alternatives considered**: reuse the release archive from `mergify-cli-bin`, rejected because it contains the executable rather than the skill source; enforce agreement inside `apm-skills-compose`, rejected because reaching the flake package output from within that package re-enters flake-parts' transposed package scope and causes infinite recursion; build or replace the binary derivation, rejected as outside CAM-41.

The source package must expose enough release and revision metadata for the composition layer to compare its apm ref with the pinned checkout.
A full commit revision should feed the apm declaration and checkout cache even when the human-facing release identity remains the tag.
The structure module reads `self'.packages.agent-plugins-mergify-cli.version` and `self'.packages.mergify-cli-bin.version`, so agreement is checked only after flake-parts has exposed both packages in the fully composed per-system output.
It follows the repository's full-flake structure-check convention: a reusable checker receives both evaluated strings as `runCommand` inputs, exits nonzero when they differ, and prints both names and values.
The same module registers `structure-mergify-release-alignment-neg`, which invokes that checker with deliberate unequal fixtures, requires the invocation to fail, and verifies that both fixture values appear in the diagnostic.
Normal builds of `structure-mergify-release-alignment` and the negative-control check must pass.

### D2: Compose `mergify-stack` through the established remote-dependency path

- **Boundary**: authored dependency declaration versus delivered flat corpus.
- **Choice**: declare the upstream skill in `modules/home/ai/plugins/version-control-and-forge/apm.yml`, pass the Nix source and revision into `apm-skills-compose`, pre-warm the URL-keyed checkout cache, reject revision drift, and assert its entry point under `.claude/skills` and `.agents/skills`.
- **Rationale**: this is the same offline mechanism used for `worktrunk`, `gh-stack`, and other remote skills, and it preserves a remote-style lock record without network access.
- **Alternatives considered**: copy the upstream skill into the first-party package, rejected because it would create a fork; add it as a generated root local-path dependency, rejected because it would erase the remote provenance and drift guard.

The apm install targets remain `agent-skills` and `claude`.
The existing later Nix fan-out remains responsible for other harness destinations.
The manifest retains the upstream identity `Mergifyio/mergify-cli`, while APM 0.29.0 lowercases GitHub owner and repository components in `cache/url_normalize.py` before deriving its checkout-cache key.
The composition therefore hashes only the normalized URL `https://github.com/mergifyio/mergify-cli` for the pre-warmed shard, because hashing the mixed-case manifest spelling creates an unused shard and lets offline resolution fall through to the network.
The lock generated inside the Nix output is evidence only for that composed output.
It does not refresh the repository root `apm.lock.yaml` or the git-ignored repository-local `.agents/` tree.

### D3: Keep first-party policy and upstream mechanism distinct

- **Boundary**: first-party authored guidance versus upstream unedited guidance.
- **Choice**: revise `git-stacked-pr-integration` into a requirement-to-mechanism map that has a worker prepare and verify one change and return its ref and evidence without publishing, has the orchestrator alone order and publish the pull-request stack, points to `mergify-stack` for Mergify command mechanics, and identifies the landed repository `stack-land` command as the checked final operation invoked only by the orchestrator.
- **Rationale**: fleet authority and safety policy change independently from Mergify command syntax, so each needs one owner.
- **Alternatives considered**: replace the first-party skill with `mergify-stack`, rejected because the upstream skill does not own fleet roles or jj constraints; copy the upstream recipe into the first-party skill, rejected because the two copies would drift.

The soft routing note is transcript-prescribed text added verbatim by this change; it is not pre-existing base text.
The sentence documenting PRs 2738, 2739, and 2740 is base evidence and must be preserved verbatim.
Adjacent prose must limit that sentence to the observed fast-forward landing and GitHub reachability and must not present it as evidence for Mergify authoring or publication.

### D4: Treat `stack-land` as the existing landing handler

- **Boundary**: protocol prose versus executable effect handler.
- **Choice**: references to the final landing operation name the existing `stack-land --tip REV PR...` command and its dry-run mode.
- **Rationale**: `stack-land` already checks the live target and pull-request conditions immediately around the fast-forward push.
- **Alternatives considered**: plan a new shell script or just recipe, rejected because commit `33f94e2ce` already supplies the handler and CAM-41 excludes its reimplementation.

The protocol may cite `stack-land` assertions, but it must not claim that those checks prove an end-to-end safe landing.
The policy must describe its reported-check predicate exactly: each supplied pull request has at least one check, every reported conclusion is `SUCCESS`, `NEUTRAL`, or `SKIPPED`, and pending, failing, or any other conclusion blocks.
The command cannot establish correct human authorization, completeness of the selected PR set, correctness of GitHub's responses, or absence of unmodeled forge behavior.

### D5: Put the role boundary in the user-context tier

- **Boundary**: committed generator versus generated harness context.
- **Choice**: add a short `Stacked landing protocol` subsection under `Version control and work dispatch` in `modules/home/tools/agents-md.nix`.
- **Rationale**: the role decision must be visible before dispatch, while detailed mechanics remain discoverable through skills.
- **Alternatives considered**: add the text to one generated `AGENTS.md`, rejected because generated files are not sources; add a project-level superset, rejected because OMP containment can discard the user-level file when a project file contains its full paragraph sequence.

A worker receives one independently shippable step within an OpenSpec change normally bound to one Linear story, verifies it, and returns its one delivery commit plus evidence without publishing or landing.
Corrections update that same delivery commit.
This stacked-delivery rule narrowly overrides the generic atomic-commit and no-amend rule for that stack unit, but never permits rewriting unrelated history outside the unit.
An orchestrator orders the delivery commits, publishes the corresponding pull-request stack, confirms the repository mode and landing preconditions, and alone invokes the selected landing mechanism.
Repository-mode detection selects local authoring and working-copy mechanics; it does not change stack identity, pull-request bookkeeping, or the landing contract.
For jj-managed repositories, the existing shared working-copy, hazard, recovery, and worktree-interop rules remain authoritative for local operations.
The subsection must preserve this soft routing note verbatim: “we start with git… The `Change-Id` format is shared, so switching the orchestrator or individual workers to jj changes nothing about identity, PR bookkeeping, or landing. The signal to switch is conflict volume in the orchestrator step, not preference.”
The subsection remains in the user-context tier, and project context must never become a superset of the user-level context.

### D6: Land the implementation as five ordered, reversible steps

- **Boundary**: change planning versus repository history.
- **Choice**: implement source packaging, apm composition, skill convergence, user-context routing, and review remediation as separate steps in that order, with each tracked file committed immediately as its own atomic history entry.
- **Rationale**: each step supplies an independently reviewable capability, and each file-level commit can be reverted without discarding unrelated evidence from the same step.
- **Alternatives considered**: one cross-cutting commit or one multi-file commit per step, rejected because either form couples independently reversible files and conflicts with the repository's commit discipline.

These implementation-history commits follow the repository's generic atomic-file discipline.
They are distinct from the one-delivery-commit-per-stack-unit rule emitted by the Task 4 user-context protocol.

### D7: Keep repository-local materialization behind a post-merge relock

- **Boundary**: Nix-composed delivery versus the repository producer path.
- **Choice**: leave the root `apm.lock.yaml` unchanged in this branch, state that a fresh frozen `just agents-install` before relock would materialize the pre-change policy without `mergify-stack`, leave the contents of any existing ignored repository-local `.agents/` tree unspecified, and require a generated `just agents-relock` follow-up only after this change is reachable from `main`.
- **Rationale**: the root producer manifest resolves each package from `cameronraysmith/vanixiets/...#main`, so a branch-local relock cannot resolve the branch's new nested dependency through that path.
- **Alternatives considered**: hand-edit the root lock or treat the Nix-generated `$out/apm.lock.yaml` as repository-local delivery evidence, rejected because neither is generated by the root producer path against the post-merge package revision.

The follow-up must review and commit the generated root lock before a fresh frozen `just agents-install` can claim repository-local delivery of `mergify-stack`.
That follow-up is not an acceptance step for CAM-41.

## Deferred canonical reconciliation

The canonical `first-party-skill-distribution` requirement has three pre-existing conflicts that CAM-41 records but does not repair.

- The `per-harness flat deployment` scenario says apm directly composes `agent-skills,claude,codex,hermes`, while the `targets` argument in `apm-skills-compose` has directly composed only `agent-skills` and `claude` since commit `0efe4489f4` on 2026-06-30 and later Nix modules fan that output out to other harnesses.
- `Build-time apm composition of first-party skills` says apm never runs outside a Nix derivation, while commit `953b0ff9c1` on 2026-09-02 added the intentional repository producer-path `apm-skills-install` app, which invokes apm outside a derivation to materialize `.agents/` and optionally refresh the root lock.
- `Flat skill name preservation` says roughly 70 absolute `@` references remain unchanged, while commit `6961d7a4d9` on 2026-08-26 removed that hand-maintained index and the current generator retains one `@` force-load reference, as recorded in `modules/home/ai/plugins/README.md` under `Corpus orientation` and `Suppression and withholding mechanisms`.

The conflicting canonical text was authored in commit `a97da9fd5f` on 2026-06-29 and entered the canonical corpus through archive commit `e82b86dd68` on 2026-08-27.
Task 6 must keep that canonical file unchanged and carry all three conflicts into a later spec-reconciliation change.

## Gate 1 modality verdicts

| Requirement | stratum | modality | Gate 1 rationale |
| --- | --- | --- | --- |
| Distinct first-party policy and upstream mechanism skills | interface | integration-smoke | This requirement observes static skill delivery and distinct imported entry points at the composed corpus boundary. |
| Release-aligned offline Mergify skill dependency | interface | integration-smoke | This requirement observes dependency identity, offline import resolution, and generated lock evidence at the Nix composition boundary. |
| Stacked landing guidance is conditioned by role and repository mode | interface | integration-smoke | This requirement observes the committed guidance source and rendered user-context output rather than a domain lifecycle or runtime computation. |

No `.feature` or EST artifact is laid out because all three requirements are dependency, import, or static-delivery interface observations exercised by Nix composition and rendered-output smoke tests.

## Risks / Trade-offs

- [Risk] The Mergify release tag and the full commit ref used by apm can diverge while both remain individually valid. → Mitigation: expose both identities from the source package, compare the apm ref to the pinned revision, and build a full-flake structure check that compares both package versions.
- [Risk] A compose assertion can prove that a directory exists while omitting the upstream entry point. → Mitigation: assert `mergify-stack/SKILL.md` under both composed targets.
- [Risk] Editing the upstream text would make future upgrades ambiguous. → Mitigation: copy the pinned tree only into apm's temporary checkout and keep every fleet-specific sentence in `git-stacked-pr-integration`.
- [Risk] The generated context can duplicate or weaken existing VCS rules. → Mitigation: keep the new subsection limited to roles and explicit precedence, link to owning skills, and evaluate the rendered context as a whole.
- [Risk] The canonical `first-party-skill-distribution` scenario names four direct apm targets even though current code composes two and fans out later. → Mitigation: record the contradiction as an undischarged provenance risk in this change and do not claim that CAM-41 repairs it.
- [Trade-off] Two stacked-landing skills remain visible instead of presenting one merged skill. → This preserves source ownership and lets upstream mechanism updates occur without rewriting fleet policy.

## Migration Plan

1. Add and evaluate the source-only Mergify package at the release already used by `mergify-cli-bin`.
   Roll back by reverting only the source-package commit.
2. Add the remote skill dependency, cache pre-warm, drift guard, delivery assertions, and plugin README registration.
   Verify the Nix-composed output rather than inspecting only source files.
   Roll back by reverting the composition commit while leaving the unused source package harmlessly present.
3. Converge `git-stacked-pr-integration` on the upstream mechanism and existing `stack-land` handler.
   Verify retained evidence, retained Git-versus-jj wording, role contracts, and resolved upstream references.
   Roll back by reverting the prose commit without affecting delivery.
4. Add the generated-context protocol and evaluate its rendered output.
   Roll back by reverting the context-generator commit.
5. Reconcile the review findings in the first-party policy and generated user context, add the full-flake release-alignment check, then correct the ignored Task 2 report without tracking it.
   Roll back the tracked corrections in reverse order; the ignored report correction needs no repository-history rollback.

Acceptance requires OpenSpec validation, normal builds of the durable package-version check and its genuine failing-case control, a network-isolated composition build, inspection of both composed skill names and the upstream reference, exact handler-state policy, source-level ownership checks, and evaluation of the generated context.
The generated verification report must cite named attributes, Markdown sections, and commands rather than line numbers.
Activation and a real stack landing are not acceptance steps for this change.

## Open Questions

None.
The pinned upstream tree supplies only `skills/mergify-stack/SKILL.md`, while the landed repository command and package supply the separate landing mechanism.
