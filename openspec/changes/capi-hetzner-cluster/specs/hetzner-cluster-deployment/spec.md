## ADDED Requirements

### Requirement: The per-role node image is built from the fleet disko layout and labelled by its closure

There SHALL be derivations `<c>-server-image` and `<c>-agent-image` (`modules/kubernetes/hetzner/image.nix`) producing raw disk images of the `<c>-server` and `<c>-agent` machine configurations with the same disko layout the fleet's installs use, built on an `x86_64-linux` builder, and a label function (`hetzner/snapshot.nix`) mapping each image to `caph-image-name=<c>-<role>-<closure-hash-prefix>`; the label SHALL be a pure function of the closure so that `checks.k8s-capi-render-<c>` can assert the rendered `imageName` equals it without building the image.
The image SHALL contain no T0 private material (`checks.k8s-closure-secret-free-<c>` of `k3s-nixos-vm-tests`).
Coverage bin: T1 traceability for ADR-009 D9.6, D9.16 and ADR-010 D10.4; non-vacuity: the scenario below.

#### Scenario: The label drifts from the CR

- **WHEN** the label function changes and the rendered tree is not re-rendered
- **THEN** `checks.k8s-capi-render-<c>` fails on `imageName`

### Requirement: Snapshot publishing is an idempotent effect that hides the throwaway server

Publishing SHALL be exposed as `apps.<system>.k8s.hetzner-snapshot-publish`, running outside the sandbox, that for each role creates a throwaway server (M4) in rescue mode, writes the image, snapshots it with the label, deletes the server, exits 0 without creating a server when a snapshot with that label already exists, prunes snapshots of older labels for the same role beyond the newest two, and refuses a label whose closure is not in the repository's current evaluation.
No CR, golden, or Flux object SHALL reference the throwaway server; the Hetzner quirk is confined to `platform.hetzner`'s effect.
This requirement rests on world assumption A19.
Coverage bin: E for ADR-009 D9.16, R9.9; non-vacuity: the scenarios below.

#### Scenario: The label already exists

- **WHEN** the effect runs twice for the same closure
- **THEN** the second run creates no server, `hcloud image list` shows one snapshot per role for that label, and the second transcript records the early exit

#### Scenario: The throwaway server survives

- **WHEN** the effect's delete step fails
- **THEN** the effect exits non-zero naming the server id, and the S4 runbook stops until `hcloud server list` shows no M4

### Requirement: The first paid action is gated on explicit written approval

No task that creates a Hetzner resource for `<c>` SHALL start before the owner's explicit written approval is recorded in that stage's PR description; silence, a merged planning PR, a green S3, or a passing `vm-k3s-capi-bootstrap` SHALL NOT constitute approval.
Coverage bin: interface (review rule with the PR body as witness); non-vacuity: the scenario below.

#### Scenario: A Hetzner call precedes the approval

- **WHEN** a transcript in the S4 PR shows an `hcloud` or CAPH-driven resource creation with a timestamp earlier than the recorded approval
- **THEN** the review fails and the resources are deleted before the PR proceeds

### Requirement: One deployment uses exactly the machines M1–M6 and no Clan-managed node

The S4 runbook SHALL involve only M1 stibnite, M2 the Linux builder, M3 the k3d management cluster on stibnite, M4 the Hetzner throwaway server, M5 the Hetzner k3s server node, and M6 the Hetzner k3s agent node, plus the CAPH-created load balancer, and SHALL record every host contacted; Terranix, nixos-anywhere, and `clan machines install` SHALL NOT touch M5 or M6, and no `<c>-*` entry SHALL exist in the Clan inventory's machines.
M3 SHALL be deleted after the pivot and M4 after each snapshot, so that no bootstrap-only machine outlives its stage.
Coverage bin: interface (runbook review; ADR-010 D10.3, D10.5, R10.5, E); non-vacuity: the scenario below.

#### Scenario: A node is installed by hand

- **WHEN** a node reachable at a Hetzner address for `<c>` was created by anything other than CAPH from the labelled snapshot
- **THEN** CAPH cannot manage it, the runbook records the violation, and the node is deleted before the stage completes

### Requirement: The first server boots with the pre-provisioned T0 identity

After M5 is `Ready`, the fingerprint of `/var/lib/rancher/k3s/server/tls/server-ca.crt` on M5 SHALL equal the Clan vars value under `secrets/clusters/<c>/`, the host certificates of M5 and M6 SHALL verify under the T0 SSH CA, Flux's root `Kustomization` SHALL be `Ready=True` at the digest in the closure, and no object in the management cluster SHALL carry a T0 value inline.
Coverage bin: E for ADR-010 R10.6, F10.1; non-vacuity: the scenario below.

#### Scenario: The provider generated its own CA

- **WHEN** the CA `Secret`s were not pre-created before the `Cluster` was applied
- **THEN** the fingerprint differs from the Clan vars value, the check fails, and the cluster is deleted and recreated with the T0 Secrets present

### Requirement: A flake bump rolls a node into a new identity and the repository stays identity-free

Bumping the flake revision, republishing the snapshots, and applying the re-rendered tree SHALL cause CAPH to replace a node with a `Machine` whose name, SSH host key, and `network.cilium.io/wg-pub-key` differ from the replaced node's, SHALL leave no object of the replaced node in either cluster, and SHALL leave `checks.k8s-node-identity-free-<c>` passing.
Coverage bin: E for ADR-009 D9.6 and ADR-010 D10.1, D10.6; non-vacuity: the scenario below.

#### Scenario: A node's identity was recorded somewhere

- **WHEN** any repository file, inventory entry, or Secret is found to reference the replaced node's name or key after the roll
- **THEN** `checks.k8s-node-identity-free-<c>` fails naming it, and the reference is removed before the stage completes

### Requirement: First-deploy administrative access needs no overlay

Until S4b, administrative access to `<c>` SHALL be the CAPH load balancer's `controlPlaneEndpoint` for the API server and the nodes' public addresses for SSH under the T0 SSH CA; the runbook SHALL NOT add a node to ZeroTier, Yggdrasil, or any Clan `wireguard` instance, and `clan/inventory/k8s-wireguard.nix` SHALL NOT exist in S4.
Coverage bin: interface (runbook review; ADR-009 D9.15); non-vacuity: the scenario below.

#### Scenario: A node joins an overlay

- **WHEN** a k3s node appears as a peer on the ZeroTier controller or in any Clan `wireguard` instance during S4
- **THEN** the runbook records the violation and the peer is removed before the stage completes

### Requirement: Disaster recovery is etcd-S3 plus the L0 set

The server node SHALL take `--etcd-s3` snapshots with credentials from the T0 set to the bucket decided under design Q2, and the recovery path SHALL be: rebuild M3 from L0, restore the snapshot on a fresh M5, re-pivot; a rehearsal SHALL be a separately approved action after S4 and is not part of this change's tasks.
Coverage bin: E (deferred rehearsal; ADR-010 D10.7, R10.g); non-vacuity: the scenario below.

#### Scenario: No snapshot exists

- **WHEN** the bucket lists no snapshot for `<c>` one interval after S4.7 completes
- **THEN** the etcd-S3 configuration is wrong and S4 is not complete
