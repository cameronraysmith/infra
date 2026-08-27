## ADDED Requirements

### Requirement: A second build service is reachable at its own hostname

The fleet SHALL provide a second build service on the host that already runs one, reachable at a hostname distinct from the incumbent's and served with a certificate for that hostname, so that a person can reach the second service without reaching the first.

**Discharged by**: `build-service-interface` requirement `A distinct hostname is served with its own certificate`, resting on world assumption `A10 — A hostname that resolves to a host and is reachable can obtain a certificate, and issuance is rate-limited`.

#### Scenario: A person opens the second build service's hostname

- **WHEN** a person opens `nixbot.scientistexperience.net` after the host's configuration has been activated
- **THEN** the second build service answers at that hostname over a connection accepted without a certificate warning, and the incumbent's hostname `buildbot.scientistexperience.net` continues to answer independently

#### Scenario: The second service's hostname does not resolve

- **WHEN** the hostname for the second build service does not resolve to the host at the time of activation
- **THEN** no certificate can be obtained for it and the requirement is unmet, which is why declaring that hostname precedes activating the host rather than following it

### Requirement: The incumbent build service continues to serve

The incumbent build service SHALL continue, across and after the introduction of the second one, to accept the deliveries it accepted before, to publish check runs under the names it published before, and to answer at its own hostname, with no interruption attributable to the second service's introduction.

**Discharged by**: `build-service-interface` requirement `The two build services hold disjoint host resources`, whose disjointness claim is bounded by the shared surfaces that requirement names.

#### Scenario: The second build service is introduced

- **WHEN** the host's configuration is activated with the second build service present for the first time
- **THEN** the incumbent's hostname still answers, its check runs still appear under their existing names for the repositories it builds, and nothing about the incumbent's own configuration was changed to make that so

#### Scenario: The second build service is withdrawn

- **WHEN** the second build service is removed from the host's configuration and the host is activated again
- **THEN** the incumbent is unaffected by the withdrawal, because nothing it depends on was ever shared with the second service beyond what the interface capability names as common

### Requirement: Repositories are built only once opted in

The second build service SHALL build no forge-hosted repository until a later change opts that repository in, and the fleet SHALL enforce that through more than one independent boundary, so that a single mistaken setting does not by itself produce a build.

**Discharged by**: `build-service-interface` requirement `Repository visibility is bounded outside the machine and narrowed within it`, resting on world assumption `A9 — A forge application's installation selection bounds what a build service can see, and its delivery secret authenticates what it is told`; the outermost boundary is not machine-assertable, which that requirement states rather than conceals.

#### Scenario: The second build service starts for the first time

- **WHEN** the second build service starts with no prior state, on a forge whose repositories carry the topic the incumbent's repositories were opted in with
- **THEN** it adopts none of them, holds an empty set of repositories, and builds nothing

#### Scenario: A repository is later opted in

- **WHEN** a later change opts one forge-hosted repository in to the second build service
- **THEN** that repository, and only that repository, becomes one the second service builds, and the incumbent continues to build whatever it built before for that same repository

### Requirement: Deliveries a build service acts on are authenticated

The second build service SHALL act only on deliveries authenticated by a secret shared between it and the forge, and that secret SHALL be distinct from the incumbent's.

**Discharged by**: `build-service-interface` requirement `Deliveries are accepted only at an authenticated endpoint`, resting on world assumption `A9`.

#### Scenario: An authenticated delivery arrives

- **WHEN** the forge sends the second build service a delivery carrying the secret shared with it
- **THEN** the second service accepts the delivery and acts on it within the bounds of the repositories it may see

#### Scenario: An unauthenticated delivery arrives

- **WHEN** a delivery reaches the second build service without the shared secret, or carrying the incumbent's secret instead of its own
- **THEN** the second service does not act on it

### Requirement: A second build service's verdicts do not gate merges

The check runs the second build service publishes SHALL carry a namespace distinct from the incumbent's, so that a repository's required checks continue to name only the incumbent until a person edits that repository's forge-side configuration deliberately.

**Discharged by**: `build-service-interface` requirement `Verdict namespaces are distinct`, resting on world assumptions `A9` and `A12 — Which service's verdict gates a merge is the forge's configuration, not the host's`.

#### Scenario: Both services publish against the same commit

- **WHEN** both build services publish a check run against the same commit of the same forge-hosted repository
- **THEN** the two appear under different names, the repository's required checks still name the incumbent's, and a change may merge on the incumbent's verdict alone

#### Scenario: A repository's required checks are edited to name the second service

- **WHEN** a person edits a repository's forge-side configuration to require a check run in the second service's namespace
- **THEN** the second service's verdict gates merges for that repository from then on, which is a deliberate act outside this requirement rather than a consequence of standing the service up

### Requirement: Forge credentials are operator-supplied and never legible in the repository

Every forge credential the second build service uses SHALL be supplied by the operator and SHALL be unreadable in the repository that declares it, and rotating one SHALL take effect on the running service rather than leaving it holding the superseded value.

**Discharged by**: `build-service-interface` requirement `Credentials exist only as activation-resolved paths`.

#### Scenario: The repository is read by anyone with access to it

- **WHEN** a person reads the repository that declares the second build service
- **THEN** they find the names of its forge credentials and where each is consumed, and no credential value

#### Scenario: A credential is rotated

- **WHEN** the operator replaces the value behind one of the second service's forge credentials
- **THEN** the running service comes to use the new value rather than continuing with the superseded one

### Requirement: One activation establishes the second build service

The second build service SHALL be established on the host by the fleet's ordinary activation act, with no step performed by hand on the host itself, so that what runs there remains a consequence of the declared configuration.

**Discharged by**: `build-service-interface` requirement `The service is a consequence of the host's declared configuration`.

#### Scenario: The host is activated

- **WHEN** the operator activates the host's declared configuration once, after the forge application exists and its credentials have been populated
- **THEN** the second build service is running, reachable at its hostname, and holding its own state, with nothing further done by hand on the host

#### Scenario: The host is activated again from the same declaration

- **WHEN** the operator activates the same declared configuration a second time
- **THEN** the second build service is in the same condition as after the first activation, because no by-hand step exists for a repeat activation to lose

### Requirement: A second build service is sized against the capacity the incumbent uses

The second build service SHALL be sized explicitly against the build capacity the incumbent already uses on that host, rather than against the host's capacity as though it were alone.

**Discharged by**: world assumption `A11 — One host's build capacity is finite and shared by everything on it`, together with the sizing recorded in this change's design; no interface property can discharge this one, because capacity is a property of the host rather than of the machine's interface.

#### Scenario: The second service's sizing is chosen

- **WHEN** the memory and concurrency of the second build service's evaluation work are chosen
- **THEN** they are chosen as a share of what remains beside the incumbent's existing draw, and the reasoning is recorded rather than left to a default derived from the host's processor count

#### Scenario: A repository is later opted in and the pair actually contends

- **WHEN** a later change opts a repository in, so that both services evaluate and build on the same host in earnest
- **THEN** that change re-observes the capacity the pair actually draws, because a sizing argument made while one service builds nothing establishes nothing about the pair under load
