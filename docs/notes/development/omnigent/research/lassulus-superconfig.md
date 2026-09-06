---
title: Research axis lassulus-superconfig
status: working-note
date: 2026-09-06
---

# Research axis `lassulus-superconfig`

Reference: `github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62` (tip commit `flake.lock: update`, 2026-09-02).
Upstream comparison point: `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711`.
Downstream comparison point: `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65`.
Terms follow the charter designation table: "Omnigent server" is the `omnigent server` process, "runner / host" is `omnigent host <server-url>`, "local sandbox" is bubblewrap or seatbelt, "OIDC mode" is authentication via `OMNIGENT_OIDC_*`.

## Summary

superconfig packages Omnigent 0.9.0 from the PyPI wheel with `python313Packages.buildPythonApplication`, runs it as a hand-written `systemd.services.omnigent` unit (no NixOS module options) on the Hetzner host `neoprism`, stores sessions in SQLite under `/var/lib/omnigent`, fronts it with nginx plus ACME at `omni.lassul.us`, and authenticates through the pocket-id IdP at `id.lassul.us` in OIDC mode.
Secrets come from one clan vars generator (`clan.core.vars.generators.omnigent`) backed by password-store, materialised as a single `EnvironmentFile`.
No runner runs on the server; the `covibe` wrapper (`tools/covibe/`) is the client that registers a laptop as a host and drives `omp` through Omnigent's `pi-native` or ACP harness.
The packaged version (0.9.0, released 2026-08-11) is three minor releases behind upstream `381bf63`, which declares `0.13.0.dev0` and whose changelog lists v0.10.0, v0.11.0 and v0.12.0 after v0.9.0.

## Entry points and import graph

- `machines/neoprism/config.nix` imports `../../2configs/omnigent.nix` at `github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:machines/neoprism/config.nix:116`, `../../2configs/covibe.nix` at `:113`, `../../2configs/pocket-id.nix` at `:110`, and `../../2configs/nginx.nix` at `:18`.
- `2configs/omnigent.nix` references the package as `self.packages.${pkgs.system}.omnigent` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:146`).
- `self.packages` is populated by `5pkgs/flake-module.nix`, which calls `lib.packagesFromDirectoryRecursive` over `5pkgs/` with a `tryEval`-wrapped `callPackage` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/flake-module.nix:11-25`); `5pkgs/omnigent/package.nix` therefore becomes `packages.<system>.omnigent`.
- `flake.nix` imports `./5pkgs/flake-module.nix` at `github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:flake.nix:210` and auto-imports every `tools/*/flake-module.nix` at `:225-233`, which is how `tools/covibe/flake-module.nix` becomes `packages.<system>.covibe`.
- The clan is built with `vars.settings.secretStore = "password-store"` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:flake.nix:107`), and `neoprism` is tagged `server` at `:133`.
- `tools/covibe/flake-module.nix` takes `omp` from the flake input `llm-agents` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:tools/covibe/flake-module.nix:12`), declared at `flake.nix:66-67` as `github:numtide/llm-agents.nix`.
- `2configs/covibe.nix` imports `self.inputs.covibe.nixosModules.default` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/covibe.nix:17`), declared at `flake.nix:85-88` as `github:lassulus/covibe`; this is the earlier co-vibing dashboard, separate from Omnigent.
- The `neoprism` host is a Hetzner machine with a bridged public IP and ZFS (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:machines/neoprism/physical.nix:42-58`).

## Version packaged and relation to upstream 381bf63

- superconfig packages `omnigent` at `version = "0.9.0"` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:80`), together with `omnigent_client` 0.9.0 (`:22`) and `omnigent_ui_sdk` 0.9.0 (`:52`).
- Upstream `381bf63` declares `version = "0.13.0.dev0"` and pins `omnigent-client==0.13.0.dev0` and `omnigent-ui-sdk==0.13.0.dev0` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:8,29-30`).
- The upstream changelog dates `v0.9.0` to 2026-08-11 and lists `v0.10.0` (2026-08-19), `v0.11.0` (2026-08-24) and `v0.12.0` (2026-09-01) after it (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:CHANGELOG.md:8,222,320,497`).
- The init commit `19d53d7` (2026-08-13) landed two days after the 0.9.0 release, and no later commit bumps the version (`git log --format='%h %ai %s' -- 5pkgs/omnigent` on the deepened clone shows `19d53d7`, `964e0ff`, `c3830f0` only).

## 1. Packaging mechanism

- Mechanism: `python313Packages.buildPythonApplication` with `format = "wheel"` over a `fetchPypi` source, not from the git tree (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:78-90`).
- The wheel is chosen because "The published wheel ships the prebuilt web SPA under omnigent/server/static/web-ui; the sdist does not." (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:83-84`).
- Hash pinning: three `sha256-` hashes, one per wheel, for `omnigent` (`:89`), `omnigent_client` (`:29`) and `omnigent_ui_sdk` (`:59`).
- Not `uv2nix`, not `pyproject-nix`, not an OCI image: search `git grep -n -iE 'uv2nix|pyproject-nix|dockerTools|oci' -- 5pkgs/omnigent 2configs/omnigent.nix tools/covibe` at the pin returns nothing.
- Dependency cycle break: `omnigent_client` is built with `pythonRemoveDeps = [ "omnigent" ]` because the two wheels depend on each other (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:16-32`).
- Runtime dependencies are listed by hand from nixpkgs (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:104-150`), including `claude-agent-sdk`, `openai-agents`, `mcp`, `fastapi`, `uvicorn`, `sqlalchemy`, `alembic`, plus `pyjwt.optional-dependencies.crypto` and `uvicorn.optional-dependencies.standard`.
- `pythonRelaxDeps` lifts seven upper bounds: `argon2-cffi`, `cachetools`, `openai`, `packaging`, `protobuf`, `rich`, `websockets` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:94-102`).
- `openai-agents` is overridden to add `websockets` as a runtime dependency "until nixpkgs catches up" (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:9-14`).
- Patches: no `.patch` files (`git ls-tree -r --name-only HEAD | grep -E '\.patch$' | grep -iE 'omnigent|covibe'` returns nothing); the one behavioural patch is a `postFixup` that wraps `$out/bin/omnigent` with `--prefix PYTHONPATH : "$program_PYTHONPATH"` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:161-164`).
- Rationale for the `postFixup`: the CLI respawns `sys.executable -m omnigent.host._daemon_entry`, which is the bare interpreter without the wrapper's site-dirs, so children fail with `ModuleNotFoundError` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:152-160`); the respawn is present upstream at `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:3246` and `PYTHONPATH` is on the daemon env allowlist at `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/connect.py:434`.
- Tests: `doCheck = false` on both sub-packages (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:41,69`); the application runs only `pythonImportsCheck` over three modules (`:166-170`).
- Platforms: `lib.platforms.unix`, `mainProgram = "omnigent"`, license `asl20` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:172-178`).

## 2. NixOS module surface

- There is no NixOS module and no `options.services.omnigent`; `2configs/omnigent.nix` is a plain configuration module that writes `systemd.services.omnigent` directly (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:106`); `git grep -n 'options\.' -- 2configs/omnigent.nix` returns nothing.
- Parameters are `let` bindings: `domain = "omni.lassul.us"`, `port = 8771`, `stateDir = "/var/lib/omnigent"` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:2-4`).
- `ExecStart` is `omnigent server --host 127.0.0.1 --port 8771 --no-open --database-uri sqlite:////var/lib/omnigent/chat.db --artifact-location /var/lib/omnigent/artifacts --agent <ompAgent>` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:145-154`).
- The upstream subcommand is a click group named `server` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:3835`), with `--database-uri` at `:3851` and `--artifact-location` at `:3863`.
- User and group: `DynamicUser = true` with `StateDirectory = "omnigent"` and `WorkingDirectory = stateDir` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:158-160`); `HOME` is set to the state directory (`:115`).
- Hardening: `ProtectSystem = "strict"`, `ProtectHome = true`, `PrivateTmp = true`, `NoNewPrivileges = true`, `ProtectKernelTunables = true`, `ProtectControlGroups = true`, `RestrictAddressFamilies = [ AF_INET AF_INET6 AF_UNIX ]` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:161-171`).
- Restart policy: `Restart = "always"`, `RestartSec = 5` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:156-157`).
- Ordering: `wantedBy multi-user.target`, `after network-online.target nginx.service`, `wants network-online.target` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:108-113`).
- Database provisioning: none; the database is SQLite at `${stateDir}/chat.db` created by the application (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:151`); `git grep -n -iE 'postgres|services\.postgresql' -- 2configs/omnigent.nix` returns nothing.
- Non-secret environment: `OMNIGENT_AUTH_ENABLED=1`, `OMNIGENT_AUTH_PROVIDER=oidc`, `OMNIGENT_OIDC_ISSUER`, `OMNIGENT_OIDC_REDIRECT_URI`, `OMNIGENT_OIDC_LOGOUT_REDIRECT_URI`, `OMNIGENT_OIDC_ALLOWED_DOMAINS=lassul.us`, `OMNIGENT_OIDC_SKIP_EMAIL_VERIFICATION=1`, `OMNIGENT_OIDC_SESSION_TTL_HOURS=168`, `OMNIGENT_ADMIN_LIST_PATH`, `OMNIGENT_NO_UPDATE_CHECK=1`, `OMNIGENT_TELEMETRY_ENABLED=0` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:114-143`).
- Admin list: a store file containing `lass@lassul.us`, one identity per line, passed through `OMNIGENT_ADMIN_LIST_PATH` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:62-64,138`); upstream reads that variable at `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/admin_list.py:80`.
- Server-side agent catalog: a single-file YAML spec `omnigent-agent-omp.yaml` with `executor.harness: acp`, `acp_agent.command: omp acp`, `omnigent_mcp: false`, `os_env.type: caller_process`, `sandbox.type: none`, and a `terminals.shell` entry running `bash` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:27-57`).
- The single-file shape is a workaround: "the bundle parser stringifies nested values under `executor.config`, so `acp_agent` arrives as a string" (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:20-26`).

## 3. Reverse proxy and TLS integration

- Proxy: nginx, `services.nginx.virtualHosts."omni.lassul.us"` with `enableACME = true` and `forceSSL = true` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:175-177`).
- Upstream binding: `proxyPass = "http://127.0.0.1:8771"` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:179`).
- Websocket and SSE: `proxyWebsockets = true` plus `proxy_read_timeout 1d; proxy_send_timeout 1d;` because "The session event stream is SSE (omnigent sets X-Accel-Buffering: no, which nginx honours) and the terminal/host/runner tunnels are WebSockets that idle between turns" (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:180-188`).
- ACME: shared host-level config `security.acme.acceptTerms = true`, `security.acme.defaults.email = "acme@lassul.us"`, firewall ports 80 and 443, `recommendedTlsSettings`, a default 404 vhost, and an `acme-challenge` location (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/nginx.nix:2-37`).
- Caddy: not present; `git grep -n -i caddy -- 2configs/omnigent.nix 2configs/nginx.nix machines/neoprism` at the pin returns nothing.

## 4. Secret source

- Mechanism: clan vars with `secretStore = "password-store"` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:flake.nix:107`); not sops-nix, not agenix (`git grep -n -iE 'sops|agenix' -- 2configs/omnigent.nix 5pkgs/omnigent tools/covibe` returns nothing).
- Generator: `clan.core.vars.generators.omnigent` with one secret file `env`, one prompt `oidc_client` of `type = "multiline"` with `persist = true`, `runtimeInputs = [ pkgs.openssl ]`, and a script that writes `OMNIGENT_OIDC_COOKIE_SECRET=$(openssl rand -hex 32)` followed by the pasted prompt text (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:83-104`).
- Variables supplied through the secret file: `OMNIGENT_OIDC_COOKIE_SECRET` (generated), `OMNIGENT_OIDC_CLIENT_ID` and `OMNIGENT_OIDC_CLIENT_SECRET` (pasted by the operator as two `KEY=value` lines) (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:90-92,100-101`).
- Consumption: `EnvironmentFile = [ config.clan.core.vars.generators.omnigent.files."env".path ]` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:155`).
- Upstream requires exactly `OMNIGENT_OIDC_ISSUER`, `OMNIGENT_OIDC_CLIENT_ID`, `OMNIGENT_OIDC_CLIENT_SECRET` and `OMNIGENT_OIDC_COOKIE_SECRET` in OIDC mode, the last at least 64 hex characters (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:252-254,270-277`).
- No `restartUnits` or equivalent is declared on the generator; `git grep -n restartUnits -- 2configs/omnigent.nix` returns nothing.
- No public vars files for omnigent are committed under `vars/per-machine/neoprism/` (`git ls-tree -r --name-only HEAD vars/per-machine/neoprism | grep omnigent` returns nothing), consistent with `env` being a secret file.

## 5. OIDC/SSO wiring and identity provider

- IdP: pocket-id at `https://id.lassul.us`, a passkey OIDC provider run on the same host via `services.pocket-id` behind nginx on port 1411, with its own clan vars generator for `ENCRYPTION_KEY` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/pocket-id.nix:2-3,17-44`).
- Client registration is manual: "pocket-id has no declarative client API, so register the client by hand" with name `omnigent`, callback `https://omni.lassul.us/auth/callback`, logout URL `https://omni.lassul.us/` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:74-79`).
- Omnigent is in OIDC mode: `OMNIGENT_AUTH_ENABLED=1`, `OMNIGENT_AUTH_PROVIDER=oidc`, issuer, redirect and logout URIs, domain allowlist `lassul.us` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:116-121`).
- `OMNIGENT_OIDC_SKIP_EMAIL_VERIFICATION=1` is set because pocket-id emits `email_verified=false` by default and Omnigent otherwise rejects the login with "Could not determine user email from IdP" (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:122-131`); upstream reads this flag at `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:304` and applies it at `omnigent/server/routes/auth.py:934-988`.
- Session TTL is raised from the 8-hour default to 168 hours (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:132-137`); the default is at `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:280`.
- Authorization is by admin list plus per-session ACLs, not by group claims: "Admins bypass every per-session ACL" (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:59-61`); `git grep -n -iE 'group|role' -- 2configs/omnigent.nix` returns nothing beyond that comment.
- CLI login uses Omnigent's cli-ticket flow, `POST /auth/cli-login` then poll `/auth/cli-poll`, so only a browser needs to reach pocket-id (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:tools/covibe/flake-module.nix:38-44`); the endpoints exist at `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:4,64-65`.
- The sso-gateway pattern (oauth2-proxy) is not used; the repo removed its oauth2-proxy config on 2026-07-19 (`7f6f51a 2026-07-19 00:20:57 +0200 2configs/oauth2-proxy: remove (no gated services left); keep pocket-id for hedgedoc`, from `git log -- 2configs/pocket-id.nix`).

## 6. Runner/host placement and sandbox provisioning

- No runner runs on the server: "the agents themselves run on whichever machine registers as a *host*, so no coding agent runs on neoprism unless someone points a host at it" (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:67-72`).
- No systemd unit for `omnigent host` exists anywhere in the repo; `git grep -n 'omnigent host' -- . ':!tools/covibe'` at the pin returns nothing.
- The host is registered ad hoc from a client machine: `covibe host` runs `exec omnigent host "$server" "$@"` in the foreground (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:tools/covibe/flake-module.nix:92-100`), with `server = "https://omni.lassul.us"` hard-coded (`:11`).
- Default client path: `covibe` runs `omnigent pi --server "$server" "$@"`, the `pi-native` harness, after checking the cached JWT expiry in `~/.omnigent/auth_tokens.json` with `jq` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:tools/covibe/flake-module.nix:103-114`).
- `omp` is substituted for upstream `pi` through a `pi` shim: `pi-native` "resolves the CLI by the literal name `pi`", so `writeShellApplication { name = "pi"; }` wraps `omp` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:tools/covibe/flake-module.nix:13-28`).
- The shim rewrites arguments: drops `--approve`, maps `--session <id>` to `--resume <id>`, and generates an ESM adapter `omnigent-esm-adapter.mjs` next to Omnigent's CommonJS bridge extension because omp only accepts ESM factories (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:tools/covibe/pi-shim.sh:4-43`).
- Runtime inputs of the client: `omnigent`, the `pi` shim, `omp`, `tmux`, `jq`, `git` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:tools/covibe/flake-module.nix:55-68`).
- Sandbox: the browser-started `omp` agent declares `os_env.type: caller_process` with `sandbox.type: none` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:43-47`), which upstream documents as "For trusted local development" (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:docs/AGENT_YAML_SPEC.md:217-225`).
- No bubblewrap or managed sandbox provider appears in the superconfig tree for this service; `git grep -n -iE 'bwrap|bubblewrap|modal|daytona|kubernetes' -- 2configs/omnigent.nix tools/covibe 5pkgs/omnigent` returns nothing.
- The `pi-native` TUI path uses a spec Omnigent materialises itself (`pi-native-ui`), not the server catalog entry (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:tools/covibe/flake-module.nix:48-51`); whether that path applies bubblewrap on Linux is governed by upstream, which states the `pi` harness wraps each agent terminal in `bwrap` and that on Linux "that isolation is mandatory" (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:140-145`).
- Omnigent's MCP relay is disabled for the ACP agent (`omnigent_mcp: false`) because "omp fails session/new outright when omnigent's MCP relay cannot start, and the relay's `python -I -m omnigent…` child cannot import omnigent under a nixpkgs-wrapped interpreter" (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:37-41`).

## 7. Buzz-specific analogues (relay, Postgres, Redis)

- superconfig has no Buzz deployment; `git grep -n -i buzz` at the pin returns nothing.
- The closest analogue is `2configs/covibe.nix`, the earlier co-vibing dashboard, which uses the same three patterns Omnigent inherits: a clan vars generator writing `COVIBE_COOKIE_SECRET`, `COVIBE_API_KEYS` and a prompted `COVIBE_OIDC_CLIENT_SECRET` into one `env` file (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/covibe.nix:22-39`), pocket-id OIDC with a hard-coded `clientId` (`:53-57`), and an nginx vhost with `proxyWebsockets` and one-day timeouts on the relay path `/r/` (`:61-80`).
- The covibe relay comment states the reason for the long timeout: "neither the relay nor omp send keepalive pings, so nginx's default 60s proxy_read_timeout would sever idle sessions" (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/covibe.nix:63-67`); the omnigent vhost repeats the same setting for SSE and WebSocket tunnels (`2configs/omnigent.nix:180-188`).
- Postgres: not present for Omnigent or covibe; `git grep -n -iE 'postgres' -- 2configs/omnigent.nix 2configs/covibe.nix` returns nothing; Omnigent runs on SQLite (`2configs/omnigent.nix:151`).
- Redis: not present; `git grep -n -iE 'redis|valkey' -- 2configs/omnigent.nix 2configs/covibe.nix tools/covibe` returns nothing.
- The vanixiets Buzz note records that Buzz needs Postgres plus "a Redis instance that exists nowhere in the fleet" (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:docs/notes/development/buzz/self-hosting.md:144`); Omnigent as deployed here needs neither, so the direct analogue is the relay's long-lived WebSocket proxy shape only.
- Omnigent's session sharing (owner/manager grants of read or edit) is the Omnigent-side analogue to Buzz's relay-mediated collaboration (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:59-61`, `tools/covibe/flake-module.nix:31-36`).

## 8. Apparent maintenance intent

Commit history for the relevant paths at the pin (`git log --format='%h %ai %s' -- <path>`, run on the clone after `git fetch --unshallow --filter=blob:none`; the clone as delivered was depth 1):

`5pkgs/omnigent`:

```
c3830f0 2026-09-02 00:31:47 +0200 5pkgs.omnigent: fix build against updated nixpkgs
964e0ff 2026-08-13 17:07:42 +0200 pkgs.omnigent: hand the dependency closure to respawned daemons
19d53d7 2026-08-13 14:26:07 +0200 pkgs.omnigent: init at 0.9.0
```

`2configs/omnigent.nix`:

```
b408ae5 2026-08-19 13:52:06 +0200 2configs/omnigent: let browser sessions open a shell on the host
3844401 2026-08-14 12:13:34 +0200 2configs/omnigent: register the omp agent as a single-file spec
686df0d 2026-08-14 11:47:46 +0200 2configs/omnigent: give CLI sessions a week-long TTL
72963af 2026-08-13 17:07:42 +0200 omnigent: run omp without the omnigent MCP relay
5cf875f 2026-08-13 16:27:02 +0200 2configs/omnigent: accept pocket-id logins without email_verified
dba670b 2026-08-13 14:26:07 +0200 2configs/omnigent: serve omni.lassul.us with pocket-id login
```

`tools/covibe`:

```
3dab422 2026-08-19 13:52:06 +0200 tools.covibe: put omp on the host daemon's PATH
f7b5559 2026-08-14 12:13:34 +0200 tools.covibe: add login and host subcommands
9766c9d 2026-08-14 11:47:46 +0200 tools.covibe: re-login when the cached session has expired
6f644d4 2026-08-13 17:51:28 +0200 tools.covibe: run omp's own TUI via omnigent's pi-native harness
72963af 2026-08-13 17:07:42 +0200 omnigent: run omp without the omnigent MCP relay
84ff373 2026-08-13 14:26:07 +0200 tools.covibe: run omp as an omnigent session on omni.lassul.us
234c2f6 2026-07-27 12:44:37 +0200 covibe: take the patched omp + client wrapper from the covibe flake
d01befb 2026-07-25 13:17:48 +0200 tools.covibe: drop API key (dashboard announce is keyless now)
6f09651 2026-07-25 12:57:49 +0200 tools.covibe: register sessions in the dashboard (remote mode)
0a05a40 2026-07-25 12:09:34 +0200 tools.covibe: omp collab client that hosts on the covibe relay
```

- The whole Omnigent integration was written in one week, 2026-08-13 to 2026-08-19, then touched once on 2026-09-02 to repair the build after a nixpkgs bump ("openai-agents 0.18.1 gained a websockets runtime dep that nixpkgs does not declare yet, and nixpkgs' openai 2.53.0 is past omnigent's <2.45 cap", commit `c3830f0` body).
- The package has not been bumped past 0.9.0 despite three upstream minor releases in that window (see "Version packaged").
- TODO/FIXME markers: none in the relevant files; `git grep -n -iE 'TODO|FIXME|XXX|HACK|broken' -- 5pkgs/omnigent 2configs/omnigent.nix tools/covibe 2configs/covibe.nix` returns nothing.
- Breakage record: every non-init commit message and most long comments describe a workaround for an observed failure (daemon `ModuleNotFoundError`, MCP relay import failure, bundle-parser stringification, `email_verified` rejection, expired JWT 401, missing `omp` on host PATH), which indicates active use on one machine rather than a reusable module.
- The repository's own AGENTS.md describes it as "lassulus's personal NixOS/nix-darwin configuration repository" and states that only packages that "could in theory be upstreamed to nixpkgs should go into the pkgs folder" (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:AGENTS.md:5-11`); no downstream-consumer commitment is stated, consistent with charter W7.
- The flake tracks `nixos-unstable` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:flake.nix:8`), so the `pythonRelaxDeps` list and the `openai-agents` override are tied to whatever nixpkgs revision the lock holds.

## Flags

- Version skew: packaged 0.9.0 (2026-08-11 release) versus upstream `381bf63` at `0.13.0.dev0`; v0.10.0, v0.11.0 and v0.12.0 are unpackaged (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:80`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:CHANGELOG.md:8,222,320,497`).
- Patched for one machine: `omni.lassul.us`, `id.lassul.us`, allowlist `lassul.us`, admin `lass@lassul.us` and the client-side server URL are literals, not options (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:2,63,118,121`; `tools/covibe/flake-module.nix:11`).
- nixpkgs-specific workaround that a vanixiets derivation would need to reproduce: the `PYTHONPATH` `postFixup` for respawned daemons (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:152-164`) and the consequence that Omnigent's MCP relay is disabled for the ACP agent (`2configs/omnigent.nix:37-41`).
- Dependency drift surface: seven `pythonRelaxDeps` and one `openai-agents` override, the last added 2026-09-02 after a nixpkgs bump broke the build (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:9-14,94-102`; commit `c3830f0`).
- Security posture divergence from charter W4: the only server-catalogued agent runs with `sandbox.type: none` and can open a `bash` terminal on the host from the browser (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:43-56`).
- `OMNIGENT_OIDC_SKIP_EMAIL_VERIFICATION=1` waives an upstream login gate; whether Kanidm emits `email_verified=true` determines whether vanixiets needs the same waiver (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:122-131`).
- Half-finished from a fleet standpoint: no runner unit exists; hosting depends on a person running `covibe host` in a foreground shell (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:tools/covibe/flake-module.nix:92-100`).
- Upstream-internals coupling in the client: `pi-shim.sh` rewrites `pi-native` arguments and writes an adapter file into Omnigent's extension directory at runtime (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:tools/covibe/pi-shim.sh:31-43`); the comment at `tools/covibe/flake-module.nix:18-19` cites `resolve_cli_binary("pi")`, while upstream `381bf63` calls `resolve_cli_binary(spec.binary)` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/onboarding/harness_install.py:866`), so the literal-name claim is unverified at the current upstream.
- No test execution: `doCheck = false` on both sub-packages and only `pythonImportsCheck` on the application (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:5pkgs/omnigent/package.nix:41,69,166-170`).
- No `restartUnits` on the vars generator, so a regenerated secret does not restart the service (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:83-104`).
- Terminology skew with the charter: the charter designation table names the process `omnigent serve`; superconfig invokes `omnigent server` (`github:Lassulus/superconfig@afb34bfd269290c395d3cedd8a234a66e7d9ad62:2configs/omnigent.nix:147`) and upstream defines the click group as `"server"` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:3835`).

## Additional sources acquired

- None acquired with `ghq get`.
- The existing `github:Lassulus/superconfig` clone was deepened in place with `git fetch --unshallow --filter=blob:none origin` to obtain commit history for dimension 8; `HEAD` remained `afb34bfd269290c395d3cedd8a234a66e7d9ad62` and nothing was checked out.

## Questions

- Q1 The charter designation table says "the `omnigent serve` process", but both superconfig and upstream `381bf63` use the subcommand `server`; should the charter designation be corrected in a v2 entry, or is `serve` intended as prose rather than the literal command?
- Q2 Charter W4 states bubblewrap is mandatory on Linux, but superconfig's browser-started ACP agent runs `sandbox.type: none`, which upstream permits for "trusted local development"; does the plan need to decide which harness path (ACP versus `pi-native` versus native terminal wrappers) the vanixiets runner uses, since the sandbox obligation differs by path?
- Q3 The charter's `-bin` proxy derivation is defined as fetching "hashed upstream release artifacts"; Omnigent's release artifact is a PyPI wheel that still needs a Python dependency closure from nixpkgs, which is what superconfig does; does a wheel-based `buildPythonApplication` count as the `-bin` proxy convention for D2, or is it a third option?
- Q4 Dimension 8 required commit dates but the delivered clone was depth 1, so I deepened it with a blobless fetch; is mutating the shared ghq clone's object store in this way acceptable under the "check out nothing" rule, or should future axes request pre-deepened clones?
- Q5 The prompt asked for "Buzz-specific" analogues, but superconfig contains no Buzz deployment; is the covibe dashboard and its relay vhost (`2configs/covibe.nix`) the intended comparison surface, or should dimension 7 be marked not applicable for this axis?
