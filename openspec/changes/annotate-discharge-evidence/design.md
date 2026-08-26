## Context

`packages/docs/src/content/docs/development/traceability/satisfaction.md` is a projection over
`openspec/specs/`, regenerated wholesale each time `openspec archive` runs (never patched — the
`stratified-change-authoring` capability's "Archive step regenerates the satisfaction projection"
requirement already establishes both facts).
It reports, per requirement, the `W ∧ S ⇒ R` discharge obligation: which specification properties (S) and
which world assumptions (W) discharge it, or that it is undischarged.

Reading the file as generated (`generated: 2026-08-25`): 68 requirements, 9 discharged, 10 partially
discharged, 49 undischarged, every `Under (W)` cell empty.
Reading which rows carry any `Discharged by (S)` text at all — 19 of 68 — and what that text says: all 19
repeat one of two fixed phrases verbatim, `skill-corpus-interface: resolvability, trigger surface` (10
rows, `grep -c` confirmed) or `own interface properties` (9 rows, `grep -c` confirmed), regardless of
which distinct requirement the row is about.
Reading `openspec/specs/*/spec.md` for any per-requirement construct those phrases could be citing —
none exists.
Reading the schema source that defines both the `verify` artifact's §8b discharge-coherence table and the
archive step's projection-rebuild instruction
(`modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml`) — both instruct the
agent to name "an interface property" discharging each requirement, with no pointer into the requirement
text itself.
The two fixed phrases are the archiving agent's own capability-level gloss, not references to anything
recorded in the corpus, because nothing recordable exists yet.

This design closes that gap at its source: it gives the corpus a place to record discharge evidence, and
extends the two existing touchpoints that already claim to report it so they read that place instead of
inventing text.

## Goals / Non-Goals

**Goals:**
- Define one optional, per-requirement annotation, written inline in the requirement's own markdown, that
  names the concrete artifact discharging that requirement.
- Make that annotation greppable and readable as prose, consistent with how the rest of the corpus
  (`### Requirement:` / `#### Scenario:`) is read by both agents and humans.
- Prove the annotation's syntax survives `openspec validate` before proposing it as a convention, not
  after.
- Extend `verify`'s §8b and the archive step's projection rebuild to read the annotation, so the fix
  reaches the deliverable rather than stopping at "a place to write evidence that nothing yet reads."
- Name the capability that owns this delta, on the evidence of what that capability's requirements
  already govern, and record the alternative considered and rejected.

**Non-Goals:**
- Editing `modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml`. See "Deferred
  work" below.
- Retrofitting any of the 68 existing requirements in `openspec/specs/` with the annotation. That is
  authorship work per capability owner, not a mechanical rewrite this change can perform correctly
  without inventing evidence that does not exist — exactly the failure mode this change exists to
  prevent.
- Populating the `Under (W)` column. That is the `extract-world-assumptions` change's territory (in
  flight; not touched by this change).
- Building a taxonomy of discharge kinds (separate fields for a test name, a scenario reference, a proof
  obligation, a manual inspection). One free-text form covers all four; see Decision D2.
- Any machine-enforced check that a `**Discharged by**:` value is non-bare. `openspec validate` checks
  markdown structure only; content-semantic checks in this schema are agent-executed and non-blocking
  (§8 already documents this for the designation lint, discharge coherence, and alphabet check). This
  change follows the same pattern rather than inventing new tooling.

## Decisions

### D1: Annotation carrier — a `**Discharged by**:` metadata line, not a `#### Discharge:` header

- **Choice**: The annotation is a `**Discharged by**: <value>` line inside the requirement's own body
  text, before its first `#### Scenario:` header.
- **Rationale**: Read directly from the OpenSpec CLI's parser source
  (`@fission-ai/openspec` v1.10.0, `dist/core/parsers/requirement-text.js` and
  `dist/core/parsers/requirement-blocks.js`):
  - `SCENARIO_HEADER = /^####\s+/` matches *any* level-4 header, not only ones labeled `Scenario:`.
    `countScenarios` (backs the "requirement must have ≥1 scenario" WARNING/ERROR) and
    `parseScenarioBlocks` (backs the MODIFIED-requirement scenario-loss check, a blocking ERROR in
    `openspec validate` — confirmed by reading `validator.js`'s `findScenarioLossIssues`) both treat
    every `####` child as a scenario. A `#### Discharge:` header would inflate scenario counts and would
    have to be reproduced verbatim on every future MODIFIED of the same requirement or trigger that
    ERROR — accidental correctness riding on the tool's scenario-detection code, not a construct meant
    for this purpose.
  - `METADATA_LINE = /^\*\*[^*]+\*\*:/` is an existing, named, load-bearing construct in
    `extractRequirementBody`: it recognizes lines like `**ID**:` / `**Priority**:` already used elsewhere
    in this repo's corpus, captures them separately from descriptive prose, and — critically — is
    invisible to both `countScenarios` and the scenario-loss check because it is not a header line at
    all. It cannot inflate the scenario count and cannot trigger a scenario-loss ERROR on a future
    MODIFIED.
  - Evidence that this choice survives validation: this change's own delta spec
    (`specs/stratified-change-authoring/spec.md`) writes a `**Discharged by**:` line inside its own new
    ADDED requirement's body, and `openspec validate --all` was run against the full corpus with that
    line present. Verbatim output recorded in verify.md's PRECHECK is not applicable here (this is a
    planning-only change; verify.md is not produced — see the Migration Plan below), so the output is
    recorded directly in this design document instead, in the "Validation evidence" subsection.
- **Alternatives considered**: A `#### Discharge:` header (rejected — see above); frontmatter (rejected —
  can only attach to a whole spec file, not to one requirement among several, and the corpus is read as
  prose by both agents and humans, so machine-only frontmatter is the wrong home); a sibling
  `discharge.yaml` keyed by requirement name (rejected — reintroduces a two-artifacts-that-can-drift
  problem, one layer earlier than the exact problem `satisfaction.md`'s "rebuild wholesale, never patch"
  rule already exists to prevent).

### D2: Annotation shape — one free-text form, no discharge-kind taxonomy

- **Choice**: `**Discharged by**: <free text>`. The same single label and value shape names a check/test
  name, a scenario reference, a proof obligation, or a dated manual inspection.
- **Rationale**: the assignment is explicit that a taxonomy of discharge kinds is the failure mode to
  avoid. The four named kinds are already self-distinguishing by their content — a test name reads as a
  test name, a date makes a manual inspection self-evident — so a field-per-kind structure would encode
  information the value already carries, purely to let a machine sort by kind, which nothing in this
  corpus currently does or has been asked to do.
- **Alternatives considered**: four labeled sub-fields (`**Discharged-by-check**:`,
  `**Discharged-by-scenario**:`, etc.) — rejected per the assignment's own stated failure mode, and
  because it would require every future author to first classify which of four boxes their evidence
  belongs in before recording it, adding authoring friction with no compensating benefit.

### D3: Owning capability — `stratified-change-authoring`, not `requirements-stratification`

- **Choice**: the delta lives in `openspec/changes/annotate-discharge-evidence/specs/
  stratified-change-authoring/spec.md`.
- **Rationale**: read all nine `openspec/specs/*/spec.md` files. `stratified-change-authoring`'s own
  Purpose line reads "created by archiving change stratify-change-write-path" — the assignment's own
  phrase, "whichever existing capability owns the change write path," names this capability by its own
  stated origin. Its existing requirements already govern the exact three touchpoints this change
  touches: the `specs` artifact's format rules ("Specs artifact applies stratum-conditional vocabulary
  rules"), `verify`'s §8 ("Verify artifact runs non-blocking stratum checks" — this is where §8b, the
  discharge-coherence table, is specified), and the archive step's projection rebuild ("Archive step
  regenerates the satisfaction projection" — this is the generator that currently has nothing to read).
  Every requirement in this capability is already tagged `interface` in the current projection
  ("discharged directly against the schema and config artifacts it constrains"), matching this delta's
  own nature: a schema/write-path convention, not a runtime behavior.
- **Alternatives considered**: `requirements-stratification`. It owns "Discharge of a requirement is
  stated, not implied" — an agent's general reasoning discipline ("an agent MUST be able to state which
  specification properties and which world assumptions together discharge it, or MUST record the
  requirement as undischarged"). Rejected because that requirement is about how an agent reasons about
  discharge in general, independent of any specific tool or corpus; it does not mention the `specs`
  artifact, `verify`, or the archive step at all. Placing the annotation's syntax there would conflate
  "the reasoning discipline" with "the markdown construct that records the reasoning's output" — the
  latter belongs with the write-path mechanics this change extends, all already in
  `stratified-change-authoring`.

## Validation evidence

`openspec validate --all` run from `/Users/crs58/projects/vanixiets` against the full corpus, with this
change's delta spec present (one ADDED requirement carrying a `**Discharged by**:` line, two MODIFIED
requirements with all original scenario headers preserved verbatim):

```
$ openspec validate --all
- Validating...
✓ change/agentic-planning-development-management-skills
✓ change/annotate-discharge-evidence
✓ change/apm-skills-marketplace
✓ spec/apple-laptop-hardware-support
✓ spec/bare-metal-install-path
✓ change/declarative-cognee-endpoint
✓ spec/encrypted-zfs-root
✓ change/extract-world-assumptions
✓ spec/graphical-desktop-session
✓ spec/pi-agent-environment
✓ spec/requirements-stratification
✓ spec/satisfaction-argument-audit
✓ spec/skill-corpus-interface
✓ change/sso-gateway
✓ spec/stratified-change-authoring
✓ change/validate-harborize-instrument
Totals: 16 passed, 0 failed (16 items)
```

All 16 items pass, including `change/annotate-discharge-evidence` itself — confirming the `**Discharged
by**:` metadata line does not trigger the "at least one scenario" check, the SHALL/MUST body-keyword
check, or the MODIFIED-requirement scenario-loss check (traced through the CLI source in Decision D1,
confirmed empirically here). Also confirmed separately with `openspec validate annotate-discharge-
evidence --json`, run before the other five planning artifacts existed: `"valid": true`, `"issues": []`.

## Risks / Trade-offs

- [Risk] A future author writes `**Discharged by**: yes` or `**Discharged by**: discharged` — a bare
  assertion naming nothing → Mitigation: the ADDED requirement's own scenarios state explicitly that a
  value naming no followable artifact is read as equivalent to no annotation; this is agent-executed
  discipline (like the existing §8 checks), not machine-enforced, because `openspec validate` has no
  content-semantic check to hook into anywhere in this schema.
- [Risk] The `**Discharged by**:` value drifts from the artifact it names (e.g. a test gets renamed and
  the annotation is not updated) → Mitigation: out of scope for this change. The same staleness risk
  already applies to every other cross-reference in this corpus (e.g. a scenario name referenced by
  title); this change does not introduce a new failure mode, only a new place values can go stale in.
- [Trade-off] The annotation is optional, so it does not close the "49 of 68 undischarged" gap by itself
  → accepted: making it mandatory would force fabricated values on every currently-undischarged
  requirement, recreating the exact problem (invented-but-hollow discharge text) this change exists to
  remove. Retrofitting real evidence is deferred, deliberate follow-up work (tasks.md), not a defect in
  this change's scope.

## Migration Plan

This change is planning-only; nothing is deployed by it.
The migration is the deferred implementation work this design records rather than performs:

1. Once no in-flight change is pinned to `superpowers-bridge-wrspm` by name (or the schema is versioned
   so a pinned change is unaffected by an edit — a schema-tooling question outside this change's scope),
   edit `modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml`:
   - `specs` artifact instruction: document the `**Discharged by**:` convention (matching the ADDED
     requirement's text in this change's delta spec).
   - `verify` artifact instruction, §8b: read the annotation into the `Discharged by (S)` column rather
     than inventing capability-level text (matching the MODIFIED "Verify artifact runs non-blocking
     stratum checks" text in this change's delta spec).
   - `apply` operations, archive step: same substitution for the projection rebuild (matching the
     MODIFIED "Archive step regenerates the satisfaction projection" text in this change's delta spec).
2. Archive this change (`openspec archive`), syncing the delta spec into
   `openspec/specs/stratified-change-authoring/spec.md`. Not performed in this pass; deliberately left
   for the orchestrator per this assignment's constraints.
3. Retrofit existing requirements with `**Discharged by**:` annotations where real evidence exists,
   capability by capability — separate follow-up work, not a single mechanical pass, since inventing
   evidence to fill the annotation would recreate this change's own target problem.

Rollback: none needed before step 2 (no corpus mutation occurs until archive). After step 2, rollback is
a normal spec revert; the annotation convention has no runtime component to roll back.

## Open Questions

- Should the eventual archive-step generator (post schema-edit) become a script rather than an
  agent-executed instruction, now that there is a fixed-format value (`**Discharged by**:`) to parse
  mechanically instead of free-form capability text to compose? Left open: this change specifies the
  annotation's syntax and contract; whether the generator becomes deterministic tooling is a separate
  design decision for whoever performs the deferred schema edit.
- Should a requirement be allowed more than one `**Discharged by**:` line (e.g. a behavioral requirement
  discharged jointly by two checks)? Left open in this pass; the ADDED requirement's text as written
  does not forbid it, but does not specify multi-line semantics either. Deferred to the retrofit work in
  step 3 of the Migration Plan, where real multi-evidence cases (if any) will surface concretely.
