---
linear_story_id: "305cc583-bdfb-4723-a283-01392adef0ce"
linear_story_identifier: "CAM-35"
linear_story_title: "Stratify the OpenSpec write path with WRSPM strata"
linear_story_url: "https://linear.app/cameronraysmith/issue/CAM-35/stratify-the-openspec-write-path-with-wrspm-strata"
linear_story_state: "In Review"
linear_team: "CAM"
linear_project: "requirements-engineering"
last_synced_state: "In Review"
last_synced_at: "2026-08-25T22:47:12Z"
review_round: 0
attempt_log:
  - { at: "2026-08-25T22:47:12Z", transition: "Backlog->In Review", outcome: "posted", note: "retroactive bind; implementation and artifacts complete before binding" }
---
## Why

OpenSpec's delta grammar checks markdown structure and well-formedness, not whether a requirement's
vocabulary is grounded in anything real. WRSPM names three strata a requirement can live in — world,
requirements (here "behavioral"), specification (here "interface") — with distinct vocabulary rules
and distinct discharge obligations. Without a stratum tag on each capability, an author has no
machine-checkable prompt to ask which vocabulary a delta may use, and the write path has nowhere to
attach the designation-lint and discharge-coherence checks that make the distinction checkable rather
than stylistic.

## What Changes

**Schema fork and stratum layer**
- From: a single `superpowers-bridge` schema bundle, described (inaccurately) as vendored third-party
  content pinned to upstream commit `0366ed5`.
- To: a first-party fork at `modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/`, adding a
  per-capability `world`/`interface`/`behavioral` stratum tag to the `proposal` artifact,
  stratum-conditional vocabulary rules to the `specs` artifact, a non-blocking section 8
  (designation lint, discharge coherence, alphabet check) to `verify`, and satisfaction-projection
  regeneration to the apply phase's archive step.
- Reason: the schema pin is captured per-change at creation and never repinned, so editing the parent
  bundle in place would retroactively change the governing schema under every change already pinned
  to it.
- Impact: non-breaking for existing changes; both bundles are delivered so pinned changes keep
  resolving.

**Task-level discharge convention**
- From: `templates/tasks.md` and the `tasks` instruction had no per-task verification convention.
- To: every task carries `— verify: <test, command, observable behavior, or delivered artifact>`,
  and `tasks.md` closes with an `## Integration Verification` group. This converged independently
  with an upstream `openspec-schemas` change to the same template; it does not reach us automatically
  because this schema ships its own bare `templates/tasks.md`, so it is a fifth framework edit here.

**Dead precondition removal and baseline bump**
- From: three unreachable `actionContext.mode == "workspace-planning"` guards at the apply, verify,
  and retrospective entry points, and a declared OpenSpec baseline of `1.4.1`.
- To: guards removed (the status JSON contract they check is intact on the current CLI, so the guard
  was dead rather than a correctness defect); declared baseline bumped to `1.10.0`, matching the
  actual toolchain.

**Project config populated**
- From: `openspec/config.yaml` had `context`, `rules`, and `operations.archive.guidance` unset.
- To: all three populated — project context (the vendored/first-party and source/delivered
  boundaries, the jj working-copy discipline, the schema resolution path), per-artifact rules for
  `proposal`, `specs`, `design`, and `verify`, and archive guidance for the satisfaction-projection
  rebuild. `rules.tasks` is deliberately absent: OpenSpec 1.10.0 silently drops rules keyed to the
  `tasks` artifact, so the equivalent guidance lives in `context` instead.

**Delivery mechanism for two schema bundles**
- From: `modules/home/ai/openspec/default.nix` exposed a single `schemaDir` option (one path).
- To: `schemaDirs`, an `attrsOf path`, delivering both `superpowers-bridge` and
  `superpowers-bridge-wrspm` as separate directory symlinks under
  `~/.local/share/openspec/schemas/<name>`. Reason: four in-flight changes remain pinned to
  `superpowers-bridge`; withdrawing that bundle would strand them with an unresolvable schema.

**Provenance correction**
- From: three READMEs (`modules/home/ai/openspec/README.md`,
  `modules/home/ai/openspec/schemas/README.md`,
  `modules/home/ai/openspec/assets/schemas/README.md`) described the parent bundle as vendored
  third-party content pinned to `0366ed5`, with a documented `cp -R` refresh recipe pointing at a
  path that no longer exists.
- To: corrected to record actual provenance — our own fork, diverged from upstream head `f5d4040` by
  +79/−29 lines in `schema.yaml` plus seven of nine templates. The stale refresh recipe was removed
  rather than repaired, because running it would have discarded every local change.

## Capabilities

### New Capabilities

- `stratified-change-authoring` — **interface**. This change's requirements describe what the write
  path demands of an author at the machine boundary: a stratum tag on each capability in `proposal`,
  stratum-conditional vocabulary admitted by `specs`, the section 8 checks `verify` runs, and the
  satisfaction-projection regeneration `archive` performs. Every one of these names a machine-side
  artifact (a tag value, a check outcome, a generated file), which places the requirements at the
  interface alphabet rather than in world vocabulary. This is distinct from the concurrently-authored
  `requirements-stratification` capability in the sibling change `requirements-engineering-skills`,
  tagged `behavioral`, which specifies what an agent must be able to do when applying the stratum
  discipline — a different vocabulary, a different consumer.

  Trust boundary: these requirements guarantee that the schema *offers* the stratum tag, the
  vocabulary rules, and the section 8 checks, and that section 8's checks are agent-executed and
  recorded rather than silently skipped. They do not guarantee that a tag is applied honestly, that
  a designation table exists, or that any requirement is actually discharged — `openspec validate`
  enforces none of that, and section 8 itself is warn-and-record, not blocking. No claim of an
  end-to-end guarantee from stratum tag to discharged requirement is made here.

### Modified Capabilities

(none — no existing `openspec/specs/` capability has a requirement-level behavior change; the
`schemaDirs` delivery change, the README corrections, and the guard removal are implementation
details of the `stratified-change-authoring` interface capability above, not changes to a separately
specified capability)

## Impact

- `modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/` (new first-party fork: `schema.yaml`,
  `README.md`, `VERSION`, `templates/`)
- `modules/home/ai/openspec/schemas/README.md`, `modules/home/ai/openspec/README.md`,
  `modules/home/ai/openspec/assets/schemas/README.md` (provenance corrections)
- `modules/home/ai/openspec/default.nix` (`schemaDir` → `schemaDirs`)
- `openspec/config.yaml` (context, rules, archive guidance)
- `openspec/schemas/superpowers-bridge-wrspm` (new project-tier symlink)
- No existing `openspec/specs/` capability's requirements change.
- Four in-flight changes remain pinned to `superpowers-bridge` and are unaffected by this fork.
