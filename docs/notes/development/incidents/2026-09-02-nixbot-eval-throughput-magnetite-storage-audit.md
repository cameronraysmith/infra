---
title: nixbot evaluation throughput, check-set cost and magnetite storage audit, 2026-09-02
---

Three questions were asked, and the answer separates into three independent findings with three different owners.
Stating them as one story would be wrong, because only the first is a code change, and the other two are an accepted architectural constraint and a policy choice respectively.

The first is per-evaluation cost: the evaluator spends most of its wall clock parked on the nix-daemon socket while every attribute's closure is resolved against nine substituters.
That is what the accompanying `nix.settings` change addresses, and it is the only one of the three that is a configuration change.

The second is global serialization: both build services evaluate one pull request at a time by design, and no safe knob exists to change that at our pinned revision.
This is accepted as architectural and is not tuned.

The third is queue load: a serial evaluator behind a standing queue of automated dependency and flake-input pull requests produces the observed wall clock arithmetically, and the lever there is policy rather than configuration.

A fourth section answers the separate storage question, and a fifth prices this repository's own check set, which is the input that makes the third finding expensive rather than merely slow.
Everything below separates what was measured from what was inferred.

## Boundaries observed, and one breach to disclose

No service was restarted, reloaded or stopped, no check was cancelled, no garbage collection was run, no store path was deleted, and no ZFS property or snapshot was touched.
kanidm, gitea and operator-facing network configuration were not touched.

One constraint was breached and is reported rather than omitted.
The check-set enumeration initially forced every check value to weak head normal form in order to mirror `--force-recurse`, which triggered import-from-derivation, and this workstation's nix configuration delegates builds to `ssh-ng://builder@magnetite`.
For roughly four minutes, about ten small derivations (cilium CRD YAML conversions) were built on magnetite and copied back before the process was killed and every subsequent invocation pinned `--option builders ''`.
That is host contact the investigation was told not to make.
It mutated no service state, cancelled nothing, and ran no store-wide operation, but it did consume a few minutes of the machine the operator was waiting on, and the honest accounting is that the measurement was obtained partly at that cost.

## Finding one: per-evaluation cost is substituter fan-out through the daemon

Measured on build 172 (PR 2908, 117 attributes, 490 seconds end to end).
The evaluation opens with a burst of roughly 75-90 seconds in which six `nix-eval-jobs` workers each hold 75-85% of a core.
Then the workers disappear entirely.
For the remaining 6.5-7 minutes the master has zero children, sits in `unix_stream_read_generic` on the nix-daemon UNIX socket, takes about 48 reads per second, and its `voluntary_ctxt_switches` count is flat across samples 30 seconds apart, meaning the main thread is fully parked.
Child CPU accounting confirms the shape: all 469.5 seconds of reaped child CPU landed inside the opening burst.
Roughly 85% of that evaluation's wall clock is that single wait.

Two readings that had been taken as evidence against any cause existing are reconciled by this rather than contradicted.
Sampling the evaluator processes for established connections finds zero, which is correct and uninformative: `nixbot.service` sets `RestrictAddressFamilies=AF_UNIX` and wraps `nix-eval-jobs` in bwrap, so the evaluator cannot hold a socket at all, and every substituter connection belongs to nix-daemon, a third process in neither sample, where eight established TLS connections to the caches were found.
A master blocked in a socket read with zero children is likewise invisible to a load-average reading, which is exactly why six configured workers presented as one busy core.

The mechanism is `--check-cache-status`, which nixbot hard-codes alongside `--option eval-cache false` and `--force-recurse`.
Every evaluated attribute's closure must be resolved against the configured substituters before the evaluation can finish, and there are nine of them.
Latency was measured with curl from magnetite against all nine, medians of three, for a hash that exists and a hash that cannot.
Miss totals: cache.nixos.org 145 ms, nix-community.cachix.org 169, cache.numtide.com 128, cache.clan.lol 92, pyproject-nix.cachix.org 158, catppuccin.cachix.org 155, cuda-maintainers.cachix.org 173, cache.scientistexperience.net 74, cameronraysmith.cachix.org 181.
Those sum to roughly 1.27 seconds of serial-equivalent latency for a single path absent from every cache.
The cost is round trips rather than connection setup: connect is uniformly 7-9 ms and the TLS handshake 22-57 ms, and keep-alive reuse demonstrably works, with a warm hit on a reused connection costing 5.6-6.3 ms against 33.7 ms cold.
The CLOSE-WAIT count at measurement was 1, and the daemon journal over four hours contains zero download errors and zero retries, so the poor-connection-reuse hypothesis is refuted alongside the naive one.

This also supplies the state dependence that a static command line could not explain.
Attribute count is not the swing variable: the `build_attributes` table records 117 attributes for builds 161 through 172 and 176 alike, and those same 117 attributes produced evaluations of roughly 200 seconds and of 3312 seconds.
What varies is how many of those paths are unknown to the daemon's narinfo cache, and `main` advancing under a branch converts warm paths into all-miss ones.

The memory-kill line is ruled out, using the service's own semantics rather than an absence of evidence.
Exceeding the eval cgroup raises `EvalOOMError` and fails the pull request; PR 2890's check did not fail while this was investigated, so the cap was not firing, and the cgroup showed 272 MiB of its 14336 MiB with `oom_kill=0` and no memory-kill or worker-restart lines in the journal.

## Finding two: global serialization is architectural and is not tuned

The reading under test was that buildbot-nix had been configured far more permissively about concurrent evaluators than nixbot.
It was not.
buildbot-nix serializes evaluation globally with `util.MasterLock("nix-eval")` in `buildbot_nix/__init__.py`, consumed at its `nix_eval.py`, and nixbot serializes it with `eval_concurrency: int = 1` in `nixbot/config.py`, enforced as an `asyncio.Semaphore` in `orchestrator.py`.
Both permit exactly one evaluation at a time and always did.
On the one dial where the two differ the migration went the more permissive way rather than the less: buildbot-nix ran `evalWorkerCount = 4` and nixbot now runs 6, raised in PR 2869 (merged 2026-08-29T03:16Z) precisely to shorten the serial chain.

There is also no knob left to turn, which matters more than the refutation.
At the pinned rev `660d7182`, nixbot's NixOS module builds its config JSON from a closed attrset that `ExecStart` consumes directly, with no freeform settings escape and no `evalConcurrency` or `evalTimeout` option, so `eval_concurrency` and the 3600 second `eval_timeout` are unreachable from this repository at any value.
`buildConcurrency` is unset and resolves to the CPU count, 16.
`evalWorkerCount` is already at the largest value whose memory cap stays enforceable, because nixbot evaluates inside a cgroup capped at `evalMaxMemorySize x (evalWorkerCount + 1)`: 6 workers at 2048 MiB cap the tree at 14 GiB against 17-20 GiB available, where 8 would imply 18 GiB.
A cap that cannot fire before the host itself exhausts is not a cap, and the overrun it guards is a permanent unretried pull request failure.
Unpinning or patching the tool therefore buys a gain that ceiling caps anyway, wagered against the one failure mode declared unrecoverable.

An apparent second concurrent evaluation was also refuted, from the service's own database.
Exactly one build row exists for head `e8b2ceb20` (build 184, created 00:11:39.816696+00), its status is `pending` and its `started_at` is `NULL`: it was queued behind the semaphore and never started.
Head `61b997f60` matches no build row at all.
A queued build's GitHub check run already reports `in_progress`, so queue time is indistinguishable from evaluation time from the outside, which is what made one waiting build look like a second running one.

## Finding three: queue load, and the numbers for it

Measured: the `eval-gcroots` index on magnetite advanced from 171 at 01:15 to 186 at 02:00, which is fifteen distinct evaluations in forty-five minutes, each in its own sandbox, with gaps between them.
That is a throughput ceiling of roughly 180 seconds per evaluation, or about twenty evaluations per hour, and it is a sequence of separate runs rather than one run retried.

The queue feeding it is larger than the window suggested.
Measured at 02:10 via `gh-axi pr list --state open`: thirty open pull requests, of which twenty-three are bot-authored — seventeen from `app/vanixiets-flake-updater` (2891, 2892, 2895 through 2909) and six from `app/renovate` (2613, 2881, 2910 through 2913) — against seven human-authored (2747, 2772, 2777, 2878, 2890, 2893, 2914).
So the automated share is 23 of 30 rather than six of eight.

The arithmetic, with the working shown so the tradeoff is arithmetic rather than a feeling.
The measured inputs are a healthy evaluation at 490 seconds (build 172), a fast class at about 200 seconds (builds 173 and 176 at 203 and 201), a slow class at 3312 seconds (build 171) and a hard timeout at 3600 seconds (build 168), against an evaluator that runs exactly one evaluation at a time.

One full cycle of the automated set, meaning one evaluation for each of the twenty-three bot-authored pull requests:

    23 x 180 s =  4,140 s = 1 h 09 m   at the measured throughput mean
    23 x 200 s =  4,600 s = 1 h 17 m   at the fast class
    23 x 490 s = 11,270 s = 3 h 08 m   at build 172's healthy rate

One slow-class member displaces most of a cycle by itself.
Build 171's 3312 seconds is 55 minutes of the only evaluator, so substituting one slow member for one healthy member adds 3312 - 490 = 2,822 seconds, 47 minutes, to the cycle total.
Build 168 consumed the full 3600 second timeout and then failed permanently, spending an hour of the sole evaluator to produce no verdict at all.

A queue item is one evaluation per push rather than per pull request, which multiplies the depth above rather than adding to it.
PR 2890 alone was force-pushed four times tonight, and every push re-triggers.
The push multiplier was not measured for the bot population, so it is carried as a parameter rather than asserted, and the cycle cost at build 172's rate scales linearly in it:

    m = 1:  23 evaluations = 11,270 s =  3 h 08 m
    m = 2:  46 evaluations = 22,540 s =  6 h 16 m
    m = 4:  92 evaluations = 45,080 s = 12 h 31 m

The measured service rate bounds what the queue can absorb: fifteen evaluations in forty-five minutes is twenty per hour, so any arrival rate above twenty evaluations per hour grows the queue without bound rather than merely lengthening it.

Say plainly what this means for a person: at this depth a human pull request can wait behind hours of automated evaluation.
A human pull request arriving at the back of one full automated cycle waits 3 hours 8 minutes at the healthy rate before its own evaluation begins, and 6 hours 16 minutes if each of those pull requests is pushed twice.
That is the consequence that makes this worth deciding rather than absorbing, and it is why PR 2890's check sat in progress for a hundred minutes without its own evaluation ever being slow.

The three findings compound rather than merely coexist, and this is the part worth stating precisely.
A flake-input update is the maximally expensive input to finding one: bumping `nixpkgs` or `home-manager` invalidates the closure, which converts warm paths into all-miss paths, which is exactly the class costing ~1.27 seconds each.
So the twenty-three automated pull requests are not just numerous, they are each drawn from the expensive class, and they are metered through a queue that admits one at a time.
Seventeen of them are flake-input bumps by construction.

What batching would save, per cycle, on the same measured inputs.
Collapsing the flake updater's seventeen pull requests into one combined pull request replaces seventeen serial evaluations with one, taking the cycle from twenty-three evaluations to seven, the six dependency-bot pull requests plus the combined one:

    before: 23 x 490 s = 11,270 s = 3 h 08 m
    after:   7 x 490 s =  3,430 s = 0 h 57 m
    saved:  16 x 490 s =  7,840 s = 2 h 11 m per cycle, a 69.6% reduction

At the measured 180 second mean the same collapse saves 16 x 180 = 2,880 seconds, 48 minutes per cycle, and under a push multiplier the saving scales with it: 2 hours 11 minutes becomes 4 hours 21 minutes at m = 2.
Inferred, and worth stating because it makes batching cheaper than the eval count alone suggests: seventeen separate input bumps each independently invalidate overlapping regions of the 29,244-path union and each pays its own cold fan-out, whereas one combined bump pays that union once, so the saving on finding one's axis is larger than the 17-to-1 ratio in evaluation count.

The lever here is policy rather than configuration, so what follows are recommendations for whoever sets this repository's automation policy rather than decisions taken here.
Batching the flake-input updates into a single pull request buys the 2 hour 11 minute per-cycle saving above, at the cost of losing per-input bisection when an update breaks something.
Rate-limiting or scheduling whatever opens them spreads the load off the hours when humans are waiting, at the cost of slower dependency freshness.
Accepting the queue with eyes open is also a legitimate answer, given that the evaluator is doing real work rather than thrashing; it simply means a human pull request's check latency is set by the bot queue depth at the moment it lands, which should then not be read as a regression.

## Finding three's input: what this repository's own check set costs

This is the part in our hands rather than the tool's, and it was measured rather than counted.

`nix eval --json .#checks.x86_64-linux --apply 'builtins.attrNames'` returns exactly 117 names, matching the 117 attributes nixbot recorded for builds 161 through 172 and 176.
The match holds across different branches, which strengthens rather than weakens it: 117 is the count both locally and on the service.
Every emitter in `modules/checks/` binds flat derivations, so `--force-recurse` finds no nested attribute sets to descend into; this is inferred, because forcing values locally triggers the import-from-derivation described above.

The checks divide into four classes.
Eleven are FULL-ACT, meaning the check value *is* a complete configuration closure: six home-manager `activationPackage` bindings in `modules/checks/home.nix:38` for users cameron, christophersmith, crs58, janettesmith, raquel and tara, and five NixOS `config.system.build.toplevel` bindings in `modules/checks/machines.nix:32` for cinnabar, electrum, galena, magnetite and pyrite, with scheelite deliberately deferred.
Five are FULL-eval, forcing a complete configuration's option subtree while carrying a small closure of their own: `atomic-agent-environment-structural`, `pi-agent-environment-structural`, `pi-agent-environment-smoke`, `nixbot-wiring` and `stibnite-access-wiring`.
Twelve are MODULE, evaluating modules or attribute-set shapes without instantiating a configuration.
The remaining eighty-nine are CHEAP package, devshell, manifest and script checks.

Measured evaluation cost, warm, second of two runs, with `--option eval-cache false` to match nixbot's invocation.
`home-manager-crs58` takes 9.26 s wall and 2.38 GB of allocation across 20.4 M thunks; `nixos-magnetite` 10.78 s and 2.85 GB across 27.1 M thunks.
The FULL-eval checks cost 2.58-3.62 s, the MODULE and CHEAP checks 1.43-1.63 s, against a flake re-evaluation floor of about 1.45 s that every check pays because the eval cache is disabled.
So a FULL-ACT check adds roughly seven to nine seconds of evaluation over the floor, and a FULL-eval check one to two.

The decisive number is derivation-closure size, because that is what `--check-cache-status` fans out over.
Measured with `nix-store -q --requisites` on each instantiated derivation, 113 of 117 succeeded locally; the four `local-k3d` variants need x86_64-linux import-from-derivation and are unmeasurable on darwin, though nixbot evaluates them normally.
The five NixOS toplevels carry 20,065 to 22,170 paths each, and the six home activations 15,338 to 19,165.
Every `mkStructuralCheck` check carries 715.
Summed across the 113 measured checks the total is 362,816 paths, but the union of distinct paths is only 29,244, and the difference is exactly what the daemon's narinfo cache deduplicates within a run.
The union is the real fan-out ceiling and the sum overstates it.

The eleven FULL-ACT checks are 9.4% of the attributes and carry 207,698 of the 362,816 summed paths, 57.2%.
More to the point, 13,872 paths are reachable only through them: 47.4% of the entire deduplicated union.
At ~1.27 s per all-miss path, a fully cold evaluation of the whole union bounds at 29,244 x 1.27 ≈ 10.3 hours, which is not a real scenario but is the right ceiling; build 172's measured ~416 s of wait implies only a few hundred path-equivalents were actually unknown, the warm store serving the rest.
Removing the FULL-ACT bindings would cap that ceiling at 15,372 paths, a 47% reduction.
These counts are a lower bound on cold fan-out, because requisites of a derivation count derivation and source paths while `queryMissing` on a cold evaluator additionally asks about input-derivation outputs.

Configurations are also multiply re-evaluated, and no memoisation is possible.
crs58's home configuration is evaluated four separate times (`home-manager-crs58`, `atomic-agent-environment-structural`, `pi-agent-environment-structural`, `pi-agent-environment-smoke`) and magnetite's NixOS configuration three (`nixos-magnetite`, `nixbot-wiring`, `stibnite-access-wiring`).
`nix-eval-jobs` dispatches each attribute independently, so a `let`-bound shared evaluation collapses duplicates only within one check file, never across files or attributes; only reducing what is *bound* as a check reduces the fan-out.

On whether the FULL-class checks are reducible, the answer differs by class and both directions are stated plainly.
The eleven FULL-ACT checks assert that a closure builds, and no module-level evaluation can establish that, so they are genuinely full in kind.
They are reducible in *multiplicity* rather than in kind: the six home activations occupy only four distinct closure shapes (crs58 and cameron identical at 19,165; christophersmith, janettesmith and raquel identical at 15,342; tara at 15,338), so a canary per shape per pull request with the full set on scheduled or main-branch runs preserves build coverage at a fraction of the per-pull-request exposure.
The honest cost of dropping any is that the omitted user's activation is no longer cache-filled by the pull request run, which is that check's stated purpose, so this is a tradeoff rather than a free win.
The same verdict applies to the five NixOS toplevels.
The five FULL-eval checks should be kept as they are: they assert real cross-module wiring and real option values of the emitted configurations, they already carry 715 to 3,121 path closures rather than build closures, and substituting a minimal re-composition would assert a reconstruction instead of the deployed configuration, weakening fidelity to save one or two seconds.
`pi-agent-environment-smoke` genuinely needs its derivation because it runs the deployed wrapper over RPC.

The repository already contains the cheaper idiom, which is why this reads as an outlier rather than a design gap.
`hm-sops-bridge-assertion-neg` evaluates the bridge module through bare `lib.evalModules` without instantiating any configuration, and the `structure/*` checks compare attribute-set shapes against literals.
The activation and toplevel bindings were introduced deliberately, to close a silently-no-op build gap and to fill per-user caches, so the recommendation is about their multiplicity per pull request and not about deleting them.

PR 2890's `modules/checks/devin-worker.nix` deserves a correction on this axis.
It does contain two full home-manager evaluations, at lines 76-98 and 125-145, one probing `aarch64-darwin` and one `x86_64-linux`, proving platform routing and fan-out through home-manager's real option types, alongside nine `lib.evalModules` probe sites.
But they evaluate *minimal* configurations, a probe user against the devin module, not this repository's `homeConfigurations`, and the check serializes only names, counts and booleans.
On the closure-fan-out axis that makes it a cheap check, not a heavy one; its cost is CPU-side module evaluation priced near the module-level probes.
The follow-up item proposing a third such evaluation was not located: the pull request body, all seven branch commit messages, both comments, the openspec corpus on that branch, and the devin files' own markers were searched and none contains it.
The nearest hook is a comment at lines 288-302 anticipating pyrite and cinnabar as machines arriving next on the same user.
If that follow-up lives in Linear it is not reachable from here and a pointer would let it be quoted rather than guessed at.

## Storage and garbage collection: healthy, not implicated

Magnetite is a Hetzner CX53 KVM guest with 16 EPYC-Rome vCPUs and 30.6 GiB RAM (`MemTotal 32091048 kB`), 20 GiB available at measurement, plus a 30 GiB zram swap device carrying 2.2 GiB with no active paging.
The pool `zroot` is single-disk, 304G, 24% allocated, 46% fragmented, ONLINE, with a scrub that repaired 0B with 0 errors on 2026-09-01.
`zroot/root/nix` holds 62.8G compressed and 127G logical at compressratio 2.06x under a 250G quota, with 187G available and zero snapshots.
The store contains 112779 paths, `/nix/var/nix/builds` is empty, and `/nix/var/nix/gcroots` holds 5 entries.
`zroot/root/nixos` carries a live 10G reservation and `zroot/root/home` a live 4G reservation.
Snapshots total 32 across four datasets at about 309 MiB of unique space, decomposing exactly as 4 hourly, 3 daily and 1 weekly per dataset, with none on nix, docker or podman.
ARC sits at 5.07 GiB of a 29.6 GiB `c_max` with a 99.0% hit ratio, and no `zfs_arc_max` tuning exists anywhere in the repository.
Nothing approaches any limit, and `vmstat` reported `wa=0` in every sample with 88-97% idle.

The storage tuning cluster is late May with a June 10 incident-response pair, which at twelve weeks is the closest thing to the remembered "two months ago".
`9bfc0c959` (2026-04-05) laid down the disko layout, pool and datasets.
`cc1921d67` and `0425a32e7` (2026-04-09) added zram swap, and `816035109` and `46cdb00c9` the podman and docker datasets.
`d5b7bf117` (2026-05-24) set `com.sun:auto-snapshot=false` on `root/nix`, `b19f746a2` (2026-05-24) set retention to frequent 0, hourly 4, daily 3, weekly 1, monthly 0, and `a0d5f6450` (2026-05-24) set min-free 5G and max-free 20G.
`220b8a6ba` and `7051ee95a` (2026-05-25) added boot-time oneshots asserting the snapshot opt-outs.
The two incident commits are the important ones: `aca5c708b` (2026-06-10) imposed `quota=250G` on `root/nix` with 10G and 4G reservations after `/nix` consumed the entire 304G pool, and `e456caf62` (2026-06-10) raised min-free to 30G and max-free to 80G, forced `nix.gc.options` to `--delete-older-than 7d`, and added a tmpfiles rule reaping `/nix/var/nix/builds` at one day after an ENOSPC crash loop orphaned 201 sandboxes and 232 GiB.
Fleet defaults come from `modules/system/nix-optimization.nix` and `modules/system/zram-swap.nix`; magnetite overrides only retention and thresholds.

Garbage collection and cache management have worked, and the verdict rests on timer and journal history rather than on declared configuration.
`nix-gc` and `nix-optimise` each fired and finished successfully on 63 of 63 retained journal days, 2026-07-01 through 2026-09-01, with real frees each run: 29.6 GiB on Jul 20, 76.5 GiB across 56404 paths on Aug 3, 0 on Aug 23, 44.2 GiB on Aug 26, and 21.7 GiB across 24086 paths on Sep 1, alongside daily hardlink savings of 12.4 to 31.1 GiB, currently 14.3 GiB.
`niks3-gc` ran the night before the audit and completed successfully, deleting 431 old closures and 30719 objects with zero failures.
All six ZFS assert and enforce oneshots report active, the one-day builds reaper holds, and monthly scrub and weekly zpool-trim are current.
No declared timer has failed or never fired.
One evidentiary boundary is worth naming rather than papering over: the journal retains from 2026-07-01, so firing between June 10 and June 30 cannot be proven from it, and with `Persistent=true`, 63 of 63 days since, and correct current state there is no positive evidence of a gap either.

Declared intent matches measured reality on every axis checked, including the 250G quota, both reservations, the snapshot opt-outs and their exact retention counts, the 30G and 80G thresholds in the live `nix.conf`, the seven-day retention, and the empty builds directory.
The split of `nix.optimise.automatic = true` against `auto-optimise-store = false` is intended rather than a defect: optimisation is batched nightly rather than paid per build.
No storage or garbage-collection change is warranted.
Storage is not implicated in the slow evaluation, and that conclusion is firm rather than provisional: no storage resource was near a limit, IO wait was zero throughout, and the maintenance windows are disjoint from the slow evaluation window, with `nix-gc` at 08:00-08:20 UTC, `nix-optimise` at 03:45-04:55 UTC and `niks3-gc` at 00:07-00:09 UTC.

## Whether finding one alone restores the 9m41s baseline

It should compress the wait that is 85% of a healthy evaluation, and that is a real and measured effect rather than a hoped-for one.
It will not by itself return a pull request's check latency to 9m41s while twenty-three automated pull requests are queued in front of it, because that latency is queue depth times per-evaluation cost and the change addresses only the second factor.
The residual within a single evaluation is also not fully accounted for: no slow evaluation was live during measurement, the `eval-gcroots` directories are cleaned after each build so the per-evaluation query count could not be counted, and two candidate multipliers remain untested — closure-scale path fan-out of order 10^4 to 10^5 lookups, consistent with the 29,244-path union going cold on an input bump, and evaluation-CPU variance on those particular branches, whose signature would be a longer burst rather than a longer park.
Distinguishing them needs a fifteen-minute strace and socket capture during one live slow evaluation, which is the next measurement to take rather than a thing to decide now.

## Recommendations, unapplied

Reducing FULL-ACT multiplicity per pull request is the repository-side lever, at 47.4% of the deduplicated path union for 9.4% of the attributes; the four distinct home closure shapes and five host shapes admit a canary-per-shape arrangement with the full set on scheduled or main-branch runs, and the cost is per-user cache fill on pull request runs.

Batching the seventeen flake-input update pull requests is the policy-side lever, and it is the largest single saving available: collapsing them into one combined pull request takes an automated cycle from twenty-three serial evaluations to seven, saving 7,840 seconds, 2 hours 11 minutes, per cycle at build 172's measured rate, and more than that under any push multiplier above one.
The cost is losing per-input bisection when an update breaks something.
It matters because at the present depth a human pull request can wait behind hours of automated evaluation before its own evaluation begins.

Magnetite's effective `substituters` list contains `cache.nixos.org` twice, once as configured and once as `https://cache.nixos.org/` contributed by the nixpkgs default, because `nix.settings.substituters` has a list type and list options merge by concatenation across modules.
If nix does not normalise the two forms to one store, every all-miss path pays a redundant round trip of about 145 ms, roughly 11% of the nine-endpoint fan-out.
Whether it normalises was not established, and `lib/caches.nix` is shared by the nixos, darwin and `flake.nix` `nixConfig` consumers, so this wants confirming before editing a cross-cutting file.

The pending nixbot input bump to `660d7182` carries nix 2.35.2 with the `srcToStore` evaluation-performance patch (NixOS/nix#16190) and a prefetch-input deduplication patch (nixbot #153); the running service predates the pin and has not restarted since 2026-08-29, so deploying it requires a deliberate restart that was out of bounds here.

`modules/checks/machines.nix` carries a stale comment stating the deferred list is empty while it holds scheelite.

If a hard memory reserve for concurrent evaluation is ever wanted, the lever is `boot.kernelParams = [ "zfs.zfs_arc_max=17179869184" ]` for a 16 GiB ARC cap, bounded by 30.6 GiB total RAM against a current 5.07 GiB of ARC use.
It is not recommended now, since ARC is reclaimable under pressure, is not binding at a 99% hit ratio, and capping it could only hurt exactly the metadata reads this workload depends on.
