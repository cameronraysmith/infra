## ADDED Requirements

### Requirement: A distinct hostname is served with its own certificate

The machine SHALL serve the second build service at one hostname of its own, distinct from the incumbent's, with a certificate obtained for that hostname, and SHALL reach the service over a local socket rather than a network port, so that no port on the host is claimed on the second service's behalf.

#### Scenario: A request arrives for the second service's hostname

- **WHEN** a request arrives for the second build service's hostname on the host's public interface
- **THEN** it is answered over a connection secured by a certificate issued for that hostname, and forwarded to the service across a local socket

#### Scenario: A port scan of the host is taken

- **WHEN** the host's listening ports are enumerated after activation
- **THEN** the second build service holds none of them, and in particular the port its own configuration would bind if its proxy integration were disabled — which is also the port the incumbent's own upstream defaults to — is unbound

### Requirement: The two build services hold disjoint host resources

The machine SHALL give the second build service its own service unit, its own user and group, its own database on the host's existing database instance, its own state directory, and its own root-retention directory, each named differently from the incumbent's, so that neither service's operation reads or writes the other's.

#### Scenario: Both services are running

- **WHEN** both build services are running on the host
- **THEN** each has its own unit, user, group, database, state directory, and root-retention directory, and no path or name among them is shared

#### Scenario: One service's state is destroyed

- **WHEN** the state directory or database of one build service is emptied
- **THEN** the other service's state directory and database are unaffected, because they are different objects on the same host rather than one object with two consumers

### Requirement: Repository visibility is bounded outside the machine and narrowed within it

The set of forge-hosted repositories the second build service can see SHALL be bounded by its forge application's installation selection, which is set on the forge and not by this machine, and SHALL be narrowed further by the machine's own configuration, which disables the topic-based adoption of repositories and names an explicit set instead.

#### Scenario: The machine's configuration is read

- **WHEN** the second build service's configuration is read
- **THEN** the topic-based adoption of repositories is off, and the set of repositories it may build is named explicitly rather than implied

#### Scenario: The forge application is installed more broadly than intended

- **WHEN** the forge application is installed on repositories beyond those intended for the second build service
- **THEN** the machine's two remaining boundaries are what stand between that installation and a build, and the outermost boundary is not one this machine can assert

### Requirement: Deliveries are accepted only at an authenticated endpoint

The machine SHALL accept deliveries for the second build service only at that service's own endpoint, authenticated by a secret held on the host, and that endpoint SHALL be the forge application's single endpoint rather than the per-repository endpoints the incumbent registers.

#### Scenario: A delivery is presented at the second service's endpoint

- **WHEN** a delivery is presented at the second build service's endpoint carrying the secret held on the host for it
- **THEN** the delivery is accepted

#### Scenario: A delivery is presented without the host's secret

- **WHEN** a delivery is presented at that endpoint without the secret held on the host for that service
- **THEN** it is rejected, and no repository event is acted on as a result of it

### Requirement: Verdict namespaces are distinct

The machine SHALL publish the second build service's check runs under a name prefix distinct from the incumbent's, and SHALL never emit a check run under the incumbent's prefix.

#### Scenario: The second service publishes a verdict

- **WHEN** the second build service publishes a check run
- **THEN** its name carries the second service's prefix, and no check run bearing the incumbent's prefix originates from the second service

#### Scenario: The prefix is configured to the incumbent's value

- **WHEN** the second build service's prefix is set to the incumbent's value
- **THEN** this property is violated, which is why the prefix is left at its own default rather than adopted from the migration recipes written for deployments where the incumbent no longer runs

### Requirement: Credentials exist only as activation-resolved paths

Each forge credential the second build service uses SHALL reach it as a path resolved when the host's configuration is activated, readable only by that service, and the service SHALL be restarted when the value behind such a path is replaced.

#### Scenario: The service starts

- **WHEN** the second build service starts
- **THEN** each credential it needs is presented to it from a path that exists on the host, and no credential value exists in the configuration that produced it

#### Scenario: A credential's value is replaced

- **WHEN** the value behind one of those paths is replaced
- **THEN** the service is restarted, because the value it holds was taken when it started and would otherwise remain the superseded one

### Requirement: The service is a consequence of the host's declared configuration

What the second build service runs SHALL be determined by the host's declared configuration at the moment it was activated, and SHALL NOT be fetched or updated independently of that activation.

#### Scenario: The host's declaration is built without deploying it

- **WHEN** the host's declared configuration is built as a check, before any deployment
- **THEN** the build either succeeds, establishing that the declaration is coherent, or fails, and no state on the host has changed either way

#### Scenario: The declaration is unchanged but time passes

- **WHEN** time passes with no change to the host's declared configuration
- **THEN** the version of the second build service that runs does not change, because nothing outside activation selects it

### Requirement: This capability states its own trust boundary

This capability SHALL state what its properties guarantee and what they do not, and SHALL NOT be described, by itself or in any downstream report, as an end-to-end guarantee that the incumbent build service is unaffected.

#### Scenario: The properties above are read as a set

- **WHEN** the properties of this capability are read as a set
- **THEN** what they establish is that the second build service is reached at its own hostname over its own certificate through a local socket with no port bound, that its unit, user, database, state, and root-retention paths are its own, that its deliveries are authenticated at its own endpoint, that its verdict namespace is its own, that its credentials exist only as activation-resolved paths, and that what runs is a consequence of the host's declared configuration

#### Scenario: A guarantee about the incumbent is sought from this capability

- **WHEN** someone asks whether these properties guarantee the incumbent build service is unaffected
- **THEN** the answer is no: the two services share the host's web front end, its database instance, its store and the disk under it, its certificate account, and its finite capacity, so disjoint names bound the ways they can interfere without eliminating them

#### Scenario: A guarantee about repository visibility is sought from this capability

- **WHEN** someone asks whether these properties guarantee that no unintended repository is ever built
- **THEN** the answer is no: the outermost boundary is the forge application's installation selection, which is set on the forge by a person and is not observable to this machine, so the machine's contribution is the two boundaries it can assert and no more
