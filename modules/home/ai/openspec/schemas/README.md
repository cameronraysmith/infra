# First-party OpenSpec schema bundles

This directory holds schema bundles **we own and edit**.
It is deliberately a sibling of `../assets/schemas/`, which holds vendored third-party bundles that must stay pristine because they have a refresh path that would silently destroy local edits.

The distinction is load-bearing: anything under `../assets/` is refreshed from upstream and is not ours to modify; anything here is ours to modify and is never refreshed.

## superpowers-bridge-wrspm

A first-party fork of the vendored `superpowers-bridge` bundle, adding a WRSPM stratum layer.

Derived from `../assets/schemas/superpowers-bridge` at vendored pin `0366ed5` (upstream `github.com/JiangWay/openspec-schemas`).
The vendored copy remains in place as the upstream reference and continues to track upstream through its own refresh path.
This fork does not, and will not, auto-track upstream: re-deriving it after an upstream refresh is a deliberate act that must re-apply the delta below.

### What the fork adds

A per-capability stratum tag in the `proposal` artifact — `world`, `interface`, or `behavioral` — carried as part of the existing proposal-to-specs contract.

Stratum-conditional vocabulary rules in the `specs` artifact.
Behavioral deltas use world vocabulary and resolve every content noun against a designation table.
World deltas state indicative assumptions whose scenarios are violation and monitoring conditions, which is obstacle analysis expressed in the native Requirement-and-Scenario grammar.
Interface deltas mention only shared phenomena and state their trust boundary.

A non-blocking section 8 in the `verify` artifact: designation lint, discharge coherence, and an alphabet check, each warn-and-record in the same spirit as the existing section 7.
These are agent-executed. `openspec validate` checks markdown structure and delta well-formedness only, and checks no vocabulary grounding, alphabet discipline, or entailment — section 8 is not validation and must not be reported as such.

Satisfaction-projection regeneration in the apply phase's archive step, writing `docs/development/traceability/satisfaction.md` from the post-sync corpus.
It is rebuilt wholesale rather than patched, because a patched discharge table accumulates exactly the staleness the artifact exists to prevent.
It deliberately does not live under `openspec/`: artifact outputs are confined to the change directory by path assertion, and the only sanctioned corpus writers are the archive merge and the sync skill, both delta-mediated and scoped to `openspec/specs/`.

### What the fork changes for maintenance reasons

The `actionContext.mode == "workspace-planning"` guards were removed from the apply, verify, and retrospective entry points.
On OpenSpec 1.10.0 `ActionContext.mode` is the single literal `"repo-local"`, so the guard was unreachable and degraded to always-proceed.
It was dead rather than wrong, and the CLI-resolved path contract it accompanied is intact and verified against 1.10.0 status JSON.

The per-task `— verify:` convention and the closing `## Integration Verification` group were adopted from upstream OpenSpec 1.10.0's own tasks template, which the vendored bundle's template had not tracked.

The declared OpenSpec baseline moved from 1.4.1 to 1.10.0.

### Delivery

The bundle is currently made live in this repository through a project-tier symlink at `openspec/schemas/superpowers-bridge-wrspm`, which `openspec schema which` reports as `Source: project`.
Resolving from the repository's own tree means an edit here is immediately effective with no activation cycle, and it is impossible for this repository to test a stale copy of an artifact for which it is the source of truth.

User-global delivery through `~/.local/share/openspec/schemas/` is a separate concern owned by `../default.nix`, whose `schemaDir` option still points at the vendored bundle.
Repointing it, or delivering both bundles, is outstanding work.

### Known upstream defects at this baseline

`rules` keyed to the `tasks` artifact are silently dropped. `openspec instructions tasks --json`
carries no `rules` key at all, while sibling artifacts carry theirs, and no warning is emitted.
`tasks` is the artifact the apply phase `tracks:`, which is the likely cause. Task-level guidance
must therefore go into the schema's own `tasks` instruction (project-invariant parts) or into the
project's `context` (project-specific parts). Do not add `rules.tasks`: it would look live and be
inert.

A change pins its schema in `.openspec.yaml` at creation time. Renaming the schema in
`openspec/config.yaml` does not repin existing changes, and the mismatch is not reported — the
change silently continues resolving the old schema, which `openspec instructions` reveals only in
the `schema=` attribute of its opening tag. Repin existing changes by hand after a rename.

`openspec schema fork` fails against a read-only source tree: it preserves mode 444 on its staging copy and then cannot write it, aborting with `EACCES`.
It also renames the result, so it would not shadow the original.
Stage a project-tier schema with a whole-directory symlink instead.
