---
linear_story_id: ac2d8b9b-98a6-455d-9061-9f2d38a1efb1
linear_story_identifier: CAM-42
linear_story_title: Path-scope first-party plugin releases to fix apm outdated noise
linear_story_url: https://linear.app/cameronraysmith/issue/CAM-42/path-scope-first-party-plugin-releases-to-fix-apm-outdated-noise
linear_story_state: Todo
linear_team: CAM
linear_project: nixbot-herculesci-cicd
last_synced_state: Todo
last_synced_at: 2026-09-03T22:32:23Z
review_round: 0
attempt_log: []
---

## Why

`apm.lock.yaml` pins all 18 first-party plugin packages to `main`, so `apm outdated` flags all 18 as stale after any commit touching `main`, even the vast majority that never touch `modules/home/ai/plugins/`. The signal is permanently noisy and every relock rewrites an ~11,390-line, ~0.5 MB lockfile for no semantic change. A path-scoped release line, extending the existing `@vanixiets/docs-v*.*.*` precedent, makes staleness correspond to real change and relock a deliberate, notified act.

## What Changes

**Release line for the plugins tree**

- From: `packages/docs/package.json` is the only monorepo package with its own semantic-release line (`extends: semantic-release-monorepo`), scoped by `semantic-release-monorepo` to commits under `packages/docs/**`, tagged `@vanixiets/docs-v*.*.*`. No release line exists for `modules/home/ai/plugins/`.
- To: A new private package.json at `modules/home/ai/plugins/package.json` (name `@vanixiets/plugins`) carries an analogous `semantic-release-monorepo` release line, scoped to commits under `modules/home/ai/plugins/**`, cutting a canonical `@vanixiets/plugins-v*.*.*` tag on every qualifying release, plus 18 lightweight per-package alias tags (`<group>-v*.*.*`, one per plugin directory) minted at the same commit via the already-used `semantic-release-major-tag` plugin's `customTags` mechanism.
- Reason: `semantic-release-monorepo` scopes commit analysis to the directory the release process is invoked from (its package.json's own directory), not an arbitrary configurable path, so the release package must live inside `modules/home/ai/plugins/` itself for the scoping to match the tree we actually want to gate on.
- Impact: `modules/apps/cluster/list-packages-json.sh` (currently hardcoded to `packages/<name>/package.json` discovery) must be generalized to also discover `modules/home/ai/plugins/package.json`; `modules/apps/release/release.sh` needs no change (its `cd "$package_path"` is already path-generic). No new hercules-ci effect: the existing `release-packages` effect (`modules/effects/vanixiets/herculesCI/release-packages.nix`) already iterates every discovered package.

**First-party dependency pinning**

- From: The 18 first-party monorepo-subpath deps in the root `apm.yml` (`cameronraysmith/vanixiets/modules/home/ai/plugins/<group>#main`) resolve `main`, recording `resolved_ref: main` in `apm.lock.yaml` for all 18 — a moving target that makes `apm outdated` fire on unrelated commits.
- To: Each dependency's `ref:` is repointed from `main` to its own literal per-package alias tag (e.g. `planning-and-development-v1.0.0`), not a commit SHA. This is a deliberate, documented departure from the repo's blanket "pin a full 40-char SHA" manifest convention for this one dependency class, justified in design.md D2/D3: these 18 deps are consumed only by the network-permitted `apm-skills-install.sh` producer self-test app, never by the network-isolated `apm-skills-compose` nix derivation (which resolves the same 18 packages as local paths, bypassing apm's git resolution entirely), so the offline-build rationale behind the blanket-SHA convention does not apply to them.
- Reason: `apm outdated`'s full-SHA revision-pin path requires an *annotated* git tag (`find_latest_annotated_tag`, apm `revision_pins.py`); this repo's semantic-release pipeline (core `semantic-release` and `semantic-release-major-tag`) creates only lightweight tags, so a SHA pin would make `apm outdated` report `unknown` forever, never `outdated` — the literal-tag-ref path is the only one that produces a real signal without new apm-side tooling.
- Impact: `apm.lock.yaml`'s 18 entries move from `resolved_ref: main` to `resolved_ref: <group>-v<version>`; `apm outdated` becomes a real per-dependency staleness signal (verified by naming the alias tag to match apm's own final-path-segment `{name}` inference); `apm-skills-compose`'s local-path-based resolution and the deployed skill tree are unaffected (confirmed unaffected by design, not merely untested).

**Relock notification**

- From: No mechanism notifies a human, or triggers a relock, when `modules/home/ai/plugins/` changes; `just agents-relock` is a purely manual, memory-dependent act.
- To: A new tag-triggered GitHub Actions workflow, on `push: tags: ['@vanixiets/plugins-v*']`, runs `just agents-relock` and opens a pull request carrying the lockfile diff, mirroring the existing `regenerate-lock-files.yaml` amend-and-push pattern.
- Reason: GitHub Actions remains live infrastructure for maintenance-bot workflows in this repo (`update-flake-inputs.yaml`, `regenerate-lock-files.yaml`) even though the release pipeline itself moved to hercules-ci effects (`.github/deprecated/` holds the retired GH Actions release jobs); a PR is an actionable, reviewable artifact, and this does not depend on `apm outdated`'s own heuristic firing correctly.
- Impact: One new workflow file; no change to the deprecated GH Actions release pipeline (it stays deprecated) and no change to the hercules-ci effects.

## Capabilities

### New Capabilities

- `plugin-release-tagging` (`interface`): the path-scoped semantic-release line for `modules/home/ai/plugins/`, its canonical and per-package alias tags, and the hercules-ci effect that owns their creation and push.
  Trust boundary: this establishes that the release line exists, is scoped correctly, and produces the named tags at the release commit. It does not establish that any particular commit deserves a release (semantic-release's own commit-analyzer judgment) or that the pushed tags are ever consumed correctly downstream — that is `plugin-dependency-freshness-signal`'s boundary.
- `plugin-dependency-freshness-signal` (`interface`): the first-party dependency pinning discipline (alias-tag ref instead of `main`) and the tag-triggered relock-and-notify workflow.
  Trust boundary: this establishes that `apm outdated` reports real staleness for these 18 dependencies and that a human receives an actionable pull request when the plugins tree's release tag advances. It does not establish that a human acts on that pull request, nor that the underlying release judgment (which commits trigger a release) is itself correct.

### Modified Capabilities

- `world-assumptions`: adds two indicative facts about `apm`'s own behavior that the two new capabilities' discharge arguments depend on — that its revision-pin tag matching accepts only annotated tags, and that it derives a path-form git dependency's tag-pattern name from the dependency's own final path segment rather than any shared or configurable prefix. Both are external-tool facts, not requirements this repository can unilaterally satisfy by design; each carries a violation/monitoring scenario per the existing `world-assumptions` convention.

## Impact

- New file: `modules/home/ai/plugins/package.json` (private, `name: "@vanixiets/plugins"`, `release` block extending `semantic-release-monorepo` with an 18-entry `semantic-release-major-tag` `customTags` array).
- Modified: `modules/apps/cluster/list-packages-json.sh` (generalize package discovery beyond `packages/<name>/`).
- Modified: root `apm.yml` (repoint 18 `dependencies.apm` entries from `#main` to `#<group>-v<version>`) and `apm.lock.yaml` (relocked, `resolved_ref` changes for the same 18 entries; a subsequent `just agents-relock` after the first plugins release is required to actually populate the new pins — this change's own scope is the mechanism, not that first relock).
- New file: a GitHub Actions workflow (name TBD in tasks.md) triggered on `push: tags: ['@vanixiets/plugins-v*']`.
- Not modified: `pkgs/by-name/apm-skills-compose/package.nix`, `modules/home/ai/skills/{compose,default}.nix`, and the deployed skill tree — confirmed by design (see design.md D2) that these consume the 18 first-party packages via local nix paths, never via the root `apm.yml`'s GitHub-subpath resolution.
- Not modified: `.github/deprecated/*`, hercules-ci `deploy-docs.nix` (docs release line and deployment are unaffected; only `release-packages.nix`'s existing per-package iteration picks up the new package automatically once discovered).
- Explicitly excluded from this change: actually cutting the first `@vanixiets/plugins-v1.0.0` release, actually running the first `just agents-relock` against it, and any change to `.releaserc*`, `apm.yml`, or `apm.lock.yaml` content (this change is planning artifacts only; see design.md Migration Plan for the sequencing a follow-on implementation change would need).
