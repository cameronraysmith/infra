# Atomic workflows

Only top-level TypeScript files are discovered by Atomic's `/workflow <name>` command.
Helpers live in subdirectories; `runs/` is git-ignored and holds observations and stage artifacts.

## Bump derivation

`bump-derivation.ts` generalizes package bumps under `pkgs/by-name/<package>/` without letting a model invent hashes or declare its own work verified.
Inputs are required `package`, optional `target_version` (latest when omitted), `plan_only` (false), `max_repair_attempts` (2), and `build_timeout_minutes` (45).
In this jj repository, `splice_after` is required and identifies the change after which delivery changes are inserted.
The workflow never moves `@`, pushes, changes bookmarks, activates a system, or runs the whole flake check surface.
Do not run the workflow or package builds as part of slice A authoring; execution belongs to slice B.

`plan_only=true` resolves the release, maps and validates the derivation, writes the plan and observations, and returns before `run-updater`.
It makes no tracked-file edits and cannot reach landing.
Ignored artifacts under `.atomic/workflows/runs/bump-derivation/<package>/` are permitted even in plan-only mode.

## An assertion must be derived from a tool observation

**An output that asserts something happened must be derived from a tool node's observation of the world.**
The original Atomic-only workflow once reported `landed: true` while its land stage had explicitly created nothing.
A hardcoded success literal could not disagree with reality.

`Witness<T>` is branded, and `witness()` constructs it only from a tool outcome and a projection of its observation.
`completedRun()` requires both `landed: Witness<boolean>` and `changes: Witness<string[]>`; callers cannot substitute a boolean or a list of guessed identifiers.
The external outputs contain the witnessed boolean and list, preserving the original result fields while adding `package`, `changes`, `skill_deps_verified`, and `self_maintained_repaired`.
Blocked exits and deliberate plan-only or operator-declined exits assert no positive landing claim and carry `landed: false` and `changes: []`.
A tool witness is evidence of what that tool checked, not an end-to-end guarantee that the specification matched intent.

## The three ADTs

`bump/types.ts` declares TypeBox schemas and derives their TypeScript types.
Unrecognized structured constructors fail validation rather than falling through to a permissive default.
Every constructor switch has an exhaustive `never` default that blocks.

- `ReleaseSource`: `GitHubRelease { owner, repo, tagPrefix }` or `Npm { name }`.
- `Updater`: `PassthruScript { storePathOrRepoPath, acceptsVersionArg }`, `NixUpdate { flakeAttr }`, or `Manual`.
  Manual updating is blocked; a model never substitutes hand-written hashes.
  Latest-only scripts accept an omitted target or an explicitly latest target, but block a specific non-latest version.
  Explicit release lookup does not depend on latest metadata; only a discovered latest-only script triggers the additional latest check.
- `SkillDep`: `Vendored { deliveryExpr, upstreamSubtree, pinKind }` or `SelfMaintained { skillPath, dependsOn, citedClaims }`.
  `pinKind` distinguishes `SrcCarried`, `ApmGitDep`, and `NpmBundled`; `ApmGitDep` blocks as unsupported in slice C.
  Self-maintained dependencies name either the package or a vendored skill and cite claims with file, lines, text, and prior verification provenance.

The registry in `bump/packages.ts` contains `atomic` and `linear-cli` skill dependencies and their static release sources, not updater guesses.
Recon discovers the updater from the derivation and verifies registry facts against the tree.
Unknown packages use deterministic, read-only release-source discovery and recon; anything unclassifiable blocks.
Atomic's npm distribution carries its builtin skill trees under `dist/builtin`.
Linear's source carries `skills/linear-cli`, delivered through `${pkgs.linear-cli.src}/skills` in the user's home module.
Its local linear-project-management and openspec-linear-sync skills are self-maintained, not vendored.

## Stages and evidence

1. `resolve-release` observes the requested release or resolves latest from the classified source.
2. `map-derivation` returns a schema-backed manifest and a prose artifact.
   Validation covers the whole manifest: pins, release source, updater, skill dependencies and build attributes.
   Every pin records whether it must change.
   Version-keyed source and release-binary hashes must change; dependency-closure FOD hashes may remain identical only when their pin names a `witnessAttr` whose build realizes that FOD.
   Each such attribute must appear in `gateAttrs.attrs`, including cross-system attributes when required; missing witnesses block validation.
   Pin observations follow the named source binding, including nested Nix attribute paths such as `src.hash` and `binaries.aarch64-darwin.hash`, and JSON manifest properties such as `version`.
   Comments and other fields are not pin evidence; ambiguous or computed bindings block as unclassifiable rather than falling back to file-wide matching.
   Pin gates return each observed literal and its expected baseline predicate (`changed` or `build-witnessed`), with the named build attribute for closure hashes; the baseline is not an independently expected new hash.
3. `run-updater` runs the classified updater with the resolved target and checks the pin and derivation-path diff boundaries.
4. `build` runs exactly the enumerated attributes with bounded, uniquely named repair stages only after failed builds.
   The gate owns build execution and exit-code observations; a repair report is not a build witness.
5. `verify-vendored-delivery` compares a built source or package subtree with upstream at the release tag or npm tarball.
   Git archives read local upstream tags without checking out or modifying the upstream repository.
   Vendored content is never repaired locally.
   Each successful comparison records the upstream subtree, delivered path, compared file count and `identical: true`.
6. `revalidate-self-maintained` plans read-only help/source/skill probes for every claim, executes them through tools, and then re-attests or minimally repairs prose and documented checks within the union of self-maintained skill directories.
   Source probes read the built package's `.src` store path; exact-quote validation reads claim-indexed observation artifacts rather than raw text in checkpoints.
   Contradictions receive evidence-backed fail-closed repairs, including example checks that miss accepted upstream forms; claims without a supported repair block.
   Validated old/new claim pairs are written to `registry-updates.json` for subsequent registry catch-up, without expanding the bump's tracked edit scope.
7. `review` uses a fresh maximum-reasoning context to falsify the bump against diffs and named tool evidence, not the worker's report.
   The read-only reviewer has no shell: it uses compact receipts and targeted artifact excerpts, and reports insufficient evidence as a workflow finding rather than reconstructing it or asking the controller.
   Unapproved or malformed review results block landing.
8. `land` requires operator confirmation, captures topology, then creates one derivation change and, when prose changed, a second skill change.
   The commands are `jj new --no-edit -A <splice_after>` followed, for change2, by `jj new --no-edit -A <change1>`.
   Each receives only its own paths with `jj squash --from @ --into <change> --use-destination-message --keep-emptied -- <paths>`.
   Verification requires exactly the ordered new chain, allowed path sets, unchanged `@`, preserved former children below the last new change, and no allowed paths left in `@`.
   Unrelated leftovers are reported, never squashed.

Every model stage writes the model and reasoning level actually observed in stage-result metadata to the package ledger, including fallback attempts.
Missing actual-model metadata blocks instead of being replaced with requested model pins.
Role constraints, prohibitions, and identifiers are protected with `<keepContext>`; bulk evidence is passed through files and `reads`.
Process callbacks use finite deadlines and forward the tool cancellation signal.
Repairs are bounded forward-only iterations with distinct node names.

## Limits and operating assumptions

Recon's well-formed attribute list can still be incomplete; independent review must challenge its coverage.
Topology checks compare observations, not locks; another writer changing the splice segment can make verification block.
The workflow preserves unrelated working-copy paths rather than treating them as part of the bump.
Scope snapshots include Git-relevant executable/file modes and symlink targets as well as file bytes; unchanged foreign paths remain outside the delta.
A blocked run can leave a partially updated working copy; it reports the evidence and never claims a verified land.
Local upstream repositories and the requested tags must already be available for GitHub subtree comparisons; source probes use the built `.src` store path.

The build gate intentionally runs `nix build` directly rather than `just build` or `just check-fast`.
Those recipes cover a wider check surface and do not forward the selected attributes and log format needed by this bounded package loop.
The direct gate is the narrow repeated check; repository-wide checks remain the human pre-PR lane.
Process output is written to package-local `.log` files with companion `.log.stream.jsonl` channel-labelled chunks for live inspection.
Each tool checkpoint separates its process receipts from domain evidence; receipts contain `command`, `exitCode`, `state`, `terminationSignal`, `logPath` and a `tail` bounded to 60 lines and 8 KB, never raw `stdout`/`stderr` fields.
Checkpoint strings over 8 KB block; source/help observations and pin baseline files are referenced by artifact path instead of embedded.
Cancellation or deadline interruption terminates the process group, drains its pipes, persists partial logs and a compact interruption receipt, then rethrows the process error rather than reporting success.

The graph is visible in the entry file from release resolution through landing.
Its realized shape depends on plan-only mode, bounded repairs, skill dependencies, review and human confirmation; a static diagram would describe only one possible run.
