---
title: Omnigent server deployment plan charter
status: charter v1
date: 2026-09-06
---

# Omnigent server deployment plan charter

Charter version: v1.
A revision is a version bump with a dated entry under "Revision history"; the text of an earlier version is never edited in place.

## Objective and motivation

Produce a deployment plan, not an implementation, for running an Omnigent server at `omni.scientistexperience.net` on the `magnetite` NixOS host of the vanixiets fleet, with Kanidm as the OIDC provider.
The plan reconciles how four reference repositories package and deploy Omnigent and Buzz with Nix against the services and conventions already deployed in `github:cameronraysmith/vanixiets`.
The plan exists so that a later implementation session can proceed from file-level instructions, named verification slices, and a closed list of human decisions, instead of re-deriving the research.

## Reference revisions

| Reference | Revision | Relevant paths |
|---|---|---|
| `github:omnigent-ai/omnigent` | `381bf638fb31e6a51990d9dab54ea9ef4b933711` | `deploy/docker/`, `deploy/fly/`, `deploy/kubernetes/`, `deploy/README.md`, `docs/`, `omnigent/sandbox/bwrap.py`, `README.md` |
| `github:Qubasa/infra` | `439ded26a84965b6c782b6277626b0d40a90f26d` | `pkgs/omnigent/`, `machines/wintux/llm.nix`, `flake.nix` |
| `github:Lassulus/superconfig` | `afb34bfd269290c395d3cedd8a234a66e7d9ad62` | `5pkgs/omnigent/package.nix`, `2configs/omnigent.nix`, `machines/neoprism/config.nix`, `tools/covibe/` |
| `github:fosskar/buzz-flake` | `6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7` | whole repository |
| `github:cameronraysmith/vanixiets` | `590f75195cc7acbb3926d39397bf860c2c6efc65` (`main`) | `modules/nixos/{kanidm,matrix,sso-gateway,cognee}.nix`, `modules/machines/nixos/magnetite/`, `modules/clan/`, `modules/terranix/{hetzner,cloudflare}.nix`, `pkgs/by-name/`, `docs/notes/development/buzz/self-hosting.md` |

Every factual claim about a reference cites `owner/repo@<short-rev>:<path>` and, where a line matters, `:<line>`.
Reference clones live under the `ghq` root as `github.com/<owner>/<repo>`; the plan never records a machine-local path.

## World assumptions (indicative)

- W1 `magnetite` is a Hetzner Cloud `cx53` VPS managed by terranix (`modules/terranix/hetzner.nix`) and runs Kanidm, matrix-synapse, the `sso-gateway` oauth2-proxy, Gitea, buildbot, and nginx.
- W2 Kanidm on `magnetite` already provisions a per-service OIDC client for synapse (`modules/nixos/kanidm.nix`, `services.kanidm.provision.systems.oauth2.synapse`) with a clan-vars secret generator and `restartUnits`.
- W3 No Hetzner bare-metal machine exists in the clan inventory (`modules/clan/inventory/machines.nix`); the i9-13900 KVM sandbox host named in the brief is not deployed.
- W4 Omnigent's Linux local sandbox is bubblewrap, mandatory on Linux (`omnigent-ai/omnigent@381bf63:README.md:142`, `omnigent/sandbox/bwrap.py`); Landlock appears only in the OpenShell/Kubernetes managed-sandbox path.
- W5 Caddy is deployed only on `cinnabar` (ZeroTier-only virtual hosts) and inside the openclaw clan service; `magnetite` web services use nginx.
- W6 The beads issue tracker is stale and is not evidence of service status; the deployed `modules/` tree is.
- W7 The reference repositories `Qubasa/infra` and `Lassulus/superconfig` are personal infrastructure flakes with no stated maintenance commitment to downstream consumers.
- W8 The `docs/notes/development/` tree is unpublished working documentation; `packages/docs/` holds the published site.

## Requirements (optative)

- R1 The plan names one host, one packaging strategy, one database, one authentication design, one secrets design, one ingress design, one sandbox/runner design, and one Buzz relationship, each with a rationale paragraph and each rejected alternative with a one-line reason.
- R2 The plan lists every vanixiets file to add or modify, every flake input to add, and every clan vars generator or sops entry to create, without implementing any of them.
- R3 The plan lists the clan vars commands the user must run, and no such command has been executed by this work.
- R4 The plan gives a local verification procedure composed of targeted `nix eval` and `nix build` slices over the surfaces it touches, and does not name `just check-fast` as a local gate.
- R5 Every claim about a reference repository is traceable to a revision and path in the table above.
- R6 Open questions that require the user's decision are listed explicitly rather than resolved by inference.
- R7 The Kanidm integration is modeled on the existing synapse client, and a non-Kanidm OAuth path appears only if the plan identifies a requirement Kanidm cannot satisfy.

## Specification (shared phenomena)

- S1 The deliverable is one file, `docs/notes/development/omnigent/deployment-plan.md`, with a YAML frontmatter block carrying `title`, `status`, and `date`, plus a sibling `charter.md` (this file) and research artifacts under `docs/notes/development/omnigent/research/`.
- S2 The plan has exactly these top-level sections in this order: Resolved references; Comparison table; Recommended architecture (subsections `D1`..`D8` matching the eight decisions); Rejected alternatives; vanixiets change list; Local verification plan; Deferred scope; Open questions.
- S3 The hostname appears only as the literal `omni.scientistexperience.net`.
- S4 Prose is one sentence per line, declarative, without marketing language; the terms in the designation table are used with the meanings given there.
- S5 No committed text contains a machine-local path, a session URL, or an attachment link.

Satisfaction argument: W1..W8 with S1..S5 discharge R1..R7; R3 additionally depends on the process invariant that no `clan vars` command runs during this work, which is discharged by human review of the run logs.

## Designations

| Term | Meaning in this work |
|---|---|
| Omnigent server | The `omnigent serve` process that exposes the web UI and API and stores sessions in its database. |
| Runner / host | The `omni host <server-url>` process that registers a machine with the server and executes agent sessions there. |
| Local sandbox | The bubblewrap (Linux) or seatbelt (macOS) OS-level isolation the runner applies to each session on the machine it runs on. |
| Managed sandbox provider | A server-side provider (`modal`, `daytona`, `blaxel`, `kubernetes`, and others under `deploy/`) that provisions a remote sandbox per session. |
| Accounts mode | Omnigent's built-in username/password authentication, bootstrapped by `OMNIGENT_ACCOUNTS_INIT_ADMIN_PASSWORD`. |
| OIDC mode | Omnigent authentication delegated to an OpenID Connect issuer via the `OMNIGENT_OIDC_*` variables. |
| Kanidm client | An entry under `services.kanidm.provision.systems.oauth2.<name>` in `modules/nixos/kanidm.nix`. |
| sso-gateway | The shared oauth2-proxy in `modules/nixos/sso-gateway.nix` for upstreams without native OIDC; not applicable to a service with its own OIDC. |
| clan vars generator | An entry under `clan.core.vars.generators.<name>` producing secret or public files consumed by a NixOS service. |
| `-bin` proxy derivation | A `pkgs/by-name` package that fetches hashed upstream release artifacts instead of building from source. |
| Buzz → omp → Atomic topology | The current agent stack: Buzz (ACP-native client) driving the `omp` harness, which runs Atomic workflows; harness modules live under `modules/home/ai/`. |
| Regulator | A deterministic command whose failure would reject the deliverable. |

## Constraints and rejected alternatives

- C1 Planning only: no commits outside the plan branch, no deploys, no `clan` mutation commands, no secret generation, no `clan vars check` or `clan vars generate`.
- C2 Target host is `magnetite`; the brief's KVM/bare-metal sandbox host is out of scope because W3 and W4 hold.
- C3 Kanidm is the OIDC provider unless a concrete unmet requirement is identified.
- C4 Prefer long-maintained general-purpose tooling over recently created agent-branded projects with unclear maintenance intent.
- C5 A package is owned by the module that enables it via `mkPackageOption`; no double-install through a shared aggregate.
- C6 OpenSpec is not used for this work; Linear is the single ledger (project plus issues in `cameronraysmith`/`CAM`).
- Rejected: `docs/plans/omnigent.md` as the path, because the repository has no `docs/plans/` and planning notes live under `docs/notes/development/<topic>/`.
- Rejected: an uncommitted plan file delivered only through chat, because a durable deliverable needs a reviewable branch.
- Rejected: KVM/`microvm.nix` runner host as initial scope, because upstream's mandatory bubblewrap sandbox on Linux covers the initial isolation need (W4).
- Rejected: Caddy as the assumed proxy on `magnetite`, because `magnetite` already terminates TLS with nginx for every existing service (W5).

## Architectural principles

- P1 Model new integrations on the closest deployed precedent: the synapse Kanidm client for OIDC, the matrix or cognee module for Postgres provisioning, the kanidm module for clan vars generators with `restartUnits`.
- P2 Prefer the vanixiets packaging convention (`pkgs/by-name`, `-bin` proxy when upstream ships reliable release artifacts) over adopting a personal infra flake as an input, because W7 makes those inputs a maintenance liability.
- P3 Keep the first deployment single-host and single-process where upstream supports it; defer managed sandbox providers (freestyle.sh, Modal) to a named follow-up.
- P4 Every recommended decision names the evidence that would reverse it.

## Naming rules

- Decisions in the plan are `D1`..`D8` in the order of the brief: host, packaging, database, auth, secrets, ingress, sandbox/runner, Buzz relationship.
- Research artifacts are `research/<reference-slug>.md` with slugs `omnigent-upstream`, `qubasa-infra`, `lassulus-superconfig`, `buzz-flake`, `vanixiets-inventory`.
- Proposed Nix attributes follow existing names: package `omnigent` under `pkgs/by-name/om/omnigent/`, module `modules/nixos/omnigent.nix`, Kanidm client `systems.oauth2.omnigent`, generator `kanidm-oauth2-omnigent`.

## Acceptance criteria and regulators

| Criterion | Regulator | Kind |
|---|---|---|
| A1 Section structure matches S2 | `rg -c '^## ' docs/notes/development/omnigent/deployment-plan.md` equals 8 and `rg -c '^### D[1-8] ' ...` equals 8 | deterministic |
| A2 Every `owner/repo@rev:path` citation resolves | for each citation, `git -C "$(ghq root)/github.com/<owner>/<repo>" cat-file -e <rev>:<path>` exits 0; vanixiets citations checked against `main` | deterministic |
| A3 Hostname literal only (S3) | `rg -n 'omni\.[a-z]+\.net'` over the plan, filtered with `rg -v 'omni\.scientistexperience\.net'`, prints nothing | deterministic |
| A4 No machine-local paths or session links (S5) | `rg -n` for each of `/home/`, `app\.devin\.ai`, and `/attachments/` over `deployment-plan.md` and `research/` prints nothing; this table is the only permitted occurrence in `charter.md` | deterministic |
| A5 One sentence per line (S4) | `rg -n '[a-z]\. [A-Z]' docs/notes/development/omnigent/*.md` prints nothing outside tables and code fences | deterministic, approximate |
| A6 Formatting | `nix fmt -- --ci` on the branch exits 0 | deterministic |
| A7 No `clan vars` command executed (R3) | human reads the run logs and workflow transcripts at the gate | recorded human judgment |
| A8 Rationale and rejected alternatives present per decision (R1) | review-board axis "charter conformance" plus human gate | recorded human judgment |
| A9 Verification plan uses targeted slices (R4) | `rg -n 'check-fast' deployment-plan.md` shows the string only in a sentence rejecting it as a local gate | deterministic, plus human gate |

## Verification commands, cheap to expensive

1. A3, A4, A5, A9 greps above.
2. A1 heading counts.
3. A2 citation resolution loop.
4. `nix fmt -- --ci`.
5. Review board fold and human gate H1.

## Risks

- RK1 Upstream `omnigent-ai/omnigent` moves quickly; the pinned revision may lag the release the implementation uses.
  Confirming observation: `deploy/` or `docs/` paths cited in the plan are absent at the implementation-time revision.
- RK2 Reference derivations may be half-finished or patched for one machine.
  Confirming observation: a `.patch` or hard-coded path in `Qubasa/infra` or `Lassulus/superconfig` that the plan would need to reproduce.
- RK3 Omnigent's OIDC mode may not support group-based authorization.
  Confirming observation: no group or role claim handling in upstream auth code or docs.
- RK4 `magnetite` may lack headroom for the server, runner, and Postgres alongside buildbot and niks3.
  Confirming observation: the `magnetite` storage and eval-throughput incident note under `docs/notes/development/incidents/` records saturation on the resources Omnigent needs.
- RK5 The Buzz note (`docs/notes/development/buzz/self-hosting.md`) predates the current Buzz relay; the Buzz comparison may rest on stale relay behavior.
  Confirming observation: `fosskar/buzz-flake` packages a relay version whose config surface differs from the note.

## Rule

Raise an open question instead of guessing.
A research or synthesis node that meets ambiguity returns it in `questions[]`; the orchestrator carries it to the human gate.

## Revision history

- v1 (2026-09-06): initial charter after intake and one elicitation round; host fixed to `magnetite`, KVM runner host rejected, domain confirmed, OpenSpec rejected in favor of Linear.
