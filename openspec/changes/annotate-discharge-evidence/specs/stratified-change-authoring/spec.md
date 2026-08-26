<!--
Delta spec for stratified-change-authoring, change annotate-discharge-evidence.

Adds one ADDED requirement (the discharge-evidence annotation's own contract) and extends two existing
requirements (verify's discharge-coherence table, the archive step's projection rebuild) to read that
annotation. See design.md for the full rationale, including why the CLI parser evidence rules out a
`####`-level header carrier in favor of the `**Discharged by**:` metadata-line form used below.
-->

## ADDED Requirements

### Requirement: Specs artifact records optional discharge evidence inline

The `specs` artifact instruction SHALL define one optional per-requirement annotation, a `**Discharged
by**:` line written inside the requirement's own body text before its first `#### Scenario:` header, that
names the concrete artifact discharging that requirement — a check or test name, a scenario reference, a
proof obligation, or a dated manual inspection.
**Discharged by**: this requirement's own body demonstrates the annotation it specifies; the delta
carrying it was checked with `openspec validate --all` (see design.md, "Validation evidence") before
being proposed, so the syntax's structural safety is a check result, not an assumption.
The annotation SHALL take exactly one form regardless of which of the four kinds it names; it SHALL NOT
be split into per-kind fields or a discharge-kind taxonomy.
A requirement carrying no `**Discharged by**:` line SHALL be read as undischarged, not as an error.

#### Scenario: Requirement carries a discharge annotation

- **WHEN** an author adds a `**Discharged by**:` line inside a requirement's body naming a check, a
  scenario, a proof obligation, or a dated manual inspection
- **THEN** the annotation is read as that requirement's discharge evidence, regardless of which of the
  four kinds it names

#### Scenario: Requirement carries no discharge annotation

- **WHEN** a requirement's body contains no `**Discharged by**:` line
- **THEN** the requirement is read as undischarged, and the absence is not reported as a defect in the
  requirement itself

#### Scenario: Discharge annotation names nothing concrete

- **WHEN** a `**Discharged by**:` line's value asserts only that the requirement is discharged, without
  naming an artifact that can be followed to its source
- **THEN** the annotation is treated as equivalent to no annotation, and the requirement is read as
  undischarged

#### Scenario: A second discharge-evidence field is proposed

- **WHEN** a future change proposes a second annotation field to distinguish discharge kinds — for
  example separate fields for a test name versus a proof obligation
- **THEN** that proposal is rejected in favor of the single free-text form, because the value's content,
  not its field structure, carries the distinction between kinds

## MODIFIED Requirements

### Requirement: Verify artifact runs non-blocking stratum checks

The `verify` artifact instruction SHALL define a section 8 comprising a designation lint, a
discharge-coherence table, and an alphabet check. All three are agent-executed and non-blocking to
`openspec validate`, which checks markdown structure and delta well-formedness only.
The discharge-coherence table's `Discharged by (S)` column SHALL be populated from each requirement's
`**Discharged by**:` annotation where one is present, copied rather than paraphrased, so the table's
claim is traceable to the same text an author or reviewer can grep in the spec file; where no annotation
is present, the row's existing undischarged handling applies unchanged.

#### Scenario: absent designation table

- **WHEN** `specs/world-assumptions/spec.md` does not exist at verify time
- **THEN** section 8's designation lint records that absence as its finding rather than reporting a
  clean pass, because a clean report with no designation table to check against is vacuous

#### Scenario: undischarged requirement

- **WHEN** an ADDED or MODIFIED requirement in the change has no named discharging interface property
  or world assumption
- **THEN** section 8's discharge-coherence table records that requirement as `undischarged` with a
  follow-up reference, and does not omit the row or silently accept the gap

#### Scenario: stratum analysis skipped entirely

- **WHEN** the proposal tagged any capability `world` or `interface` and section 8 is left empty
- **THEN** the verify artifact treats that as a signal that the stratum analysis was skipped, not that
  it produced a clean result, and does not report Overall Decision PASS on that basis alone

#### Scenario: Discharge-coherence table reads the inline annotation

- **WHEN** section 8b builds the discharge-coherence table for an ADDED or MODIFIED requirement that
  carries a `**Discharged by**:` annotation
- **THEN** the table's `Discharged by (S)` column carries that annotation's value rather than a summary
  the agent composes independently from the requirement's capability or stratum

### Requirement: Archive step regenerates the satisfaction projection

The apply phase's archive step SHALL rebuild `docs/development/traceability/satisfaction.md` wholesale
from the post-sync corpus each time `openspec archive` runs, rather than patching the existing file, and
SHALL record any undischarged requirement it finds rather than omitting it.
For each requirement, the `Discharged by (S)` column SHALL be populated from that requirement's
`**Discharged by**:` annotation in the synced main spec if one is present, and the row SHALL be recorded
`undischarged` if it is absent; the archive step SHALL NOT infer discharge from a requirement's stratum
tag or its capability's own trust-boundary statement alone.

#### Scenario: archive completes

- **WHEN** `openspec archive` finishes syncing this change's delta specs into the main capability
  specs and before the change folder moves under the archive directory
- **THEN** the archive step regenerates the satisfaction projection from the synced main specs as a
  full rebuild, so the PR diff for this cycle carries the projection's post-sync state

#### Scenario: undischarged requirement found during projection rebuild

- **WHEN** the rebuilt projection contains a behavioral requirement with no interface property and no
  world assumption discharging it
- **THEN** the projection records that requirement's row as `undischarged` with a follow-up reference,
  never omitted and never silently accepted

#### Scenario: Discharge annotation present at archive time

- **WHEN** the archive step rebuilds the projection and a synced requirement carries a `**Discharged
  by**:` annotation
- **THEN** the projection's `Discharged by (S)` column for that requirement's row is the annotation's
  value, not an inference drawn from the requirement's capability or stratum
