# skill-corpus-interface

## ADDED Requirements

### Requirement: A named skill is resolvable in the delivered corpus

The delivered corpus MUST resolve each skill name it claims to provide, so that a request for that name yields the skill's content rather than nothing.

#### Scenario: A claimed name is requested

- **WHEN** a skill name that the corpus claims to provide is requested
- **THEN** the corpus yields content for that name

#### Scenario: A source skill has not been made visible to the build

- **WHEN** a skill exists in the source tree but has not been registered with the version control the build reads from
- **THEN** the composed corpus omits it
- **AND** the omission is silent, so registration is a precondition of delivery rather than an optional step

### Requirement: A skill's trigger surface admits the situations it must fire on

Each skill MUST carry a trigger surface that names the situations in which it applies, within the length the consuming harness will accept.

#### Scenario: A trigger surface exceeds the accepted length

- **WHEN** a skill's trigger surface is longer than the consuming harness accepts
- **THEN** the surface is rejected or truncated by the harness rather than presented in full
- **AND** the skill may therefore fail to fire on situations its surface names beyond the limit

#### Scenario: A new topic is added to a skill without extending its trigger surface

- **WHEN** content covering a new situation is added to a skill whose trigger surface does not mention that situation
- **THEN** the skill does not fire on that situation
- **AND** the added content is unreachable in practice

### Requirement: Stated ownership boundaries hold across the corpus

Where a skill states that it owns a concept, no other skill in the corpus MUST restate that concept as its own, and where a skill states that another owns a concept, that other skill MUST in fact carry it.

#### Scenario: Two skills claim the same concept

- **WHEN** two skills both present themselves as the owner of one concept
- **THEN** the conflict is reported
- **AND** it is not resolved by leaving both claims in place

#### Scenario: A pointer names an owner that does not carry the concept

- **WHEN** a skill directs a reader to another skill for a concept that the second does not contain
- **THEN** the pointer is reported as dangling

#### Scenario: An enumeration of alternatives grows by one

- **WHEN** a skill enumerates the senses or alternatives of a term and declares that holding them apart is part of what it owns
- **THEN** a newly introduced sense is added to that enumeration
- **AND** an enumeration left unextended is treated as incorrect rather than merely incomplete

## Trust boundary

These properties are stated at the boundary between a developer and the corpus they load, and they mention only what is observable there: whether a name resolves, whether a trigger surface is within limits and mentions a situation, and whether ownership claims and pointers agree with each other.

They do not guarantee that a skill's content is correct, that its guidance is followed, or that following it produces a correct outcome. Those are behavioral requirements discharged elsewhere, and no property here reaches them.

They also do not guarantee that a resolvable, well-triggered, consistently-owned corpus is a *sufficient* corpus. Coverage of the situations a developer will actually encounter is not observable at this boundary and is not claimed.

Nothing here is a guarantee about the corpus end to end.
