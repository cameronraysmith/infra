---
title: Research axis omnigent-runner-topology
status: working-note
date: 2026-09-06
---

# Research axis: Omnigent runner topology

Axis revision: `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711` (`main`, `0.13.0.dev0`, commit date 2026-09-06).
Tag comparison revision: `v0.12.0`, which resolves to `github:omnigent-ai/omnigent@f04b0354fb5344c1ea8b92795ceb6760a9ad7595`.
Consumer revision: `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65`; the cited `modules/`, `pkgs/`, and `flake.lock` files are byte-identical at the current branch head `4d84c821f059932b85a6a14cac7a92c0b9ab6f2f` (`git diff --stat 590f751 HEAD -- modules/ pkgs/ flake.lock` is empty).
Package revisions: `github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442` (vanixiets root `nixpkgs` node) and `github:numtide/llm-agents.nix@10e3dca999e12a0d07f1e9e470707f4386dc3178` (vanixiets `llm-agents` node, `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:flake.lock:807-808`).

## Scope and method

This note answers the runner axis of the deployment plan: what `omnigent host` is, how it authenticates and registers, how several hosts coexist under one server, what the Linux and macOS sandboxes do to harness credentials, which harnesses the runner can offer, and what the three candidate machines `magnetite`, `pyrite`, and `stibnite` would each need.
It supplies evidence for plan Q7 (co-located runner carrying the operator's token) and plan Q14 (first agent catalog harness) and the plan Q1 tag-to-pin delta, and it enumerates runner topology options without choosing one.
Every factual claim carries a pinned citation of the form `github:owner/repo@<sha>:<path>:<line>`; claims about absent behavior are stated as negative search results over the pinned tree, not as proofs.
Findings use the code F, flags R, options O, and questions Q; references to the deployment plan's numbered questions are always written as plan Q7, plan Q14, and so on.
Contributor guidance files inside the reference clones were not used as sources; only the code and documentation paths cited below were read.

## 1. Runner command, identity, and registration

F1.
The runner command is the Click group `host` with a `--server` option; `omnigent host <url>` is documented shorthand that rewrites a leading URL-like positional into `--server <url>`, and the management subcommands are `enable`, `disable`, `status`, `stop`, `stop-session`, and `reset-id` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:8222-8231`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:8569-8570`).
F2.
The runner persists its identity in the `host:` block of `~/.omnigent/config.yaml` as `host_id` and `name`; when the block is missing, a fresh `uuid4().hex` ID and the machine hostname are generated and written back (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/identity.py:18`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/identity.py:91-105`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/identity.py:167-185`).
F3.
A partial `host: {name: ...}` block is completed rather than overwritten, so an operator can pre-seed a stable display name in the config file and let the ID be generated (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/identity.py:100-105`).
F4.
The environment variables `OMNIGENT_HOST_ID`, `OMNIGENT_HOST_NAME`, and `OMNIGENT_HOST_TOKEN` override the identity file for server-managed sandbox hosts; ID and name must be set together (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/identity.py:20-28`).
F5.
`omnigent host reset-id` mints a fresh `host_id` while preserving `name`, as the recovery path when the server refuses re-registration with HTTP 409 because another account owns the persisted ID (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/identity.py:188-200`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:9984`).
F6.
The runner dials `wss://<server>/v1/hosts/{host_id}/tunnel` when the server URL is HTTPS; the tunnel is an outbound WebSocket from the runner to the server (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/connect.py:1329-1338`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:219-235`).
F7.
The server authenticates the handshake before accepting the WebSocket, so an unauthenticated peer never completes the upgrade (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/host_tunnel.py:173-208`).
F8.
A host ID already owned by another user is rejected before accept as a cross-owner takeover; the check is skipped only for the single-user local server (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/host_tunnel.py:216-249`).
F9.
Registration persists host ID, display name, owner, and the configured-harness map reported in the `host.hello` frame (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/host_tunnel.py:252-295`).
F10.
Before the handshake the runner probes `configured_harness_map()` in a worker thread and keeps refreshing readiness while connected, so the server's picker knows which harnesses a given host can launch (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/connect.py:3117-3134`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/connect.py:3151-3176`).

## 2. Authentication modes and unattended token storage

F11.
The tunnel request carries either `X-Omnigent-Host-Token` when `OMNIGENT_HOST_TOKEN` is set, or `Authorization: Bearer <token>` from the logged-in user's stored credential (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/connect.py:3705-3716`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/identity.py:30-36`).
F12.
Managed-host launch tokens are minted by the server per sandbox launch for `host_type="managed"` sessions and are revoked with the sandbox; no pinned-tree route was found that lets an administrator mint a standing host token for a static machine, so the managed-token path is not an available alternative to a user bearer token for the three candidate hosts unless a sandbox provider is deployed (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/managed_hosts.py:1-30`).
F13.
`omnigent login` stores per-server records in `<data-dir>/auth_tokens.json`, where the data directory defaults to `~/.omnigent` and honors `OMNIGENT_DATA_DIR`; OIDC records hold `token`, `user_id`, `expires_at`, and, when the server issues one, `refresh_token` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli_auth.py:1-15`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli_auth.py:50-60`).
F14.
The token file is written as a `0o600` temp file beside the target and renamed into place, with the parent directory hardened to `0o700` first (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli_auth.py:75-95`).
F15.
The OIDC CLI login requests a ticket from `POST /auth/cli-login`, prints `Opening browser for login: <server>/auth/login?ticket=<id>`, calls `webbrowser.open`, and polls `GET /auth/cli-poll?ticket=<id>` for up to 300 seconds; the ticket itself expires after 300 seconds and is not bound to the requesting client's address, so on a headless machine the printed URL can be opened from any browser within that window (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:11991-12007`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:12050`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:50`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:575-594`).
F16.
The CLI login defaults the access-token expiry to eight hours when the server omits `expires_in` and stores the refresh grant so the host can renew past session expiry unattended (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:12021-12037`).
F17.
The server issues that refresh grant during the OIDC callback for CLI login tickets whenever a grant store exists (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:425-446`).
F18.
The grant store is created for the `accounts` and `oidc` auth sources whenever a permission store exists, with the stated purpose that an unattended host would otherwise die at the default eight-hour session-JWT expiry (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/app.py:3165-3178`).
F19.
The refresh endpoints `/oauth/token` and `/oauth/revoke` are mounted in OIDC mode without `OMNIGENT_DEVICE_GRANT_ENABLED`; that flag only adds the RFC 8628 device-code consent flow, which `omnigent login` does not use (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/app.py:3236-3298`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/device_auth.py:1-30`).
F20.
The runner renews by posting `grant_type=refresh_token` to `/oauth/token` under a token-file lock, and declines to refresh when the state directory is read-only (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli_auth.py:379-415`).
F21.
The refresh grant has an absolute lifetime of 30 days by default, overridable in whole days with `OMNIGENT_GRANT_MAX_LIFETIME_DAYS`; an unattended runner therefore needs a human browser login on the runner's identity at least every 30 days unless the operator extends the window (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/device_auth.py:114-128`).
F22.
When the runner targets a remote server, the daemon environment is allowlisted to process essentials, TLS trust, proxy selectors, and `DATABRICKS_*`; `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` are deliberately not passed to a remote-mode daemon (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:3295-3317`).
F23.
Consequence for plan Q7: a runner that is not a server-managed sandbox must hold a user's bearer token and refresh grant on disk under that runner's `OMNIGENT_DATA_DIR`, and every session it executes runs as the runner's OS user while acting as that Omnigent user (F11, F13, F18; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:236-259`).

## 3. Multi-host, naming, listing, routing, and liveness

F24.
`GET /v1/hosts` returns online and offline hosts owned by the authenticated user, with `host_id`, `name`, `owner`, `status`, and the configured-harness map; status is derived from the database row and its `updated_at`, not from the per-replica in-memory registry (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/hosts.py:566-622`).
F25.
A host is live only when its status is `online` and it was seen within `HOST_LIVENESS_TTL_S = 90` seconds, so a crashed or suspended runner shows offline after about 90 seconds (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/stores/host_store.py:49`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/stores/host_store.py:99-118`).
F26.
Session creation binds to the caller-supplied `host_id` and the caller must own both the host and the session; the same authorization path serves `POST /v1/hosts/{host_id}/runners` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/sessions/routes_core.py:644-669`).
F27.
The web UI's new-chat dialog restores a persisted host choice only once the host list shows it online; with no persisted choice it fills the empty slot with the managed sandbox when offered, else the first online host, and never overrides an explicit in-session choice (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:web/src/shell/NewChatDialog.tsx:2855-2903`).
F28.
The server seeds one picker agent per native harness and hides rows the selected host reports as not launchable, because the vendor CLI runs on the executing host rather than on the server (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/app.py:787-820`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/app.py:876-885`).
F29.
Hosts are visible only to their owner, so three runners usable from one operator's web session must all be registered by that operator's Omnigent identity; runners owned by other Kanidm users are invisible to and unusable by the operator (F24, F26).
F30.
Default names collide only in display, not identity: two machines each named by hostname register distinct IDs, but a cloned `~/.omnigent/config.yaml` would carry the same `host_id` and, under the same owner, would re-own the row in place rather than register a second host (F2, F8, F9).

## 4. Connectivity and ZeroTier

F31.
The runner needs outbound HTTPS and WebSocket reachability to the server and no inbound port; upstream describes runners as dialing in and never being deployed server-side (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:219-235`; F6).
F32.
`pyrite` is inventoried as a bare-metal NixOS laptop and ZeroTier peer with `deploy.targetHost = "root@pyrite.zt"`, and it configures suspend and hibernate ordering, so a runner on it is reachable for deployment only over the mesh and goes offline under F25 whenever the laptop sleeps (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/clan/inventory/machines.nix:77-86`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/pyrite/default.nix:218-224`).
F33.
A ZeroTier-only runner works with the plan's public `omni.scientistexperience.net` vhost as long as the laptop has ordinary internet egress; only the plan's reversing case of a mesh-only vhost would require the runner to resolve and trust the `zt+` address (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/cognee.nix:258` shows the repository's existing `zt+`-scoped firewall convention).
F34.
`stibnite` is the `aarch64-darwin` deployment controller whose primary and admin user is `crs58` and whose deploy target is `crs58@stibnite.zt` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/clan/inventory/machines.nix:99-108`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/darwin/stibnite/default.nix:62`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/darwin/stibnite/default.nix:91`).

## 5. Runner process and service management

F35.
`omnigent host` runs in the foreground by default, `--background` spawns a detached daemon after foreground sign-in, and `--non-interactive` fails instead of prompting when the stored credential is missing (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:8569-8600`).
F36.
`omnigent host enable --server <url>` installs a per-user persistent service; the helper writes a launchd agent `~/Library/LaunchAgents/ai.omnigent.host.plist` on macOS and a systemd user unit `$XDG_CONFIG_HOME/systemd/user/omnigent-host.service` on Linux, and refuses other platforms (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:9604-9620`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/service.py:42-68`).
F37.
The generated systemd unit is `Type=simple`, waits for `network-online.target`, restarts on failure after 10 seconds, and is written atomically with mode `0600`; the entry point is `python -m omnigent.host.service_entry --server <url>` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/service.py:66-68`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/service.py:115-157`).
F38.
Upstream provides no system-level unit, so a `magnetite` system service under a dedicated user is a vanixiets-authored unit rather than an upstream artifact; the plan's D7 already assumes this (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/service.py:42-62`).
F39.
A systemd user service on `pyrite` or `magnetite` runs only while the user's manager runs, so an unattended user-service runner needs lingering enabled for that user; this note did not find an upstream statement on lingering and records it as an implementation-time check.
F40.
The host daemon snapshots `PATH` at spawn and never refreshes it; when a CLI is not on that `PATH`, `resolve_cli_binary` probes `~/.local/bin`, `/usr/local/bin`, `/opt/homebrew/bin`, `~/.npm-global/bin`, and nvm version directories, none of which is a NixOS or Home Manager profile path, so a NixOS runner unit must place the vendor CLIs on the unit's `PATH` explicitly (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/_platform.py:30-56`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/_platform.py:72-80`).

## 6. Sandboxes and the native-harness stance

F41.
`omnigent/_platform.py` defines the platform flags `IS_LINUX = sys.platform.startswith("linux")` and `IS_DARWIN = sys.platform == "darwin"`, and the sandbox default is chosen by the same test (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/_platform.py:125-131`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/sandbox.py:1211-1216`).
F42.
The platform default sandbox is `linux_bwrap` on Linux and `darwin_seatbelt` on macOS; the default is chosen at spec parse time without probing for the binary, a missing `bwrap` fails loudly when the sandbox is built rather than falling back to unsandboxed execution, and the only explicit opt-out is `os_env.sandbox.type: none` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/sandbox.py:1170-1220`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:docs/AGENT_YAML_SPEC.md:230-247`).
F43.
Seatbelt is mandatory on macOS in the same sense as bubblewrap on Linux: the `darwin_seatbelt` resolver raises `OSError` when the host is not macOS or when `sandbox-exec` is not on `PATH`, with no silent fallback to `none`, and `sandbox-exec` ships with macOS at `/usr/bin/sandbox-exec` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/seatbelt_sandbox.py:345-388`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/seatbelt_sandbox.py:150`).
F44.
Bubblewrap binds `/usr`, `/lib`, `/lib64`, `/lib32`, `/bin`, and `/sbin` read-only, an allowlist of `/etc` files, fresh `/proc`, `/dev`, and `/tmp`, the cwd read-only unless `write_paths: ["."]`, and never mounts `$HOME` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:12-35`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:109-116`).
F45.
Bubblewrap additionally walks the symlink chain of `argv[0]` (the helper interpreter) and of the final target binary and binds each hop's parent and grandparent directories at their literal paths, so a store-path Python or a store-path `claude` is reachable inside the sandbox without a `read_paths` entry, but the shared libraries and sibling store paths those binaries depend on are not; no `/nix` or NixOS reference exists in the sandbox code or documentation (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:459-471`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:871-896`).
F46.
Declared `read_paths` are bound with `--ro-bind-try`, and the pinned revision skips read roots that equal the cwd or a write root and creates a missing `write_paths` directory on the host with a logged warning, which the `v0.12.0` tag does not do (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:476-484`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:509-530`).
F47.
Seatbelt prepends `sandbox-exec -f <profile>` and hides `$HOME` through a `(deny default)` baseline, so anything under the home directory not covered by cwd, scratch, `read_paths`, or `write_paths` is inaccessible (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/seatbelt_sandbox.py:1-8`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/seatbelt_sandbox.py:53-60`).
F48.
Bubblewrap needs unprivileged user namespaces, and nixpkgs defaults `security.allowUserNamespaces` to `true`, so no kernel option change is needed on `magnetite` or `pyrite` unless a hardening profile disables it (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/security/misc.nix:15-17`).
F49.
The `enforce_sandbox` policy forces `sandbox_type`, `allow_network`, `read_paths`, `write_paths`, and `env_passthrough` on agent start, and its `sandbox_type` parameter defaults to `linux_bwrap` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:docs/POLICIES.md:202-233`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/policies/builtins/safety.py:519-538`).
F50.
The native Claude, Codex, and Pi agent specs that upstream materializes declare `os_env.type: caller_process` with `sandbox.type: none`, and their declared shell terminals do the same, because the native CLI already runs unsandboxed on the user's workspace (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/claude_native.py:3182-3200`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/codex_native.py:605-616`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/pi_native.py:255-268`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/native_coding_agents.py:94-122`).
F51.
The server seeds its built-in `<harness>-ui` picker agents from those same materializers, and the runner's terminal endpoint gives an undeclared terminal the session agent spec's `os_env.sandbox`, so a web-UI Claude Code, Codex, or Pi session on a runner executes the vendor CLI without bubblewrap or Seatbelt unless a policy or a user-authored agent YAML says otherwise (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/app.py:751-786`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/runner/app.py:9323-9339`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/claude_native.py:5961-5982`).
F52.
A search of the non-`inner/` Python tree for `bwrap` finds no native launcher that applies a sandbox outside the spec's `os_env`; the native orchestration code repeatedly threads the agent's declared `os_env.sandbox` into terminals precisely so that `type: none` is honoured and not overridden by `_default_sandbox_for_platform` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/runner/native/orchestration.py:2218-2233`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/runner/native/orchestration.py:6604-6612`).
F53.
Consequence for plan Q14: the recommendation "upstream default native harness under bubblewrap" combines two things upstream keeps apart; the native terminal harnesses default to no sandbox, while bubblewrap is the default for `sys_os_*` tools and terminals of agents whose YAML omits `sandbox.type`, such as `claude-sdk` or Pi-harness agents (F42, F50, F51, F52).

## 7. Harness surface and enablement

F54.
The built-in registry is `antigravity`, `antigravity-native`, `claude-native`, `claude-sdk`, `codex`, `codex-native`, `copilot`, `cursor`, `cursor-native`, `goose`, `goose-native`, `hermes`, `hermes-native`, `kimi`, `kimi-native`, `kiro-native`, `open-responses`, `openai-agents`, `opencode-native`, `pi`, `pi-native`, `qwen`, and `qwen-native`, with aliases such as `claude`, `native-pi`, `native-opencode`, and `github-copilot`; the exported set is overlaid with plugin harnesses through `valid_harnesses()` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/spec/_omnigent_compat.py:88-142`).
F55.
`OMNIGENT_HARNESSES` is a Python `frozenset` imported by the CLI's harness validator, not an environment variable; no `os.environ` read of that name exists in the pinned tree (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:6927-6932`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/spec/_omnigent_compat.py:88`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/spec/_omnigent_compat.py:140`).
F56.
An agent selects its harness with `executor.harness`, and a parent agent can restrict sub-agent dispatch with `executor.config.allowed_harnesses`; no server-wide harness allowlist or disable list was found in a search of the pinned tree, so per-host enablement is de facto governed by which vendor CLIs are installed and reported ready (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:docs/AGENT_YAML_SPEC.md:20-22`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/runner/tool_dispatch.py:1971-1988`; F10, F28).
F57.
Readiness distinguishes binary-missing, version-too-low, and needs-auth for CLI harnesses, while SDK harnesses and unknown harnesses always report ready because their credentials are resolved at runtime (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/onboarding/harness_readiness.py:1-23`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/onboarding/harness_readiness.py:533-573`).
F58.
The launch gate is binary-only: an installed but unauthenticated CLI is still dispatched and fails at run time (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/onboarding/harness_readiness.py:501-523`).
F59.
Minimum versions are Claude `2.1.161`, Codex `0.137.0`, and Pi `0.84.2`; install specs use the Claude vendor installer, `@openai/codex`, and `@earendil-works/pi-coding-agent`, and login is delegated to `claude auth login --claudeai` and `codex login`, while Pi has no login subcommand (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/onboarding/harness_install.py:121-129`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/onboarding/harness_install.py:164-209`).
F60.
The native terminal wrappers require `tmux`, and `git`, `uv`, and Node are runtime prerequisites on the runner (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:124-139`).
F61.
The README states that on Linux the native wrappers and the `pi` harness wrap each agent terminal in `bwrap` and that the isolation is mandatory (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:140-145`); this contradicts the materialized native specs in F50 and F51 and is recorded as R2.

## 8. Claude Code, Codex, and Pi requirements and credential reachability

F62.
Claude native readiness accepts an Omnigent-configured provider, Claude managed-gateway settings, or a Claude CLI subscription login probed with `claude auth status`; Pi readiness requires the Pi binary plus either an Omnigent-managed provider or Pi's own subscription configuration (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/onboarding/harness_readiness.py:420-457`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/onboarding/harness_readiness.py:473-497`).
F63.
Codex native builds a per-session private `CODEX_HOME` that symlinks `auth.json`, `.credentials.json`, and `memories_1.sqlite` from the real Codex home and copies `config.toml`, so Codex credentials are read from the runner user's `~/.codex` at each session (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/codex_executor.py:131-165`).
F64.
Pi authenticates from `~/.pi/agent`; Omnigent can instead write a per-session `models.json` into a managed directory selected through `PI_CODING_AGENT_DIR` from the provider configured in `~/.omnigent/config.yaml` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/pi_native_credentials.py:1-16`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/pi_native_credentials.py:87`).
F65.
Every harness spawns its vendor CLI with a deny-by-default environment: the shared base is the prefixes `HTTP_`, `HTTPS_`, `ALL_PROXY`, `NO_PROXY`, `SSL_`, `XDG_`, `LANG`, `LC_` and the exact names `HOME`, `PATH`, `TERM`, `TMPDIR`, `TMP`, `TEMP`, `NODE_EXTRA_CA_CERTS`, and `SSH_AUTH_SOCK`, plus the harness's own family, plus whatever the spec declares in `os_env.sandbox.env_passthrough` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/agent_env.py:1-19`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/agent_env.py:37-71`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/agent_env.py:74-105`).
F66.
The Codex family allows `OPENAI_`, `REQUESTS_`, and `CODEX_HOME` prefixes but denies `OPENAI_API_KEY` by name so the CLI falls back to the `auth.json` subscription login; the Pi family allows `PI_`, `NODE_`, and the base prefixes plus `USER`; Claude native unsets `DATABRICKS_CONFIG_PROFILE` and `CLAUDECODE`, and also `ANTHROPIC_API_KEY` when an `apiKeyHelper` is configured (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/codex_executor.py:174`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/codex_executor.py:502-504`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/pi_executor.py:607-636`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/runner/native/orchestration.py:5991-5994`).
F67.
The Claude and Codex binaries can be pointed at explicit paths with `OMNIGENT_CLAUDE_PATH` and `OMNIGENT_CODEX_PATH`, while Pi is located only by `shutil.which("pi")` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/claude_sdk_executor.py:704`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/codex_executor.py:405`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/pi_executor.py:592`).
F68.
Because the native harnesses run unsandboxed (F50, F51), their `~/.claude`, `~/.codex`, and `~/.pi/agent` state is reachable in the default web-UI path; the home-hiding in F44 and F47 bites only agents that do run under bubblewrap or Seatbelt, which then need `read_paths`, `env_passthrough`, or a provider bridge (F49, F64).
F69.
Harness credentials live on the runner, not the server: each runner needs its own OS-user copies of the harness login state, so a dedicated `omnigent-host` system user on `magnetite` would need `claude auth login`, `codex login`, and Pi provider configuration performed as that user, or an Omnigent provider entry in that user's `~/.omnigent/config.yaml` (F59, F62, F63, F64).

## 9. Package availability

F70.
The pinned nixpkgs revision ships Claude Code `2.1.221`, Codex `0.146.0`, Pi `0.83.0`, and bubblewrap `0.11.2` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:pkgs/by-name/cl/claude-code/manifest.json:2`; `github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:pkgs/by-name/co/codex/package.nix:28`; `github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:pkgs/by-name/pi/pi-coding-agent/package.nix:16`; `github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:pkgs/by-name/bu/bubblewrap/package.nix:17`).
F71.
The pinned nixpkgs Pi `0.83.0` is below Omnigent's `0.84.2` floor and would report version-too-low; Claude and Codex from nixpkgs satisfy their floors (F59, F70).
F72.
The pinned `llm-agents.nix` revision ships Claude Code `2.1.260`, Codex `0.153.0`, and Pi `0.84.4`, all above the floors (`github:numtide/llm-agents.nix@10e3dca999e12a0d07f1e9e470707f4386dc3178:packages/claude-code/hashes.json:2`; `github:numtide/llm-agents.nix@10e3dca999e12a0d07f1e9e470707f4386dc3178:packages/codex/hashes.json:2`; `github:numtide/llm-agents.nix@10e3dca999e12a0d07f1e9e470707f4386dc3178:packages/pi/hashes.json:2`).
F73.
Vanixiets's Claude Code module installs the repository's own `flake.packages.<system>.claude-code`, whose manifest is `2.1.260`, whose platforms are `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`, and whose Linux wrapper adds `bubblewrap` and `socat` to `PATH`; Codex and Pi come from `flake.inputs.llm-agents.packages.<system>.codex` and `.pi` through `programs.codex` and `programs.pi-coding-agent` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/claude-code/default.nix:21-25`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:pkgs/by-name/claude-code/manifest.json:2`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:pkgs/by-name/claude-code/package.nix:26-31`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:pkgs/by-name/claude-code/package.nix:74-75`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/codex/default.nix:31-34`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/pi/default.nix:33-36`).
F74.
The `modules/home/ai/README.md` contract states that harness-specific modules each configure one agent and that `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and Pi's context are generated outputs of `../tools/agents-md.nix`, so a runner user who does not receive Home Manager also receives none of those context files (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/README.md:12`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/ai/README.md:27`).
F75.
The `crs58` profile includes the `ai` aggregate, and `cameron` on `magnetite` and `pyrite` is an alias of `crs58`, so the interactive user on all three candidate hosts already receives Claude Code, Codex, and Pi through Home Manager (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/users/crs58/meta.nix:15-25`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/users/aliases.nix:17-22`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/magnetite/default.nix:496-498`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/machines/nixos/pyrite/default.nix:389-391`).
F76.
`tmux` is configured through the `shell` aggregate's `programs.tmux` for the same profile (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/home/shell/tmux.nix:72`).
F77.
No vanixiets module, package, or unit for `omnigent`, `omnigent host`, or an `omnigent-host` user exists at the consumer revision; a search of `modules/` and `pkgs/` for `omnigent` returned no matches.
F78.
A dedicated `omnigent-host` system user would not receive the Home Manager `ai` aggregate, so a system-service runner needs the harness packages, `tmux`, `git`, `uv`, Node, and `bwrap` placed on its `PATH` by the unit rather than by Home Manager (F40, F60, F75, F77).

## 10. OIDC session TTL

F79.
The server reads `OMNIGENT_OIDC_SESSION_TTL_HOURS` with default `"8"`, an integer number of hours (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:280`).
F80.
This eight-hour value bounds the session JWT the runner presents as its bearer, and it is unchanged between `v0.12.0` and the pinned revision (`github:omnigent-ai/omnigent@f04b0354fb5344c1ea8b92795ceb6760a9ad7595:omnigent/server/oidc.py:280`).
F81.
The runner survives the eight-hour boundary only through the refresh grant of F16 to F21; the 30-day grant lifetime, not the eight-hour TTL, is the practical re-login interval for an unattended runner, which supports keeping the plan's Q15 default of 8 hours.

## 11. Tag-to-pin delta for plan Q1

F82.
`v0.12.0` resolves to `f04b0354fb5344c1ea8b92795ceb6760a9ad7595`; the pinned revision is 285 commits ahead and the full diff touches 1,012 files with 114,078 insertions and 9,449 deletions (measured with `git rev-list --count v0.12.0..381bf638fb31e6a51990d9dab54ea9ef4b933711` and `git diff --shortstat v0.12.0 381bf638fb31e6a51990d9dab54ea9ef4b933711` over the pinned clone).
F83.
Restricted to the paths the prompt names, `omnigent/server/oidc.py omnigent/server/routes/auth.py omnigent/inner/bwrap_sandbox.py omnigent/host* pyproject.toml`, the delta is 9 files, 687 insertions, and 102 deletions: `omnigent/host/_daemon_entry.py` (+69), `omnigent/host/connect.py` (+320), `omnigent/host/daemon_lifecycle.py` (+76), `omnigent/host/frames.py` (+36), `omnigent/host/identity.py` (+38), `omnigent/host/service.py` (+30), `omnigent/inner/bwrap_sandbox.py` (+54), `omnigent/server/routes/auth.py` (+139), and `pyproject.toml` (+27); `omnigent/server/oidc.py` does not appear in the stat and is byte-identical at both revisions.
F84.
`pyproject.toml` moves from `0.12.0` to `0.13.0.dev0`, bumps the `omnigent-client`, `omnigent-ui-sdk`, and `omnigent-slack` pins accordingly, and adds the extras `kms`, `microsandbox`, and `vault` plus a `build>=1.2` development dependency; no base dependency the plan relies on changes (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:8`).
F85.
The `auth.py` delta adds a `?reauth=1` forced re-authentication path that sends `prompt=login` and `max_age=0` to the issuer and rejects the callback when the `id_token` lacks `auth_time` or its `auth_time` predates the demand, and factors the existing `id_token` validation into `_validate_id_token`; the PKCE `code_challenge_method: S256` request and the `RS256`..`ES512` algorithm list the plan's D4 cites exist at both revisions (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:181-215`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:847-900`).
F86.
The `reauth` path is exercised only by the RFC 8628 device-consent flow behind `OMNIGENT_DEVICE_GRANT_ENABLED`, which at `v0.12.0` was mounted only in `accounts` mode and at the pin is also mounted in standard OIDC mode; a Kanidm deployment that leaves the flag unset never sends `prompt=login` and does not depend on Kanidm emitting `auth_time` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/device_auth.py:24-28`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/app.py:3236-3262`; F19).
F87.
The `bwrap_sandbox.py` delta is the read-root de-duplication and missing-`write_paths` creation of F46 plus a docstring note that `"*"` in `cwd_allow_hidden` allows every dotpath; the default bind set, the `/etc` allowlist, and the interpreter-chain binds are unchanged (F44, F45, F46).
F88.
The `omnigent/host/` delta adds `reset_host_id()` and the `reset-id` subcommand (F5), a launchd unload wait in `service.py`, and connection-path changes in `connect.py`, `frames.py`, `daemon_lifecycle.py`, and `_daemon_entry.py`; the login refresh-grant issuance in `auth.py`, the grant-store creation and `/oauth/token` mounting in `app.py`, the `_HostGroup` positional shorthand, and the eight-hour OIDC default are all already present at `v0.12.0` (`github:omnigent-ai/omnigent@f04b0354fb5344c1ea8b92795ceb6760a9ad7595:omnigent/server/app.py:2923-2929`; `github:omnigent-ai/omnigent@f04b0354fb5344c1ea8b92795ceb6760a9ad7595:omnigent/cli.py:8057`; F80).
F89.
Beyond the prompt's path set, the host-related delta also touches `omnigent/server/routes/host_tunnel.py` (+21, debug-event logging around the managed-token branch), `omnigent/server/routes/hosts.py` (+50), `omnigent/stores/host_store.py` (+244, liveness and managed-host columns), `omnigent/server/managed_hosts.py` (+476), `omnigent/server/routes/device_auth.py` (+45, the OIDC-mode mounting of F86), `omnigent/claude_native.py` (+315), `omnigent/pi_native_credentials.py` (+87), `omnigent/codex_native.py` (+1), and `omnigent/inner/sandbox.py` (+8).
F90.
Unchanged between the tag and the pin: `omnigent/server/oidc.py`, `omnigent/onboarding/harness_readiness.py`, `omnigent/onboarding/harness_install.py`, `omnigent/spec/_omnigent_compat.py`, `omnigent/pi_native.py`, `omnigent/native_coding_agents.py`, and `omnigent/inner/agent_env.py`, so the harness floors, registry, env filtering, and native-spec sandbox stance in F50, F54, F59, and F65 hold for the `v0.12.0` wheel the plan recommends as well as for the pin.
F91.
The plan's runner assumptions survive the delta: outbound-only runner, per-user bearer authentication with a login-issued refresh grant, bubblewrap and Seatbelt defaults, deny-by-default harness environments, and no upstream system unit are the same at both revisions; the `v0.12.0` wheel lacks only the pin-era `reset-id` recovery, the tightened cross-owner rejection, the missing-`write_paths` creation, and the OIDC-mode device-consent flow.

## Runner topology options

The options below are enumerated for the parent agent and the human gate; this note does not choose among them.
All options share these requirements: outbound HTTPS to `omni.scientistexperience.net` (F31), a unique persisted `host_id` per runner (F2, F30), a bearer token and refresh grant on the runner's disk with a human browser login at least every 30 days (F13 to F21), `tmux`, `git`, `uv`, Node, and the vendor CLIs at or above the F59 floors on the runner's `PATH` (F40, F60, F70 to F72), and `bwrap` on Linux or `sandbox-exec` on macOS for any agent that does use the default sandbox (F42, F43).

O1.
One server-local runner on `magnetite` under a dedicated `omnigent-host` system user, as the plan's D7 states.
Service: vanixiets-authored `systemd.services.omnigent-host` with `ExecStart` equivalent to `omnigent host --server https://omni.scientistexperience.net --non-interactive` (F1, F35, F38).
State: `/var/lib/omnigent-host` as home and `OMNIGENT_DATA_DIR`, holding `config.yaml`, `auth_tokens.json`, `~/.claude`, `~/.codex`, and `~/.pi/agent` (F2, F13, F63, F64).
Credentials: the operator runs `omnigent login` as `omnigent-host` once, opens the printed ticket URL in a browser on another machine within five minutes, and repeats this every 30 days; vendor CLI logins are done as that user (F15, F21, F69).
Packages: supplied by the unit's `path`, not Home Manager (F78).
Implications: the runner embeds the operator's Omnigent identity on the server host, which is the plan's Q7 decision; sessions run as `omnigent-host` on the same machine as the server and database; web-UI Claude Code, Codex, and Pi sessions are unsandboxed under F51 unless an `enforce_sandbox` policy is set (F49).

O2.
One server-local runner on `magnetite` under the existing `cameron` user via `omnigent host enable`.
Service: upstream systemd user unit under `~/.config/systemd/user/omnigent-host.service`, requiring lingering for `cameron` (F36, F37, F39).
State and credentials: `cameron`'s own `~/.omnigent`, `~/.claude`, `~/.codex`, and `~/.pi/agent`, already provisioned by the `ai` aggregate (F75).
Implications: no new user or unit in vanixiets, but the runner is not declaratively managed, the unit file is written by the CLI at mode `0600`, and sessions run with `cameron`'s full home and secrets in scope (F37, F68).

O3.
One runner per host with a single Omnigent account: `magnetite` (O1 or O2), `pyrite` (systemd user service for `cameron`), and `stibnite` (launchd agent for `crs58`).
Ownership: all three hosts must be registered by the same Kanidm-backed Omnigent identity so they appear in one picker (F24, F29).
Naming: pre-seed `host: {name: magnetite|pyrite|stibnite}` in each `config.yaml` so the default hostnames are not relied on (F3).
Service: `pyrite` and `stibnite` use `omnigent host enable`, which yields a systemd user unit on `pyrite` and `ai.omnigent.host.plist` on `stibnite` (F36).
Sandbox: agents that use the default sandbox get bubblewrap on `magnetite` and `pyrite` and Seatbelt on `stibnite`, and an `enforce_sandbox` policy that forces `linux_bwrap` would fail on `stibnite`, so a per-platform `sandbox_type` or `auto` is needed if such a policy is adopted (F42, F43, F49).
Implications: laptops go offline under the 90-second TTL during sleep and stay listed as offline; the web UI restores a remembered laptop host only when it is online and otherwise falls back to the first online host, so the operator should decide whether that fallback is acceptable (F25, F27, F32); each laptop holds a 30-day refresh grant in its interactive user's home (F21).

O4.
Laptop-only runners on `pyrite` and `stibnite` with no server-local runner, the plan's D7 reversing case.
Implications: no personal token on the server host; session availability depends on a laptop being awake; `magnetite` runs only the server (F25, F32).

O5.
Separate Omnigent accounts per runner.
Ownership: each runner logs in as a distinct Kanidm user; hosts are visible and usable only to their owner, so the operator's web session sees only the hosts registered under the operator's own identity (F24, F26, F29).
Implications: this isolates blast radius per account but makes a shared three-host picker impossible; it suits distinct humans, not one operator with three machines.

O6.
Multiple runner identities on one machine, for example `magnetite` with both an `omnigent-host` system runner (O1) and a `cameron` user runner (O2).
Requirements: distinct home directories so the two `config.yaml` files carry distinct `host_id` values and distinct names (F2, F30).
Implications: two picker rows for one machine with different privilege envelopes; useful to test the dedicated-user sandbox posture while keeping a personal fallback, at the cost of two token stores to renew (F21).

O7.
Managed-host token authentication for a non-personal runner.
Status: not available for static machines at the pinned revision; launch tokens are minted per server-provisioned sandbox and require a sandbox provider, which the plan defers (F12).
Implications: listed for completeness so the gate can see that the only unattended credential for `magnetite`, `pyrite`, or `stibnite` today is a user bearer token plus refresh grant.

Per-runner decisions the gate must make regardless of option: foreground versus background versus service (F35 to F37), dedicated home and `OMNIGENT_DATA_DIR` versus the interactive user's home (F13), whether the token store may live under a non-interactive user's home (plan Q7), which harness CLIs are installed per host and hence reported ready (F10, F57), and whether an `enforce_sandbox` policy should apply bubblewrap or Seatbelt to native sessions that upstream ships unsandboxed (F49, F51).

## Flags

R1.
Plan Q14's recommendation "upstream default native harness under bubblewrap" conflates two upstream defaults; the materialized native Claude, Codex, and Pi specs and the seeded picker agents declare `sandbox.type: none`, so the D7 `read_paths` finding would not be exercised by a web-UI Claude Code session unless an `enforce_sandbox` policy or a user-authored agent YAML applies bubblewrap (F50, F51, F53).
R2.
Upstream `README.md:140-145` states that native wrappers and the `pi` harness are mandatorily wrapped in `bwrap` on Linux, which contradicts the materialized specs at the same revision and the orchestration code that threads `type: none` through; this note treats the code as authoritative and records the README statement as stale or as describing a path not traced here (F52, F61).
R3.
The re-export wrapper `omnigent/sandbox/bwrap.py` documents that "When `bwrap` is missing, the default falls back to `none`", which contradicts the fail-loud contract in `omnigent/inner/sandbox.py`; the plan cites the `inner/` module and should keep doing so (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/sandbox/bwrap.py:15-19`; F42).
R4.
The sibling note `omnigent-upstream.md` on the working branch lists `OMNIGENT_HARNESSES` as an environment variable "Harness list override" at its line 147; it is a Python constant and no environment read exists, so that inventory row should be corrected (F55).
R5.
The pinned nixpkgs Pi `0.83.0` is below Omnigent's `0.84.2` floor; only the `llm-agents.nix` Pi `0.84.4` that vanixiets already uses satisfies it, so a runner unit must not fall back to `pkgs.pi-coding-agent` (F71, F72, F73).
R6.
Upstream `deploy/README.md` names the runner tunnel `WS /v1/runner/tunnel` while the host client dials `/v1/hosts/{host_id}/tunnel`; the code path is the one the proxy must pass through (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:228`; F6).
R7.
A dedicated `omnigent-host` system user receives none of the Home Manager `ai` aggregate, so O1 needs the harness packages and their login state provisioned by other means; no vanixiets surface does this today (F77, F78).
R8.
The refresh grant's 30-day absolute lifetime makes every unattended runner a recurring manual browser-login chore unless `OMNIGENT_GRANT_MAX_LIFETIME_DAYS` is raised; raising it is a security-sensitive choice and is left to the gate (F21).
R9.
The plan's D7 inference that a sandboxed terminal cannot exec anything under `/nix/store` is narrowed but not removed by F45: the interpreter and target binary store paths are auto-bound, their dependency store paths are not, so `read_paths` for `/nix/store` remains the expected fix and the first-session test remains necessary.
R10.
The charter's designation table and this prompt write the runner command as `omni host <server-url>` and `omnigent host <server-url>`; upstream's canonical form is `omnigent host --server <url>` with the positional form accepted as shorthand, so a systemd `ExecStart` should use the explicit option (F1).

## Additional sources acquired

- `github:numtide/llm-agents.nix@10e3dca999e12a0d07f1e9e470707f4386dc3178`, a read-only clone at the vanixiets `flake.lock` revision, read for the Claude Code, Codex, and Pi package versions the Home Manager modules install; its contributor guidance file was not used.
- `github:omnigent-ai/omnigent` tag `v0.12.0` at `f04b0354fb5344c1ea8b92795ceb6760a9ad7595`, resolved in the existing unshallowed reference clone for the plan Q1 delta.
- `github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442`, already present from the nixpkgs-modules axis and reused for package versions and the `allowUserNamespaces` default.

## Questions

Q1.
Should the deployment plan's Q14 be restated as two decisions, one for which harness seeds the first catalog and one for whether an `enforce_sandbox` policy applies bubblewrap to native sessions that upstream ships unsandboxed (R1)?
Recommended: yes, because the D7 `read_paths` risk cannot be tested by the native harness as materialized.

Q2.
Is the operator willing to hold a personal Omnigent bearer token and 30-day refresh grant under a non-interactive `omnigent-host` home on `magnetite`, and to repeat the printed-URL browser login for that user at least every 30 days (F15, F21, F23)?
Recommended: no recommendation; this is the deployment plan's Q7 gate and is security-sensitive.

Q3.
Should all three runners register under one Kanidm-backed Omnigent identity so they share one picker (O3), or does the operator want per-runner accounts and accept that they cannot be selected from one web session (O5)?
Recommended: one identity, because the three machines belong to one human and the picker is owner-scoped.

Q4.
Is the web UI's fallback to the first online host acceptable when a remembered laptop runner is asleep, or must every session creation name a host explicitly (F27)?
Recommended: accept the fallback for the first deployment and revisit after observing laptop offline behavior.

Q5.
Should the upstream `omnigent host enable` user services on `pyrite` and `stibnite` be adopted as-is, or should vanixiets author declarative systemd-user and launchd units for those hosts (F36, F37)?
Recommended: adopt upstream's for the first deployment, since they are per-user, mode `0600`, and require no repository change.

Q6.
Should the runner note in `omnigent-upstream.md` be corrected to describe `OMNIGENT_HARNESSES` as a Python constant (R4)?
Recommended: yes, in a follow-up edit to that note.

Q7.
Should the README-versus-code contradiction about mandatory `bwrap` for native wrappers be raised upstream, or first re-traced through `_resolve_session_spec_entry` to rule out a server-side spec that re-applies a sandbox (R2)?
Recommended: re-trace first, because this note followed the seeded picker agents, the orchestration terminal threading, and the terminal endpoint but did not execute a session.

Q8.
Should a first sandboxed session on `magnetite` be scheduled with a `claude-sdk` or Pi agent YAML that omits `sandbox.type`, so that bubblewrap and the NixOS `read_paths` gap are exercised independently of the native harness (F42, F45, F53, R9)?
Recommended: yes, as the concrete test for D7.

Q9.
Should charter v2 record the runner command as `omnigent host --server <url>` rather than `omni host <server-url>` (R10)?
Recommended: yes, alongside the `omnigent server` rename the plan's Q5 already proposes.

Q10.
Should `OMNIGENT_DEVICE_GRANT_ENABLED` stay unset on the Kanidm deployment so that the `prompt=login`/`auth_time` re-authentication path of F85 and F86 is never exercised, or is a device-code login for non-CLI clients wanted (F19)?
Recommended: leave it unset; `omnigent login` and the runner do not need it, and enabling it exposes a public `/oauth/device/authorize` endpoint unless `OMNIGENT_DEVICE_CLIENT_SECRET` is also set.
