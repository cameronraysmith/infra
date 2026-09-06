## ADDED Requirements

### Requirement: The management cluster is a capability with one contract and two handlers, of which handler B exists first

The management cluster SHALL be exposed as `apps.<system>.k8s.mgmt-k3d` (handler B: on stibnite, create a k3d cluster under Colima Docker, `clusterctl init` with the pinned Cluster API core, CAPH, and cluster-api-k3s providers, apply the T0 `Secret`s and the rendered `capi-cryolite` tree, wait for the workload control plane, `clusterctl move`, delete the k3d cluster; `modules/kubernetes/capi/management.nix`), SHALL be an `apps` effect and not a check because it needs Docker, network access, and the Hetzner API token, SHALL read the spend gate of `hetzner-cluster-deployment` before any step that reaches the Hetzner Cloud API, and the contract every handler satisfies SHALL be: a kubeconfig on the operator host, the Cluster API core, CAPH, and cluster-api-k3s providers `Ready`, the rendered `capi-cryolite` tree and the T0 `Secret`s applied unchanged, and `clusterctl move` to the workload cluster succeeding.
Handler A (the k3s closure as a NixOS QEMU VM through `virtualisation.host.pkgs`, including Darwin/HVF) SHALL NOT be implemented by this change and, when added, SHALL satisfy the same contract without any change to a CR or a Secret.
Trust boundary: the handler observes what `kubectl` and `clusterctl` report; it does not guarantee the providers reconcile correctly against Hetzner.
Coverage bin: interface (recipe outcome; K, not a check) for ADR-009 D9.4, D9.17, R9.6; non-vacuity: the scenario below.

#### Scenario: A CR names the handler

- **WHEN** any object in the rendered `capi-cryolite` tree or any T0 `Secret` references k3d, Colima, Docker, or a QEMU artifact and `checks.k8s-capi-render-cryolite` is rebuilt
- **THEN** the golden diff fails, because the golden carries no handler-specific field

### Requirement: The provider install is reproducible from the repository through the pinned override

Handler B SHALL run `clusterctl init` with the Nix-rendered `clusterctl.yaml` of `capi-cluster-rendering` and no other provider source, SHALL print the three providers' versions and `Ready` conditions, and SHALL fail when any provider is absent from the override or is installed from clusterctl's built-in registry instead.
Coverage bin: interface (recipe outcome) for ADR-009 F9.2, D9.4; non-vacuity: the scenario below.

#### Scenario: The override omits cluster-api-k3s

- **WHEN** the `k3s` bootstrap and control-plane entries are removed from the override and the recipe runs
- **THEN** `clusterctl init` fails to resolve the provider and the recipe exits non-zero, and independently `checks.k8s-capi-providers` fails at evaluation

### Requirement: The L0 root set is the only prerequisite of the management cluster

Handler B SHALL require nothing beyond the repository checkout, the decryptable Clan vars under `secrets/clusters/cryolite/`, one Hetzner API token supplied as a `Secret`, and stibnite with Colima; it SHALL NOT require a seed host, a standing Hetzner machine, a fleet host, ZeroTier, or any Clan overlay.
Coverage bin: interface (S4 review item; ADR-010 R10.5, E); non-vacuity: the scenario below.

#### Scenario: A hidden prerequisite is discovered

- **WHEN** the S4 runbook transcript lists a host contacted that is none of M1–M6 or the CAPH load balancer
- **THEN** the L0 review item fails and S4 does not proceed until the dependency is removed or recorded as a new L0 member in ADR-010

### Requirement: The pivot moves the cluster and its T0 Secrets, and the management cluster is then deleted

`apps.<system>.k8s.clusterctl-move` SHALL run `clusterctl move --to-kubeconfig cryolite` after both nodes are `Ready` and Flux's root `Kustomization` is `Ready=True`, SHALL assert that the `Cluster`, its control plane, its `MachineDeployment`, and every `Secret` labelled `cluster.x-k8s.io/cluster-name=cryolite` are present in the workload cluster afterwards, and the handler-B recipe SHALL then delete the k3d cluster so that no management cluster remains on stibnite.
This requirement rests on world assumption A21.
Coverage bin: interface (recipe outcome; ADR-010 R10.f, E); non-vacuity: the scenario below.

#### Scenario: A T0 Secret does not move

- **WHEN** a T0 `Secret` is applied without the `cluster.x-k8s.io/cluster-name` label and the pivot runs
- **THEN** the post-move assertion fails naming the missing `Secret`, and the recipe does not delete the management cluster
