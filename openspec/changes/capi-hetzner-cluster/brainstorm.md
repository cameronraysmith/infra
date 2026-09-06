<!--
Raw capture of the brainstorming step for this change.

Procedural note, recorded rather than elided: the interactive `superpowers:brainstorming`
dialogue was NOT run. This change was split out of `k3s-nixos-vm-tests` during that change's
revision 2 (2026-09-04, scope review) by a child session whose launch brief fixed the
architecture (deltas D-a..D-j of the revision-2 dispatch, recorded in ADR-009 and ADR-010).
What follows is the decision log the interactive skill would have produced. Answers fixed by
the brief are marked `[given]`; answers taken from the ADRs' source reading are marked
`[decided]`; answers that require the human are marked `[open]` and appear in design.md Open
Questions with recommendations.
-->

# Background

`k3s-nixos-vm-tests` proves the `<c>` core in hermetic VMs and stops at the VM boundary.
Its revision 1 carried stages S3–S5 (management handlers, CAPI rendering, a NoCloud bootstrap leaf, a Hetzner deployment, cloud variants) in the same change; revision 2 moved them here because they have a different modality (effects and a paid deployment, not sandbox checks), a different gate (explicit spend approval), and a different dependency direction (this change depends on that one and not the reverse).

Findings this change rests on, all from ADR-009 and ADR-010.
F1 cluster-api-k3s has an `airGapped` bootstrap path that expects the k3s binary on the image and runs `/opt/install.sh` (read in source).
F2 cluster-api-k3s is absent from clusterctl's built-in provider registry and is installed through a `clusterctl.yaml` override (read in source).
F3 CAPH boots servers from a named Hetzner snapshot and Hetzner Cloud has no image-upload API (read in CAPH's documentation; the hcloud API reference was not read).
F4 cluster-api-k3s reads a pre-existing `<cluster>-token` Secret and CA Secrets before generating its own, and `KThreesConfig.spec.files[].contentFrom.secret` resolves a management-cluster Secret into a cloud-init `write_files` entry (read in source).
F5 cluster-api-k3s and CAPH have not been run together by anyone found (inferred risk).
F6 NixOS can consume a NoCloud seed; that it boots a CAPI-shaped seed through the shim into `k3s.service` is inferred.

# Decision chain

## Q1 [given]: is this change planning-only?

Yes.
It writes the artifacts S3–S5 implement against and touches no cloud, no money, no workflow, no frozen prototype.

## Q2 [given]: what is the root set of the bootstrap?

L0: the repository, the Clan vars under `secrets/clusters/<c>/`, one Hetzner API token, and stibnite.
The former seed host (L1) is removed; no standing extra machine exists.
Evidence: ADR-010 D10.2, D10.3.

## Q3 [given]: which management-cluster handler first?

Handler B, k3d on stibnite's Colima Docker.
Handler A (the k3s closure as a NixOS QEMU VM, Darwin/HVF) is deferred behind the same contract: kubeconfig, three providers, identical CRs, `clusterctl move`.
Evidence: ADR-009 D9.4, D9.17.

## Q4 [decided]: how are the providers installed reproducibly?

`clusterctl init` with a Nix-rendered `clusterctl.yaml` whose `providers[]` point at store paths of the vendored release manifests at pinned versions, because F2; a KVM-free regulator asserts the override names exactly the three providers and that every image in the manifests is digest-pinned.
Evidence: ADR-009 F9.2, D9.4.

## Q5 [given]: how does cluster identity reach a node?

Only through `KThreesConfig.spec.files[].contentFrom.secret{name,key}` from Secrets in the management cluster; never inline, never baked into the snapshot; the server drops the Flux age-key Secret manifest into `/var/lib/rancher/k3s/server/manifests/`.
Public material may be baked in.
Evidence: ADR-010 D10.4, F10.2.

## Q6 [given]: what does a node's own identity count for?

Nothing outside the cluster: `Machine` name, host keys, Cilium WireGuard key, and `CiliumNode` are disposable; new nodes do not inherit old identities; nodes are not Clan machines.
The parent's `k8s-node-identity-free-<c>` regulator takes the rendered `capi-<c>` tree as an input once it exists.
Evidence: ADR-010 D10.1, D10.6.

## Q7 [given]: which image path?

O1: per-role NixOS snapshots from the fleet disko layout, label derived from the closure, published by an idempotent `platform.hetzner` effect that hides the throwaway server; GCP/AWS upload natively.
O2 (stock Debian plus cloud-init `kexec` reinstall) rejected: Hetzner-special, double boot, cache credentials on nodes, CR pins `debian-12`.
Evidence: ADR-009 D9.16.

## Q8 [decided]: how is the cloud-init bootstrap regulated before any node exists?

A KVM leaf `vm-k3s-capi-bootstrap` boots the `<c>-server` image from a NoCloud seed whose `user-data` is the rendered bootstrap template with `contentFrom.secret` entries resolved against the parent's fixtures; it asserts the shim path, the T0 landing places, fresh host keys per boot under the fixture SSH CA, and no CA private key on disk.
The leaf regulates the node's consumption of the data, not the provider's production of it; the provider's output is observed in S3 against Handler B.
Evidence: ADR-009 D9.9, R9.d; ADR-010 R10.3, R10.4, R10.e.

## Q9 [given]: how does an operator reach the cluster after the first deploy?

The CAPH load-balancer endpoint for the API server and node public IPs under the T0 SSH CA.
The administrative overlay is S4b: a Clan `wireguard` instance controlled by the existing primary VPS, one gateway workload per cluster with a T0 peer key, stibnite admin-only; nodes never join any Clan overlay.
Evidence: ADR-009 D9.15.

## Q10 [given]: which machines take part in one end-to-end deployment?

M1–M6 of ADR-010 D10.5 and the CAPH load balancer, which is not a machine; Terranix, nixos-anywhere, and Clan install never touch M5 or M6.

## Q11 [given]: when may S4 start?

On the owner's explicit written approval recorded in the S4 PR; never on silence, never on a green S3.

## Q12 [decided]: how is disaster recovery done?

k3s `--etcd-s3` snapshots with T0 credentials plus L0: rebuild M3, restore on a fresh M5, re-pivot; a rehearsal is separately approved after S4.
Evidence: ADR-010 D10.7, R10.g.

## Q13 [decided]: what happens to S5?

Its requirements stay in `capi-cluster-rendering` marked `[S5, deferred]` with no scheduled task; the `platform` sum is total today (`kubevirt` throws a distinct error), `gcp`/`aws` render-only when scheduled.
Evidence: ADR-009 D9.10, D9.13.

## Q14 [open]: ambiguities

Listed as Q1–Q7 in design.md Open Questions with recommendations; Q1 (S4 spend) is never adopted by silence.

# Design trade-offs recorded

- Handler B puts a Docker dependency on stibnite, the one non-Nix runtime in the bootstrap; accepted because M3 is bootstrap-only and deleted after the pivot, and Handler A removes it when scheduled.
- Resolving `contentFrom.secret` inside the VM leaf makes the leaf's oracle the provider's fixture text rather than the provider itself; accepted because the provider needs a management cluster and network, which the sandbox lacks, and S3 observes the provider's real output once against Handler B.
- Deriving the snapshot label from the closure hash means every rebuild that changes the closure republishes a snapshot; accepted because that is the property that makes a flake bump roll nodes.
- Delivering the root `OCIRepository` digest through `files[]` rolls control-plane machines on a configuration bump; carried from revision 1 unchanged.
- Boot-time host-key signing exposes the SSH CA private key transiently on each node; accepted pending R10.e's discharge, with offline per-`Machine` certificates as the recorded alternative.
- Deferring the overlay leaves first-deploy administration on public IPs under an SSH CA; accepted because the overlay's gateway shape is itself unverified and should not gate the first node.
