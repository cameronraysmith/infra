## ADDED Requirements

### Requirement: First-party dependency pins name a release identity, not a moving branch

Each first-party plugin package's monorepo-subpath dependency declaration SHALL reference the plugins release line's per-package alias tag for that package, and MUST NOT reference the `main` branch.

This interface establishes that a staleness check against these dependencies compares against a fixed release identity rather than the branch tip.
It does not establish that the referenced alias tag is the most recent one available at any given moment, nor that a dependent has already relocked against a newer alias tag — those are separately observable via a staleness check and the notification workflow below.

#### Scenario: A dependency declaration names its own alias tag

- **WHEN** a first-party plugin package's dependency declaration is read
- **THEN** its referenced tag's name matches that package's own directory name

#### Scenario: A staleness check reflects real change, not incidental commits

- **WHEN** a staleness check is run against a first-party dependency whose referenced alias tag is not the most recent one matching its own name
- **THEN** the check reports that dependency as outdated
- **AND** a first-party dependency whose referenced alias tag remains the most recent one matching its own name is reported as up to date, even when unrelated commits have since reached `main`

---

### Requirement: A plugins release notifies a human with a reviewable artifact

Advancement of the plugins release line's canonical tag SHALL trigger an automated process that re-resolves the first-party dependency pins and produces a reviewable, human-actionable artifact reflecting the result, without requiring a human to have proactively checked for the release.

This interface establishes that a plugins release is followed by an automated, visible re-resolution attempt.
It does not establish that a human reviews or merges the resulting artifact, nor that re-resolution always produces a change (a release that does not alter any already-current pin produces no diff).

#### Scenario: A plugins release triggers automated re-resolution

- **WHEN** the plugins release line's canonical tag advances
- **THEN** an automated process re-resolves every first-party dependency pin against the new release

#### Scenario: Re-resolution that changes pins produces a reviewable artifact

- **WHEN** automated re-resolution changes at least one first-party dependency pin
- **THEN** the process produces an artifact a human can review before the change takes effect

#### Scenario: Re-resolution that changes nothing produces no artifact

- **WHEN** automated re-resolution against a new release leaves every first-party dependency pin unchanged
- **THEN** no reviewable artifact is produced
