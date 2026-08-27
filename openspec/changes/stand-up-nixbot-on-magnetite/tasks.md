## 1. Forge application

- [ ] 1.1 Register a dedicated GitHub App for nixbot with repository permissions Contents read, Checks write, Metadata read, Pull requests read, organization permission Members read, and subscribed events push, pull request, check run, and check suite; set its webhook URL to `https://nixbot.scientistexperience.net/webhooks/github` and its user-authorization callback to `https://nixbot.scientistexperience.net/auth/github/callback` — verify: the application's settings page lists exactly those permissions and events, and its numeric id and OAuth client id are recorded in this change's verify.md
- [ ] 1.2 Install that application with a repository selection covering only repositories intended for nixbot, and record the resulting selection — verify: the application's installations page shows that selection, recorded verbatim in verify.md, and the resolution of the design's open question about whether an empty selection is permitted is recorded with it
- [ ] 1.3 Open the incumbent buildbot application's settings and confirm its permissions, events, webhook URL, and installation selection are unchanged — verify: the recorded incumbent settings match the pre-change state, with the application id noted in verify.md

## 2. Flake input

- [ ] 2.1 Add the `nixbot` flake input to `flake.nix`, following this repository's `nixpkgs`, and lock it — verify: `nix flake metadata --json` reports a `nixbot` node pinned to a specific revision, and `nix eval .#modules.nixos --apply builtins.attrNames` still evaluates
- [ ] 2.2 Confirm the existing `buildbot-nix` input is untouched — verify: `git diff flake.nix` shows only the added `nixbot` input, and `nix flake metadata --json` reports the `buildbot-nix` node at its previous revision

## 3. Credentials

- [ ] 3.1 Declare three `clan.core.vars` generators in the new aspect — an operator-populated application private key, a generated webhook secret, and an operator-populated interface-login secret — each owned by the service user with the service named in its restart list — verify: `nix eval .#nixosConfigurations.magnetite.config.clan.core.vars.generators --apply builtins.attrNames` lists the three new generators alongside the incumbent's six
- [ ] 3.2 Generate the webhook secret and populate the two operator slots with the values from task 1.1 — verify: `clan vars list magnetite` reports all three as set, and `vars/per-machine/magnetite/` carries one encrypted entry per generator file
- [ ] 3.3 Confirm no credential value entered the repository — verify: `just lint` passes, including its secret scan, and reading each new `vars/` entry shows an encrypted blob rather than a value

## 4. First-party aspect

- [ ] 4.1 Write `modules/nixos/nixbot.nix` defining `flake.modules.nixos.nixbot`, configuring the service with its own hostname, its GitHub integration referencing the three credential paths, the topic-based repository adoption disabled, an explicit repository allowlist, provider-qualified administrators, the host's own platform as the only build system, explicitly chosen evaluation worker count and per-worker memory, the local database path, and the module's proxy integration left enabled with certificate issuance requested — verify: `nix eval .#nixosConfigurations.magnetite.config.services.nixbot` sub-attributes return those values, specifically `domain`, `github.topic` as null, `github.repoAllowlist`, `buildSystems`, `evalWorkerCount`, `database.createLocally`, `nginx.enable`, and `nginx.enableACME`
- [ ] 4.2 Confirm the verdict namespace is left at the module's default rather than set to the incumbent's — verify: `nix eval .#nixosConfigurations.magnetite.config.services.nixbot.statusContextPrefix` returns the module default and not the incumbent's prefix
- [ ] 4.3 Give the aspect file a header documenting its generators and its coexistence constraints, following the incumbent aspect's header form — verify: the file's header names each generator and its consumer, and `just lint` passes

## 5. Host composition

- [ ] 5.1 Import the upstream `inputs.nixbot.nixosModules.nixbot` module in `modules/machines/nixos/magnetite/default.nix` alongside the existing upstream imports, and name `nixbot` in that host's aspect list — verify: `nix eval .#nixosConfigurations.magnetite.config.services.nixbot.enable` returns true
- [ ] 5.2 Confirm the incumbent's composition is unchanged — verify: `git diff --stat` reports no change under `modules/nixos/buildbot.nix` or the repository-root `buildbot-nix.toml`, and `nix eval .#nixosConfigurations.magnetite.config.services.buildbot-nix.master.domain` still returns the incumbent's hostname
- [ ] 5.3 Confirm the two services claim disjoint host resources in the evaluated configuration — verify: `nix eval` of the magnetite configuration shows distinct unit names, distinct users and groups, distinct state directories, and distinct root-retention directories for the two services, and that no TCP port is bound on the new service's behalf

## 6. Hostname

- [ ] 6.1 Add an unproxied `nixbot` CNAME to `modules/terranix/cloudflare.nix` following the existing incumbent record — verify: the repository's terraform plan recipe reports exactly one record to add and none to change or destroy
- [ ] 6.2 Apply the plan and confirm public resolution — verify: `dig +short nixbot.scientistexperience.net` resolves through to the host's address, and the record is not intercepted by the provider's proxy

## 7. Build gate

- [ ] 7.1 Build the host's configuration without deploying it — verify: `nix build .#checks.x86_64-linux.nixos-magnetite 2>&1 | tee logs/nixos-magnetite-$(date +%Y%m%d-%H%M%S).log` succeeds

## 8. Deployment

- [ ] 8.1 Deploy the host — verify: `clan machines update magnetite 2>&1 | tee logs/clan-update-magnetite-$(date +%Y%m%d-%H%M%S).log` completes, and on the host `systemctl is-active nixbot.service` reports active with its socket unit present

## 9. Documentation

- [ ] 9.1 Record the two-service topology, the dedicated forge application, and the boundaries that keep the new service from building anything, in the repository's documentation tree — verify: `just docs-build` succeeds and the documentation link check passes

## 10. Integration Verification

- [ ] 10.1 Verify the new service answers at its own hostname over an accepted connection — verify: an HTTPS request to `https://nixbot.scientistexperience.net/` returns a successful response with a certificate issued for that hostname
- [ ] 10.2 Verify the incumbent still serves — verify: an HTTPS request to `https://buildbot.scientistexperience.net/` returns a successful response, and the incumbent's units on the host report active
- [ ] 10.3 Verify the new service builds nothing — verify: its interface reports an empty repository set, and no build has been recorded since deployment
- [ ] 10.4 Verify delivery authentication both ways — verify: a redelivery from the forge application's advanced settings is accepted with a successful response, and a request to the same endpoint without the shared secret is rejected
- [ ] 10.5 Verify both databases exist on the one instance — verify: listing databases on the host shows the incumbent's and the new service's side by side, each owned by its own role
- [ ] 10.6 Verify no verdict namespace collision — verify: no check run bearing the incumbent's prefix originates from the new service, and no repository's required checks name the new service's prefix
- [ ] 10.7 Verify the capacity picture after deployment — verify: memory in use, the store dataset's free space against its quota, and the incumbent's evaluation and build activity are recorded in verify.md as the baseline the first repository opt-in will be measured against
- [ ] 10.8 Verify the rollback path is available — verify: removing the aspect from the host's list builds cleanly as a check, establishing that withdrawal is a redeploy rather than a repair
