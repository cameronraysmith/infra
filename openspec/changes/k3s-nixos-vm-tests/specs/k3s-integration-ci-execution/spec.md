## ADDED Requirements

### Requirement: VM leaves are independent Linux-only checks requiring KVM

Each VM regulator SHALL be exposed as one `perSystem.checks.vm-<subject>` derivation, present only where `pkgs.stdenv.hostPlatform.isLinux`, built through `nixosLib.runTest`, and SHALL carry `requiredSystemFeatures` containing `kvm` and `nixos-test`; no non-VM check SHALL depend on a VM check.

#### Scenario: A leaf is enumerated

- **WHEN** `nix eval .#checks.x86_64-linux --apply builtins.attrNames` is run
- **THEN** each `vm-k3s-*` leaf appears as its own attribute, and `nix eval .#checks.aarch64-darwin --apply builtins.attrNames` lists none of them

#### Scenario: A VM leaf's system features are inspected

- **WHEN** `nix derivation show .#checks.x86_64-linux.vm-k3s-substrate` is run
- **THEN** `env.requiredSystemFeatures` contains `kvm` and `nixos-test`

### Requirement: The developer host discovers VM leaves by prefix

`just test-integration` SHALL build every `checks.<system>.vm-*` leaf for the current system, including the k3s leaves, and SHALL NOT enumerate them by name.

#### Scenario: A new leaf is added

- **WHEN** a `vm-k3s-snapshotter` leaf is added and `just test-integration` is run on a KVM-capable Linux host
- **THEN** the new leaf is built without any change to the justfile

### Requirement: VM leaves gate CI only from a runner whose KVM has been probed

A VM regulator SHALL be added to a GitHub Actions job only after a manually dispatched probe on the same runner label has built `vm-k3s-substrate` under `--option system-features 'kvm nixos-test benchmark big-parallel'` three consecutive times; if the probe fails, VM leaves remain developer-host regulators run through `just test-integration` until a KVM-capable runner exists.
The existing `integration` job that runs the frozen `local-k3d` prototype is not edited by either outcome.
This requirement rests on world assumption A14.
Coverage bin: interface (CI job outcome); non-vacuity: the probe-fails scenario is the recorded negative.

#### Scenario: The probe passes

- **WHEN** the probe job passes three consecutive dispatches on `ubuntu-latest`
- **THEN** a `vm` job building the VM leaves is added to `test-cluster.yaml` on that label with the probe run links recorded in the change, and the `integration` job is unchanged

#### Scenario: The probe fails

- **WHEN** `/dev/kvm` is absent or the build is refused for a missing system feature on the probed runner
- **THEN** no VM job is added to that runner, the change records the failure, and the VM leaves remain developer-host regulators

### Requirement: The buildbot worker leaves VM leaves inert without failing anything else

On the buildbot worker, which exposes neither `kvm` nor `nixos-test`, VM leaves SHALL be unschedulable or filtered, and no other check's verdict SHALL change because of them.

#### Scenario: A push with VM leaves reaches buildbot

- **WHEN** a branch adding `vm-k3s-substrate` is pushed and buildbot evaluates the flake
- **THEN** every non-VM check reports the same verdict as before the leaf existed, and the VM leaf is either absent from the schedule or reported as skipped for a missing feature, never as a failure of the branch

### Requirement: Cached CI hashing covers the VM leaves' inputs

When VM leaves run in GitHub Actions through `cached-ci-job`, its `hash-sources` SHALL include `modules/checks/vm-*.nix`, `modules/nixos/**`, `modules/kubernetes/**`, `kubernetes/clusters/cryolite/**`, `kubernetes/modules/**`, `kubernetes/tests/cryolite/**`, and the age and cosign fixtures, so that a change to any of them invalidates the cache.

#### Scenario: A module change invalidates the cache

- **WHEN** a sysctl value in `modules/nixos/k3s-server/kernel.nix` changes and the workflow runs
- **THEN** the cached job reports a cache miss and rebuilds the VM leaves

### Requirement: Registry publishing is an effect, never a check

Pushing the `cryolite` configuration artifact to GHCR and signing it SHALL be exposed as `apps.<system>.k8s.oci-push` and `apps.<system>.k8s.cosign-sign` under `modules/apps/k8s/`, running outside the sandbox, SHALL NOT be reachable from any `checks.<system>.*` derivation, and the push SHALL fail when the registry's reported digest differs from the store-resident layout digest it published.
The Hetzner snapshot effect and the Cluster API effects are specified by `openspec/changes/capi-hetzner-cluster/` under the same rule.
Coverage bin: E; non-vacuity: the digest-mismatch scenario in `k3s-manifest-purity-regulator` and the scenario below.

#### Scenario: A check reaches for an effect

- **WHEN** a derivation under `checks.<system>` references the store path of an `apps` publishing script or opens a network connection
- **THEN** the sandbox build fails, and review rejects any change that relaxes the sandbox to make it pass

#### Scenario: The effect is absent from the checks closure

- **WHEN** `nix path-info -r` is run over every `checks.x86_64-linux.*` output
- **THEN** no store path under `modules/apps/k8s/` appears

### Requirement: The frozen prototypes' execution path is not edited

Stages S0–S2 SHALL NOT edit, disable, or delete the `integration` job, its `SOPS_AGE_KEY` wiring, the k3d scripts under `modules/apps/cluster/`, the `local-k3d-ci` nixidy environment, `modules/nixidy.nix`, `kubernetes/nixidy/`, or `kubernetes/tests/local-k3d/`; any migration or retirement of the `local-k3d` path is a separately authorized later change, which SHOULD not delete the k3d path before `vm-k3s-platform` has passed on the chosen runner.
Coverage bin: interface (review rule with a `git diff --stat` witness); non-vacuity: the scenario below.

#### Scenario: A stage touches a frozen path

- **WHEN** a change implementing S0, S1, S2, or the execution wiring shows any path under `kubernetes/clusters/local*`, `kubernetes/nixidy/`, `kubernetes/tests/local-k3d/`, or `modules/apps/cluster/` in `git diff --stat`, or edits the `integration` job
- **THEN** review rejects the change
