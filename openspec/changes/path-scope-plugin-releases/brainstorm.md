<!--
Raw capture of superpowers:brainstorming output.

This file captures the output of the brainstorming skill verbatim; it does not impose any structure.
The skill's natural output is usually a decision-log format (background → decision chain Q1-Qn → design trade-offs),
but the organization may vary depending on the conversation.

design.md is extracted from this file and reorganized into a structured design document.

Do not copy this file's content into design.md — design.md is an independent, reorganized artifact;
the two are complementary but do not overlap.
-->

# Brainstorm: path-scoped release mechanism for first-party plugin packages

## Process note

`superpowers:brainstorming` is an interactive, turn-taking skill designed for a live human collaborator.
This artifact was produced by a non-interactive subagent operating under an explicit "return with questions rather than interpreting ambiguity" contract, with no live human available to answer clarifying questions mid-exploration.
In place of interactive Q&A, the exploration below was driven entirely by source-grounded investigation of this repository and of the `apm` CLI's own source (cloned locally at `~/ghq/github.com/microsoft/apm`, tag `v0.29.0`, matching the installed binary). Every claim below is cited to a file and line. Where the investigation could not settle a question, that is recorded as an open question rather than assumed.

## Background (verified, not re-derived)

The repo publishes 18 first-party apm skill packages under `modules/home/ai/plugins/<group>/`. The root `apm.yml` (`apm.yml:80-98`) declares each as a monorepo-subpath dependency of the form `cameronraysmith/vanixiets/modules/home/ai/plugins/<group>#main`, and `apm.lock.yaml` records `resolved_ref: main` / `resolved_commit: fcf0253f52365b6065e8ffb3c4258d81f201e695` (same commit for all 18) with no `depth` field, distinguishing them from the third-party deps' `depth: 2` entries (`apm.lock.yaml:8-9, 940-943`). Because the ref is a branch, `apm outdated` classifies all 18 as `git branch` source and flags them stale on any commit to `main`.

Docs already release path-scoped via semantic-release: `packages/docs/package.json` sets `"release": {"extends": "semantic-release-monorepo", ...}` (`packages/docs/package.json:66-129`) with no explicit `tagFormat`. `semantic-release-monorepo`'s default tag format is `<package-name>-v<version>` (vendored README, `semantic-release-monorepo/README.md:90-100`), so `@vanixiets/docs` (the package.json `name`) yields the observed `@vanixiets/docs-v*.*.*` tags. The monorepo plugin scopes commit analysis to "a file in or below a package's root" (`semantic-release-monorepo/README.md:15-17`), where "root" is the directory the `semantic-release` process is invoked from, not a configurable path.

Release execution: `.github/deprecated/{cd,ci-nix-fast-build,ci-pre-nix-check,package-release,deploy-docs}.yaml` are all under `.github/deprecated/` — dead. The live release path is the hercules-ci effect `modules/effects/vanixiets/herculesCI/release-packages.nix`, fired `onPush.default` (main-branch pushes) under nixbot/buildbot-nix, which clones `https://github.com/cameronraysmith/vanixiets.git` fresh, authenticates with a repo-scoped PAT (`GIT_CREDENTIALS`, read+write, distinct from buildbot's read-only App-installation token — comment at `release-packages.nix:202-203`), enumerates packages via `config.apps.list-packages-json.program`, and dispatches `config.apps.release.program <pkg-path>` per discovered package (`release-packages.nix:216-247`). `list-packages-json.sh` hardcodes discovery to `packages/<name>/package.json` (`modules/apps/cluster/list-packages-json.sh:22-31`). `release.sh` takes an arbitrary `package_path`, `cd`s into it (`modules/apps/release/release.sh:154-175`), and runs `semantic-release` from there — so `release.sh` itself is already path-generic; only the discovery script is hardcoded to `packages/*`.

Separately (and this turned out to matter a great deal): the actual **deployed** skill tree — `modules/home/ai/skills/compose.nix` → `pkgs/by-name/apm-skills-compose/package.nix` → `aiSkills.composed` — never resolves the 18 first-party packages via the root `apm.yml`'s GitHub subpath refs at all. The compose derivation builds its own synthetic consumer manifest listing each first-party package as a **local relative path** (`- ./${n}`, `apm-skills-compose/package.nix:83-99, 248`) copied in from the local worktree (`copyFirstPartyPackages`, `apm-skills-compose/package.nix:97-99`). The root `apm.yml`/`apm.lock.yaml`'s `main`-pinned subpath entries are consumed by exactly one thing: `modules/apps/apm-skills-install.sh`, a `nix run` app (`just agents-install` / `just agents-relock`, `justfile:576-583`) that is a producer self-test ("materializes the marketplace this repo publishes back into the repo it is published from" — `apm-skills-install.sh:4-13`), not a build-sandboxed derivation. This matters for the offline/full-SHA question below.

## Q1 — Does `apm install --frozen` need network for these deps regardless of ref form?

Yes, confirmed. `--frozen` (`apm_cli/commands/install.py:1767-1774` → `InstallService.enforce_frozen`) verifies lockfile *presence and structure*, not content; materialization reads `resolved_commit` (always a full SHA, already resolved at lock time) and fetches that SHA through the bare cache, which checks `_rev_parse_present()` first — "no network if SHA already present" (`apm_cli/deps/bare_cache.py:440-445`). The manifest `ref:` field (branch, tag, or SHA) is consulted only when *re-resolving* — `apm install --update` / `apm update` (relock). So: network cost, if any, lands only on relock, exactly as stated in the assignment background. Confirmed against source, not just restated.

## Q2 — Does a tag ref on a monorepo subpath dep force a network fetch the same way a branch does?

Partially, and the more important finding is about the sandboxing boundary, not the ref form. `bare_cache.py`'s Tier-1 fetch (`git fetch origin <sha>`) only works for a full 40-char SHA (`bare_cache.py:180-188`); a branch OR a tag name both require a `git clone --branch <ref>` (`bare_cache.py:271-291`) — heavier, and for a *branch* specifically, non-deterministic across time (the tip moves). So the manifest convention "full 40-char SHA avoids a network fetch" is really "…avoids a **repeated, moving-target** fetch"; a literal tag name is a *fixed* target once cut, but apm still has to resolve it via clone rather than a direct SHA fetch.

Crucially, though: this "full SHA required" convention (repeated verbatim in `version-control-and-forge/apm.yml:9-10`, `:18-19`, `planning-and-development/apm.yml` comments, etc.) exists to keep the **hermetic, network-isolated `apm-skills-compose` nix derivation** buildable offline (`apm-skills-compose/package.nix:116-146`: `apm install --root "$out"` inside `runCommandLocal`, a sandboxed build with no network). But per the Background section above, the 18 first-party deps' GitHub-subpath pins are **never consumed inside that sandboxed derivation** — only by the network-permitted `apm-skills-install.sh` app. So the rationale that forces "full SHA, never a ref name" onto the seven genuine third-party deps does not mechanically apply to these 18 self-referential ones. This reopens a design option (see D2 in design.md) that would otherwise be foreclosed.

## Q3 — If we still use a full-SHA pin (to stay consistent with the blanket convention), does `apm outdated` treat it as a real signal once it corresponds to a tag?

No — and this is the load-bearing finding of the whole exploration. `apm outdated`'s SHA-revision-pin path (`is_full_revision_pin(current_ref)` → `_check_revision_pin_ref` → `find_latest_annotated_tag`, `apm_cli/commands/outdated.py:233-262, 300-317`) explicitly rejects any non-annotated tag: `if not ref.annotated: continue` (`apm_cli/deps/revision_pins.py:120-121`), calling this a "fail-closed security fence." I then checked how *this repo's own* semantic-release pipeline creates tags:
- semantic-release core: `git tag <tagName> <ref>` — no `-a` (`node_modules/.../semantic-release/lib/git.js:227-229`).
- `semantic-release-major-tag` (already a devDependency, already used at root for `v${major}`/`v${major}.${minor}` floating tags): `git tag --force ${tag}` — no `-a` (`node_modules/.../semantic-release-major-tag/dist/steps/success.js:29-33`).

Every tag this repo's release pipeline creates, including the existing `@vanixiets/docs-v*.*.*` tags, is **lightweight**. Under a full-SHA pin, `apm outdated` would call `find_latest_annotated_tag`, find zero annotated candidates, and report `status: unknown` forever — never `outdated`, even when the plugins tree has genuinely changed. The stated goal ("apm outdated becomes a real signal") is **not achievable** via the full-SHA path with this repo's current tagging tooling. This forecloses the naive "just point ref at the SHA behind the newest tag" reading of the proposed direction.

## Q4 — Is there a path where `apm outdated` genuinely works, without building new annotated-tag tooling?

Yes. `apm outdated`'s *other* branch — a literal tag name as `ref:` (not a SHA) — does **not** filter on annotation. `_check_one_dep` (`outdated.py:264-401`) only enforces `ref.annotated` inside the SHA-pin path; the literal-tag-ref path (`is_tag_ref` → `_semver_tag_candidates`, `outdated.py:319-370`) accepts any `GitReferenceType.TAG`, lightweight included. Given Q2's finding that these 18 deps sit outside the sandboxed-build offline requirement, pinning `ref:` to the literal tag name (not a SHA) is viable for these specifically.

But the literal-tag-ref path still has to match a tag pattern, and apm derives that pattern's `{name}` from **the dependency's own final path segment**, not from any shared prefix: `package_name(dep_ref)` for a virtual subdirectory dependency returns `virtual_path.rsplit("/", 1)[-1]` (`apm_cli/deps/revision_pins.py:87-91`), and this is independently documented, not just inferred from source: "For virtual subdirectory packages (installed via `path:` in `apm.yml`), `{name}` is derived from the final path segment, so a dep with `path: packages/my-pkg` resolves tags like `my-pkg_v1.2.3`" (`apm` docs, `reference/cli/outdated.md:23`). There is no consumer-side override for this — the only `tag_pattern` override documented anywhere in apm is on the **producer** side (`marketplace.packages[].tag_pattern`, `manifest-schema.md:933`), and these deps deliberately bypass marketplace-shorthand resolution (`testing-and-quality/apm.yml` comment: "apm install validates every transitive apm.yml and rejects the NAME@MARKETPLACE shorthand, which would break the hermetic offline nix compose").

So a single shared tag like `@vanixiets/plugins-v1.0.0` will never be recognized by `apm outdated` for a dependency whose `virtual_path` ends in `planning-and-development` — it would need a tag literally named `planning-and-development-v1.0.0` (or the `_v`/`--v` variants) to match `DEFAULT_TAG_PATTERNS` (`marketplace/tag_pattern.py:33-39`).

## Q5 — Can one release event mint 18 differently-named tags at the same commit?

Yes, and this repo already has the tool for it. `semantic-release-major-tag`'s `customTags` accepts arbitrary literal text combined with `${major}`/`${minor}`/`${patch}` placeholders (its README example: `"example-${major}.${minor}"`, vendored README lines 33-49) — this is exactly the existing mechanism the root `package.json` already uses for its own `v${major}`/`v${major}.${minor}` floating tags. Configuring `customTags: ["planning-and-development-v${major}.${minor}.${patch}", "testing-and-quality-v${major}.${minor}.${patch}", ... /* all 18 */]` on the new plugins release line would, on every release, force-create 18 lightweight alias tags at the release commit alongside the canonical `@vanixiets/plugins-v<version>` tag — each shaped exactly as apm's own default pattern-inference expects, with zero apm-side customization.

## Q6 — Where would the new release's package.json actually live, so that semantic-release-monorepo's commit scoping matches `modules/home/ai/plugins/`?

`semantic-release-monorepo` scopes to "a file in or below a package's root," where "root" is the directory `semantic-release` is invoked from (README lines 13-17), i.e. `release.sh`'s `cd "$package_path"` (`release.sh:175`). To scope commit analysis to `modules/home/ai/plugins/**` (not `packages/plugins/**`, which is a different directory with no first-party skill content), the new package.json must live at `modules/home/ai/plugins/package.json` itself, and `list-packages-json.sh` must be generalized beyond its current `packages/<name>/` hardcoding (`list-packages-json.sh:22-31`) to also discover it. `release.sh` needs no change — its `cd "$package_path"` already works for any path.

## Q7 — Who owns tag creation and push?

The `release-packages` hercules-ci effect, authenticated as a first-party GitHub PAT identity (not the buildbot-nix App installation token — `release-packages.nix:202-203`), running on `onPush.default` (main-branch pushes) under nixbot/buildbot-nix (`release-packages.nix:260`). GitHub Actions plays no role in tag creation; the entire GH-Actions release pipeline (`cd.yaml`, `ci-nix-fast-build.yaml`, `ci-pre-nix-check.yaml`, `package-release.yaml`, `deploy-docs.yaml`) is under `.github/deprecated/`. A new plugins release line rides the same effect once `list-packages-json.sh` discovers its package.json — no new effect is needed.

## Q8 — How should "notify + relock when the plugins tree changes" actually work?

Not via `apm outdated`'s own automatic per-run detection (there is no scheduled `apm outdated` run anywhere in this repo today, deprecated or live). Instead: a new, tag-push-triggered GitHub Actions workflow (GH Actions remains active infrastructure for maintenance-bot workflows — `update-flake-inputs.yaml` and `regenerate-lock-files.yaml` are both still live, non-deprecated), triggered on `push: tags: ['@vanixiets/plugins-v*']`, running `just agents-relock` and opening a pull request with the diff — mirroring `regenerate-lock-files.yaml`'s amend-and-push pattern. Git tags containing `@` and `/` are already proven to work as GH ref names in this exact repo (the existing `@vanixiets/docs-v*` tags). This gives a human an actionable, reviewable artifact (a PR) rather than a silent status flag, and does not depend on `apm outdated`'s per-dependency tag-pattern inference at all — that mechanism (Q3-Q5) is worth having as a secondary, ad-hoc signal (`apm outdated` run by hand), but the workflow is the primary, reliable notification.

## Decision funnel

1. Naive reading of the proposed direction (pin ref → SHA behind newest tag, `apm outdated` "just works") is **falsified** by Q3: this repo's tags are lightweight, and apm's SHA-revision-pin path fail-closes on non-annotated tags.
2. The literal-tag-ref path is viable (Q4) but needs per-dependency-shaped tags, not one shared tag, because of how apm infers `{name}` (Q4).
3. `semantic-release-major-tag`'s existing `customTags` mechanism cheaply produces those 18 shaped alias tags per release (Q5), reusing tooling already present and already used for an analogous purpose at root scope.
4. The commit-scoping boundary (Q6) requires the new package.json to live at `modules/home/ai/plugins/package.json`, not under `packages/`, and requires generalizing `list-packages-json.sh`.
5. Tag/release ownership stays with the existing hercules-ci `release-packages` effect (Q7); no new effect.
6. The actual "notify a human, make relock a deliberate act" goal is best served by a dedicated, tag-triggered GH Actions workflow opening a PR (Q8), independent of whether `apm outdated`'s own heuristic fires correctly — belt-and-suspenders rather than betting everything on one mechanism.

## Open items carried into design.md

- Whether root `package.json`'s own `v${major}`/`v${major}.${minor}` release config is *actually invoked* by anything today (root is not under `packages/`, and `list-packages-json.sh` only walks `packages/*`) is unresolved — flagged as an open question rather than assumed either way.
- Naming: `plugins` vs `skills` as the release-line segment name is a judgment call, resolved in design.md with rationale, not empirically forced.
