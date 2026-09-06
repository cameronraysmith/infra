## Why

`openspec/changes/k3s-nixos-vm-tests/` (stages S0–S2) proves the core of the new sibling cluster `kubernetes/clusters/cryolite` inside hermetic NixOS VMs: the node module, the `nix` snapshotter, Cilium with kube-proxy replacement, Flux from a digest-pinned OCI artifact, and the `cryolite` Chainsaw suite.
It stops at the VM boundary.
Nothing in it creates a node on a cloud, decides which machine creates it, delivers the cluster's stable identity to a node that did not exist a minute ago, or gives an operator a path to the API server afterwards.
The revision-2 design review (ADR-009, ADR-010) fixed those answers: Cluster API with cluster-api-k3s and CAPH manages nodes from day one; nodes boot a per-role NixOS snapshot and self-configure from a NoCloud seed in `airGapped` mode; cluster identity (T0) is generated once by Clan vars and reaches a node only through `KThreesConfig.spec.files[].contentFrom.secret`; node identity (T1) is disposable; the bootstrap has no seed host and its root set (L0) is the repository, the Clan vars, one Hetzner API token, and stibnite; the management cluster is a throwaway k3d process on stibnite; and the administrative overlay is deferred until the cluster exists.
This change carries stages S3, S4, S4b, and the deferred S5 for those decisions.

## What Changes

This change is planning-only, like its parent.
It records nothing new in the ADRs; it writes the artifacts S3–S5 implement against, depends on `k3s-nixos-vm-tests` (its S3 requires that change's S2 to have passed), and touches no cloud, no money, no workflow, and none of the frozen prototypes (`kubernetes/clusters/local*`, `kubernetes/nixidy/`, `kubernetes/tests/local-k3d/`, `modules/apps/cluster/`).

**S3 — management handler, rendering, and the bootstrap leaf (mixed KVM)**
Handler B: the effect `apps.k8s.mgmt-k3d` creates a k3d cluster on stibnite (Colima), runs `clusterctl init` with a Nix-rendered `clusterctl.yaml` override pointing at the vendored, digest-pinned release manifests of Cluster API core, CAPH, and cluster-api-k3s (`modules/kubernetes/capi/providers.nix`, `capi/management.nix`), applies the T0 `Secret`s and the rendered CRs, waits, runs `clusterctl move`, and deletes the k3d cluster; it is an effect rather than a check because it needs Docker, network access, and the Hetzner token; the handler contract (kubeconfig, the three providers, identical CRs, `clusterctl move`) is fixed so that Handler A (the k3s closure as a NixOS QEMU VM, including Darwin/HVF) can be added later without changing a CR.
`kubernetes/modules/capi/` and `kubernetes/modules/platform/{default,hetzner,aws,kubevirt}.nix` (`aws` and `kubevirt` declared and throwing) render the `capi-cryolite` tree — `Cluster`, `KThreesControlPlane` (replicas 1), `KThreesConfigTemplate`, `MachineDeployment` (replicas 1), `MachineHealthCheck`, `HetznerCluster`, two `HCloudMachineTemplate`s whose `imageName` is the per-role snapshot label — against a committed golden (`checks.k8s-capi-render-cryolite`, KVM-free), with every T0 item delivered as `files[]` entries whose content is `contentFrom.secret{name,key}` and no node name anywhere (`k8s-node-identity-free-cryolite` takes the rendered tree as an input).
`modules/nixos/k3s-server/capi-bootstrap.nix` adds the `k3s-server.bootstrap` seam (`clan-vars | cloud-init`) with the Nix-written `/opt/install.sh` shim, and the KVM leaf `vm-k3s-capi-bootstrap` boots the `cryolite-server` image from a NoCloud seed carrying the rendered bootstrap data with T0 fixtures inlined, asserting that `k3s.service` starts from `services.k3s.configPath`, that the config drop-ins and the Flux age-key `Secret` manifest land where ADR-010 D10.4 says, that two boots yield distinct host keys valid under the fixture SSH CA, and that no CA private key survives on disk.
`checks.k8s-capi-providers` asserts the override names exactly the three providers with digest-pinned images.

**S4 — the first Hetzner deployment (effectful; explicit spend gate)**
`apps.k8s.hetzner-snapshot-publish` (`modules/kubernetes/hetzner/{image,snapshot}.nix`) builds the per-role disk image from the fleet disko layout on the Linux builder (M2), writes it to a rescue-mode throwaway server (M4), snapshots it with `caph-image-name=<label>`, deletes the server, and is idempotent on the label with one snapshot per revision per role and older ones pruned.
The operator (M1) generates the T0 set with Clan vars, runs Handler B (M3), applies the T0 `Secret`s and the `capi-cryolite` tree, and CAPH creates the load balancer and one server node (M5) and one agent node (M6) from the snapshots; Flux reconciles `cryolite` from the digest in the closure; `clusterctl move` pivots CAPI into `cryolite` and M3 is deleted.
Administrative access is the CAPH load-balancer endpoint plus node public IPs under the T0 SSH CA; no Clan overlay is involved.
S4 is the first action that bills Hetzner: spend is approved in principle, and each flake revision is released by `VANIXIETS_HETZNER_SPEND_APPROVED=<flake rev>` in the operator's shell, which every Hetzner-calling effect checks before its first API call and `checks.k8s-spend-gate-cryolite` regulates KVM-free; every billing task carries a `[bills Hetzner]` marker and a cost line, and the etcd-S3 bucket is fleet-level Terranix infrastructure that outlives the cluster.

**S4b — administrative overlay (effectful)**
A Clan `wireguard` instance whose controller is the existing primary VPS; one gateway per cluster runs as a one-replica `hostNetwork` workload on the control-plane node, joins as a peer with a T0 key delivered as a `Secret`, and subnet-routes into the Hetzner private network; stibnite joins as an admin-only peer.
Nodes are not Clan machines and never join ZeroTier, Yggdrasil, or the overlay themselves.

**S5 — deferred**
`platform.gcp` as the render-only golden variant (GCP-only; `platform.aws` stays declared and throwing), the cloud-invariant-core equivalence regulator across variants, the ClusterMesh preconditions, and the dataplane allowlist derivation are specified here with a `[S5, deferred]` marker and no task is scheduled for them.

**Disaster recovery**
K3s `--etcd-s3` snapshots plus L0 rebuild L2 and restore or re-pivot; a rehearsal is a separately approved action after S4.

## Capabilities

### New Capabilities
- `capi-cluster-rendering` (stratum: `behavioral`): what the fleet requires of the rendered Cluster API declaration of `cryolite` — a golden Hetzner tree whose `imageName` is the closure label, T0 delivery only through `contentFrom.secret` and no node identity in any object, a Nix-rendered and pinned provider override, a total `platform` sum with an evaluation error for the unhandled provider, a cloud-controller manager for every cloud-init variant, and, deferred to S5, cross-variant core equivalence and ClusterMesh preconditions.
- `capi-bootstrap-vm-regulator` (stratum: `behavioral`): what the fleet requires of the hermetic regulator for the cloud-init bootstrap path — that the production node image boots from a NoCloud seed shaped exactly as cluster-api-k3s emits it, that the shim starts `k3s.service` through the production module, that T0 material lands where the design says and T1 identity is fresh on every boot, and that each assertion fails under a mutation.
- `capi-management-cluster` (stratum: `interface`): the properties at the operator-to-management-cluster boundary — one handler contract, Handler B on stibnite first, provider install from the pinned override, the L0 root set as the only prerequisite, and `clusterctl move` as the pivot. Trust boundary: the handler observes what `kubectl` and `clusterctl` report; it does not guarantee that the providers reconcile correctly against Hetzner, which S4 observes.
- `hetzner-cluster-deployment` (stratum: `interface`): the properties at the fleet-to-Hetzner boundary — the snapshot-publish effect's idempotence and label contract, the S4 spend gate, the M1–M6 inventory as the complete machine set, T0 fingerprint equality on the first server, first-deploy administrative access without an overlay, and the etcd-S3 disaster-recovery path. Trust boundary: the effects observe the hcloud API's responses; the API's own behaviour (no image upload, snapshot labels, server lifecycle) is a world assumption and is only ever observed.
- `k8s-admin-overlay` (stratum: `behavioral`): what the fleet requires of the deferred administrative overlay — controller on the primary VPS, one gateway workload per cluster with a T0 peer key, nodes never Clan machines, stibnite admin-only, and the dataplane untouched.

### Modified Capabilities
- `world-assumptions` (stratum: `world`): assumptions are added — cluster-api-k3s defaults the cloud provider to external (A17), Cilium ClusterMesh requires disjoint PodCIDRs and a covering native-routing CIDR (A18), Hetzner Cloud offers no image-upload API (A19), cloud-init's NoCloud datasource reads user-data from a labelled seed (A20), and Cluster API's `clusterctl move` carries the Secrets labelled with the cluster name (A21).

## Impact

Implementation, in later changes, touches only the `[add]` paths the parent design's target module layout marks for S3–S5: `modules/kubernetes/capi/{providers,management,render}.nix`, `modules/kubernetes/hetzner/{image,snapshot}.nix`, `modules/kubernetes/identity.nix` (an added input), `modules/nixos/k3s-server/capi-bootstrap.nix`, `modules/checks/vm-k3s-capi-bootstrap.nix`, `modules/checks/k8s-capi-render.nix`, `modules/apps/k8s/{hetzner-snapshot-publish,clusterctl-init,clusterctl-move,k8s-mgmt-k3d}`, `kubernetes/modules/capi/`, `kubernetes/modules/platform/`, the `capi-cryolite` golden under `kubernetes/tests/cryolite/golden/`, `secrets/clusters/cryolite/` (the T0 generators the parent adds gain the etcd-S3 and, in S4b, the gateway peer key), and, in S4b, one Clan `wireguard` instance in the inventory naming the primary VPS as controller and stibnite as a peer.
`modules/devshells/kubernetes.nix` gains clusterctl and hcloud additively.
Nothing under `kubernetes/clusters/local*`, `kubernetes/nixidy/`, `kubernetes/tests/local-k3d/`, `modules/apps/cluster/`, `.github/workflows/`, or the flake inputs is edited; the existing ZeroTier network and every existing Clan machine are untouched, and no k3s node becomes a Clan machine.
S4 and S4b spend money and create cloud resources; S3 and S5 do not.
