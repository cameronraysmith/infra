---
title: Omnigent server deployment plan
status: working-note
date: 2026-09-06
---

# Omnigent server deployment plan

This plan synthesizes the five research artifacts under `research/` into one recommended deployment of an Omnigent server at `omni.scientistexperience.net` on `magnetite`, with Kanidm as the OIDC provider.
It follows charter v1 (`charter.md`): eight decisions `D1`..`D8`, a rejected alternative per decision, a file-level change list, targeted verification slices, deferred scope, and open questions for the human gate.
Terms follow the charter designation table; the charter's `omnigent serve` names the process that upstream's CLI registers as `omnigent server` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:3835`).

## Resolved references

| Reference | Revision | Paths read |
|---|---|---|
| `github:omnigent-ai/omnigent` | `381bf638fb31e6a51990d9dab54ea9ef4b933711` (`main`, `0.13.0.dev0`) | `deploy/README.md`, `deploy/docker/`, `deploy/fly/`, `deploy/kubernetes/`, `omnigent/server/{oidc,oidc_access,admin_list,auth}.py`, `omnigent/inner/{bwrap_sandbox,sandbox}.py`, `omnigent/cli.py`, `omnigent/db/utils.py`, `pyproject.toml`, `README.md`, `CHANGELOG.md` |
| `github:Qubasa/infra` | `439ded26a84965b6c782b6277626b0d40a90f26d` | `pkgs/omnigent/`, `machines/wintux/{llm,packages}.nix`, `flake.nix` |
| `github:Lassulus/superconfig` | `afb34bfd269290c395d3cedd8a234a66e7d9ad62` | `5pkgs/omnigent/package.nix`, `2configs/omnigent.nix`, `2configs/covibe.nix`, `tools/covibe/` |
| `github:fosskar/buzz-flake` | `6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7` | whole repository |
| `github:block/buzz` | `95154bee4034ca7a40b33095c2ddbde8c9aa1614` (`desktop-v0.5.20`, the buzz-flake pin) | `crates/buzz-relay/`, `crates/buzz-pubsub/`, `docs/remote-agents.md` |
| `github:cameronraysmith/vanixiets` | `590f75195cc7acbb3926d39397bf860c2c6efc65` (`main`) | `modules/nixos/{kanidm,matrix,sso-gateway,cognee,buildbot}.nix`, `modules/machines/nixos/magnetite/default.nix`, `modules/terranix/cloudflare.nix`, `modules/nixpkgs/per-system.nix`, `modules/checks/`, `pkgs/by-name/`, `docs/notes/development/buzz/self-hosting.md`, `docs/notes/development/incidents/` |

The release artifact this plan recommends is the PyPI wheel `omnigent-0.12.0-py3-none-any.whl`, which is the newest release behind the pinned `0.13.0.dev0` revision (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:8`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:CHANGELOG.md:8`).
The v0.12.0 wheel hash was not fetched by this synthesis and is an implementation-time input.

Two facts in this plan come from evaluating the vanixiets flake rather than from a cited file: `nix eval .#nixosConfigurations.magnetite.config.security.allowUserNamespaces` prints `true`, and the check names `package-<name>`, `nixos-<machine>`, `terraform-validate`, and `gitleaks` are declared under `modules/checks/` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/checks/packages.nix:39`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/checks/machines.nix:38`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/checks/validation.nix:209`).

Additional sources acquired by this synthesis: a shallow read-only clone of `github:kanidm/kanidm` at tag `v1.11.0` was fetched to check the `email_verified` claim, and was then set aside without being read as a reference because that repository's agent instructions ask that it not be used as one; no citation into it appears in this plan, and the claim stays open as Q2.

## Comparison table

| Dimension | `omnigent-ai/omnigent` (upstream) | `Qubasa/infra` | `Lassulus/superconfig` | `fosskar/buzz-flake` |
|---|---|---|---|---|
| 1 Packaging | PyPI wheel with bundled SPA and GHCR images; no native binary (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:.github/workflows/release-omnigent.yml:127-144`) | `uv2nix` source build of `v0.3.0` with a separate `buildNpmPackage` SPA bound to the removed `ap-web/` layout and a malformed writable-config patch (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/package.nix:22-29`; `github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/web-ui.nix:21-23`) | `buildPythonApplication` from the pinned `0.9.0` wheel with `pythonRelaxDeps` and a `PYTHONPATH` fix for the respawned daemon (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:78-164`) | `rustPlatform.buildRustPackage` from a pinned `block/buzz` tree, `doCheck = false`, one startup-retry patch (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-relay/package.nix:15-47`) |
| 2 Module surface | CLI only; no NixOS unit (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:3835-3872`) | None; workstation package binding that no machine installs (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/wintux/llm.nix:11-31`) | Direct `systemd.services.omnigent` with `DynamicUser`, SQLite in the state directory, hardening, no reusable module (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:106-171`) | `services.buzz-server` with static user, `StateDirectory`, `settings` escape hatch, Postgres and Redis provisioning, member oneshot (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:42-268,381-439`) |
| 3 Proxy and TLS | Requires HTTP/2 TLS termination, WebSocket upgrades on `/v1`, unbuffered SSE (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:186-217`) | None for Omnigent; repository convention is nginx `forceSSL` plus ACME (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/gchq-local/gitea.nix:99-108`) | nginx ACME vhost, `proxyWebsockets`, one-day read and send timeouts (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:175-190`) | None; README delegates TLS to an unspecified proxy (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:README.md:75-80`) |
| 4 Secrets | Environment variables only; `_require` strips whitespace (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:243-250`) | None for Omnigent; clan vars with `restartUnits` elsewhere (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/gchq-local/gitea.nix:6-10`) | One clan vars `EnvironmentFile` with cookie secret and prompted client credentials (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:83-104`) | One `EnvironmentFile`; clan generator without `restartUnits` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-clan.nix:168-230`) |
| 5 OIDC and SSO | Native OIDC with issuer discovery, PKCE, domain allowlist, file-backed admin roster, no group claims (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc_access.py:1-30`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/admin_list.py:1-23`) | None; no identity provider deployed | pocket-id OIDC, `OMNIGENT_OIDC_SKIP_EMAIL_VERIFICATION`, email admin list (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:116-143`) | None; Nostr pubkeys are identity (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:249-267`) |
| 6 Runner and sandbox | Runner is a separate outbound WebSocket process; Linux sandbox is mandatory bubblewrap binding `/usr`, `/lib*`, `/bin`, `/sbin` plus declared `read_paths` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:219-259`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:105-116`) | Workstation CLI; wrapper `PATH` omits `bubblewrap` (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/package.nix:81-87`) | No server-side runner; hosts are registered ad hoc from client shells and the only catalogued ACP agent declares `sandbox.type: none` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:tools/covibe/flake-module.nix:92-114`; `github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:43-47`) | Home Manager `buzz-acp` user units with no sandbox (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-agents.nix:56-112`); `buzz-backend-kubernetes` compiled into the sidecars but wired by no module (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-sidecars/package.nix:36-47`) |
| 7 Buzz analogues | No Buzz, Redis, or relay; ACP is the shared protocol (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/acp_cli_harnesses.py:1-20`) | None | covibe is a relay-style proxy, not Buzz (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/covibe.nix:61-80`) | Buzz is the comparison system; relay, pairing relay, Postgres, Redis, S3 (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:143-187`) |
| 8 Maintenance intent | Fast-moving `main`; daily deployment changes; release cadence about weekly (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:CHANGELOG.md:8`) | Added once 2026-07-27, never revised, orphaned by 2026-09-04 (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/wintux/llm.nix:11`) | One-week personal deployment at `0.9.0`, patched for one machine (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:80`) | Ten days of feature work then bot-only updates; version bump blocked on a patch refresh (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:effects.nix:39-59`) |

## Recommended architecture

### D1 Host placement

Run the Omnigent server, its PostgreSQL database, and one co-located runner on `magnetite`, under explicit systemd memory limits, with the runner gated by Q7.

`magnetite` is the charter's fixed target (C2) and its most recent audit measured 20 GiB available of 30.6 GiB with 88-97% idle CPU and zero IO wait, so RK4's confirming observation is not present (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/incidents/2026-09-02-nixbot-eval-throughput-magnetite-storage-audit.md:192-199`).
The buildbot sizing comment reserves about 24 GiB for everything other than eval workers, and Omnigent is not in that budget (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/buildbot.nix:161-165`).
Upstream documents the server working set as about 512 MB to 1 GB (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:181-184`), so the proposed budget is `MemoryHigh=2G` and `MemoryMax=3G` on `omnigent.service` and `MemoryHigh=6G` and `MemoryMax=8G` on the runner unit, leaving the buildbot reservation intact.
Placing the runner on the same host as the server avoids laptop availability as a dependency and keeps the first deployment single-host (P3).

Reversing evidence: a measured buildbot or synapse latency regression after enabling the runner, or a `MemoryMax` kill in `journalctl -u omnigent-host`, would move the runner off `magnetite` to a laptop or a managed sandbox provider.

### D2 Packaging strategy

Add `pkgs/by-name/omnigent/package.nix` as a `buildPythonApplication` of the `v0.12.0` PyPI wheel, adapted from the superconfig recipe, and own it from the module through `mkPackageOption`.

The release workflow gates publication on the web UI bundle being present inside the core wheel, so a wheel build needs no Node toolchain and none of the `ap-web`-to-`web/` churn that broke the Qubasa derivation (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:.github/workflows/release-omnigent.yml:125-144`; `github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/web-ui.nix:21-23`).
Superconfig demonstrates the three adaptations the wheel needs on nixpkgs: `pythonRelaxDeps` for version pins that lag nixpkgs, the `uvicorn` standard extras, and a `PYTHONPATH` prefix so the CLI's `sys.executable -m omnigent.host._daemon_entry` respawn can import the package (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:78-164`).
The vanixiets `pkgs/by-name` tree is flat with `pkgsNameSeparator = "-"`, so the package lives at `pkgs/by-name/omnigent/package.nix` and not under a two-letter shard as the charter naming rule states (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixpkgs/per-system.nix:51-52`); Q4 asks for the charter correction.
A wheel of a released version is chosen over a source build of the pinned `0.13.0.dev0` revision because the wheel is the artifact upstream tests and publishes.
This plan read the OIDC surfaces at the pin and not at the `v0.12.0` tag, so the implementation must confirm before building that `omnigent/server/oidc.py`, `omnigent/server/oidc_access.py`, `omnigent/server/routes/auth.py`, and `omnigent/server/admin_list.py` are unchanged between `v0.12.0` and `381bf638fb31e6a51990d9dab54ea9ef4b933711` by a tag-to-pin diff, and re-derive D4 from the tag if they differ (Q1).
The derivation adds `psycopg[binary]` for D3 because the base wheel places it under the `databricks` extra (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:282-287`), and the runtime `PATH` suffix carries `bubblewrap`, `git`, `uv`, `nodejs`, `tmux`, and `ripgrep`, closing the Qubasa omission (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/package.nix:81-87`).
No Qubasa, superconfig, or Omnigent flake input is added (P2, W7).

Reversing evidence: a nixpkgs dependency the wheel cannot be relaxed onto, or an upstream release of a source-tree build path that vanixiets already tools for, would move to a `pyproject-nix` source build.

### D3 Database

Use the shared local PostgreSQL instance with an `omnigent` database owned by a static `omnigent` system user over the Unix socket, and pass `--database-uri postgresql+psycopg:///omnigent?host=/run/postgresql` explicitly.

Upstream names Postgres "the default and the production answer" and SQLite a single-instance lite tier (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:146-165`).
The matrix module is the closest precedent (P1): `ensureDatabases`, `ensureUsers` with `ensureDBOwnership`, and `host = "/run/postgresql"` against the shared instance (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:229-243,358-372`), and buzz-flake uses the same socket idiom (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:286-295`).
Peer authentication over the socket removes the database password generator that cognee needs for TCP (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:49-69`), which is why D5 has no database secret.
The `postgresql+psycopg://` dialect is written explicitly because the normalizer that rewrites `postgres://` lives in the Docker entrypoint and `omnigent/db/utils.py`, and the plan does not rely on `omnigent server` applying it to `--database-uri` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/db/utils.py:184-194`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:3851-3860`).
Migrations run inside the server at startup, so the unit orders `after` and `requires` `postgresql.service` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/db/utils.py:398-405`).
No PostgreSQL backup exists in the fleet, and the Buzz note names backups a prerequisite for any stateful tenant (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md:148-152`); Q6 carries that decision.

Reversing evidence: the psycopg socket URL failing in the server's SQLAlchemy engine setup at implementation time, or an explicit decision that the deployment is disposable and single-user, would select SQLite in `StateDirectory` as superconfig does.

### D4 Authentication

Use OIDC mode against a new confidential Kanidm client `systems.oauth2.omnigent`, modeled field for field on `systems.oauth2.synapse`, with authorization by a Kanidm scope map on a new `omnigent_users` group plus Omnigent's domain allowlist and admin roster.

The Kanidm client declares `displayName = "Omnigent"`, `originUrl = "https://omni.scientistexperience.net/auth/callback"`, `originLanding = "https://omni.scientistexperience.net/"`, `preferShortUsername = true`, `scopeMaps.omnigent_users = [ "openid" "profile" "email" ]`, and `basicSecretFile` from the D5 generator, exactly as synapse does (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:183-212`).
The synapse client sets no PKCE or legacy-crypto relaxations, and Omnigent sends `code_challenge_method: S256` unconditionally in its authorization request and accepts both the ES and RS signing families, so whichever algorithm the deployed Kanidm already uses for synapse is accepted and the omnigent client needs no relaxation either (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:206-214`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:871-879`).
The `omnigent_users` group is a stub with `overwriteMembers = false` like `matrix_users`, and membership is granted operationally (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:167-181`); Q8 asks whether to reuse `matrix_users` instead.
The scope map is the group-based authorization lever, because RK3 is confirmed: Omnigent admits by domain allowlist, admin roster, or invite and reads no group or role claim (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc_access.py:9-30`).
The server environment sets `OMNIGENT_AUTH_ENABLED=1`, `OMNIGENT_AUTH_PROVIDER=oidc`, `OMNIGENT_OIDC_ISSUER=https://accounts.scientistexperience.net/oauth2/openid/omnigent`, `OMNIGENT_OIDC_CLIENT_ID=omnigent`, `OMNIGENT_OIDC_REDIRECT_URI=https://omni.scientistexperience.net/auth/callback`, `OMNIGENT_OIDC_LOGOUT_REDIRECT_URI=https://omni.scientistexperience.net/`, `OMNIGENT_OIDC_ALLOWED_DOMAINS` per Q3, and `OMNIGENT_ADMIN_CREDENTIALS_PATH=/var/lib/omnigent/admin-credentials` so that the admin roster resolves to `/var/lib/omnigent/admins` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:252-289`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/admin_list.py:51-71`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:282-307`).
The client secret and cookie secret arrive through the D5 `EnvironmentFile`; the cookie secret must be at least 64 hex characters, which `openssl rand -hex 32` produces (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:270-278`).
`OMNIGENT_OIDC_SKIP_EMAIL_VERIFICATION` stays unset until Q2 is answered, because upstream requires `email_verified` by default and the waiver trusts any signed email claim (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:296-310`).
The module renders the admin roster from an `adminEmails` list option into `<stateDir>/admins` in `ExecStartPre`, because the roster is file-only and promotion is additive (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/admin_list.py:14-23`).
Discovery runs at startup against the issuer, so the unit orders `after = [ "kanidm.service" ]` and polls the issuer in `preStart` as the matrix unit does (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:338-352`).
No non-Kanidm path is needed (R7, C3): the only unverified Kanidm behaviour is the `email_verified` claim, and Omnigent has an explicit waiver for it.

Reversing evidence: a first login failing at the callback for a reason other than a missing `email_verified` claim, or an upstream change requiring a claim Kanidm cannot emit, would justify a different OIDC provider.

### D5 Secrets

Add two clan vars generators owned by the modules that consume them: `kanidm-oauth2-omnigent` in `modules/nixos/kanidm.nix` and `omnigent-cookie-secret` in `modules/nixos/omnigent.nix`, both consumed as `EnvironmentFile` entries with `restartUnits`.

`kanidm-oauth2-omnigent` copies the synapse generator: `files."secret"` owned `kanidm:kanidm`, mode `0400`, `restartUnits = [ "kanidm.service" "omnigent.service" ]`, generated by `openssl rand -hex 32` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:91-121`).
It adds a second file `files."env"` owned by `root`, mode `0400`, `restartUnits = [ "omnigent.service" ]`, containing `OMNIGENT_OIDC_CLIENT_SECRET=<same value>`, because Omnigent reads the client secret from the environment at `_require("OMNIGENT_OIDC_CLIENT_SECRET")` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:252-254`) and `git grep -n -i -E 'CLIENT_SECRET|_PATH|_FILE' -- omnigent/server/oidc.py` at `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711` matches only lines 140, 174, 254, 342, and 384, none of which names a file-path variant that `LoadCredential` could target.
`omnigent-cookie-secret` writes `files."env"` with `OMNIGENT_OIDC_COOKIE_SECRET=<openssl rand -hex 32>` under the same ownership, following the superconfig generator but splitting the cookie secret from the client secret so that rotating one does not rotate the other (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:83-104`).
Trailing-newline handling is not a concern on either side: kanidm-provision reads `basicSecretFile` as the synapse deployment already does, and Omnigent strips whitespace in `_require` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:243-250`).
`EnvironmentFile` is read by the service manager before privilege drop, so root ownership is compatible with a static service user, and it is the vanixiets precedent for environment-only consumers (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:57-64`).
No database secret exists because D3 uses socket peer authentication, and no runner token is stored as a clan var because the runner token is a per-user login artifact (D7).
After the implementation lands, the operator runs `clan vars generate magnetite --generator kanidm-oauth2-omnigent`, `clan vars generate magnetite --generator omnigent-cookie-secret`, then `clan vars list magnetite` to confirm, and finally `clan machines update magnetite`; this work executed none of these commands (R3, C1).

Reversing evidence: an upstream option to read `OMNIGENT_OIDC_CLIENT_SECRET` from a file path would move both consumers to `LoadCredential` as the matrix unit does.

### D6 Ingress

Expose the server through an nginx virtual host for `omni.scientistexperience.net` with ACME and `forceSSL`, proxying to a loopback listener with `proxyWebsockets = true` and one-day read and send timeouts, and add an unproxied Cloudflare CNAME to `magnetite`.

`magnetite` terminates TLS with nginx and ACME for kanidm and matrix, and its firewall opens 80 and 443 publicly (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:470-513`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:444-455`).
Omnigent needs WebSocket upgrades for the runner tunnel and terminals and unbuffered SSE for session events (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:186-217`), and the SSE response sets `X-Accel-Buffering: no` itself, so nginx needs no `proxy_buffering off` override (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/sessions/routes_events.py:2187-2199`).
The superconfig vhost is the deployed precedent for the timeout values, because idle WebSocket tunnels would otherwise be severed at nginx's 60-second default (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:175-190`).
The DNS record follows the `accounts`, `kb`, and `auth` records: a CNAME to `magnetite.scientistexperience.net` with `proxied = false` so ACME issuance works (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/terranix/cloudflare.nix:100-133`).
The server listens on `127.0.0.1` on a port chosen by the module, and the firewall gains no new rule.
Public ingress is required because browsers complete the OIDC flow and runners dial the public URL over `WS /v1/runner/tunnel` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:226-229`).

Reversing evidence: a requirement that all Omnigent traffic stay on the ZeroTier mesh would move the vhost to the `zt+` interface with an internal certificate and require every runner and browser to be a mesh member.

### D7 Sandbox and runner

Run one `omnigent host https://omni.scientistexperience.net` as a system service under a dedicated `omnigent-host` user on `magnetite`, with bubblewrap, and with the runner's agent configuration declaring NixOS store paths as `read_paths`.

The runner is a separate process that registers over an outbound WebSocket (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:219-259`).
It needs `uv`, `git`, Node, and `tmux` on `PATH` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:124-139`) plus `bwrap` on Linux (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:140-145`), which the D2 wrapper supplies.
Bubblewrap requires unprivileged user namespaces, and `magnetite` evaluates `security.allowUserNamespaces = true`, so no kernel change is needed.
The default bubblewrap view binds the directories `/usr`, `/lib`, `/lib64`, `/lib32`, `/bin`, and `/sbin` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:109-116`), an allow-list of `/etc` files for libc, DNS, and the dynamic linker (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:118-131`), and the `/etc` subtrees `ld.so.conf.d`, `ssl`, `ca-certificates`, `pki`, and `alternatives` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:133-145`), and it adds only the paths the agent's `sandbox.read_paths` declares (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:326-328`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:docs/POLICIES.md:211`).
This plan infers, from the NixOS filesystem layout rather than from any cited upstream line, that none of those default binds holds binaries on NixOS, so a sandboxed terminal cannot exec anything under `/nix/store` unless `sandbox.read_paths` adds `/nix/store`, `/run/current-system/sw`, and the runner user's `/etc/profiles/per-user` directory.
This NixOS-specific gap is the runner's principal implementation risk and must be verified with a first sandboxed session before the runner is declared working.
The runner authenticates with the bearer token of the user who logged in on that machine, so a co-located runner embeds one operator's identity and executes sessions as `omnigent-host` on the server host (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/connect.py:3711-3715`); Q7 asks for that approval.
The runner unit cannot carry `RestrictNamespaces = true` or `SystemCallFilter` sets that block `clone` namespaces, because bubblewrap needs them; buzz-flake's hardening block is reusable for the server unit only (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:406-437`).
No `sandbox.type: none` catalog entry is created, unlike the superconfig server's ACP agent (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:43-47`).
Managed sandbox providers and a KVM host are deferred (P3, C2).

Reversing evidence: a sandboxed session that still cannot exec store binaries after `read_paths` is set, or the operator declining to place a personal bearer token on the host, would select laptop-only runners for the first deployment.

### D8 Buzz relationship

Keep Omnigent independent of the Buzz → omp → Atomic topology, add no buzz-flake input, and treat buzz-flake as a module-shape reference only.

vanixiets installs Buzz as a client and already pins the identical `block/buzz` revision and source hash that buzz-flake builds from, so a buzz-flake input would duplicate a vendored source (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:pkgs/by-name/buzz/source/package.nix:33-48`; `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-desktop/source.nix:5-15`).
Upstream Omnigent has no Buzz, Redis, pairing relay, or S3 dependency, and the only shared protocol is ACP (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:143-187`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:298-302`).
Three buzz-flake patterns are worth mirroring in `modules/nixos/omnigent.nix`: the socket `DATABASE_URL`, the `settings` attrset rendered into unit environment, and the `after`/`requires` on Postgres with startup retry (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:33-36,145,224-241,384-392`).
RK5 is not confirmed: every relay variable and startup gate the vanixiets Buzz note names exists under the same name at the buzz-flake pin, and the three discrepancies are note omissions or a flake description error rather than config-surface changes (`github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/config.rs:567,894-899,969-978`).
Two probable buzz-flake defects are recorded for Q10 and are irrelevant to Omnigent: an `s3.addressingStyle` enum value upstream rejects, and a relay wrapper `PATH` lacking `bash`, `curl`, and `openssl` for the fail-closed pre-receive hook (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:201-208`; `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/api/git/hook.rs:11-127`).

Reversing evidence: an upstream Omnigent integration that consumes a Buzz relay, or a decision to self-host the Buzz relay on `magnetite`, would add an explicit adapter or a separate Buzz plan rather than co-deploying Redis and pairing into this one.

## Rejected alternatives

- D1 `cinnabar` or a laptop as server host: rejected because the charter fixes `magnetite` and only `magnetite` runs Kanidm, nginx ACME, and the shared Postgres.
- D2 `Qubasa/infra` or `Lassulus/superconfig` as a flake input: rejected because both are personal flakes with stale pins and one-machine patches (W7, RK2 confirmed by `github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/writable-materialized-config.patch:5-11`).
- D2 `uv2nix` source build of the pinned revision: rejected because it adds three flake inputs and a `pnpm` SPA build that no vanixiets package currently exercises.
- D2 OCI image via `virtualisation.oci-containers`: rejected because the target is a NixOS module and the server image omits runner tooling (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Dockerfile:1-27`).
- D3 SQLite in `StateDirectory`: rejected because upstream calls it the lite tier and the fleet's stateful tenants share one Postgres instance (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:157-165`).
- D3 TCP with a generated password as cognee does: rejected because socket peer authentication needs one fewer secret and matches matrix.
- D4 Accounts mode: rejected because it cannot issue runner identity and exposes setup before the first admin exists (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:405-414`).
- D4 the shared `sso-gateway`: rejected because Omnigent has native OIDC and routing it through the gateway double-gates it (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/sso-gateway.nix:18-23`).
- D5 one combined generator for client and cookie secret: rejected because rotating either secret would then rotate both.
- D5 `LoadCredential` for the client secret: rejected because Omnigent reads it only from the environment.
- D6 Caddy: rejected because `magnetite` terminates TLS with nginx for every deployed service (W5, `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:39-57`).
- D6 ZeroTier-only ingress: rejected because browser OIDC and runner tunnels need the public URL.
- D7 KVM or `microvm.nix` runner host: rejected because no such host exists and bubblewrap is upstream's mandatory Linux sandbox (W3, W4).
- D7 `sandbox.type: none` agents: rejected because it removes the only isolation on a shared host.
- D7 managed sandbox providers: deferred, not selected, per P3.
- D8 buzz-flake as a flake input or Buzz relay co-deployment: rejected because vanixiets already vendors the same Buzz source and Omnigent needs none of the relay's dependencies.

## vanixiets change list

- Add `pkgs/by-name/omnigent/package.nix`: `buildPythonApplication` in `format = "wheel"` from the `omnigent-0.12.0-py3-none-any.whl` PyPI artifact with its hash, `pythonRelaxDeps` as needed against the vanixiets nixpkgs pin, `psycopg` added to `propagatedBuildInputs`, the `uvicorn` standard extras, a `postFixup` that prefixes `PYTHONPATH` for the respawned daemon, a `PATH` suffix of `bubblewrap`, `git`, `uv`, `nodejs`, `tmux`, and `ripgrep`, and `meta.mainProgram = "omnigent"`.
- Add `modules/nixos/omnigent.nix` as `flake.modules.nixos.omnigent`: options `enable`, `package` via `mkPackageOption`, `domain`, `port`, `stateDir`, `user`, `group`, `database.createLocally`, `oidc.issuer`, `oidc.clientId`, `oidc.allowedDomains`, `adminEmails`, `settings` as `attrsOf (oneOf [ str int bool ])`, and `environmentFiles`; a static `omnigent` system user; `services.postgresql.ensureDatabases` and `ensureUsers` with `ensureDBOwnership`; `systemd.services.omnigent` running `omnigent server --host 127.0.0.1 --port <port> --database-uri postgresql+psycopg:///omnigent?host=/run/postgresql --artifact-location <stateDir>/artifacts` with `StateDirectory`, `EnvironmentFile` list, `after`/`requires` on `postgresql.service`, `after` on `kanidm.service` with an issuer `preStart` poll, `MemoryHigh`/`MemoryMax`, and the buzz-flake hardening block; the `ExecStartPre` roster render into `<stateDir>/admins`; the nginx vhost for `domain` with ACME, `forceSSL`, `proxyWebsockets`, and one-day timeouts; and the `omnigent-cookie-secret` generator.
- Add `modules/nixos/omnigent-host.nix` as `flake.modules.nixos.omnigent-host`, gated by Q7: a static `omnigent-host` user with a home directory, `systemd.services.omnigent-host` running `omnigent host https://omni.scientistexperience.net` with `Restart = always`, `MemoryHigh`/`MemoryMax`, no `RestrictNamespaces`, a runtime `PATH` including the D2 package, and an agent-config seed declaring `sandbox.read_paths` for `/nix/store`, `/run/current-system/sw`, and the user's profile directory; the login token is bootstrapped manually once by the operator and is not a clan var.
- Modify `modules/nixos/kanidm.nix`: add `clan.core.vars.generators.kanidm-oauth2-omnigent` with `files."secret"` and `files."env"` as in D5, add `groups.omnigent_users` as a stub with `overwriteMembers = false`, and add `systems.oauth2.omnigent` with the D4 fields.
- Modify `modules/machines/nixos/magnetite/default.nix`: import `omnigent` and, if Q7 approves, `omnigent-host` from `flakeModules`, and set `services.omnigent.enable`, `domain = "omni.scientistexperience.net"`, `oidc.allowedDomains`, and `adminEmails` from Q3.
- Modify `modules/terranix/cloudflare.nix`: add `resource.cloudflare_dns_record.omni` as a CNAME for `omni.scientistexperience.net` to `magnetite.scientistexperience.net` with `proxied = false`.
- `flake.nix` and `flake.lock`: no change; no Qubasa, superconfig, Omnigent, or buzz-flake input is added.
- No sops entries are added; both secrets are clan vars generators.
- No Buzz server module, Redis, pairing relay, S3 credential, managed sandbox provider credential, or KVM/microvm file is added.

## Local verification plan

- Cheap text regulators over this plan before any Nix evaluation: `rg -c '^## '` equals 8, `rg -c '^### D[1-8] '` equals 8, the hostname filter, the machine-local-path filter, the one-sentence-per-line filter, and the citation resolution loop over the six pinned revisions.
- `nix build .#packages.x86_64-linux.omnigent` and `nix run .#omnigent -- --version` to confirm the wheel builds and the console script imports.
- `nix build .#checks.x86_64-linux.package-omnigent` for the build-realization check the package tree derives automatically.
- `nix eval .#nixosConfigurations.magnetite.config.services.omnigent --json` to inspect the option tree, and `nix eval .#nixosConfigurations.magnetite.config.systemd.services.omnigent.serviceConfig --json` to confirm `EnvironmentFile`, `StateDirectory`, and memory limits.
- `nix eval .#nixosConfigurations.magnetite.config.services.kanidm.provision.systems.oauth2 --apply builtins.attrNames --json` and `nix eval .#nixosConfigurations.magnetite.config.services.kanidm.provision.groups --apply builtins.attrNames --json` to confirm the client and group.
- `nix eval .#nixosConfigurations.magnetite.config.services.nginx.virtualHosts --apply builtins.attrNames --json` to confirm the vhost, and `nix eval .#nixosConfigurations.magnetite.config.services.postgresql.ensureDatabases --json` to confirm the database.
- `nix eval .#nixosConfigurations.magnetite.config.clan.core.vars.generators --apply builtins.attrNames --json` to confirm both generators are declared, without running any `clan vars` command.
- `nix eval .#nixosConfigurations.magnetite.config.security.allowUserNamespaces` remains `true` after the runner module is imported.
- `nix build .#checks.x86_64-linux.nixos-magnetite` for the machine closure once the package, option, and generator slices above pass.
- `nix build .#checks.aarch64-darwin.terraform-validate` for the Cloudflare change, and `nix build .#checks.aarch64-darwin.gitleaks` before review.
- `nix fmt -- --ci` on the branch.
- `just check-fast` is not a local gate for this work because the surfaces are covered by the targeted slices above and the host-specific shortcut does not include `magnetite`.
- Post-deployment, outside this plan's scope: a first browser login through Kanidm to answer Q2, and a first sandboxed runner session to confirm the `read_paths` finding in D7.

## Deferred scope

- Managed sandbox providers (freestyle.sh, Modal, Daytona, Blaxel, Kubernetes) and their credentials (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:267-309`).
- A KVM or `microvm.nix` runner host, because none exists in the fleet (W3).
- Buzz relay self-hosting, Redis, pairing relay, S3, and any Buzz-to-Omnigent adapter.
- Group-claim authorization inside Omnigent, because upstream reads none; the Kanidm scope map stands in for it.
- Multi-replica deployment, because the runner registry is in memory and multi-replica needs a shared registry (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/kubernetes/README.md:385-387`).
- PostgreSQL backup automation as implementation work, but not as a decision: Q6 must be answered before the service holds data.
- Tracking upstream `main` instead of releases, and the Qubasa writable-config patch, until a Home Manager agent bundle from the store is actually used with this server (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/package.nix:51-52`).
- The GitHub App integration and its `OMNIGENT_GITHUB_APP_PRIVATE_KEY_PATH` secret.

## Open questions

- Q1 Should the package target the released `v0.12.0` wheel or a source build of the pinned `0.13.0.dev0` revision?
  Recommended: the wheel, with the pin used only as the reading revision for this plan, and with a tag-to-pin diff of `omnigent/server/oidc.py`, `omnigent/server/oidc_access.py`, `omnigent/server/routes/auth.py`, and `omnigent/server/admin_list.py` run at implementation time to confirm that D4 as written applies to `v0.12.0`, since the `v0.12.0` tag was not available in the reference clone during this synthesis.
- Q2 Does Kanidm emit `email_verified: true` with the `email` scope for the deployed `1.11` server?
  Recommended: leave `OMNIGENT_OIDC_SKIP_EMAIL_VERIFICATION` unset, attempt one login after deployment, and set the waiver only if the callback rejects the token for a missing claim; the Kanidm source was not consulted at that repository's request.
- Q3 Which email domains go in `OMNIGENT_OIDC_ALLOWED_DOMAINS` and which Kanidm emails go in `adminEmails`?
  Recommended: `scientistexperience.net` as the only allowed domain and the operator's Kanidm primary email as the only admin, rather than an empty allowlist that admits every Kanidm account with the scope.
- Q4 Should charter v2 correct the package path from `pkgs/by-name/om/omnigent/` to the flat `pkgs/by-name/omnigent/`, and the reference table's `omnigent/sandbox/bwrap.py` to `omnigent/inner/bwrap_sandbox.py` as the file this plan cites?
  Recommended: yes for both, as a dated v2 entry.
- Q5 Should charter v2 rename the designation `omnigent serve` to upstream's literal `omnigent server`?
  Recommended: yes; this plan uses the charter term for the concept and the literal for commands.
- Q6 Is a PostgreSQL backup and restore procedure a precondition for the first deployment?
  Recommended: yes, at minimum a `services.postgresqlBackup` dump of the `omnigent` database with off-host copy, because no fleet tenant has one today.
- Q7 Should the first deployment include the co-located `omnigent-host` runner carrying the operator's bearer token, with `MemoryMax=8G`?
  Recommended: yes, because laptop-only runners make session availability depend on a laptop, provided the operator accepts a personal token stored under the `omnigent-host` home on `magnetite`.
- Q8 New `omnigent_users` Kanidm group or reuse `matrix_users`?
  Recommended: a new group, so that Matrix and Omnigent membership can diverge.
- Q9 Should RK5 be closed on the buzz-flake evidence?
  Recommended: yes for the config-surface claim, with the Buzz note's two inaccuracies (configurable health and metrics ports, Redis not startup-fatal) corrected in a follow-up to that note.
- Q10 Should the two probable buzz-flake defects be reported upstream to `fosskar/buzz-flake`?
  Recommended: yes, as two issues, since neither affects this plan and both would affect anyone adopting the flake.
- Q11 Should the designation table gain Buzz-side terms for the relay and `buzz-acp`?
  Recommended: no; the comparison table's one-line analogues suffice and Buzz is out of implementation scope.
- Q12 Should the depth-1 reference clones of `Qubasa/infra` and `omnigent-ai/omnigent` be unshallowed so that A2 resolves historical citations offline?
  Recommended: yes before the next research round; this plan cites only the pinned revisions.
- Q13 Is a nixpkgs clone under the `ghq` root wanted so that the buzz-flake artifact's default-`PATH` citation resolves under A2?
  Recommended: no; that citation supports a Buzz finding outside this plan's scope.
- Q14 Should the runner's first agent catalog use the native terminal harness, ACP, or pi-native wrappers?
  Recommended: the upstream default native harness under bubblewrap, so that the D7 `read_paths` finding is tested before any ACP agent is added.
- Q15 What `OMNIGENT_OIDC_SESSION_TTL_HOURS` should the server use?
  Recommended: the upstream default of 8 hours.
