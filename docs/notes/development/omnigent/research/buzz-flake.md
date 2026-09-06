---
title: Research axis buzz-flake
status: working-note
date: 2026-09-06
---

# Research axis buzz-flake

Axis: `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7`, whole repository.
The axis revision is the repository head as of 2026-09-05 and the repository has 41 commits in total, all between 2026-08-18 and 2026-09-05.
The flake packages `block/buzz` from source and ships a NixOS module, a Home Manager module, and a clan service for the Buzz relay and its agents (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:README.md:3-5`).
Every relay behaviour claim below is read at the upstream revision the flake pins, `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614`, which carries the tag `desktop-v0.5.20`.
Terms follow the charter designation table; "Omnigent server", "Runner / host", "Local sandbox", "Managed sandbox provider", and "clan vars generator" carry the meanings given there.

## Summary

- The flake builds relay, admin CLI, pair relay, sidecars, web bundles, and the desktop app from one pinned `block/buzz` checkout with `rustPlatform.buildRustPackage` and `fetchPnpmDeps`; nothing is fetched as a wheel, release binary, or OCI image except a prebuilt `sherpa-onnx` static-library archive consumed by the desktop build.
- The NixOS module `services.buzz-server` runs `buzz-relay` as a hardened static-user systemd unit with `StateDirectory=buzz`, provisions local PostgreSQL and a dedicated Redis instance by default, and takes secrets through one `EnvironmentFile`.
- No reverse proxy, TLS, ACME, OIDC, or sandbox appears anywhere in the flake; identity is Nostr keypairs and the README delegates TLS to an unspecified proxy.
- The clan service role `server` adds a clan vars generator that prompts for S3 credentials and generates `BUZZ_RELAY_PRIVATE_KEY` and `BUZZ_GIT_HOOK_HMAC_SECRET` into one environment file.
- vanixiets already pins the identical upstream revision and source hash in `pkgs/by-name/buzz/source/package.nix`, so the relay buzz-flake packages is the same tree vanixiets already builds `buzz-cli` from.
- The vanixiets Buzz self-hosting note was read at `desktop-v0.5.4`; every relay environment variable and startup gate it names still exists with the same name at `desktop-v0.5.20`, so charter risk RK5's confirming observation is not observed, with three discrepancies recorded under "RK5 evaluation".
- Three probable defects were found in the flake: the `s3.addressingStyle` enum offers a value upstream rejects, the relay wrapper omits `bash`, `curl`, and `openssl` that the upstream pre-receive hook shells out to, and the Redis option description contradicts upstream startup code.

## Buzz server topology and Omnigent analogues

The topology the flake deploys has five runtime components plus one external dependency.

| Buzz component | What the flake runs | Omnigent analogue |
|---|---|---|
| Relay (`buzz-relay`) | Rust Nostr WebSocket relay plus REST API and static web UI, `systemd.services.buzz-relay`, binding `127.0.0.1:3000` by default (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:73-77,381-439`) | Direct analogue: the Omnigent server, a FastAPI process serving HTTP, SSE, terminal-attach WebSockets, persistence, and the web UI (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:221-225`). |
| Pairing relay (`buzz-pair-relay`) | Separate in-memory WebSocket sidecar for NIP-AB device pairing, `systemd.services.buzz-pair-relay` on `127.0.0.1:5000` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:342-379`) | Not present; `git grep -n -i -E 'device pairing|nostrpair|pair relay' 381bf638 -- deploy docs README.md` returns nothing. |
| PostgreSQL | `services.postgresql` with `ensureDatabases = [ "buzz" ]` and `ensureDBOwnership`, connected over the unix socket (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:143-150,286-295`) | Direct analogue: Omnigent selects Postgres or SQLite per `DATABASE_URL`, with Postgres "the default and the production answer" (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:144-165`). |
| Redis | `services.redis.servers.buzz` on `127.0.0.1:6380` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:165-177,297-301`) | Not present in Omnigent; `git grep -n -i -E '\bredis\b|valkey' 381bf638 -- deploy docs README.md` returns one advisory sentence about a shared registry for multi-replica Kubernetes (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/kubernetes/README.md:387`). |
| ACP harness (`buzz-acp` spawning `buzz-agent`) | Home Manager user services, one per agent, dialing the relay with `BUZZ_RELAY_URL` and running the agent as an ACP model process (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-agents.nix:56-112`) | Partial analogue: the Omnigent runner / host dials the server over `WS /v1/runner/tunnel` and executes the LLM loop locally (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:226-229`), and Omnigent also speaks the Agent Client Protocol to `acp:` agents (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:298-302`). |
| S3 object store (external) | Required; `s3.endpoint` has no default and the relay probes the bucket at startup (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:179-187`; `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:README.md:65-67`) | No analogue; Omnigent's docker deployment computes an `ARTIFACT_DIR` on a volume rather than requiring object storage (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/README.md:261`). |

The relay crate reports its own version `0.2.1` at the pinned tree and states that it "does NOT inherit the workspace version" (`github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/Cargo.toml:4-7`).
The flake labels every package with the desktop version `0.5.20` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-desktop/source.nix:3-6`).

## RK5 evaluation: does the vanixiets note describe the relay buzz-flake packages

The note is `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md`, committed 2026-08-04 (`git log --format='%h %ai %s' -- docs/notes/development/buzz` shows `fbac23b4e 2026-08-04 20:50:08 -0400 docs(buzz): add notes on self-hosting`).
The note states that every relay claim was read at `block/buzz` revision `651f6372754e60e3f936b3397040eb0f1e44c9f3`, tag `desktop-v0.5.4`, and that the relay shipped at `0.2.0` under `relay-v*` tags (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md:14-16`).
buzz-flake pins `95154bee4034ca7a40b33095c2ddbde8c9aa1614`, tag `desktop-v0.5.20`, dated 2026-08-25 (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-desktop/source.nix:6-8`).
Tag `relay-v0.2.1` (2026-08-08) is an ancestor of the pin and `git rev-list --count relay-v0.2.1..95154bee -- crates/buzz-relay` is 22, so the packaged relay is `0.2.1` plus 22 unreleased relay commits.

The charter's confirming observation for RK5 is that buzz-flake "packages a relay version whose config surface differs from the note".
Every relay environment variable the note names exists under the same name at the pinned revision:

| Variable in the note | Location at the pin |
|---|---|
| `RELAY_URL`, default `ws://localhost:3000` (note line 300) | `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/config.rs:567` |
| `BUZZ_ADMIN_HOST` exact-authority match (note line 206) | `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/config.rs:969-978` |
| `BUZZ_GIT_HOOK_HMAC_SECRET` auto-generated when unset (note line 31) | `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/config.rs:894-899` |
| `BUZZ_AUTO_MIGRATE` (note line 157) | set by the module at `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:23` |
| Conformance probe fatal by default (note line 77) | `BUZZ_GIT_CONFORMANCE_PROBE` defaults on and failure propagates with `?` at `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/main.rs:491-516` |
| Health `8080` and metrics `9102` bind `0.0.0.0` (note line 302) | health listener binds `("0.0.0.0", config.health_port)` at `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/main.rs:1268` |
| Postgres unavailable at start is fatal with no retry (note line 287) | `Db::new(...).map_err(...)?` at `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/main.rs:185-188`, which is exactly what the flake patches |
| Pre-receive hook shells out to `curl` and `openssl` and is fail-closed (note line 250) | `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/api/git/hook.rs:11,32,115,127` |

Three discrepancies exist and none of them is a config-surface change between the two revisions.

1. The note says health and metrics ports "are not configurable" (note line 302); `BUZZ_HEALTH_PORT` and `BUZZ_METRICS_PORT` are read at the pin (`github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/config.rs:754-762`) and were already read at `desktop-v0.5.4` (`github:block/buzz@651f6372754e60e3f936b3397040eb0f1e44c9f3:crates/buzz-relay/src/config.rs:658-663`), so the note is inaccurate about the port and accurate about the fixed `0.0.0.0` bind address, and the flake exposes both ports as `healthPort` and `metricsPort` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:79-89`).
2. The note says "Redis is not startup-fatal, and readiness returns 503 without it" (note line 348); the flake's `redisUrl` description says "Redis is required; the relay aborts if it cannot connect" (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:156`); at the pin, `deadpool_redis::Config::create_pool` builds a lazy pool and `PubSubManager::new` constructs channels without opening a connection (`github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/main.rs:380-392`; `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-pubsub/src/lib.rs:117-142`), so the note's reading matches upstream and the flake's description does not.
3. The note leaves open "whether non-technical family members can point the desktop app at a custom relay at all" (note line 191); the flake's clan `client` role answers it by wrapping `buzz-desktop` with `--set-default BUZZ_RELAY_URL` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-clan.nix:276-287`), and upstream reads that variable at `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:desktop/src-tauri/src/relay.rs:40`.

The note also does not mention `RELAY_OWNER_PUBKEY`, `BUZZ_REQUIRE_AUTH_TOKEN`, `BUZZ_REQUIRE_RELAY_MEMBERSHIP`, `BUZZ_PAIRING_RELAY_URL`, or declarative membership via `buzz-admin add-member`, all of which the flake wires (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:22,249-267,305-340`; `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-clan.nix:254-258`) and all of which exist upstream at the pin (`github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/config.rs:569,614,622,671`).
These are omissions in the note, not changes in the relay.

Verdict: the relay the note describes matches the relay buzz-flake packages in every named variable and startup gate; the relay moved from `0.2.0` to `0.2.1` plus 22 commits between the two readings, and the note's own caveat that it was read off the desktop release axis still applies because the flake also pins the desktop axis.
vanixiets already pins the same tree: `pkgs/by-name/buzz/source/package.nix` fetches tag `desktop-v0.5.20`, rev `95154bee4034ca7a40b33095c2ddbde8c9aa1614`, hash `sha256-+5fdFmxB9TOgYoeJrEs2FCYldku4OyEJVrpdC/FYRFQ=` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:pkgs/by-name/buzz/source/package.nix:33-48`), byte-identical to the flake's `src` hash (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-desktop/source.nix:14`).

## 1. Packaging mechanism

All packages derive from one `buzz-source` attribute that calls `fetchFromGitHub` with `owner = "block"`, `repo = "buzz"`, `rev = "95154bee4034ca7a40b33095c2ddbde8c9aa1614"`, and `hash = "sha256-+5fdFmxB9TOgYoeJrEs2FCYldku4OyEJVrpdC/FYRFQ="` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-desktop/source.nix:5-15`).
The overlay wires `buzz-source`, `buzz-web`, `buzz-relay`, `buzz-sidecars`, and `buzz-desktop` through `callPackage` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/overlay.nix:1-9`).

`buzz-relay` is `rustPlatform.buildRustPackage` with `cargoLock.lockFile` pointing into the fetched source and `outputHashes` for two git dependencies, `mesh-llm-sdk-0.75.1` and `aws-creds-0.39.1` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-relay/package.nix:15-22`; `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-desktop/source.nix:20-27`).
It builds three workspace packages, `buzz-relay`, `buzz-admin`, and `buzz-pair-relay` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-relay/package.nix:40-44`).
Tests are disabled because "the workspace test suite needs a live Postgres, Redis and S3" (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-relay/package.nix:46-47`).
`postInstall` wraps `buzz-relay` with `git` prefixed onto `PATH` and `BUZZ_WEB_DIR` and `BUZZ_ADMIN_WEB_DIR` defaulted to the `buzz-web` outputs (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-relay/package.nix:49-54`).
Native build inputs are `cmake`, `pkg-config`, `perl`, `protobuf`, `makeWrapper`, with `openssl` as the only `buildInputs` entry and `dontUseCmakeConfigure = true` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-relay/package.nix:26-38`).

One patch applies to the relay: `retry-postgres-startup.patch` replaces the single `Db::new` call with a six-attempt, five-second-delay loop (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-relay/package.nix:24`; `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-relay/retry-postgres-startup.patch:1-36`).
A `patch -p1 --dry-run` of that file against `crates/buzz-relay/src/main.rs` extracted from the pinned upstream revision succeeds with "Hunk #1 succeeded at 182 (offset 11 lines)".
The same dry run against `desktop-v0.5.23` fails with "Hunk #1 FAILED at 171" because upstream inserted `.with_session_timeouts_from_env();` into the hunk context (`github:block/buzz@b9392d9d78744df365f9276e1ffe8c1baa5ea903:crates/buzz-relay/src/main.rs:254-262`).

`buzz-web` is `stdenvNoCC.mkDerivation` with `fetchPnpmDeps` (`fetcherVersion = 4`, workspaces `buzz-web` and `buzz-admin-web`, hash from `buzz-source.webPnpmHash`) and builds `web/dist` and `admin-web/dist` with `pnpm -C ... build` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-web/package.nix:10-53`).
`buzz-sidecars` builds `buzz-acp`, `buzz-agent`, `buzz-backend-kubernetes`, `buzz-dev-mcp`, `git-credential-nostr`, and `buzz-cli` from the same lockfile (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-sidecars/package.nix:33-40`).
`buzz-desktop` builds the Tauri app with `cargo-tauri.hook`, installs the sidecars into `desktop/src-tauri/binaries` before the bundle step, and consumes a prebuilt `sherpa-onnx` `1.13.4` static-library archive fetched with `fetchurl` and two per-platform hashes (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-desktop/package.nix:32-57,84,126-132`).
That archive is the only fetched binary artifact in the flake; there is no wheel, no release binary for the relay, and no OCI image.
No `buildPythonApplication`, `uv2nix`, or `pyproject-nix` appears (`grep -rn -E 'buildPythonApplication|uv2nix|pyproject-nix|dockerTools|fetchurl' .` matches only the `sherpa-onnx` `fetchurl`).

Hash pinning covers `src`, two cargo git-dependency output hashes, two pnpm store hashes, and two `sherpa-onnx` archive hashes; a `cargoHash` for the vendored registry is not used because `cargoLock.lockFile` vendors from the lockfile directly.
The update script moves the pin to the newest `desktop-v*` GitHub release and refreshes `src` and the pnpm hashes, refusing the bump if `sherpa-onnx-sys` moved in the lockfile (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-desktop/update.sh:5-7,47-56`).

## 2. NixOS module surface

The module is `services.buzz-server`, exported as `nixosModules.buzz-server` and `nixosModules.default` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:flake.nix:57-60`).
Every setting the relay reads is an environment variable and the module renders an attrset of them into `systemd.services.buzz-relay.environment` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:12-37`).

Options (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:42-268`):

| Option | Default | Environment variable |
|---|---|---|
| `enable` | false | |
| `package` | `buzz-flake.packages.${system}.buzz-relay` | |
| `user`, `group` | `buzz`, `buzz` | |
| `stateDir` | `/var/lib/buzz` | `BUZZ_GIT_REPO_PATH=${stateDir}/repos` |
| `bindAddress` | `127.0.0.1:3000` | `BUZZ_BIND_ADDR` |
| `healthPort`, `metricsPort` | `8080`, `9102` | `BUZZ_HEALTH_PORT`, `BUZZ_METRICS_PORT` |
| `relayUrl` | required | `RELAY_URL` |
| `pairingRelay.enable`, `.bindAddress`, `.url` | false, `127.0.0.1:5000`, `<relayUrl>/pair` | `BUZZ_PAIR_RELAY_BIND_ADDR`, `BUZZ_PAIRING_RELAY_URL` |
| `adminHost` | null | `BUZZ_ADMIN_HOST`, `BUZZ_ADMIN_WEB_DIR` |
| `serveWebUi` | true | `BUZZ_WEB_DIR` |
| `autoMigrate` | true | `BUZZ_AUTO_MIGRATE` |
| `databaseUrl` | `postgres:///buzz?host=/run/postgresql&user=buzz` | `DATABASE_URL` |
| `redisUrl` | `redis://127.0.0.1:${redis.port}` | `REDIS_URL` |
| `database.createLocally` | true | |
| `redis.createLocally`, `redis.port` | true, `6380` | |
| `s3.endpoint`, `.bucket`, `.region`, `.addressingStyle` | required, `buzz-media`, `us-east-1`, `path` | `BUZZ_S3_ENDPOINT`, `BUZZ_S3_BUCKET`, `BUZZ_S3_REGION`, `BUZZ_S3_ADDRESSING_STYLE` |
| `environmentFile` | null | `EnvironmentFile=` |
| `settings` | `{}` | free-form attrs of str, int, or bool rendered last |
| `openFirewall` | false | |
| `members` | `{}` | reconciled by `buzz-admin add-member` |

Unit shape for `buzz-relay` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:381-439`): `ExecStart = lib.getExe cfg.package`; static `User`/`Group` (not `DynamicUser`); `EnvironmentFile` when set; `StateDirectory = "buzz"` only when `stateDir` is the default; `WorkingDirectory = cfg.stateDir`; `Restart = "on-failure"`, `RestartSec = 5`; `after` and `requires` on `postgresql.target` and `redis-buzz.service` when created locally; hardening `CapabilityBoundingSet = [""]` (or `AmbientCapabilities = CAP_NET_BIND_SERVICE` below port 1024), `LockPersonality`, `MemoryDenyWriteExecute`, `NoNewPrivileges`, `PrivateDevices`, `PrivateTmp`, `ProtectClock`, `ProtectControlGroups`, `ProtectHome`, `ProtectHostname`, `ProtectKernelLogs`, `ProtectKernelModules`, `ProtectKernelTunables`, `ProtectProc = "invisible"`, `ProtectSystem = "strict"`, `ReadWritePaths = [cfg.stateDir]`, `RemoveIPC`, `RestrictAddressFamilies = [AF_INET AF_INET6 AF_UNIX]`, `RestrictNamespaces`, `RestrictRealtime`, `RestrictSUIDSGID`, `SystemCallArchitectures = "native"`, `SystemCallFilter = ["@system-service" "~@privileged"]`, `UMask = "0077"`.
No `Type=` is set, so the unit is `Type=simple`; no `TimeoutStopSec` or `StartLimitIntervalSec` is set.

User and group: `users.users.buzz` is `isSystemUser` with `home = cfg.stateDir` and `users.groups.buzz` is created, both only when the names are the default (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:278-284`).
An assertion forces `user == "buzz"` whenever `database.createLocally` is on because the ensured role is named `buzz` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:271-276`).

Database provisioning: `services.postgresql.enable = true`, `ensureDatabases = ["buzz"]`, `ensureUsers = [{ name = "buzz"; ensureDBOwnership = true; }]` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:286-295`).
Redis provisioning: `services.redis.servers.buzz` bound to `127.0.0.1` on `cfg.redis.port` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:297-301`).
Migrations run inside the relay at startup when `autoMigrate` is true; otherwise the operator runs `buzz-admin migrate` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:134-141`).

Two auxiliary units exist.
`buzz-members` is a `Type=oneshot` unit that runs after and requires `buzz-relay.service`, retrying `buzz-admin add-member --pubkey ... --role ...` up to 60 times at two-second intervals because "the relay seeds the community mapping during startup, after the unit is already active" (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:305-340`).
`buzz-pair-relay` runs `buzz-pair-relay` with a similar hardening set minus `AF_UNIX`, `ProtectProc`, `ReadWritePaths`, `RemoveIPC`, and `SystemCallFilter` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:342-379`).

The only check is an evaluation-only smoke test that enables the module with `relayUrl`, `s3.endpoint`, and `environmentFile` and builds `system.build.toplevel` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:checks/nixos-module.nix:3-19`; `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:flake.nix:69-72`).

## 3. Reverse proxy and TLS integration

Not present.
The search `grep -rn -i -E 'nginx|caddy|traefik|acme|letsencrypt|tls|ssl' . --exclude-dir=.git` matches only prose.
The README states "The relay speaks plain HTTP/WebSocket; put a reverse proxy in front of `bindAddress` and make `relayUrl` match the public URL, since it is used in the NIP-42 authentication challenge" (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:README.md:75-77`).
It adds that when the pairing relay is enabled the operator must route `pairingRelay.url`, by default `<relayUrl>/pair`, to `pairingRelay.bindAddress` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:README.md:78-80`).
The clan service README repeats "TLS and the public reverse proxy are outside this service" (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-clan.md:32-33`).
The module offers only `openFirewall`, which opens the `bindAddress` port and nothing for health or metrics (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:243-247,303`).
No websocket-upgrade or long-timeout guidance appears; the vanixiets note carries that guidance for nginx at `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md:294-297`, and the deployed precedent for `proxyWebsockets = true` is `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:285` and `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:513`.

## 4. Secret source

The NixOS module takes one `environmentFile` path with the example `/run/secrets/buzz-relay.env` and requires at least `BUZZ_RELAY_PRIVATE_KEY`, `BUZZ_GIT_HOOK_HMAC_SECRET`, `BUZZ_S3_ACCESS_KEY`, and `BUZZ_S3_SECRET_KEY` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:211-222`; `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:README.md:68-74`).
Neither sops-nix nor agenix is referenced; `grep -rn -i -E 'sops|agenix' . --exclude-dir=.git` returns nothing, and the `/run/secrets/` example is a path convention only.

The clan service supplies that file through a clan vars generator named `buzz-server-${instanceName}` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-clan.nix:168-230`).
It has two hidden, persisted prompts, `s3-access-key` and `s3-secret-key`, one secret file `relay-environment` owned by `buzz:buzz`, and a script that derives `BUZZ_RELAY_PRIVATE_KEY` from `buzz-admin generate-key`, `BUZZ_GIT_HOOK_HMAC_SECRET` from `openssl rand -hex 32`, and writes all four as shell-quoted `NAME=value` lines with a Python heredoc (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-clan.nix:175-228`).
The generator declares no `restartUnits`, unlike the vanixiets Kanidm generators (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:58-64`).
The service wires `environmentFile = generator.files.relay-environment.path` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-clan.nix:253`).
The clan README notes that "Regenerating the vars replaces both generated secrets" (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-clan.md:29`); the vanixiets note records that the relay keypair "is effectively unrotatable" because rotation orphans relay-signed events (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md:195`).

The Home Manager module takes `openrouterEnvironmentFile` supplying `OPENROUTER_API_KEY` and a per-agent `privateKeyFile` supplying `BUZZ_PRIVATE_KEY`, both as opaque paths, and writes the non-secret agent environment into the Nix store with `pkgs.writeText` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-agents.nix:27-30,78-83,99-103,125-133`).

## 5. OIDC/SSO wiring

Not present.
The search `grep -rn -i -E 'oidc|openid|oauth|kanidm|keycloak|authelia|sso' . --exclude-dir=.git` over the flake returns nothing.
The same search over the upstream relay crate, `git grep -n -i -E 'oidc|openid|oauth' 95154bee -- crates/buzz-relay/src`, returns nothing; the only `oauth` hits in the workspace are Databricks credentials inside `crates/buzz-agent` (`github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-agent/src/auth.rs`).
Identity in the module is Nostr keypairs: `members` maps a "bech32 npub or 64-char hex" pubkey to `member` or `admin`, and the relay owner is `RELAY_OWNER_PUBKEY` in `settings` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:249-267`).
The clan `client` role states "Identity keys are not managed: they are created in the app and stored in the user's keyring" (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-clan.md:60-61`).
This matches the vanixiets note's conclusion that "Buzz identity is nostr-native and there is no kanidm bridge worth building" (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md:171`).

## 6. Runner/host placement and sandbox provisioning

The agent runtime is `homeModules.buzz-agents`, which creates one `systemd.user.services.buzz-agent-<name>` per configured agent (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:flake.nix:62`; `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-agents.nix:140-144`).
Each unit runs `buzz-acp` with `BUZZ_RELAY_URL = cfg.relayUrl`, `BUZZ_ACP_AGENT_COMMAND = buzz-agent`, `BUZZ_ACP_MCP_COMMAND = buzz-dev-mcp`, `BUZZ_AGENT_PROVIDER = "openrouter"`, and the model and system prompt from the option set (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-agents.nix:59-77,98`).
Placement is any machine with a user session and network reach to `relayUrl`; the module has no dependency on the server module and the README example runs both on separate configurations (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:README.md:96-124`).
Each unit gets `WorkingDirectory = %S/buzz-agents/<name>`, `StateDirectory = buzz-agents/<name>`, `Restart = always`, `NoNewPrivileges = true`, and `PrivateTmp = true`, and nothing else (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-agents.nix:104-110`).

Sandboxes are not provisioned.
The search `grep -rn -i -E 'bwrap|bubblewrap|sandbox|firejail|landlock|microvm|container' . --exclude-dir=.git` over the flake returns nothing.
The `buzz-sidecars` package does compile `buzz-backend-kubernetes`, described upstream as the "Kubernetes backend provider for Buzz remote agents" that "realizes the contract as a bare Pod running the `sprig` image" (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-sidecars/package.nix:36`; `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-backend-kubernetes/Cargo.toml`; `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:docs/remote-agents.md:22-24`), but no module in the flake invokes it.
In the charter's terms, `buzz-acp` is a runner / host with no local sandbox, and the Kubernetes provider is a managed sandbox provider that is packaged but unwired.
Upstream states the launcher model explicitly: "anything that can set that environment and exec the harness — a bash script, a systemd unit, a CI job, or this document's provider protocol — is a conforming launcher" (`github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:docs/remote-agents.md:31-36`).

## 7. Buzz-specific components with an Omnigent analogue worth mirroring

- Postgres provisioning by `ensureDatabases` plus `ensureDBOwnership` over the unix socket with `DATABASE_URL = postgres:///buzz?host=/run/postgresql&user=buzz` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:145,286-295`) is the same idiom vanixiets already uses for synapse (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/matrix.nix:362-369`), and Omnigent accepts any `postgres://` URL (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:154-156`); the socket-URL shape is worth mirroring.
- The `settings` escape hatch, an `attrsOf (oneOf [str int bool])` rendered into the unit environment with bools as literal `true`/`false` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:33-36,224-241`), fits Omnigent's env-var-driven configuration (`OMNIGENT_*` variables per the charter designation table).
- The `after`/`requires` on `postgresql.target` plus the flake's startup-retry patch (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:384-392`) addresses the same failure class the vanixiets note assigns to `StartLimitIntervalSec = 0` and `RestartSec = "30s"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md:287`); Omnigent's entrypoint runs Alembic migrations before serving (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/SKILL.md:46`), so the same ordering matters there.
- The hardening block (`ProtectSystem = "strict"` with `ReadWritePaths`, `SystemCallFilter = ["@system-service" "~@privileged"]`, `UMask = "0077"`) at `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:406-437` is a reusable template for the Omnigent server unit, with the caveat that a runner on the same host needs `bwrap` and therefore user namespaces, which `RestrictNamespaces = true` denies.
- The relay has no analogue for the Nostr event store, the pairing relay, the S3 conformance probe, or the `members` reconciliation unit, and Redis has no Omnigent counterpart (see topology table).
- The Home Manager agent module's launcher pattern, a user unit that reads three `EnvironmentFile`s and execs the harness (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-agents.nix:96-111`), is the closest shape to an `omni host <server-url>` runner unit.

## 8. Apparent maintenance intent

The repository was created 2026-08-18 and the axis revision is dated 2026-09-05; `git log --format='%h %ai %s'` shows 41 commits, all by `fosskar` or `fosskar[bot]`.
Per-path last-touch dates from `git log --format='%h %ai %s' -- <path>`:

| Path | Last commit |
|---|---|
| `modules/buzz-server.nix` | `e2fea42 2026-08-22 18:09:39 +0000 server: add device pairing relay` |
| `modules/buzz-clan.nix` | `e2fea42 2026-08-22 18:09:39 +0000 server: add device pairing relay` |
| `modules/buzz-clan.md` | `eee64a9 2026-08-20 11:49:21 +0000 clan: rename service buzz-server -> buzz` |
| `modules/buzz-agents.nix` | `0971b24 2026-08-23 07:01:10 +0000 agents: wire the dev mcp server and relax the owner` |
| `packages/buzz-relay` | `66cf3d2 2026-08-27 12:15:19 +0000 relay: retry postgres startup` |
| `packages/buzz-desktop/source.nix` | `ec94ac5 2026-08-26 03:01:17 +0000 buzz-desktop: 0.5.18 -> 0.5.20` |
| `packages/buzz-sidecars`, `packages/buzz-web` | `74381e4 2026-08-20 11:17:31 +0000 packages: give each package its own directory` |
| `checks` | `6e505ac 2026-08-18 11:19:02 +0000 add flake packaging buzz relay, web bundles and nixos module` |
| `README.md` | `e4e1a04 2026-08-27 12:16:55 +0000 readme: remove stale package details` |
| `flake.lock` | `6811fbd 2026-09-05 01:00:35 +0000 flake: update nixbot (#14)` |

Human-authored commits stop on 2026-08-27; every commit after that is a nixbot flake-input update.
Automation is a nixbot schedule that updates flake inputs at 01:00 and runs `packages/buzz-desktop/update.sh` at 03:00 daily through `fosskar/nixfiles` updaters (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:effects.nix:39-59`).
The automation is live: the GitHub pull request list observed on the artifact date shows two open bot pull requests, `#16 buzz-desktop: 0.5.20 -> 0.5.23` opened 2026-09-05 and `#15 flake: update nixpkgs` opened 2026-09-04, plus 14 closed.
Upstream tags `desktop-v0.5.22` (2026-09-03) and `desktop-v0.5.23` (2026-09-05) exist beyond the pin.
`grep -rn -i -E 'todo|fixme|xxx|hack' . --exclude-dir=.git` returns nothing.
`doCheck = false` on all three Rust packages and the single evaluation-only check mean no build in the flake exercises relay behaviour.
The flake's `nixpkgs` input is `nixos-unstable` at `34ab99075ac4f7e40cf037eef32cb1c360bb85e9` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:flake.lock:26-40`), while vanixiets locks `044bfe75bfe4c7bbe043dc17b5e42ea823b84a09`; the module's use of `postgresql.target` requires a nixpkgs that defines it, which the vanixiets pin does (its `nixos/modules/services/databases/postgresql.nix` declares `wants = [ "postgresql.target" ]`).
The repository shows 0 stars and 0 forks on the GitHub page observed on the artifact date.
The repository is a personal packaging flake in the sense of charter W7 and C4, with a single maintainer and about ten days of feature development followed by bot-only activity.

## Flags

- Probable defect, `s3.addressingStyle`: the option enum is `["path" "virtual-host"]` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:201-208`; `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-clan.nix:106-113`), but upstream `S3AddressingStyle::from_str` accepts only `"path"` or `"virtual"` and returns `BUZZ_S3_ADDRESSING_STYLE must be 'path' or 'virtual'` otherwise, which `Config` propagates as a startup error (`github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-media/src/config.rs:22-34`; `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/config.rs:764-765`); selecting `virtual-host` would fail at boot.
- Probable defect, pre-receive hook tools: the relay writes a `#!/usr/bin/env bash` hook that calls `openssl dgst`, `curl`, and `sed` and is fail-closed (`github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/api/git/hook.rs:11,32,115,127`), git subprocesses inherit the relay's `PATH` (`github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/api/git/transport.rs:390-392`), upstream's Docker runtime installs `curl` and `openssl` and a test asserts it (`github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:Dockerfile:142-147`; `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/api/git/hook.rs:185-208`), but the flake wrapper prefixes only `git` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-relay/package.nix:50-51`) and the module sets no `path`; NixOS's default service `PATH` is `coreutils`, `findutils`, `gnugrep`, `gnused`, and `systemd` (read from the vanixiets-locked nixpkgs at `nixos/lib/systemd-lib.nix:700-707`), so `bash`, `curl`, and `openssl` are absent and every git push through the packaged relay would be rejected by the hook; the vanixiets note already records the mulatta wrapper carrying these tools as "load-bearing" (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md:249-250`); this is inferred from code, not observed at runtime.
- Inaccurate option description: `redisUrl` says "Redis is required; the relay aborts if it cannot connect" (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:156`), while upstream startup creates a lazy pool and opens no Redis connection before serving (`github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/main.rs:380-392`; `github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-pubsub/src/lib.rs:117-142`).
- Version skew pending: the flake's own patch `retry-postgres-startup.patch` applies to the pin with an 11-line offset and fails against `desktop-v0.5.23`, the target of open bot pull request `#16`, because upstream changed the hunk context (`github:block/buzz@b9392d9d78744df365f9276e1ffe8c1baa5ea903:crates/buzz-relay/src/main.rs:254-262`); the bump cannot merge without a patch refresh.
- Half-finished surface: `buzz-backend-kubernetes` is compiled into `buzz-sidecars` and bundled into the desktop app but no module wires the provider (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-sidecars/package.nix:36`).
- Non-secret agent configuration, including the system prompt and model, is written to the world-readable Nix store via `pkgs.writeText` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-agents.nix:78-83`); no secret is placed there, but the pattern must not be copied for values such as `OMNIGENT_ACCOUNTS_INIT_ADMIN_PASSWORD`.
- Health and metrics listeners bind `0.0.0.0` unconditionally upstream and the module's `openFirewall` does not cover them (`github:block/buzz@95154bee4034ca7a40b33095c2ddbde8c9aa1614:crates/buzz-relay/src/main.rs:1268`; `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-server.nix:303`); the NixOS firewall's default-deny hides them, but the module documents neither fact.
- The clan vars generator omits `restartUnits`, so regenerating the environment file does not restart `buzz-relay.service` (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:modules/buzz-clan.nix:188-192`), contrary to vanixiets principle P1.
- No test builds or runs the relay: `doCheck = false` on every Rust package and the only check is evaluation-only (`github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:packages/buzz-relay/package.nix:47`; `github:fosskar/buzz-flake@6811fbd9bce5a4ec4889d2e6eb48fa75d1a7f4c7:checks/nixos-module.nix:3-4`).
- The vanixiets note's claim that health and metrics ports are "not configurable" (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md:302`) is inaccurate for the port numbers at both the note's revision and the pin (see RK5 evaluation, item 1).

## Additional sources acquired

- `github:block/buzz@3c7f288c60d67df78577b237e27c3dfc8831aaa1`, cloned read-only with `direnv exec . ghq get block/buzz`; all citations into it are at the buzz-flake pin `95154bee4034ca7a40b33095c2ddbde8c9aa1614`, at the vanixiets note's revision `651f6372754e60e3f936b3397040eb0f1e44c9f3`, or at tag `desktop-v0.5.23` (`b9392d9d78744df365f9276e1ffe8c1baa5ea903`), all of which are contained in the clone.
- The `fosskar/buzz-flake` reference clone was a shallow clone containing only the axis commit; `git fetch --unshallow` was run on it to obtain history for dimension 8, and the checked-out revision was not changed.
- The NixOS default service `PATH` was read from the nixpkgs input resolved from the vanixiets `flake.lock` (`github:NixOS/nixpkgs@044bfe75bfe4c7bbe043dc17b5e42ea823b84a09:nixos/lib/systemd-lib.nix:700-707`) via `nix eval` of the flake input's `outPath`; no nixpkgs clone was added under the `ghq` root, so that citation does not resolve with the charter's A2 `git cat-file` loop as written.

## Questions

1. Does the plan's Buzz relationship (charter D8) need buzz-flake as a flake input at all, given that vanixiets already pins the identical `block/buzz` revision and source hash in `pkgs/by-name/buzz/source/package.nix` and charter P2 prefers vendoring over personal infra inputs?
2. Should the RK5 risk be closed on this evidence (same variable names and startup gates at both revisions, relay `0.2.0` to `0.2.1` plus 22 commits), or does the charter want the note re-read against the pin before the comparison table in the plan is written?
3. Should the two probable buzz-flake defects (addressing-style enum, missing hook tools on `PATH`) be reported upstream to `fosskar/buzz-flake`, or only recorded here?
4. Is a nixpkgs clone under the `ghq` root wanted so that the systemd default-`PATH` citation resolves under the A2 loop, or is the flake.lock-resolved store path acceptable for a research artifact?
5. The charter designation table has no term for a Nostr relay or for `buzz-acp`; this artifact calls `buzz-acp` a "runner / host" by analogy and the relay "the Buzz analogue of the Omnigent server"; should the designation table gain Buzz-side terms before the plan's comparison table uses them?
