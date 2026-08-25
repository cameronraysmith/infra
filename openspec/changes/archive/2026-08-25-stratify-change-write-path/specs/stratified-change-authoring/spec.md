## ADDED Requirements

### Requirement: Proposal artifact records a stratum tag per capability

The `proposal` artifact instruction SHALL require every capability listed in its Capabilities section
to carry an explicit stratum tag of `world`, `interface`, or `behavioral`, recorded alongside the
capability name.

#### Scenario: capability listed without a stratum tag
- **WHEN** an author lists a capability in `proposal.md`'s Capabilities section
- **THEN** the schema instruction requires a stratum tag (`world`, `interface`, or `behavioral`) to
  accompany that capability before the `specs` artifact can apply stratum-conditional rules to it

#### Scenario: honest all-behavioral tagging is accepted
- **WHEN** every capability in a change is tagged `behavioral`
- **THEN** the instruction records that as a legitimate outcome to state explicitly, not a gap to pad
  with a `world` or `interface` tag that does not fit

### Requirement: Specs artifact applies stratum-conditional vocabulary rules

The `specs` artifact instruction SHALL apply distinct vocabulary rules to a delta spec depending on
the stratum tag its capability carries in the proposal: `behavioral` deltas are restricted to world
vocabulary resolvable against a designation table, `world` deltas are restricted to indicative
assumptions with violation-condition scenarios plus a designation table, and `interface` deltas are
restricted to shared-phenomena vocabulary with an explicit trust-boundary statement.

#### Scenario: interface-tagged delta

- **WHEN** a capability is tagged `interface` in the proposal
- **THEN** its delta spec instruction restricts the delta to properties at the machine's interface
  alphabet, mentioning only shared phenomena, and requires the delta to state what it guarantees and
  what it does not

#### Scenario: behavioral-tagged delta

- **WHEN** a capability is tagged `behavioral` in the proposal
- **THEN** its delta spec instruction restricts the delta to world vocabulary, requiring every content
  noun to resolve against the designation table in `specs/world-assumptions/`, and directs any
  requirement that can only be stated by naming a machine-side artifact to the `interface` stratum
  instead

### Requirement: Verify artifact runs non-blocking stratum checks

The `verify` artifact instruction SHALL define a section 8 comprising a designation lint, a
discharge-coherence table, and an alphabet check. All three are agent-executed and non-blocking to
`openspec validate`, which checks markdown structure and delta well-formedness only.

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

### Requirement: Archive step regenerates the satisfaction projection

The apply phase's archive step SHALL rebuild `docs/development/traceability/satisfaction.md` wholesale
from the post-sync corpus each time `openspec archive` runs, rather than patching the existing file,
and SHALL record any undischarged requirement it finds rather than omitting it.

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

### Requirement: Tasks artifact records per-task verification

The `tasks` artifact instruction and its template SHALL require every task checkbox to carry a
verification clause, in the form `— verify: <test, command, observable behavior, or delivered
artifact>`, and SHALL require the task list to close with an `## Integration Verification` group.

#### Scenario: task without nameable verification

- **WHEN** an author cannot name what a task's verification would run or observe
- **THEN** the tasks instruction treats that task as not yet decomposed enough, rather than accepting
  a checkbox with no verification clause

#### Scenario: task list completion

- **WHEN** a task list is complete
- **THEN** it closes with an `## Integration Verification` group asserting the broader system behavior
  that the individual tasks' verifications do not, on their own, establish

### Requirement: The stratum layer states its own trust boundary

Any check, tag, or convention this capability introduces SHALL state explicitly, in its governing
instruction or project rule text, what it guarantees and what it does not, and SHALL NOT be described,
by itself or in downstream reporting, as an end-to-end guarantee from a stratum tag to a discharged
requirement.

#### Scenario: reading the verify rules

- **WHEN** an author or reviewer reads `rules.verify` in `openspec/config.yaml` or the `verify`
  artifact's section 8 instruction
- **THEN** the text states that `openspec validate` checks markdown structure and delta
  well-formedness only, that section 8 checks no vocabulary grounding, alphabet discipline, or
  entailment, and that section 8 must never be reported as validation

#### Scenario: this capability's own trust boundary, stated once here

- **WHEN** this capability's requirements are read as a set
- **THEN** the guarantee they establish is that the schema *offers* the stratum tag, the
  stratum-conditional vocabulary rules, the section 8 checks, and the projection rebuild, and that
  section 8's findings are recorded rather than silently skipped; they do not guarantee that any
  author applies a tag honestly, that a designation table exists, or that any requirement is actually
  discharged — those remain open findings for section 8 and the projection to surface, not properties
  this capability can itself enforce
