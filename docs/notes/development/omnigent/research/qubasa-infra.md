---
title: Research axis qubasa-infra
status: working-note
date: 2026-09-06
---

# Research axis: `Qubasa/infra`

Axis revision: `github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d` (`main`, commit "bump nixpkgs, disable openwebui", 2026-09-04).
Upstream comparison revision: `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711` (charter reference table).
Terms follow the charter designation table in `docs/notes/development/omnigent/charter.md` (charter v1, on the plan branch, not yet on `main`).

## Scope and method

The starting set was `pkgs/omnigent/{package.nix,web-ui.nix,flake-module.nix,writable-materialized-config.patch}`, `machines/wintux/llm.nix`, and `flake.nix`.
Every import reached from that set was followed: `flake.nix` imports `pkgs/omnigent/flake-module.nix`; `machines/wintux/configuration.nix` imports `./packages.nix`; `packages.nix` imports `./llm.nix`; `flake.nix` attaches `modules/shared.nix` to every machine.
The repository was searched for `omnigent`, `omni`, `OMNIGENT`, `services.omnigent`, `DynamicUser`, `oidc`, `kanidm`, `authelia`, `oauth2`, `buzz`, `redis`, `relay`, `postgres`, `services.nginx`, `services.caddy`, `acme`, `sops`, `agenix`, `clan.core.vars`, `/run/secrets`, `todo`, and `fixme`.
Only `flake.nix:114` and `machines/wintux/llm.nix:11` mention Omnigent outside `pkgs/omnigent/`.
The local reference clone of `Qubasa/infra` is a depth-1 partial clone (`git rev-parse --is-shallow-repository` prints `true`; `remote.origin.partialclonefilter` is `blob:none`), so `git log -- <path>` returns only the HEAD commit; per-path history in section 8 was read from the GitHub commits API and each commit is cited by full SHA.
The local reference clone of `omnigent-ai/omnigent` is also depth-1 and has no `v0.3.0` tag; facts about `v0.3.0` were read from GitHub at the tag's commit `4edb4d95b95fd2748f3f119628936d75511918e9`.
Because both clones are promisor clones, `git cat-file -e <sha>:<path>` for those historical commits succeeds by lazily fetching from the remote when network access is available, so the charter A2 check passes for every `github:` citation in this note under those conditions.

## Version packaged and relation to upstream 381bf63

`Qubasa/infra` packages Omnigent `0.3.0` from the GitHub tag `v0.3.0`: `version = "0.3.0";` and `rev = "v${version}";` (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/package.nix:22-27`).
The `v0.3.0` tag object is `6d892ec0808fc36c1a2fc42d3c066c774b6fa96d`, pointing at commit `4edb4d95b95fd2748f3f119628936d75511918e9`, tagged 2026-06-27 and released 2026-06-27 (GitHub `git/ref/tags/v0.3.0`, `git/tags/6d892ec…`, and `releases/tags/v0.3.0`).
Upstream `381bf63` carries `version = "0.13.0.dev0"` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:8`), dated 2026-09-06.
GitHub `compare/v0.3.0...381bf63` reports `status: diverged, ahead_by: 2503, behind_by: 2`, with merge base `dc018f59176fd693d51ddb140c7f45688f99d8fd`.
The three most recent upstream releases are `v0.12.0` (2026-09-01), `v0.11.0` (2026-08-25), and `v0.10.0` (2026-08-19), so the packaged version is nine minor releases behind the newest release.
Two of the surfaces the derivation depends on moved between `v0.3.0` and `381bf63`: the SPA directory (`ap-web/` with npm at `v0.3.0`; `web/` with `pnpm@11.15.1` at `381bf63`) and the line offset of the patched function (see section 1).

## 1. Packaging mechanism

Mechanism: from source with `uv2nix` plus `pyproject-nix` plus `pyproject-build-systems`, wrapped in a `stdenvNoCC.mkDerivation` shell that only installs `makeWrapper` wrappers (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/package.nix:16-18,89-105`).
Source: `fetchFromGitHub { owner = "omnigent-ai"; repo = "omnigent"; rev = "v${version}"; hash = "sha256-Caypds51+SbeaQYLnbWtfNXbG12eL1KpZQEL/Vdw+l8="; }` (`package.nix:24-29`).
The uv workspace is loaded from the fetched source and turned into a Python overlay with `sourcePreference = "wheel";` (`package.nix:37-40`).
The interpreter is pinned to `python = python312;` (`package.nix:69`), matching upstream `requires-python = ">=3.12"` at both `v0.3.0` (`github:omnigent-ai/omnigent@4edb4d95b95fd2748f3f119628936d75511918e9:pyproject.toml:10`) and `381bf63` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:pyproject.toml:11`).
The Python set composes `pyproject-build-systems.overlays.default`, the lockfile overlay, and a local `pyprojectOverrides` overlay, then builds `venv = pythonSet.mkVirtualEnv "omnigent-${version}-env" workspace.deps.default;` (`package.nix:71-79`).
The output derivation has `dontUnpack = true;` and an `installPhase` that wraps `${venv}/bin/omnigent` and `${venv}/bin/omni` with `--suffix PATH : "${runtimePath}"` (`package.nix:93-105`).
`runtimePath` is `lib.makeBinPath [ nodejs git tmux uv ripgrep ]` (`package.nix:81-87`); `bubblewrap` is not in it.
`passthru = { inherit venv pythonSet workspace; };` exposes the intermediate sets (`package.nix:107-109`).
`meta` declares `license = lib.licenses.asl20; mainProgram = "omnigent"; platforms = lib.platforms.unix;` (`package.nix:111-117`).

Web UI: the browser SPA is a separate `buildNpmPackage` derivation in `web-ui.nix` with `src = "${src}/ap-web";` and `npmDepsHash = "sha256-zgrihNaPy7vRs2PlCsHf3LWorPDU1784+tqv+eufpag=";` (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/web-ui.nix:16-23`).
Its `buildPhase` runs `./node_modules/.bin/vite build --outDir dist --emptyOutDir`, deliberately skipping upstream's `tsc -b` step, because upstream `vite.config.ts` hard-codes `outDir` to `../omnigent/server/static/web-ui` (`web-ui.nix:25-34`; upstream `github:omnigent-ai/omnigent@4edb4d95b95fd2748f3f119628936d75511918e9:ap-web/vite.config.ts:164-165`, and `ap-web/package.json` script `build` is `tsc -b && vite build`).
The `omnigent` Python package override sets `env.OMNIGENT_SKIP_WEB_UI = "true"` and in `postPatch` copies `${webUI}` into `omnigent/server/static/web-ui` so setuptools packages it as package data (`package.nix:57-65`).
Upstream `setup.py` at `v0.3.0` shells out to `npm install` and `npm run build` in `ap-web/` unless `OMNIGENT_SKIP_WEB_UI == "true"` (`github:omnigent-ai/omnigent@4edb4d95b95fd2748f3f119628936d75511918e9:setup.py:123-152`).
At `381bf63` the same hook builds `web/` with `pnpm` from a root `pnpm-workspace.yaml` and `pnpm-lock.yaml` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:setup.py:98-132`), and no `ap-web/` directory exists at that revision; `web-ui.nix` therefore does not apply to `381bf63` without rewriting to `pnpm` fetching.

Patch: one patch, `writable-materialized-config.patch`, adds `target.chmod(target.stat().st_mode | 0o200)` before `target.write_text(...)` in `_materialize_override_bundle` in `omnigent/chat.py` (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/writable-materialized-config.patch:8`).
The stated reason is "Home Manager exposes agent bundles from the read-only Nix store; make omnigent's temp override copy writable before it rewrites config.yaml" (`package.nix:51-52`).
The hunk header claims `@@ -2942,6 +2942,7 @@` but the body carries five old lines and six new lines; GNU `patch -p1 --dry-run` against `v0.3.0` `omnigent/chat.py` reports `Hunk #1 succeeded at 2943 with fuzz 1 (offset 1 line)`, while `git apply --check` reports `error: corrupt patch at line 12`.
The same dry run against `381bf63` `omnigent/chat.py` reports `Hunk #1 succeeded at 3080 with fuzz 1 (offset 138 lines)`, and upstream still has no `chmod` in `omnigent/chat.py` at `381bf63` (`git grep chmod -- omnigent/chat.py` is empty), so the patch remains relevant to a newer package.

Flake wiring: `flake.nix` declares `pyproject-nix`, `uv2nix`, and `pyproject-build-systems` inputs with `inputs.nixpkgs.follows = "nixpkgs"` and `pyproject-nix`/`uv2nix` follows (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:flake.nix:77-91`) and imports `./pkgs/omnigent/flake-module.nix` (`flake.nix:114`).
`flake-module.nix` exposes `perSystem.packages.omnigent = pkgs.callPackage ./package.nix { uv2nix = inputs.uv2nix; pyproject-nix = inputs.pyproject-nix; pyproject-build-systems = inputs.pyproject-build-systems; }` (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/flake-module.nix:6-10`).
The root `nixpkgs` follows `unstable-nixpkgs` (`flake.nix:38`), locked to `NixOS/nixpkgs@3ed67ec0a4d3c7ab4ae1f04f8ee8df07bfa506a2` (2026-09-02); the root `uv2nix` input (lock node `uv2nix_2`) is locked to `pyproject-nix/uv2nix@7f9c6b613d2e749e54854b1d60ab6a2192db889e` (2026-08-29), `pyproject-nix` to `6a8a7881d75b6f98967e7b8069f4ead331384301` (2026-09-03), and `pyproject-build-systems` to `150839ac67b5a34db56a55e8f6b7099a4e7878ab` (2026-08-31) (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:flake.lock`).
No OCI image, fetched wheel, or release binary is used; search `git grep -n -i 'dockerTools\|fetchurl\|fetchPypi' -- pkgs/omnigent` is empty.
For comparison, vanixiets `main` has `uv2nix`, `pyproject-nix`, and `pyproject-build-systems` only as transitive lock nodes reached through the `hermes-agent` and `nixhelm` inputs and not as direct inputs (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:flake.lock`, nodes `uv2nix`, `uv2nix_2`; `flake.nix` mentions `pyproject-nix` only as a cachix substituter at lines 166 and 177).

## 2. NixOS module surface

Not present.
Searches `git grep -n -i 'services\.omnigent\|omnigent serve\|omni host\|DynamicUser'` over the whole repository return nothing.
No `systemd.services.*`, `StateDirectory`, `User`, `ExecStart`, state directory, service user or group, or database provisioning exists for Omnigent anywhere in `Qubasa/infra`.
The only consumer is `machines/wintux/llm.nix`, which binds `omnigent = flakeInputs.self.packages."x86_64-linux".omnigent;` in a `let` block (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/wintux/llm.nix:11`) and then does not reference `omnigent` in its `environment.systemPackages` list (`llm.nix:16-31`).
`wintux` is a workstation: `configuration.nix` sets `clan.core.networking.targetHost = "root@127.0.0.1";`, `console.keyMap = "de";`, `virtualisation.libvirtd.enable = true;`, and a `nvidia` specialisation (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/wintux/configuration.nix:54,60-66,74,79`).

## 3. Reverse proxy and TLS integration

Not present for Omnigent.
Search `git grep -n -i 'services\.nginx\|services\.caddy\|services\.traefik\|acme'` finds nginx virtual hosts only for the blog, cookbook, gitea, and nextcloud on `gchq-local` and for the mail server on `qube-email`.
The repository's proxy convention is nginx with `forceSSL = true; enableACME = true;` and `proxyWebsockets = true;` on `locations."/"`, as in the Gitea host (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/gchq-local/gitea.nix:99-108`), with `clan.nginx.acme.email = "acme@qube.email";` (`machines/gchq-local/configuration.nix:27`).
No websocket or SSE handling, hostname, or ACME entry refers to Omnigent.

## 4. Secret source

Not present for Omnigent.
Search `git grep -n 'OMNIGENT'` returns only the build-time `OMNIGENT_SKIP_WEB_UI` in `package.nix:48,58`; no `OMNIGENT_*` runtime variable, env file, or secret path is supplied anywhere.
The repository's secret mechanism is clan vars with sops backing: `clan.core.vars.generators.<name>.files.<file>` with `owner`, `group`, and `restartUnits` (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/gchq-local/gitea.nix:6-10`), consumed as `.path` (`gitea.nix:69`), plus a top-level `sops/` and `vars/` tree.
One direct `config.sops.secrets.<name>.path` use exists for the mail server (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/qube-email/simplemail.nix:97`).
No agenix usage exists (`git grep -n -i agenix` is empty).

## 5. OIDC/SSO wiring

Not present.
Search `git grep -n -i 'oidc\|kanidm\|authelia\|oauth2\|keycloak'` over non-`facter.json` files matches nothing relevant; the only hits are the substring `index` in unrelated files.
The Gitea host uses Anubis `auth_request` for bot filtering, not an identity provider (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/gchq-local/gitea.nix:105-111`).
No identity provider is deployed in `Qubasa/infra`.

## 6. Runner/host placement and sandboxes

Not present as a server or runner deployment.
The derivation installs both entry points, `omnigent` and `omni` (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/package.nix:100`), which upstream defines as one CLI with `omni` as a short alias (`github:omnigent-ai/omnigent@4edb4d95b95fd2748f3f119628936d75511918e9:pyproject.toml:244-248`).
The intended placement, when it was wired, was a workstation system package on `wintux` alongside `claude-code`, `omp`, and other agent CLIs (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/wintux/llm.nix:16-31`); no `omnigent serve` or `omni host` invocation exists.
Sandbox provisioning is implicit: `bubblewrap` is installed as an unrelated workstation package (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/wintux/packages.nix:119`) and is absent from the wrapper's `runtimePath` (`package.nix:81-87`), so the package relies on the host `PATH` for the mandatory Linux `bwrap` sandbox described at `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:README.md:140-144`.
No managed sandbox provider, KVM, or `microvm.nix` configuration relates to Omnigent (`machines/wintux/mvm.nix` is imported by `configuration.nix:17` for `muvm`, unrelated to Omnigent).

## 7. Buzz-specific analogues

Not present.
Search `git grep -n -i 'buzz\|redis\|relay'` finds only `redis-rspamd.service` in the mail server (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/qube-email/simplemail.nix:68,81`).
The repository's Postgres provisioning pattern is the clan-core `clan.core.postgresql.users.<name>` and `clan.core.postgresql.databases.<name>.create.options` with `restore.stopOnRestore`, used for Gitea on `gchq-local` (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/gchq-local/gitea.nix:12-20`) atop `services.postgresql.package = pkgs.postgresql_16;` (`machines/gchq-local/configuration.nix:57-59`).
That pattern is not applied to Omnigent here, and no relay or Redis analogue exists.

## 8. Apparent maintenance intent

Local `git log --format='%h %ai %s' -- pkgs/omnigent` and `-- machines/wintux/llm.nix` each print only `439ded2 2026-09-04 19:18:45 +0200 bump nixpkgs, disable openwebui`, because the reference clone is depth-1.
GitHub commits API for `path=pkgs/omnigent` returns exactly one commit: `4aa589e5f9a1ace427f5a7e6d079029fab2624ed` 2026-07-27 "flake update and add omnigent", which added all four files under `pkgs/omnigent/`, the three `pyproject-nix` flake inputs, and the `flake-module.nix` import (`github:Qubasa/infra@4aa589e5f9a1ace427f5a7e6d079029fab2624ed:pkgs/omnigent/package.nix`, `:flake.nix`).
The packaging has not been revised since; the version stayed at `0.3.0` through nine upstream minor releases and four subsequent `flake.nix` or `flake.lock` bumps (`11020d2974b61db324ab0ff6b4b4a9eed67f91bd` 2026-08-15, `439ded26a84965b6c782b6277626b0d40a90f26d` 2026-09-04, among them).
`machines/wintux/llm.nix` history for Omnigent: added to `environment.systemPackages` in `4aa589e5f9a1ace427f5a7e6d079029fab2624ed` (2026-07-27); removed in `ddbc7dcc94edf773c089a17f0215277d1f6e96be` (2026-08-10, "updaten nixpkgs, vscodium, and many other changes"); re-added with the `let` binding in `0325acc489beb49533f28aa8ef73854fb5356412` (2026-08-15, "add ghidra cli, and pueue"); removed from the package list again in `e22267791a9434f511670a75d2ca7879961283d4` (2026-09-04, commit message "asd"), leaving the `let` binding unused.
At the axis revision the `omnigent` package is therefore built by the flake (`packages.x86_64-linux.omnigent`) but installed on no machine (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/wintux/llm.nix:11,16-31`).
No `TODO`, `FIXME`, or `HACK` marker exists under `pkgs/omnigent/` or in `llm.nix` (`git grep -n -i 'todo\|fixme\|hack' -- pkgs/omnigent machines/wintux/llm.nix` is empty).
The `README.md` describes the repository as "my server farm" managed with Clan (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:README.md:1-2`), consistent with charter W7.

## Flags

- F1 Version skew: packaged `0.3.0` (2026-06-27) against upstream `0.13.0.dev0` at `381bf63` (2026-09-06), 2503 commits and nine minor releases behind (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/package.nix:22`).
- F2 `web-ui.nix` is bound to the `ap-web/` npm layout; upstream `381bf63` has moved the SPA to `web/` under `pnpm@11.15.1`, so the derivation cannot be bumped to a current release without replacing `buildNpmPackage` and `npmDepsHash` (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/web-ui.nix:21-23`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:setup.py:108-110`).
- F3 `writable-materialized-config.patch` has a malformed hunk header (`-2942,6 +2942,7` for a five-line-old, six-line-new body); GNU `patch` applies it with fuzz, `git apply --check` rejects it as corrupt (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/writable-materialized-config.patch:5-11`).
- F4 The patch is a workaround for a Home Manager read-only-store case, a one-machine concern stated in the derivation comment (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/package.nix:51-52`); upstream has not fixed it at `381bf63`, matching charter risk RK2.
- F5 The package is orphaned at the axis revision: `llm.nix` binds it in `let` but does not install it, after commit `e22267791a9434f511670a75d2ca7879961283d4` titled "asd" removed it (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:machines/wintux/llm.nix:11,16-31`).
- F6 `runtimePath` omits `bubblewrap`, which upstream declares mandatory on Linux; the package only works because `wintux` installs `bubblewrap` system-wide (`github:Qubasa/infra@439ded26a84965b6c782b6277626b0d40a90f26d:pkgs/omnigent/package.nix:81-87`; `machines/wintux/packages.nix:119`).
- F7 No NixOS module, service unit, proxy, secret, OIDC, or database configuration exists for Omnigent in this repository; the axis contributes a packaging recipe only.

## Additional sources acquired

None.
No `ghq get` was run.
Facts about commits outside the depth-1 clones (`Qubasa/infra` history commits `4aa589e…`, `ddbc7dc…`, `0325acc…`, `e222677…`, `11020d2…`; `omnigent-ai/omnigent` tag commit `4edb4d9…`) were read over the GitHub REST API and raw.githubusercontent.com and are cited by full SHA.

## Questions

- Q1 Charter regulator A2 resolves citations to commits outside the depth-1 clones (`4aa589e…`, `4edb4d9…`) only through the promisor lazy fetch, which needs network access at check time; should the orchestrator unshallow the two reference clones (`git fetch --unshallow`) so A2 is offline-deterministic, or accept network-dependent resolution?
- Q2 The prompt asks for `git log` commit dates per path, and with a depth-1 clone that command yields one commit; should the GitHub API-derived history in section 8 stand as the record, or should the orchestrator re-run `git log` after unshallowing?
- Q3 vanixiets holds `uv2nix`/`pyproject-nix` only as transitive lock nodes; if the plan adopts Qubasa's from-source mechanism (charter P2 prefers `pkgs/by-name` and a `-bin` proxy where upstream ships release artifacts), does adding them as direct flake inputs fall within the plan's "every flake input to add" list (R2), or is that a decision for the packaging synthesis node?
