# satisfaction-argument-audit

## ADDED Requirements

### Requirement: Specification is checked against intent independently

An agent MUST be able to check whether a formal obligation means what the stated intent says, by a procedure that does not let the intent bias the reading of the obligation.

#### Scenario: Obligation is compared to intent

- **WHEN** an agent checks a formal obligation against the intent it is supposed to capture
- **THEN** the obligation is restated in prose without the intent being visible during that restatement
- **AND** the restatement is compared to the intent afterwards
- **AND** each comparison yields exactly one of confirmed, disputed, gap, or unchecked

#### Scenario: Obligation and intent disagree

- **WHEN** a comparison finds that the obligation permits behaviour the intent forbids
- **THEN** the intent is treated as authoritative
- **AND** the obligation is strengthened toward the intent
- **AND** the intent is not weakened to match the obligation

#### Scenario: Verification of the artifact has not yet succeeded

- **WHEN** an agent is asked to check obligation against intent while the artifact has not yet been shown to satisfy the obligation
- **THEN** the agent completes the artifact check first
- **AND** does not report an intent comparison as evidence about the artifact

### Requirement: Everything the argument depends on unverified is enumerated

An agent MUST be able to produce the complete set of points at which an assurance argument rests on something assumed rather than established.

#### Scenario: Argument rests on an assumed step

- **WHEN** an agent inventories what an assurance argument depends on
- **THEN** every assumed step is listed with the reason it is assumed
- **AND** anything excluded from checking by an opt-in checking regime is listed, including the units that were never marked for checking

#### Scenario: Inventory is empty

- **WHEN** an inventory reports that nothing is assumed
- **THEN** the emptiness is treated as a result requiring corroboration rather than as a clean result
- **AND** the agent states what it examined to reach that conclusion

### Requirement: Agreement between two artifacts is not treated as confirmation

An agent MUST determine whether a claim and the formal statement said to support it were derived independently, because two artifacts derived from the same mistaken understanding agree with each other.

#### Scenario: Claim and formal statement agree

- **WHEN** a claim and the formal statement supporting it are found to agree
- **THEN** the agent determines whether they were derived from a common origin
- **AND** where they were, the agreement is recorded as uncorroborated rather than as confirmation

#### Scenario: A stated guarantee is trivially true

- **WHEN** a stated guarantee holds because its precondition can never be met, or because it asserts nothing
- **THEN** the guarantee is reported as vacuous
- **AND** it is not counted as evidence

### Requirement: External claims are bounded by what was actually established

An agent producing a claim for an audience outside the work MUST state what is established and what is not, and MUST NOT describe a guarantee as holding across the whole of a thing when it was established only of a part.

#### Scenario: A quotable claim is requested

- **WHEN** an agent is asked for a claim suitable for an external audience
- **THEN** the claim states what was established, over what scope, and under what assumptions
- **AND** the claim is accompanied by an explicit statement of what may not yet be claimed

#### Scenario: A whole-system guarantee is about to be stated

- **WHEN** a claim would assert that a guarantee holds end to end
- **THEN** the claim is refused in that form
- **AND** it is replaced by one naming the part over which the guarantee was established

### Requirement: The audit runs at a boundary, not continuously

An agent MUST distinguish the per-change check from the periodic audit over accumulated work, and MUST NOT substitute one for the other.

#### Scenario: A single change is being checked

- **WHEN** a single unit of change is being checked
- **THEN** the per-change checks run and record findings without blocking the unit on them

#### Scenario: A milestone or external claim is reached

- **WHEN** a milestone is reached or an external claim is to be made
- **THEN** the full audit runs without reliance on the reasoning that produced the work
- **AND** its findings are recorded as a rebuilt record rather than as amendments to a previous one
