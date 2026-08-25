# Active OpenSpec schema bundles

This directory holds the schema bundle that new work targets.
Its sibling `../assets/schemas/` holds the earlier bundle, now frozen as a reference; see that directory's README for what it is and why it stays delivered.

Both directories are ours to edit. The `assets` name and an earlier description of that tree as vendored third-party content were both inaccurate — it is a fork under our maintenance that has diverged substantially from upstream. The distinction between the two directories is lifecycle, not ownership: this one is where changes land, that one is frozen and touched only to unblock a change already pinned to it.

## superpowers-bridge-wrspm

A fork of `superpowers-bridge` adding a WRSPM stratum layer.

Derived from `../assets/schemas/superpowers-bridge`, which is itself our fork of `github.com/JiangWay/openspec-schemas` and had already diverged from upstream by +79 / −29 lines in `schema.yaml` before this fork was taken. So this bundle's ancestry is two forks deep, and upstream is a reference rather than a merge base.

Neither bundle auto-tracks upstream. Re-deriving either is a deliberate three-way merge against `~/ghq/github.com/JiangWay/openspec-schemas`, not a copy.

The reason to fork rather than edit the parent in place is the schema pin, discovered after the fact. A change records its schema in its own `.openspec.yaml` at creation time and is never repinned, so editing the parent would have retroactively changed the governing schema under every change already pinned to it. Forking leaves those changes on the bundle they were authored against.

### What the fork adds

A per-capability stratum tag in the `proposal` artifact — `world`, `interface`, or `behavioral` — carried as part of the existing proposal-to-specs contract.

Stratum-conditional vocabulary rules in the `specs` artifact.
Behavioral deltas use world vocabulary and resolve every content noun against a designation table.
World deltas state indicative assumptions whose scenarios are violation and monitoring conditions, which is obstacle analysis expressed in the native Requirement-and-Scenario grammar.
Interface deltas mention only shared phenomena and state their trust boundary.

A non-blocking section 8 in the `verify` artifact: designation lint, discharge coherence, and an alphabet check, each warn-and-record in the same spirit as the existing section 7.
These are agent-executed. `openspec validate` checks markdown structure and delta well-formedness only, and checks no vocabulary grounding, alphabet discipline, or entailment — section 8 is not validation and must not be reported as such.

Satisfaction-projection regeneration in the apply phase's archive step, writing `packages/docs/src/content/docs/development/traceability/satisfaction.md` from the post-sync corpus.
It is rebuilt wholesale rather than patched, because a patched discharge table accumulates exactly the staleness the artifact exists to prevent.
It deliberately does not live under `openspec/`: artifact outputs are confined to the change directory by path assertion, and the only sanctioned corpus writers are the archive merge and the sync skill, both delta-mediated and scoped to `openspec/specs/`.

### What the fork changes for maintenance reasons

The `actionContext.mode == "workspace-planning"` guards were removed from the apply, verify, and retrospective entry points. These guards were ours rather than upstream's, added to the parent fork alongside its CLI-resolved artifact paths.
On OpenSpec 1.10.0 `ActionContext.mode` is the single literal `"repo-local"`, so the guard was unreachable and degraded to always-proceed.
It was dead rather than wrong, and the CLI-resolved path contract it accompanied is intact and verified against 1.10.0 status JSON.

The per-task `— verify:` convention and the closing `## Integration Verification` group were adopted from upstream OpenSpec 1.10.0's own tasks template, which the parent bundle's template had not tracked.

The declared OpenSpec baseline moved from 1.4.1 to 1.10.0.

### Delivery

The bundle is currently made live in this repository through a project-tier symlink at `openspec/schemas/superpowers-bridge-wrspm`, which `openspec schema which` reports as `Source: project`.
Resolving from the repository's own tree means an edit here is immediately effective with no activation cycle, and it is impossible for this repository to test a stale copy of an artifact for which it is the source of truth.

Both bundles are delivered user-global by the `programs.openspec.schemaDirs` option in `../default.nix`, so a change pinned to either resolves.

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
