<!--
Raw capture of the brainstorming step for this change.

Procedural note, recorded rather than elided: the interactive `superpowers:brainstorming`
dialogue was NOT run. This change was authored by an autonomous session whose launch brief
pre-settled the scope decisions and instructed it not to wait for a human, so the
schema-sanctioned manual-write path was taken. What follows is the decision log that the
interactive skill would have produced: the questions that actually had to be answered, the
options for each, the answer taken, and the evidence it rests on. Questions whose answer
arrived pre-settled from the launch brief are marked `[given]`; the rest were decided from
research evidence and are marked `[decided]`, with the evidence cited inline.
-->

# Background

Two build services are in play, and one of them must not be disturbed.

The incumbent is buildbot-nix, serving `buildbot.scientistexperience.net` from magnetite.
Its composition path was genuinely unknown at the start of this work and is now established: `flake.nix:5` hands `modules/` to `import-tree`, `modules/nixos/buildbot.nix:20` assigns the aspect `flake.modules.nixos.buildbot`, `modules/machines/nixos/magnetite/default.nix:35-36` imports the upstream `inputs.buildbot-nix.nixosModules.buildbot-master` and `buildbot-worker` modules directly, and line 43 of the same file's aspect list names `buildbot`.
`modules/clan/machines.nix:29-31` then binds `flake.modules.nixos."machines/nixos/magnetite"` into `clan.machines.magnetite`, which is what `clan machines update magnetite` deploys.
No `machines/`-level import exists because host composition does not live there; it lives under `modules/machines/`.
Magnetite is the only host importing the buildbot aspect.

The candidate is nixbot, Mic92's single-process successor to the buildbot-nix master/worker pair.
Its real NixOS surface is `nixosModules.nixbot` (`nixbot/flake.nix:65`); `buildbot-nix`, `buildbot-master`, and `buildbot-worker` are deprecated aliases that warn (`nixbot/flake.nix:56-68`).
It is one systemd service plus a socket unit, evaluates with a bundled nix-eval-jobs, builds through the host nix daemon, scales out through ordinary nix remote builders, and has no worker concept at all (`nixbot/README.md:3-11, 46-55`; `nixbot/docs/MIGRATION.md:23-24`).

Two migrated reference deployments exist.
Mic92's own dotfiles is GitHub-backed like vanixiets and migrated in two phases: the module swap at `7e55c8a4` (2026-07-16) kept the old domain and the old check-name prefix, `7c99c63c` (2026-07-26) flipped the domain, and `0aa2dcc1`/`0b138e94` (2026-08-16) rewrote the deployment into Mic92's "flakelet" runtime shape.
clan-infra is Gitea-backed and runs nixbot on `web01` through a wrapper module `flake.nixosModules.nixbot = [ inputs.nixbot.nixosModules.nixbot ./nixbot.nix ]` (`clan-infra/modules/flake-module.nix:59-62`), deployed by `clan machines update web01`, with credentials supplied by prompt-based `clan.core.vars` generators (`clan-infra/modules/nixbot.nix:9-84`).

# Decision chain

## Q1 [given]: does nixbot replace buildbot, or coexist with it?

Coexist.
Buildbot stays authoritative for every repository; nixbot is stood up beside it at `nixbot.scientistexperience.net`, and success is `clan machines update magnetite` deploying a working instance.
This one answer propagates into almost every decision below, because both reference deployments assumed replacement and their choices invert under coexistence.

## Q2 [decided]: which deployment shape — the upstream NixOS module, or Mic92's flakelet runtime?

Taken: the upstream NixOS module, composed the way this repository already composes buildbot.

The flakelet shape at dotfiles HEAD evaluates nixbot's units from the nixbot flake on the machine at runtime, decoupled from the NixOS generation, and needs three further Mic92-only inputs (`dotfiles/flake.nix:95-99`) plus a push-deploy path over step-ca SSH certificates (`dotfiles/machines/eve/modules/nixbot.nix:311-356`).
Under that shape `clan machines update magnetite` would stop being the truth about what runs, which is exactly the property the brief names as success.
The directly transferable precedent is the dotfiles snapshot at `df7be240` (2026-07-24): flake input, `inputs.nixbot.nixosModules.nixbot` imported at the host, a `services.nixbot` block, and a plain nginx vhost.
That shape ran for a month before being replaced for reasons specific to Mic92's deploy tooling, and clan-infra still runs the equivalent today.

Within that, one sub-fork: clan-infra bundles upstream and site config into a wrapper list, whereas vanixiets imports the upstream module at the machine and keeps site config in a named aspect (`modules/machines/nixos/magnetite/default.nix:29-51`).
Follow vanixiets' own convention, since the buildbot precedent in this repository is exactly that and a second composition style would be a second convention beside an existing one.

## Q3 [decided]: reuse buildbot's GitHub App, or register a second one?

Taken: a second, dedicated GitHub App.

dotfiles reused its App unchanged across the migration — same `appId` 915265, same OAuth client id, same three secret names — and that is strong evidence reuse works *when nixbot replaces buildbot*.
Under coexistence the same move imports the incumbent's blast radius into the new service.
nixbot needs Checks read-write and Pull requests read-only and the `check_run`/`check_suite` events (`nixbot/docs/GITHUB.md:23-33`), none of which buildbot-nix requires (`buildbot-nix/docs/GITHUB.md:23-36`), so reuse means editing the permissions of the App the running server depends on.
Reuse also means one App-level webhook and one identity for both services; buildbot-nix creates per-repository webhooks pointing at `change_hook/github` (`buildbot-nix/buildbot_nix/buildbot_nix/github_projects.py:666-684`) while nixbot consumes the App-level webhook at `/webhooks/github` (`nixbot/docs/GITHUB.md:17-19`), so the two do not collide today, but a single App couples every later permission change to both.
A second App costs one registration and three new credentials and keeps the incumbent's registration untouched, which is what "must keep working untouched" requires.

## Q4 [decided]: how is "builds nothing yet" enforced?

Taken: three independent boundaries, none of them claimed as end-to-end.

nixbot's `github.topic` defaults to `build-with-buildbot` and performs a one-shot import on an empty database (`nixbot/nixosModules/nixbot.nix:434-444`).
Left at its default against an App installed on this fleet's repositories, that default would sweep in precisely the repositories buildbot already builds, and double-build them.
So: the forge application's installation selection bounds what nixbot can see at all; `github.topic = null` disables the topic import; and `repoAllowlist` names exactly the intended set.
The first boundary lives in GitHub's UI, outside anything this repository can assert, which is why the interface capability states the boundary rather than claiming the guarantee.

## Q5 [decided]: which check-name prefix?

Taken: the default, `nixbot`.

Both reference deployments set `statusContextPrefix = "buildbot"` (`clan-infra/modules/nixbot.nix`; `dotfiles/machines/eve/modules/nixbot.nix`), and both were right to, because nixbot inherited branch-protection rules that name `buildbot/...` contexts.
Here the service those rules name is still running.
Keeping the default `nixbot` prefix (`nixbot/nixosModules/nixbot.nix:326-337`) leaves the incumbent's verdicts as the only ones the forge's required checks name, which makes the new service's verdicts advisory by construction rather than by promise.

## Q6 [decided]: reverse proxy and TLS

Taken: the module-managed vhost with `nginx.enableACME = true`.

nixbot's `nginx.enable` defaults true and creates the vhost proxying to `/run/nixbot/web.sock` (`nixbot/nixosModules/nixbot.nix:1122-1141`), but `nginx.enableACME` defaults **false** (`:866-869`), so TLS must be asked for explicitly.
Every other vanixiets vhost on magnetite is `forceSSL` plus `enableACME` against one shared ACME account (`modules/machines/nixos/magnetite/default.nix:87-90`), so the flag reproduces the house pattern.
Leaving nginx enabled also keeps the service off TCP entirely: the 8010 port is bound only when `nginx.enable = false` (`:937`), and 8010 happens to be the nixpkgs buildbot default, so disabling nginx would manufacture the one port collision available here.

DNS is declarative through terranix, and there is no `nixbot` record today; the existing `buildbot` CNAME at `modules/terranix/cloudflare.nix:62-69` is the template, `proxied = false` so ACME's HTTP challenge reaches the host.

## Q7 [decided]: database

Taken: `database.createLocally = true` on magnetite's existing shared PostgreSQL.

The host runs exactly one PostgreSQL instance, additively configured by gitea, matrix-synapse, cognee, niks3, and buildbot, listening on the local socket and loopback only.
nixbot's local-database path adds database and role `nixbot` (`nixbot/nixosModules/nixbot.nix:1111-1120`) and connects over `/run/postgresql`, which merges into that instance rather than standing up a second one.
No history carries over from buildbot (`nixbot/docs/MIGRATION.md:26-29`), which is irrelevant here because buildbot keeps its own database and its own history.

## Q8 [decided]: credentials

Taken: three `clan.core.vars` generators named after their consumer, mirroring the incumbent's naming.

clan vars is this fleet's primary secrets system, with sops-nix retained for supplementary user secrets (`packages/docs/src/content/docs/guides/secrets-management.md:14-16`), and buildbot's own six generators are the in-repo pattern (`modules/nixos/buildbot.nix:22-100`), consumed as `...files."<file>".path`.
nixbot takes every secret as a file path and passes it to the unit as a systemd credential (`nixbot/nixosModules/nixbot.nix:1028-1035`), so the same shape applies unchanged: App private key and OAuth secret are operator-populated slots, the webhook secret is generated.

## Q9 [decided]: capacity

Taken: size the new service explicitly and treat capacity, not naming, as the real coexistence risk.

Names, units, users, databases, state directories, and GC-root directories are all disjoint between the two stacks by construction, which the mapping audit confirmed row by row.
What is genuinely shared is finite: 32 GiB of memory against buildbot's four eval workers at 2 GiB each, one nix store under a 250 G ZFS quota with a `min-free`/`max-free` reaper and a 7-day GC window, one nginx, one PostgreSQL, one ACME account, and the same `/nix/var/nix/builds` sandbox tree that a June 2026 disk incident already taught this fleet about.
So the change sizes nixbot's eval workers and build systems deliberately rather than accepting defaults derived from core count (`nixbot/nixosModules/nixbot.nix:271-287`).

## Q10 [decided]: what about `buildbot-nix.toml`?

Taken: leave it exactly as it is.

The expectation going in was that everything carries over except artifacts like `buildbot-nix.toml`.
That is refuted in its one named instance: the file is upstream buildbot-nix's own per-repository convention (`buildbot-nix/README.md:169-171`), vanixiets carries one at its root, and nixbot deliberately still parses that filename with the same schema plus a `build_branches` key (`nixbot/nixbot/nixbot/repo_config.py:14-15, 33-38`).
Nothing needs renaming; a `nixbot.toml` is optional and belongs to a later migration change.

## Q11 [given]: what is out of scope?

Migrating vanixiets' own CI onto nixbot; migrating ironstar; finishing python-nix-template's migration, which never completed onto buildbot-nix and will retarget to nixbot; and retiring buildbot.
Each is its own later change, named in the proposal's context and nowhere else in this change's artifacts.

# Trade-offs accepted

Two services doing the same job on one host is duplicated capability and duplicated resource draw, accepted because the alternative — cutting over — is the thing this change deliberately does not do.

A second GitHub App is a second registration to keep track of and a second set of credentials to rotate, accepted because it is what keeps the incumbent's registration untouched.

A service that builds nothing is, on the day it lands, unexercised beyond its own health: it serves its UI, receives authenticated webhook deliveries, and holds an empty project list.
Accepted, because the first repository opted in is a reviewable step in a later change rather than a side effect of standing up infrastructure.

Keeping the `nixbot` check-name prefix means that when a repository is later opted in, its required-checks configuration must be edited deliberately for nixbot's verdicts to matter.
That is the cost of not silently inheriting the incumbent's authority, and it is the right way round.
