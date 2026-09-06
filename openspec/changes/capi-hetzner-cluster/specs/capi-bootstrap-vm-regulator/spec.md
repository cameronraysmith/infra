## ADDED Requirements

### Requirement: The production module has one bootstrap seam and the default leaves existing consumers unchanged

The production module `flake.modules.nixos.k3s-server` SHALL gain an option `k3s-server.bootstrap` with values `clan-vars` (default) and `cloud-init` (`modules/nixos/k3s-server/capi-bootstrap.nix`); with the default, the evaluated configuration of every existing consumer SHALL be byte-identical to its configuration before the option existed; with `cloud-init`, the module SHALL enable `services.cloud-init` with the NoCloud datasource only, install the Nix-written shim at `/opt/install.sh`, and order `k3s.service` after `cloud-final.service`.
The shim SHALL ignore every `INSTALL_K3S_*` variable, SHALL link the closure's `k3s` binary where cluster-api-k3s expects it, and SHALL start `k3s.service` reading `services.k3s.configPath`.
Coverage bin: T1 integrity for ADR-009 D9.2, D9.3, D9.8; non-vacuity: the scenario below.

#### Scenario: The default changes an existing consumer

- **WHEN** the option is added and `nix eval` of `vm-k3s-substrate`'s machine configuration is compared with its value before the option existed
- **THEN** the two are byte-identical, and any difference fails the S3.6 verification

### Requirement: The bootstrap regulator boots the production image from a NoCloud seed shaped as the provider emits it

There SHALL be a regulator, `vm-k3s-capi-bootstrap` (`modules/checks/vm-k3s-capi-bootstrap.nix`), that boots the `cryolite-server` image with `k3s-server.bootstrap = "cloud-init"` from a seed whose `user-data` is the rendered `KThreesControlPlane` bootstrap template of `capi-hetzner-cluster` (`capi-cluster-rendering`) with every `contentFrom.secret` entry resolved against the test-only fixtures under `kubernetes/tests/fixtures/`, and whose `runcmd` is cluster-api-k3s' own fixture text `INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC='server' sh /opt/install.sh`; it SHALL assert that `cloud-final.service` completed, that `k3s.service` is active with `ExecStart` reading `services.k3s.configPath`, and that the merged k3s configuration contains the token and CA paths from `/etc/rancher/k3s/config.yaml.d/`.
The regulator SHALL require `kvm nixos-test` and SHALL read no host environment, GitHub Secret, or network.
Coverage bin: T2 adequacy for ADR-009 D9.9, R9.5 and ADR-010 R10.3; non-vacuity: the mutations below.

#### Scenario: The seed carries no runcmd

- **WHEN** the `runcmd` is removed from the seed and the regulator is rebuilt
- **THEN** the regulator fails because `k3s.service` never becomes active

#### Scenario: A T0 item is inlined

- **WHEN** the token drop-in is rendered with inline `content` instead of `contentFrom.secret` and the regulator is rebuilt
- **THEN** the regulator fails at the assertion that every T0 file in the seed originated from a `contentFrom.secret` entry

### Requirement: T0 material lands where the design says and is not baked into the image

The bootstrap regulator SHALL assert that the Flux age-key `Secret` manifest is present under `/var/lib/rancher/k3s/server/manifests/` and applied to the cluster, that the etcd-S3 credential drop-in is present and referenced by the merged configuration, and that none of those files or their contents is present in the `cryolite-server` image closure before the seed is applied.
Coverage bin: T2 integrity for ADR-010 D10.4, R10.3; non-vacuity: the scenario below.

#### Scenario: The age key is baked into the image

- **WHEN** the fixture age private key is added to `environment.etc` of `cryolite-server` and the regulator is rebuilt
- **THEN** the regulator fails at the closure assertion, and `checks.k8s-closure-secret-free-cryolite` of `k3s-nixos-vm-tests` fails independently

### Requirement: Node identity is fresh on every boot and the CA private key does not survive

The bootstrap regulator SHALL boot the same image from the same seed twice on fresh disks, SHALL assert that the two SSH host keys differ and that both carry certificates valid under the fixture SSH CA, and SHALL assert that after `k3s.service` is active the SSH CA private key is absent from every filesystem of the guest, including cloud-init's instance data directory.
Coverage bin: T2 integrity for ADR-010 D10.1, R10.4, R10.e; non-vacuity: the mutations below.

#### Scenario: The host key is signed by a foreign CA

- **WHEN** the seed's SSH CA is replaced by a different test key and the regulator is rebuilt
- **THEN** the regulator fails at the certificate-validity assertion naming the CA fingerprint

#### Scenario: The CA key persists

- **WHEN** the deletion step is removed from the signing unit and the regulator is rebuilt
- **THEN** the regulator fails naming the path where the CA private key was found
