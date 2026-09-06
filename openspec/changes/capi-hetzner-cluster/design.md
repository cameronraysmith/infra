## Context

This change is the second half of the plan `openspec/changes/k3s-nixos-vm-tests/` begins.
That change proves the core of `kubernetes/clusters/<c>` inside NixOS VMs (S0–S2); this one takes the same node closure to Hetzner under Cluster API (S3, S4), adds the administrative overlay afterwards (S4b), and holds the render-only cloud variants until a second cloud is real (S5).
The decisions it implements are recorded in ADR-009 (Cluster API, cluster-api-k3s, CAPH, the `platform` sum, image path O1, handler B, the deferred overlay) and ADR-010 (identity tiers T0/T1/T2, bootstrap levels L0–L3, machines M1–M6, `contentFrom.secret` delivery, no seed host); this document does not restate them, it fixes how the S3–S5 artifacts satisfy them and where each artifact sits.
Scope inherits the parent's constraints: `local` and `local-k3d` are frozen prototypes, nothing here edits them, and the only edits to existing files are additive.

Three facts from the ADRs shape every decision below.
The L0 root set is the repository, the Clan vars under `secrets/clusters/<c>/`, one Hetzner API token, and stibnite; no other machine may be required to reach a running cluster (ADR-010 D10.2).
Node identity is disposable: a node that CAPH replaces has a new `Machine` name, new host keys, and a new Cilium WireGuard key, and nothing in the repository, the inventory, or the management cluster may name the old one (ADR-010 D10.1, D10.6).
The Hetzner path needs a throwaway server to make a snapshot because Hetzner Cloud has no image-upload API (ADR-010 F10.5, read in CAPH's documentation); that quirk is hidden inside `platform.hetzner`'s effect and never surfaces in a CR (ADR-009 D9.16).

Boundaries named once for the whole document: Cluster API core, CAPH, cluster-api-k3s, k3d, clusterctl, hcloud, and cloud-init are vendored and consumed at pinned revisions from nixpkgs or from vendored release manifests; the `platform` sum, the `capi` modules, the bootstrap seam, the shim, the handler recipe, the snapshot effect, the goldens, and the regulators are first-party.
Source-versus-delivered: the `capi-<c>` tree is source in `kubernetes/modules/capi/` and `kubernetes/clusters/<c>/`, delivered as rendered YAML applied to the management cluster; the node image is source in `modules/machines/nixos/<c>-{server,agent}.nix`, delivered as a Hetzner snapshot whose label is the only thing a CR sees.

## Goals / Non-Goals

Goals
- Fix the artifacts S3 builds so that a k3d management cluster on stibnite accepts the rendered `capi-<c>` tree, the provider install is reproducible from the repository, and the cloud-init bootstrap path is regulated in a VM before any node exists.
- Fix the S4 procedure so that the L0 set suffices, every machine involved is one of M1–M6, T0 material reaches nodes only through `contentFrom.secret`, and the first-deploy administrative path needs no overlay.
- Fix the handler contract so Handler A can be added later without changing a CR.
- Specify S4b and S5 precisely enough that their later implementation is a matter of scheduling, not design.

Non-Goals
- Implementing anything; this change is planning-only.
- Any edit to the frozen prototypes, the k3d workflow, the flake inputs, the existing ZeroTier network, or any existing Clan machine.
- Handler A, `platform.gcp`, `platform.aws`, `platform.kubevirt` beyond its evaluation error, ClusterMesh, and a second cluster.
- Spending money before the owner's explicit written approval of S4.

## Decisions

### D1: Handler B first; the contract is the kubeconfig, three providers, identical CRs, and `clusterctl move` [ADR-009 D9.4, D9.17]

`apps.k8s.k8s-mgmt-k3d` creates a k3d cluster on stibnite's Colima Docker and runs `clusterctl init --config <store path>/clusterctl.yaml --core cluster-api:<v> --bootstrap k3s:<v> --control-plane k3s:<v> --infrastructure hetzner:<v>`; the override's `providers[]` `url`s are store paths of the vendored release manifests (`modules/kubernetes/capi/providers.nix`).
The contract a handler must satisfy is: a kubeconfig on stibnite, those three providers `Ready`, the `capi-<c>` tree and the T0 `Secret`s applied unchanged, and `clusterctl move --to-kubeconfig <c>` succeeding.
Handler A (`virtualisation.host.pkgs` QEMU VM of the k3s closure, Darwin/HVF) is deferred and must satisfy the same contract when added; nothing in the CRs or the Secrets names the handler.
Boundary: k3d, clusterctl, and the provider manifests are vendored; the override, the recipe, and the contract test are first-party.
This is the one place the design accepts a Docker dependency on stibnite; it is bootstrap-only (M3) and deleted after the pivot.

### D2: The `capi-<c>` tree is rendered by easykubenix and regulated by a golden, Hetzner only until S5 [ADR-009 D9.1, D9.6, D9.10, D9.16]

`kubernetes/modules/capi/` renders the cloud-invariant core (`Cluster`, `KThreesControlPlane`, `KThreesConfigTemplate`, `MachineDeployment`, `MachineHealthCheck`); `kubernetes/modules/platform/hetzner.nix` alone renders `HetznerCluster` and the two `HCloudMachineTemplate`s and sets `imageName` from the per-role snapshot label; `kubernetes/clusters/<c>/topology.nix` fixes `platform = hetzner`, one server, one agent.
`checks.k8s-capi-render-<c>` diffs the render against `kubernetes/tests/<c>/golden/capi/`.
`platform.kubevirt` is declared and throws a distinct evaluation error; `gcp` and `aws` are declared, render-only, and S5.
The hash chain the parent establishes (`clusters/<c> → k8s-oci-<c> → k3s-flux.nix → <c>-server closure`) is extended here by two links: `→ snapshot label → capi-<c>`, so one flake revision determines the CRs.
Boundary: the CRD schemas are vendored; the rendering modules and golden are first-party.

### D3: T0 material is delivered only through `contentFrom.secret`; the bootstrap template names no node [ADR-010 D10.4, D10.6; ADR-009 D9.7]

The rendered `KThreesControlPlane.spec.kthreesConfigSpec.files[]` and `KThreesConfigTemplate.spec.template.spec.files[]` carry every T0 item as `contentFrom.secret{name,key}` referencing a management-cluster `Secret` named `<c>-<item>`: the token and CA drop-ins under `/etc/rancher/k3s/config.yaml.d/`, the etcd-S3 credentials (server), the Flux age-key `Secret` manifest under `/var/lib/rancher/k3s/server/manifests/` (server), the SSH CA private key for boot-time host-key signing (both, deleted after use), and the cosign and SSH CA public material (both; may equally be baked into the image).
Inline `content` is forbidden for T0 items; the `k8s-node-identity-free-<c>` regulator of the parent takes the rendered `capi-<c>` tree as an added input.
The root `OCIRepository` digest travels the same way (ADR-009 D9.7), so a configuration bump rolls control-plane machines; accepted in revision 1 (parent A1) and unchanged.
Boundary: `contentFrom.secret` is cluster-api-k3s' vendored mechanism (ADR-010 F10.2, read in source); which items travel and where they land is first-party.

### D4: One bootstrap seam in the production module; the NoCloud leaf regulates the cloud-init half [ADR-009 D9.8, D9.9; ADR-010 R10.3–R10.4]

`modules/nixos/k3s-server/capi-bootstrap.nix` adds `k3s-server.bootstrap = "clan-vars" | "cloud-init"`; `cloud-init` enables `services.cloud-init` with the NoCloud datasource only, installs the shim at `/opt/install.sh` (which ignores `INSTALL_K3S_*`, links the closure's `k3s`, and starts `k3s.service` reading `services.k3s.configPath`), and orders `k3s.service` after `cloud-final.service`.
`vm-k3s-capi-bootstrap` (`modules/checks/vm-k3s-capi-bootstrap.nix`) boots the `<c>-server` image with a seed ISO whose `user-data` is the rendered bootstrap template with the `contentFrom.secret` entries resolved against the parent's test-only fixtures, exactly as the provider would resolve them; a second boot from a fresh disk and the same seed yields distinct host keys, both valid under the fixture SSH CA, and the CA private key is absent from the disk after `k3s.service` is active.
The leaf's `runcmd` text is taken from cluster-api-k3s' own fixture (`INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC='server' sh /opt/install.sh`) so the oracle is the provider's output, not the design's paraphrase (accepted in revision 1; the shim ignores `INSTALL_K3S_EXEC`).
Boundary: cloud-init and its NoCloud datasource are vendored; the seam, the shim, and the leaf are first-party.
Verified-versus-inferred: that NixOS boots from a CAPI-shaped NoCloud seed and the shim starts `k3s.service` is inferred (ADR-009 R9.d); this leaf is its discharge.

### D5: Image path O1 — per-role snapshots from the fleet disko layout, published by an idempotent effect [ADR-009 D9.16]

`modules/kubernetes/hetzner/image.nix` builds `<c>-server` and `<c>-agent` as raw disk images with the same disko layout the fleet's `nixos-anywhere` installs use, on the Linux builder (M2); `hetzner/snapshot.nix` and `apps.k8s.hetzner-snapshot-publish` create a throwaway server (M4) in rescue mode, write the image, snapshot it with `caph-image-name=<label>` where `<label>` is derived from the closure's store hash and role, delete the server, and exit 0 without acting when a snapshot with that label already exists; snapshots of older labels for the same role are pruned beyond the newest two.
GCP and AWS variants (S5) upload natively and never need M4.
O2 (stock Debian plus a cloud-init `kexec` reinstall) is rejected: Hetzner-specific, a double boot per replacement, reachable cache credentials on every node, and a CR that pins `debian-12` rather than a closure.
Boundary: hcloud and the rescue system are vendored; the image derivation, the label function, and the effect are first-party.
Verified-versus-inferred: that a Nix-built image written in rescue mode and snapshotted satisfies CAPH's `imageName` contract is inferred (ADR-009 R9.e); S4's first node boot is its discharge.

### D6: The S4 procedure uses M1–M6 and nothing else, and is gated on explicit approval [ADR-010 D10.2, D10.5]

The runbook is fixed as the ordered list in `tasks.md` S4 and the machine table is ADR-010 D10.5: M1 stibnite (operator, bootstrap and admin), M2 Linux builder (bootstrap), M3 k3d management cluster on stibnite (bootstrap; deleted after pivot), M4 Hetzner throwaway server (bootstrap; deleted after snapshot), M5 Hetzner k3s server node and M6 agent node (cluster; created by CAPH, receive T0 via `contentFrom.secret`, host CAPI after pivot); the CAPH-created load balancer is the API endpoint and not a machine.
A review item before the first `hcloud` call confirms the L0 set is the complete prerequisite (ADR-010 R10.5), and the first server's `server-ca.crt` fingerprint is compared with the Clan vars value after boot (R10.6).
The gate: no S4 task may start without the owner's explicit written approval recorded in the S4 PR; silence, a merged planning PR, or a green S3 does not authorize it.
Terranix, nixos-anywhere, and `clan machines install` never touch M5 or M6 (ADR-010 D10.3).

### D7: The administrative overlay is S4b, controlled by the primary VPS, with one gateway workload per cluster [ADR-009 D9.15]

A Clan `wireguard` instance is added to the inventory with the existing primary VPS as controller and stibnite as an admin-only peer; the cluster joins through one `Deployment` (replicas 1, `hostNetwork`, control-plane node selector) whose peer private key is a T0 item delivered as a `Secret`, advertising the Hetzner private network as its allowed subnet.
No k3s node is a Clan machine, joins ZeroTier, Yggdrasil, or the overlay directly, and the Cilium WireGuard dataplane is unchanged.
Until S4b, administrative access is the CAPH load-balancer endpoint and node public IPs under the T0 SSH CA.
Verified-versus-inferred: the gateway-as-peer shape is not in the Clan `wireguard` README (ADR-009 R9.g); S4b's first connection is its discharge, and the design accepts that S4b may need a Clan-side change to register a non-machine peer (open question Q3).

### D8: Disaster recovery is etcd-S3 plus L0 [ADR-010 D10.7]

`--etcd-s3` snapshots run from the server node with credentials from the T0 set; recovery rebuilds M3 from L0, restores the snapshot on a fresh M5, and re-pivots.
A rehearsal is a separately approved action after S4 (ADR-010 R10.g, inferred).

### D9: S5 is specified, marked, and unscheduled

The cross-variant core-equivalence golden, the ClusterMesh preconditions, the dataplane allowlist derivation, and the `gcp`/`aws` variants keep their requirements in `capi-cluster-rendering` with an `[S5, deferred]` marker; `tasks.md` lists S5 as a stage with no unchecked task and a note that scheduling it is a separate decision.

## Risks / Trade-offs

- R1 cluster-api-k3s and CAPH have not been run together by anyone found (ADR-009 R9.c). Mitigation: S3 applies both providers and the rendered `Cluster` to Handler B and observes the objects' conditions before any spend; S4 is the first real reconciliation and is gated.
- R2 The NoCloud leaf resolves `contentFrom.secret` itself, so it regulates the node's consumption of the bootstrap data, not the provider's production of it. Mitigation: the `runcmd` and `write_files` shapes are taken from cluster-api-k3s' fixtures and source (ADR-010 F10.2); the provider's own behaviour is observed in S3 by reading the `<c>-server` bootstrap `Secret` the provider generates against Handler B.
- R3 Boot-time SSH CA signing exposes the CA private key on the node transiently (ADR-010 R10.e, OQ10.2). Mitigation: the leaf greps the disk after the unit completes; the alternative (offline per-`Machine` certificates) is recorded and can be adopted without changing the CRs' shape.
- R4 A stale snapshot label (image built from an unpushed revision) would let CAPH create nodes from an image whose closure the repository does not have. Mitigation: the label is derived from the closure hash, `k8s-capi-render-<c>` fails when the rendered label differs from the built image's, and the publish effect refuses a label whose closure is not in the repository's current evaluation.
- R5 Handler B depends on Docker on stibnite, which is the one non-Nix runtime dependency of the bootstrap. Accepted because M3 is bootstrap-only and deleted; Handler A removes it when scheduled.
- R6 Pruning snapshots beyond the newest two per role can delete the image a rollback would need. Accepted with the bound stated; rollback to an older revision re-publishes from the closure, which is reproducible.

## Migration Plan

S3 follows the parent's S2; S4 follows S3 and explicit approval; S4b follows S4; S5 is unscheduled.
Nothing is migrated: `<c>` is new, the prototypes are frozen, and the fleet hosts keep Terranix, nixos-anywhere, and Clan install.
Rollback of S3 is deleting the `[add]` paths; rollback of S4 is `hcloud` deletion of M5, M6, the load balancer, and the snapshots, which the same effects can perform; rollback of S4b is removing the inventory instance and the gateway `Deployment`.

## Open Questions

Recommendations stand on silence except Q1, which spends money and needs explicit words.

- Q1 S4 approval. Recommendation: none can be given here; the owner writes it in the S4 PR.
- Q2 etcd-S3 bucket provider (ADR-010 OQ10.1). Recommendation: Hetzner Object Storage in the same project so the L0 token covers it.
- Q3 Whether the Clan `wireguard` service accepts a peer that is not a Clan machine, or S4b needs a Clan-side change. Recommendation: read the service at S4b planning time; if a machine entry is required, register the gateway as a Clan machine with no deploy target and state that it is the only non-node exception to "nodes are not Clan machines".
- Q4 Snapshot retention bound. Recommendation: two per role, as D5 states.
- Q5 Whether `k8s-capi-render-<c>` compares the whole tree or per-object files. Recommendation: per-object files under `golden/capi/`, so a diff names the object.
- Q6 Whether S3's Handler B run is a check or an effect. Recommendation: an effect (`apps.k8s.k8s-mgmt-k3d`) with a recorded transcript in the S3 PR; it needs Docker and network and cannot be a check.
- Q7 Whether the SSH CA signs host keys on the node at boot or the operator signs offline (ADR-010 OQ10.2). Recommendation: on-node signing, discharged by `vm-k3s-capi-bootstrap` as written.
