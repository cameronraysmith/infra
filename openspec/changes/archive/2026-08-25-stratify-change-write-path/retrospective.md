# Retrospective: stratify-change-write-path

> Written: 2026-08-25 (after verify passed with warnings)
> Commit range: `677e05ff78bb..ee0e026b7def` (implementation scope; see §0 for the wider jj-join range)
> Worktree: none — jj-colocated multi-parent development join (see `openspec/config.yaml` `context`)

---

## 0. Evidence

> Up-front quantified data — later Wins / Misses bullets reference it directly, avoiding a repeated [evidence: ...] on every line.

- **Commit range**: `677e05ff78bb..ee0e026b7def` (4 commits implementing this change's scope). The
  wider jj working-copy range `fa465be8ed8a..HEAD` (main's merge-base to current working copy) is 27
  commits, because this repository's jj diamond-join workflow shares one working-copy history across
  concurrent unrelated chains (other in-flight changes, dependency bumps); only the 4 named commits
  touch this change's files.
- **Diff size**: +1995 / −48 lines across 17 files, for the 4 implementation commits combined (`git
  diff --stat 677e05ff78bb^..ee0e026b7def -- modules/home/ai/openspec/ openspec/config.yaml
  openspec/schemas/`). This subagent's own contribution — the seven planning artifacts — adds
  `proposal.md`, `design.md`, `specs/stratified-change-authoring/spec.md`, `tasks.md`, `plan.md`,
  `verify.md`, this file — uncommitted at write time (orchestrator-owned commit per assignment
  constraints).
- **Tasks done**: 20/20 (`grep -c '^- \[x\]' tasks.md`; 0 remaining `- [ ]`).
- **Active hours**: the 4 implementation commits span 17:35–18:05 on 2026-08-25 (~30 minutes of
  committed history observed via `jj show <commit> -T 'author.timestamp()'`). Time spent in the
  brainstorming/design session before the first commit is not independently timestamped in the
  evidence available to this subagent.
- **Subagent dispatches**: n/a for the implementation commits — no evidence in `jj log` distinguishes
  subagent-authored commits from directly-authored ones (all four carry the same author identity).
  This retrospective itself was written by subagent `ChangeAArtifacts`, dispatched by the orchestrating
  session to produce this change's seven missing planning artifacts.
- **New external dependencies**: none. No package manifest changed; the work is schema/config/nix
  option authoring within the existing toolchain.
- **Bugs encountered post-merge**: n/a — this change has not yet been archived/merged as of this
  retrospective.
- **OpenSpec validate state at archive**: not yet archived. At verification time: `openspec validate
  --all --json` reports 12/12 items valid (7 changes, 5 specs), and `openspec validate
  stratify-change-write-path --type change` reports valid.
- **Test coverage signal**: n/a — no test framework applies to schema.yaml/config.yaml/README
  authoring. The applicable correctness signals are `openspec validate`, `openspec instructions
  <artifact> --json`, and `nix eval` against the home-manager option, all exercised in `tasks.md` and
  `verify.md`.

Commit chain (chronological, implementation scope only):

```
677e05ff78bb feat(openspec): fork superpowers-bridge as a first-party wrspm schema
653740701270 feat(openspec): populate project context, rules, and archive guidance
a3719f84c210 fix(openspec): correct schema bundle provenance and drop the dead refresh recipe
ee0e026b7def feat(openspec): deliver both schema bundles so pinned changes resolve
```

---

## 1. Wins

- [evidence: `modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/schema.yaml:69-392`] The
  stratum tag, vocabulary rules, and section 8 checks landed as a coherent chain across three
  artifacts (proposal → specs → verify), each pointing back to the one tag recorded in the proposal,
  matching the design's stated contract.
- [evidence: `openspec validate --all --json` → 12/12 valid] The fork did not regress any of the six
  other changes or five capability specs already in the corpus, including the four still pinned to
  the frozen `superpowers-bridge` bundle.
- [evidence: `jj show 653740701270`, `openspec instructions tasks --change stratify-change-write-path
  --json | jq 'has("rules")'` → `false`] The `rules.tasks` dead-letter defect was caught and routed
  around (guidance moved to `context`) rather than landing silently inert, because it was verified
  against the actual CLI JSON output rather than assumed from the schema author's documentation.
- [evidence: `nix eval .#homeConfigurations."crs58@aarch64-darwin".config.programs.openspec.schemaDirs
  --apply builtins.attrNames --json` → `["superpowers-bridge","superpowers-bridge-wrspm"]`] The
  `schemaDirs` nix option change was verified at the evaluation level, not by reading source, matching
  this project's own stated nix-verification convention.

## 2. Misses

- [med] [painful | evidence: `modules/home/ai/openspec/assets/schemas/README.md:13`] The first
  attempt at this work forked the schema believing the parent bundle was vendored third-party content
  that had to stay pristine. That belief was wrong — the parent was already a first-party fork,
  diverged from upstream by +79/−29 lines — and the fork decision is correct for a different reason
  (the schema-pin hazard, not vendoring). The correction is recorded in `design.md` D2 rather than
  silently absorbed into a clean narrative.
- [low] [nit | evidence: this subagent's own `tasks.md` authoring, corrected in this session] Two of
  this subagent's own verification clauses in `tasks.md` were wrong on first write (§3 below) and
  required actually running the command before the claim could stand — a reminder that a plausible-
  sounding verify clause is not evidence until executed.
- [low] [nit | evidence: `verify.md` §5] This subagent's own planning-artifact files were unstaged at
  verify time, by design (the orchestrator commits, per this assignment's constraints), which means
  §5's "no unstaged files" check cannot be satisfied by this subagent's own work in isolation — it
  will only be true once the orchestrator commits these seven artifacts.

## 3. Plan deviations

| Plan task | What changed | Why |
|-----------|--------------|-----|
| tasks.md §4.1 (nix delivery verification) | Initially drafted as a weak structural check (`nix eval .#homeConfigurations --apply builtins.attrNames` returning a non-empty list); replaced with a direct evaluation of `config.programs.openspec.schemaDirs` for the `crs58` user | The weak check would pass even if `schemaDirs` were broken; the stronger eval actually observes the delivered option value, matching this repository's stated nix-verification convention in `openspec/config.yaml` `context`. |
| tasks.md §5.2 (stale `cp -R` recipe removal) | Initially claimed `grep -c "cp -R"` returns `0`; running it returned `1`, because the removal is narrated in prose ("was a blind `cp -R`... has been removed") rather than the string being fully absent | Verify clause rewritten to check for the absence of a runnable code block and the absence of the stale path on disk (`ls ~/projects/planning-workspace/...` → no such file), which is what the task actually claims. |

## 4. Skill / workflow compliance

| Skill                                            | Used |
|--------------------------------------------------|------|
| superpowers:brainstorming                        | yes  |
| superpowers:writing-plans                        | no   |
| superpowers:using-git-worktrees                  | no   |
| superpowers:subagent-driven-development          | unverifiable |
| (transitive) superpowers:test-driven-development | unverifiable |
| (transitive) superpowers:requesting-code-review  | unverifiable |
| superpowers:finishing-a-development-branch       | no   |

> This table reflects what is verifiable from committed evidence and this subagent's own scope, not a
> first-hand account of the original authoring session (this subagent did not run that session).
> `brainstorming` = yes on the strength of `brainstorm.md`'s Q1–Q10 decision-log structure, which
> matches that skill's characteristic output format described in its own instruction text.

### Deliberately Skipped Skills

- **`superpowers:writing-plans`**
  - **What was skipped**: the whole skill. No `plan.md` existed prior to this subagent's session;
    `plan.md` was authored retroactively, reconstructing the implementation from the four committed
    diffs rather than the skill decomposing tasks into micro-steps before implementation.
  - **Why this cycle**: this subagent was dispatched after `tasks.md`, `design.md`, and `specs/` were
    all also missing — the schema and config work was already committed (commits `677e05ff78bb`
    through `ee0e026b7def`) before any planning artifact besides `brainstorm.md` existed. The plan
    could not precede the implementation because this subagent's task was explicitly to backfill the
    planning chain for already-completed work.
  - **How to prevent recurrence**: `scope-judgment rule` — for a change whose planning-artifact chain
    is being backfilled after the fact (as stated explicitly in this subagent's assignment), `plan.md`
    is understood to be a reconstruction, not a live writing-plans-skill session, and should say so in
    its own text (this `plan.md` does, in its Goal/Architecture preamble reading as retrospective
    rather than prospective). No schema or skill change is warranted; the gap is inherent to backfill
    work, not a process defect.

- **`superpowers:using-git-worktrees`**
  - **What was skipped**: the whole skill.
  - **Why this cycle**: this repository is jj-colocated with a multi-parent development join (see
    `openspec/config.yaml` `context` and `CLAUDE.md`'s "Working-copy hazards" section). Its own
    documented discipline states worktree creation is ask-gated and the diamond join is the default
    for parallel chains — confirmed by `jj show 677e05ff78bb` and the other three implementation
    commits all landing directly in the shared working-copy history with no worktree-specific commit
    pattern (e.g. no `git worktree` remnants, no separate branch merge).
  - **How to prevent recurrence**: `one-off — schema boundary case, no prevention possible`. The
    schema was authored against a generic git-native workflow assumption
    (`superpowers:using-git-worktrees` isolates a git worktree per change); this project's jj diamond
    workflow supersedes that isolation mechanism entirely, by design, for every change, not just this
    one. This is a standing, structural mismatch between the schema's assumed VCS mode and this
    project's actual VCS mode, not a per-cycle judgment call — hence a boundary case rather than a
    preventable skip.

- **`superpowers:subagent-driven-development`** (and its transitives, `test-driven-development` and
  `requesting-code-review`)
  - **What was skipped**: unknown — recorded as unverifiable rather than "no", because this subagent
    has no first-hand visibility into the original authoring session and the jj commit history does
    not distinguish subagent-dispatched work from directly-authored work by commit metadata alone.
  - **Why this cycle**: n/a — this is a visibility gap, not a decision this subagent can attribute to
    a specific trigger.
  - **How to prevent recurrence**: `schema graph fix` — if this is a recurring gap across cycles, a
    future schema revision could require the apply-phase instruction to record subagent-dispatch
    evidence (e.g. a commit-message convention or a dispatch log) that a later verify/retrospective
    pass could check mechanically, rather than requiring first-hand session memory.

- **`superpowers:finishing-a-development-branch`**
  - **What was skipped**: the whole skill (no PR opened, no branch finished).
  - **Why this cycle**: explicitly out of scope for this subagent — the assignment states "Run NO VCS
    write commands" and "Do not run `openspec archive`", both prerequisites this skill's instruction
    requires to have already completed (retrospective + archive both done) before it runs.
  - **How to prevent recurrence**: `scope-judgment rule` — this is expected, not a defect, whenever a
    planning-backfill subagent is dispatched separately from the orchestrator that owns commit/PR/
    archive actions. No schema change needed.

## 5. Surprises

- The parent `superpowers-bridge` bundle's provenance was wrong in three READMEs before this change:
  described as vendored third-party content pinned to `0366ed5`, when it was in fact a first-party
  fork already diverged from upstream by +79/−29 lines. This surprised the first attempt at this work
  into forking for the wrong stated reason (see §2 Misses and `design.md` D2).
- `openspec instructions tasks --json` silently drops the top-level `rules` key with no warning, while
  every sibling artifact (`proposal`, `specs`, `design`, `verify`) carries it — confirmed directly via
  `jq 'has("rules")'` on each artifact's JSON output. This is not documented as a known OpenSpec
  1.10.0 limitation anywhere this subagent found; it was discovered empirically during this change's
  own authoring.
- `openspec schema fork` fails with `EACCES` against a read-only nix-store source tree, because it
  preserves the source's mode-444 permissions on its own staging copy before trying to write to that
  copy.

## 6. Promote candidates → long-term learning

- [ ] [med] **A schema written against `superpowers:using-git-worktrees` has no escape hatch for
  projects on a non-git-worktree VCS discipline (e.g. jj diamond join).** → **Promote to project
  CLAUDE.md** (`/Users/crs58/.claude/skills/preferences-git-version-control/03-jj-mode.md` or the
  `superpowers-bridge-wrspm` schema's own `apply` instruction)
  > **Why**: this cycle's `finishing-a-development-branch`/`using-git-worktrees` skip is a standing
  > structural mismatch (see §4 Deliberately Skipped Skills), not a per-cycle judgment call, and will
  > recur identically on every future change authored under this schema in this repository.
  > **How to apply**: when a schema's apply-phase instruction names `using-git-worktrees` as a
  > required step, and the project is jj-colocated, record explicitly (in the schema's own
  > `apply.instruction`, mirroring `rules.tasks`'s dead-letter note pattern) that the diamond-join
  > working copy satisfies the isolation intent and the worktree skill is a documented boundary case,
  > not a compliance gap to chase.

- [ ] [med] **`openspec instructions <artifact> --json` silently drops `rules` for the `tasks`
  artifact specifically, with no warning.** → **Promote to schema** (a future
  `superpowers-bridge-wrspm` VERSION bump, or an upstream OpenSpec issue)
  > **Why**: discovered empirically this cycle via `jq 'has("rules")'` comparison across artifacts;
  > without that check it would have looked live and been silently inert, exactly as
  > `openspec/config.yaml`'s own `context` block warns.
  > **How to apply**: any future schema author adding `rules.tasks` to a superpowers-bridge-derived
  > schema on OpenSpec ≤1.10.0 should first confirm with the same `jq 'has("rules")'` check before
  > relying on it, and file the defect upstream if not already tracked.

- [ ] [low] **A verify clause is not evidence until it has actually been run once.** → **One-off**
  (recorded here; general enough that it likely restates existing session discipline rather than
  needing a new promotion target)
  > **Why**: this cycle's own §3 plan-deviation table shows two verify clauses that were plausible but
  > wrong until executed (the `nix eval` structural-vs-targeted check, and the `cp -R` grep-count
  > claim).
  > **How to apply**: when authoring `tasks.md`/`verify.md` verification clauses for already-completed
  > work, run each command before writing the claimed result into the artifact, not after.
