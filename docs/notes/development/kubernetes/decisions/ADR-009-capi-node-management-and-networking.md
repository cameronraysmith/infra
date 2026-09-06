# ADR-009: Cluster API node management and cluster networking

## Status

Proposed (2026-09-04; revision 2 the same day: the seed host is removed, the admin overlay moves to S4b with the primary VPS as controller, the k3d handler comes first, the image path is fixed as O1, and the machine lifecycle is M1–M6 of ADR-010).
Design only; no flake input, production module, workflow, Terranix, or cloud change lands with this record.
Implemented by stages S3, S4, S4b, and the deferred S5 of `openspec/changes/capi-hetzner-cluster/`, which depends on `openspec/changes/k3s-nixos-vm-tests/`; S4 spends money and needs explicit written approval.
Every decision governs the sibling cluster `kubernetes/clusters/<c>` (ADR-007 D7.15); revision-1 decisions are retained with a bracketed revision-2 status and the three revision-2 decisions are D9.15–D9.17.

## Context

ADR-007 regulates the k3s node OS and ADR-008 the reconciler and artifacts.
Neither says how nodes come to exist, how they join, or how they talk to each other and to their operators.
The fleet's existing answer is Terranix for hosts and ZeroTier for the overlay; neither is a node lifecycle manager and neither knows what a `MachineDeployment` is.
The proximal target is a two-node k3s cluster on Hetzner whose nodes are Cluster API objects, and whose declaration is cloud-invariant except for a typed platform submodule, so that a second cloud is a new submodule and not a fork.
The two mechanisms differ in direction: Clan is push (the admin knows the IP and deploys to it), CAPI is pull (a node appears from an image and configures itself from what the provider hands it), and the image path (D9.16), the identity tiers (ADR-010), and the overlay design (D9.15) all follow from choosing pull for the cluster's nodes.
What this record owns after revision 2: Cluster API, cluster-api-k3s, CAPH, the typed `platform` sum, the CCM requirement, CAPI rendering, air-gapped bootstrap, the management-cluster handlers, the image path, and the network architecture.
Who the nodes are, how they get their secrets, and in what order the machines come to exist is ADR-010.

Paths under `~/ghq/` refer to the reference trees listed in ADR-007's appendix at the revisions recorded there.
Claims read in source are stated as facts; claims that were not executed are marked as inferred and listed in the open-risk table with the regulator that would discharge them.

## Findings

### F9.1: cluster-api-k3s has an air-gapped bootstrap path that expects the k3s binary to be present

`KThreesConfigSpec.AirGapped` skips the `get.k3s.io` download; the operator is expected to place the k3s binary and the install script at `AirGappedInstallScriptPath`, default `/opt/install.sh` (`~/ghq/github.com/k3s-io/cluster-api-k3s/bootstrap/api/v1beta2/kthreesconfig_types.go:159-170`; `pkg/cloudinit/cloudinit.go:73`).
The generated cloud-init `runcmd` is `INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC='server' sh /opt/install.sh` for the control plane and the `agent` form for workers (`pkg/cloudinit/controlplane_init.go:30`, `worker_join.go:26`), preceded by `write_files` that include `/etc/rancher/k3s/config.yaml` (`pkg/k3s/config.go:10`) and any `KThreesConfig.spec.files` (`kthreesconfig_types.go:30`).
The webhook defaults `disableCloudController` to `true` and `cloudProviderName` to `external` (`kthreesconfig_webhook.go:67-72`), and `tls-san` always includes the control-plane endpoint (`pkg/k3s/config.go:49`) with `spec.serverConfig.tlsSan` appended (`kthreesconfig_types.go:72-74`).

### F9.2: cluster-api-k3s is not in clusterctl's built-in registry

clusterctl's provider table has `aws`, `gcp`, `hetzner`, `kubevirt`, and a `kubekey-k3s` bootstrap/control-plane pair (`~/ghq/github.com/kubernetes-sigs/cluster-api/cmd/clusterctl/client/config/providers_client.go:40`, `47`, `50`, `65`, `87`, `100`, `379`, `421`); the `k3s-io/cluster-api-k3s` providers are absent.
Its own samples install it through a `clusterctl.yaml` override that names local `bootstrap-components.yaml` and `control-plane-components.yaml` (`~/ghq/github.com/k3s-io/cluster-api-k3s/samples/clusterctl.yaml:1-7`).
For this design the override is a strength: the components are Nix-rendered manifests applied to the management cluster, and `clusterctl` never fetches anything.

### F9.3: CAPH boots from a named Hetzner snapshot

`HCloudMachineTemplate.spec.template.spec.imageName` selects the snapshot; `imageURL` is mutually exclusive (`~/ghq/github.com/syself/cluster-api-provider-hetzner/api/v1beta1/hcloudmachine_types.go:55-60`, `79`).
CAPH's documented image pipeline labels the snapshot `caph-image-name=<name>-<version>` and the template refers to that label (`docs/caph/02-topics/03-node-image.md:30`, `55`; `docs/caph/03-reference/03-hcloud-machine-template.md:19`).
hetzkube does exactly this with kubeadm: `imageName = "2505-x86"` in the rendered `HCloudMachineTemplate` (`~/ghq/github.com/Lillecarl/hetzkube/kubenix/modules/capi.nix:141`, `220`, `305`, `367`; `README.md:44-45`), and a `clusterctl move` from a bootstrap cluster (`README.md:110`).
Nobody in the reference set combines CAPH with cluster-api-k3s.

### F9.4: NixOS' QEMU VM can be built for a Darwin host

`virtualisation.host.pkgs` selects the host package set (`~/ghq/github.com/NixOS/nixpkgs/nixos/modules/virtualisation/qemu-vm.nix:728`), the run script checks KVM on Linux and HVF on Darwin (`299-318`), and QEMU is `qemu_kvm` when host and guest arches match and plain `qemu` otherwise (`741-751`).
A NixOS k3s node closure evaluated for `aarch64-linux` with `host.pkgs = aarch64-darwin` is therefore a runnable management cluster on stibnite; the same closure for `x86_64-linux` runs under KVM or TCG on Linux.
k3s is Linux-only, so there is no nix-darwin k3s module and the Darwin host contributes only the hypervisor.

### F9.5: NixOS can consume a NoCloud seed

Nixpkgs' own `cloud-init` test builds an ISO labelled `cidata` with `meta-data` and `user-data` and boots a NixOS guest against it (`~/ghq/github.com/NixOS/nixpkgs/nixos/tests/cloud-init.nix:14`, `28`, `52`, `68`, `78-79`).
The nixpkgs k3s module composes `ExecStart` from `role` at evaluation and accepts `--config <configPath>` at runtime (`nixos/modules/services/cluster/rancher/default.nix:485`, `932-940`).
Nothing in either tree runs cloud-init's `runcmd` into `k3s.service`; that shim (D9.3) is the untested piece.

### F9.6: the Clan `wireguard` service allocates a ULA per instance and distinguishes controllers from peers

Each instance gets a deterministic `/40` ULA; each controller a `/56`; each peer one 64-bit suffix used in every controller subnet; peers connect to all controllers (`~/ghq/git.clan.lol/clan/clan-core/clanServices/wireguard/default.nix:2-8`, `30-31`, `42-50`; `README.md:8-34`).
This is a hub-and-spoke admin network, not a dataplane.

### F9.7: Cilium's own encryption and ClusterMesh preconditions

Cilium WireGuard transparent encryption is node-to-node on UDP 51871 (`~/ghq/github.com/cilium/cilium/Documentation/security/network/encryption-wireguard.rst:13-14`, `34`).
ClusterMesh requires non-conflicting PodCIDRs across all clusters and nodes and, in native routing, a `ipv4-native-routing-cidr` covering every connected cluster's PodCIDR range (`Documentation/network/clustermesh/setup.rst:34-35`, `60`), a unique `cluster.name` and `cluster.id` (`126`), and mutually reachable ClusterMesh API servers (`373`).

## Decisions

### D9.1: Cluster API is the node-management contract; cluster-api-k3s and CAPH are the first providers [narrowed, rev 2]

Nodes are `Machine` objects owned by a `KThreesControlPlane` and a `MachineDeployment`, with a `MachineHealthCheck`.
Terranix is not the node manager (this reverses the interim position that Terranix would create k3s hosts).
Revision 1 continued "it survives only to provision the seed/management host and any cloud objects CAPI does not own"; that clause is Superseded by D-e (rev 2, ADR-010 D10.3): there is no seed host, and Terranix is simply unrelated to the cluster.
Terranix, nixos-anywhere, and `clan machines install` never touch a k3s node: CAPH can manage only servers it created, so a node installed by any of them would be a permanent non-CAPI node.
Terranix stays what it is for the fleet hosts (magnetite, cinnabar), which are a different machine class.
CAPI manages nodes from day one so that S4's first two Hetzner nodes are already rolled by flake bump (D9.6), not hand-replaced later.

### D9.2: remote k3s uses cluster-api-k3s `airGapped` mode; the NixOS image supplies the binary

`KThreesConfigTemplate.spec.agentConfig.airGapped: true` (and the control-plane equivalent) so the node never downloads k3s.
The NixOS snapshot carries `pkgs.k3s` from the locked nixpkgs, which is the same binary the VM leaves test.
No kubeadm anywhere: hetzkube's `KubeadmControlPlane`/`KubeadmConfigTemplate` are replaced by the KThrees kinds.

### D9.3: a Nix-written `/opt/install.sh` shim starts `k3s.service`

The NixOS image ships a script at `/opt/install.sh` (an `environment.etc`-style symlink or `systemd.tmpfiles` entry into the store) that ignores `INSTALL_K3S_*` download semantics, copies nothing, and does two things: it verifies `/etc/rancher/k3s/config.yaml` exists (written by cloud-init `write_files` from the `KThreesConfig`) and runs `systemctl start k3s.service`.
`services.k3s.configPath = "/etc/rancher/k3s/config.yaml"` so the unit reads the CAPI-generated config.
`services.k3s.role` is fixed at evaluation (F9.5); the image is therefore built per role (`machines/nixos/<c>-server.nix`, `machines/nixos/<c>-agent.nix`, ADR-007 D7.17), which resolved ambiguity 2 of the first revision in favor of one snapshot per role (D9.16); the two-unit alternative is not built.
The sentinel file the template expects (`{{ .SentinelFileCommand }}`) is written by the shim after `systemctl is-active k3s` succeeds.
The shim, `services.k3s.configPath`, and the per-role unit live in `modules/nixos/k3s-server/capi-bootstrap.nix`.

### D9.4: management cluster is a capability with two handlers behind one contract [narrowed by D9.17, rev 2]

The contract is: a kubeconfig, the CAPI core plus CAPH plus cluster-api-k3s providers installed from Nix-rendered manifests through a `clusterctl.yaml` override (F9.2), and then identical CRs applied by `kubectl apply` or `clusterctl move`.

- Handler A: the NixOS k3s node closure as a QEMU VM via `virtualisation.host.pkgs` (F9.4), running on `aarch64-darwin` (HVF), `x86_64-linux` with KVM, or `x86_64-linux` under TCG (slow, correct). Revision 1 preferred it because it is the production closure; revision 2 defers it (D9.17).
- Handler B: k3d on stibnite through Colima, a cluster that runs only the CAPI, CAPH, and cluster-api-k3s controllers, exposed as `apps.k8s-mgmt-k3d` from `modules/kubernetes/capi/management.nix`. It reuses the k3d pattern of ADR-005 but is not `kubernetes/clusters/local-k3d/`, which is a frozen prototype and is not edited.

Revision 1 exercised both handlers in S3 and wrote that `kubernetes/clusters/local-k3d/` "survives the k3d workflow deletion in ADR-007 D7.13"; both statements are Superseded by D-g and D-a (rev 2, D9.17 and ADR-007 D7.15): S3 exercises handler B by a recipe that is not a check, no `vm-capi-management` leaf is built until handler A returns, and nothing is deleted.

### D9.5: no nix-darwin k3s module [kept; handler-A half deferred]

k3s is Linux-only; a Darwin host runs a management cluster and nothing else.
With handler B first (D9.17), the Darwin side is Colima running k3d; the `packages.aarch64-darwin.management-vm` output of revision 1 (the `aarch64-linux` node closure with `host.pkgs` set to the Darwin package set) is the deferred handler A.

### D9.6: node OS is a Hetzner snapshot labelled by flake revision; a flake bump rolls nodes [kept; refined by D9.16]

The node image is built from the same NixOS k3s configuration the VM leaves import, uploaded as a Hetzner snapshot labelled `caph-image-name=<rev>` per role by the `apps.k8s.hetzner-snapshot-publish` effect (packer is not required; the upload path is the `hcloud-upload-image` pattern of D9.16, inferred from CAPH's label contract, F9.3).
The easykubenix cluster module emits `HCloudMachineTemplate.spec.template.spec.imageName` from the same string.
Changing the flake revision changes the template, which makes CAPI create replacement machines and delete the old ones; that is the only node-roll mechanism.
Revision 1 added that configuration-only changes must not roll nodes; under the single hash chain of ADR-007 D7.17 a configuration change is a flake revision change and does roll nodes, which was accepted as ambiguity 1 of the first revision. The root `OCIRepository` digest still travels through `KThreesConfig.spec.files` (D9.7) because that is where per-cluster bootstrap data belongs, not because it avoids a roll.

### D9.7: the root `OCIRepository` digest is delivered through `KThreesConfig.spec.files` [kept; extended by ADR-010 D10.4]

The Flux install manifest is in the image (`services.k3s.manifests`, ADR-008 D8.3); the root `OCIRepository` and root `Kustomization` are rendered into `KThreesConfig.spec.files` as `/var/lib/rancher/k3s/server/manifests/flux-root.yaml`.
The same `files` list carries the T0 secrets by reference: `KThreesConfig.spec.files[].contentFrom.secret{name,key}` names a Secret in the management cluster, and the server node drops the Flux age-key Secret manifest into the same directory (ADR-010 D10.4). The snapshot therefore contains no secret.

### D9.8: one k3s NixOS module, one bootstrap-identity seam

`flake.modules.nixos.k3s-server` gains a `bootstrap` option with two values, `clan-vars` (token and server address from Clan vars; the two-guest `vm-k3s-platform` leaf) and `cloud-init` (token, server address, and role config from the CAPI-generated `/etc/rancher/k3s/config.yaml`; the CAPH path and the NoCloud VM leaf).
The option lives in `modules/nixos/k3s-server/capi-bootstrap.nix`; the `clan-vars` value does not make a k3s node a Clan machine (ADR-010 D10.1), it only names where the VM leaf's fixture token comes from.
Everything else in the module — kernel, networking, packages, `snapshotter`, disabled components — is identical in both, which is the invariant the two VM leaves regulate together.

### D9.9: the NoCloud VM leaf regulates the CAPI path

`vm-k3s-capi-bootstrap` boots one node from the `cloud-init` bootstrap variant with a `cidata` ISO built in the sandbox containing the `write_files` and `runcmd` that cluster-api-k3s would generate (rendered by a Nix function that mirrors `pkg/cloudinit/controlplane_init.go`), and asserts that `k3s.service` reaches `active`, the sentinel file exists, and `kubectl get nodes` reports the node.
It does not run the CAPI controllers.
Mutation: remove `write_files` for `/etc/rancher/k3s/config.yaml` and expect the shim to fail before `systemctl start`.

### D9.10: one easykubenix cluster module with a cloud-invariant core and a typed `platform` sum

The cluster module owns `Cluster`, `KThreesControlPlane`, `KThreesConfigTemplate`, `MachineDeployment`, `MachineHealthCheck`, the Flux install and root objects, and Cilium.
`platform` is a submodule typed as a sum over `hetzner | gcp | aws | kubevirt`; the selected variant alone owns `*Cluster`, `*MachineTemplate`, the node-image reference, the cloud-controller manager, and an optional CSI.
An unhandled provider name is an evaluation error (`throw`), not an empty render.
Only `hetzner` is implemented in S4; `gcp` and `aws` are render-only golden variants in S5; `kubevirt` is the name reserved for a self-hosted variant and is not implemented.

### D9.11: a per-cloud CCM is mandatory (R6)

Because cluster-api-k3s defaults `cloud-provider=external` (F9.1), a cluster without a cloud-controller manager never clears node taints.
The `platform` variant must render its CCM; a T1 leaf fails when the rendered tree for any variant lacks a CCM `Deployment` or `DaemonSet`, and the assertion is tied to the bootstrap seam: it applies when `bootstrap = "cloud-init"` and is vacuous under `clan-vars`, where the module passes `--disable-cloud-controller` as it does today.

### D9.12: two networks with partially overlapping membership [D9.12b Superseded by D-d (rev 2, D9.15)]

- D9.12a [kept] The existing ZeroTier fleet network is untouched; Kubernetes nodes never join it.
- D9.12b [Superseded by D-d (rev 2, D9.15)] A dedicated Clan `wireguard` instance (its own `/40` ULA, F9.6) is the Kubernetes admin plane: members are every Kubernetes node plus admin workstations (stibnite and peers), never schedulable; control-plane nodes are the WireGuard controllers. It carries the API server on 6443 (the node's ULA is in `tls-san`, F9.1), SSH and Clan deploys, ClusterMesh API-server reachability, and node joins (`server` address is the controller's ULA). Rationale: every Clan overlay (ZeroTier, Yggdrasil, WireGuard) is a per-machine identity, and node identity is disposable (ADR-010 D10.1); a node that must be a Clan peer to join cannot be replaced by CAPI without a Clan edit.
- D9.12c [kept] The dataplane does not use the Clan WireGuard (hub-and-spoke would route pod traffic through controllers). Cilium WireGuard transparent encryption runs directly between node IPs (F9.7); cross-cloud it runs over public IPs, with UDP 51871 allowlisted through nftables in the node closure to the eval-time-known node set.
- D9.12d [kept] Cross-cloud is ClusterMesh between per-cloud clusters with disjoint PodCIDRs and a native-routing CIDR that covers every participating node network; etcd is never stretched across clouds.

### D9.13: ClusterMesh preconditions are evaluation-time assertions

The cluster module asserts, for the set of clusters that declare mesh membership, that PodCIDRs are pairwise disjoint, `cluster.id` values are unique, and every PodCIDR is contained in the shared `ipv4-native-routing-cidr` (F9.7).
A violation is an evaluation error, which the S0 purity leaf turns into a failing check.

### D9.14: no Crossplane, no Anthos

Neither adds a property the CAPI contract lacks for this fleet; both add a reconciler.

### D9.15: nodes join no Clan overlay; the admin overlay is one gateway per cluster peering with the primary VPS, and it is S4b [new, rev 2; D-d]

k3s nodes never join any Clan overlay.
ZeroTier, Yggdrasil, and the Clan `wireguard` service each bind a network identity to a machine, and T1 node identity is disposable (ADR-010 D10.1); Yggdrasil is the worst fit because its key is its address.
The existing ZeroTier network stays as it is (D9.12a).

When the admin overlay is added, it is a Clan `wireguard` instance whose controller is the existing primary VPS — already a Clan machine with a public endpoint — not the control-plane nodes (D9.12b) and not a new seed host (ADR-010 D10.3).
One gateway per cluster joins as a peer, using a T0 peer key (ADR-010 D10.1) delivered as a Secret, and runs as a one-replica `hostNetwork` workload scheduled onto control-plane nodes; it subnet-routes into the Hetzner private network, so the apiserver, node private IPs, and ClusterMesh API server are reachable from the overlay without any node being a peer.
Stibnite joins as an admin-only peer.
A gateway pod that moves between control-plane nodes keeps its peer identity because the key is cluster identity, not node identity.

The overlay is deferred past the first Hetzner deploy: S4 administers the cluster through the CAPH load balancer's API endpoint and the nodes' public IPs with SSH-CA-signed host keys (ADR-010 D10.1); S4b adds the overlay.
`clan/inventory/k8s-wireguard.nix`, which revision 1 placed in S4, is an S4b artifact.
The dataplane (D9.12c) and cross-cloud rules (D9.12d, D9.13) are unchanged: ClusterMesh needs explicit reachability, disjoint PodCIDRs, and native-routing coverage, regulated at evaluation, and etcd is never stretched.

### D9.16: image path O1 — per-role NixOS snapshots from the fleet disko layout; the Hetzner upload is a provider quirk hidden in `platform.hetzner` [new, rev 2; D-f]

Because CAPI is pull (Context), the node image must be complete before the node exists.
O1, chosen: one NixOS snapshot per role (`<c>-server`, `<c>-agent`), both built from the same disko layout the fleet uses for installs, so the image is the closure and the CR's `imageName` is the closure revision; the hash chain of ADR-007 D7.17 runs unbroken from `clusters/<c>` to the snapshot label.
GCP and AWS variants (S5) use the provider's native custom-image or AMI upload and need no throwaway server.
Hetzner Cloud has no image-upload API (read in CAPH docs: "it is not possible to upload your own images directly. However, a server can be created, configured, and then snapshotted", `~/ghq/github.com/syself/cluster-api-provider-hetzner/docs/caph/02-topics/03-node-image.md:22`), so its upload is the `hcloud-upload-image` pattern: a throwaway server in rescue mode, the image `dd`'d onto its disk, a snapshot taken with label `caph-image-name=<rev>`, the server deleted (machine M4 of ADR-010 D10.5).
That sequence is hidden inside the `platform.hetzner` effect `apps.k8s.hetzner-snapshot-publish` (`modules/kubernetes/hetzner/{image,snapshot}.nix`): idempotent on the label, one snapshot per revision per role, older snapshots pruned.

O2, rejected: boot a stock Debian image and kexec-reinstall NixOS from cloud-init. It is Hetzner-specific, double-boots every replacement (including spot replacements), needs reachable binary-cache credentials on the node at install time, and pins `debian-12` in the CR instead of a closure, which breaks the hash chain.

### D9.17: management handler B (k3d on stibnite/Colima) first; handler A (NixOS QEMU VM, Darwin/HVF) deferred [new, rev 2; D-g]

S3 implements handler B only, as `apps.k8s-mgmt-k3d`.
Handler A is deferred with its contract intact: the same kubeconfig-plus-providers interface, the same CRs, the same `clusterctl move` semantics, so adding it later changes no CR and no stage.
The management cluster is bootstrap-only in either handler (ADR-010 D10.2, level L2): it exists on stibnite until `clusterctl move` has pivoted CAPI into the workload cluster, then it is deleted.

## Requirements carried into the OpenSpec delta specs

| Code | Requirement | Regulator | Tier |
|---|---|---|---|
| R9.1 | cloud-invariant core renders identically across `platform` variants modulo platform-owned fields (golden diff) | `capi-cloud-invariant-render` | T1 |
| R9.2 | unhandled `platform` is an evaluation error | `capi-platform-sum-total` | T1 |
| R9.3 | every variant with `bootstrap = "cloud-init"` renders a CCM (R6) | `capi-ccm-present` | T1 |
| R9.4 | ClusterMesh preconditions hold at evaluation | `clustermesh-preconditions` | T1 |
| R9.5 | a NoCloud seed boots a `cloud-init` node through the shim into `k3s.service`, with T0 material arriving as `contentFrom.secret`-shaped files | `vm-k3s-capi-bootstrap` | T2 |
| R9.6 | handler B runs the CAPI providers from Nix-rendered manifests through the `clusterctl.yaml` override and accepts the rendered CRs | `apps.k8s-mgmt-k3d` recipe on stibnite (K; not a check) | K |
| R9.7 | two Hetzner nodes are `Ready`, Flux converges, `clusterctl move` pivots, and a flake bump rolls one node | S4 runbook (not a check) | E |
| R9.8 | the `capi-<c>` render for `platform = hetzner` matches its golden, and the golden names no node or node key | `k8s-capi-render`, `k8s-node-identity-free` | T1 |
| R9.9 | the snapshot-publish effect is idempotent on the label and leaves exactly one snapshot per revision per role | `apps.k8s.hetzner-snapshot-publish` postcondition | E |

## Verified versus inferred

| Code | Claim | Status | Discharging regulator |
|---|---|---|---|
| R9.a | cluster-api-k3s `airGapped` emits `INSTALL_K3S_SKIP_DOWNLOAD=true ... sh /opt/install.sh` | read in source (F9.1) | `vm-k3s-capi-bootstrap` renders and consumes the same text |
| R9.b | cluster-api-k3s installs through a `clusterctl.yaml` override | read in source (F9.2) | handler B `clusterctl init` on stibnite (S3); a T1 leaf asserts the rendered override names both k3s providers |
| R9.c | CAPH and cluster-api-k3s work together | inferred; no reference deployment found | handler B applies both providers and the rendered `Cluster` (S3, shape only); S4 is the first real reconciliation |
| R9.d | NixOS boots from a CAPI-generated NoCloud seed and the shim starts `k3s.service` | inferred from F9.5 | `vm-k3s-capi-bootstrap` (S3) |
| R9.e | a Nix-built disk image written to a rescue-mode server and snapshotted satisfies CAPH's `imageName` contract without packer | inferred from F9.3 | S4 first node boot |
| R9.f | `virtualisation.host.pkgs` on `aarch64-darwin` runs the k3s closure fast enough to serve as a management cluster | inferred from F9.4; deferred with handler A (D9.17) | none until handler A is scheduled |
| R9.g | a one-replica `hostNetwork` WireGuard gateway on a control-plane node, peering with the primary VPS and subnet-routing the Hetzner private network, gives admin reachability to the apiserver and nodes | inferred from F9.6; the gateway-as-peer shape is not in the Clan `wireguard` README | S4b; until then S4 uses the LB endpoint and public IPs |
| R9.h | UDP 51871 allowlist to an eval-time node set is stable under CAPI node rolls | inferred; the node set changes when a `MachineDeployment` scales | a T1 assertion that the allowlist is derived from the same `MachineDeployment` replica set, plus S4 roll observation |
| R9.i | the Hetzner Cloud API has no image-upload endpoint | read in CAPH docs (`03-node-image.md:22`); the hcloud API reference itself was not read | none needed for the design; S4's first `hetzner-snapshot-publish` run is the behavioral check |

## Provenance

| ADR decision | Design-review code | Note |
|---|---|---|
| D9.1 | D27 (reversed), D20; seed-host clause superseded by D-e | `cross-cloud-node-management.md` §D27; `oci-caph-timoni-decisions.md` D20; revision-2 dispatch §D-e |
| D9.2 | D19 | `oci-caph-timoni-decisions.md` F18–F20, D19 |
| D9.3 | D19 | `oci-caph-timoni-decisions.md` D19 |
| D9.4 | D20 | `oci-caph-timoni-decisions.md` F21, D20 |
| D9.5 | D20 | `oci-caph-timoni-decisions.md` D20 |
| D9.6 | D21 | `oci-caph-timoni-decisions.md` F22, D21 |
| D9.7 | D22 | `oci-caph-timoni-decisions.md` D22 |
| D9.8 | D28 | `cross-cloud-node-management.md` D28 |
| D9.9 | D28 | `cross-cloud-node-management.md` D28 |
| D9.10 | D29 | `cross-cloud-node-management.md` D29 |
| D9.11 | D29, R6 | `cross-cloud-node-management.md` R6 |
| D9.12 | D30a–D30d | `cross-cloud-node-management.md` D30 |
| D9.13 | D30d | `cross-cloud-node-management.md` D30d |
| D9.14 | D31 | `cross-cloud-node-management.md` D31 |
| D9.15 | D-d | revision-2 dispatch §D-d; supersedes D30b / D9.12b |
| D9.16 | D-f | revision-2 dispatch §D-f; refines D21 / D9.6, resolves first-revision ambiguity 2 |
| D9.17 | D-g | revision-2 dispatch §D-g; narrows D20 / D9.4 |

## Related

- ADR-007: VM regulators and stage plan; D7.11–D7.12 are constrained by D9.8; D7.15 fixes the scope and D7.17 the module tree this record's files live in.
- ADR-008: the artifact the CAPI bootstrap delivers (D8.3, D8.4) and the Flux install it assumes in the image.
- ADR-010: identity tiers (T0/T1/T2), bootstrap levels (L0–L3), machines M1–M6, T0 delivery through `contentFrom.secret`, and the node-identity-free regulator; D9.15–D9.17 depend on it.
- `openspec/changes/capi-hetzner-cluster/`: S3, S4, S4b, deferred S5; its `specs/capi-cluster-rendering/spec.md` and `specs/capi-bootstrap-vm-regulator/spec.md` carry R9.1–R9.9.
- `openspec/changes/k3s-nixos-vm-tests/specs/k3s-substrate-vm-regulator/spec.md`: the substrate the CAPI path inherits.
