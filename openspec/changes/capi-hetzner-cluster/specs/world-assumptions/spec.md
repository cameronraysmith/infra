## ADDED Requirements

### Requirement: A17 — cluster-api-k3s defaults the cloud provider to external

It is true of the cluster-api-k3s bootstrap provider at the revision the fleet pins, independent of what this fleet builds, that its defaulting webhook sets `disableCloudController` to `true` and `cloudProviderName` to `external` when neither is given, so a node it bootstraps carries the `node.cloudprovider.kubernetes.io/uninitialized` taint until a cloud-controller manager removes it.
Any requirement whose discharge depends on this fact SHALL name it explicitly, and SHALL be treated as losing its discharge once this assumption's violation condition below is observed.

#### Scenario: The provider stops defaulting to external

- **WHEN** a pinned cluster-api-k3s release bootstraps a node with no cloud-controller manager present and the node becomes schedulable without the taint
- **THEN** this assumption is void, and the `capi-cluster-rendering` requirement `Every cloud-init platform variant renders a cloud-controller manager` loses the argument that an absent CCM leaves nodes unschedulable

### Requirement: A18 — Cilium ClusterMesh requires non-overlapping PodCIDRs and a covering native-routing CIDR

It is true of Cilium ClusterMesh, independent of what this fleet builds, that PodCIDR ranges in all connected clusters and nodes must be non-conflicting, that in native-routing mode the native-routing CIDR must cover every connected cluster's PodCIDRs, and that each cluster needs a unique name and numeric id, so two clusters that violate any of these cannot be meshed regardless of how they are otherwise configured.
Any requirement whose discharge depends on this fact SHALL name it explicitly, and SHALL be treated as losing its discharge once this assumption's violation condition below is observed.

#### Scenario: Cilium meshes clusters with overlapping PodCIDRs

- **WHEN** a deployed Cilium version establishes pod-to-pod connectivity between two clusters whose PodCIDRs overlap
- **THEN** this assumption is void, and the `capi-cluster-rendering` requirement `ClusterMesh preconditions hold at evaluation` may be relaxed to a warning

### Requirement: A19 — Hetzner Cloud offers no image-upload API

It is true of Hetzner Cloud, independent of what this fleet builds, that a custom operating-system image cannot be uploaded directly; the only path to a bootable custom image is to create a server, write the image to its disk (for example from the rescue system), and snapshot it, after which the snapshot can be referenced by name or label.
This is stated in CAPH's documentation and was not independently confirmed against the hcloud API reference; the first run of `apps.k8s.hetzner-snapshot-publish` is its behavioural check.
Any requirement whose discharge depends on this fact SHALL name it explicitly, and SHALL be treated as losing its discharge once this assumption's violation condition below is observed.

#### Scenario: Hetzner adds an image-upload endpoint

- **WHEN** the hcloud API accepts a custom image upload that CAPH can reference as `imageName`
- **THEN** this assumption is void, the throwaway server M4 becomes unnecessary, and the `hetzner-cluster-deployment` requirement `Snapshot publishing is an idempotent effect that hides the throwaway server` may be simplified to a direct upload with the same label contract

### Requirement: A20 — cloud-init's NoCloud datasource reads user-data from a labelled seed

It is true of cloud-init, independent of what this fleet builds, that the NoCloud datasource reads `user-data` and `meta-data` from a filesystem labelled `cidata` (or `CIDATA`) attached to the machine, or from a location named on the kernel command line, and applies `write_files` before `runcmd`, with `cloud-final.service` marking the end of the run.
Any requirement whose discharge depends on this fact SHALL name it explicitly, and SHALL be treated as losing its discharge once this assumption's violation condition below is observed.

#### Scenario: The ordering or the seed contract changes

- **WHEN** a pinned cloud-init release runs `runcmd` before `write_files` has placed its files, or stops reading a `cidata`-labelled seed
- **THEN** this assumption is void and the `capi-bootstrap-vm-regulator` requirement `The bootstrap regulator boots the production image from a NoCloud seed shaped as the provider emits it` loses the argument that the shim sees the T0 files when it runs

### Requirement: A21 — `clusterctl move` carries the Secrets labelled with the cluster name

It is true of Cluster API's `clusterctl move`, independent of what this fleet builds, that it moves the `Cluster` object graph and the `Secret`s labelled `cluster.x-k8s.io/cluster-name=<name>` to the target management cluster, and that cluster-api-k3s labels the token Secret it uses with that label.
The token labelling was read in cluster-api-k3s source; that the pre-provisioned CA Secrets move with the cluster is inferred from the same labelling rule and is observed in S4.
Any requirement whose discharge depends on this fact SHALL name it explicitly, and SHALL be treated as losing its discharge once this assumption's violation condition below is observed.

#### Scenario: A labelled Secret is left behind

- **WHEN** a `clusterctl move` completes and a `Secret` carrying `cluster.x-k8s.io/cluster-name=cryolite` remains only in the source cluster
- **THEN** this assumption is void and the `capi-management-cluster` requirement `The pivot moves the cluster and its T0 Secrets, and the management cluster is then deleted` must move the T0 Secrets explicitly before deleting the management cluster
