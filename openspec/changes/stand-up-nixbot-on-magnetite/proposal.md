---
linear_story_id: CAM-40
linear_story_identifier: CAM-40
linear_story_title: "Stand up nixbot on magnetite alongside buildbot"
linear_story_url: https://linear.app/cameronraysmith/issue/CAM-40/stand-up-nixbot-on-magnetite-alongside-buildbot
linear_story_state: In Review
linear_team: CAM
linear_project: nixbot-herculesci-cicd
last_synced_state: In Review
last_synced_at: 2026-08-28T02:26:23Z
review_round: 0
max_review_rounds: 3
attempt_log:
  - { at: "2026-08-27T18:20:00Z", transition: "Backlog->Todo", outcome: "posted", note: "T1 bind; issue created in the existing project and seeded from this proposal" }
  - { at: "2026-08-27T21:45:26Z", transition: "Todo->In Progress", outcome: "posted", note: "T2 apply; first checked tasks.md checkbox, credential-independent portion implemented on fm/vx-nixbot-implement-r1" }
  - { at: "2026-08-28T02:26:23Z", transition: "In Progress->In Review", outcome: "posted", note: "T3 verify; verify.md created, change ready for roborev and documenter review" }
---

## Why

Magnetite's CI is buildbot-nix, whose master/worker pair upstream has succeeded with nixbot: one service, no workers, building through the host nix daemon.
Migrating anything onto nixbot requires an instance to migrate onto, and standing that instance up carries every genuinely uncertain question — a second forge application, a second hostname and certificate, a second database on a shared instance, and capacity on a host already running the incumbent.
This change plans that instance beside buildbot, which stays authoritative for every repository, so each later migration becomes a small reviewable opt-in rather than a cutover.

## What Changes

This change is planning-only.
It writes the artifacts a later change implements against; no module code, no host configuration, and no deployment happen here.

**A second build service on magnetite, at its own hostname**
- From: magnetite runs one build service, buildbot-nix, reachable at `buildbot.scientistexperience.net`, composed through the `buildbot` aspect named in the host's aspect list and the upstream master and worker modules imported at the host.
- To: a second build service, nixbot, reachable at `nixbot.scientistexperience.net`, composed the same way — a new `nixbot` aspect plus the upstream `nixosModules.nixbot` imported at the host — with the incumbent's composition untouched.
- Reason: a migration target must exist before anything can migrate onto it, and the incumbent must keep serving while it does.
- Impact: non-breaking for the incumbent by construction; the two services share the host's nginx, PostgreSQL, nix store, and ACME account, which is where the residual risk lives.

**A dedicated forge application rather than the incumbent's**
- From: one GitHub App serves buildbot, holding the permissions buildbot-nix needs and creating per-repository webhooks.
- To: a second GitHub App dedicated to nixbot, holding the additional permissions and events nixbot requires and receiving deliveries at the application-level webhook endpoint, with the incumbent's application unedited.
- Reason: nixbot needs check-run write access and check events the incumbent does not; adding them to the incumbent's application would edit the registration a running service depends on, and one shared application would couple both services' identities and blast radii.
- Impact: one more registration to hold and one more credential set to rotate, in exchange for leaving the incumbent's registration alone.

**No repository is built by the new service in this change**
- From: nothing; the service does not exist.
- To: the service stands up able to serve its interface and receive authenticated deliveries while building no repository, bounded by the forge application's installation selection, by disabling the topic-based auto-import whose default would otherwise sweep in every repository the incumbent already builds, and by an explicit repository allowlist.
- Reason: opting a repository in is a reviewable decision belonging to a later change, not a side effect of standing up infrastructure.
- Impact: the service is deliberately unexercised beyond its own health on the day it lands.

**Verdicts that do not gate merges**
- From: the incumbent's verdicts are the ones the forge's required checks name.
- To: the new service publishes verdicts under a distinct name prefix, so the forge's required checks continue to name only the incumbent until someone edits them deliberately.
- Reason: both reference deployments adopted the incumbent's prefix precisely because they replaced it; under coexistence the same move would collide with a service that is still running.
- Impact: when a repository is later opted in, its required-checks configuration must be edited explicitly for the new service's verdicts to matter.

**Credentials through the fleet's primary secrets system**
- From: the incumbent's forge credentials are clan vars generators consumed as file paths.
- To: three further generators of the same shape for the new service's application key, webhook secret, and interface login secret, each reaching the service as a file path resolved at activation.
- Reason: the fleet already has one answer for this and the service consumes credentials as file paths, so no new mechanism is warranted.
- Impact: three encrypted entries added under the machine's vars tree; no credential value enters the repository.

## Capabilities

### New Capabilities
- `nixbot-build-service` (stratum: `behavioral`): what the fleet requires of a second build service standing beside an incumbent one — that it is reachable at its own hostname, that the incumbent keeps working, that it builds no repository until opted in, that its verdicts do not gate merges, that its forge credentials are operator-supplied and never legible in the repository, that one ordinary activation establishes it, and that it is sized so the incumbent keeps the capacity it uses.
- `build-service-interface` (stratum: `interface`): the properties at the machine's interface that discharge those requirements — a distinct hostname served over TLS, a distinct verdict namespace, authenticated delivery at an application-level endpoint, disjoint unit, user, database, state and GC-root paths with no TCP port bound, credentials present only as activation-resolved file paths, and a repository-visibility boundary set by the forge application's installation selection. Its trust boundary is stated in the capability: the installation selection is set by hand in the forge and is not something this machine can assert, capacity outcomes are not guaranteed, and the shared nginx, PostgreSQL, nix store and ACME account remain common-mode surfaces.

### Modified Capabilities
- `world-assumptions` (stratum: `world`): four assumptions are added — forge-application scoping and delivery authentication, hostname resolution and certificate issuance, the finiteness of one host's build capacity, and the fact that which service's verdict gates a merge is the forge's configuration rather than ours — and the designation table gains the terms the new behavioral requirements use.

## Impact

Implementation, in a later change, touches: a new `flake.modules.nixos.nixbot` aspect under `modules/nixos/`; the `nixbot` flake input in `flake.nix`; `modules/machines/nixos/magnetite/default.nix` to import the upstream module and name the new aspect in its aspect list; three `clan.core.vars` generators and their entries under `vars/per-machine/magnetite/`; a `nixbot` CNAME in `modules/terranix/cloudflare.nix` applied with the repository's terraform recipes; and a documentation note recording the two-service topology.
Nothing under the incumbent's `modules/nixos/buildbot.nix`, its aspect entry, its generators, its vhost, its database, or the repository-root `buildbot-nix.toml` is edited, added to, or removed.
The root `buildbot-nix.toml` in particular stays as it is: nixbot still parses that exact filename with the same schema, so the expectation that it would have to be replaced does not hold.

Out of scope here, each its own later change, sequenced after this one: migrating vanixiets' own CI onto nixbot; finishing python-nix-template's migration, which never completed onto buildbot-nix and now retargets to nixbot; migrating ironstar; and retiring buildbot once nothing depends on it.
