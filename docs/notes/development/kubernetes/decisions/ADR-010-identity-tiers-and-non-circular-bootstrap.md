# ADR-010: Identity tiers and non-circular bootstrap

## Status

Proposed (2026-09-04, revision 2 of the k3s VM-test design; charter v1 the same day resolves OQ10.1 and OQ10.2 and adds D10.8).
Design only; no flake input, production module, Clan inventory, workflow, or cloud change lands with this record.
Implemented by S0 of `openspec/changes/k3s-nixos-vm-tests/` (the identity-free regulator) and by S3, S4, and S4b of `openspec/changes/capi-hetzner-cluster/` (delivery, deployment, admin overlay); S4 spends money, approved in principle and released per flake revision by ADR-009 D9.19.
Every decision governs the sibling cluster `kubernetes/clusters/cryolite` (ADR-007 D7.15, named in D7.20).
The programme-level view is `../cryolite-charter.md`.

## Context

ADR-009 makes the nodes of `cryolite` Cluster API objects that CAPH creates from a snapshot and deletes on every flake bump.
A node that is replaced on every revision cannot carry identity that anything else depends on: a Clan machine has a stable name, host key, ZeroTier identity, and vars directory, and every one of those would have to be rewritten each time CAPI rolled a `MachineDeployment`.
The fleet's existing identity model (one Clan machine per host, secrets generated per machine by Clan vars, deployed by push) therefore does not extend to the cluster's nodes, and the first revision of ADR-009 had already started to bend it: a seed host that was a Clan machine so that it could hold the join token, a Clan WireGuard instance whose members were the nodes, control-plane nodes as overlay controllers.

This record separates what must be stable from what may be disposable, names the machines that exist during one end-to-end deployment and when each of them stops existing, and fixes the bootstrap so that the only inputs are things the operator already has.
The rule that follows from the separation: a replacement node never inherits an old node's identity; node identity is made worthless instead of being preserved.

Paths under `~/ghq/` refer to the reference trees listed in ADR-007's appendix at the revisions recorded there.
Claims read in source are stated as facts; claims that were not executed are marked as inferred and listed in the open-risk table.

## Findings

### F10.1: cluster-api-k3s reads a pre-existing join token and CA set before generating its own

The bootstrap controller looks up the Secret `<cluster>-token` (key `value`) in the cluster's namespace and generates one only when the lookup returns not-found (`~/ghq/github.com/k3s-io/cluster-api-k3s/pkg/token/token.go:32-44`, `67-69`, `85-113`).
The CA set follows the Cluster API convention: `NewCertificatesForInitialControlPlane` names `<cluster>-ca` (server CA, written to `/var/lib/rancher/k3s/server/tls/server-ca.{crt,key}`), `<cluster>-cca` (client CA, `client-ca.{crt,key}`), and, for embedded etcd, `<cluster>-etcd` (`etcd/server-ca.{crt,key}`), and `LookupOrGenerate` uses whatever Secrets already exist under those names (`pkg/secret/certificates.go:48`, `66-92`, `180-187`; `pkg/secret/const.go:36-42`; `pkg/secret/secret.go:54-56`).
Creating those Secrets before the `Cluster` object is therefore the supported way to make the token and CAs cluster identity that survives the management cluster (D10.1); nothing in the CRs changes.

### F10.2: `KThreesConfig.spec.files[].contentFrom.secret` resolves a management-cluster Secret into a cloud-init `write_files` entry

`File.ContentFrom` is a `FileSource` whose only member is `Secret{Name, Key}`, documented as "a secret that should populate this file" (`~/ghq/github.com/k3s-io/cluster-api-k3s/bootstrap/api/v1beta2/kthreesconfig_types.go:243-287`).
The controller resolves each such file by reading `secret.Data[key]` from the named Secret in the `KThreesConfig`'s namespace, substitutes the content, and clears `ContentFrom` before rendering cloud-init (`bootstrap/controllers/kthreesconfig_controller.go:358-384`).
The bootstrap data itself is stored as a Secret owned by the `KThreesConfig` (`kthreesconfig_controller.go:554-586`) and reaches the node through the provider's user-data channel, so the material is never in the image and never in a CR.

### F10.3: k3s reads a drop-in directory beside its config file and can take its S3 credentials from a Secret

k3s merges `/etc/rancher/k3s/config.yaml` with every `*.yaml` in `/etc/rancher/k3s/config.yaml.d/` (`~/ghq/github.com/k3s-io/k3s/pkg/configfilearg/parser.go:102-123`, `227-237`), so a `files[]` entry can add server flags that cluster-api-k3s's `KThreesServerConfig` does not model without touching the generated `config.yaml`.
`--etcd-s3-config-secret` names a Secret in `kube-system` "used to configure S3, if etcd-s3 is enabled and no other etcd-s3 options are set" (`pkg/cli/cmds/server.go:510-514`), so the etcd-S3 credentials can travel as a Secret manifest in `/var/lib/rancher/k3s/server/manifests/` like the Flux age key rather than as flag values in a file.

### F10.4: Cilium's WireGuard key is generated per node and published on the Node object

With `encryption.type=wireguard`, each agent generates its own key and publishes the public half in the `network.cilium.io/wg-pub-key` Node annotation, which peers read to build their tunnel set (ADR-009 F9.7).
No key is configured, stored, or distributed by the operator, which is what makes it T1 material (D10.1): a replacement node gets a new key and a new annotation and the mesh reconverges.

### F10.5: Hetzner Cloud has no image-upload API

CAPH's node-image documentation states that "In Hetzner Cloud, it is not possible to upload your own images directly. However, a server can be created, configured, and then snapshotted" (`~/ghq/github.com/syself/cluster-api-provider-hetzner/docs/caph/02-topics/03-node-image.md:22`).
This is the reason machine M4 (D10.5) exists at all, and the reason it is a provider quirk hidden inside `platform.hetzner` (ADR-009 D9.16) rather than a property of the design.

## Decisions

### D10.1: three identity tiers [new, rev 2; D-c]

| Tier | Property | Members | Where it lives |
|---|---|---|---|
| T0 cluster identity | stable; generated once by Clan vars generators; sops-encrypted in the repository under `secrets/clusters/cryolite/` | k3s join token; pre-provisioned k3s CA set (server CA, client CA, etcd CA; F10.1); Flux SOPS age key (ADR-008 D8.9); Cosign signing key (ADR-008 D8.14); SSH CA; etcd-S3 credentials; later the admin-overlay gateway peer key (ADR-009 D9.15) | repository (encrypted); management-cluster Secrets during bootstrap; the workload cluster after pivot |
| T1 node identity | disposable; generated on the node or by the provider; never referenced outside the cluster | CAPI `Machine` name; SSH host keys, signed at boot by the T0 SSH CA; Cilium WireGuard key (F10.4); `CiliumNode` identity | the node only |
| T2 cluster endpoints | stable; owned by the platform | kube-apiserver behind CAPH's `controlPlaneLoadBalancer` / `controlPlaneEndpoint`; later one admin-overlay gateway per cluster (ADR-009 D9.15) | provider objects and the cluster's Services |

T0 is the set of things whose loss would make the cluster unrecoverable or unreachable from the repository; everything in it has a Clan vars generator and a sops file, and nothing in it names a node.
T1 is everything a node makes for itself; the rule is that a new node never inherits an old node's T1 material, and nothing outside the cluster may store or reference it.
T2 is what clients connect to; it is stable because it is not attached to a node.
Nodes are not Clan machines: they have no entry in the Clan inventory, no vars directory, and no overlay membership.

Public halves of T0 material (the SSH CA public key, authorized user keys, the Cosign public key) may be baked into the snapshot; private halves may not, so the snapshot is secret-free (D10.4).

### D10.2: four bootstrap levels; L0 is a regulator target [new, rev 2; D-e]

| Level | What exists | Lifetime |
|---|---|---|
| L0 root set | the repository; Clan vars and sops keys; a Hetzner API token; stibnite | permanent; the only inputs |
| L1 | nothing (the seed host of ADR-009 revision 1 is removed) | — |
| L2 management cluster | k3d on stibnite through Colima (handler B, ADR-009 D9.17): `clusterctl init` with CAPI core, CAPH, and cluster-api-k3s through a `clusterctl.yaml` override (ADR-009 F9.2); T0 Secrets and the `capi-cryolite` CRs applied | bootstrap only; deleted after pivot |
| L3 workload cluster | `cryolite`: two Hetzner nodes created by CAPH; Flux reconciles from the digest in the closure (ADR-008 D8.4); after `clusterctl move` from L2 it hosts its own CAPI providers | permanent |

Nothing outside L0 may be required to reach L3, and L0 must not contain a running machine other than the operator's workstation; this is a stated invariant of the runbook and a review item on the S4 PR, not something a check can assert.
There is no standing extra Hetzner machine (L1 is empty), which removes the seed host's Clan entry, its ZeroTier membership, its Terranix declaration, and its monthly cost.
Disaster recovery is D10.7.

### D10.3: the seed host is removed; Terranix, nixos-anywhere, and Clan install never touch a k3s node [new, rev 2; D-e; supersedes ADR-009 D9.1's seed-host clause]

CAPH can manage only servers it created (ADR-009 F9.3); a node installed by nixos-anywhere or `clan machines install` would be a permanent non-CAPI node, and Terranix would have to know a per-node identity to declare it.
Terranix therefore stays what it is for the fleet hosts (magnetite, cinnabar), which are a different machine class, and is unrelated to the cluster.
Revision 1 of ADR-009 (D9.1) kept Terranix "to provision the seed/management host"; with L1 empty there is nothing for it to provision.

### D10.4: T0 material reaches a node at first boot through `contentFrom.secret`; snapshots are secret-free and per role [new, rev 2; D-c]

Every T0 item a node needs is a `KThreesConfig.spec.files[]` entry with `contentFrom.secret{name,key}` (F10.2) naming a Secret in the management cluster's namespace for `cryolite`, created from the sops-decrypted Clan vars by the L2 apply step:

- the join token and the CA set are not files at all; they are the `<cluster>-token`, `<cluster>-ca`, `<cluster>-cca`, and `<cluster>-etcd` Secrets cluster-api-k3s reads before generating its own (F10.1);
- server nodes receive the Flux `flux-system/sops-age` Secret manifest at `/var/lib/rancher/k3s/server/manifests/flux-sops-age.yaml`, beside the root `OCIRepository` of ADR-009 D9.7;
- server nodes receive the etcd-S3 configuration Secret manifest in the same directory and `etcd-s3: true` plus `etcd-s3-config-secret` in a `config.yaml.d/` drop-in (F10.3);
- every node receives the SSH host-certificate signing request's answer: the T0 SSH CA signs host keys at boot through a unit in the closure that reads the CA private key from a `files[]` entry, signs the freshly generated host key, and deletes the CA key from disk. This is the one T0 private item that touches every node and it is present only until the unit completes.

The snapshot contains the k3s binary, the shim (ADR-009 D9.2), the Flux install manifest (ADR-008 D8.3), the preloaded images, and the public halves of T0; nothing else.
There is one snapshot per role (`cryolite-server`, `cryolite-agent`; ADR-009 D9.16) because `services.k3s.role` is fixed at evaluation (ADR-009 F9.5), and the two differ in nothing that is identity.

### D10.5: machines in one end-to-end deployment [new, rev 2; D-e]

| Machine | What it is | Role in the deploy | Lifetime |
|---|---|---|---|
| M1 stibnite (`aarch64-darwin`) | operator workstation | flake evaluation, Clan vars T0 generation, management-cluster host, snapshot upload, `clusterctl init` / `apply` / `move`; retains `kubectl`, `flux`, `ssh` afterwards | bootstrap and admin |
| M2 Linux builder | the existing magnetite builder or nix-darwin `linux-builder` | builds the `x86_64-linux` node images | bootstrap only |
| M3 management cluster | a k3d process on stibnite (Colima), handler B | runs CAPI, CAPH, cluster-api-k3s until pivot | bootstrap only; deleted after `clusterctl move` |
| M4 Hetzner throwaway server | a server booted into rescue mode | the node image is `dd`'d onto its disk; a snapshot is taken with label `caph-image-name=<rev>`; the server is deleted (`hcloud-upload-image` pattern, F10.5) | bootstrap only; exists for minutes |
| M5 Hetzner k3s server node | created by CAPH from the server snapshot | booted by cluster-api-k3s air-gapped cloud-init; receives T0 through `contentFrom.secret`; after pivot also hosts the CAPI providers | cluster |
| M6 Hetzner k3s agent node | created by CAPH from the agent snapshot | booted by cluster-api-k3s air-gapped cloud-init; receives T0 through `contentFrom.secret` | cluster |
| not a machine | the CAPH-created Hetzner load balancer | the kube-apiserver endpoint (T2) | cluster |

M4 is run by the `apps.k8s.hetzner-snapshot-publish` effect and is never visible to the CRs; GCP and AWS variants (S5) have no M4.
After pivot the set of running machines is M1 (idle), M5, M6, and the load balancer; a flake bump replaces M5 and M6 with successors that share none of their T1 material.

### D10.6: the `k8s-node-identity-free` regulator [new, rev 2; D-c]

`checks.<system>.k8s-node-identity-free-cryolite` (`modules/kubernetes/identity.nix`, ADR-007 D7.17) evaluates the rendered `capi-cryolite` CRs, the rendered Flux artifact, the Clan inventory, and the sops file index under `secrets/clusters/cryolite/`, and fails if any of them names a node or a node key: a `Machine` name pattern, a node hostname, an SSH host key or its fingerprint, a Cilium WireGuard public key, or a `CiliumNode` name.
It is KVM-free (T1) and runs from S0 with the CRs stubbed to what `kubernetes/clusters/cryolite/` renders at that stage; from S3 it consumes the real render.
Mutation evidence: a fixture that adds a `nodeName` field to a Flux `Kustomization` patch, and one that adds a Clan inventory machine named like a `MachineDeployment` replica, must both fail the leaf.
The node-side half of the rule (a replacement node does not reuse a predecessor's host key) is a `vm-k3s-capi-bootstrap` assertion in S3: the leaf boots the node twice from the same seed and asserts the two host-key fingerprints differ while both verify against the T0 SSH CA.

### D10.7: disaster recovery is etcd-S3 plus L0 [new, rev 2; D-e]

k3s writes etcd snapshots to S3 with the T0 credentials (F10.3).
Recovery from total loss of M5 and M6 is: from L0, rebuild L2 (D10.2), apply the same T0 Secrets and CRs, let CAPH create new nodes, restore the etcd snapshot on the first server (`k3s server --cluster-reset --cluster-reset-restore-path`), and `clusterctl move` again.
Because the token and CAs are T0, the restored cluster is the same cluster to every client and to Flux; because node identity is T1, no client or peer holds anything about the lost nodes that the new ones must reproduce.
The S3 bucket and its credentials are the one piece of state outside the repository that recovery depends on, and they are listed in L0's Clan vars.

### D10.8: the etcd-S3 bucket is fleet-level Terranix infrastructure [new, charter v1; resolves OQ10.1]

The bucket outlives the cluster by construction: it is provisioned by Terranix beside the fleet hosts (magnetite, cinnabar), not by any `apps.k8s.*` effect and not by a Kubernetes object, so deleting `cryolite` or losing M5 and M6 leaves the snapshots in place for D10.7.
The first variant is Hetzner Object Storage in the project the L0 token administers; the GCP variant is a GCS bucket from the existing GCP Terranix.
It is believed, not verified, that the `hcloud` Terraform provider exposes no Object Storage bucket resource (ADR-009 R9.j); if S4 confirms that, the bucket is declared through the `aws` or `minio` Terraform provider against Hetzner's S3 endpoint, and the access key is created once in the Hetzner console and enters T0 through Clan vars.
The bucket bills the Hetzner project and is on the billing surface of ADR-009 D9.19.
Terranix's involvement stops at the bucket and its key; D10.3 stands.

## Requirements carried into the OpenSpec delta specs

| Code | Requirement | Regulator | Tier |
|---|---|---|---|
| R10.1 | no CAPI CR, Flux manifest, Clan inventory entry, or Secret index names a node or node key | `k8s-node-identity-free-cryolite` | T1 |
| R10.2 | the per-role snapshot closure contains no T0 private material | a T1 leaf that greps the closure for the sops file paths and key fingerprints of `secrets/clusters/cryolite/` | T1 |
| R10.3 | a NoCloud-seeded node consumes `contentFrom.secret`-shaped `write_files` and the server drops the Flux age-key Secret into `server/manifests/` | `vm-k3s-capi-bootstrap` | T2 |
| R10.4 | two boots from one seed yield distinct host keys, both valid under the T0 SSH CA | `vm-k3s-capi-bootstrap` | T2 |
| R10.5 | the L0 set suffices to reach L3 with no standing extra machine | S4 runbook review item (not a check) | E |
| R10.6 | the pre-provisioned `<cluster>-token` and CA Secrets are the ones the first server boots with | S4 runbook: fingerprint of `/var/lib/rancher/k3s/server/tls/server-ca.crt` equals the Clan vars value | E |

## Verified versus inferred

| Code | Claim | Status | Discharging regulator |
|---|---|---|---|
| R10.a | cluster-api-k3s uses a pre-existing `<cluster>-token` Secret and pre-existing CA Secrets | read in source (F10.1) | S3 handler-B apply with pre-created Secrets; S4 R10.6 |
| R10.b | `contentFrom.secret` resolves into cloud-init `write_files` | read in source (F10.2) | `vm-k3s-capi-bootstrap` renders the same shape (R10.3) |
| R10.c | k3s merges `config.yaml.d/*.yaml` and accepts `--etcd-s3-config-secret` | read in source (F10.3) | `vm-k3s-capi-bootstrap` asserts the merged flag set |
| R10.d | Hetzner Cloud has no image-upload API | read in CAPH docs (F10.5) | none needed; S4's first snapshot publish is the behavioral check |
| R10.e | an SSH host key signed at boot by a CA delivered through `files[]`, with the CA key deleted afterwards, leaves no recoverable private CA material on the node | inferred; depends on the unit ordering and on cloud-init not persisting `write_files` content elsewhere | `vm-k3s-capi-bootstrap` greps the booted disk for the CA key after the unit completes |
| R10.f | `clusterctl move` carries the pre-provisioned T0 Secrets with the `Cluster` | inferred from Cluster API's move semantics (Secrets labelled with the cluster name move with it; the token Secret carries `cluster.x-k8s.io/cluster-name`, `token.go:96-98`) | S4 runbook: Secrets present in L3 after move |
| R10.g | etcd restore plus re-pivot yields a cluster Flux treats as unchanged | inferred | a DR rehearsal after S4, separately approved |
| R10.h | the `hcloud` Terraform provider has no Object Storage bucket resource | believed; not read (ADR-009 R9.j) | S4 Terranix task selects the provider by inspection of the pinned provider's resource index |

## Provenance

| Decision | Source |
|---|---|
| D10.1, D10.4, D10.6 | revision-2 dispatch §D-c |
| D10.2, D10.3, D10.5, D10.7 | revision-2 dispatch §D-e |
| D10.8 | charter-v1 answers §Q3; ADR-009 D9.21 records the same decision from the Terranix side |
| F10.1–F10.3 | read in `~/ghq/github.com/k3s-io/cluster-api-k3s` at `ecba04b` and `~/ghq/github.com/k3s-io/k3s` at `a305766` during this revision |
| F10.5 | read in `~/ghq/github.com/syself/cluster-api-provider-hetzner` at `b5e7742` during this revision |

## Open questions

- OQ10.1 Resolved by D10.8: fleet-level Terranix-provisioned Hetzner Object Storage, with the provider fallback recorded there; the residual question of which Terraform provider declares the bucket is carried in the charter (`../cryolite-charter.md` §"Open questions").
- OQ10.2 Resolved: the SSH CA signs host keys on the node at boot (D10.4), and R10.e is discharged by `vm-k3s-capi-bootstrap` in S3.

## Related

- ADR-007: scope (D7.15), module tree (D7.17), stage plan (D7.18); `k8s-node-identity-free` is an S0 leaf there.
- ADR-008: the Flux SOPS age key (D8.9) and Cosign key (D8.14) are T0 members.
- ADR-009: CAPI, the air-gapped shim (D9.2), `files[]` delivery (D9.7), the image path (D9.16, D9.18), the overlay whose gateway key is T0 (D9.15), handler B (D9.17), the spend gate (D9.19), and the Terranix side of the etcd-S3 bucket (D9.21).
- `../cryolite-charter.md`: the programme charter; carries the M1–M6 and L0–L3 tables forward and the open questions this record leaves.
- `openspec/changes/k3s-nixos-vm-tests/`: S0 carries R10.1 and R10.2.
- `openspec/changes/capi-hetzner-cluster/`: S3 carries R10.3 and R10.4; S4 carries R10.5 and R10.6.
