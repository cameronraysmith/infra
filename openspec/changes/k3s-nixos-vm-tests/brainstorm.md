<!--
Raw capture of the brainstorming step for this change.

Procedural note, recorded rather than elided: the interactive `superpowers:brainstorming`
dialogue was NOT run. This change was authored by a child session whose launch brief fixed
the questions to answer (Q1-Q7 of ADR-007) and instructed it to stop after publishing the
design as a draft PR. What follows is the decision log the interactive skill would have
produced. Answers fixed by the brief are marked `[given]`; answers taken from research
evidence are marked `[decided]`, with the evidence in ADR-007 cited by section; answers
that require the human are marked `[open]` and appear as D-codes in the ADR and as
Open Questions in design.md.

Second pass (2026-09-04): the human resolved the open questions and the wider design space
in a design review recorded in four notes (k3s-nixkube-decisions, k8s-architecture-current-
vs-nixified, oci-caph-timoni-decisions, cross-cloud-node-management). Answers taken from
those notes are marked `[reviewed]`; the original Q1-Q10 entries are kept as history and
annotated where superseded.
-->

# Background

The Kubernetes platform is verified by one GitHub Actions workflow, `.github/workflows/test-cluster.yaml`, which runs a k3d cluster in Docker on `ubuntu-latest` and drives `modules/apps/cluster/k3d-integration-ci.sh` through seven phases ending in a Chainsaw suite.
It was written when no KVM host was available for NixOS VM tests.
PR #2954 has since landed the pattern for full QEMU/KVM regulators in this repository (`modules/checks/vm-nixos-base.nix`) and made `just test-integration` build every `checks.<system>.vm-*` leaf.

Research for this change (ADR-007, `docs/notes/development/kubernetes/decisions/ADR-007-nixos-vm-tests-for-k3s.md`) established five findings that shape every decision below.
F1: `flake.modules.nixos.k3s-server` is imported by no machine and no check, and its `virtualisation.containerd.settings` block is inert because `virtualisation.containerd.enable` is never set.
F2: the k3d run keeps kube-proxy and ServiceLB and disables Cilium's kube-proxy replacement, so it regulates an envelope that differs from the production module's exactly where Cilium's datapath and LoadBalancer address assignment are concerned; Gateway `Programmed=True` depends on an address that ServiceLB supplies in k3d and nothing supplies in production.
F3: `nixosLib.runTest` requires `kvm nixos-test`; the buildbot worker has no KVM; GitHub documents nested virtualization on hosted runners as unsupported.
F4: the Nix sandbox has no network, so every OCI image is a build input; the k3s core bundle is 236 MiB compressed and the platform images are bounded at 1.5–2.5 GiB.
F5: manifest rendering already has T1 build checks.

# Decision chain

## Q1 [given]: is this change planning-only?

Yes.
No VM leaf, no check, no workflow edit, no k3d deletion lands here.
The change writes the artifacts that four later implementation stages are applied against.

## Q2 [decided]: which tier does each current assertion belong to?

Three tiers plus a residual class: T1 pure eval/build, T2 NixOS VM substrate, T3 live platform stack in a NixOS VM, K residual k3d.
Every current Chainsaw assertion is T3 because every one of them observes a live controller.
Every property the production k3s module claims about the node — flags, kernel modules, sysctls, firewall, CIDRs, absence of flannel and kube-proxy — is T1 for its evaluated form and T2 for its effective form.
Manifest rendering and the `file:///manifests` grep are T1.
Nothing is K once the six blockers in ADR-007 Q4 are given their hermetic substitutes.
Evidence: ADR-007 Q1 tables.

## Q3 [decided]: how does the single-node leaf get a CNI?

O-a: no CNI.
The single-node leaf regulates the substrate only and asserts the node is `NotReady` for exactly the missing-CNI reason with CoreDNS `Pending`.
O-b (ship Cilium via `autoDeployCharts` with preloaded images) conflates two envelopes in the cheapest VM leaf and pulls a GiB-class image closure into it; it is deferred to the T3 leaf where those images are needed anyway.
O-c (fetch at runtime) is impossible in the sandbox.
Evidence: ADR-007 Q2.

## Q4 [decided]: how many platform leaves?

O-1: one `vm-k3s-platform` leaf.
The Chainsaw steps form a dependency chain (Certificates need the ClusterIssuer, which needs step-ca and the Gateway solver, which needs Cilium and an LB address; ArgoCD manages all of them), so O-2's slice leaves would each preload Cilium and rebuild the same readiness scaffolding.
O-2 is the fallback if O-1's measured wall time exceeds 15 minutes, splitting `vm-k3s-cilium` first.
O-3 (platform stays on k3d permanently) is rejected because each blocker has a hermetic substitute; the only unmovable property is a property of k3d itself.
Evidence: ADR-007 Q4.

## Q5 [decided]: how is the multi-node token delivered?

Store-path token (`pkgs.writeText`) as nixpkgs does, until a production `clan.core.vars` generator exists.
Writing a `share = true` generator inside the test before production has one would invent production shape in a test.
The switch to the generator is a task gated on the human's answer to D-S2.
Evidence: ADR-007 Q3.

## Q6 [decided]: what replaces `SOPS_AGE_KEY`?

A committed test-only age keypair, installed at activation, modeled on clan-core's `lib/test/age.nix` and sops-nix's `checks/nixos-test.nix`.
The rendered environment for the VM encrypts `SopsSecret` payloads to the test public key.
What this does not cover is stated in the spec: production key provisioning, recipients, rotation, GitHub Secret wiring.
Evidence: ADR-007 Q5.

## Q7 [decided]: where does Chainsaw run?

In the guest.
`pkgs.chainsaw` exists in the locked nixpkgs; the default cluster loads through client-go's default rules so `KUBECONFIG=/etc/rancher/k3s/k3s.yaml chainsaw test <store path>` needs no flag; the `--cluster` and `--kube-*` flags exist for the alternative.
Running from the test driver via `forward_port` adds a host-side Chainsaw and a TLS SAN concern for no gain.
Evidence: ADR-007 Q7.

## Q8 [decided]: how does the CI runner question get settled?

By a probe job, not by assumption.
Stage 4 begins with a manually dispatched job on `ubuntu-latest` that grants `/dev/kvm` via the udev rule GitHub's own changelog shows, checks the device, and builds `vm-k3s-substrate` with `--option system-features 'kvm nixos-test benchmark big-parallel'`.
Only a repeatedly passing probe promotes the VM leaves into the workflow; a failing probe leaves them developer-host regulators run through `just test-integration` (D-C1 is moot in rev 2: the k3d job is untouched either way).
Evidence: ADR-007 F3, Q6.

## Q9 [decided, superseded by Q11, then by Q20]: is a VM-specific nixidy environment required?

Originally yes, pending D-P2.
Superseded (rev 1): nixidy is retired; the VM variant is a `target` of the easykubenix cluster module (design D9).
Superseded by D-a (rev 2): nixidy is not retired; `kubernetes/nixidy/local-k3d` is frozen and untouched, and the VM leaf renders the new sibling cluster `cryolite` with easykubenix, so no nixidy environment of any kind is added.

## Q10 [resolved]: which decisions must the human take before stage 1?

All seven were answered in the design review: D-S1 yes (`base` is imported); D-S2 not now (store-path token; production paths are named by the bootstrap seam, ADR-009 D9.8); D-P1 Cilium LB-IPAM; D-P2 superseded by easykubenix-only; D-C1 developer-KVM-only until a runner exists; D-C2 `local-k3d/` survives as management handler B; D-M1 re-scoped to delete the dead block and use `containerdConfigTemplate` only if NRI proves disabled.
Revision 2: D-C1 and D-C2 are moot (Superseded by D-a (rev 2): nothing about `local-k3d` is deleted or migrated by this change, so the fallback-runner and keep-or-delete questions have no object); D-P2 stays superseded; D-S1, D-S2, D-P1, D-M1 are kept.

## Q11 [reviewed]: which reconciler and which manifest framework?

Flux consuming a digest-pinned OCI artifact, bootstrapped from `services.k3s.manifests`; easykubenix is the only rendering framework for `cryolite`.
ArgoCD needs a git source and cannot pin by digest; Flux installs offline from `pkgs.fluxcd` and verifies signatures with a key from the closure.
Revision 1 continued "nixidy and the Phase-3/4 adoption split are retired, ADR-006 is reversed"; that clause is Superseded by D-a (rev 2): the retirements and the ADR-006 reversal are Future Work for a later, separately authorized feedback change, and ArgoCD keeps `local-k3d` while Flux takes `cryolite` (ADR-008 D8.15).
Evidence: ADR-008 F8.1, D8.1, D8.10, D8.15.

## Q12 [reviewed]: how are images and configuration packaged?

By consumer: `nix-snapshotter.buildImage` for Nix-native workloads on `nix`-snapshotter nodes; nix2container for portable images; a Nix derivation emitting an OCI image layout for Flux configuration, digest known in the sandbox, pushed by an `apps` effect that asserts digest equality.
Tags are the flake revision and are aliases only; every consumer uses a digest or a store path.
Evidence: ADR-008 F8.2, D8.4, D8.5, D8.7.

## Q13 [reviewed]: how does the VM leaf obtain the Flux artifact without a network?

An in-guest registry seeded from the store-resident OCI layout, as nix-snapshotter's push-and-pull test does; images are preloaded through `services.k3s.images` and never traverse the registry.
Evidence: ADR-008 F8.3, D8.6.

## Q14 [reviewed]: which container snapshotter?

k3s's embedded `--snapshotter nix` (nix-snapshotter is vendored in k3s); the production module gains `k3s-server.snapshotter` defaulting to `"nix"`; nixkube is not a flake input; runtime `flakeRef`/`nixExpr` are forbidden and rejected by the S0 purity leaf.
NRI behaviour is asserted in the substrate leaf, not assumed.
Evidence: ADR-007 F6, D7.1, D7.2, D7.8.

## Q15 [reviewed]: who manages nodes?

Cluster API with cluster-api-k3s and CAPH from day one; the interim Terranix-as-node-manager position is reversed.
Remote nodes boot a NixOS Hetzner snapshot labelled by flake revision in `airGapped` mode; a Nix-written `/opt/install.sh` shim starts `k3s.service` from `services.k3s.configPath`; no kubeadm.
The management cluster is a capability with two handlers (NixOS QEMU VM; k3d via ctlptl) behind one contract.
Revision 1 continued "Terranix is only the seed/management-host provisioner"; Superseded by D-e (rev 2, ADR-010 D10.3): there is no seed host, Terranix is unrelated to the cluster, and the management cluster is a throwaway k3d process on stibnite (handler B first, handler A deferred, ADR-009 D9.17).
Everything in this question past the node-image and shim facts is now owned by `openspec/changes/capi-hetzner-cluster/`.
Evidence: ADR-009 F9.1–F9.4, D9.1–D9.7, D9.16, D9.17; ADR-010 D10.3.

## Q16 [reviewed]: how is multi-cloud declared?

One easykubenix cluster module: cloud-invariant core plus a `platform` sum over `hetzner | gcp | aws | kubevirt` that alone owns `*Cluster`, `*MachineTemplate`, node image, CCM, optional CSI; unhandled provider is an evaluation error; a per-cloud CCM is mandatory because cluster-api-k3s defaults `cloud-provider=external`.
Kept in rev 2; specified by `capi-hetzner-cluster` (`capi-cluster-rendering`), with `gcp` deferred to S5 and `aws` declared-but-throwing since charter v1 (ADR-009 D9.20).
Evidence: ADR-009 D9.10, D9.11.

## Q17 [reviewed]: how are the networks arranged?

ZeroTier untouched and k8s nodes never join it; Cilium WireGuard is the dataplane directly between node IPs; cross-cloud is ClusterMesh between per-cloud clusters with disjoint PodCIDRs and never stretched etcd; no Crossplane, no Anthos.
Revision 1 continued "a dedicated Clan `wireguard` instance is the admin plane (API server, SSH, deploys, ClusterMesh API reachability, node join)" with control-plane nodes as controllers; Superseded by D-d (rev 2, ADR-009 D9.15): nodes join no Clan overlay because every Clan overlay is per-machine identity and node identity is disposable (ADR-010 T1); the admin overlay, when added in S4b, is one gateway workload per cluster peering with the existing primary VPS as controller; first-deploy access is the CAPH load balancer plus node public IPs under the SSH CA.
Evidence: ADR-009 F9.6, F9.7, D9.12–D9.15.

## Q18 [reviewed]: how many stages?

Six in rev 1: S0 purity/provenance (KVM-free), S1 substrate and snapshotter leaves, S2 `vm-k3s-platform`, S3 management handlers and the NoCloud-seeded bootstrap leaf, S4 two Hetzner nodes on explicit spend approval, S5 gcp/aws render-only variants.
Revision 2 (D-i, D-j): seven, split across two changes.
This change owns S0 (adds `k8s-node-identity-free-cryolite`), S1, and S2 (rescoped to the two-guest `cryolite` core, D-b).
`openspec/changes/capi-hetzner-cluster/` owns S3 (handler B, provider rendering, `k8s-capi-render`, `vm-k3s-capi-bootstrap`, T0 delivery), S4 (first paid action, explicit gate), S4b (admin overlay), and the deferred S5.
Evidence: ADR-007 Q6 and the revision-2 stage table.

## Q19 [resolved, charter v1]: ambiguities found while folding the review in

Revision 1 listed A1–A9; A1–A3, A5–A7, A9 were accepted by the owner and are recorded in design.md Decisions or moved to the sibling change.
The charter-v1 review answered the rest: A4 (`services.dockerRegistry` in the S2 guest only), A10 (the cluster is `cryolite`, ADR-007 D7.20), A11 (copy and adapt the Chainsaw steps), A12 (no registry mirror on the agent); A8 (world-assumption numbering) is settled at sync time.
Each is recorded in design.md Open Questions with its resolution.

## Q20 [reviewed, rev 2]: what is the target of the regulators — the existing clusters or a new one?

A new sibling cluster `kubernetes/clusters/cryolite`; `local` and `local-k3d` are frozen prototypes that keep ArgoCD, nixidy, sops-secrets-operator, kube-proxy, and the k3d workflow, and are neither migrated nor edited.
Existing files grow only additively through default-off options (`modules/kubernetes.nix` gains `cryolite` in `evalCluster`; `modules/nixos/k3s-server/default.nix` gains `snapshotter` and loses its dead containerd block; `modules/devshells/kubernetes.nix` gains flux, clusterctl, hcloud, cosign, crane).
The target module layout in design.md marks every path `[keep]`, `[add]`, or `[+opt]`; deleting the `[add]` paths makes the cluster disappear with no other edit.
Evidence: ADR-007 D7.15, D7.19; revision-2 dispatch D-a, D-h.

## Q21 [reviewed, rev 2]: whose identity is stable?

The cluster's (T0: join token and CA set, Flux age key, cosign key, SSH CA, etcd-S3 credentials, generated once by Clan vars), and its endpoints (T2: the CAPH load balancer); never the node's (T1: Machine name, host keys, Cilium WireGuard key, `CiliumNode`), which is disposable and never referenced outside the cluster.
A KVM-free regulator `k8s-node-identity-free-cryolite` makes this a property of the repository (S0); the in-VM proof of T0 delivery through `contentFrom.secret` is S3 in the sibling change.
Evidence: ADR-010 D10.1, D10.2, D10.4, D10.6.

# Design trade-offs recorded

- Reusing the production deferred module unmodified means the test cannot set `nodeIP`, which the module does not expose; the two-guest platform leaf sets `services.k3s.nodeIP` directly as glue rather than adding an option speculatively.
- Regulating a new cluster `cryolite` instead of migrating `local-k3d` leaves the F2 envelope drift (kube-proxy, ServiceLB) in place for the frozen prototype; accepted because the prototype is not the production target and its retirement is Future Work, not this change.
- The O-a `NotReady` assertion is narrow by intent (reason and message), accepting brittleness against kubelet message wording in exchange for non-vacuity.
- The single platform leaf trades granular failure attribution for one envelope and one image closure; Chainsaw's own step names recover most of the attribution.
- Store-path tokens are world-readable in the store; acceptable only because the value authorizes nothing outside the sandbox, and stated as such.
- The `platform` sum is declared from day one but only `hetzner` executes; the render-only `gcp` variant buys a stable seam at the cost of untested runtime differences until a second cloud is deployed.
- Delivering the root `OCIRepository` digest through `KThreesConfig.spec.files` keeps configuration changes off the snapshot at the cost of a control-plane machine rollout per digest bump (design A1).
- Keyed cosign is chosen over keyless because verification must work in a sandbox without Fulcio or Rekor; key rotation becomes a Clan vars concern.
