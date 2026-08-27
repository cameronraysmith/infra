# Nixbot on magnetite implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a nixbot instance on magnetite at `nixbot.scientistexperience.net`, deployed by `clan machines update magnetite`, coexisting with the buildbot-nix server that stays authoritative for every repository.

**Architecture:** A new first-party aspect `flake.modules.nixos.nixbot` at `modules/nixos/nixbot.nix` carries the site configuration; the upstream `inputs.nixbot.nixosModules.nixbot` module is imported at the host alongside the existing upstream imports, exactly as the incumbent buildbot modules are. nixbot is one service unit fronted by the host's existing nginx over a unix socket, with its own database on the host's existing PostgreSQL instance and its own credentials as clan vars. The incumbent's module, aspect entry, generators, vhost, database, and the repository-root `buildbot-nix.toml` are not edited.

**Tech Stack:** nix flakes with flake-parts and import-tree; clan-core for deployment and vars; nixbot (`github:Mic92/nixbot`, `nixosModules.nixbot`); nginx with ACME; PostgreSQL; terranix against Cloudflare for DNS.

## Global Constraints

- Nothing under `modules/nixos/buildbot.nix`, its entry in magnetite's aspect list, its clan vars generators, its nginx vhost, its database, or the repository-root `buildbot-nix.toml` is edited, added to, or removed. Verified per task by `git diff --stat`.
- The verdict namespace stays at the module default: never set `services.nixbot.statusContextPrefix`. The incumbent's contexts are `buildbot/...` and the forge's required checks name them.
- `services.nixbot.github.topic = null`. Its default is `"build-with-buildbot"`, which is the topic the incumbent's repositories carry, and it performs a one-shot import against an empty database.
- No credential value in any file in the repository. Credentials are `clan.core.vars` generators consumed as `...files."<file>".path`.
- Every generator that feeds the service names `restartUnits = [ "nixbot.service" ]`, because the unit snapshots credentials at start.
- `services.nixbot.nginx.enable` stays at its default `true`, so the service listens on `/run/nixbot/web.sock` and binds no TCP port. Its TCP fallback default is 8010, which is also the nixpkgs buildbot default.
- Host budget: Hetzner CX53, 16 vCPU, 32 GiB RAM, `/nix` under a 250 G ZFS quota. The incumbent already sizes 4 eval workers at 2 GiB (`modules/nixos/buildbot.nix:150-154`). nixbot takes `evalWorkerCount = 2` and `evalMaxMemorySize = 2048`.
- `buildSystems = [ "x86_64-linux" ]`, matching the incumbent (`modules/nixos/buildbot.nix:111`).
- `admins` entries are provider-qualified for nixbot (`github:cameronraysmith`), unlike buildbot's bare `cameronraysmith`.
- Long or output-heavy commands are captured: `<command> 2>&1 | tee logs/<identifier>-$(date +%Y%m%d-%H%M%S).log`, with any filter after the `tee`.

---

### Task 1: Dedicated GitHub App

**Files:**
- Modify: `openspec/changes/stand-up-nixbot-on-magnetite/verify.md` (record the application id, OAuth client id, and installation selection)

**Interfaces:**
- Consumes: nothing.
- Produces: the numeric application id used as `services.nixbot.github.appId` in Task 5; the OAuth client id used as `services.nixbot.github.oauthId`; and three secret values consumed by Task 4 — the application's PEM private key, its OAuth client secret, and the webhook secret this task sets on the application to the value Task 4 generates.

- [ ] **Step 1: Register the application**

At `https://github.com/settings/apps/new` (or the organization equivalent), create an application named for nixbot with:

- Homepage URL: `https://nixbot.scientistexperience.net/`
- Webhook URL: `https://nixbot.scientistexperience.net/webhooks/github`
- User authorization callback URL: `https://nixbot.scientistexperience.net/auth/github/callback`
- Repository permissions: Contents read-only, Checks read and write, Metadata read-only, Pull requests read-only
- Organization permissions: Members read-only
- Subscribe to events: Push, Pull request, Check run, Check suite

These are nixbot's documented requirements (`~/ghq/github.com/Mic92/nixbot/docs/GITHUB.md:17-33`). Do not touch the incumbent application (id `3305657`, `modules/nixos/buildbot.nix:129`).

- [ ] **Step 2: Record identifiers and generate the private key**

Record the numeric App ID and the OAuth client id in verify.md. Generate a private key and keep the downloaded PEM available for Task 4 Step 4; do not commit it anywhere.

- [ ] **Step 3: Install with a narrow repository selection**

Install the application on the account with "Only select repositories", choosing only repositories intended for nixbot. Record the exact selection in verify.md, together with the answer to the design's open question: whether the provider permits an installation with no repository selected at all.

- [ ] **Step 4: Confirm the incumbent application is unchanged**

Open the incumbent application's settings and record its permissions, events, webhook URL, and installation selection in verify.md, confirming they match the pre-change state.

- [ ] **Step 5: Commit the record**

```bash
git add openspec/changes/stand-up-nixbot-on-magnetite/verify.md
git commit -m "docs(nixbot): record dedicated GitHub App registration"
```

---

### Task 2: Flake input

**Files:**
- Modify: `flake.nix:62-64` region (add the input beside `buildbot-nix`)
- Modify: `flake.lock`

**Interfaces:**
- Consumes: nothing.
- Produces: `inputs.nixbot`, whose `nixosModules.nixbot` Task 6 imports.

- [ ] **Step 1: Add the input**

In `flake.nix`, immediately after the `buildbot-nix` block at lines 62-64, add:

```nix
    nixbot.url = "github:Mic92/nixbot";
    nixbot.inputs.nixpkgs.follows = "nixpkgs";
    nixbot.inputs.treefmt-nix.follows = "treefmt-nix";
```

- [ ] **Step 2: Lock it**

Run: `nix flake lock 2>&1 | tee logs/flake-lock-nixbot-$(date +%Y%m%d-%H%M%S).log`
Expected: the log reports adding input `nixbot` and no other input changing.

- [ ] **Step 3: Verify the lock**

Run:

```bash
nix flake metadata --json | python3 -c 'import json,sys; d=json.load(sys.stdin); n=d["locks"]["nodes"]; print("nixbot", n["nixbot"]["locked"]["rev"]); print("buildbot-nix", n["buildbot-nix"]["locked"]["rev"])'
```

Expected: a revision printed for `nixbot`, and the `buildbot-nix` revision identical to the one before this task (compare against `git show HEAD:flake.lock`).

- [ ] **Step 4: Commit**

```bash
git add flake.nix flake.lock
git commit -m "feat(nixbot): add nixbot flake input"
```

---

### Task 3: Aspect skeleton with credential generators

**Files:**
- Create: `modules/nixos/nixbot.nix`

**Interfaces:**
- Consumes: nothing from earlier tasks at evaluation time.
- Produces: `flake.modules.nixos.nixbot`, and three generators whose file paths Task 5 consumes: `nixbot-github-app-secret-key.files."key.pem"`, `nixbot-github-webhook-secret.files."secret"`, and `nixbot-github-oauth-secret.files."secret"`.

- [ ] **Step 1: Write the aspect with its generators only**

Create `modules/nixos/nixbot.nix` with exactly this content; the service block arrives in Task 5, so this step is complete and evaluable on its own:

```nix
# nixbot CI service for magnetite, standing beside the buildbot-nix server.
#
# Coexistence constraints (buildbot stays authoritative for every repository):
#   - statusContextPrefix is left at its default "nixbot"; buildbot's contexts
#     are "buildbot/..." and the forge's required checks name those.
#   - github.topic is null; its default "build-with-buildbot" is the topic
#     buildbot's repositories carry, and it one-shot-imports on an empty DB.
#   - nginx.enable stays true, so the service listens only on
#     /run/nixbot/web.sock and binds no TCP port (its TCP fallback default
#     8010 is also the nixpkgs buildbot default).
#   - A dedicated GitHub App, not buildbot's (id 3305657, buildbot.nix:129):
#     nixbot needs Checks write and the check_run/check_suite events, which
#     buildbot-nix does not, so sharing would edit a running service's
#     registration.
#
# Credential generator catalog (slots; values populated as marked):
#   - nixbot-github-app-secret-key: manual `clan vars set` (GitHub App PEM key)
#   - nixbot-github-oauth-secret: manual `clan vars set` (OAuth client secret)
#   - nixbot-github-webhook-secret: auto-generated
{
  flake.modules.nixos.nixbot =
    {
      config,
      pkgs,
      ...
    }:
    {
      # GitHub App private key (populated manually via clan vars set)
      clan.core.vars.generators.nixbot-github-app-secret-key = {
        files."key.pem" = {
          owner = "nixbot";
          restartUnits = [ "nixbot.service" ];
        };
        script = ''
          echo "nixbot GitHub App private key: populate via clan vars set" >&2
          exit 1
        '';
      };

      # GitHub App OAuth client secret (populated manually via clan vars set)
      clan.core.vars.generators.nixbot-github-oauth-secret = {
        files."secret" = {
          owner = "nixbot";
          restartUnits = [ "nixbot.service" ];
        };
        script = ''
          echo "nixbot GitHub OAuth secret: populate via clan vars set" >&2
          exit 1
        '';
      };

      clan.core.vars.generators.nixbot-github-webhook-secret = {
        files."secret" = {
          owner = "nixbot";
          restartUnits = [ "nixbot.service" ];
        };
        runtimeInputs = [ pkgs.openssl ];
        script = ''
          openssl rand -hex 32 > $out/secret
        '';
      };
    };
}
```

- [ ] **Step 2: Verify the aspect is discovered**

Run:

```bash
nix eval .#modules.nixos --apply 'm: builtins.elem "nixbot" (builtins.attrNames m)'
```

Expected: `true`. import-tree discovers any tracked `.nix` file under `modules/`, so the file must be added to git for this to pass (`modules/README.md:6-12`).

- [ ] **Step 3: Format and lint**

Run: `just lint 2>&1 | tee logs/lint-nixbot-aspect-$(date +%Y%m%d-%H%M%S).log`
Expected: passes, including the secret scan.

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/nixbot.nix
git commit -m "feat(nixbot): add nixbot aspect with credential generators"
```

---

### Task 4: Populate the credentials

**Files:**
- Create: `vars/per-machine/magnetite/nixbot-github-app-secret-key/key.pem/` (generated, committed encrypted)
- Create: `vars/per-machine/magnetite/nixbot-github-oauth-secret/secret/` (generated, committed encrypted)
- Create: `vars/per-machine/magnetite/nixbot-github-webhook-secret/secret/` (generated, committed encrypted)

**Interfaces:**
- Consumes: the three secret values from Task 1; the generator names from Task 3.
- Produces: three deployable credential entries; the webhook secret value must be entered into the forge application's webhook configuration in Step 5.

This task depends on Task 6 having placed the aspect on the host before `clan vars` can see the generators. If `clan vars list magnetite` does not show them, do Task 6 first and return here; the two are independent in content and only ordered by that visibility.

- [ ] **Step 1: List what exists now**

Run: `clan vars list magnetite 2>&1 | tee logs/clan-vars-list-before-$(date +%Y%m%d-%H%M%S).log`
Expected: the incumbent's six `buildbot-*` generators, and the three `nixbot-*` generators reported as not yet set.

- [ ] **Step 2: Generate the webhook secret**

Run: `clan vars generate magnetite 2>&1 | tee logs/clan-vars-generate-$(date +%Y%m%d-%H%M%S).log`
Expected: `nixbot-github-webhook-secret` is generated; the two manual generators fail their scripts by design with the "populate via clan vars set" message, which is the slot marker and not an error to fix.

- [ ] **Step 3: Set the application private key**

Run: `clan vars set magnetite nixbot-github-app-secret-key/key.pem`
Paste the PEM from Task 1 Step 2 at the prompt.

- [ ] **Step 4: Set the OAuth client secret**

Run: `clan vars set magnetite nixbot-github-oauth-secret/secret`
Paste the client secret generated on the application's settings page.

- [ ] **Step 5: Put the webhook secret on the application**

Read the generated value on the deploy host after Task 8, or read it out of the vars store with `clan vars get magnetite nixbot-github-webhook-secret/secret`, and enter it as the application's webhook secret. The forge and the host must hold the same value or every delivery is rejected.

- [ ] **Step 6: Verify all three are set and encrypted**

Run:

```bash
clan vars list magnetite 2>&1 | tee logs/clan-vars-list-after-$(date +%Y%m%d-%H%M%S).log
head -c 64 vars/per-machine/magnetite/nixbot-github-app-secret-key/key.pem/secret
```

Expected: all three reported set; the second command prints a sops-encrypted blob header, not PEM text.

- [ ] **Step 7: Commit**

```bash
git add vars/per-machine/magnetite
git commit -m "feat(nixbot): add nixbot credential vars for magnetite"
```

---

### Task 5: Service configuration

**Files:**
- Modify: `modules/nixos/nixbot.nix` (append the service block inside the aspect)

**Interfaces:**
- Consumes: the generator paths from Task 3; `appId` and `oauthId` from Task 1.
- Produces: `services.nixbot.*` on magnetite, which Task 7 builds and Task 8 deploys.

- [ ] **Step 1: Append the service block**

Inside the aspect body in `modules/nixos/nixbot.nix`, after the third generator, add — substituting the two recorded identifiers from Task 1 for `<APP_ID>` and `<OAUTH_CLIENT_ID>`:

```nix
      services.nixbot = {
        enable = true;
        domain = "nixbot.scientistexperience.net";

        admins = [ "github:cameronraysmith" ];

        buildSystems = [ "x86_64-linux" ];

        # Sized beside the incumbent's 4 workers x 2 GiB (buildbot.nix:150-154)
        # on a 16 vCPU / 32 GiB host: 2 x 2 GiB here keeps the pair inside the
        # same headroom the incumbent's comment budgets for.
        evalWorkerCount = 2;
        evalMaxMemorySize = 2048;

        github = {
          enable = true;
          appId = <APP_ID>;
          appSecretKeyFile =
            config.clan.core.vars.generators.nixbot-github-app-secret-key.files."key.pem".path;
          webhookSecretFile =
            config.clan.core.vars.generators.nixbot-github-webhook-secret.files."secret".path;
          oauthId = "<OAUTH_CLIENT_ID>";
          oauthSecretFile =
            config.clan.core.vars.generators.nixbot-github-oauth-secret.files."secret".path;

          # Default is "build-with-buildbot", the topic the incumbent's
          # repositories carry, and it one-shot-imports against an empty DB.
          topic = null;

          # No repository is built by this service until a later change opts
          # one in. Empty-list semantics are verified by observing the project
          # list after deployment, not assumed.
          repoAllowlist = [ ];
        };

        # The module creates the vhost proxying to /run/nixbot/web.sock and this
        # flag makes it forceSSL + enableACME. The incumbent aspect writes that
        # vhost override by hand only because buildbot-nix has no such option.
        nginx.enableACME = true;

        database.createLocally = true;
      };
```

- [ ] **Step 2: Verify the option values**

Run:

```bash
nix eval --json .#nixosConfigurations.magnetite.config.services.nixbot \
  --apply 'c: { inherit (c) enable domain buildSystems evalWorkerCount evalMaxMemorySize statusContextPrefix; topic = c.github.topic; allow = c.github.repoAllowlist; acme = c.nginx.enableACME; nginx = c.nginx.enable; db = c.database.createLocally; }'
```

Expected: `enable` true, `domain` `"nixbot.scientistexperience.net"`, `topic` null, `allow` `[]`, `acme` true, `nginx` true, `db` true, `statusContextPrefix` `"nixbot"`, `evalWorkerCount` 2.

- [ ] **Step 3: Verify the incumbent is untouched**

Run:

```bash
nix eval --raw .#nixosConfigurations.magnetite.config.services.buildbot-nix.master.domain
git diff --stat HEAD~4 -- modules/nixos/buildbot.nix buildbot-nix.toml
```

Expected: `buildbot.scientistexperience.net`, and an empty diff for both paths.

- [ ] **Step 4: Verify resource disjointness in the evaluated configuration**

Run:

```bash
nix eval --json .#nixosConfigurations.magnetite.config \
  --apply 'c: { units = builtins.filter (n: n == "nixbot" || n == "buildbot-master" || n == "buildbot-worker") (builtins.attrNames c.systemd.services); users = builtins.filter (n: n == "nixbot" || n == "buildbot" || n == "buildbot-worker") (builtins.attrNames c.users.users); }'
```

Expected: all three units and all three users present as distinct names.

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/nixbot.nix
git commit -m "feat(nixbot): configure nixbot service for magnetite"
```

---

### Task 6: Host composition

**Files:**
- Modify: `modules/machines/nixos/magnetite/default.nix:29-53`

**Interfaces:**
- Consumes: `inputs.nixbot` from Task 2; `flake.modules.nixos.nixbot` from Task 3.
- Produces: the evaluated magnetite configuration Tasks 5, 7, and 8 act on.

- [ ] **Step 1: Import the upstream module**

In the `imports` list at lines 29-37, after `inputs.buildbot-nix.nixosModules.buildbot-worker` on line 36, add:

```nix
        inputs.nixbot.nixosModules.nixbot
```

Import the real module name. `nixosModules.buildbot-nix`, `buildbot-master`, and `buildbot-worker` in the nixbot flake are deprecated aliases that warn (`~/ghq/github.com/Mic92/nixbot/flake.nix:56-68`), and importing one of those from nixbot alongside the genuine buildbot-nix modules would be actively confusing.

- [ ] **Step 2: Name the aspect**

In the aspect list at lines 38-53, add `nixbot` on its own line immediately after `buildbot` on line 43:

```nix
        buildbot
        nixbot
```

- [ ] **Step 3: Verify composition**

Run:

```bash
nix eval .#nixosConfigurations.magnetite.config.services.nixbot.enable
nix eval .#nixosConfigurations.magnetite.config.services.buildbot-nix.master.enable
```

Expected: `true` for both.

- [ ] **Step 4: Commit**

```bash
git add modules/machines/nixos/magnetite/default.nix
git commit -m "feat(nixbot): compose nixbot onto magnetite"
```

---

### Task 7: Hostname

**Files:**
- Modify: `modules/terranix/cloudflare.nix` (after the `buildbot` record at lines 61-69)

**Interfaces:**
- Consumes: nothing.
- Produces: public resolution for `nixbot.scientistexperience.net`, without which certificate issuance in Task 9 cannot complete.

- [ ] **Step 1: Add the record**

After the `buildbot` record ending at line 69, add:

```nix
      # DNS CNAME record for nixbot CI endpoint (resolves to magnetite)
      resource.cloudflare_dns_record.nixbot = {
        zone_id = config.data.cloudflare_zone.scientistexperience "id";
        name = "nixbot";
        type = "CNAME";
        content = "magnetite.scientistexperience.net";
        ttl = 1; # automatic
        proxied = false;
      };
```

`proxied = false` matches every sibling record and is what lets the ACME HTTP challenge reach the host.

- [ ] **Step 2: Plan**

Run: `just --list | grep -i terraform` to identify this repository's terraform recipes, then run the plan recipe: `just terraform-plan 2>&1 | tee logs/terraform-plan-nixbot-$(date +%Y%m%d-%H%M%S).log`
Expected: exactly one resource to add, none to change, none to destroy.

- [ ] **Step 3: Apply**

Run: `just terraform-apply 2>&1 | tee logs/terraform-apply-nixbot-$(date +%Y%m%d-%H%M%S).log`
Expected: one resource added.

- [ ] **Step 4: Verify resolution**

Run: `dig +short nixbot.scientistexperience.net`
Expected: resolves through `magnetite.scientistexperience.net` to the host's address, with no Cloudflare proxy address in the chain.

- [ ] **Step 5: Commit**

```bash
git add modules/terranix/cloudflare.nix
git commit -m "feat(nixbot): declare nixbot DNS record"
```

---

### Task 8: Build gate

**Files:** none modified.

**Interfaces:**
- Consumes: everything from Tasks 2, 3, 5, and 6.
- Produces: the built host toplevel Task 9 deploys.

- [ ] **Step 1: Build the host's configuration**

Run:

```bash
nix build .#checks.x86_64-linux.nixos-magnetite 2>&1 | tee logs/nixos-magnetite-$(date +%Y%m%d-%H%M%S).log
```

Expected: succeeds. This check is `config.system.build.toplevel` for every non-deferred NixOS machine on the system (`modules/checks/machines.nix:19-34`), so it is the narrowest thing that can falsify the whole configuration without touching the host.

- [ ] **Step 2: Confirm no other check regressed by this change**

Run:

```bash
nix eval .#checks.x86_64-linux --apply builtins.attrNames --json
```

Expected: the same check names as before this change, plus nothing removed. A full `just check-fast` run belongs to pre-pull-request validation, not to this step.

---

### Task 9: Deploy and verify

**Files:**
- Modify: `openspec/changes/stand-up-nixbot-on-magnetite/verify.md` (record every observation below)

**Interfaces:**
- Consumes: Task 8's built configuration; Task 4's credentials; Task 7's DNS record.
- Produces: the deployed service and the recorded evidence the change's acceptance rests on.

- [ ] **Step 1: Deploy**

Run:

```bash
clan machines update magnetite 2>&1 | tee logs/clan-update-magnetite-$(date +%Y%m%d-%H%M%S).log
```

Expected: completes without error.

- [ ] **Step 2: Confirm the unit and socket**

Run:

```bash
ssh root@magnetite.zt 'systemctl is-active nixbot.service nixbot.socket; systemctl is-active buildbot-master.service buildbot-worker.service'
```

Expected: `active` for the nixbot unit and socket, and `active` for both incumbent units.

- [ ] **Step 3: Confirm both hostnames serve**

Run:

```bash
curl -sS -o /dev/null -w '%{http_code} %{ssl_verify_result}\n' https://nixbot.scientistexperience.net/
curl -sS -o /dev/null -w '%{http_code} %{ssl_verify_result}\n' https://buildbot.scientistexperience.net/
```

Expected: a success or redirect status with `ssl_verify_result` 0 for both.

- [ ] **Step 4: Confirm no port was claimed**

Run:

```bash
ssh root@magnetite.zt 'ss -ltnp | grep -E ":8010|nixbot" || echo "no nixbot tcp listener"'
```

Expected: `no nixbot tcp listener`.

- [ ] **Step 5: Confirm both databases exist**

Run:

```bash
ssh root@magnetite.zt "sudo -u postgres psql -lqt | cut -d'|' -f1,2 | grep -E 'nixbot|buildbot'"
```

Expected: both databases listed, each owned by its own role.

- [ ] **Step 6: Confirm the service builds nothing**

Run:

```bash
curl -sS https://nixbot.scientistexperience.net/api/v1/projects | head -c 400
```

Expected: an empty project collection. If the endpoint path differs at the pinned revision, read it from the service's own interface and record the actual path in verify.md.

- [ ] **Step 7: Exercise delivery authentication both ways**

Redeliver the most recent delivery from the application's Advanced settings page and record the response status. Then run:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' \
  -d '{}' https://nixbot.scientistexperience.net/webhooks/github
```

Expected: the redelivery is accepted with a 2xx; the unsigned request is rejected with a 4xx.

- [ ] **Step 8: Record the capacity baseline**

Run:

```bash
ssh root@magnetite.zt 'free -g; zfs list -o name,used,avail,quota zroot/root/nix; systemctl status nixbot.service --no-pager | head -20'
```

Record memory in use, the store dataset's usage against its quota, and the nixbot unit's memory in verify.md as the baseline the first repository opt-in will be measured against.

- [ ] **Step 9: Confirm the rollback path**

On a scratch branch, remove `nixbot` from magnetite's aspect list and run:

```bash
nix build .#checks.x86_64-linux.nixos-magnetite 2>&1 | tee logs/nixos-magnetite-rollback-$(date +%Y%m%d-%H%M%S).log
```

Expected: builds cleanly, establishing that withdrawal is a redeploy rather than a repair. Discard the scratch branch.

- [ ] **Step 10: Commit the evidence**

```bash
git add openspec/changes/stand-up-nixbot-on-magnetite/verify.md
git commit -m "docs(nixbot): record deployment verification for magnetite"
```

---

### Task 10: Documentation

**Files:**
- Create or modify: a page under `packages/docs/src/content/docs/` recording the two-service topology

**Interfaces:**
- Consumes: the decisions in design.md and the observations in verify.md.
- Produces: the documented topology a later migration change reads before opting a repository in.

- [ ] **Step 1: Write the page**

Document: the two build services and their hostnames; that buildbot remains authoritative for every repository; the dedicated forge application and why it is not shared; the three boundaries that keep nixbot from building anything; the verdict-namespace distinction and what it means for required checks; and the shared surfaces that remain common-mode (nginx, PostgreSQL, the nix store and its quota, the ACME account, capacity).

- [ ] **Step 2: Verify the docs build**

Run: `just docs-build 2>&1 | tee logs/docs-build-nixbot-$(date +%Y%m%d-%H%M%S).log`
Expected: succeeds.

- [ ] **Step 3: Verify links**

Run: `nix build .#checks.x86_64-linux.package-vanixiets-docs-test-linkcheck 2>&1 | tee logs/docs-linkcheck-$(date +%Y%m%d-%H%M%S).log`
Expected: succeeds. If the check's attribute name differs on this system, resolve it from `nix eval .#checks.x86_64-linux --apply builtins.attrNames`.

- [ ] **Step 4: Commit**

```bash
git add packages/docs
git commit -m "docs(nixbot): document the two-service build topology on magnetite"
```
