# Verification Report

> This file is produced by the `openspec-verify-change` skill after apply completes, to confirm that the implementation is consistent with the specs, design, and tasks.
> Any failed check must be returned to its corresponding artifact for correction before verification runs again.

**Change**: `integrate-mergify-stacked-landing`
**Verified at**: `2026-09-02 23:18 EDT`
**Verifier**: `Codex verify_change subagent`
**Integrated-main boundary**: `47ca9d8dec2cf10a985e8e6587e10a87c3df741b`
**Feature tip before this report**: `80431096c7f443262c09ba1da3c09aaf8c01351e`

## Summary

| Dimension | Status |
|---|---|
| Completeness | 23/23 tasks complete; 3/3 delta requirements have implementation evidence |
| Correctness | 3/3 requirements and 14/14 scenarios map to package attributes, Markdown contracts, or exact commands |
| Coherence | 7/7 design decisions are reflected in implementation and verification evidence; three pre-existing canonical conflicts remain explicit |

No critical issue was found.
The change passes verification with six warnings and one suggestion.

## Issues by priority

### Critical

None.

### Warnings

- **W1 — Direct-target provenance remains undischarged.**
  The canonical `first-party-skill-distribution` scenario says apm directly composes `agent-skills,claude,codex,hermes`, while `apm-skills-compose` directly composes only `agent-skills` and `claude` and later Nix modules fan that output out.
  Reconcile the canonical direct-target model in a separate change before citing it as evidence for four direct apm outputs.
- **W2 — The canonical apm execution boundary contradicts the producer installer.**
  The canonical `Build-time apm composition of first-party skills` requirement says apm never runs outside a Nix derivation, while the current `apm-skills-install` app deliberately runs apm as the repository producer path for `just agents-install` and `just agents-relock`.
  Reconcile the canonical statement with the intentional producer-path exception in a separate spec change.
- **W3 — The canonical absolute-autoload census is stale.**
  The canonical `Flat skill name preservation` scenario says roughly 70 absolute `@` references remain unchanged, while `rg --no-filename '@\$\{skillsPath\}' modules/home/tools/agents-md.nix | wc -l` returns one.
  Reconcile that scenario with the current catalog-driven corpus and single force-load reference in a separate spec change.
- **W4 — Repository-local materialization requires a post-main follow-up.**
  The Nix-composed output contains `mergify-stack`, but the unchanged root `apm.lock.yaml` does not; repository evidence does not establish the contents of any existing ignored repository-local `.agents/` tree.
  A fresh frozen `just agents-install` before the post-main generated relock would materialize the pre-change set and would not establish `mergify-stack` delivery.
  After this change reaches `main`, a separate branch must run `just agents-relock`, review and commit the generated root lock, and only then claim frozen repository-local `.agents/` delivery of `mergify-stack`.
- **W5 — Repository artifacts cannot prove absence of external activation or landing.**
  The feature diff contains no activation or landing implementation, and the Task 6 execution report records that it invoked neither operation.
  Repository artifacts and local command logs cannot establish that no external actor activated a configuration or landed a stack elsewhere.
  Treat “no activation or real landing” as an execution-scope statement, not a repository-proven global fact.
- **W6 — Delivery has not been pushed.**
  At the pre-report check, the branch was 71 commits ahead of `origin/main` with no upstream-only commit, and this verification was prohibited from pushing or opening a pull request.
  Resolve publication during the authorized finishing workflow; the local delivery state does not invalidate verification against the integrated-main boundary.

### Suggestions

- **S1 — Main-spec purpose placeholders remain.**
  `openspec validate --all --json` reports pre-existing placeholder-purpose warnings for ten main specs, including the three capabilities modified here, while reporting this change itself valid with no issues.
  Replace those placeholders through separate main-spec maintenance rather than widening CAM-41.

## 1. Structural validation

- [x] All items report `"valid": true` under plain all-item validation.

**Result**:

```text
openspec validate integrate-mergify-stacked-landing --strict: valid
openspec validate --specs --json: 15 passed, 0 failed
openspec validate --all --json: 20 passed, 0 failed (5 changes, 15 specs)
openspec validate --all --strict --json: 10 passed, 10 failed (5 changes, 5 specs passed)
```

Plain validation emitted informational long-requirement notices and the placeholder-purpose warnings summarized in S1, but no invalid item.
`openspec validate --all --strict --json` reports 10 of 20 items valid: all five changes and five specs pass, while ten specs fail solely because strict mode promotes each pre-existing placeholder-`Purpose` warning.
Every strict-mode failure has exactly one warning at the `overview` path for that placeholder and no structural error; the accompanying long-requirement notices are informational.

| Item | Type | Issues |
|---|---|---|
| — | — | No change-specific strict or plain-validation failures; S1 accounts for all combined strict-mode failures |

## 2. Task completion (`tasks.md`)

- [x] Every task entry is complete.

The CLI-resolved task file contains 23 `- [x]` entries and no `- [ ]` entry.
This count includes all six Task 6 review-remediation tasks, including the normal and negative release-alignment structure checks.

| Task | Reason incomplete | Blocks archive? |
|---|---|---|
| — | No incomplete tasks | No |

## 3. Delta spec sync state

The delta files were resolved from `artifactPaths.specs.existingOutputPaths` in `openspec status --change integrate-mergify-stacked-landing --json`.
All three delta requirement blocks and their 14 scenarios now match their canonical blocks exactly.

| Capability | Sync status | Notes |
|---|---|---|
| `first-party-skill-distribution` | Synced in `7733bb335` | `Distinct first-party policy and upstream mechanism skills` matches exactly with all three scenarios |
| `third-party-plugin-dependency` | Synced in `c8db6c710` | `Release-aligned offline Mergify skill dependency` matches exactly with all five scenarios, including W4 |
| `skill-corpus-interface` | Synced in `80431096c` | `Stacked landing guidance is conditioned by role and repository mode` matches exactly with all six scenarios |

An exact comparison from each named `### Requirement:` anchor through its final scenario produces no diff, and each canonical heading occurs once; this establishes sync idempotence because another sync would add nothing.
The three sync commits have addition/deletion counts `28/0`, `52/0`, and `59/0`; they appended the new blocks without editing the older canonical `Build-time apm composition of first-party skills`, `per-harness flat deployment`, or `Flat skill name preservation` anchors.
W1 through W3 therefore remain unresolved canonical conflicts rather than reconciliations performed by this sync.

## 4. Requirement and scenario correctness

| Requirement | Current scenarios covered | Evidence | Gap |
|---|---|---|---|
| `Distinct first-party policy and upstream mechanism skills` | `Both stacked-landing skills are composed`; `Evidence and routing text retain distinct provenance`; `Upstream skill is added` | `nix build --option builders '' .#apm-skills-compose --no-link --print-out-paths` produced both skill names under `.claude/skills` and `.agents/skills`; `cmp` matched both upstream copies to the pinned source; `git-stacked-pr-integration` sections `Stacked PR integration policy`, `Role contracts`, and `VCS routing` retain the exact evidence sentence, its narrowed provenance, and the exact soft note | None within the delta; W1 through W3 remain canonical conflicts |
| `Release-aligned offline Mergify skill dependency` | `Source and executable releases agree`; `Mergify skill composes offline`; `Dependency revision drifts`; `Upstream source is composed without modification`; `Repository-local materialization waits for the merged producer package` | Package attributes `.#packages.aarch64-darwin.agent-plugins-mergify-cli.version` and `.#packages.aarch64-darwin.mergify-cli-bin.version` both evaluate to `2026.8.31.1`; check attributes `.#checks.aarch64-darwin.structure-mergify-release-alignment` and `.#checks.aarch64-darwin.structure-mergify-release-alignment-neg` both build; `.#apm-skills-compose` builds offline and its generated lock records revision `727ce50b8fb3be8a9a24025807e159d644dbba80` plus matching file hashes; exact root-lock commands establish W4 | Existing ignored `.agents/` contents are unspecified; a fresh frozen pre-relock install would materialize the pre-change set |
| `Stacked landing guidance is conditioned by role and repository mode` | `Worker prepares one stack step`; `Orchestrator prepares a Git-native landing`; `Landing policy evaluates reported check conclusions`; `Repository is jj-managed`; `Stacked delivery narrows the generic commit rule`; `OMP composes user and project context` | `git-stacked-pr-integration` sections `Role contracts`, `Requirement-to-mechanism map`, `Checked landing boundary`, and `VCS routing`; evaluated user-context section `Stacked landing protocol`; integrated-main `stack-land` predicate and tests | None within the delivered-text interface; actual authorization and landing remain outside the claim |

The first-party `git-stacked-pr-integration` skill owns fleet policy, roles, routing, and evidence, while upstream `mergify-stack` owns stack authoring and publication mechanics.
The policy and rendered context identify the orchestrator as the sole actor authorized to publish: the worker may use the upstream authoring and rewrite mechanics locally, prepares and verifies one change, and returns its ref and evidence without publishing or landing; the orchestrator alone orders refs, publishes their pull-request stack through `mergify-stack`, and invokes `stack-land` for the checked final effect.

The exact reported-check predicate is `length(checks) > 0` and every reported `.state` belongs to `{SUCCESS, NEUTRAL, SKIPPED}`.
The handler rejects an empty array and selects every state outside that set as a blocking failure; merged tests cover permitted `NEUTRAL` and `SKIPPED`, pending and failing states, and an unrecognized value.
The separate post-push predicate requires an object whose state is `MERGED` and whose `mergedAt` value is a string.

## 5. Design coherence

| Decision | Implementation correspondence | Status |
|---|---|---|
| D1: Pin a source-only Mergify package beside the existing binary package | Source package attribute plus normal and negative full-flake release-alignment checks | Followed |
| D2: Compose `mergify-stack` through the established remote-dependency path | Version-control-and-forge apm manifest, normalized checkout-cache shard, drift guard, `.#apm-skills-compose`, and its generated lock | Followed |
| D3: Keep first-party policy and upstream mechanism distinct | `git-stacked-pr-integration` sections `Stacked PR integration policy`, `Role contracts`, and `Requirement-to-mechanism map` assign policy, roles, routing, and evidence to the first-party skill; upstream `mergify-stack` owns stack authoring and publication mechanics, while only the orchestrator has authority to publish | Followed |
| D4: Treat `stack-land` as the existing landing handler | Policy section `Checked landing boundary` matches the integrated-main command and test predicate exactly | Followed |
| D5: Put the role boundary in the user-context tier | Evaluated `Stacked landing protocol` preserves worker/orchestrator, VCS, jj, commit-rule, and containment boundaries | Followed |
| D6: Land the implementation as five ordered, reversible steps | Tracked implementation edits remain path-atomic, including the Task 6 policy, context, and structure-check commits | Followed |
| D7: Keep repository-local materialization behind a post-merge relock | Root lock is unchanged; existing ignored `.agents/` contents are unspecified; a fresh frozen pre-relock install would materialize the pre-change set; W4 records the mandatory generated follow-up | Followed |

The brainstorm explicitly supersedes its original four-step sequence and single-conflict inventory with the approved five-step sequence: source packaging, apm composition, skill convergence, user-context routing, and review remediation.
Its current inventory matches design D6 and the design section `Deferred canonical reconciliation`, whose three conflicts are W1, W2, and W3 above.
No other design/spec divergence was found.

## 6. Implementation signal and provenance boundaries

- [x] No unstaged or uncommitted implementation file was present before updating this report.
- [ ] All related commits have been pushed.

**Feature range**: `47ca9d8dec2cf10a985e8e6587e10a87c3df741b..80431096c7f443262c09ba1da3c09aaf8c01351e`.

`origin/main`, the merge base, and the recorded integrated-main boundary all resolve to `47ca9d8dec2cf10a985e8e6587e10a87c3df741b`.
`git log 33f94e2ce..47ca9d8dec2cf10a985e8e6587e10a87c3df741b -- pkgs/by-name/stack-land modules/home/tools/stack-land.nix` attributes `pkgs/by-name/stack-land/stack-land.sh` and `pkgs/by-name/stack-land/test-stack-land.sh` to that integrated-main commit.
`git diff --name-only 47ca9d8dec2cf10a985e8e6587e10a87c3df741b..HEAD -- pkgs/by-name/stack-land modules/home/tools/stack-land.nix` is empty.
Those merged `stack-land` files are integrated-main provenance, not CAM-41 feature edits.

The `pkgs/by-name/apm-skills-compose/package.nix` blob at the feature tip equals its Task 2 blob from `e9af49c2`; Task 6 adds the alignment checks without changing composition.
`git diff --quiet 33f94e2ce..HEAD -- apm.lock.yaml` exits zero, and `rg -q 'Mergifyio/mergify-cli|mergify-stack' apm.lock.yaml` finds no match.
The lock generated inside the `.#apm-skills-compose` Nix output contains the Mergify revision and hashes, but it is not the repository root lock and does not prove delivery through repository-local `.agents/`.
Repository artifacts do not establish the contents of any existing ignored `.agents/` tree; the unchanged root lock establishes instead that a fresh frozen `just agents-install` before relock would materialize the pre-change set.
The mandatory producer-path follow-up is W4.

The feature diff contains no Cognee path, binary or home-manager Mergify change, `stack-land` change, nixbot or ruleset setting, or root-lock edit.
The push checkbox remains open because external publication was excluded from this verification task.

## 7. Front-door routing leak detector

- [x] No files exist under `docs/superpowers/specs/*.md`.

The null-glob probe reported `leak-count=0`.

| File | Content captured into change? | Recommended action |
|---|---|---|
| — | No leak | None |

## 8. Deferred manual dogfood versus automated-test equivalence

`plan.md` contains no `[~]` deferred row, so no equivalence table is required.
Activation and a real landing are explicit non-goals rather than deferred acceptance checks.
Their exclusion does not convert the external-action proof limitation in W5 into repository evidence.

| Deferred dogfood | Equivalent automated test | Coverage assessment | Real gap? |
|---|---|---|---|
| — | — | No deferred rows | No |

## 9. Designation lint and discharge coherence

### 9a. Designation lint

The proposal tags all three modified capabilities as `interface` and tags none as `behavioral`.
The behavioral-noun lexer pass is therefore not applicable.
`openspec/specs/world-assumptions/spec.md` exists, so this is not a vacuous clean result caused by a missing designation table.

### 9b. Discharge coherence

| Requirement | Discharged by (S) | Under (W) | Status |
|---|---|---|---|
| Distinct first-party policy and upstream mechanism skills | Distinct named entry points in the `.#apm-skills-compose` output plus the first-party policy's ownership, evidence, and routing sections | No named world assumption is needed for this static Nix-output observation | Discharged at the declared two-target interface; W1 through W3 remain undischarged canonical provenance conflicts |
| Release-aligned offline Mergify skill dependency | Equal package attributes, normal and genuine negative-control structure checks, offline composition, generated-lock revision and hashes, byte comparison, unchanged root lock, and the explicit post-main relock obligation | Task-local upstream fact that tag `2026.8.31.1` resolves to `727ce50b8fb3be8a9a24025807e159d644dbba80`; no reusable world-assumption id is claimed | Discharged at the Nix build boundary; existing ignored `.agents/` contents remain unspecified, and fresh frozen repository-local delivery remains pending W4 |
| Stacked landing guidance is conditioned by role and repository mode | First-party policy sections plus evaluated user-context text containing sole publication ownership, the exact check predicate, commit precedence, VCS routing, jj authority, exact note, and containment rule | Integrated-main handler behavior is established by command source and tests; no named world assumption is needed for the static guidance observation | Discharged for authored, composed, and rendered text; authorization, external activation, forge state, and landing success remain outside the claim |

### 9c. Alphabet check

No alphabet violation was found.
The requirements observe package attributes, check builds, Nix build products, generated locks, named skill entry points, and rendered context text, all of which are machine-visible interface phenomena.
Role and landing language describes the contract the interface must expose, and each delta's trust-boundary paragraph declines to claim actual worker behavior, authorization, forge state, repository-local delivery before relock, or landing success.

## Overall decision

- [ ] PASS — may proceed without qualifications.
- [x] PASS WITH WARNINGS — the delta specs are synced and the change may proceed to archive while retaining W1 through W6.
- [ ] FAIL — return to a failed artifact and correct it.

**Next step**:

Review the completed retrospective and retain W1 through W6 and S1 when archiving; the three delta capabilities require no further sync.
After CAM-41 reaches `main`, complete W4 on a separate branch by running `just agents-relock`, reviewing and committing the generated root lock, and only then claiming repository-local `.agents/` delivery.
Do not infer authorization to push, activate, invoke `stack-land`, or perform a real landing from this verification verdict.
