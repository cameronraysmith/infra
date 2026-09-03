## ADDED Requirements

### Requirement: Release-aligned offline Mergify skill dependency

The repository SHALL pin the Mergify source that supplies `mergify-stack` to the same upstream release as `mergify-cli-bin`.
The `structure-mergify-release-alignment` check SHALL read `agent-plugins-mergify-cli.version` and `mergify-cli-bin.version` from the fully composed per-system package output and SHALL fail its build when those values disagree, naming both package values in the failure.
The repository SHALL exercise the same comparison logic with a deliberate mismatch that passes only when the checker rejects the unequal values and reports both fixtures.
The apm composition SHALL resolve that source from a Nix-pinned, pre-warmed checkout with no network access, SHALL record the remote dependency revision and file hashes in the lock generated inside its Nix output, and MUST fail when the apm declaration and Nix source revision disagree.
The upstream skill and its reference files MUST remain unedited.
The root `apm.lock.yaml` MUST remain unchanged on a feature branch whose root producer dependencies still resolve package paths from `main`.
While that root lock remains unchanged, a fresh frozen `just agents-install` before the post-main relock SHALL materialize the pre-change policy and SHALL NOT establish `mergify-stack` delivery.
The contents of any existing ignored repository-local `.agents/` tree are unspecified.
A generated `just agents-relock` follow-up MUST run after the dependency is reachable from `main`, review and commit the refreshed root lock, and only then claim frozen repository-local delivery of `mergify-stack`.

This interface establishes the source identity, durably enforced release alignment, offline resolution, and delivered bytes visible at the Nix build boundary.
The Nix-generated lock and `$out/.agents` tree do not establish delivery through the root lock and repository-local `.agents/` path.
This interface does not establish that the upstream guidance is correct or that the executable and skill together guarantee a successful landing.

#### Scenario: Source and executable releases agree

- **WHEN** the full-flake structure check reads the Mergify skill source package and `mergify-cli-bin` from the per-system package output
- **THEN** both identify upstream release `2026.8.31.1`
- **AND** the apm dependency uses the full commit revision resolved for that release
- **AND** the normal release-alignment check build succeeds
- **AND** its negative-control check invokes the same checker with unequal source and binary fixtures, requires that invocation to fail, and verifies that the diagnostic names both fixture values

#### Scenario: Mergify skill composes offline

- **WHEN** `apm-skills-compose` resolves the declared `mergify-stack` dependency in a network-isolated build
- **THEN** it consumes the pre-warmed checkout derived from the Nix-pinned source
- **AND** the generated lock records the remote dependency's resolved revision and per-file hashes
- **AND** the composed `agent-skills` and `claude` targets contain the upstream `mergify-stack/SKILL.md` entry point

#### Scenario: Dependency revision drifts

- **WHEN** the revision declared by the version-control-and-forge apm package differs from the Nix-pinned Mergify source revision
- **THEN** composition fails before attempting a network fetch

#### Scenario: Upstream source is composed without modification

- **WHEN** the Mergify checkout is prepared for apm composition
- **THEN** its `mergify-stack` skill and reference files match the pinned upstream tree without patching, forking, or rewriting

#### Scenario: Repository-local materialization waits for the merged producer package

- **WHEN** this feature branch contains the nested Mergify dependency while the root producer manifest resolves `version-control-and-forge` from `main`
- **THEN** the branch leaves the root `apm.lock.yaml` unchanged
- **AND** a fresh frozen `just agents-install` before relock materializes the pre-change set
- **AND** the contents of any existing ignored repository-local `.agents/` tree remain unspecified
- **AND** Nix-composed `$out/.agents` evidence does not discharge repository-local git-ignored `.agents/` delivery
- **AND** a follow-up runs `just agents-relock` after the dependency is reachable from `main`, reviews and commits the generated root lock, and only then claims frozen repository-local delivery of `mergify-stack`
