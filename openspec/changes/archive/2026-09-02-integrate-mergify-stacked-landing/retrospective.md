# Retrospective: integrate-mergify-stacked-landing

> Written: 2026-09-02 (after verify passed with warnings)
> Commit range: `47ca9d8dec2cf10a985e8e6587e10a87c3df741b..451fb2912e5368c7bbe4a41657819c62117798aa`
> Worktree: `/Users/crs58/.treehouse/vanixiets-22808a/4/vanixiets`

---

## 0. Evidence

- **Commit range**: `47ca9d8dec2cf10a985e8e6587e10a87c3df741b..451fb2912e5368c7bbe4a41657819c62117798aa` (72 commits, including the deliberate current-`origin/main` integration commit `300e918eb`)
- **Diff size**: +1,446 / -55 lines across 17 files before this retrospective
- **Tasks done**: 23/23 (`tasks.md` contains 23 checked entries and no unchecked entry)
- **Active hours**: 2 hours 48 minutes 48 seconds by first-to-last commit timestamps in the range
- **Subagent dispatches**: at least 14 evidenced: six task executions, six task-review passes recorded in `.superpowers/sdd/progress.md`, and two whole-branch review rounds; the exact harness dispatch log is not part of the repository
- **New external dependencies**: `Mergifyio/mergify-cli` source and its `mergify-stack` skill at release `2026.8.31.1`, revision `727ce50b8fb3be8a9a24025807e159d644dbba80`, Apache-2.0
- **Bugs encountered post-merge**: n/a because this feature has not merged; current-main integration exposed policy drift before publication
- **OpenSpec validate state at archive**: not at archive; `openspec validate integrate-mergify-stacked-landing --strict` passed before this retrospective, and archive remains unperformed
- **Test coverage signal**: no line-coverage metric; `verify.md` maps 14/14 scenarios, both `structure-mergify-release-alignment` checks build, the negative check exercises the same comparison handler with unequal fixtures, and the offline composition build passes

Commit chain (chronological):

```text
47ca9d8de integrated-main boundary
cf0cc53d5 docs(openspec): scaffold Mergify stacked landing change
171347374 docs(openspec): capture approved Mergify landing design
64ace8e38 docs(openspec): propose Mergify stacked landing integration
64f9cb192 docs(openspec): design Mergify stacked landing integration
bc10dac34 docs(openspec): specify stacked skill coexistence
09ecbd0ab docs(openspec): specify pinned Mergify skill dependency
20bd403ac docs(openspec): specify role-conditioned stacked landing
26a3823f1 docs(openspec): align landing plan with atomic commits
1b83f6b8d docs(openspec): plan Mergify landing implementation tasks
a9db65ff3 docs(openspec): correct Mergify mechanism boundary
2cad35a92 docs(openspec): correct stacked landing design boundary
803279af8 docs(openspec): correct Mergify dependency delta
589803064 docs(openspec): correct skill interface delta
1d9fe0595 docs(openspec): correct Mergify landing tasks
08559da54 docs(openspec): write Mergify landing implementation plan
61bf875c7 docs(openspec): sync CAM-41 readiness state
b57edaab5 docs(openspec): record Gate 1 modality verdicts
54253d44a docs(openspec): align Mergify verification tasks
c64fabb83 docs(openspec): align Mergify verification plan
1fd53042e feat(agent-plugins): pin Mergify skill source
e16124dd5 docs(openspec): complete Mergify source task
c3ebd0c2a docs(openspec): sync CAM-41 implementation state
a23ccacc7 feat(agent-skills): declare upstream Mergify skill
f4b9417db docs(openspec): specify APM cache URL normalization
79522ae6a docs(openspec): align APM cache shard task
445f4638a docs(openspec): align APM cache shard plan
e9af49c2c feat(agent-skills): compose upstream Mergify skill
d27f90df8 docs(agent-skills): register Mergify mechanism skill
43e9589b5 docs(openspec): complete Mergify composition task
08fabc066 docs(agent-skills): converge stacked landing policy
b5a0ae72f docs(openspec): complete stacked landing policy task
e530852d0 docs(openspec): define stacked protocol precedence
c8d27638a docs(openspec): resolve stacked delivery precedence
4e47a9b4a docs(openspec): sharpen context protocol task
046d7d3ce docs(openspec): specify context protocol precedence
168f4b849 docs(agents): add stacked landing role protocol
f6fa385bd docs(openspec): complete user context protocol task
96dd80314 docs(openspec): verify rendered soft note
ef5fba3ca docs(openspec): fix soft note verifier target
68c276d57 chore(openspec): record integration verification
4b015ad01 docs(openspec): verify Mergify landing integration
300e918eb Merge remote-tracking branch 'origin/main' into cam-41-land-changes-through-a-git-native-stacked-pr-protocol
288845b7c docs(openspec): clarify reviewed delivery intent
1367ac9cf docs(openspec): design review remediation
f4bcfba6c docs(openspec): distinguish evidence provenance
128de9f1b docs(openspec): assign stack publication ownership
b8fa5dcd4 docs(openspec): separate skill delivery paths
9fcefed64 docs(openspec): add review remediation task
ee23d005b docs(openspec): plan review remediation
2f9caff29 docs(agent-skills): correct stacked landing policy
c57fe0494 docs(agents): assign stack publication to orchestrator
4e115a65f docs(openspec): inject Mergify binary sibling
380568a49 docs(openspec): specify release mismatch failure
627ba1eb5 docs(openspec): correct release assertion task
ecae9cf48 docs(openspec): correct release assertion plan
2bf29650f docs(openspec): route Mergify alignment to checks
3795519b5 docs(openspec): design Mergify alignment check
0dd6370f7 docs(openspec): specify Mergify alignment check
a14ed679b docs(openspec): task Mergify alignment check
f9ea13d56 docs(openspec): plan Mergify alignment checks
92a535e93 test(checks): enforce Mergify release alignment
51cedffce docs(openspec): complete review reconciliation task
827fd0fc9 docs(openspec): correct feature scope boundary
df6cf6e77 docs(openspec): classify integrated main provenance
1d3c479fe docs(openspec): reverify Mergify landing integration
41cac9fb2 docs(openspec): supersede brainstorm review record
2bb5deeaf docs(openspec): narrow repository materialization claim
55f29b2d3 docs(openspec): bound ignored materialization evidence
babdd4aa5 docs(openspec): specify fresh materialization boundary
e2b91d842 docs(openspec): clarify materialization task evidence
197cade1d docs(openspec): constrain materialization evidence
451fb2912 docs(openspec): refresh Mergify verification boundaries
```

## 1. Wins

- The transcript reconnaissance in `/Users/crs58/firstmate/data/vx-skills-vendoring-intent/report.md` answered the acquisition, policy-ownership, context-tier, and Cognee-scope questions before planning began.
  Firstmate then designated that report as the evidence base in inbox message `001.msg`, so the change could preserve the Nix and APM coexistence model without reopening already resolved intent.
- Task 2's failed offline build identified APM 0.29.0's lowercase GitHub URL normalization at the actual cache boundary.
  Commits `f4b9417db` through `445f4638a` corrected the plan, task, and design before commit `e9af49c2c` produced the successful offline composition.
- Integrating current `origin/main` in `300e918eb` brought the landed handler and tests into the review surface.
  The first whole-branch review then caught that the first-pass policy assigned publication too broadly and described the handler as accepting only `SUCCESS`, while the current handler also accepts `NEUTRAL` and `SKIPPED`; commits `2f9caff29` and `c57fe0494` aligned the policy and rendered context with the executable behavior.
- The release-alignment property moved to the established build-time structure-check boundary after two package-level sibling lookups produced fixed-point recursion.
  Firstmate inbox message `004.msg` directed the work to the `modules/lib/mk-eval-check.nix` and `modules/checks/aeneas-toolchain.nix` idiom, and commit `92a535e93` records the resulting full-flake check.
- `structure-mergify-release-alignment-neg` is a genuine negative control rather than a second passing fixture.
  It invokes the same checker with unequal values, requires the checker to fail, and verifies that both values appear in the diagnostic, as recorded in Task 6's current report and `verify.md`.
- The second whole-branch review corrected evidence boundaries rather than changing implementation behavior.
  Commits `827fd0fc9` through `451fb2912` distinguish integrated-main files from CAM-41 feature files, supersede the stale brainstorm sequence, and replace claims about mutable ignored `.agents/` state with the narrower fresh-frozen-install claim.
- The temporal-provenance audit found three canonical conflicts instead of silently treating one document type as authoritative.
  `design.md` records that canonical text from `a97da9fd5f` and archive commit `e82b86dd68` conflicts with the two-target implementation from `0efe4489f4`, the producer installer from `953b0ff9c1`, and the post-index generator from `6961d7a4d9`.
- The six current task reports preserve RED/GREEN commands, atomic commits, and bounded claims.
  The tracked implementation remains path-atomic, and `verify.md` separates authored source, Nix-composed output, rendered context, root-lock materialization, and external effects.

## 2. Misses

### Process and implementation misses

- [med] [painful | `.superpowers/sdd/task-2-report.md`] The first cache pre-warm hashed the mixed-case manifest URL, but APM hashes a normalized lowercase GitHub URL, so the offline build attempted the network before the brief and plan were corrected.
- [med] [painful | `.superpowers/sdd/task-6-report.md`] Two package-level approaches attempted to read a sibling package while the package set was still being constructed and both produced infinite recursion before the check moved to the full-flake structure layer.
- [med] [painful | `300e918eb`, `2f9caff29`, `c57fe0494`] The initial policy and generated context drifted from the current handler's accepted check states and did not reserve stack publication solely for the orchestrator.
- [low] [nit | `96dd80314`, `ef5fba3ca`] The first Task 4 verifier checked whitespace-sensitive source text instead of the rendered context and needed a verifier-only correction.
- [low] [nit | `.superpowers/sdd/task-2-report.md`] The ignored Task 2 report retained a stale blocked conclusion after its own successful resolution until Task 6 corrected the mutable report.
- [med] [painful | `41cac9fb2` through `451fb2912`] The first post-Task-6 verification still carried a four-step brainstorm and inferred existing ignored `.agents/` contents from the root lock; the final review required seven documentation corrections and a refreshed verification report.

### Unresolved warnings

- [med] [warning | `verify.md` W1–W3] Three pre-existing canonical requirements still conflict with current implementation: four direct APM targets versus two plus Nix fan-out, build-only APM execution versus the producer installer, and roughly 70 absolute autoload references versus one current force-load reference.
- [high] [blocking follow-up | `verify.md` W4] The root `apm.lock.yaml` remains unchanged.
  After CAM-41 reaches `main`, a separate branch must run `just agents-relock`, review and commit the generated root lock, and only then claim fresh frozen repository-local `.agents/` delivery of `mergify-stack`.
- [med] [warning | `verify.md` W5] The task reports record no activation or landing command in this execution, but repository files and local logs cannot prove that no external actor performed either action.
- [med] [warning | `verify.md` W6] The verified branch has not been pushed and no pull request has been opened; publication remains owned by the separately authorized finishing workflow.
- [low] [nit | `verify.md` S1] Ten canonical main specs retain pre-existing purpose placeholders, including the three capabilities modified here.

## 3. Plan deviations

| Plan task | What changed | Why |
|---|---|---|
| 2.2 | The cache shard hashes lowercase `https://github.com/mergifyio/mergify-cli` while the manifest retains `Mergifyio/mergify-cli`. | APM 0.29.0 normalizes GitHub owner and repository components before hashing; the mixed-case shard was unused and the offline build fell through to the network. |
| 4.2–4.3 | The exact soft-note assertion moved from the Nix source to evaluated rendered context. | The source's indentation is an implementation detail; the requirement concerns delivered user context. |
| Original four-step sequence | Review remediation became a fifth independently shippable step and Task 6. | The current-origin review found publication ownership, handler-state, evidence-scope, and release-alignment gaps after the initial integration verification. |
| 6.3 initial approach | Release agreement moved from `apm-skills-compose` package evaluation to `modules/checks/structure/mergify-release-alignment.nix`. | Both direct and argument-shaped sibling lookups re-entered the package-set fixed point; the build-time structure-check idiom compares fully evaluated package outputs without self-reference. |
| 6.4 evidence wording | Claims about the existing ignored `.agents/` tree became an explicit unknown; only a fresh frozen pre-relock install is characterized. | Ignored materialized state is mutable and cannot be inferred from the unchanged tracked root lock. |
| Completion boundary | The post-main root relock, push, pull request, activation, and real landing remain outside this change's completed acceptance work. | The approved scope assigns relock and publication to later authorized workflows and excludes activation and landing from CAM-41 acceptance. |

## 4. Skill / workflow compliance

| Skill | Used |
|---|---|
| `superpowers:brainstorming` | yes — the approved decision chain is in `brainstorm.md`, grounded by the transcript reconnaissance report |
| `superpowers:writing-plans` | yes — `plan.md` defines six tasks, verification commands, interfaces, and rollback boundaries |
| `superpowers:using-git-worktrees` | yes — the cycle ran in the Firstmate-provided treehouse worktree recorded in §0 rather than creating a nested worktree |
| `superpowers:subagent-driven-development` | yes — six current task briefs and six current task reports exist under `.superpowers/sdd/` |
| `(transitive) superpowers:test-driven-development` | yes — each implementation report records RED and GREEN evidence; Task 6 adds a failing-case control that exercises the production checker |
| `(transitive) superpowers:requesting-code-review` | yes — `.superpowers/sdd/progress.md` records each task review, and the two whole-branch review rounds produced the Task 6 and final evidence-boundary corrections |
| `superpowers:finishing-a-development-branch` | no — Firstmate retained delivery-mode authority, and `verify.md` W6 records no push or pull request |

### Deliberately Skipped Skills

- **`superpowers:finishing-a-development-branch`**
  - **What was skipped**: the branch-finishing option selection and any resulting merge, push, pull-request, or cleanup action.
  - **Why this cycle**: Firstmate inbox message `001.msg` says “Do not choose delivery modes; that is firstmate's,” while the change scope prohibits a real landing and `verify.md` W6 records the unpushed state.
  - **How to prevent recurrence**: `one-off — schema boundary case, no prevention possible` because the Firstmate lane deliberately separates verified implementation from its externally authorized delivery decision; the later delivery owner must invoke the finishing workflow rather than retroactively treating verification as finishing.

## 5. Surprises

- APM's cache identity is not the manifest's display spelling: version 0.29.0 lowercases GitHub path components before hashing, so a byte-faithful mixed-case pre-warm does not satisfy offline lookup.
- Integrating current `origin/main` changed the relevant handler semantics from the branch's earlier view: `NEUTRAL` and `SKIPPED` became permitted conclusions with explicit positive tests.
- A package cannot safely assert equality against a sibling reached through the same still-forming package set; reshaping the argument did not remove the fixed-point cycle.
- The tracked root lock constrains what a fresh frozen producer install would materialize, but it says nothing reliable about files already present in a mutable ignored `.agents/` tree.
- The first canonical-conflict inventory was incomplete.
  Git provenance exposed three conflicts whose relative recency differed, so the change retained them as explicit warnings instead of selecting a silent winner.
- A passing implementation verification did not imply that the planning history and evidence language were current.
  The second review still found a stale brainstorm sequence, feature-scope attribution, and overbroad materialization claims.

## 6. Promote candidates → long-term learning

- [ ] [med] **Derive offline cache keys with the dependency tool's canonicalization algorithm, while preserving upstream spelling in manifests.** → **Promote to skill** (`third-party plugin dependency` planning guidance)
  > **Why**: Task 2's mixed-case pre-warm created an unused shard and caused an offline Nix build to attempt the network.
  > **How to apply**: Before adding a pre-warmed remote checkout, inspect the installed resolver's URL normalization and add a failing offline build before the cache implementation.

- [ ] [high] **Compare sibling package properties only after the package set is fully composed.** → **Promote to project CLAUDE.md** (Nix structure-check guidance)
  > **Why**: Two `apm-skills-compose` designs re-entered the package fixed point and failed with infinite recursion, while the existing build-time structure-check idiom accepted both evaluated values safely.
  > **How to apply**: When a Nix invariant relates two flake package outputs, route it through a `modules/checks/structure/` derivation and include a failing-case control instead of reading one package from inside the other.

- [ ] [high] **Review policy against the current effect handler after integrating the current mainline.** → **Promote to schema** (`superpowers-bridge-wrspm` review gate)
  > **Why**: Commit `300e918eb` introduced the current handler predicate, and the following review found both accepted-state and publication-owner drift in the first-pass guidance.
  > **How to apply**: Before final verification of policy that names an existing handler, integrate the approved mainline boundary and compare the policy with the handler plus its positive and negative tests.

- [ ] [med] **Treat ignored materialized trees as unknown unless a fresh generation command produced the observed tree.** → **Promote to skill** (`openspec-verify-change` evidence-boundary guidance)
  > **Why**: The unchanged root lock supports a claim about a fresh frozen install, but the final review found that it cannot establish the current contents of mutable ignored `.agents/` state.
  > **How to apply**: When verification crosses from a tracked producer or lock to an ignored output tree, either run the producer and inspect that result or state the existing tree's contents as unspecified.

- [ ] [med] **Carry temporal provenance into canonical-conflict review before syncing deltas.** → **Promote to schema** (`superpowers-bridge-wrspm` pre-sync review)
  > **Why**: Git history distinguished three older canonical statements from later implementation changes and prevented CAM-41 from silently claiming to repair unrelated requirements.
  > **How to apply**: When a delta relies on canonical prose that conflicts with current code or working notes, record the conflicting commits and dates, retain the gap as a warning, and require a separate reconciliation decision.
