---
title: Research axis omnigent-upstream
status: working-note
date: 2026-09-06
---

# Research axis: `omnigent-ai/omnigent`

Axis revision: `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711` (`main`, commit "fix(web): let keyboard/AT scrolling settle the scroll restore (#6643)", 2026-09-06 17:39:45 +0200).
Terms follow the charter designation table in `docs/notes/development/omnigent/charter.md`.
Every upstream citation below has the form `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:<path>:<line>`; the revision is written in full each time so the charter A2 check resolves it mechanically.

## Scope and method

The reading set was `deploy/README.md`, `deploy/docker/`, `deploy/fly/`, `deploy/kubernetes/`, `README.md`, `pyproject.toml`, `omnigent/version.py`, the three release workflows under `.github/workflows/`, and the server, host, and sandbox modules reached from `rg -n 'OMNIGENT_' omnigent/`.
Upstream has no single settings module; environment variables are read at their point of use across `omnigent/server/*.py`, `omnigent/server/routes/*.py`, `omnigent/host/local_server.py`, `omnigent/cli.py`, and `deploy/docker/entrypoint.py`, so the table in section "Server environment variables" cites the first read site of each variable.
The upstream documentation titled "Auth", "Single sign-on (OIDC)", and "Database: Postgres or SQLite" lives inline in `deploy/README.md`; the cloud sandbox host material is the section "Run hosts in cloud sandboxes" of the same file, and no standalone file named "Cloud Sandbox Host" exists at this revision (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:144`, `:267`, `:390`, `:416`).
The local reference clone was depth-1 at the start of this axis; it was deepened by 400 commits with `git fetch --deepen=400 origin` so that `git log -- <path>` covers 2026-08-27 through 2026-09-06, and HEAD was unchanged by that fetch.
Searches for `buzz`, `omp`, `atomic`, `ACP`, `landlock`, `groups`, `roles`, `X-Accel-Buffering`, `proxy_read_timeout`, and `shutil.which(` were run over the whole tree excluding `node_modules` and lockfiles.

## Version and release mechanism

The project version at this revision is `0.13.0.dev0`, declared in `pyproject.toml` and mirrored in `omnigent/version.py` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:8`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/version.py:15`).
The newest changelog release is `v0.12.0` dated 2026-09-01, preceded by `v0.11.0` (2026-08-24) and `v0.10.0` (2026-08-19), a weekly minor cadence (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:CHANGELOG.md:8`, `:222`, `:320`).
The build backend is setuptools and `requires-python` is `>=3.12` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:1-3`, `:11`).
Two console scripts are installed, `omnigent` and the short alias `omni`, both resolving to `omnigent.cli:main` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:396-397`).

Three artifact channels exist.

1. PyPI: the release workflow runs `uv build --out-dir dist` to produce the core sdist and wheel, builds the `omnigent-client` and `omnigent-ui-sdk` wheels, asserts the web-UI bundle is inside the core wheel, and publishes to TestPyPI then PyPI via OIDC Trusted Publishing (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:.github/workflows/release-omnigent.yml:1-14`, `:125-144`).
2. GHCR: `oss-publish-images.yml` publishes `ghcr.io/omnigent-ai/omnigent-server`, `ghcr.io/omnigent-ai/omnigent-host`, and `-openshell`, `-kubernetes`, `-modal` server variants, tagged `:sha-<short>`, `:vX.Y.Z`, `:latest`, `:latest-rc`, and `:latest-nightly`, for `linux/amd64,linux/arm64` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:.github/workflows/oss-publish-images.yml:1-18`, `:116-120`, `:191`).
3. GitHub Releases: `github-release.yml` is metadata only, attaches no wheels, and carries only the source tarball GitHub auto-attaches; the release is created as a draft for a human to publish (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:.github/workflows/github-release.yml:1-24`).

Prebuilt artifacts per platform follow from the above.
For `x86_64-linux` the prebuilt artifacts are the pure-Python wheel on PyPI and the `linux/amd64` OCI images; no standalone native binary is published (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:.github/workflows/github-release.yml:15-17`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Dockerfile:28-31`).
For `aarch64-darwin` the documented install paths are `uv tool install omnigent`, `pip install omnigent`, the Homebrew tap `omnigent-ai/tap/omnigent`, and `uv tool install ... git+https://github.com/omnigent-ai/omnigent.git`; no darwin binary release exists, and the wheel is platform-independent (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:95-116`).
The `-bin` designation in the charter therefore maps to "wheel from PyPI" rather than to a native executable; there is no upstream Nix expression, flake, or `-bin` derivation in the tree.

## Runtime dependencies

`uv` and `git` are listed as required by the upstream installer; Node.js 22 LTS or newer with `npm` is required for the coding-harness CLIs installed by `omnigent run`, and `pnpm` for the web UI (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:124-130`).
`tmux` is required by the native terminal wrappers `claude`, `codex`, `cursor`, `hermes`, `kiro`, and `pi` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:136-139`).
`bubblewrap` (`bwrap`) is Linux-only and mandatory for the native terminal wrappers and the `pi` harness; a missing `bwrap` makes those terminals fail to start, and macOS uses the built-in `seatbelt` sandbox (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:140-145`).
`harness_install.py` installs Node-based harness CLIs with `npm install -g <package>` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/onboarding/harness_install.py:1000`).
The install ledger tracks the dependency set `uv`, `node`, `npm`, `tmux`, `bwrap` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/install_ledger.py:539`).
`shutil.which(` occurs 76 times under `omnigent/`; the probed binaries and occurrence counts are `tmux` (27), `uv` (5), `sandbox-exec` (3), `databricks` (3), `srt` (2), `sh` (2), `bwrap` (2), `bash` (2), and one each of `uvx`, `ucode`, `strace`, `pi`, `opencode`, `omnigent`, `node`, `hermes`, `goose`, `gh`, `claude`, `agy` (representative sites: `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:318`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli_config.py:130`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/runner/github_resource.py:309`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/onboarding/sandboxes/bootstrap.py:118`).
`git` is invoked directly by subprocess for worktrees (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/git_worktree.py:112`).
Core Python dependencies include `uvicorn[standard]`, `websockets`, `alembic`, `fastapi`, and `sqlalchemy` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:43`, `:46`, `:70`, `:79`, `:86`).
`psycopg[binary]` is not a baseline dependency; it appears only in the `databricks` extra, and the Docker server image installs it explicitly (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:282-287`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Dockerfile:157-159`).
Managed-sandbox provider extras are `modal`, `daytona`, `blaxel`, `boxlite`, `microsandbox`, `cwsandbox`, `e2b`, `islo`, `openshell`, and `kubernetes` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:167`, `:171`, `:174`, `:179`, `:182`, `:186`, `:190`, `:195`, `:199`, `:204`).
The server image deliberately omits `tmux`, `git`, and harness runtime requirements because runners run outside it, while the host image bakes in `git`, `tmux`, Node, and the `claude`, `codex`, `pi`, and `kiro-cli` CLIs (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Dockerfile:1-27`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/README.md:266-275`).
Docker base images are `python:3.12-slim` for builder, host, and runtime stages and `node:22-slim` for the web builder and Node runtime stages (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Dockerfile:62-63`, `:75`, `:99`, `:173`, `:201`, `:422`).

## Database

Postgres is described as "the default and the production answer" and is required for more than one server instance; SQLite is the "lite tier" for demos and single-instance deploys with the tradeoffs "single instance only, no managed backups" (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:149-165`).
Both backends share one schema and one Alembic migration set (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:146-147`).
The bare `omnigent server` command defaults to `sqlite:///<data_dir>/chat.db`, with `--database-uri` or the config key `database_uri` overriding it (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:1274-1286`, `:4100`).
The daemon-owned local server also defaults to SQLite at `<data_dir>/chat.db` and honours `OMNIGENT_DATABASE_URI` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/local_server.py:633`).
The data directory is `OMNIGENT_DATA_DIR` or `~/.omnigent` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/local_server.py:60-61`).
The Docker entrypoint requires `DATABASE_URL` from the environment or `database_uri` from config, normalises `postgres://` and `postgresql://` to `postgresql+psycopg://`, and reads `ARTIFACT_DIR`, `HOST`, and `PORT` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/entrypoint.py:132-153`).
Docker Compose provisions `postgres:16-alpine` and injects `DATABASE_URL=postgresql+psycopg://...@postgres:5432/...` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/docker-compose.yaml:26-27`, `:61`).
Fly defaults to `DATABASE_URL = "sqlite:////data/artifacts/chat.db"` on a persistent volume and recommends Postgres for multiple instances or managed backups (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/fly/fly.toml:22-25`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/fly/README.md:72-75`).
Migrations run at startup with `alembic.command.upgrade("head")` on every boot, and a connect-and-migrate retry with linear backoff exists for cold managed Postgres endpoints (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/db/utils.py:398-405`, `:460-470`).
First boot against a remote Postgres takes about one minute for migrations, so health-check grace must tolerate it (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:176-180`).
Kubernetes runs one replica because the runner registry is in memory; Redis is named only as a hypothetical shared registry (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/kubernetes/README.md:385-387`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/kubernetes/base/deployment.yaml:8`).

## Server environment variables

The table lists every `OMNIGENT_*` variable read by server, entrypoint, database, and local-server code plus the four un-prefixed entrypoint variables, with the first read site as citation.
Variables read only by client, harness, or CLI-install code (`OMNIGENT_HOME`, `OMNIGENT_INDEX_URL`, `OMNIGENT_PYTHON_EXECUTABLE`, `OMNIGENT_REQUIRE_WRAPPER`, `OMNIGENT_WRAPPER_*`, `OMNIGENT_UNINSTALL_LEDGER_*`, `OMNIGENT_SERVER_URL`, `OMNIGENT_RUNNER_TUNNEL_TOKEN`, `OMNIGENT_HOST_TOKEN`) are excluded from the server table.
All paths are relative to the repository root at `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711`.

| Variable | Role | First read site |
|---|---|---|
| `DATABASE_URL` | Entrypoint database URL, env-first, normalised to psycopg3 | `deploy/docker/entrypoint.py:132` |
| `ARTIFACT_DIR` | Entrypoint artifact directory, default `/data/artifacts` | `deploy/docker/entrypoint.py:146` |
| `HOST` | Entrypoint bind host | `deploy/docker/entrypoint.py:151` |
| `PORT` | Entrypoint bind port, default `8000` | `deploy/docker/entrypoint.py:153` |
| `OMNIGENT_AUTH_ENABLED` | Master auth switch; entrypoint sets default `1` | `omnigent/server/auth.py:313-325`, `deploy/docker/entrypoint.py:182` |
| `OMNIGENT_AUTH_PROVIDER` | Explicit `accounts`, `oidc`, or `header` pin | `omnigent/server/auth.py:358-360` |
| `OMNIGENT_AUTH_HEADER` | Header-mode identity header, default `X-Forwarded-Email` | `omnigent/server/auth.py:9` |
| `OMNIGENT_AUTH_HEADER_STRIP_PREFIX` | Header-mode prefix removal | `omnigent/server/auth.py:108` |
| `OMNIGENT_LOCAL_SINGLE_USER` | Single-user local mode | `omnigent/host/local_server.py:666` |
| `OMNIGENT_OIDC_ISSUER` | OIDC issuer; presence selects `oidc` | `omnigent/server/oidc.py:252` |
| `OMNIGENT_OIDC_CLIENT_ID` | OIDC client id | `omnigent/server/oidc.py:253` |
| `OMNIGENT_OIDC_CLIENT_SECRET` | OIDC client secret | `omnigent/server/oidc.py:254` |
| `OMNIGENT_OIDC_REDIRECT_URI` | Explicit callback URL | `omnigent/server/oidc.py:260` |
| `OMNIGENT_DOMAIN` | Derives `https://<domain>/auth/callback`; also used by Caddy overlay | `omnigent/server/oidc.py:262-268` |
| `OMNIGENT_OIDC_COOKIE_SECRET` | Hex cookie secret, at least 32 bytes | `omnigent/server/oidc.py:270-278` |
| `OMNIGENT_OIDC_SESSION_TTL_HOURS` | Session TTL, default 8 | `omnigent/server/oidc.py:280` |
| `OMNIGENT_OIDC_LOGOUT_REDIRECT_URI` | Post-logout redirect | `omnigent/server/oidc.py:281-283` |
| `OMNIGENT_OIDC_ALLOWED_DOMAINS` | Comma-separated email domain allowlist | `omnigent/server/oidc.py:285-290` |
| `OMNIGENT_OIDC_ALLOWED_DOMAINS_PATH` | Path override for runtime allowlist file | `omnigent/server/oidc_access.py:44` |
| `OMNIGENT_OIDC_ALLOW_INVITES` | Enables individual OIDC invites | `omnigent/server/oidc.py:297` |
| `OMNIGENT_OIDC_SKIP_EMAIL_VERIFICATION` | Trusts email claim without `email_verified` | `omnigent/server/oidc.py:304` |
| `OMNIGENT_OIDC_EMAIL_CLAIM` | Identity claim name, default `email` | `omnigent/server/oidc.py:316` |
| `OMNIGENT_OIDC_SCOPES` | Scope override, default `openid email profile` | `omnigent/server/oidc.py:338`, `:359` |
| `OMNIGENT_ACCOUNTS_COOKIE_SECRET` | Accounts-mode cookie secret | `omnigent/server/accounts_config.py:119` |
| `OMNIGENT_ACCOUNTS_BASE_URL` | Accounts-mode public base URL | `omnigent/server/accounts_config.py:132` |
| `OMNIGENT_ACCOUNTS_INIT_ADMIN_PASSWORD` | Pre-seeds first admin password | `omnigent/cli.py:3907` |
| `OMNIGENT_ACCOUNTS_INIT_ADMIN_USERNAME` | Pre-seeds first admin username | `omnigent/server/accounts_bootstrap.py:71` |
| `OMNIGENT_ACCOUNTS_SESSION_TTL_HOURS` | Accounts session TTL | `omnigent/server/accounts_config.py:138` |
| `OMNIGENT_ACCOUNTS_INVITE_TTL_HOURS` | Invite TTL | `omnigent/server/accounts_config.py:139` |
| `OMNIGENT_ACCOUNTS_MAGIC_TTL_MINUTES` | Magic-link TTL | `omnigent/server/accounts_config.py:140` |
| `OMNIGENT_ACCOUNTS_AUTO_OPEN` | Auto-open browser on local server | `omnigent/cli.py:3964` |
| `OMNIGENT_ADMIN_CREDENTIALS_PATH` | Anchors data dir; admin credential file | `omnigent/server/admin_list.py:58` |
| `OMNIGENT_ADMIN_LIST_PATH` | Path override for `<data_dir>/admins` | `omnigent/server/admin_list.py:77` |
| `OMNIGENT_CONFIG` | Explicit server config file path | `omnigent/server/server_config.py:60` |
| `OMNIGENT_CONFIG_HOME` | Config-only home override | `omnigent/host/local_server.py:68` |
| `OMNIGENT_DATA_DIR` | Runtime data dir override, default `~/.omnigent` | `omnigent/host/local_server.py:60` |
| `OMNIGENT_DATABASE_URI` | Local-server database override | `omnigent/host/local_server.py:633` |
| `OMNIGENT_DB_URL` | Alembic ini database URL | `omnigent/db/alembic.ini:4` |
| `OMNIGENT_ARTIFACT_URI` | Remote `s3://` artifact store | `deploy/docker/entrypoint.py:159` |
| `OMNIGENT_LAKEBASE_INSTANCE` | Databricks Lakebase instance | `omnigent/db/utils.py:47` |
| `OMNIGENT_FEATURES` | Comma-separated release features | `omnigent/server/routes/hosts.py:560` |
| `OMNIGENT_HARNESS_INSTALL_ENABLED` | Feature flag for harness installs | `omnigent/server/feature_flags.py:17` |
| `OMNIGENT_LOG_LEVEL` | Server log level | `omnigent/server/app.py:1339` |
| `OMNIGENT_WEB_UI_DIST` | Web UI dist directory override | `omnigent/server/app.py:239` |
| `OMNIGENT_SKIP_WEB_UI` | API-only landing | `omnigent/server/static/api_only_landing.html:34` |
| `OMNIGENT_BUILTIN_AGENT_DIRS` | Extra builtin agent directories | `omnigent/server/app.py:689` |
| `OMNIGENT_SHARING_MODE` | Session sharing mode | `omnigent/server/app.py:1185` |
| `OMNIGENT_PUBLIC_SHARING` | Public sharing toggle | `omnigent/server/app.py:1204` |
| `OMNIGENT_TERMINAL_BRIDGE` | Terminal bridge toggle | `omnigent/server/app.py:1323` |
| `OMNIGENT_WS_ALLOWED_ORIGINS` | WebSocket origin allowlist | `omnigent/server/ws_origin.py:31` |
| `OMNIGENT_INTERNAL_WS_ORIGIN` | Internal WebSocket origin | `omnigent/server/ws_origin.py:22` |
| `OMNIGENT_DEVICE_GRANT_ENABLED` | CLI device-grant login | `omnigent/server/routes/device_auth.py:25` |
| `OMNIGENT_DEVICE_CLIENT_SECRET` | Device-grant client secret | `omnigent/server/routes/device_auth.py:38` |
| `OMNIGENT_GRANT_MAX_LIFETIME_DAYS` | Device-grant max lifetime | `omnigent/server/routes/device_auth.py:119` |
| `OMNIGENT_GITHUB_APP_ID` | GitHub App id | `omnigent/server/github_app.py:115` |
| `OMNIGENT_GITHUB_APP_CLIENT_ID` | GitHub App client id | `omnigent/server/github_app.py:170` |
| `OMNIGENT_GITHUB_APP_CLIENT_SECRET` | GitHub App client secret | `omnigent/server/github_app.py:171` |
| `OMNIGENT_GITHUB_APP_REDIRECT_URI` | GitHub App redirect | `omnigent/server/github_app.py:175` |
| `OMNIGENT_GITHUB_APP_PRIVATE_KEY` | GitHub App private key | `omnigent/server/github_app.py:187` |
| `OMNIGENT_GITHUB_APP_PRIVATE_KEY_PATH` | GitHub App private key path | `omnigent/server/github_app.py:189` |
| `OMNIGENT_GITHUB_APP_SLUG` | GitHub App slug | `omnigent/server/github_app.py:204` |
| `OMNIGENT_CREDENTIAL_ENC_KEY` | Credential encryption key | `omnigent/cli.py:4227` |
| `OMNIGENT_DICTATION_ENGINE` | Dictation engine | `omnigent/server/dictation_worker.py:19` |
| `OMNIGENT_DICTATION_REMOTE_URL` | Remote dictation URL | `omnigent/server/dictation_worker.py:6` |
| `OMNIGENT_DICTATION_MODEL_DIR` | Dictation model directory | `omnigent/server/dictation.py:59` |
| `OMNIGENT_DICTATION_PUNCT_DIR` | Dictation punctuation directory | `omnigent/server/dictation.py:60` |
| `OMNIGENT_DICTATION_MAX_STREAMS` | Dictation stream cap | `omnigent/server/routes/dictation.py:48` |
| `OMNIGENT_EXECUTOR_TYPE` | Session executor override | `omnigent/server/routes/_sessions/helpers.py:1846` |
| `OMNIGENT_STRICT_PROJECT_SESSION_CREATE` | Session create validation | `omnigent/server/routes/_session_create_validation.py:34` |
| `OMNIGENT_RUNNER_WORKSPACE` | Runner workspace for bundles | `omnigent/server/bundles.py:64` |
| `OMNIGENT_HOST_ID` | Host id for host tunnel | `omnigent/server/routes/host_tunnel.py:167` |
| `OMNIGENT_HARNESSES` | Harness list override | `omnigent/cli.py:6927` |
| `OMNIGENT_EXTENSION_DEV_BUNDLES` | Extension dev bundles | `omnigent/cli.py:4800` |
| `OMNIGENT_SESSION_RESUMPTION` | Session resumption toggle | `omnigent/host/local_server.py:480` |
| `OMNIGENT_SERVER_SHUTDOWN_TIMEOUT_S` | Graceful shutdown timeout | `omnigent/cli.py:671` |
| `OMNIGENT_BLAXEL_HOST_IMAGE` | Blaxel managed-host image | `omnigent/server/managed_hosts.py:1589` |
| `OMNIGENT_E2B_MAX_LIFETIME_S` | E2B sandbox lifetime cap | `omnigent/server/managed_hosts.py:1341` |
| `OMNIGENT_CWSANDBOX_MAX_LIFETIME_S` | CoreWeave sandbox lifetime cap | `omnigent/server/managed_hosts.py:285` |
| `OMNIGENT_OPENSHELL_WORKSPACE` | OpenShell workspace | `omnigent/server/managed_hosts.py:2127` |

Managed-provider credentials are read from the server environment, not the config file: `MODAL_TOKEN_ID`/`MODAL_TOKEN_SECRET`, `DAYTONA_API_KEY`, `BL_WORKSPACE`/`BL_API_KEY`, `ISLO_API_KEY` with optional `ISLO_BASE_URL`, and `E2B_API_KEY` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:305-307`).

## Authentication

Auth mode selection: an explicit `OMNIGENT_AUTH_PROVIDER` wins; otherwise `header` is the default unless `OMNIGENT_AUTH_ENABLED` is truthy, in which case a set `OMNIGENT_OIDC_ISSUER` selects `oidc` and its absence selects `accounts` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/auth.py:328-360`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:392-403`).
`OMNIGENT_AUTH_ENABLED=0` disables auth even though the variable is set (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/auth.py:316-319`).
The bare `omnigent server` leaves auth off, giving single-user `header` mode with no login; the containerised entrypoint sets `OMNIGENT_AUTH_ENABLED=1` by default (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:392-397`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/entrypoint.py:182`).

OIDC mode requires `OMNIGENT_OIDC_ISSUER`, `OMNIGENT_OIDC_CLIENT_ID`, `OMNIGENT_OIDC_CLIENT_SECRET`, `OMNIGENT_OIDC_COOKIE_SECRET` (hex, at least 32 bytes), and either `OMNIGENT_OIDC_REDIRECT_URI` or `OMNIGENT_DOMAIN`, from which `https://<domain>/auth/callback` is derived (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:252-278`).
Any issuer that publishes `/.well-known/openid-configuration` is supported; the server fetches discovery at startup, and GitHub is special-cased with hardcoded endpoints (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/README.md:167-171`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:334-364`).
The default scopes for a generic issuer are `openid email profile`, overridable with `OMNIGENT_OIDC_SCOPES` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:359`).
The auth router is mounted at `/auth` and exposes `GET /auth/login`, `GET /auth/callback`, `GET /auth/logout`, `POST /auth/invite`, `POST /auth/cli-login`, `GET /auth/cli-poll`, and `GET /auth/users` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/app.py:3197`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:152`, `:234`, `:503`, `:552`, `:575`, `:596`, `:652`).
The login flow is authorization code with PKCE `S256` and an HS256-signed state cookie (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:203`, `:213`).
The `id_token` is validated against the issuer JWKS with `iss` and `aud` checks and accepts `RS256`, `RS384`, `RS512`, `ES256`, `ES384`, and `ES512` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:871-879`).
Identity is the `email` claim by default and must be accompanied by a truthy `email_verified`; `OMNIGENT_OIDC_EMAIL_CLAIM` selects another claim such as `preferred_username`, and a custom claim always requires `OMNIGENT_OIDC_SKIP_EMAIL_VERIFICATION` because `email_verified` vouches only for `email` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:958-1009`).
No group or role claim is read anywhere in `oidc.py`, `oidc_access.py`, or `routes/auth.py`; `rg -n -i 'groups|roles'` over those files returns nothing.
Admission is the union of three additive conditions: email domain in the effective allowlist (env `OMNIGENT_OIDC_ALLOWED_DOMAINS`, config `allowed_domains:`, and file `<data_dir>/allowed_domains`), membership in the admin list, or an individual invite when `OMNIGENT_OIDC_ALLOW_INVITES` is set; an empty allowlist admits every authenticated IdP user (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc_access.py:9-30`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/config.yaml.example:27-31`).
Admin bootstrap in OIDC mode is the file-backed roster `<data_dir>/admins` unioned with the config `admins:` list; a listed email is promoted to `is_admin=True` on login, promotion is additive only, and the module states that OIDC "has no other admin signal" (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/admin_list.py:1-23`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/config.yaml.example:18-24`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/app.py:1586-1587`).
The config file is `OMNIGENT_CONFIG` or `<data_dir>/config.yaml`, and upstream states it is often world-readable so credentials belong in the environment (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/server_config.py:57-63`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/config.yaml.example:14-16`).

Accounts mode is built-in username/password with first-user-is-admin bootstrap and UI invites; it requires `OMNIGENT_ACCOUNTS_COOKIE_SECRET` and `OMNIGENT_ACCOUNTS_BASE_URL`, and `OMNIGENT_ACCOUNTS_INIT_ADMIN_PASSWORD` pre-seeds the first admin (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:405`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/accounts_config.py:119-132`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/.env.example:42-55`).
`POST /auth/setup` is intentionally unauthenticated while no password-bearing account exists, so an accounts-mode instance exposed before setup can be claimed by the first visitor (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/.env.example:50-55`).
Accounts mode cannot serve managed sandboxes: the runner dials back with the user's identity, which accounts mode cannot supply over the runner WebSocket, and the server returns `403` even though the host connects; this applies to every sandbox provider (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:409-414`).
`OMNIGENT_ACCOUNTS_INIT_ADMIN_PASSWORD` has no role in OIDC mode; a one-time `omnigent debug migrate-accounts-to-oidc <db-url> --domain <domain>` remaps accounts identities to emails when switching modes (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:455-460`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:10776`).
Header mode trusts `X-Forwarded-Email` by default and is documented for deployments behind an existing SSO proxy such as oauth2-proxy (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:407`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/README.md:210-221`).

## Runner and host

The server is a FastAPI application handling HTTP, SSE, terminal-attach WebSockets, persistence, and the web UI; the runner (host) is a Python process on the user's machine that dials the server over a WebSocket tunnel, executes the LLM loop and tools locally, and streams events back (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:219-237`).
`omnigent login <server-url>` detects the auth mode and stores a token reused by `run`, `attach`, and `host`; `omnigent host <server-url>` registers the machine so web-UI sessions run on it (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:239-259`).
`omni` is an installed alias, so `omni host <server-url>` is the same command (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:396-397`).
The `host` command accepts the server URL positionally or via `--server`, supports `--background`, and `omnigent host enable` installs a per-user OS service, which on Linux is a `systemd --user` unit `omnigent-host.service` with `Restart=on-failure` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:8601-8616`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/service.py:21`, `:53-58`, `:133-134`).
The host tunnel URL is `wss://<server>/v1/hosts/<host_id>/tunnel` for HTTPS servers and `ws://` otherwise (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/connect.py:1333-1338`).
Tunnel authentication sends `Authorization: Bearer <token>` for logged-in hosts or `X-Omnigent-Host-Token` (from `OMNIGENT_HOST_TOKEN`) for managed hosts (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/connect.py:3711-3715`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/identity.py:27`, `:36`).
Server-side WebSocket routes under `/v1` are `/hosts/{host_id}/tunnel`, `/runners/{runner_id}/tunnel`, `/sessions/updates`, `/sessions/{session_id}/resources/terminals/{terminal_id}/attach`, and `/dictation/stream` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/host_tunnel.py:137`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/runner_tunnel.py:346`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/sessions/routes_core.py:1418`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/terminal_attach.py:130`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/dictation.py:109`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/app.py:2575`).
The runner tunnel pings every 30 seconds (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/runner_tunnel.py:47`).
Uvicorn is started with `ws_max_size=RUNNER_TUNNEL_MAX_MESSAGE_BYTES`, which is 100 MiB, in both the Docker entrypoint and `omnigent server` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/entrypoint.py:523-527`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:4382`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/runner/transports/ws_tunnel/limits.py:5`).
`omnigent server` binds `127.0.0.1:6767` by default and takes `--host`, `--port`, `--database-uri`, `--artifact-location`, `--config`, `--admin-password`, and `--background` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:3836-3845`, `:3851-3914`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/local_server.py:727`).

Managed sandbox providers reachable from the CLI are Modal, Daytona, Blaxel, Islo, and E2B; server-managed hosts are created with `"host_type": "managed"` and configured under a `sandbox:` section with `provider`, `server_url`, and an optional `reaper` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:267-302`).
Each managed sandbox authenticates back with a server-minted per-launch token, so no user credentials enter the sandbox (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:308-309`).
Most sandboxes boot from `ghcr.io/omnigent-ai/omnigent-host:latest`, built from the `host` Dockerfile target (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:319`).
Kubernetes managed hosts require server auth to be `header`, `oidc`, or single-user (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/kubernetes/README.md:280`, `:298`).

## Sandbox behaviour

The Linux platform default sandbox is `linux_bwrap` (mount, PID, UTS, IPC namespaces plus seccomp via the `bwrap` binary); macOS defaults to `darwin_seatbelt` via `sandbox-exec`, and Windows to `windows_jobobject` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/sandbox.py:1171-1180`).
The default is resolved at spec parse time without probing the binary; at run time `BwrapSandboxBackend.resolve` raises with an install hint when `bwrap` is absent, so an agent never silently runs unsandboxed, and `os_env.sandbox.type: none` is the only opt-out (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/sandbox.py:1188-1198`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:318-322`).
Inside bwrap: `/usr`, `/lib*`, `/bin`, `/sbin` read-only; an allowlist of `/etc` files for libc, DNS, and TLS; fresh `/proc`, `/dev`, `/tmp`; cwd read-only by default with `write_paths: ["."]` to flip it; top-level dotfiles tmpfs-masked except `.venv`; `$HOME` never mounted; a seccomp denylist plus `CLONE_NEW*` filtering and `clone3` denied with `ENOSYS`, on top of `PR_SET_NO_NEW_PRIVS` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:12-50`).
Registered backends are `linux_bwrap`, `darwin_seatbelt`, `windows_jobobject`, and `none`; no `landlock_sandbox.py` exists under `omnigent/inner/` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/sandbox.py:50`, `:1160-1166`).
Landlock appears only as an external constraint: the OpenShell managed-sandbox gateway's supervisor uses Landlock/seccomp/netns and must run on amd64 Linux, a Kubernetes Landlock LSM policy denies the sandbox user's home directory and `/build/*` inside the host image, a parser test names a `linux_landlock` type as a soft backend that rejects `credential_proxy`, and a design document mentions `landlock_sandbox.py` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/openshell/README.md:57-60`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Dockerfile:385`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/onboarding/sandboxes/openshell.py:103`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:tests/spec/test_parser.py:4082-4103`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:designs/SANDBOX_CREDENTIAL_PROXY.md:314`).
The `web_fetch` builtin tool also probes `bwrap` and `sandbox-exec` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/tools/builtins/web_fetch.py:126`, `:134`).

## Ingress and streaming

Each open session view holds a long-lived `GET /v1/sessions/{id}/stream` `text/event-stream` response; browsers cap HTTP/1.1 at about six connections per origin, and uvicorn speaks HTTP/1.1 only, so upstream instructs terminating TLS with HTTP/2 at a reverse proxy in front of `:8000` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:186-217`).
The SSE response sets `Cache-Control: no-cache` and `X-Accel-Buffering: no` to disable nginx-style response buffering (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/sessions/routes_events.py:2187-2199`).
The bundled Caddy overlay publishes `80`, `443`, and `443/udp`, auto-provisions Let's Encrypt via HTTP-01 for `{$OMNIGENT_DOMAIN}`, negotiates HTTP/2 and HTTP/3 over TLS via ALPN, and its whole site block is `encode zstd gzip` plus `reverse_proxy omnigent:8000` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/docker-compose.https.yaml:18-20`, `:27-35`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Caddyfile:1-13`, `:27-30`).
Kubernetes uses an nginx `Ingress` with `cert-manager.io/cluster-issuer: letsencrypt-prod` and a single `/` prefix rule to the `omnigent` service (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/kubernetes/base/ingress.yaml:5-23`).
No upstream deploy file sets a proxy read, idle, or send timeout; `rg -n -i 'proxy_read_timeout|proxy-read-timeout|idle_timeout|proxy_buffering' deploy/` matches only a Microsandbox VM `idle_timeout_s` option (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/microsandbox/README.md:61`).
The stated proxy requirements are therefore HTTP/2 termination, WebSocket upgrade passthrough on the five `/v1` WebSocket routes, unbuffered SSE, and tolerance for messages up to 100 MiB on the tunnel routes.
Health is `GET /health`; Docker checks every 30 s with a 20 s start period, Fly every 30 s with a 20 s grace period, and Kubernetes liveness every 30 s after 20 s and readiness every 10 s after 10 s (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Dockerfile:453`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/fly/fly.toml:36-40`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/kubernetes/base/deployment.yaml:38-51`).
The server listens on `8000` in every container template (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Dockerfile:451`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/docker-compose.yaml:63-64`).

## Resource footprint

The server working set is documented as about 512 MB to 1 GB (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:181-184`).
Fly reports about 275 MB idle RSS and pins a `shared-cpu-1x` machine with `1gb` memory because the 256 MB default OOM-loops (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/fly/fly.toml:48-52`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/fly/README.md:36`).
Kubernetes requests `512Mi` memory and `250m` CPU with limits `1Gi` and `1000m` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/kubernetes/base/deployment.yaml:31-37`).
These figures cover the server only; the runner and any Postgres are separate processes with no upstream sizing.

## ACP, Buzz, `omp`, and Atomic references

`buzz` does not occur anywhere in the tree outside `node_modules` and lockfiles.
`omp` occurs three times, each as "Pi forks like `omp`" describing an ACP agent that owns its own system prompt; it is a harness name, not a relay or service (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/acp_executor.py:206`, `:1510`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/onboarding/acp_auth.py:59`).
`atomic` occurs only as ordinary English ("atomic replacement", "atomic writer") (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:docs/model-hardcoding-plan.md:209`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:docs/UNINSTALL_DESIGN.md:48`).
ACP is a first-class harness family: a declarative catalog of builtin ACP CLI harnesses, each a vendor CLI speaking the Agent Client Protocol on stdio, all routed through `omnigent/inner/acp_harness.py` and `AcpExecutor`, the same path a user-configured `acp:<slug>` agent uses (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/acp_cli_harnesses.py:1-20`).
Devin runs through the generic ACP harness with a small vendor extension layer, and the README documents driving an OpenClaw Gateway session over ACP (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:docs/DEVIN_ACP_DESIGN.md:1-6`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:277`).
Redis is not a dependency; it is named once as a hypothetical shared runner registry (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/kubernetes/README.md:385-387`).

## Deployment-plan dimensions

### 1. Packaging mechanism

Upstream ships a platform-independent wheel on PyPI, multi-arch OCI images on GHCR, and a metadata-only GitHub Release with the auto-attached source tarball (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:.github/workflows/release-omnigent.yml:1-14`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:.github/workflows/oss-publish-images.yml:191`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:.github/workflows/github-release.yml:15-17`).
The web UI bundle is inside the core wheel, so a wheel-based package does not need a separate Node build (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:.github/workflows/release-omnigent.yml:140-144`).
The wheel does not include `psycopg`; a Postgres deployment must add `psycopg[binary]>=3.1,<4` or the `databricks` extra (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Dockerfile:157-159`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:282-287`).
A charter-style `-bin` derivation would wrap the PyPI wheel (`fetchPypi` of `omnigent-<version>-py3-none-any.whl` plus the two SDK wheels), since no native binary exists; the source path is `uv build` from the Git tree with a pnpm web build (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:124-130`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:.github/workflows/release-omnigent.yml:127-130`).
The pinned revision is `0.13.0.dev0`, ahead of the latest release `v0.12.0`, so a released wheel and this revision differ (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:8`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:CHANGELOG.md:8`).

### 2. NixOS module surface

The server process is `omnigent server --host <h> --port <p> --database-uri <uri> --artifact-location <dir> --config <config.yaml>`, or the equivalent config keys `host`, `port`, `database_uri`, `artifact_location` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:3836-3872`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/entrypoint.py:146-153`).
Runtime state is `<data_dir>` (`OMNIGENT_DATA_DIR`) holding `chat.db`, `artifacts/`, `logs/`, `config.yaml`, `admins`, `allowed_domains`, and the accounts cookie secret; Docker anchors it at `/data` via `OMNIGENT_ADMIN_CREDENTIALS_PATH=/data/admin-credentials` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/local_server.py:58-70`, `:628-632`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/docker-compose.yaml:68-77`).
The module surface upstream's templates imply is: bind host and port, database URI, data directory, auth mode and the `OMNIGENT_OIDC_*` set, `OMNIGENT_DOMAIN`, an `admins` list, an `allowed_domains` list, `OMNIGENT_FEATURES`, `OMNIGENT_LOG_LEVEL`, and an optional `sandbox:` provider section (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/docker-compose.yaml:60-151`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/kubernetes/base/configmap.yaml:1-16`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:287-302`).
Migrations run on every boot, so no separate migrate step is needed, but first boot against remote Postgres takes about a minute (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/db/utils.py:398-405`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:176-180`).
The server needs no `tmux`, `git`, `bwrap`, or Node on its `PATH`; those belong to the runner unit (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Dockerfile:9-14`).
Upstream's own Linux service unit is a `systemd --user` unit for the host, not for the server; there is no upstream system-level unit for either process (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/service.py:1`, `:53-58`).

### 3. Reverse proxy and TLS integration

Upstream's own TLS story is Caddy with automatic Let's Encrypt and a two-line site block, or nginx Ingress with cert-manager; the server never terminates TLS (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Caddyfile:27-30`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/kubernetes/base/ingress.yaml:5-8`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:200-204`).
The proxy must speak HTTP/2 to browsers, pass WebSocket upgrades on `/v1/hosts/*/tunnel`, `/v1/runners/*/tunnel`, `/v1/sessions/updates`, `/v1/sessions/*/resources/terminals/*/attach`, and `/v1/dictation/stream`, and honour `X-Accel-Buffering: no` on `/v1/sessions/*/stream` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:200-204`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/sessions/routes_events.py:2190-2199`).
Upstream sets no explicit proxy timeouts; the 30 s tunnel ping keeps idle WebSockets alive against default proxy idle timeouts of 60 s or more (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/runner_tunnel.py:47`).
`OMNIGENT_DOMAIN` is a single variable that both derives the OIDC callback and names the Caddy site, so the public hostname is stated once in upstream's stack (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:255-268`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Caddyfile:27`).

### 4. Secret source

Secrets upstream keeps in the environment, never in `config.yaml`: `DATABASE_URL` (carries the password), `OMNIGENT_OIDC_CLIENT_SECRET`, `OMNIGENT_OIDC_COOKIE_SECRET`, `OMNIGENT_ACCOUNTS_COOKIE_SECRET`, `OMNIGENT_ACCOUNTS_INIT_ADMIN_PASSWORD`, `OMNIGENT_DEVICE_CLIENT_SECRET`, `OMNIGENT_CREDENTIAL_ENC_KEY`, GitHub App secrets, and provider API keys (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/entrypoint.py:125-127`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/config.yaml.example:14-16`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:305-307`).
The OIDC cookie secret is 32 random bytes as 64 hex characters, generated upstream with `openssl rand -hex 32` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/.env.example:120-122`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:270-278`).
Kubernetes injects secrets with `envFrom: secretRef`, and Docker via compose environment, so an `EnvironmentFile=` or `LoadCredential=` pattern that materialises the same variable names is the direct analogue (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/kubernetes/base/deployment.yaml:23-27`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/docker-compose.yaml:103-106`).
No secret is read from a file path by the server except `OMNIGENT_GITHUB_APP_PRIVATE_KEY_PATH` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/github_app.py:189`).

### 5. OIDC/SSO wiring

Omnigent runs its own OIDC relying party, so an external `sso-gateway` or oauth2-proxy is unnecessary; header mode exists for that topology but is the weaker option because it trusts a header (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:407`, `:467-470`).
A Kanidm client needs: redirect URI `https://omni.scientistexperience.net/auth/callback`, scopes `openid email profile`, and an `id_token` signed with an algorithm in `RS256/RS384/RS512/ES256/ES384/ES512` carrying `email` and `email_verified: true` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:262-268`, `:359`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:871-879`, `:999-1009`).
Group-based authorisation is unavailable; access is gated by email domain allowlist, admin roster, or invite, and admin is a per-email roster in `admins:` or `<data_dir>/admins` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc_access.py:9-30`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/admin_list.py:4-8`).
This confirms charter risk RK3 ("no group or role claim handling in upstream auth code or docs").
PKCE `S256` is always used, and the client secret is required, so the Kanidm client must be a confidential client with PKCE permitted (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:213`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:254`).
Discovery is fetched at startup from `<issuer>/.well-known/openid-configuration` with a 10 s timeout, so the server unit must start after Kanidm is reachable (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:360-363`).
Managed-sandbox and runner dial-back work in OIDC mode and fail in accounts mode, so OIDC mode is a prerequisite for any non-laptop runner placement (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:409-414`).

### 6. Runner/host placement

Upstream's model places the runner on the user's machine or in a managed sandbox and never in the server process (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:219-237`).
A runner co-located on the server host is `omnigent host https://omni.scientistexperience.net` run as a user with a login token, or `omnigent host enable` as a `systemd --user` unit; it needs `tmux`, `git`, `bwrap`, Node 22 with `npm`, and `uv` on its `PATH` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:255-259`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/service.py:53-58`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:124-145`).
The runner's Linux isolation is bubblewrap user namespaces plus seccomp; the kernel must permit unprivileged user namespaces for `bwrap` to work as a non-root user (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/bwrap_sandbox.py:1-10`).
Managed providers (Modal, Daytona, Blaxel, Islo, E2B, Kubernetes, OpenShell, Boxlite, Microsandbox, CoreWeave) are opt-in extras with their own credentials and are a deferrable follow-up per charter P3 (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:167-204`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:267-309`).
A runner tunnel authenticates with the user's bearer token, so a system-level runner unit would embed one user's identity; upstream has no server-owned "system runner" concept beyond managed hosts with per-launch tokens (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/connect.py:3711-3715`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:308-309`).

### 7. Buzz-specific architecture analogues

Omnigent has no relay, no `omp`-style companion service, and no Redis; the server is one uvicorn process with an in-memory runner registry (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/kubernetes/README.md:385-387`).
The analogue of Buzz's ACP relationship is Omnigent's generic ACP harness over stdio on the runner, which spawns a vendor CLI locally rather than connecting to a remote relay (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/acp_cli_harnesses.py:3-20`).
The analogue of a Buzz relay's client tunnel is the host WebSocket tunnel `/v1/hosts/{host_id}/tunnel`, initiated outbound from the runner, so no inbound port is required on the runner machine (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/host/connect.py:1333-1338`).
Upstream never mentions Buzz, so any Buzz comparison rests on vanixiets-side notes, not on upstream text.

### 8. Maintenance intent

The pinned commit is on `main` at `0.13.0.dev0`, five days after `v0.12.0`, on a weekly minor-release cadence (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:CHANGELOG.md:8`, `:222`, `:320`).
The 400 commits preceding HEAD span 2026-08-27 to 2026-09-06, about 40 commits per day.
Per-path history in that window (`git log --format='%h %ai %s' -- <path>`; the 2026-08-27 entry on each path is the shallow-fetch boundary, not a real touch): `deploy/README.md` 2 touches (`e4b1c830` 2026-09-06 microsandbox provider, `103a6e1e` 2026-09-04 sandbox reaper); `deploy/docker` 6 touches, newest `87cc2456` 2026-09-04 `EXTRA_HARNESS_CLIS` build-arg and `1747a830` 2026-09-04 `gh` in the managed host image; `deploy/kubernetes` 2 touches (`3b8f0030` 2026-09-04 keepalive, `04b4a453` 2026-09-01 `pod_ready_timeout_s`); `deploy/fly` 0 touches; `omnigent/server/oidc.py` 0 touches; `omnigent/server/routes/auth.py` 1 touch (`0de839be` 2026-09-02 device grant under OIDC); `omnigent/server/oidc_access.py` 0 touches; `omnigent/inner/bwrap_sandbox.py` 3 touches (`4ebfe345` 2026-09-03, `cea0c932` 2026-09-02, `6283ac46` 2026-09-01); `omnigent/server/routes/host_tunnel.py` 3 touches, newest `103a6e1e` 2026-09-04.
The OIDC core is stable over the window while sandbox, managed-host, and Docker host image surfaces move daily.
The Docker host image installs vendor CLIs from mutable refs verified only by `--version`, and the cursor installer "cannot be pinned at all" (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/README.md:312-316`).
`docker-compose.yaml` defaults the image tag to `latest` and advises pinning `sha-<short>` or `vX.Y.Z` for reproducibility (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/docker-compose.yaml:42-45`).
Upstream keeps no Nix expression, so a vanixiets package tracks PyPI versions or Git tags with no upstream help.

## Flags

- F1 `deploy/README.md` and the Dockerfile header name the runner path `WS /v1/runner/tunnel`, but the registered routes are `/v1/runners/{runner_id}/tunnel` and `/v1/hosts/{host_id}/tunnel` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:228`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Dockerfile:7`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/runner_tunnel.py:346`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/host_tunnel.py:137`); the code paths are authoritative for proxy rules.
- F2 `deploy/docker/README.md` links `designs/OIDC_AUTH.md` and `designs/SESSIONS_AUTH.md`, neither of which exists at this revision; `designs/` holds 21 files and only `DEVICE_AUTH.md` concerns auth (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/README.md:354-355`).
- F3 The accounts-to-OIDC migration command is documented as `omnigent debug migrate-accounts-to-oidc` in `deploy/README.md` and as `omnigent accounts migrate-to-oidc` in `.env.example`; only the `debug` form exists in the CLI (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:459`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/.env.example:220-221`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/cli.py:10776`).
- F4 `psycopg` is absent from the base wheel, so a Nix package for a Postgres deployment must add it explicitly (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:287`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/Dockerfile:157-159`).
- F5 The charter's "Cloud Sandbox Host documentation", "Auth and SSO documentation", and "Database documentation" are sections of `deploy/README.md`, not standalone files; the charter's reference table should cite the sections (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:144`, `:267`, `:390`).
- F6 The pinned revision is a `.dev0` version ahead of the newest release, so a `-bin` wheel derivation cannot match this exact revision; the closest release is `v0.12.0` of 2026-09-01 (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:8`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:CHANGELOG.md:8`).
- F7 No group or role claim handling exists in OIDC code, confirming charter RK3 (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc_access.py:9-30`).
- F8 Landlock is not an Omnigent sandbox backend at this revision; the charter's Landlock assumption at `charter.md:31-39` applies only to the OpenShell/Kubernetes gateway and to a design doc (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/inner/sandbox.py:1160-1166`, `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/openshell/README.md:57-60`).
- F9 The Railway one-click button is marked "button pending" (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/README.md:19`).
- F10 Accounts mode exposes an unauthenticated `POST /auth/setup` until the first admin exists (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:deploy/docker/.env.example:50-55`).
- F11 Upstream has no settings module; environment variables are read at 80-plus scattered sites, so the table above is the only consolidated inventory and must be re-derived with `rg -n -o 'OMNIGENT_[A-Z0-9_]+' omnigent/server deploy/docker/entrypoint.py` at any new revision.

## Additional sources acquired

- None cloned; the existing reference clone of `github:omnigent-ai/omnigent` was deepened in place with `git fetch --deepen=400 origin` (HEAD unchanged at `381bf638fb31e6a51990d9dab54ea9ef4b933711`; tags `v0.3.0` and `v0.3.0rc1` arrived with the fetch).
- GitHub commits API was attempted for per-path history and returned an unauthenticated rate-limit error; the deepened local clone replaced it.

## Questions

- Q1 Does Kanidm emit `email_verified: true` alongside `email` in its `id_token` for the `email` scope, or must the plan set `OMNIGENT_OIDC_SKIP_EMAIL_VERIFICATION=1` or `OMNIGENT_OIDC_EMAIL_CLAIM=preferred_username`; this is a Kanidm-side fact outside this axis (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:999-1009`).
- Q2 Should the plan target the released wheel `v0.12.0` for a `-bin` derivation or the pinned `main` revision via a source build, given F6.
- Q3 Should the first deployment include a co-located runner on `magnetite` (`omnigent host` under a user account with a personal bearer token) or laptop-only runners, given that upstream has no system-level runner identity (section 6).
- Q4 Which email domain(s) should populate `allowed_domains`, and which Kanidm-issued email addresses should seed `admins:`; upstream admits every IdP user when the allowlist is empty (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc_access.py:15-18`).
- Q5 Does `magnetite` permit unprivileged user namespaces for `bwrap`, a NixOS-side fact this axis did not check.
- Q6 Should the charter reference table be amended per F5 so that A2 citation checks point at `deploy/README.md` sections rather than at non-existent standalone documents.
