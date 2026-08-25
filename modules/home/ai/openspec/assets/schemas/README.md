# Forked OpenSpec schema bundles

This directory holds OpenSpec schema bundles that originated upstream and have since been modified here.
They are delivered user-global through the crs58 home-manager module.
Each bundle is a self-contained schema directory that the OpenSpec CLI selects per change.

The directory name says `assets`, and an earlier revision of this file described the contents as vendored third-party bundles pinned to an upstream commit.
That was inaccurate and the description is corrected below.
These are forks under our maintenance, not mirrors, and editing them is expected rather than forbidden.

## superpowers-bridge

Forked from `github.com/JiangWay/openspec-schemas` (the `superpowers-bridge/` bundle within that repository), whose current head is `f5d4040`, "docs(superpowers-bridge): bump OpenSpec baseline to 1.4.1", 2026-06-10.
A local reference copy of upstream is at `~/ghq/github.com/JiangWay/openspec-schemas`.

The fork has diverged substantially and does not track upstream.
`schema.yaml` differs by +79 / −29 lines against upstream head, and seven of the nine templates plus `templates/adopters/CLAUDE.md.fragment.md` also differ.
Re-deriving from upstream is therefore a deliberate merge, never a copy.

Our changes, as distinct from upstream's content:

CLI-resolved artifact paths replace hardcoded repo-local ones throughout.
Instructions read `artifactPaths.tasks.existingOutputPaths`, `artifactPaths.specs.existingOutputPaths`, and `artifactPaths.brainstorm` from `openspec status --change <name> --json` rather than assuming a repo-local change directory layout.

The `actionContext.mode == "workspace-planning"` precondition guards on the apply, verify, and retrospective entry points.
These are ours, not upstream's, and they are dead on OpenSpec 1.10.0, where `ActionContext.mode` is the single literal `"repo-local"` — the guard is unreachable and degrades to always-proceed.
They are retained here because this bundle is frozen as the reference (see below); the WRSPM fork removes them.

The two Traditional-Chinese localization files, `README.zh-TW.md` and `templates/adopters/CLAUDE.md.fragment.zh-TW.md`, are absent from this copy.
Neither is consumed by the OpenSpec CLI, which reads only `schema.yaml` and `templates/*.md`.

This bundle requires the superpowers Claude plugin.
It invokes `superpowers:`-namespaced skills — brainstorming, writing-plans, using-git-worktrees, subagent-driven-development, finishing-a-development-branch — and stops if they are absent.
It is additive governance layered on the plugin rather than a replacement for it.

### Status: frozen reference

This bundle is no longer the target for new work.
`../../schemas/superpowers-bridge-wrspm` supersedes it for new changes and carries the WRSPM stratum layer; see that directory's README for what it adds.

This bundle is nevertheless still delivered, and must remain so.
A change records its schema in its own `.openspec.yaml` at creation time and is never repinned, so withdrawing this bundle would strand every change already pinned to `superpowers-bridge` with an unresolvable schema.
Four in-flight changes are so pinned as of 2026-08-25: `agentic-planning-development-management-skills`, `apm-skills-marketplace`, `declarative-cognee-endpoint`, and `validate-harborize-instrument`.

Treat it as frozen: fix it only where an in-flight change pinned to it is actually blocked, and carry anything forward-looking into the WRSPM fork instead.

### Delivery and selection

Both bundles are delivered user-global under `~/.local/share/openspec/schemas/<name>/` by the `programs.openspec.schemaDirs` option in `../../default.nix`.
A project selects its default in `openspec/config.yaml`; a change may also be created against a specific bundle with `openspec new <name> --schema <bundle>`.
Each project still needs `openspec init` first.

Note that `vanixiets` itself resolves the WRSPM fork through a project-tier symlink at `openspec/schemas/`, which shadows the user-global copy, so an edit to the fork is live here without an activation cycle.

### Re-deriving from upstream

The refresh recipe previously documented here pointed at `~/projects/planning-workspace/openspec-schemas-superpowers-bridge/`, a path that no longer exists, and was a blind `cp -R` that would have discarded every local change listed above.
It has been removed rather than repaired.

Because the fork has diverged by design, re-deriving is a three-way merge against `~/ghq/github.com/JiangWay/openspec-schemas` with the local changes re-applied deliberately, and it should produce a reviewable diff rather than an overwrite.
