# Atomic workflows

Workflows in this directory are executed by `@bastani/atomic` (`/workflow <name>`).
Only top-level `.ts` files here are discovered; `runs/` holds per-run artifacts and is git-ignored.

## `bump-atomic-derivation.ts`

### The bump is easy to get subtly wrong

Moving `pkgs/by-name/atomic/` to a new upstream Atomic release is mechanically easy and easy to get subtly wrong.
A second pin somewhere else in the tree keeps the old version, a hash gets copied instead of regenerated, or the change lands on top of the wrong thing.
The work is not hard enough to need a human for every step and not safe enough to run unattended.
The workflow's job is therefore **to make each way the bump can be wrong falsifiable by something other than a model's own report of its work.**

That framing came from a defect rather than from theory.
The first run of this workflow returned `status: "completed"` and `landed: true` while its land stage had explicitly reported that it had created nothing.
The output was a hardcoded literal in the `run` return, so it was structurally incapable of disagreeing with reality.
Everything below is organised around not being able to do that again.

### An assertion must be derived from a tool observation

**An output that asserts something happened must be derived from a tool node's observation of the world.**
In the code this is the `Witness<T>` type: it is branded, `witness()` is its only constructor, and `witness()` only accepts a `ctx.tool` outcome.
`completedRun()`, the only way to build the success result, takes `landed` as a `Witness<boolean>` rather than a boolean, so the completion path cannot be reached by typing `true`.
The type is deliberately about twenty lines and knows nothing about this workflow; it is a seam, not a framework.

Negative claims (`landed: false` on a blocked exit) need no witness.
Asserting that nothing happened, when nothing happened, is the safe direction of the error.

### Stages, and what each gate falsifies

`resolve-release` (tool) falsifies "the target release exists".
A run that would otherwise spend forty-five minutes discovering that `0.9.18` was never published stops in a few seconds against the npm registry and the GitHub tag.

`map-derivation` (stage, schema-backed) falsifies "we know what to change and what covers it".
Its prose artifact is for humans and later stages; its `schema` returns the machine-usable part: the system double and the flake attributes that actually build or check this package.
`schema` and `output` compose, so the structured value arrives as `result.structured` while the ordinary text of that same message becomes the artifact.

The structured value is validated before use (`validateGateAttrs`) for shape, non-emptiness, and shell-safety, and the run stops blocked if it does not hold up.
Before that validation existed, the attributes were prose that nothing parsed and the gate built a hardcoded `.#atomic`, so recon could name three attributes and the gate would still check one.
A gate over the wrong attributes is green for the same reason an unrun gate is green, which is the same provenance failure as `landed: true` one layer up.

`apply-bump` (stage) is not a gate.
It is the only stage allowed to write to the derivation, and it is told to prefer the repository's own update mechanism and never to hand-write a hash it did not observe.

`build-gate-N` (tool) falsifies "this actually builds".
It runs a single `nix build --no-link --log-format internal-json -v <attrs…>` over every attribute recon enumerated.
This is the gate the rest of the run rests on: a real build, run by workflow code rather than by a model reporting on itself, with its exit status read directly.

`repair-N` (stage) makes the failed build the next task rather than the end of the run, bounded by `max_repair_attempts`.
It is given the log path and told to search it, not read it.
It is explicitly forbidden from narrowing the attribute set or weakening a check, because the failure mode being guarded against is a model making the gate agree with the code instead of the other way round.

`review` (stage, schema-backed) falsifies "green means correct".
A green build cannot see a stale second pin, a copied hash, or a check that was quietly disabled.
The stage therefore runs on a different model in a fresh context, is told it did not write the change, and must produce evidence per finding.
It is also asked to check that the gate's attributes cover the package, since the reviewer is the only thing that can catch recon having enumerated a plausible but wrong gate.

`address-review` and its confirming gate (stage, tool) falsify "the fix did not break the build".
Any repair after review re-runs the same gate.

Human confirmation (`ctx.ui.confirm`) keeps history from being touched without a person.
Declining is a *completed* run with `landed: false`, not a failure.

`capture-land-topology` (tool) is not a gate on the bump.
It takes the baseline the land verification is measured against: the change id of `@` and the set of change ids one hop from it.
If that baseline cannot be read, the run stops blocked before touching history, because without it nothing afterwards could be verified, and an unverifiable land is exactly what this workflow exists to prevent.

`land` (stage) is constrained by the fact that `@` here is a multi-parent development join that other sessions coordinate through.
`@` must not move; the squash must be path-scoped; the change is created with an explicit `jj new --no-edit -B @` so that the change the stage makes and the change the verifier looks for have the same topology.
It also receives the successful build log through `reads`.
On the failing run the land stage refused to act partly because its fresh context had no way to see that anything had been built, and concluded "nobody has built it".

`verify-land` (tool) falsifies "a change was landed, and only the bump was landed".
It re-reads the change graph and asserts, from real `jj` output, that (1) `@`'s change id is unchanged, (2) exactly one change id adjacent to `@` is new, and (3) that change's diff touches only `pkgs/by-name/atomic/`.
The `landed` output is the conjunction of those three assertions, carried through a `Witness`.

Adjacency rather than the `@-` revset is the deliberate choice: `@` is a multi-parent join, so `@-` names a set, not "the change we just made".
Comparing adjacency sets before and after says exactly what was added without assuming how many parents `@` has.
The verifier tolerates changes *leaving* the adjacency set, because `jj new -B @` legitimately pushes `@`'s former parents one hop away.

### Stop and blocked conditions

The run stops blocked, neither failed nor completed, when:

- the release does not exist upstream;
- recon's structured attributes are missing or malformed;
- the build is still red after the repair budget;
- a post-review fix leaves it red;
- the pre-land change graph cannot be read; or
- `verify-land`'s assertions do not hold.

Every blocked exit carries `landed: false` and the evidence it was decided from, so the reason is inspectable without rerunning.

The run stops completed with `landed: false` in exactly one case: a human declined to land a verified bump.

### Known limits

- `internal-json` logs are for machines.
  `--log-format internal-json` keeps the build's full structured stream on disk, which is what makes surgical `rg` over a large log useful, but it makes the `tail` that re-enters model context much less readable than the previous `--print-build-logs`.
  The repair prompt compensates by naming the format and giving search patterns; a human tailing the log live will want `jq`.
- `verify-land` is a snapshot comparison, not a lock.
  Another session committing to an adjacent change between the baseline capture and the verification would show up as a second new adjacent change and block the run.
  That is the intended direction of failure, since a false block is recoverable and a false `landed: true` is what got us here, but it does mean the land phase assumes it is briefly the only writer.
- The landed change may only touch `pkgs/by-name/atomic/`.
  That is what `verify-land` asserts, so a release whose bump also has to change a pin elsewhere in the tree cannot be landed as one change here.
  The land stage is told to leave the outside file in the working copy and report it, and a human decides where it belongs.
  Widening the assertion to "whatever recon listed" would make the check depend on the same enumeration it is supposed to be independent of.
- The gate trusts recon's enumeration.
  Validation checks that the attributes are well-formed and non-empty, not that they are the *right* attributes; only the review stage can catch a plausible but incomplete list.
- Model identifiers are pinned in the file and drift with the provider catalogue.
  `anthropic/claude-fable-5-1:medium` is the recon primary and is present in the catalogue, but the first-party anthropic route rejects this client's reported version (HTTP 400, `Claude Code 2.1.75 does not support this model`).
  The fallback chain therefore leads with `openrouter/anthropic/claude-fable-5.1:medium`, the same model by a route without that gate, before falling back to a different family.
  A single failing route is not evidence that a model is unavailable, and the earlier revision of this file wrongly recorded it as such.
- The workflow never pushes, never touches a bookmark, and never runs `nix flake check`.
  Landing means one local `jj` change and nothing more.

### Deviation: the build gate does not go through `just`

The gate runs `nix build` directly instead of a `just` recipe, which is against this repository's usual habit of routing commands through the justfile.
Two concrete reasons, both checked rather than assumed:

- `just build` depends on `lint check`, which runs `prek run --all-files` and a whole `nix flake check`, and it hardcodes `--print-build-logs`.
  A gate that must run several times inside a repair loop cannot pay for the entire check surface each round, and it cannot forward the log-format flag the loop depends on.
- `just check-fast` builds *all* checks and cannot forward flags either.

These two commands are not duplicated routing.
`just check-fast` is the broad operator a human runs before a PR: everything, no arguments, one answer.
The gate here is the narrow operator inside a repair loop: exactly the attributes recon enumerated for one package, in a machine-readable format, run repeatedly.
Collapsing them into one recipe would either make the pre-PR check too narrow or the repair loop too slow.
If a `just` recipe is ever added that takes attributes and a log format as arguments, this gate should move onto it.

### The graph has no fixed shape to draw

The graph is materialized while `run(ctx)` executes: the repair rounds are a bounded loop, the review-repair stage is conditional, and the land phase depends on a human answer.
A hand-drawn picture of that would be a snapshot of one possible run that stops being true the first time someone edits the control flow, so read the run body, or attach to a live run's graph overlay.
