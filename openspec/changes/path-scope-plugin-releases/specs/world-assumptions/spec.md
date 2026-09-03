## ADDED Requirements

### Requirement: A9 — apm's revision-pin staleness check requires an annotated tag

It is true of the pinned `apm` release, independent of what this fleet builds, that its full-SHA revision-pin staleness check considers only annotated tags when searching for a newer release, and silently ignores a lightweight tag as a candidate regardless of its name or version.
Any requirement whose discharge depends on this fact SHALL name it explicitly rather than restating it as unattributed justification prose, and SHALL be treated as losing its discharge once this assumption's violation condition below is observed.

#### Scenario: apm gains lightweight-tag support for revision-pin staleness checks

- **WHEN** a future `apm` release considers a lightweight tag as a valid candidate for its full-SHA revision-pin staleness check
- **THEN** this assumption is void, and the `plugin-dependency-freshness-signal` requirement `First-party dependency pins name a release identity, not a moving branch` loses the discharge argument that currently rests on pinning by literal tag name specifically to avoid this filter, and MAY instead pin by full commit SHA

### Requirement: A10 — apm names a path-form dependency's tag pattern from its own final path segment

It is true of the pinned `apm` release, independent of what this fleet builds, that for a git dependency declared with an explicit subdirectory path, its tag-pattern matching derives the substitutable package name from that dependency's own final path segment, and that no per-dependency override of this derivation is available outside of marketplace-producer-side configuration, which this repository's first-party dependency declarations do not use.
Any requirement whose discharge depends on this fact SHALL name it explicitly, and SHALL be treated as losing its discharge once this assumption's violation condition below is observed.

#### Scenario: apm gains a consumer-side tag-pattern override for path-form dependencies

- **WHEN** a future `apm` release adds a per-dependency tag-pattern override usable outside marketplace-producer configuration
- **THEN** this assumption is void, and the `plugin-release-tagging` requirement `Alias tag name matches its directory exactly` loses the discharge argument that currently rests on shaping each alias tag to match the directory-derived name apm infers automatically, and the release line MAY instead mint a single shared tag with an explicit override configured per dependency
