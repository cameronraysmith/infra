# Retrospective: configure-pi-agent-environment

> Written: 2026-08-16 (after verify passed)
> Commit range: `e276ba799866b6f7b562895880957795bc8162f9..66979ae73d1e368e4a9aff3ea4fa614258e94fef`
> Worktree: isolated Git clone at `/private/tmp/vanixiets-pi-policy-repair`

---

## 0. Evidence

> Up-front quantified data — later Wins / Misses bullets reference it directly, avoiding repeated evidence blocks.

- **Commit range**: `e276ba799866b6f7b562895880957795bc8162f9..66979ae73d1e368e4a9aff3ea4fa614258e94fef` (14 commits before this retrospective commit)
- **Diff size**: +7,103 / -26 lines across 16 files
- **Tasks done**: 52/52 (`grep -cE '^\s*- \[x\]' tasks.md` → 52; total task checkboxes → 52)
- **Active hours**: 51 h 01 m elapsed commit window, from `8f2bc9a80` at 2026-08-13 17:47:06 -0400 through `66979ae73` at 2026-08-15 20:48:18 -0400; this includes human-gate waits and is not a labor-hours estimate
- **Subagent dispatches**: 81 fresh Herdr Pi launches, including this retrospective author; structurally counted in the parent session JSONL as assistant Bash tool calls containing both `herdr pane run` and the exact `pi --provider openai-codex --model gpt-5.6-sol:high` launch, excluding continuation prompts to already-running agents
- **New external dependencies**: `rytswd/pi-agent-extensions` at `c700f300707db5345727052682c88e3064030aa2` (MIT, source-only fixed-output package); checked-in Catppuccin theme content from `aldoborrero/pi-agent-kit` at `128c4c08396961ea8f934111ba1aad0b33c525b2` (MIT). No flake input was added.
- **Bugs encountered post-merge**: none; the branch has not been merged, and all defects below were found before merge
- **OpenSpec validate state at archive**: not archived; fresh pre-retrospective all-item validation was 9/9 valid, and `verify.md` records PASS
- **Test coverage signal**: 189/189 policy cases, 21/21 live deployed permission-policy cases, three independent Pi regulators, 24 smoke mutation cases, 52/52 tasks, 25/25 requirement/scenario mappings, and 9/9 OpenSpec items valid (`.superpowers/sdd/task-4-report.md`, `task-8-report.md`, `task-10-report.md`, and `verify.md`)

Commit chain (chronological):

```text
8f2bc9a80 docs(pi): plan nix managed environment
5f89b6616 feat(pi): package selected extensions
b4db1ffb6 feat(pi): compose exact resources and theme
84c9519a3 feat(pi): enforce agent safety policy
c3882c349 fix(pi): model jj development join correctly
a0e48b30b test(pi): verify aggregate agent startup
0ae3977c7 test(pi): verify pre-activation environment
6a6d527a1 docs(pi): record Darwin rollback generation
835a6e75c test(pi): verify activated environment
38d1525bd fix(pi): fail closed on unclassified shell mutations
b1e53641e fix(pi): preserve recognized shell reads
b70cfaeb4 fix(pi): honor curl get negation order
6ab78945e test(pi): verify remediated live policy
66979ae73 docs(openspec): verify pi agent environment
```

---

## 1. Wins

- [evidence: `5f89b6616`, `b4db1ffb6`, `.superpowers/sdd/task-5-report.md`] The implementation kept the dependency boundary narrow: one fixed-output source package, six positive selectors, two explicit negative selectors, no `node_modules`, no new flake input, and an unchanged `modules/checks/packages.nix` auto-map.
- [evidence: `84c9519a3`, `c3882c349`, `38d1525bd`, `b1e53641e`, `b70cfaeb4`] RED-first tables converted shell, Git, jj, capability, and adapter assumptions into a closed regression surface that finished at 189 passing policy cases rather than leaving review findings as prose.
- [evidence: `a0e48b30b`, `.superpowers/sdd/task-4-report.md`] The actual deployed Pi 0.84.1 wrapper was exercised once in a hermetic aggregate environment with strict JSONL parsing, 24 mutation cases, zero provider-triggering requests, bounded process-group cleanup, stdin closure, and exit status 0.
- [evidence: `6a6d527a1`, `835a6e75c`, `6ab78945e`, `.superpowers/sdd/task-10-report.md`] The human-only activation boundary held across two activations: the parent session audit found zero agent `just activate --ask` invocations, while live probes established active `system-54-link` and exact N-1 rollback `system-53-link`.
- [evidence: `verify.md`] The final verification mapped all 25 requirements and 25 scenarios to implementation and evidence, found 52/52 tasks complete, and reported 9/9 OpenSpec items valid with no warnings or deferred `[~]` rows.

## 2. Misses

- [high] [blocking | evidence: `.superpowers/sdd/task-8-report.md`, `38d1525bd`] Final review found four fail-open cases after the first activation: `curl --expand-data`, an unknown future curl long option, and unresolved persistent Git and jj aliases. The policy needed a closed-world option/subcommand model earlier, before activation.
- [high] [blocking | evidence: `.superpowers/sdd/task-8-report.md` “Curl GET negation-order follow-up”, `b70cfaeb4`] The ordered analyzer treated `--get --no-get` as if GET semantics remained enabled, allowing two data-bearing mutations. The initial tests covered positive state setting but not the inverse transition or later restoration.
- [med] [painful | evidence: `.superpowers/sdd/task-8-report.md` “Review follow-up RED”, `b1e53641e`] The first fail-closed correction overprompted recognized read-only curl flags, deployed Git built-ins, and terminal Git informational options. Safety was restored, but usability regressions required another RED/GREEN cycle and a complete deployed-command inventory.
- [med] [painful | evidence: `.superpowers/sdd/task-6-report.md`, `6a6d527a1`] The plan assumed a standalone Home Manager rollback generation. This Darwin host is activated through nix-darwin and has no standalone Home Manager profile, forcing the rollback contract and four planning/spec artifacts to move to `/nix/var/nix/profiles/system` during execution.
- [med] [painful | evidence: `.superpowers/sdd/task-6-report.md` “Evidence provenance correction”; `.superpowers/sdd/task-10-report.md` “Human activation gate provenance audit”] Human-gate provenance needed repeated repairs. An unsafe unquoted report-assembly heredoc corrupted preliminary chronology, and later review required a second structural parent-session audit to establish direct request/reply ordering and zero agent activation invocations.
- [low] [nit | evidence: `.superpowers/sdd/task-6-report.md`] The first live probe used BSD `stat -f` syntax while PATH resolved GNU coreutils `stat`; the harness failed before any Pi assertion and had to be rerun with `stat --format`.

## 3. Plan deviations

| Plan task | What changed | Why |
|-----------|--------------|-----|
| Task 3 | The jj repository model gained a separate `wip` classification probe, exact argv oracles for every jj scenario, and corrected `[wip]`-over-`[merge]` topology in `c3882c349`. | Review showed the original model conflated ordinary and diamond repositories and did not fully prove read-only probe order. |
| Task 4 | The RPC smoke grew strict JSON parsing, process-group timeout escalation, exact benign UI shapes, 24 mutation cases, and an absent-or-null `sessionFile` contract. | Review exposed harness false-positive paths; pinned Pi 0.84.1 serializes optional `undefined` by omitting `sessionFile`, so requiring the key would reject valid behavior (`.superpowers/sdd/task-4-report.md`). |
| Task 6.1 / 6.5 | Rollback evidence changed from Home Manager generations to nix-darwin `/nix/var/nix/profiles/system` links. | The host has no standalone Home Manager profile; `just activate --ask` advances the nix-darwin system profile (`6a6d527a1`, `.superpowers/sdd/task-6-report.md`). |
| Added Tasks 8–10 | Three remediation slices were added after the original implementation: fail-closed unknown options/aliases, allowlisted recognized reads, and ordered `--no-get` handling. | Whole-change review found both fail-open gaps and overprompt regressions after the original seven-task plan (`38d1525bd`, `b1e53641e`, `b70cfaeb4`). |
| Task 8.5 / 8.6 | A second human activation and live verification advanced `system-53-link` to `system-54-link`. | The first activation predated the policy remediations, so static checks could not prove the deployed environment contained the corrected rules (`6ab78945e`, `.superpowers/sdd/task-10-report.md`). |
| VCS execution boundary | Implementation moved from the jj-managed primary checkout into an isolated Git clone, and the whole-change base was corrected from obsolete commit incarnation `667905e` to current parent `e276ba799`. | jj auto-rebase/import changed commit IDs and ancestry while preserving change intent; the clone needed the imported current commit graph for reliable diffs (`.superpowers/sdd/task-5-report.md`). |

## 4. Skill / workflow compliance

| Skill                                            | Used |
|--------------------------------------------------|------|
| superpowers:brainstorming                        | yes — `brainstorm.md` |
| superpowers:writing-plans                        | yes — `plan.md` and `tasks.md` |
| superpowers:using-git-worktrees                  | yes — isolation requirement resolved with the dedicated Git clone `/private/tmp/vanixiets-pi-policy-repair` rather than editing the jj-managed primary checkout |
| superpowers:subagent-driven-development          | yes — 81 fresh Herdr Pi launches and task reports under `.superpowers/sdd/` |
| (transitive) superpowers:test-driven-development | yes — retained RED/GREEN evidence in task reports 4, 5, 8, and 10 |
| (transitive) superpowers:requesting-code-review  | yes — per-task, remediation, final-live, and verify reviews are present in the parent-session dispatch record and authoritative reports |
| superpowers:finishing-a-development-branch       | no — not yet used; mandatory schema order places it after retrospective and archive |

> **Default expectation**: all yes. The one no is a schema-order boundary, detailed below.

### Deliberately Skipped Skills

- **`superpowers:finishing-a-development-branch`**
  - **What was skipped**: The entire branch-finishing workflow—merge/PR choice, push, and cleanup—has not run.
  - **Why this cycle**: This retrospective must be written now, while `verify.md` is PASS and before archive. The binding schema says “After retrospective + archive are both done” invoke `finishing-a-development-branch` (`superpowers-bridge/schema.yaml`, completion step 6), while the retrospective template simultaneously requires every apply-phase skill to be marked used. `verify.md` also leaves “All related commits have been pushed” unchecked and directs retrospective, then archive, then finishing. Running the skill before this artifact would violate the schema's canonical order.
  - **How to prevent recurrence**: `schema graph fix` — remove `finishing-a-development-branch` from the retrospective's apply-phase compliance table, or split compliance into “used through retrospective” and “required after archive.” Evaluate finishing in a post-archive completion artifact/check instead of requiring retrospective to attest to a future step.

## 5. Surprises

- The assumed Home Manager rollback profile did not exist; the operational rollback surface was the nix-darwin system profile (`.superpowers/sdd/task-6-report.md`, `6a6d527a1`).
- “Fail closed” was not a one-direction rule: broad unknown-option prompting fixed bypasses but also overprompted valid reads until the deployed Git 2.55.0 built-in inventory and reviewed curl flags were encoded (`38d1525bd`, `b1e53641e`).
- Curl request semantics are an ordered state machine: `--no-get` must clear prior `--get`/`-G`, and a later positive option must restore it (`b70cfaeb4`).
- A human confirmation sentence was insufficient for final review without structural provenance tying it to the exact request, timestamp, direct parent ID, subsequent dispatch order, and a parser-backed count of zero agent activation commands (`.superpowers/sdd/task-10-report.md`).
- jj change IDs preserved intent while imported Git commit IDs and parentage moved under auto-rebase; treating an earlier commit incarnation as a stable baseline produced the obsolete `667905e` assumption (`.superpowers/sdd/task-5-report.md`).
- Pi 0.84.1's optional `sessionFile` may be absent rather than explicitly null under `--no-session`; source-contract review prevented a reviewer-requested false failure (`.superpowers/sdd/task-4-report.md`).

## 6. Promote candidates → long-term learning

- [ ] [high] **Treat security-sensitive CLI classification as a closed-world ordered state machine, testing every unknown option, consumed value, alias resolution, negation, and restoration transition.** → **Promote to project CLAUDE.md** (policy-testing section)
  > **Why**: Final review found unknown curl options and unresolved aliases failing open, then found `--get --no-get` retaining stale GET state; the first fix also overprompted valid reads.
  > **How to apply**: Whenever policy parses a CLI, derive cases from the deployed option/command inventory and add RED rows for unknowns, value arity, aliases, transfer boundaries, positive/negative toggles, and both transition orders before activation.

- [ ] [high] **Human-only gates require structural parent-session evidence, not narrative recollection.** → **Promote to schema** (`superpowers-bridge` activation-gate verification)
  > **Why**: Two review rounds were spent repairing provenance before the evidence proved direct request/reply ordering and zero agent activation invocations.
  > **How to apply**: For every human-only command, retain request ID/time, direct-child confirmation ID/time, first subsequent tool/dispatch, and parser-backed enumeration of agent shell invocations before any live probe is accepted.

- [ ] [med] **Select rollback profiles from the actual activation mechanism; nix-darwin activation rolls back through `/nix/var/nix/profiles/system`, not an assumed standalone Home Manager generation.** → **Promote to project CLAUDE.md** (Darwin activation section)
  > **Why**: The original Home Manager rollback assumption failed on this host and forced mid-cycle corrections across design, plan, spec, and tasks.
  > **How to apply**: Before writing an activation plan, inspect the activation recipe and profile ownership; for nix-darwin record `readlink` and `readlink -f` of the system profile before the human command and require exact N-1 preservation afterward.

- [ ] [med] **Retrospective compliance cannot require a branch-finishing skill that the same schema mandates only after retrospective and archive.** → **Promote to schema** (`superpowers-bridge` retrospective template and apply workflow)
  > **Why**: The current template's all-yes expectation contradicts schema completion step 6, making truthful compliance impossible at retrospective write-time.
  > **How to apply**: Move finishing compliance to a post-archive completion check, or label it “pending by required order” in the retrospective template and exclude it from skipped-skill recurrence accounting.

- [ ] [med] **Across jj auto-rebase and Git import, track stable jj change IDs separately from mutable Git commit IDs and resolve baselines from the current imported graph.** → **Promote to skill** (`jj-version-control` import/auto-rebase guidance)
  > **Why**: An obsolete planning-commit incarnation (`667905e`) was initially used until the current imported planning commit's actual parent (`e276ba799`) was established.
  > **How to apply**: At every clone/export/review boundary, record change ID plus current commit ID, verify the current commit's parent with the imported graph, and never reuse a pre-auto-rebase commit hash as a diff baseline without `cat-file` and ancestry checks.
