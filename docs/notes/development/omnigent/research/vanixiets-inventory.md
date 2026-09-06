---
title: Research axis vanixiets-inventory
status: working-note
date: 2026-09-06
---

# Research axis: vanixiets inventory

Axis revision: `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65` (`main` at the time the charter was written).
Terms follow the charter designation table in `docs/notes/development/omnigent/charter.md` (charter v1, on the plan branch, not yet on `main`).
Every citation below is of the form `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:<path>:<lines>`; the plan branch differs from that revision only by the added charter file, so line numbers were verified against the working tree and hold for the cited revision.

## Scope and method

The inventory covers the `magnetite` host, Kanidm, PostgreSQL, the shared SSO gateway, ingress and DNS, clan vars generators, packaging and module discovery, flake inputs, the Buzz, omp, and Atomic home-manager surfaces, documentation conventions, and the verification surfaces a future `modules/nixos/omnigent.nix` and `pkgs/by-name/omnigent/` would touch.
Files were read directly and line numbers were confirmed with `grep -n` and `sed -n` against the working tree.
`git blame` and `git log` were used for provenance where a comment and its adjacent code disagree.
No `clan` command, no `just check-fast`, no deployment, and no secret generation was run.
No external repository was acquired for this axis.

## 1. The `magnetite` host

### Hardware and inventory

Magnetite is a Hetzner Cloud `cx53` in `fsn1`, provisioned from a `debian-12` image, with the comment "16 vCPU, 32GB RAM, 320GB SSD, legacy BIOS" (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/terranix/hetzner.nix:24-30`).
Terranix creates one Cloudflare `A` record per enabled Hetzner machine, named after the machine, pointing at the server's `ipv4_address`, with `ttl = 1` and `proxied = false`, so `magnetite.scientistexperience.net` is the apex that the service CNAMEs below resolve through (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/terranix/hetzner.nix:71-78`).
The clan inventory records `magnetite` as `machineClass = "nixos"` with tags `nixos`, `cloud`, `hetzner`, and `peer`, description "Build infrastructure server (niks3, buildbot, Gitea)", and `deploy.targetHost = "root@magnetite.zt"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/clan/inventory/machines.nix:65-75`).
Its system is `x86_64-linux` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/clan/inventory/machines.nix:8`).
Its ZeroTier IPv6 address is `fddb:4344:343b:14b9:399:930f:39db:40d2`, exposed as `flake.lib.hosts.magnetite.zt` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/lib/hosts.nix:8`).

### Imports

The machine module imports `srvos.nixosModules.server`, `srvos.nixosModules.hardware-hetzner-cloud`, `srvos.nixosModules.mixins-nginx`, `home-manager.nixosModules.home-manager`, `niks3.nixosModules.niks3`, `buildbot-nix.nixosModules.buildbot-master`, `buildbot-nix.nixosModules.buildbot-worker`, and `nixbot.nixosModules.nixbot` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:29-38`).
It then imports the repository flake modules `base`, `hm-sops-bridge`, `niks3`, `ssh-known-hosts`, `stibnite-builder`, `stibnite-session`, `buildbot`, `nixbot`, `gitea`, `sso-gateway`, `gitea-actions-runner`, `docker`, `kanidm`, `matrix`, `omnigraph`, `effects-vanixiets-secrets`, and `effects-ironstar-secrets` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:39-57`).
The `cognee` flake module is not in that list, although the host still carries an `sso.services.cognee` registration and the cognee ZFS dataset (see Flags).
A future `omnigent` flake module would be added to this `with flakeModules; [ ... ]` list (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:39-57`).

### Disks and ZFS datasets

Disko declares one disk at `/dev/sda` with a `/boot` partition and a ZFS partition for pool `zroot` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/disko.nix:7-29`).
The pool sets `com.sun:auto-snapshot = "true"` at the root, so datasets inherit hourly and daily snapshots unless they opt out (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/disko.nix:35-39`).
`/` carries a `10G` reservation and `/home` a `4G` reservation (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/disko.nix:49-58`).
`/nix` sets `com.sun:auto-snapshot = "false"` and `quota = "250G"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/disko.nix:65-69`).
Separate datasets are mounted at `/var/lib/containers`, `/var/lib/cognee`, and `/var/lib/docker` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/disko.nix:73-88`).
No dataset is dedicated to `/var/lib/postgresql`, so the shared PostgreSQL data directory lives on the root dataset under the `10G` reservation and the root-inherited snapshot policy.
Snapshot retention is forced to `frequent = 0`, `hourly = 4`, `daily = 3`, `weekly = 1`, `monthly = 0` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:171-176`).
Boot-time oneshots assert `com.sun:auto-snapshot=false` on `zroot/root/nix`, `zroot/root/docker`, and `zroot/root/podman` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:187-215`).
Nix `min-free` is 30 GiB and `max-free` is 80 GiB (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:295-296`).

### ACME, firewall, and existing ports

ACME is enabled with `acceptTerms = true` and `defaults.email = "cameron@scientistexperience.net"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:115-118`).
The public firewall allows TCP `22`, `80`, and `443`, and the `zt+` interface class allows TCP `8090` for Omnigraph with a comment that further ports are added by service modules (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:444-455`).
`net.ipv6.ip_nonlocal_bind = 1` is set so services can bind the ZeroTier address before the interface settles (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:431`).
Loopback ports already in use by proxied services are Kanidm `127.0.0.1:8443` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:133`), Gitea `3002` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/gitea.nix:88`), niks3 `127.0.0.1:5752` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/niks3.nix:66`), and the Synapse, LiveKit JWT, and LiveKit ports referenced from the Matrix vhost (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:482-511`).
Mesh-bound ports in use are Omnigraph `8090` on `magnetite.zt` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:391-392`) and, when the cognee module is imported, cognee REST `9270` on `magnetite.zt` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:141-142`).

### Incident evidence relevant to capacity

The 2026-09-02 audit measured 16 EPYC-Rome vCPUs, 30.6 GiB RAM with 20 GiB available, a single-disk 304G pool at 24% allocated, `zroot/root/nix` at 62.8G compressed under the 250G quota, and `wa=0` in every `vmstat` sample (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/incidents/2026-09-02-nixbot-eval-throughput-magnetite-storage-audit.md:192-199`).
The same note records the June 10 incident in which `/nix` consumed the whole pool, followed by the 250G quota, the 10G and 4G reservations, `min-free` 30G and `max-free` 80G, seven-day GC retention, and a one-day reaper for `/nix/var/nix/builds` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/incidents/2026-09-02-nixbot-eval-throughput-magnetite-storage-audit.md:207-208`).
The note concludes that storage is healthy and not implicated in evaluation slowness (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/incidents/2026-09-02-nixbot-eval-throughput-magnetite-storage-audit.md:216-219`).
CI evaluation on the host is globally serialized in both buildbot-nix and nixbot, and roughly 85% of one measured evaluation's wall clock was a wait on nix-daemon substituter fan-out (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/incidents/2026-09-02-nixbot-eval-throughput-magnetite-storage-audit.md:32-39` and `:60-64`).
The repository check set at that time was exactly 117 attributes under `checks.x86_64-linux` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/incidents/2026-09-02-nixbot-eval-throughput-magnetite-storage-audit.md:138`).
Buildbot's memory sizing comment budgets 4 eval workers times 2 GiB and leaves roughly 24 GiB for buildbot subprocesses, postgres, matrix, and nginx, and does not account for an Omnigent server or its sandboxes (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/buildbot.nix:161-165`).

## 2. Kanidm

### Server

The Kanidm domain is `accounts.scientistexperience.net` and the origin is `https://${domain}` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:46` and `:130`).
Kanidm binds `127.0.0.1:8443` with TLS and reads `fullchain.pem` and `key.pem` directly from the ACME certificate directory, with access granted via `SupplementaryGroups` on the unit (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:133-147` and `:227`).
Kanidm's own online backup is enabled with `online_backup.versions = 7` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:149-152`).
Provisioning is enabled with `autoRemove = false` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:155-160`).
The nginx vhost for the domain sets `enableACME = true`, `forceSSL = true`, proxies to `https://127.0.0.1:8443` with `proxyWebsockets = true`, and disables `proxy_ssl_verify` for the loopback TLS hop (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:281-290`).

### Admin credential generators

`kanidm-admin-password` and `kanidm-idm-admin-password` are clan vars generators whose `password` file is owned `kanidm:kanidm`, mode `0440`, with `restartUnits = [ "kanidm.service" ]` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:58-64` and `:77-83`).
They are consumed via `provision.adminPasswordFile` and `provision.idmAdminPasswordFile` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:163-165`).
A `kanidm-site-branding` oneshot consumes the admin password through `LoadCredential = "admin-password:<path>"` and the CLI's `KANIDM_PASSWORD` environment variable (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:230-259`).

### The Synapse OAuth2 client precedent

The generator `kanidm-oauth2-synapse` writes `files."secret"` with `secret = true`, owner and group `kanidm`, mode `0400`, and `restartUnits = [ "kanidm.service" "matrix-synapse.service" ]`, produced by `openssl rand -hex 32 > "$out/secret"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:106-121`).
The file is owned by `kanidm` because `kanidm-provision` runs as `kanidm.service` `ExecStartPost` and reads `basicSecretFile` host-side (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:92-99`).
The client is `provision.systems.oauth2.synapse` with `displayName = "Matrix"`, `originUrl = "https://matrix.scientistexperience.net/_synapse/client/oidc/callback"`, `originLanding = "https://app.cinny.in/login/matrix.scientistexperience.net"`, and `preferShortUsername = true` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:183-205`).
Its scope map is `scopeMaps.matrix_users = [ "openid" "profile" "email" ]` and it binds `basicSecretFile` to the generator's `secret` path (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:206-211`).
The Synapse client declares no `claimMaps`; group claims are a gateway-only addition (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/sso-gateway.nix:481-491`).

### Group provisioning

`provision.groups.matrix_users` is declared with `overwriteMembers = false`, and the comment states members are added operationally with `kanidm group add-members matrix_users <user>` because the person record is intentionally not declared (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:167-181`).
The file header states that declarative person records are destructive on re-provision and that the admin's account is created imperatively (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:26-27`).

### Consumer side of the Synapse precedent

Synapse consumes the secret through `systemd.services.matrix-synapse.serviceConfig.LoadCredential = [ "oidc-secret:<generator path>" ]` and a `preStart` loop that waits for Kanidm to answer over HTTPS (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:343-352`).
Its OIDC provider block uses `issuer = "https://accounts.scientistexperience.net/oauth2/openid/synapse"`, `client_id = "synapse"`, and `client_secret_path = "/run/credentials/matrix-synapse.service/oidc-secret"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:300-306`).
The issuer URL pattern is therefore `https://accounts.scientistexperience.net/oauth2/openid/<client-name>`, and a client named `omnigent` would use `.../oauth2/openid/omnigent`.

### The sibling gateway client differs in one byte

The gateway's generator `kanidm-oauth2-sso` writes the secret with `printf '%s' "$(openssl rand -hex 32)"` to strip the trailing newline, because `kanidm-provision` trims the stored `basic_secret` but `oauth2-proxy` reads `--client-secret-file` verbatim and a 65th byte fails the token exchange (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/sso-gateway.nix:374-392`).
The Synapse generator does not strip the newline (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:118-120`).
Which form an Omnigent generator needs depends on whether Omnigent trims the secret it reads from its secret file; that is an upstream question (see Questions).

## 3. PostgreSQL

### Shared instance and consumers

Gitea uses `database.type = "postgres"`, `host = "/run/postgresql"`, and `port = 5432` on the shared instance (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/gitea.nix:76-81`).
niks3 and nixbot each set `database.createLocally = true` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/niks3.nix:81` and `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/nixbot.nix:146`).
No module pins `services.postgresql.package` or a `postgresql_NN` attribute, so the server version follows the nixpkgs default for the pinned channel.

### Matrix: Unix socket, `ensureDatabases`, `ensureUsers`

Synapse connects with `database = "matrix-synapse"`, `user = "matrix-synapse"`, `host = "/run/postgresql"`, and `allow_unsafe_locale = true` to accept the system-locale database created by `ensureDatabases` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:229-243`).
The module adds `services.postgresql.ensureDatabases = [ "matrix-synapse" ]` and `ensureUsers = [ { name = "matrix-synapse"; ensureDBOwnership = true; } ]`, with a comment that this auto-merges with the shared instance configured by Gitea and Buildbot (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:358-372`).
This is the socket-authenticated pattern: the system user name equals the database role name and no password is needed.

### Cognee: loopback TCP with a generated password

Cognee sets `database.createLocally = true`, `database.host = "127.0.0.1"`, and `vectorStore.backend = "pgvector"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:99-106`).
It forces `settings.listen_addresses = "127.0.0.1"`, sets `password_encryption = "scram-sha-256"`, and prepends `host cognee cognee 127.0.0.1/32 scram-sha-256` and the `::1/128` equivalent to `authentication` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:191-201`).
The role password is set idempotently by an `ExecStartPost` on `postgresql-setup.service` that reads the plaintext file and pipes `ALTER ROLE` to `psql` over stdin so the password does not appear in argv (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:204-225`).
The generator `cognee-db-password` emits `password` owned by `postgres` and `env` owned by `cognee`, both restarting `cognee.service` and `postgresql.service`, from one `openssl rand -hex 32` value (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:49-69`).
The `env` file is delivered through `environmentFile` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:164`).
A build-time assertion rejects any bind address that is not loopback or the ZeroTier prefix, because `ip_nonlocal_bind = 1` would let a wrong public bind succeed silently (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:167-183`).
The cognee module is defined but not imported on `magnetite` at this revision (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:39-57`).

### Backups

No `services.postgresqlBackup`, `pg_dump`, or `borgbackup` configuration exists under `modules/nixos/` or the magnetite machine directory at this revision.
The Buzz self-hosting note independently records that a search for `postgresqlBackup|borgbackup|clan\.core\.state` under `modules/` returned zero matches on 2026-08-04, and names backups as a prerequisite for any new stateful service, listing Gitea, Kanidm, Matrix, and cognee as already lacking them (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md:148-152` and `:167`).
The only backup-like mechanisms present are Kanidm's `online_backup.versions = 7` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:152`) and the ZFS hourly, daily, and weekly snapshots on the root dataset (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:171-176`), neither of which leaves the host.

## 4. Native OIDC versus the shared SSO gateway

The `sso-gateway` module header states the rule: use the gateway for services with no OIDC of their own, and give a service with built-in OIDC its own per-service Kanidm client modeled on `services.kanidm.provision.systems.oauth2.synapse`, because routing such a service through `sso.services.*` would double-gate it (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/sso-gateway.nix:18-23`).
The `sso.services` option description repeats the same rule (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/sso-gateway.nix:288-297`).
Each registered service emits a `forceSSL` and `enableACME` vhost with `auth_request /oauth2/auth` wiring (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/sso-gateway.nix:83-95`).
The gateway auto-derives a Kanidm group stub with `overwriteMembers = false` for every `allowedGroups` entry, a per-group `scopeMaps` of `openid`, `email`, `profile`, and a `claimMaps.groups` with `joinType = "array"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/sso-gateway.nix:464-491`).
Its `oauth2-proxy-kanidm` unit is `DynamicUser = true` and receives both secrets through `LoadCredential = [ "client-secret:..." "cookie-secret:..." ]` referenced as `%d/client-secret` and `%d/cookie-secret` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/sso-gateway.nix:430-443`).
On `magnetite`, `sso.enable = false`, so the gateway unit, its Kanidm client, and its vhosts are not emitted even though the module is imported (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:126`).
`sso.rootRedirectUrl = "https://accounts.scientistexperience.net/"` and an `sso.services.cognee` registration remain declared but inert under `sso.enable = false` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:133` and `:144-146`).

## 5. Ingress, ZeroTier, and DNS

### Public nginx vhosts

Kanidm: `enableACME = true`, `forceSSL = true`, `proxyPass = "https://127.0.0.1:8443"`, `proxyWebsockets = true` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:281-285`).
Matrix: one vhost with `enableACME = true` and `forceSSL = true`, multiple `proxyPass` locations to `127.0.0.1` ports, and a LiveKit location with `recommendedProxySettings = true` and `proxyWebsockets = true` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:470-513`).
Gitea: `forceSSL = true`, `enableACME = true`, `proxy_pass http://localhost:3002` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/gitea.nix:132-135`).
Buildbot: `domain = "buildbot.scientistexperience.net"`, `useHTTPS = true`, and a vhost with `forceSSL = true` and `enableACME = true` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/buildbot.nix:106-107` and `:178-180`).
The `srvos.nixosModules.mixins-nginx` import supplies the nginx baseline on the host (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:32`).

### Caddy

Caddy is enabled only in the `cinnabar` machine module, where it serves `kanban.zt`, `matrix.zt`, `ntfy.zt`, `radicle.zt`, and `hermes.zt` with `tls internal` and `reverse_proxy` to loopback ports (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/cinnabar/caddy.nix:12-78`).
Its listen addresses are the literal cinnabar ZeroTier IPv6 and IPv4 addresses (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/cinnabar/caddy.nix:6-9`).
It sets both `ip_nonlocal_bind` sysctls and opens TCP `443` only on `zt+` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/cinnabar/caddy.nix:94-100`).
No Caddy configuration exists for `magnetite`; magnetite's public ingress is nginx only.

### ZeroTier-only listener conventions on magnetite

The pattern on magnetite is: bind the service to `magnetite.zt` from `flake.lib.hosts`, open the port under `networking.firewall.interfaces."zt+".allowedTCPPorts`, and rely on the host-level `ip_nonlocal_bind = 1` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:391-392`, `:431`, and `:453-455`).
Cognee adds the build-time no-public-bind assertion described in section 3 (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:167-183`).
Public and mesh reachability are two separate firewall lists; a port added only to `interfaces."zt+"` is not reachable from the public interface (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:444-455`).

### Cloudflare DNS

The zone is discovered through `data.cloudflare_zone.scientistexperience` with `name = "scientistexperience.net"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/terranix/cloudflare.nix:38-40`).
Each magnetite service record is a `CNAME` to `magnetite.scientistexperience.net` with `ttl = 1` and `proxied = false`: `niks3`, `buildbot`, `nixbot`, `git`, `matrix`, `accounts.scientistexperience.net`, the cognee `kb` FQDN read from `flake.lib.cognee.publicFqdn`, and `auth.scientistexperience.net` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/terranix/cloudflare.nix:52-133`).
The `accounts` record uses the literal FQDN form and cites an ADR-0023 hostname convention (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/terranix/cloudflare.nix:102-110`).
`proxied = false` is stated as the condition for ACME issuance to work (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/terranix/cloudflare.nix:114` and `:125`).
No `omni` record exists at this revision.
An `omni.scientistexperience.net` record would follow the `accounts` shape: `resource.cloudflare_dns_record.omni` with `type = "CNAME"`, `content = "magnetite.scientistexperience.net"`, `ttl = 1`, `proxied = false`.

## 6. Clan vars generator conventions

Generators are declared inline in the owning NixOS module under `clan.core.vars.generators.<name>` and consumed through `config.clan.core.vars.generators.<name>.files."<file>".path` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:106-121` and `:211`).
Per-file attributes in use are `secret`, `owner`, `group`, `mode`, and `restartUnits` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:107-115`).
`restartUnits` lists every real consumer of the file, including the provider (`kanidm.service`) and the consumer (`matrix-synapse.service`), so rotation re-runs provisioning and refreshes the consumer's `LoadCredential` snapshot (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:98-104` and `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:328-336`).

### Example A: script generator with two consumers

`kanidm-oauth2-synapse` is a script generator with `runtimeInputs = [ pkgs.openssl ]` and `script = ''openssl rand -hex 32 > "$out/secret"''` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:106-121`).
The provider reads it host-side as `basicSecretFile` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:211`).
The consumer receives it through systemd `LoadCredential` at `/run/credentials/matrix-synapse.service/oidc-secret` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:344-346` and `:306`).

### Example B: prompt generator producing an `EnvironmentFile`

`omnigraph-r2` declares `prompts.access-key` and `prompts.secret-key` with `type = "hidden"` and `persist = true`, and a script that writes `AWS_ACCESS_KEY_ID=...` and `AWS_SECRET_ACCESS_KEY=...` lines from `$prompts/<name>` into `$out/env` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:328-365`).
The `env` file is consumed by `services.omnigraph.environmentFile` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:395`), which the Omnigraph module passes to systemd as `EnvironmentFile` alongside an optional `LoadCredential` for a bearer token (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/omnigraph.nix:28` and `:625-626`).
Cognee's `cognee-db-password` is the corresponding script-generated `env` example, emitting `DB_PASSWORD=<value>` and consumed via `environmentFile` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:49-69` and `:164`).

### Ownership rule of thumb in use

A file read host-side by a service running as a static user is owned by that user with mode `0400` or `0440` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:109-111`).
A file consumed only through `LoadCredential` does not need consumer-side ownership because credential staging is root-side, which is why a `DynamicUser` gateway can read a `kanidm`-owned secret (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/sso-gateway.nix:366-373` and `:431`).

## 7. Packaging, module discovery, and flake inputs

### Package layout

There is no `pkgs/by-name/README.md` and no `pkgs/README.md` at this revision.
Custom packages are discovered by `pkgs-by-name-for-flake-parts` with `pkgsDirectory = ../../pkgs/by-name` and `pkgsNameSeparator = "-"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixpkgs/default.nix:13-16` and `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixpkgs/per-system.nix:51-52`).
The directory is flat, one directory per package name, with nested directories joined by `-`: `pkgs/by-name/omnigraph/package.nix` yields `omnigraph`, and `pkgs/by-name/buzz/cli/`, `buzz/source/`, `buzz/git-credential-nostr/`, and `buzz/git-sign-nostr/` yield `buzz-cli`, `buzz-source`, and so on (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/tools/commands/dev/buzz.nix:42` references `pkgs.buzz-cli`).
The repository does not use nixpkgs' two-letter shard directories; the charter's proposed path `pkgs/by-name/om/omnigent/` does not match this layout (see Flags).
The composed overlay `flake.overlays.default` exposes these packages to machine configurations through `nixpkgs.overlays = [ inputs.self.overlays.default ]` in the base defaults (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixpkgs/compose.nix:20-21` and `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixpkgs/base-defaults.nix:23`).

### Binary proxy derivation precedent

`worktrunk-bin` is a `stdenv.mkDerivation` over `fetchurl` of a per-platform GitHub release asset selected by `stdenv.hostPlatform.system`, with per-platform hashes and `autoPatchelfHook` on Linux (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:pkgs/by-name/worktrunk-bin/package.nix:3-46`).
`mergify-cli-bin` and `uncomment-bin` are further `-bin` packages in the same directory.

### Source build precedent

`omnigraph` is a `rustPlatform.buildRustPackage` with `fetchFromGitHub`, a pinned `rev` and `hash`, an unstable-dated version string, and native inputs `protobuf`, `cmake`, and `pkg-config` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:pkgs/by-name/omnigraph/package.nix:5-18`).
Both `omnigraph` and `atomic` ship an `update.sh` beside `package.nix`.

### `mkPackageOption` and module discovery

The Omnigraph NixOS module owns its package with `package = lib.mkPackageOption pkgs "omnigraph" { };` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/omnigraph.nix:212`).
The Atomic home module uses the same form, `lib.mkPackageOption pkgs "atomic" { }`, and its header explains that the overlay is what makes the custom package resolvable from `pkgs` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/atomic/default.nix:7` and `:53`).
Every `.nix` file under `modules/` is a flake-parts module discovered by `import-tree`, and a new file must be tracked by git before a flake build can see it (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/README.md:8` and `:13`).
NixOS service modules assign `flake.modules.nixos.<name>` and are then named in a machine's `with flakeModules; [ ... ]` list (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:16` and `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:39-57`).

### Flake inputs

Inputs are declared in the `inputs = { ... };` block of `flake.nix` with `nixpkgs` on `nixos-unstable-small` and stable fallbacks on `26.05` channels (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:flake.nix:8-13`).
Inputs use `github:owner/repo[/ref]` URLs with `inputs.nixpkgs.follows = "nixpkgs"` and `treefmt-nix` follows where applicable (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:flake.nix:56-68`).
Personal or fork inputs already present are `cameronraysmith/cognee-nix/cognee-v112`, `cameronraysmith/playwright-web-flake/fix-webkit-darwin-mac15-arm64`, and `cameronraysmith/easykubenix/dev` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:flake.nix:60`, `:107`, and `:137`).
Third-party agent tooling arrives as `llm-agents.url = "github:numtide/llm-agents.nix"` and `hermes-agent.url = "github:NousResearch/hermes-agent/main"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:flake.nix:113` and `:125`).
`worktrunk` is both a flake input pinned to `v0.65.0` and a `-bin` package at `0.76.0`, so the two coexist (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:flake.nix:119` and `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:pkgs/by-name/worktrunk-bin/package.nix:32`).
No `Qubasa/infra`, `Lassulus`, or `omnigent-ai/omnigent` input exists at this revision.

## 8. Buzz, omp, and Atomic

### Buzz

Buzz is a home-manager wrapper, not a NixOS service: it installs a `buzz` wrapper only when `sops.secrets.buzz-nsec.path` exists, exports `BUZZ_PRIVATE_KEY` from that file, defaults `BUZZ_RELAY_URL` to `https://cameron.communities.buzz.xyz`, and `exec`s `pkgs.buzz-cli` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/tools/commands/dev/buzz.nix:19-42`).
The Buzz source is pinned to `block/buzz` tag `desktop-v0.5.20` with a fixed hash, plus a second pinned `rev` `95154bee4034ca7a40b33095c2ddbde8c9aa1614` for an auxiliary fetch (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:pkgs/by-name/buzz/source/package.nix:33-52`).
No server-side Buzz relay or bridge exists under `modules/nixos/`, `modules/clan/`, or any machine directory at this revision.
The self-hosting decision note recommends against self-hosting a relay now and remaining a chat tenant on Block's relay (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md:44-47`).

### omp

`programs.omp` is declared in the repository's own module, with `package` defaulting to `flake.inputs.llm-agents.packages.${system}.omp` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/omp/default.nix:62-68`).
The header states the upstream home-manager module is deliberately not imported because it writes `~/.omp/agent/config.yml` as a read-only store symlink while omp mutates that file at runtime (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/omp/default.nix:9`).

### Atomic

`programs.atomic` owns its package through `lib.mkPackageOption pkgs "atomic" { }` and installs it with `home.packages = lib.mkIf cfg.enable [ cfg.package ]` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/atomic/default.nix:50-53` and `:79`).
Its `settings.json` is merged rather than installed, because Atomic writes its own keys into the same file (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/atomic/default.nix:11-23`).
The Atomic package carries a `manifest.json`, an `npm-dist-repairs.patch`, and an `update.sh`, indicating an npm-distribution build rather than a `-bin` proxy.

### Relevance

All three surfaces are client-side under `modules/home/`; none defines a `services.*` NixOS option or a systemd system service.
An Omnigent server module would be the first server-side component in this cluster, and any Buzz relationship in the plan would be a client-to-relay relationship rather than a co-deployed service.

## 9. Documentation and formatting

`docs/README.md` is a symlink to the repository root `README.md` (commit "docs: symlink README.md"), so it carries the project README rather than a notes index (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/README.md`).
There is no `README.md` under `docs/notes/`, `docs/notes/development/`, or `docs/notes/development/omnigent/`.
Published documentation lives under `packages/docs/`, and `docs/` holds working notes (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/plugins/agent-context-vanixiets/.apm/instructions/10-repository-overview.instructions.md:20-22`).
The Buzz self-hosting note uses frontmatter `title`, `status: working-note`, `date`, a single `#` title, and `##` sections ending with `## Open questions` and `## Source material caveats` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md:1-7` and `:378-410`).
The sibling research note `qubasa-infra.md` on the plan branch ends with `## Flags`, `## Additional sources acquired`, and `## Questions`, which this note mirrors.
treefmt enables only `programs.nixfmt`, and the prek hook set is treefmt plus a staged-diff gitleaks scan (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/formatting.nix:11-29`).
No Markdown formatter or linter runs over `docs/` at this revision; `just docs-lint` and `just docs-check` operate only inside `packages/docs` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:justfile:729-735`).
`.pre-commit-config.yaml` in the working tree is generated by git-hooks.nix and gitignored, consistent with the repository instruction that hooks are declared in `modules/formatting.nix` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:.gitignore:8` and `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/plugins/agent-context-vanixiets/.apm/instructions/10-repository-overview.instructions.md:33`).

## 10. Verification surfaces for a future module and package

### Existing check emitters

`modules/checks/machines.nix` emits `checks.<system>.nixos-<machine>` as `nixosConfigurations.<machine>.config.system.build.toplevel` for every NixOS inventory machine whose system matches, so the machine check for this host is `checks.x86_64-linux.nixos-magnetite` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/checks/machines.nix:35-41`).
That file also asserts that inventory names match `nixosConfigurations` and `flake.lib.machineSystems` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/checks/machines.nix:26-34`).
`modules/checks/packages.nix` emits `checks.<system>.package-<name>` for every `self'.packages` entry not in its blacklist (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/checks/packages.nix:36-39`).
`modules/checks/package-tests.nix` emits `checks.<system>.package-<pname>-test-<tname>` for each `passthru.tests` entry (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/checks/package-tests.nix:40`).
The repository instruction names the direct-build form `nix build .#checks.<system>.<name>` as the narrowest useful selection and names `just check-fast` as the normal full loop (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/plugins/agent-context-vanixiets/.apm/instructions/10-repository-overview.instructions.md:30-36`).

### Exact paths a plan can name

Package realization: `nix build .#packages.x86_64-linux.omnigent` and its check alias `nix build .#checks.x86_64-linux.package-omnigent`, both of which come into existence automatically when `pkgs/by-name/omnigent/package.nix` is tracked (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixpkgs/per-system.nix:51-52` and `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/checks/packages.nix:39`).
Module evaluation: `nix eval .#nixosConfigurations.magnetite.config.services.omnigent --json` for the option tree, and targeted evals such as `nix eval .#nixosConfigurations.magnetite.config.services.kanidm.provision.systems.oauth2 --apply builtins.attrNames`, `nix eval .#nixosConfigurations.magnetite.config.services.nginx.virtualHosts --apply builtins.attrNames`, `nix eval .#nixosConfigurations.magnetite.config.services.postgresql.ensureDatabases`, and `nix eval .#nixosConfigurations.magnetite.config.networking.firewall.interfaces --json`, following the `nix eval ... --apply builtins.attrNames --json` idiom the justfile uses for output discovery (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:justfile:116-129`).
Generator evaluation: `nix eval .#nixosConfigurations.magnetite.config.clan.core.vars.generators --apply builtins.attrNames --json` to confirm a `kanidm-oauth2-omnigent` generator is declared, without running any `clan vars` command.
Host closure: `nix build .#checks.x86_64-linux.nixos-magnetite` or equivalently `nix build .#nixosConfigurations.magnetite.config.system.build.toplevel`, which is the same derivation (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/checks/machines.nix:38`).
Dry-run cache preview: `just check-uncached nixosConfigurations.magnetite.config.system.build.toplevel` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:justfile:53-60`).
Terranix: the existing `checks.aarch64-darwin.terraform-validate` in `just test-quick` covers a new Cloudflare record's syntax (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:justfile:657`).
Secrets scan: `nix build .#checks.<system>.gitleaks` covers any newly committed file (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/plugins/agent-context-vanixiets/.apm/instructions/10-repository-overview.instructions.md:35-36`).

## Flags

F1 Stale comment versus code on `sso.enable`: the comment block at `modules/machines/nixos/magnetite/default.nix:120-125` describes the gateway as active with cognee as consumer #1, but line 126 sets `sso.enable = false`; `git blame` dates the comment to `f07466bcf0` (2026-06-19) and the disable to `378364579` (2026-06-20, "disable self-hosted cognee server + SSO gateway (reversible; config retained)"), so the code is newer and governs (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:120-126`).
F2 Charter path versus repository layout: the charter proposes `pkgs/by-name/om/omnigent/`, but the repository's `pkgs/by-name` is flat with no two-letter shards, so the conforming path is `pkgs/by-name/omnigent/package.nix` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixpkgs/per-system.nix:51-52`; charter line 103 on the plan branch).
F3 Retained-but-inert cognee surfaces: `sso.services.cognee`, the `kb` and `auth` DNS records, and the `/var/lib/cognee` dataset remain declared although the cognee module is not imported on magnetite; a plan that reuses `auth.scientistexperience.net` or the gateway must account for this retained state (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:144-146`, `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/terranix/cloudflare.nix:115-133`, `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/disko.nix:77-79`).
F4 Trailing-newline divergence between the two OAuth2 secret generators: `kanidm-oauth2-synapse` leaves a newline and `kanidm-oauth2-sso` strips it for a verbatim reader; the correct form for `kanidm-oauth2-omnigent` depends on Omnigent's secret-file handling (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:118-120` and `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/sso-gateway.nix:385-392`).
F5 No PostgreSQL backup exists on the fleet, and the Buzz note already names this as a prerequisite for any new stateful service (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md:148-152`).
F6 Stale host list in `just check-uncached-machine`: its `nixos_hosts` array is `cinnabar electrum galena scheelite` and omits `magnetite` and `pyrite`, so the generic `just check-uncached <config>` form must be used for magnetite (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:justfile:34-35`).
F7 Buildbot's memory budget comment enumerates postgres, matrix, and nginx but not Omnigraph or any future Omnigent sandboxes, so host memory headroom for Omnigent is uncounted (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/buildbot.nix:161-165`).
F8 No Markdown formatter or linter covers `docs/`, so the plan's prose conventions are enforced by review rather than tooling (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/formatting.nix:11-14`).

## Additional sources acquired

None.
All findings come from the vanixiets working tree at the axis revision; no external repository was cloned for this axis.

## Questions

Q1 Does Omnigent read its OIDC client secret from a file verbatim or trim it, which decides whether the `kanidm-oauth2-omnigent` generator follows the Synapse form or the `printf '%s'` gateway form (F4)?
Q2 Should Omnigent connect to PostgreSQL over the Unix socket as a static system user matching its role name, as Matrix does, or over loopback TCP with a generated password, as cognee does; the answer depends on whether Omnigent runs as a static user or `DynamicUser` and whether its database client supports peer authentication.
Q3 Is a PostgreSQL backup a hard precondition for deploying Omnigent on magnetite, given that none exists for Gitea, Kanidm, Matrix, or any other tenant (F5)?
Q4 Should `omni.scientistexperience.net` be public nginx with ACME and `forceSSL`, following Kanidm and Matrix, or a ZeroTier-only listener, following Omnigraph and cognee; the two patterns differ in DNS, firewall list, and TLS source.
Q5 Should the charter's `pkgs/by-name/om/omnigent/` be corrected to `pkgs/by-name/omnigent/` in the plan (F2)?
Q6 Should Omnigent gate on a new `omnigent_users` group with `overwriteMembers = false` and operational membership, mirroring `matrix_users`, or reuse `matrix_users`?
Q7 What memory and CPU budget does the plan reserve for Omnigent and its sandboxes on a host whose existing sizing comment leaves roughly 24 GiB after CI eval workers (F7)?
