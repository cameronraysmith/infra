---
title: nixbot evaluation throughput and magnetite storage audit, 2026-09-02
---

Two questions were asked together: why nixbot evaluations on magnetite collapsed from a 9m41s baseline to 44-55 minutes, and whether magnetite's store, ZFS datasets and garbage collection have behaved since the storage tuning of roughly two months ago.
They turn out to be independent.
The storage stack is healthy and is not implicated; the evaluation slowdown lives in substituter round trips reaching the evaluator through the nix daemon.
Everything below separates what was measured from what was inferred, and every host command was read-only: no service was started, stopped or reloaded, no check was cancelled, no garbage collection was run, no store path was deleted, and no ZFS property or snapshot was touched.

## The reported hypothesis is refuted

The reading under test was that buildbot-nix had been configured far more permissively about concurrent evaluators than the nixbot configuration that replaced it, and that the right knobs had neither been found nor dialled in.
Read against both upstream sources, that is not what happened.
buildbot-nix serializes evaluation globally with `util.MasterLock("nix-eval")` in `buildbot_nix/__init__.py`, consumed at `nix_eval.py`, and nixbot serializes it with `eval_concurrency: int = 1` in `nixbot/config.py`, enforced as an `asyncio.Semaphore` in `orchestrator.py`.
Both permit exactly one evaluation at a time, and they always did.
On the one dial where the two differ, the migration went the more permissive way rather than the less: buildbot-nix ran `evalWorkerCount = 4` and nixbot now runs 6, raised in PR 2869 (merged 2026-08-29T03:16Z) precisely to shorten the serial chain.

There is also no knob left to turn, which matters more than the refutation.
At the pinned rev `660d7182`, nixbot's NixOS module builds its config JSON from a closed attrset that `ExecStart` consumes directly, with no freeform settings escape and no `evalConcurrency` or `evalTimeout` option; `eval_concurrency` and the 3600 second `eval_timeout` are therefore unreachable from this repository at any value.
`buildConcurrency` is unset and resolves to the CPU count, 16, so build concurrency is already saturating.
`evalWorkerCount` is already at the largest value whose memory cap stays enforceable: nixbot evaluates inside a cgroup capped at `evalMaxMemorySize x (evalWorkerCount + 1)`, so 6 workers at 2048 MiB cap the tree at 14 GiB against 17-20 GiB available, where 8 would imply 18 GiB.
A cap that cannot fire before the host itself exhausts is not a cap, and exceeding the cgroup is an `EvalOOMError`, which fails the pull request permanently with no retry.

The claim that two evaluations were in flight simultaneously is also refuted, by the service's own database.
Exactly one build row exists for head `e8b2ceb20` (build 184, created 00:11:39.816696+00), its status is `pending` and its `started_at` is `NULL`: it was queued behind the evaluation semaphore and never started.
Head `61b997f60` matches no build row at all.
A queued build's GitHub check run already reports `in_progress`, so queue time is indistinguishable from evaluation time from the outside, which is what made one waiting build look like a second running one.
The 50-minute run attributed to `9769a88d5` was queue wait behind the preceding evaluation, then supersession while still pending.

## What the evaluation is actually doing

Measured, on build 172 (PR 2908, 117 attributes, 490 seconds end to end).
The evaluation opens with a burst of roughly 75-90 seconds in which six `nix-eval-jobs` workers each hold 75-85% of a core, churning at about one worker lifetime per attribute.
Then the workers disappear entirely.
For the remaining 6.5-7 minutes the master process has zero children, sits in `unix_stream_read_generic` on the nix-daemon UNIX socket, takes about 48 reads per second, and its `voluntary_ctxt_switches` count is flat across samples 30 seconds apart, meaning the main thread is fully parked.
Child CPU accounting confirms the shape: 469.5 seconds of reaped child CPU all landed inside the first 75-90 seconds, after which CPU is near zero.
Roughly 85% of that healthy evaluation's wall clock is that single wait.

The daemon on the other end of the socket is not working either.
It idles at a few percent CPU while holding established TLS connections to the caches, and its journal over four hours contains zero `unable to download` lines, zero TLS errors, and no retry storms.
Host-wide during the slow window: load 1.11 across 16 CPUs, `vmstat wa=0` in every sample, 88-97% idle, ARC hit ratio 99% over 18 days, and no swap activity against a 30 GiB zram device.
The eval cgroup sat at 272 MiB of its 14336 MiB cap with `oom_kill=0`.

Attribute count is not the variable.
The `build_attributes` table records 117 attributes for builds 161 through 172 and 176 alike, and those same 117 attributes produced evaluations of roughly 200 seconds and of 3312 seconds.
Build 168 (PR 2904) is the worst case and it did not merely run slowly: it was killed at nixbot's hard 3600 second `eval_timeout`, recorded verbatim as `"msg": "evaluation failed", "build_id": 168, "error": "evaluation timed out after 3600 seconds"`, which is a permanent failure with no retry.

The mechanism connecting these is `--check-cache-status`, which nixbot hard-codes in its `nix-eval-jobs` invocation alongside `--option eval-cache false` and `--force-recurse`.
Every evaluated attribute's closure must be resolved against the configured substituters before the evaluation can finish, and there are nine of them.
The evaluator cannot reach the network itself: `nixbot.service` sets `RestrictAddressFamilies=AF_UNIX` and runs `nix-eval-jobs` under bwrap, so every substituter byte flows through the daemon over the socket the master is parked on.

Latency was measured with curl from magnetite against all nine endpoints, medians of three, for a hash that exists and a hash that cannot.
Miss totals: cache.nixos.org 145 ms, nix-community.cachix.org 169, cache.numtide.com 128, cache.clan.lol 92, pyproject-nix.cachix.org 158, catppuccin.cachix.org 155, cuda-maintainers.cachix.org 173, cache.scientistexperience.net 74, cameronraysmith.cachix.org 181.
Those sum to roughly 1.27 seconds of serial-equivalent latency for a single path absent from every cache.
The cost is round trips rather than connection setup: connect is uniformly 7-9 ms and the TLS handshake 22-57 ms, and keep-alive reuse demonstrably works, with a warm hit on a reused connection costing 5.6-6.3 ms against 33.7 ms cold.
The specific network hypothesis of broken connection reuse is therefore refuted too: the CLOSE-WAIT count at measurement was 1, not a pileup, and the cachix-family 404s carry 100-150 ms of server think time behind Cloudflare rather than any handshake cost.

## The change that shipped, and what it does not fix

Since no nixbot-level concurrency dial is both available and safe, the change raises the daemon's ceiling on concurrent cache round trips, in `modules/machines/nixos/magnetite/default.nix` beside the existing host-level nix tuning.
`http-connections` goes from its default 25 to 100, bounded by file descriptors and outbound sockets.
`max-substitution-jobs` goes from its default 16 to 32, bounded by CPU for decompression and by network for the transfers.
Both oversubscribe the 16 cores on purpose, because the work they bound is latency-bound rather than CPU-bound, which is what an idle host blocked on cache round trips demonstrates.
Neither is bounded by RAM: they apply to `nix-daemon.service`, outside the eval cgroup whose 14 GiB cap is the one ceiling that must stay enforceable, and 100 curl handles cost single-digit MiB against 20 GiB available.
`http-connections` is the dial the measurement shows binding; `max-substitution-jobs` is build-side and is not measured as binding, and is raised only because it was an untuned default on the same latency-bound path.

Whether this alone restores the 9m41s baseline cannot be determined from what was measured, and the honest answer is that it is unlikely to do so by itself.
The measured park phase accounts for 85% of a healthy 8-minute evaluation, and raising the round-trip ceiling should compress that phase directly.
It does not explain the multiplier that turns a 200 second evaluation into a 3312 second one at identical attribute count.
No slow evaluation was live during measurement, so the split of a 3312 second run into burst and park was never observed, and the per-evaluation query count could not be counted because the `eval-gcroots` directories for builds 168, 171, 172 and 173 are cleaned after each build.
Two candidate multipliers remain untested: closure-scale path fan-out of order 10^4 to 10^5 lookups, and evaluation-CPU variance on those particular branches, where a longer burst rather than a longer park would be the signature.
Distinguishing them needs a 15 minute strace and socket capture during one live slow evaluation, which is the next measurement to take rather than a thing to guess at now.

Storage is not implicated, and that conclusion is firm rather than provisional: no storage resource was near a limit, IO wait was zero throughout, and no maintenance window overlaps the slow evaluation.

## Storage and garbage collection audit

Magnetite is a Hetzner CX53 KVM guest with 16 EPYC-Rome vCPUs and 30.6 GiB RAM (`MemTotal 32091048 kB`), 20 GiB available at measurement, plus a 30 GiB zram swap device carrying 2.2 GiB with no active paging.
The pool `zroot` is single-disk, 304G, 24% allocated, 46% fragmented, ONLINE, with a scrub that repaired 0B with 0 errors on 2026-09-01.
`zroot/root/nix` holds 62.8G compressed and 127G logical at compressratio 2.06x under a 250G quota, with 187G available and zero snapshots.
The store contains 112779 paths by `nix path-info --all | wc -l`, `/nix/var/nix/builds` is empty, and `/nix/var/nix/gcroots` holds 5 entries.
`zroot/root/nixos` carries a 10G reservation and `zroot/root/home` a 4G reservation, both live.
Compression is lz4 fleet-wide with a 128K recordsize.
Snapshots total 32 across four datasets at about 309 MiB of unique space, decomposing exactly as 4 hourly, 3 daily and 1 weekly per dataset, with none on nix, docker or podman.
ARC sits at 5.07 GiB of a 29.6 GiB `c_max` with a 99.0% hit ratio, and no `zfs_arc_max` tuning exists anywhere in the repository.
Nothing approaches any limit.

The storage tuning cluster is late May with a June 10 incident-response pair, which at 12 weeks is the closest thing to the remembered "two months ago".
`9bfc0c959` (2026-04-05) laid down the disko layout, pool and datasets.
`cc1921d67` and `0425a32e7` (2026-04-09) added zram swap.
`d5b7bf117` (2026-05-24) set `com.sun:auto-snapshot=false` on `root/nix`, `b19f746a2` (2026-05-24) set retention to frequent 0, hourly 4, daily 3, weekly 1, monthly 0, and `a0d5f6450` (2026-05-24) set min-free 5G and max-free 20G.
`220b8a6ba` and `7051ee95a` (2026-05-25) added boot-time oneshots asserting the snapshot opt-outs.
The two incident commits are the important ones: `aca5c708b` (2026-06-10) imposed `quota=250G` on `root/nix` with 10G and 4G reservations, in response to `/nix` consuming the entire 304G pool, and `e456caf62` (2026-06-10) raised min-free to 30G and max-free to 80G, forced `nix.gc.options` to `--delete-older-than 7d`, and added a tmpfiles rule reaping `/nix/var/nix/builds` at 1 day after an ENOSPC crash loop orphaned 201 sandboxes and 232 GiB.

Garbage collection and cache management have worked, and the evidence is timer and journal history rather than declared configuration.
`nix-gc` and `nix-optimise` each fired and finished successfully on 63 of 63 retained journal days, 2026-07-01 through 2026-09-01, with real frees each run: 29.6 GiB on Jul 20, 76.5 GiB across 56404 paths on Aug 3, 0 on Aug 23, 44.2 GiB on Aug 26, and 21.7 GiB across 24086 paths on Sep 1, alongside daily hardlink savings of 12.4 to 31.1 GiB (14.3 GiB currently).
`niks3-gc` ran the night before the audit and completed successfully, deleting 431 old closures and 30719 objects with zero failures.
All six ZFS assert and enforce oneshots report active, the 1-day builds reaper holds, monthly scrub and weekly zpool-trim are current, and no declared timer has failed or never fired.
The one evidentiary boundary worth naming: the journal's retained window begins 2026-07-01, so firing between June 10 and June 30 cannot be proven from it.
With `Persistent=true`, 63 of 63 days since, and correct current state, there is no positive evidence of a gap either; this is a limit on the evidence rather than a suspected failure.

Declared intent matches measured reality on every axis checked, including the 250G quota, both reservations, the snapshot opt-outs and their exact retention counts, the 30G and 80G thresholds in the live `nix.conf`, the 7 day retention, and the empty builds directory.
The split of `nix.optimise.automatic = true` against `auto-optimise-store = false` is intended rather than a defect: optimisation is batched nightly rather than paid per build.
No storage or garbage-collection change is warranted; every mechanism is functioning and the store sits at roughly a quarter of its quota.

Three items are recorded as unapplied recommendations.
First, magnetite's effective `substituters` list contains `cache.nixos.org` twice, once as configured and once as `https://cache.nixos.org/` contributed by the nixpkgs default, because `nix.settings.substituters` has a list type and list options merge by concatenation across modules.
If nix does not normalise the two forms to one store, every all-miss path pays a redundant round trip of about 145 ms, roughly 11% of the nine-endpoint fan-out; whether it normalises was not established, and `lib/caches.nix` is shared by the nixos, darwin and `flake.nix` `nixConfig` consumers, so this wants confirming before editing a cross-cutting file.
Second, the pending nixbot input bump to `660d7182` carries nix 2.35.2 with the `srcToStore` evaluation-performance patch (NixOS/nix#16190) and a prefetch-input deduplication patch (nixbot #153); the running service predates the pin and has not restarted since 2026-08-29, so deploying it requires a deliberate restart that was out of bounds during this work.
Third, if a hard memory reserve for concurrent evaluation is ever wanted, the lever is `boot.kernelParams = [ "zfs.zfs_arc_max=17179869184" ]` for a 16 GiB ARC cap, bounded by 30.6 GiB total RAM against a current 5.07 GiB of ARC use; it is not recommended now, since ARC is reclaimable under pressure, is not binding at a 99% hit ratio, and capping it could only hurt exactly the metadata reads this workload depends on.
