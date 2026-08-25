# requirements-stratification

## ADDED Requirements

### Requirement: Stratum assignment for any requirement-like statement

An agent working on a requirement-like statement MUST be able to determine which stratum the statement belongs to — the world, the requirements, or the specification — and MUST be able to say what vocabulary that stratum admits.

#### Scenario: Statement names something the machine cannot observe

- **WHEN** an agent encounters a requirement-like statement that refers to a phenomenon no machine at the boundary can observe
- **THEN** the agent places the statement in the requirements stratum rather than the specification stratum
- **AND** the agent does not attempt to make it implementable by substituting an observable proxy without recording that substitution as an assumption

#### Scenario: Statement is true regardless of what is built

- **WHEN** an agent encounters a statement that holds independently of the artifact under construction
- **THEN** the agent places the statement in the world stratum as an indicative assumption
- **AND** the agent does not state it as an obligation on the artifact

### Requirement: Grounding of terms used in requirements

Every content term used in a requirement MUST resolve to a designated phenomenon, and an agent MUST be able to detect a term that does not.

#### Scenario: Term appears in a requirement with no designation

- **WHEN** an agent reviews a requirement containing a content term that no designation record covers
- **THEN** the agent reports the term as ungrounded
- **AND** the agent records either that the term needs a designation, or that the term refers to the artifact rather than the environment and the requirement belongs in a different stratum

#### Scenario: Term resolves to two different phenomena

- **WHEN** an agent finds that a single term resolves to two distinct phenomena in the same body of requirements
- **THEN** the agent reports the term as used in two senses
- **AND** the agent does not silently prefer one sense

### Requirement: Separation of what is assumed from what is wanted

An agent MUST keep statements that are true of the environment separate from statements about what is wanted, and MUST NOT record an assumption only as justification prose inside an obligation.

#### Scenario: Assumption is embedded as justification

- **WHEN** an agent encounters an obligation whose stated rationale asserts something true of the environment
- **THEN** the agent extracts that assertion as an assumption in the world stratum
- **AND** the agent records the condition under which the assumption would cease to hold

### Requirement: Discharge of a requirement is stated, not implied

For any requirement, an agent MUST be able to state which specification properties and which world assumptions together discharge it, or MUST record the requirement as undischarged.

#### Scenario: No discharging property can be named

- **WHEN** an agent cannot name any specification property that, together with the recorded assumptions, delivers a requirement
- **THEN** the agent records the requirement as undischarged with a follow-up reference
- **AND** the agent does not omit the requirement from the discharge record
- **AND** the agent does not treat a passing verification of the artifact as evidence that the requirement is discharged

#### Scenario: A relied-upon assumption is later falsified

- **WHEN** an assumption that a requirement's discharge relies on is found no longer to hold
- **THEN** the requirements that relied on it are identified as having lost their discharge
- **AND** the loss is reported rather than being absorbed silently

### Requirement: Obstacle analysis produces the boundary and open questions

An agent producing a trust boundary or an open-questions record for a body of requirements MUST derive it by negating goals rather than by recall.

#### Scenario: Trust boundary is being written

- **WHEN** an agent writes the boundary or open-questions section for a body of requirements
- **THEN** the agent negates each goal in turn to find the environment behaviours under which the requirement would fail to be delivered
- **AND** each behaviour found is recorded as the violation condition of an assumption
