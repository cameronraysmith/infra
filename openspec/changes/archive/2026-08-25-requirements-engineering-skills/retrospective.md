# Retrospective: requirements-engineering-skills

> Written: 2026-08-25 (after verify passed with warnings)
> Commit range: `804f0880d2bb..86f948422d74`
> Worktree: shared jj development-join working copy (`/Users/crs58/projects/vanixiets`), not yet merged/archived

---

## 0. Evidence

- **Commit range**: `804f0880d2bb..86f948422d74` (9 commits)
- **Diff size**: +1043 / -41 lines across 26 files (`git diff --stat 804f0880d2bb~1 86f948422d74`)
- **Tasks done**: 25/25 (`grep -cE '^\s*- \[x\]' tasks.md`)
- **Active hours**: not reconstructable from `git log` alone — commit timestamps are available but this retrospective is a cold write with no session-telemetry record of active working time; left unrecorded rather than estimated
- **Subagent dispatches**: not tracked for the implementation commits; this retrospective and its sibling planning artifacts were themselves produced by one subagent dispatch (`ChangeBArtifacts`)
- **New external dependencies**: none — no package, library, or tool dependency was added; all changes are first-party skill prose, two reference markdown files, and one nix generator file
- **Bugs encountered post-merge**: none observed — the change has not yet been archived/merged to `main`, so there is no post-merge window to report against
- **OpenSpec validate state at archive**: not yet archived. Current state (this verify pass): `openspec validate requirements-engineering-skills --type change` → valid; `openspec validate --all --json` → 12/12 items valid, 0 invalid
- **Test coverage signal**: n/a — no automated test suite exists for skill prose or `agents-md.nix` content; guard level is `none`, recorded as a gap rather than hidden (see §2 Misses)

Commit chain (chronological):

```
804f0880d2bb feat(skills): add the WRSPM requirements engineering hub
95f23a5ab33e feat(skills): add the satisfaction argument audit
0c08eaace52a feat(skills): own contract and institution theory in foundations
d42961a35323 feat(skills): route the satisfaction argument through the verification triad
4fa43577ee2f feat(skills): record the WRSPM shear and the openspec corpus relationship
4b18b32fc343 feat(skills): add the stratum dimension to the acceptance layer
677342616299 feat(skills): ground discovery and glossary in designation discipline
0235fd2c3b74 feat(context): integrate the discharge obligation into agent context
86f948422d74 docs(openspec): add requirements-engineering-skills artifacts and delta specs
```

---

## 1. Wins

- [evidence: §0 diff size; `804f0880d2bb`, `95f23a5ab33e`] Both new skills landed as single, complete commits each — no follow-up fixup commits were needed to correct their content, which is some evidence the design settled in the brainstorm/design-record phase before authoring began.
- [evidence: `d42961a35323`, `4fa43577ee2f`, `4b18b32fc343`, `677342616299`; verify.md §8b row 13] All nine routing-edit targets were spot-checked and confirmed to point at a concept the new skills actually carry — no dangling pointer was found among them, which is the concrete outcome the change's own `skill-corpus-interface` capability exists to make checkable.
- [evidence: `docs/notes/development/methodology/meta-requirements-framework-integration.md`, "Falsification criteria, and the first result"; `proposal.md` §"Stratum tagging note, corrected"] The change caught and corrected its own stratification error before this verify pass, by applying the schema's own section-8 discharge check to itself. This is the strongest evidence the schema and the new skills produced this cycle actually cohere with each other rather than existing as parallel, unconnected artifacts.
- [evidence: verify.md §1, §5, §6] Structural validation, the front-door leak detector, and activation delivery (177 skills, both new ones resolving under `~/.claude/skills/`) all passed cleanly with no rework required.

## 2. Misses

- [high] [blocking-for-full-confidence | evidence: verify.md §8b rows 1–10] Ten of the thirteen requirements this change introduces are only partially discharged: `skill-corpus-interface` delivers the guidance but nothing discharges that an agent applies it correctly. No automated test or eval exists to close this gap, and none was created in this cycle. This does not block `openspec validate` or archive (per the schema's own non-blocking design for section 8), but it is a real, currently-open gap rather than a formality.
- [med] [painful | evidence: `design.md` D3; `proposal.md` §"Stratum tagging note, corrected"] The original proposal's all-`behavioral` tagging and its "no machine boundary" defense were both wrong, and the same rationalisation was defended once before being caught a second time by the discharge check. The cost was contained (a proposal rewrite, not a re-implementation), but it means the first version of this change's own contract with itself was incorrect and shipped into the working copy before being caught.
- [low] [nit | evidence: this retrospective's §4] `superpowers:writing-plans` was not invoked live for this cycle; `plan.md` was authored retroactively in this verify/retrospective pass rather than driving the implementation. The plan-vs-actual comparison this schema step exists to support is consequently a plan-matches-actual-by-construction document rather than an independent check.

## 3. Plan deviations

| Plan task | What changed | Why |
|-----------|--------------|-----|
| Task 8 (this pass) | `plan.md` was written after implementation rather than before, and after `tasks.md` and `design.md` rather than driving them | Implementation was already complete and committed when this subagent was dispatched; the assignment was to reconstruct the planning-artifact chain from committed evidence, not to plan forward work. This is the schema's documented "timing note" pattern for `verify.md` (produced after apply, not during planning) extended one step further, to `plan.md` and `tasks.md` as well. |

No other deviation was found between the design record's stated intent and the delivered commits — the nine routing-edit targets, the two new reference files, the contract-senses correction, and the `agents-md.nix` edits all match what the design record and proposal describe.

## 4. Skill / workflow compliance

| Skill                                            | Used |
|--------------------------------------------------|------|
| superpowers:brainstorming                        | unverified |
| superpowers:writing-plans                        | no |
| superpowers:using-git-worktrees                  | no |
| superpowers:subagent-driven-development           | no |
| (transitive) superpowers:test-driven-development | no |
| (transitive) superpowers:requesting-code-review  | unverified |
| superpowers:finishing-a-development-branch       | pending |

> This departs from the schema's default expectation of all-yes. Every "no" or "unverified" is accounted for below.

### Deliberately Skipped Skills

- **`superpowers:writing-plans`**
  - **What was skipped**: The live `writing-plans` dialogue that normally produces `plan.md` from `tasks.md` before implementation.
  - **Why this cycle**: `plan.md` did not exist prior to this verify/retrospective pass (`openspec status --change requirements-engineering-skills --json` showed `plan.artifactPaths.existingOutputPaths: []` at the start of this pass), and implementation was already committed (`804f0880d2bb`..`0235fd2c3b74`) before this subagent was dispatched to complete the planning-artifact chain. There was no implementation left to plan.
  - **How to prevent recurrence**: `scope-judgment rule` — when a subagent is dispatched specifically to backfill planning artifacts for already-implemented work (as this assignment explicitly states), `plan.md` should be written as a record of the micro-steps taken, not as a forward-looking plan, and the retrospective should name this explicitly rather than silently marking the row "yes." No schema or skill change is needed; the schema's own `verify` and `retrospective` instructions already anticipate artifacts produced after the fact — this is that same pattern applied one step earlier in the artifact chain than the schema explicitly documents.

- **`superpowers:using-git-worktrees`**
  - **What was skipped**: Isolating this change's implementation in a dedicated git worktree.
  - **Why this cycle**: This repository is jj-colocated and uses a shared multi-parent development-join working copy by house convention (`CLAUDE.md`, "Making changes in jj-managed or colocated repos"); the nine implementation commits land in that shared working copy via `jj new --no-edit` + `jj squash`, not via `git worktree add`. This subagent's own assignment explicitly forbids creating a worktree or running VCS write commands.
  - **How to prevent recurrence**: `one-off — schema boundary case, no prevention possible`. The `superpowers-bridge-wrspm` schema's apply-phase mechanics assume a git-native worktree model; this repository's own `CLAUDE.md` overrides that with the jj development-join model for every change, not just this one. This is a standing, repository-wide substitution rather than a cycle-specific gap, so there is nothing this cycle could have done differently.

- **`superpowers:subagent-driven-development`**
  - **What was skipped**: Task-by-task subagent dispatch driving the implementation commits.
  - **Why this cycle**: Same root cause as `using-git-worktrees` above — the jj development-join model substitutes direct chain commits (by whichever agent or session authored them) for the worktree-plus-subagent-per-task mechanic `subagent-driven-development` assumes.
  - **How to prevent recurrence**: `one-off — schema boundary case, no prevention possible`, same reasoning as above.

- **`(transitive) superpowers:test-driven-development`**
  - **What was skipped**: Writing a failing test before any implementation edit.
  - **Why this cycle**: The deliverable is prose (skill `SKILL.md` files, reference markdown, a nix string generator) with no executable behavior a unit test can exercise; `verify.md` §8b records this as guard level `none` rather than a silently accepted gap.
  - **How to prevent recurrence**: `one-off — schema boundary case, no prevention possible`. TDD's precondition — an executable contract a test can assert against — does not hold for skill content; the corpus-wide convention (confirmed by inspecting sibling skills such as `preferences-validation-assurance` / `verification-before-completion`) is prose reviewed by routing/ownership checks, not unit tests, and `skill-corpus-interface` now makes that check-set explicit for this class of content rather than leaving it entirely informal.

- **`superpowers:finishing-a-development-branch`**
  - **What was skipped**: Merge/branch-completion and `openspec archive`.
  - **Why this cycle**: The assignment explicitly reserves archive to the orchestrator, after verifying both sibling change chains (`requirements-engineering-skills` and `stratify-change-write-path`).
  - **How to prevent recurrence**: not a skip requiring prevention — this step is correctly deferred, not omitted; it is marked `pending` above rather than `no` for that reason.

`superpowers:brainstorming` and `(transitive) superpowers:requesting-code-review` are marked `unverified` rather than `no`: `brainstorm.md` exists and states the design was settled in a session this retrospective cannot re-observe, and no commit trailer or artifact in this range names a code-review pass. Neither claim ("was used" or "was skipped") is grounded in evidence this subagent could inspect, so neither is asserted.

## 5. Surprises

- The discharge-coherence check did not merely fail to endorse the original all-`behavioral` tagging — it actively contradicted the tagging's own stated rationale. The expectation going into this verify pass was that section 8 might report a routine gap; instead it reported that the proposal's author had rationalized away a boundary the check could name concretely. This is recorded in `design.md` D3 as the central finding this design document exists to preserve, not merely as a surprising log entry here.
- `skill-corpus-interface`'s Trust boundary section, written before this verify pass, already anticipated and disclaimed exactly the partial-discharge outcome this verify pass's §8b table arrived at independently (that the interface properties reach delivery, not content correctness). That the spec's own boundary language matched the verify pass's finding without either being written to match the other is a mild, positive surprise about how carefully the boundary was scoped at authoring time.

## 6. Promote candidates → long-term learning

- [ ] [high] **A schema-mandated self-check (section 8) that contradicts its own author is stronger evidence of instrument validity than a self-check that merely confirms.** → **Promote to memory** (type: feedback)
  > **Why**: This cycle's central finding — the discharge-coherence check catching the proposal's own "no machine boundary" rationalisation, one section after the same rationalisation had already been flagged and defended once — is the strongest available evidence that `superpowers-bridge-wrspm`'s section 8 has real content rather than being ceremony. A check that only ever confirms its author's priors should itself be suspected of co-vacuity.
  > **How to apply**: When evaluating whether a new mandatory check (a lint, a schema gate, a review step) is pulling its weight, look for a case where it disagreed with the person who introduced it, about the artifact that introduced it. Absence of such a case after reasonable exercise is itself a signal worth investigating, not a clean bill of health.

- [ ] [med] **Ten of thirteen requirements in this change carry only a delivery-mechanics discharge, with no automated check for content correctness.** → **Promote to schema** (`superpowers-bridge-wrspm`, or a follow-up change on `pi-agent-environment`)
  > **Why**: `skill-corpus-interface`'s own Trust boundary section states plainly that its properties do not reach whether a skill's guidance is followed or produces a correct outcome, and this verify pass confirms that gap is real and currently unclosed for all ten behavioral requirements introduced here.
  > **How to apply**: When the `world-assumptions` capability extraction from `pi-agent-environment` (named as future work in `design.md` D3) is scheduled, evaluate whether it — or a separate eval harness for skill guidance — is the right mechanism to convert these ten partial discharges into full ones, rather than letting the gap accumulate silently across future changes that also lean on `skill-corpus-interface`.

- [ ] [low] **`plan.md` produced retroactively for already-implemented work should say so in its own header, not just in the retrospective.** → **One-off** (just record it, do not promote)
  > **Why**: This cycle's `plan.md` carries a header note explaining it was written after the fact; without that note, a future reader comparing `plan.md` to the commit history could mistake it for a plan that actually drove the implementation, when it is a reconstruction.
  > **How to apply**: Not general enough to promote — most cycles under this schema will write `plan.md` before implementation, per the schema's own designed order. This is a note for the rare backfill case, already handled locally in this cycle's `plan.md`.
