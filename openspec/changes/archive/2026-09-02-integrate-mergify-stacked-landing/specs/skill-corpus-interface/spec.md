## ADDED Requirements

### Requirement: Stacked landing guidance is conditioned by role and repository mode

The delivered corpus SHALL assign preparation and verification of one independently shippable change to a worker and SHALL require that worker to return its ref and evidence without publishing or landing.
The delivered corpus SHALL reserve ordering refs, publishing the pull-request stack, and landing it for the orchestrator alone.
The first-party stacked-PR skill SHALL refer to the upstream `mergify-stack` skill for Mergify command mechanics and SHALL map landing requirements to the landed repository `stack-land` command without duplicating either mechanism.
The user-level `Stacked landing protocol` entry SHALL name its context tier and SHALL keep the OpenSpec change, normally bound to one Linear story, as the dispatch unit while encoding each independently shippable delivery step as one commit and one pull request.
Repository-mode detection SHALL select local authoring and working-copy mechanics without changing stack identity, pull-request bookkeeping, or the landing contract.
Within a stacked landing, the protocol SHALL narrowly override the generic atomic-commit rule: a worker maintains one delivery commit for its stack unit, applies corrections to that same commit, and never rewrites unrelated history outside the stack unit.
The existing jj working-copy, hazard, recovery, and worktree-interop contracts SHALL remain authoritative for local jj operations.
The entry SHALL preserve this soft routing note verbatim: “we start with git… The `Change-Id` format is shared, so switching the orchestrator or individual workers to jj changes nothing about identity, PR bookkeeping, or landing. The signal to switch is conflict volume in the orchestrator step, not preference.”
The entry SHALL remain in the user-context tier, and project context MUST NOT become a superset of the user-level context.
The first-party policy SHALL state that `stack-land` accepts a supplied pull request only when it reports at least one check and every reported conclusion is `SUCCESS`, `NEUTRAL`, or `SKIPPED`; pending, failing, and any other reported conclusion SHALL block.

This interface establishes the role and routing statements visible in the delivered guidance.
It does not grant landing authority, validate repository topology or forge state, or guarantee that a landing succeeds.

#### Scenario: Worker prepares one stack step

- **WHEN** a worker receives one step of a stacked change
- **THEN** it maintains one independently shippable delivery commit with verification evidence
- **AND** corrections update that delivery commit without rewriting unrelated history outside its stack unit
- **AND** it returns that ref and evidence without publishing a pull request, assembling the stack, or landing it

#### Scenario: Orchestrator prepares a Git-native landing

- **WHEN** an orchestrator receives a set of verified, independently shippable refs for a repository without `.jj/`
- **THEN** it orders the refs and alone publishes their pull-request stack through the upstream `mergify-stack` mechanism
- **AND** it retains the final landing decision and alone invokes the existing `stack-land --tip REV PR...` handler

#### Scenario: Landing policy evaluates reported check conclusions

- **WHEN** the first-party policy describes the reported-check gate implemented by `stack-land`
- **THEN** a nonempty set containing only `SUCCESS`, `NEUTRAL`, or `SKIPPED` conclusions is eligible to proceed
- **AND** an empty set or any pending, failing, or other reported conclusion blocks the landing

#### Scenario: Repository is jj-managed

- **WHEN** `.jj/` is present at the repository root
- **THEN** VCS detection selects the existing jj development-join and working-copy mechanics without changing stack identity, pull-request bookkeeping, or the landing contract
- **AND** the existing jj hazard, recovery, and worktree-interop contracts remain authoritative for local operations
- **AND** the Mergify Git-native path remains a soft alternative rather than an override

#### Scenario: Stacked delivery narrows the generic commit rule

- **WHEN** the Stacked landing protocol is read with the surrounding Version control and work dispatch section
- **THEN** the dispatched unit remains an OpenSpec change normally bound to one Linear story
- **AND** each independently shippable stack step is delivered as one commit and one pull request
- **AND** the worker returns the commit and evidence while the orchestrator alone publishes the corresponding pull request
- **AND** the stacked protocol overrides only the generic atomic-commit rule for corrections to that delivery commit
- **AND** the shared jj working-copy, hazard, recovery, and exclusive worktree branch-ownership rules remain authoritative

#### Scenario: OMP composes user and project context

- **WHEN** OMP evaluates the generated user-level context alongside project context
- **THEN** the Stacked landing protocol remains a short user-level entry
- **AND** project guidance is not made a full-paragraph superset that causes OMP to discard the user-level file through containment de-duplication
