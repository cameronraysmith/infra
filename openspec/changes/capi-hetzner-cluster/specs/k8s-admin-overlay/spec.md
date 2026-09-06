## ADDED Requirements

### Requirement: The administrative overlay is a Clan wireguard instance controlled by the primary VPS, added only after the first deployment

The administrative overlay for `cryolite` SHALL be one Clan `wireguard` instance whose controller role is held by the existing primary VPS and by no k3s node and no new machine, SHALL be added to the inventory only in S4b after S4 has completed, and SHALL leave the existing ZeroTier network and every existing Clan machine's configuration unchanged.
Coverage bin: interface (inventory diff review; ADR-009 D9.15); non-vacuity: the scenario below.

#### Scenario: The overlay is added before the cluster exists

- **WHEN** a `wireguard` instance naming `cryolite` appears in the inventory in an S3 or S4 PR
- **THEN** the review fails and the instance is removed from that PR

### Requirement: The cluster joins through one gateway workload with a T0 peer key

`cryolite` SHALL join the overlay through exactly one `Deployment` rendered in `kubernetes/clusters/cryolite/` with one replica, `hostNetwork: true`, a control-plane node selector, a peer private key read from a T0 `Secret` whose generator lives under `secrets/clusters/cryolite/`, and the Hetzner private network as its advertised subnet; no k3s node SHALL hold a per-node overlay key, and the gateway's identity SHALL be per cluster so that node replacement leaves it unchanged.
Coverage bin: T1 integrity (`k8s-purity-cryolite`, `k8s-node-identity-free-cryolite`, and `k8s-capi-render-cryolite` over the rendered tree) for ADR-009 D9.15 and ADR-010 D10.1; non-vacuity: the scenario below.

#### Scenario: A per-node key appears

- **WHEN** the rendered tree or the T0 generators gain a key named after a node and the regulators are rebuilt
- **THEN** `checks.k8s-node-identity-free-cryolite` fails naming it

### Requirement: Stibnite is an admin-only peer and nodes are not Clan machines

Stibnite SHALL join the overlay as a peer with no route advertised and no controller role; no k3s node SHALL appear in the Clan inventory's machines or as a peer of the instance; and the Cilium WireGuard dataplane between nodes SHALL be unchanged by the overlay.
Coverage bin: interface (inventory review) for ADR-009 D9.12, D9.15; non-vacuity: the scenario below.

#### Scenario: A node is registered as a peer

- **WHEN** a `cryolite-*` machine appears in the inventory or as an instance peer
- **THEN** `checks.k8s-node-identity-free-cryolite` fails naming the entry and the review rejects the change

### Requirement: The overlay path is observed to carry administrative traffic and its absence is observed to fail

After S4b, `kubectl` against the API server's private address and `ssh` to a control-plane node's private address from stibnite SHALL succeed over the overlay while the public-address path of S4 continues to work; scaling the gateway `Deployment` to zero SHALL make the overlay path fail while the public path still works.
Coverage bin: E for ADR-009 R9.g; non-vacuity: the scale-to-zero scenario below.

#### Scenario: The gateway is absent

- **WHEN** the gateway `Deployment` is scaled to zero
- **THEN** the private-address `kubectl` and `ssh` from stibnite fail and the public-address path succeeds, and both transcripts are recorded in the S4b PR
