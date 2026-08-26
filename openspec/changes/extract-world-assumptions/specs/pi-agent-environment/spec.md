## MODIFIED Requirements

### Requirement: Permission-gate reuse

The system MUST use the pinned rytswd permission-gate shell parser, built-in rules, project-trust boundary, and headless behavior as the Bash enforcement engine.
This choice rests on the `world-assumptions` capability's assumption that Pi ships no native permission system (`world-assumptions` A1); should that assumption be falsified, this requirement's discharge argument for building Bash enforcement into an external parser rather than a native mechanism no longer holds.

#### Scenario: Shell command enters policy

- **WHEN** the pure policy harness evaluates shell and untrusted project-config cases through the pinned parser and rule API
- **THEN** semantic commands and project attempts to weaken protected behavior receive the literal expected decisions

### Requirement: Additional shell policy

Nix-owned permission-gate rules MUST classify dangerous commands, semantic mutating HTTP requests, direct `rm`, worktree creation, and Pi package mutation, with direct `rm` and package mutation blocked and interactive mutating HTTP and worktree requests prompted.
The prompted decision class for mutating HTTP and worktree requests names the same autonomous-session assumption as `Fail-open policy` below (`world-assumptions` A2), and the two requirements' discharge under that assumption is not yet reconciled; see this change's `design.md` open question on the prompt-class contradiction.
This requirement's discharge is recorded undischarged pending that arbitration, per `verify.md` §8b.

#### Scenario: Shell mutation reaches custom rules

- **WHEN** a parsed command matches a declared shell-policy table row
- **THEN** policy returns the literal allow, prompt, or block decision with `rip` or Nix-pin guidance where applicable

### Requirement: Non-Bash edit and write policy

A compact first-party pure decision core with a thin Pi adapter MUST evaluate non-Bash `edit` and `write` tool calls and classify each outcome as allow, notify-and-allow, or block.
It MUST refuse only a mutation version control could not recover, and MUST announce rather than refuse every condition whose target is inside a repository.
The exported adapter factory or handler seam MUST be directly executable as policy evidence.
The extension is scoped to Pi, and the system MUST declare that scope to atomic rather than relying on either agent's default discovery, under the `world-assumptions` capability's assumption that atomic inherits Pi's configuration root and loads Pi's extension directory unconditionally (`world-assumptions` A6).
The policy MUST normalize a tool path exactly as Pi resolves it, covering the `@` prefix, a leading `~`, a `file://` URL, and Unicode space variants, so the path the policy judges is the path the tool opens, under the assumption that this enumeration is exhaustive of Pi's own path resolution (`world-assumptions` A7).
This requirement's announce-rather-than-refuse discharge additionally rests on the assumptions that Pi has no native permission system (A1), that an unanswerable dialog stalls an autonomous session (A2), that policy failure carries no safety evidence (A3), that refusing on ambiguity has a real cost and prevents nothing (A4), and that a target inside a repository is recoverable from its history (A5) — the last of which has a known sharp edge for untracked, gitignored targets recorded in this change's `design.md`.

#### Scenario: Non-Bash mutation reaches policy

- **WHEN** the policy harness runs pure-core rows and directly invokes the exported adapter seam with synthetic edit/write allow, notify, and block calls, an unrelated tool, malformed tool input, atomic's headerless `edit` input shape, and core or capability exceptions
- **THEN** the core returns the literal decisions, the adapter translates block and passes allow and notify through, passes unrelated tools through, converts malformed input into a diagnostic block, converts exceptions into permission, and starts no Pi process per row

#### Scenario: Pi-only scope is declared to atomic

- **WHEN** the generated atomic settings are inspected
- **THEN** every Pi-only extension is named as a force-exclude relative to the inherited Pi configuration root, in the spelling atomic matches against that root

#### Scenario: Tool path is normalized as Pi resolves it

- **WHEN** the policy normalizes `@`-prefixed, `~`-prefixed, `file://`, Unicode-space, and ordinary relative paths
- **THEN** each result equals the path Pi's own resolution produces, and a path that normalizes to nothing is rejected as malformed

### Requirement: Git default-branch boundary

The first-party policy extension MUST announce, and allow, a non-Bash edit or write while the target Git repository is on `main` or `master`.
It MUST block a target the identified Git repository does not contain.
The Git branch of repository inspection MUST remain reachable when the jj probe reports an outside-repository diagnostic followed by additional advisory lines.
This requirement's announce-rather-than-refuse discharge for the default-branch case rests on the same failure-carries-no-safety-evidence and recoverable-history assumptions as `Non-Bash edit and write policy` (`world-assumptions` A3, A5), scoped here to Git default-branch history specifically.
Its fallback to Git branch inspection additionally rests on the assumption that a target's identified containment is measured through Pi's own exhaustively enumerated path forms (A7) and that jj emits a stable outside-repository diagnostic with trailing `Hint:` lines (A8).

#### Scenario: Edit is proposed on a Git branch

- **WHEN** injected repository capabilities report a feature branch, `main`, or `master`
- **THEN** feature-branch mutation is eligible to continue, default-branch mutation is announced and eligible to continue, and a target outside the repository is blocked

#### Scenario: Jj reports outside a repository with trailing advice

- **WHEN** the jj root probe exits non-zero with the outside-repository diagnostic followed by the trailing `Hint:` lines jujutsu emits inside a Git repository
- **THEN** inspection falls through to the Git branch rather than treating the probe as indeterminate

### Requirement: Jj diamond boundary

The first-party policy extension MUST consume typed, discriminated repository state and admit both healthy ordinary and healthy diamond-managed jj repositories before non-Bash edits and writes.
Every unhealthy jj condition other than target containment MUST be announced and allowed rather than refused, under the `world-assumptions` capability's assumption that its target is inside a repository whose history can recover it (`world-assumptions` A5).
Common jj health MUST require canonical repository identity and target containment; unambiguous, conflict-free `@`; a non-divergent current `@` change identity; neither `main` nor `master` pointing directly to `@`; and successful, unambiguous parsing of every read-only probe, each invoked with `jj --ignore-working-copy`.
A separate bookmark-listing classification probe MUST report the `wip` convention, including a divergent `wip` indicator, before the repository is classified as diamond-managed.
Only a repository already classified as diamond-managed MUST run the unique `wip`-resolution probe and admit absent, moved, or divergent `wip` failure outcomes.
A repository with no `wip` report MUST remain eligible for ordinary classification and MUST NOT reach a missing-`wip` failure.
Diamond health MUST additionally require `@` to be the nonconflicted, nondivergent `[wip]` commit with exactly one parent and exactly one non-divergent `wip` bookmark pointing to it.
It MUST probe `@-` separately as the `[merge]` join, require that join to be nonconflicted with at least two parents, and probe `parents(@-)` separately to require conflict-free immediate parents whose count matches the join report.
Neither `@` nor `@-` MUST be required to be empty, and diamond health MUST impose no working-copy-cleanliness requirement.
Ordinary jj health MUST impose no `wip`, diamond-topology, emptiness, or working-copy-cleanliness requirement.
This requirement's announce-rather-than-refuse discharge additionally rests on the assumption that policy failure carries no safety evidence (A3), and its repository-identity and containment probes rest on the assumptions that Pi's path forms are exhaustively enumerated (A7) and that jj emits a stable outside-repository diagnostic with trailing `Hint:` lines (A8), the latter shared with `Git default-branch boundary`.

#### Scenario: Edit is proposed in a jj repository

- **WHEN** the literal policy table evaluates ordinary healthy states, including a nonempty `@`, with no `wip` report; ordinary conflict, divergence, and protected-bookmark states; an actual healthy empty `@` `[wip]` over an empty six-parent `@-` join; healthy nonempty `[wip]` and conflict-resolved nonempty join states; classified-diamond absent, moved, or divergent unique-`wip` resolution; non-single-parent `[wip]`; single-parent or conflicted join; conflicted immediate join parent; join-parent count mismatch; and malformed or failing join probes
- **THEN** the ordinary healthy rows and all three healthy diamond rows are eligible to continue, the ordinary no-`wip` rows never reach missing-`wip` failure, every unhealthy row is announced diagnostically and eligible to continue, every indeterminate row is eligible to continue while still classifying its diagnostic, a target the repository does not contain blocks, and every recorded read-only jj argv exactly matches the ordered `jj --ignore-working-copy` argv oracle

### Requirement: Fail-open policy

Parser errors, core or adapter exceptions, ambiguous repository state, and missing or throwing capabilities MUST permit the affected tool call rather than refuse it, under the `world-assumptions` capability's assumptions that policy failure carries no safety evidence and that refusing on ambiguity has a real cost and prevents nothing (`world-assumptions` A3, A4).
Malformed tool input remains the one refusal drawn from an unreadable request rather than an unrecoverable target.
The policy MUST NOT require an interactive answer to permit a mutation, under the assumptions that Pi has no native permission system and that an unanswerable dialog on an autonomous session stalls it indefinitely (`world-assumptions` A1, A2).
This clause and `Additional shell policy`'s prompted decision class for mutating HTTP and worktree requests are not yet reconciled; the arbitration is recorded as an open question in this change's `design.md` and is not resolved here.

#### Scenario: Policy cannot decide safely

- **WHEN** the policy harness injects each parser, decision, adapter, repository, or capability failure
- **THEN** the result is permission rather than a block or an uncaught exception, and the repository classification still reports its diagnostic

#### Scenario: Announcement channel is unavailable

- **WHEN** the notification capability is absent or throws on a notify-class decision
- **THEN** the mutation remains permitted rather than becoming refused
