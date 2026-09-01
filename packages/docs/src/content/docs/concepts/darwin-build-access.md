---
title: Darwin build access
description: How the fleet reaches stibnite's aarch64-darwin store, and why the remote builder and the remote store are two mechanisms rather than one
sidebar:
  order: 9
---

Nix evaluation is portable and nix building is not.
Magnetite, which carries both CI services, is x86_64-linux, so it can evaluate an aarch64-darwin derivation and cannot build one.
Stibnite is the fleet's only aarch64-darwin machine, and until `modules/system/stibnite-access.nix` nothing declared it as a build target: the only `nix.buildMachines` entries anywhere named the rosetta VM and magnetite, both of them Linux.
Darwin derivations therefore had no build target at all, which is a different condition from having a slow one.

## Two mechanisms, two callers

The two ways to reach another machine's store are not interchangeable, and treating one as a synonym for the other is the mistake this page exists to prevent.

A remote builder is `nix.buildMachines` on the caller, or `--builders` on one invocation.
The caller's nix daemon copies the input closure out to stibnite, builds there, and copies the output closure back, so the result exists in the *caller's* store.
That is what a caller wants when the verdict is wanted locally: a CI service that will sign the output and push it to the binary cache, or an operator on magnetite who feeds the result to a later local step.

A remote store build is `--store ssh-ng://…`, or `--eval-store` for the mirror-image split.
Evaluation stays with the caller and the entire build happens inside stibnite's store: the derivation and its source inputs are copied to stibnite, while the output closure is not copied back.
That is what a caller wants when its own store is empty and stays empty — an ephemeral CI runner, a fresh container, an installer image — where a remote builder would spend the job populating a store that is about to be discarded.
Nothing lands locally, so a caller that needs the output path locally wants the builder instead.

| | Remote builder | Remote store |
|---|---|---|
| Configured as | `services.stibnite-builder.buildMachines`, spliced into `nix.buildMachines` | `services.stibnite-builder.storeUri`, written to `/etc/nix/stibnite-store-uri` |
| Evaluation | caller | caller |
| Build | stibnite | stibnite |
| Output closure | copied back to the caller | stays in stibnite's store |
| Intended caller | a developer or operator who needs an aarch64-darwin result locally, such as building or testing Darwin configurations from magnetite | a machine whose store is empty and stays empty |

Both mechanisms speak `ssh-ng` to the same account through the same ssh alias, which is what the `stibnite-access-wiring` check pins.
Legacy `ssh://`, which would run `nix-store --serve` on the far side, is deliberately not served.

## What the builder entry claims, and why

`systems` is `aarch64-darwin` alone.
`nix config show extra-platforms` on stibnite reports `aarch64-darwin` and nothing else, so advertising `x86_64-darwin` would route derivations the machine refuses to build.

`maxJobs` is 4.
Stibnite has 18 logical cores, 12 performance and 6 efficiency, and 64 GiB of memory, and it is also a laptop in interactive use that commits 12 cores and 48 GiB to the rosetta builder VM and the same again to colima when either runs.
The remote share is deliberately a minority of the machine.

`speedFactor` is 1 and is inert.
Nix compares speed factors only among machines that can build the same system, and there is no second aarch64-darwin machine to compare against.

`supportedFeatures` is `apple-virt` and `big-parallel`.
Both are real on this hardware.
`benchmark` is dropped because timings taken on a laptop under interactive load are not measurements, and `nixos-test` is dropped because it is a Linux sandbox capability that nix lists unconditionally.

## Two keys, two authorizations

The build and session keys are separately authorized so they can be revoked or rotated independently.

Magnetite generates both keypairs as `clan.core.vars` generators, `stibnite-nix-build` and `stibnite-agent-session`.
No plaintext private key material is committed.
Each private half is committed age/SOPS-encrypted under `vars/per-machine/magnetite/` and is decryptable only by magnetite and the authorized users recorded beside it.
The public halves are committed under the same path, and stibnite's configuration reads them at evaluation time.

The build key is authorized on `nixbuild`, a non-admin account on stibnite that exists only to serve the build protocol.
Its authorized-keys entry carries `restrict` and a forced command of `nix-daemon --stdio`, which restricts the key to starting that program with no pty, forwarding, shell, or other command.
The forced command does not bound the nix daemon's authority.
`nixbuild` deliberately belongs to Nix's `trusted-users` because an untrusted account cannot receive unsigned store paths that a caller evaluated itself.
That membership is store-root-equivalent on stibnite: the account can cause arbitrary paths to enter the store and influence what the daemon trusts.

The session key is the broader credential: it authorizes an ordinary login as `crs58`, an admin-group member who is already a Nix trusted user through `@admin`.
It therefore includes build authority plus shell access, while giving automated sessions an identity that can be revoked or rotated independently of the human's keys and the build key.

The `stibnite-access-wiring` check asserts the separation in both directions: the session key does not appear in the build account's authorized keys, the build key does not appear in the session account's, and the build key's line is exactly its forced command plus the key.

## What an operator must do

Two steps are the operator's.

Run `clan vars generate magnetite` when either keypair is rotated or first created, and commit the resulting encrypted private half and public value under `vars/per-machine/magnetite/`.
Stibnite's authorization reads those values at evaluation time, so an ungenerated key is an evaluation failure rather than a silent grant.

Activate both ends: `clan machines update magnetite` for the builder entry, the ssh alias and the store URI, and `just activate` on stibnite for the account and its authorization.
Stibnite's activation also adds `nixbuild` to macOS's `com.apple.access_ssh` service ACL, which on this machine nests only the admin group; without that the build account is refused by sshd before the key is ever consulted, and the failure reads as `Permission denied (publickey)` with a correct key installed.
Creating a macOS account requires Full Disk Access when `darwin-rebuild` runs over ssh, so the first activation carrying this change should run in a graphical session on the machine.

## What is deliberately not enabled

`nixbot.toml` sets `attribute = "checks.x86_64-linux"`, which prevents CI from evaluating or requesting aarch64-darwin work and makes the builder unreachable from CI.
The configurations in `modules/nixos/nixbot.nix` and `modules/nixos/buildbot.nix` each set `buildSystems = [ "x86_64-linux" ]` as an independent second layer.
These controls remain because stibnite is a laptop without guaranteed availability and a sleeping machine could gate CI.

## Related

- [Build service topology](/concepts/build-service-topology/) — the two CI services kept separate from this development builder
- [Clan Integration](/concepts/clan-integration/) — how `clan machines update` deploys these ends
- [Secrets management](/guides/secrets-management/) — how `clan.core.vars` credentials reach a service
