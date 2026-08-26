## Why

`packages/docs/src/content/docs/development/traceability/satisfaction.md` is regenerated wholesale at
archive time and reports, per requirement, whether it is discharged.
Reading the current projection and its stated inputs shows it is structurally incapable of reporting
anything but undischarged for nearly every row: no requirement in `openspec/specs/` carries any
per-requirement discharge evidence, so the archive-time agent has nothing to read.
Of the 19 rows that carry any `Discharged by (S)` text, all 19 repeat one of two fixed capability-level
phrases verbatim (10 rows say `skill-corpus-interface: resolvability, trigger surface`, 9 rows say `own
interface properties`) rather than naming anything specific to the requirement in question.
This makes the discharge-coherence check the schema already runs (§8b of `verify`) vacuous, and makes the
projection a document that looks like an argument and contains none.

## What Changes

**Discharge evidence gets a home in the corpus**
- From: no requirement anywhere in `openspec/specs/` can name what discharges it; the archive-time agent
  invents a capability-level gloss instead.
- To: any requirement may carry one optional `**Discharged by**:` line, written inline in its own body
  before its first `#### Scenario:`, naming the concrete artifact that discharges it — a check or test
  name, a scenario reference, a proof obligation, or a dated manual inspection.
- Reason: the projection needs something specific to read; a capability-level gloss cannot distinguish
  one requirement's evidence from its sibling's.
- Impact: non-breaking. The annotation is optional; a requirement without one is read as undischarged,
  exactly as today.

**Verify's discharge-coherence table and the archive step's projection rebuild get a defined source**
- From: both are instructed to name "an interface property" discharging each requirement, with no
  pointer to where in the requirement's own text that name should come from.
- To: both read the requirement's `**Discharged by**:` annotation where one is present, and copy its
  value rather than paraphrasing or inferring one from the requirement's capability or stratum.
- Reason: closes the loop between "the annotation exists" and "the projection actually uses it," so the
  fix reaches the deliverable the assignment names.
- Impact: non-breaking; these are the same two touchpoints the corpus already documents (§8b of `verify`,
  and the archive step in `apply.instruction`), extended rather than replaced.

This change is planning-only.
The schema file that carries both of the instructions above
(`modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml`) is not edited in this
pass — see design.md for why, and tasks.md for the deferred implementation work.

## Capabilities

### New Capabilities

None. This change extends an existing capability's write-path requirements rather than introducing a
new one; see Modified Capabilities.

### Modified Capabilities

- `stratified-change-authoring` (`interface`): adds the discharge-evidence annotation's own contract
  (ADDED requirement) and extends two existing requirements — `Verify artifact runs non-blocking stratum
  checks` and `Archive step regenerates the satisfaction projection` — to read that annotation rather
  than inventing capability-level justification text. Every existing requirement in this capability is
  already tagged `interface` in the current projection ("discharged directly against the schema and
  config artifacts it constrains"); this delta keeps that tagging, since the annotation and the two
  touchpoints it extends are all schema/write-path conventions, not runtime behavior.

## Impact

- `openspec/specs/stratified-change-authoring/spec.md`: gains one new requirement and two extended ones,
  once this change is archived (not performed in this pass).
- `modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml`: needs its `specs`,
  `verify`, and archive-step instructions updated to match the new spec text — deferred implementation
  work, recorded in tasks.md, not performed in this pass because the schema is pinned by name in every
  in-flight change's `.openspec.yaml` and at least one other change is running against it concurrently.
- `packages/docs/src/content/docs/development/traceability/satisfaction.md`: will gain genuine
  `Discharged by (S)` values wherever a requirement carries the annotation, the next time the archive
  step's (updated) instruction runs — also deferred, since it depends on the schema edit above.
- The 68 requirements currently in `openspec/specs/`: none are retrofitted with the annotation by this
  change. Retrofitting is deferred implementation work (tasks.md), separate from specifying the
  annotation's syntax and contract.
- No code, build, or runtime behavior outside the OpenSpec corpus and its schema is affected.
