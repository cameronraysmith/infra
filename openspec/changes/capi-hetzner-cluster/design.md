## Context

This change is the second half of the plan `openspec/changes/k3s-nixos-vm-tests/` begins.
That change proves the core of `kubernetes/clusters/cryolite` inside NixOS VMs (S0–S2); this one takes the same node closure to Hetzner under Cluster API (S3, S4), adds the administrative overlay afterwards (S4b), and holds the render-only cloud variants until a second cloud is real (S5).
The decisions it implements are recorded in ADR-009 (Cluster API, cluster-api-k3s, CAPH, the `platform` sum, image path O1, handler B, the deferred overlay) and ADR-010 (identity tiers T0/T1/T2, bootstrap levels L0–L3, machines M1–M6, `contentFrom.secret` delivery, no seed host); this document does not restate them, it fixes how the S3–S5 artifacts satisfy them and where each artifact sits.
Scope inherits the parent's constraints: `local` and `local-k3d` are frozen prototypes, nothing here edits them, and the only edits to existing files are additive.
The charter-v1 review (ADR-009 D9.18–D9.21, ADR-010 D10.8) names the cluster `cryolite`, releases Hetzner spend one flake revision at a time behind `VANIXIETS_HETZNER_SPEND_APPROVED`, makes the etcd-S3 bucket fleet-level Terranix infrastructure, and narrows S5 to GCP; the programme-level view is `docs/notes/development/kubernetes/cryolite-charter.md`.

Three facts from the ADRs shape every decision below.
The L0 root set is the repository, the Clan vars under `secrets/clusters/cryolite/`, one Hetzner API token, and stibnite; no other machine may be required to reach a running cluster (ADR-010 D10.2).
Node identity is disposable: a node that CAPH replaces has a new `Machine` name, new host keys, and a new Cilium WireGuard key, and nothing in the repository, the inventory, or the management cluster may name the old one (ADR-010 D10.1, D10.6).
The Hetzner path needs a throwaway server to make a snapshot because Hetzner Cloud has no image-upload API (ADR-010 F10.5, read in CAPH's documentation); that quirk is hidden inside `platform.hetzner`'s effect and never surfaces in a CR (ADR-009 D9.16).

Boundaries named once for the whole document: Cluster API core, CAPH, cluster-api-k3s, k3d, clusterctl, hcloud, and cloud-init are vendored and consumed at pinned revisions from nixpkgs or from vendored release manifests; the `platform` sum, the `capi` modules, the bootstrap seam, the shim, the handler recipe, the snapshot effect, the goldens, and the regulators are first-party.
Source-versus-delivered: the `capi-cryolite` tree is source in `kubernetes/modules/capi/` and `kubernetes/clusters/cryolite/`, delivered as rendered YAML applied to the management cluster; the node image is source in `modules/machines/nixos/cryolite-{server,agent}.nix`, delivered as a Hetzner snapshot whose label is the only thing a CR sees.

## Goals / Non-Goals

Goals
- Fix the artifacts S3 builds so that a k3d management cluster on stibnite accepts the rendered `capi-cryolite` tree, the provider install is reproducible from the repository, and the cloud-init bootstrap path is regulated in a VM before any node exists.
- Fix the S4 procedure so that the L0 set suffices, every machine involved is one of M1–M6, T0 material reaches nodes only through `contentFrom.secret`, and the first-deploy administrative path needs no overlay.
- Fix the handler contract so Handler A can be added later without changing a CR.
- Specify S4b and S5 precisely enough that their later implementation is a matter of scheduling, not design.

Non-Goals
- Implementing anything; this change is planning-only.
- Any edit to the frozen prototypes, the k3d workflow, the flake inputs, the existing ZeroTier network, or any existing Clan machine.
- Handler A, `platform.gcp` beyond its deferred S5 golden, `platform.aws` and `platform.kubevirt` beyond their evaluation errors, ClusterMesh, and a second cluster.
- Any Hetzner Cloud API call whose flake revision the owner has not released through the spend gate (D10).

## Decisions

### D1: Handler B first; the contract is the kubeconfig, three providers, identical CRs, and `clusterctl move` [ADR-009 D9.4, D9.17]

Handler B is the effect `apps.k8s.mgmt-k3d`, run on stibnite (M1).
It creates a k3d cluster on stibnite's Colima Docker (M3), runs `clusterctl init --config <store path>/clusterctl.yaml --core cluster-api:<v> --bootstrap k3s:<v> --control-plane k3s:<v> --infrastructure hetzner:<v>` with the override's `providers[]` `url`s pointing at store paths of the vendored release manifests (`modules/kubernetes/capi/providers.nix`), applies the T0 `Secret`s and the rendered `capi-cryolite` tree, waits for the workload control plane to report `Ready`, runs `clusterctl move --to-kubeconfig cryolite`, and deletes the k3d cluster.
It is an effect and not a check because it needs Docker, network access to Hetzner and GHCR, and the Hetzner API token, none of which a sandboxed derivation has; its transcript in the S3 and S4 PRs is the evidence, and every step that reaches the Hetzner Cloud API is behind the gate of D10.
The contract a handler must satisfy is: a kubeconfig on stibnite, those three providers `Ready`, the `capi-cryolite` tree and the T0 `Secret`s applied unchanged, and `clusterctl move --to-kubeconfig cryolite` succeeding.
Handler A (`virtualisation.host.pkgs` QEMU VM of the k3s closure, Darwin/HVF) is deferred and must satisfy the same contract when added; nothing in the CRs or the Secrets names the handler.
Boundary: k3d, clusterctl, and the provider manifests are vendored; the override, the recipe, and the contract test are first-party.
This is the one place the design accepts a Docker dependency on stibnite; it is bootstrap-only (M3) and deleted after the pivot.

### D2: The `capi-cryolite` tree is rendered by easykubenix and regulated by a golden, Hetzner only until S5 [ADR-009 D9.1, D9.6, D9.10, D9.16]

`kubernetes/modules/capi/` renders the cloud-invariant core (`Cluster`, `KThreesControlPlane`, `KThreesConfigTemplate`, `MachineDeployment`, `MachineHealthCheck`); `kubernetes/modules/platform/hetzner.nix` alone renders `HetznerCluster` and the two `HCloudMachineTemplate`s and sets `imageName` from the per-role snapshot label; `kubernetes/clusters/cryolite/topology.nix` fixes `platform = hetzner`, one server, one agent.
`checks.k8s-capi-render-cryolite` diffs the render against `kubernetes/tests/cryolite/golden/capi/`.
`platform.kubevirt` and `platform.aws` are declared and `throw` a distinct evaluation error naming the variant (ADR-009 D9.20); `gcp` is declared, render-only, and the sole S5 variant.
`checks.k8s-capi-render-cryolite` compares per-object files under `golden/capi/`, so a diff names the object (Q5, accepted).
The hash chain the parent establishes (`clusters/cryolite → k8s-oci-cryolite → k3s-flux.nix → cryolite-server closure`) is extended here by two links: `→ snapshot label → capi-cryolite`, so one flake revision determines the CRs.
Boundary: the CRD schemas are vendored; the rendering modules and golden are first-party.

### D3: T0 material is delivered only through `contentFrom.secret`; the bootstrap template names no node [ADR-010 D10.4, D10.6; ADR-009 D9.7]

The rendered `KThreesControlPlane.spec.kthreesConfigSpec.files[]` and `KThreesConfigTemplate.spec.template.spec.files[]` carry every T0 item as `contentFrom.secret{name,key}` referencing a management-cluster `Secret` named `cryolite-<item>`: the token and CA drop-ins under `/etc/rancher/k3s/config.yaml.d/`, the etcd-S3 credentials (server), the Flux age-key `Secret` manifest under `/var/lib/rancher/k3s/server/manifests/` (server), the SSH CA private key for boot-time host-key signing (both, deleted after use), and the cosign and SSH CA public material (both; may equally be baked into the image).
Inline `content` is forbidden for T0 items; the `k8s-node-identity-free-cryolite` regulator of the parent takes the rendered `capi-cryolite` tree as an added input.
The root `OCIRepository` digest travels the same way (ADR-009 D9.7), so a configuration bump rolls control-plane machines; accepted in revision 1 (parent A1) and unchanged.
Boundary: `contentFrom.secret` is cluster-api-k3s' vendored mechanism (ADR-010 F10.2, read in source); which items travel and where they land is first-party.

### D4: One bootstrap seam in the production module; the NoCloud leaf regulates the cloud-init half [ADR-009 D9.8, D9.9; ADR-010 R10.3–R10.4]

`modules/nixos/k3s-server/capi-bootstrap.nix` adds `k3s-server.bootstrap = "clan-vars" | "cloud-init"`; `cloud-init` enables `services.cloud-init` with the NoCloud datasource only, installs the shim at `/opt/install.sh` (which ignores `INSTALL_K3S_*`, links the closure's `k3s`, and starts `k3s.service` reading `services.k3s.configPath`), and orders `k3s.service` after `cloud-final.service`.
`vm-k3s-capi-bootstrap` (`modules/checks/vm-k3s-capi-bootstrap.nix`) boots the `cryolite-server` image with a seed ISO whose `user-data` is the rendered bootstrap template with the `contentFrom.secret` entries resolved against the parent's test-only fixtures, exactly as the provider would resolve them; a second boot from a fresh disk and the same seed yields distinct host keys, both valid under the fixture SSH CA, and the CA private key is absent from the disk after `k3s.service` is active.
The leaf's `runcmd` text is taken from cluster-api-k3s' own fixture (`INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC='server' sh /opt/install.sh`) so the oracle is the provider's output, not the design's paraphrase (accepted in revision 1; the shim ignores `INSTALL_K3S_EXEC`).
Boundary: cloud-init and its NoCloud datasource are vendored; the seam, the shim, and the leaf are first-party.
Verified-versus-inferred: that NixOS boots from a CAPI-shaped NoCloud seed and the shim starts `k3s.service` is inferred (ADR-009 R9.d); this leaf is its discharge.

### D5: Image path O1 — per-role snapshots from the fleet disko layout, published by an idempotent effect [ADR-009 D9.16, D9.18]

`modules/kubernetes/hetzner/image.nix` builds `cryolite-server` and `cryolite-agent` as raw disk images with the same disko layout the fleet's `nixos-anywhere` installs use, on the Linux builder (M2); the image derivation is provider-neutral and pure, and only its transport is provider-specific.
`hetzner/snapshot.nix` and `apps.k8s.hetzner-snapshot-publish` are the Hetzner transport: create a throwaway server (M4) in rescue mode, write the image, snapshot it with `caph-image-name=<label>` where `<label>` is derived from the closure's store hash and role, delete the server, and exit 0 without acting when a snapshot with that label already exists.
The transport exists because Hetzner Cloud has no image-import endpoint; the GCP variant (S5) uploads the same image to GCS and calls `images.insert`, and never needs M4.
CAPH's only hook is create-from-image, so anything that reconfigures a node after boot is O2, and a just-in-time image build would put a builder in the loop of every unattended replacement; both are rejected.
Retention is two snapshots per role, the current and the previous revision, because `HCloudMachineTemplate.Spec` is immutable (ADR-009 R9.k, read in CAPH's webhook) and an in-flight rollout or a rollback references the previous image until every `Machine` has been replaced; a snapshot older than that is pruned once no template in the management cluster references it.
O2 (stock Debian plus a cloud-init `kexec` reinstall) is rejected: Hetzner-specific, a double boot per replacement, reachable cache credentials on every node, and a CR that pins `debian-12` rather than a closure.
Boundary: hcloud and the rescue system are vendored; the image derivation, the label function, and the effect are first-party.
Verified-versus-inferred: that a Nix-built image written in rescue mode and snapshotted satisfies CAPH's `imageName` contract is inferred (ADR-009 R9.e); S4's first node boot is its discharge.

### D6: The S4 procedure uses M1–M6 and nothing else, and is gated per flake revision [ADR-010 D10.2, D10.5; ADR-009 D9.19]

The runbook is fixed as the ordered list in `tasks.md` S4 and the machine table is ADR-010 D10.5: M1 stibnite (operator, bootstrap and admin), M2 Linux builder (bootstrap), M3 k3d management cluster on stibnite (bootstrap; deleted after pivot), M4 Hetzner throwaway server (bootstrap; deleted after snapshot), M5 Hetzner k3s server node and M6 agent node (cluster; created by CAPH, receive T0 via `contentFrom.secret`, host CAPI after pivot); the CAPH-created load balancer is the API endpoint and not a machine.
A review item before the first `hcloud` call confirms the L0 set is the complete prerequisite (ADR-010 R10.5), and the first server's `server-ca.crt` fingerprint is compared with the Clan vars value after boot (R10.6).
The gate is D10: Hetzner spend is approved in principle, and each flake revision that is about to bill is released by the operator setting `VANIXIETS_HETZNER_SPEND_APPROVED` to that revision in the shell that runs the effect; silence, a merged planning PR, or a green S3 releases nothing.
Terranix, nixos-anywhere, and `clan machines install` never touch M5 or M6 (ADR-010 D10.3); Terranix does provision the fleet-level etcd-S3 bucket (D8).

### D7: The administrative overlay is S4b, controlled by the primary VPS, with one gateway workload per cluster [ADR-009 D9.15]

A Clan `wireguard` instance is added to the inventory with the existing primary VPS as controller and stibnite as an admin-only peer; the cluster joins through one `Deployment` (replicas 1, `hostNetwork`, control-plane node selector) whose peer private key is a T0 item delivered as a `Secret`, advertising the Hetzner private network as its allowed subnet.
No k3s node is a Clan machine, joins ZeroTier, Yggdrasil, or the overlay directly, and the Cilium WireGuard dataplane is unchanged.
Until S4b, administrative access is the CAPH load-balancer endpoint and node public IPs under the T0 SSH CA.
Verified-versus-inferred: the gateway-as-peer shape is not in the Clan `wireguard` README (ADR-009 R9.g); S4b's first connection is its discharge, and the design accepts that S4b may need a Clan-side change to register a non-machine peer (open question Q3).

### D8: Disaster recovery is etcd-S3 plus L0 [ADR-010 D10.7]

`--etcd-s3` snapshots run from the server node with credentials from the T0 set; recovery rebuilds M3 from L0, restores the snapshot on a fresh M5, and re-pivots.
The bucket is fleet-level Terranix infrastructure that outlives the cluster (ADR-010 D10.8, ADR-009 D9.21): Hetzner Object Storage in the L0 token's project, declared through the `hcloud` Terraform provider if it exposes a bucket resource and otherwise through the `aws` or `minio` provider against Hetzner's S3 endpoint with an access key created once in the console; which provider applies is believed, not verified (ADR-009 R9.j), and S4.0 settles it.
The bucket bills Hetzner and is on the billing surface of D10.
A rehearsal is a separately approved action after S4 (ADR-010 R10.g, inferred).

### D10: Every Hetzner-billing action is listed, marked, and gated per flake revision [ADR-009 D9.19]

The billing surface of this change is: snapshot publication (tasks S4.1–S4.2: throwaway-server minutes for M4 and snapshot storage, once per revision per role); CAPH's creation of one load balancer and two servers (task S4.3: M5, M6, and their hourly running cost); the etcd-S3 bucket (storage and requests, from task S4.0 onward); and every later node cycle or rebuild (task S4.6 and after), which repeats S4.2 and replaces servers.
Three surfaces carry it: the charter's billing section, a `[bills Hetzner]` marker with a cost line on every S4 task in `tasks.md`, and the gate itself.
The gate: every `apps.k8s.*` effect that calls the Hetzner Cloud API (`hetzner-snapshot-publish`, `mgmt-k3d`, the S4 rollback and prune paths) reads `VANIXIETS_HETZNER_SPEND_APPROVED`, exits non-zero before its first API call with a message naming the expected flake revision when the variable is unset or differs from the revision it is about to act on, and otherwise records the released revision in its transcript.
The approval is a per-revision shell act; a later flake revision needs a new one.
Its regulator is `checks.k8s-spend-gate-cryolite` (KVM-free): it runs each effect's dry-run entry point with the variable unset and with a wrong revision and asserts refusal before any API call, and with the matching revision asserts the dry-run plan lists exactly the expected Hetzner actions and no more; the mutation is an effect edited to skip the read, which the check fails naming the effect.
The parent change reads nothing of this: no task of `k3s-nixos-vm-tests` bills anything.

### D11: S5 is GCP-only; `platform.aws` is declared and throws [ADR-009 D9.20]

The deferred S5 renders `platform.gcp` only, with a GCS bucket from the existing GCP Terranix as its etcd-S3 variant and native custom-image upload as its transport.
`platform.aws` stays a member of the typed sum so that a consumer selecting it is told by name that it is unimplemented, exactly as `platform.kubevirt` is; an AWS implementation is a later decision, not a deferred stage.

### D9: S5 is specified, marked, and unscheduled

The cross-variant core-equivalence golden, the ClusterMesh preconditions, the dataplane allowlist derivation, and the `gcp` variant keep their requirements in `capi-cluster-rendering` with an `[S5, deferred]` marker; `tasks.md` lists S5 as a stage with no unchecked task and a note that scheduling it is a separate decision.
The `aws` variant is no longer part of S5 (D11).

## Risks / Trade-offs

- R1 cluster-api-k3s and CAPH have not been run together by anyone found (ADR-009 R9.c). Mitigation: S3 applies both providers and the rendered `Cluster` to Handler B and observes the objects' conditions before any spend; S4 is the first real reconciliation and is gated.
- R2 The NoCloud leaf resolves `contentFrom.secret` itself, so it regulates the node's consumption of the bootstrap data, not the provider's production of it. Mitigation: the `runcmd` and `write_files` shapes are taken from cluster-api-k3s' fixtures and source (ADR-010 F10.2); the provider's own behaviour is observed in S3 by reading the `cryolite-server` bootstrap `Secret` the provider generates against Handler B.
- R3 Boot-time SSH CA signing exposes the CA private key on the node transiently (ADR-010 R10.e, OQ10.2). Mitigation: the leaf greps the disk after the unit completes; the alternative (offline per-`Machine` certificates) is recorded and can be adopted without changing the CRs' shape.
- R4 A stale snapshot label (image built from an unpushed revision) would let CAPH create nodes from an image whose closure the repository does not have. Mitigation: the label is derived from the closure hash, `k8s-capi-render-cryolite` fails when the rendered label differs from the built image's, and the publish effect refuses a label whose closure is not in the repository's current evaluation.
- R5 Handler B depends on Docker on stibnite, which is the one non-Nix runtime dependency of the bootstrap. Accepted because M3 is bootstrap-only and deleted; Handler A removes it when scheduled.
- R6 Pruning snapshots beyond the newest two per role can delete the image a rollback would need. Accepted with the bound stated and the reason in D5; rollback to an older revision re-publishes from the closure, which is reproducible.
- R7 The spend gate is an environment variable read by first-party effects, so an effect that forgets to read it bills without approval. Mitigation: `k8s-spend-gate-cryolite` exercises every Hetzner-calling effect's refusal path, and the effects share one gate function in `modules/apps/k8s/`.
- R8 The `hcloud` Terraform provider may lack an Object Storage resource (ADR-009 R9.j). Mitigation: the fallback provider path is fixed in D8 and costs one console action; S4.0 records which path applied.

## Migration Plan

S3 follows the parent's S2; S4 follows S3 and explicit approval; S4b follows S4; S5 is unscheduled.
Nothing is migrated: `cryolite` is new, the prototypes are frozen, and the fleet hosts keep Terranix, nixos-anywhere, and Clan install.
Rollback of S3 is deleting the `[add]` paths; rollback of S4 is `hcloud` deletion of M5, M6, the load balancer, and the snapshots, which the same effects can perform; rollback of S4b is removing the inventory instance and the gateway `Deployment`.

## Open Questions

The owner answered Q1–Q7 in the charter-v1 review; each is recorded with its resolution and the decision that carries it.
Questions that remain open for this change are carried in the charter (`docs/notes/development/kubernetes/cryolite-charter.md` §"Open questions").

- Q1 [resolved] S4 spend: approved in principle, released per flake revision through `VANIXIETS_HETZNER_SPEND_APPROVED` (D10); no blanket approval exists.
- Q2 [resolved] etcd-S3 bucket: fleet-level Terranix, Hetzner Object Storage, with the provider fallback and the believed-unverified `hcloud` provider gap recorded (D8).
- Q3 [accepted] Clan `wireguard` and a non-machine peer: verified at S4b planning time; if a machine entry is required, the gateway is registered as a Clan machine with no deploy target and named as the one non-node exception to "nodes are not Clan machines" (D7).
- Q4 [resolved] snapshot retention: two per role, current and previous, for the template-immutability reason in D5.
- Q5 [resolved] `k8s-capi-render-cryolite` compares per-object files under `golden/capi/` (D2).
- Q6 [resolved] Handler B is the effect `apps.k8s.mgmt-k3d` with a recorded transcript (D1).
- Q7 [resolved] the SSH CA signs host keys on the node at boot; `vm-k3s-capi-bootstrap` discharges ADR-010 R10.e (D4).
