---
title: Research axis nixpkgs-modules
status: working-note
date: 2026-09-06
---

# Research axis: nixpkgs modules

Axis revision: `github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442`, the `nixos-unstable-small` tarball pinned by the vanixiets `flake.lock` root `nixpkgs` node, commit date 2026-08-04 16:03:19 +0000, `.version` `26.11`.
Consumer revision: `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65`; the cited vanixiets files are byte-identical at the current branch head `4d84c821f059932b85a6a14cac7a92c0b9ab6f2f` (`git diff --stat 590f751 HEAD -- modules/ flake.nix flake.lock` is empty).
Where a finding is an inference from cited facts rather than a cited fact, the sentence says so.

## Scope and method

Modules were read from the local reference clone at the pinned revision (`git rev-parse HEAD` prints `85f62611fa3f3eacbcfe3bc7a6d6518b443ca442`).
Every option surface below was confirmed against the declaration lines cited, not against generated documentation.
Nix evaluation was used only to resolve flake input store paths (`nix eval --raw .#inputs.<name>.outPath`) for srvos and buildbot-nix; no NixOS configuration was evaluated, and the one evaluated fact referenced (`security.allowUserNamespaces = true` on `magnetite`) is inherited from `deployment-plan.md:27` and is not re-derived here.
systemd semantics that NixOS does not itself define are cited to the systemd 261 manual pages, matching the `systemd` package version `261.1` at the pin (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:pkgs/os-specific/linux/systemd/default.nix:206`).

## 1. PostgreSQL shared instance (plan D3)

### Option surface

- F1 `services.postgresql.ensureDatabases` is `listOf str`, default `[]`, and creates each database only when `SELECT 1 FROM pg_database` finds none (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:421-435` and `:915-917`); it never deletes databases.
- F2 `services.postgresql.ensureUsers` is a `listOf submodule` whose options are `name : str`, `ensureDBOwnership : bool` default `false`, and `ensureClauses`, a freeform attrset of `str`, `int`, or `bool` values default `{}` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:436-490`).
- F3 `ensureDBOwnership = true` emits `ALTER DATABASE "<name>" OWNER TO "<name>"` and asserts that `<name>` also appears in `ensureDatabases` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:99-116` and `:625-637`).
- F4 `CREATE DATABASE` is issued with no locale or encoding arguments, so an ensured database inherits the cluster defaults; the vanixiets Synapse module documents the consequence (`en_US.UTF-8` collation rather than `C`) and works around it with `allow_unsafe_locale` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:915-917`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:229-243`).
- F5 `services.postgresql.settings` is a submodule with freeform type `attrsOf (oneOf [ bool float int str ])` and named options `shared_preload_libraries`, `log_line_prefix` (default `[%p] `), and `port` (default `5432`) (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:531-575`).
- F6 The module sets `settings.listen_addresses` to `"*"` when `enableTCPIP` is true and `"localhost"` otherwise, with ordinary priority rather than `mkDefault`, which is why the cognee module needs `lib.mkForce "127.0.0.1"` to change it (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:643`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:191-195`).

### Authentication and socket

- F7 The default `pg_hba.conf` tail is `local all postgres peer map=postgres`, `local all all peer`, `host all all 127.0.0.1/32 md5`, `host all all ::1/128 md5`, appended with `mkAfter` so consumer rules placed earlier win under first-match semantics (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:688-697`).
- F8 Peer authentication over the Unix socket therefore admits a database role whose name equals the connecting Unix user, which is the contract `ensureUsers` documents (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:488-500`); an `omnigent` system user reaching an `omnigent` role needs no password.
- F9 The pinned PostgreSQL packages are patched so `DEFAULT_PGSOCKET_DIR` is `/run/postgresql`, and the unit declares `RuntimeDirectory = "postgresql"` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:pkgs/servers/sql/postgresql/patches/socketdir-in-run-13+.patch:8`; `nixos/modules/services/databases/postgresql.nix:789`); Synapse and Gitea on `magnetite` already connect with `host = "/run/postgresql"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:239-242`; `modules/nixos/gitea.nix:76-79`).

### Package default by `system.stateVersion`

- F10 `services.postgresql.package` defaults through `mkDefault` to `postgresql_18` for `stateVersion >= 26.11`, `postgresql_17` for `>= 25.11`, `postgresql_16` for `>= 24.11`, `postgresql_15` for `>= 23.11`, and `postgresql_14` for `>= 22.05`, throwing for older versions (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:647-684`).
- F11 `magnetite` declares `system.stateVersion = "25.05"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:74`), so the pinned module selects `pkgs.postgresql_16`, and `dataDir` defaults to `/var/lib/postgresql/16` via `psqlSchema` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:686`).
- F12 No vanixiets module or imported input on `magnetite` sets `services.postgresql.package`: `git grep` over `modules/nixos` finds only `matrix.nix:364` and `cognee.nix:191` assigning `services.postgresql`, neither sets `package`, and the buildbot-nix master module that enables PostgreSQL does not either (`github:nix-community/buildbot-nix@d193d375fe5c4be29f13dc34552903cae6813b07:nixosModules/master.nix:1081-1090`).
- F13 The module also emits a `warn` whenever the package is not pinned, naming the selected major as "the next that will be removed when EOL on the next stable cycle" (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:650-659`); the plan's PostgreSQL major is therefore 16 until either `stateVersion` or an explicit `package` changes, and a `psycopg` connection from Omnigent targets a 16 server.

### Additive behaviour on an already-enabled host

- F14 PostgreSQL on `magnetite` is enabled by the buildbot-nix master module with `enable = true` plus `ensureDatabases = [ "buildbot" ]` and an `ensureDBOwnership` user (`github:nix-community/buildbot-nix@d193d375fe5c4be29f13dc34552903cae6813b07:nixosModules/master.nix:1081-1090`), and the vanixiets Synapse module adds `ensureDatabases = [ "matrix-synapse" ]` and a matching owner without touching `enable` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:364-372`).
- F15 Because `ensureDatabases` is a list option and `ensureUsers` is a list of submodules, definitions from several modules concatenate under normal module merging, and `package`, `dataDir`, and `jit` are `mkDefault` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:644`, `:684`, `:686`); an Omnigent module that only appends `ensureDatabases = [ "omnigent" ]` and an owner entry merges additively and does not disable, replace, or re-initialise the shared instance.
- F16 The nixpkgs Gitea module shows the upstream idiom for a consumer that also enables the server: `services.postgresql.enable = mkDefault true` beside its own `ensureDatabases`/`ensureUsers` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/misc/gitea.nix:736-747`); the vanixiets precedent (F14) omits `enable` entirely, and either form is additive.
- F17 The cognee module is defined but is not in the `magnetite` import list at the consumer revision (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:39-57`), so its `mkForce "127.0.0.1"` on `listen_addresses` and its `scram-sha-256` rules are not currently active on `magnetite`, and the shared instance listens on `localhost` per F6.

### Readiness ordering

- F18 Ensured databases and users are created by `postgresql-setup.service`, a `oneshot` with `RemainAfterExit = true` that is `requires`/`after` `postgresql.service` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:870-881`).
- F19 `postgresql.target` `requires` both `postgresql.service` and `postgresql-setup.service`, and `postgresql.service` is `partOf` and `wants` the target (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/databases/postgresql.nix:744-752` and `:762-763`).
- F20 A unit ordered only `after = [ "postgresql.service" ]` can start before the `omnigent` database or role exists; ordering on `postgresql.target` is what buzz-flake and buildbot-nix do (`github:nix-community/buildbot-nix@d193d375fe5c4be29f13dc34552903cae6813b07:nixosModules/master.nix:1047`), and it is the ordering that guarantees the ensured objects exist when Omnigent runs Alembic at startup.

## 2. nginx reverse proxy (plan D6)

### Option surface

- F21 Location `proxyPass` is `nullOr str` default `null` and emits `proxy_pass <value>;` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/web-servers/nginx/location-options.nix:37-45`; `default.nix:538-540`).
- F22 Location `proxyWebsockets` is `bool` default `false` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/web-servers/nginx/location-options.nix:47-55`).
- F23 Location `extraConfig` is `lines` default `""`, placed verbatim after the generated directives and before the recommended-header include (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/web-servers/nginx/location-options.nix:126-132`; `default.nix:566-569`).
- F24 Location `recommendedProxySettings` is `bool` defaulting to the module-level `services.nginx.recommendedProxySettings`, which is itself `bool` default `false` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/web-servers/nginx/location-options.nix:144-151`; `default.nix:666-672`).
- F25 Module-level `services.nginx.proxyTimeout` is `str` default `"60s"` and is consumed only by the module-level `recommendedProxySettings` block (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/web-servers/nginx/default.nix:674-681`).
- F26 Virtual-host `enableACME` is `bool` default `false`; `forceSSL` is `bool` default `false`; `http2` is `bool` default `true`; vhost `extraConfig` is `lines` default `""` appended to the server block (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/web-servers/nginx/vhost-options.nix:111-120`, `:173-184`, `:227-240`, `:303-310`).
- F27 `forceSSL = true` emits a separate plain-HTTP `server` block returning a redirect to `https://$host$request_uri` alongside the ACME challenge location (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/web-servers/nginx/default.nix:479-490`).

### What `proxyWebsockets = true` emits

- F28 Inside the location block the module emits exactly three directives: `proxy_http_version 1.1;`, `proxy_set_header Upgrade $http_upgrade;`, and `proxy_set_header Connection $connection_upgrade;` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/web-servers/nginx/default.nix:545-549`), with the `map $http_upgrade $connection_upgrade` block defined at `http` level (`default.nix:311-312`).
- F29 It emits no timeout directive; the 60-second default read timeout is why superconfig's Omnigent vhost adds `proxy_read_timeout 1d;` and `proxy_send_timeout 1d;` in location `extraConfig` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:180-189`).

### What `recommendedProxySettings` emits

- F30 With the module-level option true, the `http` block gains `proxy_redirect off`, `proxy_connect_timeout`, `proxy_send_timeout`, and `proxy_read_timeout` set to `proxyTimeout`, `proxy_http_version 1.1`, `proxy_set_header "Connection" ""`, and an `include` of a header file setting `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`, `X-Forwarded-Host`, and `X-Forwarded-Server` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/web-servers/nginx/default.nix:105-112` and `:275-285`).
- F31 With the location-level option true and `proxyPass` set, the location re-includes the same header file after `extraConfig` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/web-servers/nginx/default.nix:566-569`); this matters because nginx `proxy_set_header` at location level replaces, rather than merges with, the `http`-level set, so a websocket location still forwards `Host` and `X-Forwarded-*`.
- F32 `magnetite` imports `srvos.nixosModules.mixins-nginx`, which sets `services.nginx.recommendedProxySettings = lib.mkDefault true` together with the other `recommended*` toggles (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:32`; `github:nix-community/srvos@a00436b148ec1c2f54f60e3973af197d7c7d8009:nixos/mixins/nginx.nix:9-17`), so F30 is already in effect for every vhost on the host and the plan's one-day timeouts must be location-level overrides of the `http`-level 60-second values.
- F33 Location-level `proxy_read_timeout`/`proxy_send_timeout` in `extraConfig` override the `http`-level values for that location only; raising module-level `proxyTimeout` instead would change every vhost on `magnetite` (F25, F30).

### Proxy buffering for SSE

- F34 No option in `default.nix`, `vhost-options.nix`, or `location-options.nix` mentions `proxy_buffering` or `X-Accel-Buffering` (`rg -n 'proxy_buffering|X-Accel' nixos/modules/services/web-servers/nginx/` returns nothing at the pin), and the generated configuration emits no buffering directive.
- F35 Disabling buffering therefore requires either location `extraConfig = "proxy_buffering off;"` (F23) or reliance on the upstream `X-Accel-Buffering: no` response header, which is nginx runtime behaviour honoured by default and not something the NixOS module configures or guarantees; superconfig relies on the header (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:180-183`).

### Consumer precedent

- F36 The Synapse vhost on `magnetite` uses `enableACME = true`, `forceSSL = true`, `proxyPass` to `127.0.0.1` ports, and a LiveKit location with `recommendedProxySettings = true` and `proxyWebsockets = true` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:470-513`); the public firewall opens TCP 22, 80, and 443 (`modules/machines/nixos/magnetite/default.nix:445-451`).

## 3. Unprivileged user namespaces and bubblewrap (plan D7)

- F37 `security.allowUserNamespaces` is `bool` default `true`; when false the module sets `boot.kernel.sysctl."user.max_user_namespaces" = 0` and asserts it is incompatible with `nix.settings.sandbox = true` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/security/misc.nix:15-32` and `:109-120`).
- F38 `security.unprivilegedUsernsClone` is a separate `bool` default `false` that, when true, sets `boot.kernel.sysctl."kernel.unprivileged_userns_clone" = true` with `mkDefault`, and its description states it only works in a hardened profile (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/security/misc.nix:34-42` and `:124-126`); on the stock kernel `magnetite` runs, `user.max_user_namespaces` via `allowUserNamespaces` is the governing control and `kernel.unprivileged_userns_clone` does not exist.
- F39 `security.allowUserNamespaces` is neither set nor referenced anywhere under `modules/` at the consumer revision (`git grep allowUserNamespaces 590f751 -- modules` returns nothing), consistent with the plan's evaluated `true`.
- F40 Bubblewrap at the pin is `0.11.2`, an ordinary `stdenv.mkDerivation` with `doCheck = false` because tests are incompatible with the Nix sandbox, described as "Unprivileged sandboxing tool", and the expression contains no setuid, `security.wrappers`, or capability installation (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:pkgs/by-name/bu/bubblewrap/package.nix:15-23` and `:50-60`); the installed `bwrap` therefore relies entirely on unprivileged user namespaces.
- F41 The Omnigent runner's bwrap argv always includes `--dev /dev`, `--tmpfs /tmp`, `--unshare-pid`, `--unshare-uts`, `--unshare-ipc`, `--die-with-parent`, and `--new-session`, adds `--unshare-net` when networking is disabled or egress relay rules apply, and on ordinary hosts mounts a fresh procfs with `--proc /proc` rather than binding the host `/proc` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:248-261`, `:440-458`, and `:608-631`).
- F42 The kernel features bubblewrap therefore needs from the runner's execution context are: `CLONE_NEWUSER` (user namespace creation, gated by `user.max_user_namespaces`), `CLONE_NEWNS`/`CLONE_NEWPID`/`CLONE_NEWUTS`/`CLONE_NEWIPC` and optionally `CLONE_NEWNET`, the `mount` family of syscalls for `proc`, `tmpfs`, and bind mounts, and a `/proc` in the runner's mount namespace without masked overmounts so that a fresh procfs mount succeeds inside the user namespace; the last point is the mechanism behind the ESPHome comments in F46 and is an inference from those comments and the Omnigent code, not a cited kernel-documentation fact.

## 4. systemd service properties and hardening for the server and runner

### NixOS surface

- F43 `systemd.services.<name>.serviceConfig` is `attrsOf unitOption` whose entries become `Key=value` lines in `[Service]`; NixOS validates only `Type` and `Restart` against enumerations and passes every other key through to systemd unchanged (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/lib/systemd-unit-options.nix:26-45` and `:386-397`; `nixos/lib/systemd-lib.nix:353-365` and `:764-813`).
- F44 `DynamicUser`, `StateDirectory`, `LoadCredential`, `EnvironmentFile`, `MemoryHigh`, `MemoryMax`, `RestrictNamespaces`, and `SystemCallFilter` are therefore all plain `serviceConfig` keys with no NixOS-level typing; list values serialise to one line per element (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/lib/systemd-lib.nix:353-365`), and an unknown or misspelled key is reported by systemd at unit load rather than by `nix build`.

### systemd 261 semantics used by the plan

- F45 Per `systemd.exec(5)` for 261 (<https://www.freedesktop.org/software/systemd/man/261/systemd.exec.html>): `DynamicUser=yes` allocates a transient UID/GID at start and implies `RemoveIPC=`, `NoNewPrivileges=`, `RestrictSUIDSGID=`, `ProtectSystem=strict`, and `ProtectHome=read-only`; `StateDirectory=` creates persistent directories below `/var/lib` and exports `$STATE_DIRECTORY`, and with `DynamicUser=` the directory lives under `/var/lib/private/<name>` with a symlink at `/var/lib/<name>`; `LoadCredential=` stages a read-only copy under `$CREDENTIALS_DIRECTORY`; `EnvironmentFile=` reads `KEY=value` lines before exec; `NoNewPrivileges=` blocks privilege gain via `execve` (setuid/setgid bits and file capabilities) and does not by itself prevent user-namespace creation; `RestrictNamespaces=` defaults to no restriction and accepts an allow- or deny-list of namespace types, with `yes` denying all; `SystemCallFilter=` kills the process with `SIGSYS` on a filtered call; `PrivateUsers=` itself creates a user namespace.
- F46 Per `systemd.resource-control(5)` for 261 (<https://www.freedesktop.org/software/systemd/man/261/systemd.resource-control.html>): `MemoryHigh=` and `MemoryMax=` are cgroup v2 memory controls accepted in `[Service]`, so the plan's `serviceConfig.MemoryHigh`/`MemoryMax` need no further NixOS plumbing.

### Precedents at the pin

- F47 The ESPHome service is the pinned nixpkgs precedent for a hardened unit whose child (`platformio`) invokes `bwrap`: it keeps `NoNewPrivileges = true`, `ProtectSystem = "strict"`, `ProtectProc = "invisible"`, `RestrictSUIDSGID = true`, and `SystemCallArchitectures = "native"`, but sets `RestrictNamespaces = false`, `ProtectHostname = false`, `ProtectKernelLogs = false`, `ProtectKernelTunables = false`, and `ProcSubset = "all"` each annotated "breaks bwrap", and its `SystemCallFilter` is `[ "@system-service" "@mount" ]` with `@mount` annotated as required for chroot (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/home-automation/esphome.nix:153-184`).
- F48 The same module deliberately uses a static system user instead of `DynamicUser` because the `/var/lib/esphome -> /var/lib/private/esphome` symlink broke path resolution inside the sandboxed toolchain (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/home-automation/esphome.nix:108-116`).
- F49 The Kanidm service is the contrasting precedent for a unit that never needs namespaces: its default hardening sets `PrivateUsers = true`, `RestrictNamespaces = true`, `ProcSubset = "pid"`, `ProtectKernelTunables = true`, and `SystemCallFilter = [ "@system-service" "~@privileged @resources @setuid @keyring" ]` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/security/kanidm.nix:90-136`), and this shape is also what buzz-flake's server hardening block resembles.
- F50 superconfig's Omnigent server unit (server only, no co-located runner) runs with `DynamicUser = true`, `StateDirectory = "omnigent"`, `EnvironmentFile` from a clan var, `NoNewPrivileges = true`, `ProtectSystem = "strict"`, and `ProtectKernelTunables = true` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:155-171`).

### Interaction for the runner unit (`omnigent host <server-url>`)

- F51 `NoNewPrivileges = true` is compatible with the runner: `bwrap` at the pin is setuid-free (F40) and user-namespace creation is not a privilege gain via `execve` (F45), and ESPHome keeps it enabled beside `bwrap` (F47).
- F52 `RestrictNamespaces` must be absent or `false` for the runner, because `yes` denies the `CLONE_NEWUSER`/`CLONE_NEWNS`/`CLONE_NEWPID`/`CLONE_NEWUTS`/`CLONE_NEWIPC`/`CLONE_NEWNET` flags bubblewrap passes (F41, F45); a minimum allow-list would be `RestrictNamespaces = [ "user" "mnt" "pid" "uts" "ipc" "net" ]`, which is an inference from F41 and F45 that no pinned module demonstrates.
- F53 A `SystemCallFilter` for the runner must not exclude `@mount` (or the `mount`, `umount2`, `pivot_root`, `unshare`, and `setns` calls it groups), since `@system-service` alone omits them; ESPHome's `[ "@system-service" "@mount" ]` is the cited working set (F47), and buzz-flake's `~@privileged` deny-list also removes `@mount`, `@setuid`, and `unshare`-adjacent calls, so that block is reusable for the server unit only.
- F54 `ProtectKernelTunables`, `ProtectKernelLogs`, `ProtectHostname`, and `ProcSubset = "pid"` each break `bwrap` per ESPHome (F47), which is consistent with Omnigent's fail-closed fresh `--proc /proc` mount (F41); a runner unit copying the server's hardening block would fail at the first sandboxed session even with `RestrictNamespaces` removed.
- F55 `PrivateUsers = true` on the runner would place the runner itself inside a user namespace whose UID map is a single identity mapping, so nested `bwrap` user namespaces would inherit that one-entry map; the summary evidence for this is `systemd.exec(5)` (F45) and no pinned module combines `PrivateUsers` with `bwrap`, so this remains unverified and is listed under Questions.
- F56 `DynamicUser` is not itself incompatible with bubblewrap, but it implies `ProtectSystem=strict` and `ProtectHome=read-only` (F45), rotates the UID across restarts so anything written outside `StateDirectory` becomes orphaned, and produces the `/var/lib/private` symlink that broke ESPHome's toolchain (F48); the plan's static `omnigent-host` user with a real home directory (D7) avoids all three, at the cost of the implicit hardening `DynamicUser` would add.
- F57 For the server unit (`omnigent serve`, no `bwrap`), either `DynamicUser = true` (superconfig, F50) or a static `omnigent` user works with `StateDirectory`; the plan's peer-authenticated PostgreSQL socket (F8) needs the connecting Unix username to equal the database role, and a `DynamicUser` name is stable (it equals the unit's `User=` or unit name) even though its UID is not, so peer auth is compatible with `DynamicUser` as long as `ensureUsers.name` matches that name.

## 5. Kanidm OAuth2 client provisioning

- F58 `services.kanidm.provision.systems.oauth2` is `attrsOf submodule` default `{}` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/security/kanidm.nix:584-588`).
- F59 The complete `systems.oauth2.<name>` option set at the pin, with types and defaults, is (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/security/kanidm.nix:590-726`, `mkPresentOption` at `:140-146`):
  `present : bool = true`;
  `public : bool = false`;
  `displayName : str` (required);
  `originUrl : either (strMatching ".*://?.*$") (nonEmptyListOf that)` (required);
  `originLanding : str` (required);
  `basicSecretFile : nullOr path = null`, documented "Do NOT use a path from the nix store here";
  `imageFile : nullOr path = null`;
  `enableLocalhostRedirects : bool = false`;
  `enableLegacyCrypto : bool = false`;
  `allowInsecureClientDisablePkce : bool = false`;
  `preferShortUsername : bool = false`;
  `scopeMaps : attrsOf (listOf str) = {}`;
  `supplementaryScopeMaps : attrsOf (listOf str) = {}`;
  `removeOrphanedClaimMaps : bool = true`;
  `claimMaps : attrsOf submodule = {}` with `claimMaps.<claim>.joinType : enum [ "array" "csv" "ssv" ] = "array"` and `claimMaps.<claim>.valuesByGroup : attrsOf (listOf str) = {}`.
- F60 Assertions at the pin: a `public` client cannot set `basicSecretFile` and cannot set `allowInsecureClientDisablePkce`; a non-public client cannot set `enableLocalhostRedirects`; every group named in `scopeMaps`, `supplementaryScopeMaps`, or `claimMaps.<claim>.valuesByGroup` must be a provisioned group; each claim map must have at least one group with values (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/security/kanidm.nix:880-926`).
- F61 Any non-null `basicSecretFile` (or admin password file) with provisioning enabled requires `cfg.package.enableSecretProvisioning`, otherwise evaluation fails with a message recommending `kanidm.withSecretProvisioning` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/security/kanidm.nix:834-849`); every `basicSecretFile` is also added to the service's read-only bind paths (`kanidm.nix:52-64`).
- F62 Provisioning runs from a post-start script that `curl`-polls the configured origin until it answers, recovers the `idm_admin` credential, and invokes `kanidm-provision` with the generated JSON (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/security/kanidm.nix:219-250`).
- F63 The pin provides `kanidm_1_8` through `kanidm_1_11` and `kanidmWithSecretProvisioning_1_8` through `_1_11`, where `kanidm_1_11` is `1.11.0` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:pkgs/top-level/all-packages.nix:7372-7397`; `pkgs/servers/kanidm/1_11.nix:1-3`); vanixiets uses `pkgs.kanidmWithSecretProvisioning_1_11` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:124`), so F61 is satisfied for a confidential Omnigent client.
- F64 The deployed `systems.oauth2.synapse` client sets `displayName`, `originUrl`, `originLanding`, `preferShortUsername = true`, `scopeMaps.matrix_users`, and `basicSecretFile` from a clan vars generator (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:183-212`); an `omnigent` client is a sibling attribute using the same six options plus, if desired, `claimMaps` for group-to-claim mapping.
- F65 The Kanidm unit's own hardening (`PrivateUsers = mkForce false` in the server unit, `RestrictNamespaces = true`, restrictive `SystemCallFilter`) is unaffected by adding a client and is not a template for the runner (F49; `github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/security/kanidm.nix:984`).

## 6. ZeroTier and mesh-only ingress

- F66 `services.zerotierone` exposes exactly `enable`, `joinNetworks : listOf str = []`, `port : port = 9993`, `package`, and `localConf` (a JSON settings submodule, default `{}`) (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/networking/zerotierone.nix:18-52`).
- F67 The module opens UDP `cfg.port` in the firewall, denies DHCP on `zt*`, and pins `MACAddressPolicy = "none"` for `zt*` links (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/networking/zerotierone.nix:90-110`); `joinNetworks` joins listed networks and does not leave removed ones (`zerotierone.nix:20-29`).
- F68 No ZeroTier option constrains another service to the overlay; mesh-only ingress for a runner or an admin surface is composed from the service's bind address plus `networking.firewall.interfaces.<iface>.allowedTCPPorts` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/networking/firewall.nix:297-303`) or `networking.firewall.trustedInterfaces` (`firewall.nix:164-173`), and `magnetite` already uses the interface form as `interfaces."zt+".allowedTCPPorts = [ 8090 ]` with a comment inviting service modules to append (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:452-455`).
- F69 The plan's D7 runner is an outbound client of the server (`omnigent host https://omni.scientistexperience.net`) and exposes no listener of its own, so ZeroTier is not on its path; ZeroTier becomes relevant only for a Q7 remote runner reaching a mesh-bound server URL, which this axis does not resolve.

## 7. Flake consumption of the pin

- F70 `flake.nix` declares root `nixpkgs` as `https://channels.nixos.org/nixos-unstable-small/nixexprs.tar.xz` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:flake.nix:8-13`), and `flake.lock` resolves root input `nixpkgs` to node `nixpkgs_9` with `locked.rev = 85f62611fa3f3eacbcfe3bc7a6d6518b443ca442`, `lastModified = 1785859399` (2026-08-04 16:03:19 UTC), and URL `https://releases.nixos.org/nixos/unstable-small/nixos-26.11pre1047825.85f62611fa3f/nixexprs.tar.xz` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:flake.lock`, node `nixpkgs_9`).
- F71 Inputs whose `nixpkgs` follows the root node include `buildbot-nix`, `disko`, `git-hooks`, `home-manager_2`, `niks3`, `nix-darwin`, `nixbot`, `nixos-hardware`, `sops-nix`, `srvos`, `terranix`, and `treefmt-nix_5` (twenty-eight nodes in total), so the buildbot-nix and srvos modules cited above evaluate against the same nixpkgs as the NixOS modules (`flake.lock`, `inputs.nixpkgs = ["nixpkgs"]` on those nodes).
- F72 `clan-core` does not follow root `nixpkgs` (its `flake.nix` follows list covers `flake-parts`, `sops-nix`, `disko`, `treefmt-nix`, `nix-darwin`, and `systems` only; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:flake.nix:74-80`) and locks its own `nixpkgs_2` at `c27cdad491a991b11ed731760aa2ef8db0cb0410`; clan-core's library nevertheless resolves nixpkgs as `self.inputs.nixpkgs or clan-core.inputs.nixpkgs`, so machine configurations use the root pin (`github:clan-lol/clan-core@1c21a2388ffbf9a957a60f58d18757420666cc43:lib/clan/default.nix:34`).
- F73 `cognee-nix`, `llm-agents`, `nix-index-database`, `catppuccin`, `nixpkgs-linux-stable`, and `nixpkgs-darwin-stable` keep separate nixpkgs nodes; the node literally named `nixpkgs` in the lock is catppuccin's `nixpkgs-unstable` input at `044bfe75bfe4c7bbe043dc17b5e42ea823b84a09`, not the root pin (`flake.lock`, node `catppuccin.inputs.nixpkgs = "nixpkgs"`).
- F74 Pin versus deployed system: the lock was last bumped to `85f62611` on main in commit `a29f6422` (2026-08-05), `system.stateVersion = "25.05"` on `magnetite` has been unchanged since commit `1398e171` (2026-04-05), and the branch `origin/update-nixpkgs` (commit `e6a7cc9c`, 2026-09-04, not merged into main) moves root nixpkgs to `8a37cfb926b31472f2e90b992c197c62d6bb4d74`; the module logic at the pin is newer than the state version (it already contains the `25.11`/`26.11` PostgreSQL branches, F10) but every stateVersion-gated default resolves as for `25.05`.
- F75 Whether the running generation on `magnetite` is built from main's lock cannot be verified from the repository alone; this axis compares the pin against the main-revision configuration, not against the live host.

## Flags

- R1 The buzz-flake research note states that "vanixiets locks `044bfe75bfe4c7bbe043dc17b5e42ea823b84a09`" (`docs/notes/development/omnigent/research/buzz-flake.md:222`); that revision is catppuccin's separate nixpkgs node (F73), not the root pin, and the root pin is `85f62611fa3f3eacbcfe3bc7a6d6518b443ca442`; the note's conclusion (that the pin defines `postgresql.target`) still holds (F19).
- R2 The deployment plan orders the server unit `after`/`requires` `postgresql.service` (`deployment-plan.md:79` and `:179`); ensured databases and roles are created by `postgresql-setup.service`, so the unit must order on `postgresql.target` (F18-F20) or migrations can race database creation on first deploy.
- R3 The deployment plan says nginx "needs no `proxy_buffering off` override" because Omnigent sets `X-Accel-Buffering: no` (`deployment-plan.md:120`); that is correct nginx runtime behaviour but the NixOS module neither sets nor verifies it (F34-F35), so the verification slice should observe an unbuffered event stream end to end rather than rely on module configuration.
- R4 The deployment plan's runner hardening statement names only `RestrictNamespaces` and `SystemCallFilter` (`deployment-plan.md:139`); the pinned ESPHome precedent shows `ProtectKernelTunables`, `ProtectKernelLogs`, `ProtectHostname`, and `ProcSubset = "pid"` also break `bwrap` (F47, F54), so the runner unit must drop those four as well, while `NoNewPrivileges` can stay (F51).
- R5 `magnetite` already has `recommendedProxySettings = true` via srvos (F32), so the vhost's one-day timeouts must be written as location-level `extraConfig` overrides; setting module-level `proxyTimeout` would change every vhost on the host (F33).
- R6 The PostgreSQL major is 16 by `stateVersion` at this pin and the module warns on every evaluation that the unpinned default is the next major to be removed (F10-F13); the Omnigent module should not set `services.postgresql.package`, since any such setting would apply to the shared instance and require a cluster migration.
- R7 An ensured `omnigent` database inherits the cluster locale (F4); Synapse required a workaround for this and Omnigent's Alembic schema may or may not care, which this axis cannot determine.
- R8 The cognee module's `mkForce "127.0.0.1"` on `listen_addresses` is not active on `magnetite` because cognee is not imported there (F17); if cognee is later imported, that `mkForce` conflicts with nothing in the Omnigent socket-only design, but any future TCP consumer would need to reconcile with it.
- R9 The root nixpkgs pin has a pending bump on `origin/update-nixpkgs` (F74); if that branch merges before implementation, the line citations in this note must be re-verified against `8a37cfb926b31472f2e90b992c197c62d6bb4d74`.

## Additional sources acquired

- `github:nix-community/srvos@a00436b148ec1c2f54f60e3973af197d7c7d8009`, read via the locked flake input store path to confirm `nixos/mixins/nginx.nix` sets `recommendedProxySettings = lib.mkDefault true` (F32).
- `github:nix-community/buildbot-nix@d193d375fe5c4be29f13dc34552903cae6813b07`, read via the locked flake input store path to confirm `nixosModules/master.nix` enables PostgreSQL and orders on `postgresql.target` (F12, F14, F20).
- `github:clan-lol/clan-core@1c21a2388ffbf9a957a60f58d18757420666cc43`, already present locally, read for `lib/clan/default.nix:34` (F72).
- systemd 261 manual pages `systemd.exec(5)` and `systemd.resource-control(5)` at `https://www.freedesktop.org/software/systemd/man/261/`, fetched for F45-F46 because NixOS does not define these semantics.
- No new clones were created; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711` and `github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62` were read at their existing local pinned checkouts.

## Questions

- Q1 Should the server unit order on `postgresql.target` (F19-F20, R2) instead of the plan's `postgresql.service`, and should the plan text at `deployment-plan.md:79` and `:179` be amended accordingly?
- Q2 Should the nginx location carry an explicit `proxy_buffering off;` in `extraConfig` in addition to the upstream `X-Accel-Buffering: no` header (F35, R3), or is end-to-end observation of an unbuffered SSE stream in the verification slice sufficient?
- Q3 For the runner unit, is the intended hardening baseline the ESPHome set (F47: `NoNewPrivileges`, `ProtectSystem = "strict"`, `RestrictNamespaces = false`, `SystemCallFilter = [ "@system-service" "@mount" ]`, with `ProtectKernelTunables`, `ProtectKernelLogs`, `ProtectHostname`, and `ProcSubset = "pid"` omitted), or should the runner start with no hardening and add properties only as each is verified against a real sandboxed session?
- Q4 Should `PrivateUsers` be explicitly `false` on the runner (F55), given no pinned module demonstrates nested `bwrap` under `PrivateUsers = true`?
- Q5 For the server unit, is a static `omnigent` user (plan D3/D7) preferred over `DynamicUser = true` with `StateDirectory` (F56-F57), given both satisfy peer authentication as long as `ensureUsers.name` equals the unit's `User=`?
- Q6 Is the Omnigent Kanidm client confidential (`basicSecretFile` from a clan vars generator, `public = false`, as Synapse) or public with PKCE (F59-F60)?
The option set forbids `basicSecretFile` for a public client and forbids `enableLocalhostRedirects` for a confidential one, so the choice fixes the rest of the block.
- Q7 Does Omnigent's Alembic schema depend on database collation or encoding (R7), and if so should the plan add a `CREATE DATABASE ...
LOCALE 'C'` pre-step outside `ensureDatabases`?
- Q8 Should this note and the buzz-flake note be reconciled on the root nixpkgs revision (R1) by the parent, or is a flag here sufficient?
