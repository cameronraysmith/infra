# Mergify stacked landing integration implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the release-aligned upstream `mergify-stack` skill beside the first-party Git-native stacked-landing policy and expose their role boundary in generated user context.

**Architecture:** A source-only Nix package pins the upstream Mergify tree, and `apm-skills-compose` uses that tree to resolve the declared remote dependency without network access.
A full-flake structure check reads both Mergify versions from the composed per-system package output and fails its build when they differ.
The first-party skill owns fleet policy while the unedited upstream skill owns Mergify command detail, and the generated user-context tier assigns preparation and verification to workers while reserving pull-request stack publication and landing for the orchestrator through the existing `stack-land` handler.

**Tech Stack:** Nix, apm, Markdown agent skills, generated AGENTS context, OpenSpec, Git, and GitHub CLI evidence.

## Global Constraints

- Keep `mergify-cli-bin` at release `2026.8.31.1` unchanged and pin the source package to that same upstream release.
- Preserve the upstream `mergify-stack` tree byte-for-byte.
- Preserve the PR 2738, 2739, and 2740 evidence sentence byte-for-byte from base and add the literal transcript-prescribed soft note “we start with git… The `Change-Id` format is shared, so switching the orchestrator or individual workers to jj changes nothing about identity, PR bookkeeping, or landing. The signal to switch is conflict volume in the orchestrator step, not preference.”.
- Limit the evidence sentence to the observed fast-forward landing and GitHub reachability; do not present it as evidence of Mergify authoring or publication.
- Treat `git-stacked-pr-integration` as the first-party policy owner, `mergify-stack` as the upstream mechanism owner, and `stack-land --tip REV PR...` as the existing checked landing handler.
- A worker prepares and verifies one change and returns its ref and evidence without publishing; the orchestrator alone orders and publishes the pull-request stack and alone lands it.
- Describe the handler's reported-check gate exactly: each supplied pull request needs at least one check, every reported conclusion must be `SUCCESS`, `NEUTRAL`, or `SKIPPED`, and pending, failing, or any other conclusion blocks.
- Compose only the current direct targets `agent-skills` and `claude`, leaving later Nix fan-out and the older four-target requirement as an undischarged provenance risk.
- Leave the root `apm.lock.yaml` unchanged; the Nix-generated `$out/apm.lock.yaml` and `$out/.agents` tree do not prove repository-local `.agents/` delivery.
  Before a generated `just agents-relock` follow-up after this change reaches `main`, a fresh frozen `just agents-install` would materialize the pre-change set, while the contents of any existing ignored repository-local `.agents/` tree are unspecified.
- Record but do not repair the canonical conflicts over four direct targets, apm never running outside Nix, and roughly 70 unchanged absolute `@` references despite the current single force-load reference.
- Do not claim an end-to-end guarantee across human authorization, GitHub responses, selected pull requests, or unmodeled forge behavior.
- Do not add Cognee gates, alter the binary derivation or its home-manager installation, implement a landing script or recipe, change nixbot or ruleset settings, perform a real landing, or edit `apm.lock.yaml` manually.
- For CAM-41's planning and implementation history, commit each edited file immediately as a separate atomic commit without amending or rewriting history; this workflow instruction is distinct from the stacked-delivery precedence that Task 4 emits into user context.
- When regenerating `verify.md`, cite named package attributes, Markdown sections, and commands rather than line numbers.

## File Map

- Create `pkgs/by-name/agent-plugins/mergify-cli/package.nix` to expose the pinned upstream source, release identity, full revision, and fixed-output hash.
- Modify `modules/home/ai/plugins/version-control-and-forge/apm.yml` to declare the full-revision upstream `mergify-stack` dependency.
- Modify `pkgs/by-name/apm-skills-compose/package.nix` to pre-warm the Mergify checkout, reject revision drift, and assert the delivered `SKILL.md` entry points.
- Create `modules/checks/structure/mergify-release-alignment.nix` to auto-register the normal `checks.<system>.structure-mergify-release-alignment` build and its genuine failing-case control.
- Modify `modules/home/ai/plugins/README.md` to register the distinct first-party and upstream owners.
- Modify `modules/home/ai/plugins/version-control-and-forge/.apm/skills/git-stacked-pr-integration/SKILL.md` to map fleet requirements to the upstream mechanism and existing landing handler.
- Modify `modules/home/tools/agents-md.nix` to emit the concise role-conditioned protocol from the committed user-context source.

---

### Task 1: Pin and inspect the upstream Mergify source

**Files:**

- Create: `pkgs/by-name/agent-plugins/mergify-cli/package.nix`
- Reference: `pkgs/by-name/mergify-cli-bin/package.nix`
- Reference: `openspec/changes/integrate-mergify-stacked-landing/design.md`
- Reference: `openspec/changes/integrate-mergify-stacked-landing/specs/third-party-plugin-dependency/spec.md`

**Interfaces:**

- Consumes: the exact release string `2026.8.31.1` from `mergify-cli-bin.version`.
- Produces: a source derivation whose `version`, `rev`, and source output become the single release identity, full commit identity, and checkout tree consumed by Task 2.
- Produces: the exact upstream `skills/mergify-stack/SKILL.md` entry point for Tasks 2 and 3.

- [ ] **Step 1: Verify the release tag through the GitHub API boundary.**

Run: `gh-axi api repos/Mergifyio/mergify-cli/git/ref/tags/2026.8.31.1 --jq '.object.sha'`.

Expected: `727ce50b8fb3be8a9a24025807e159d644dbba80` with exit status 0.

- [ ] **Step 2: Verify the recursive skill tree and record the source hash.**

Run: `nix store prefetch-file --unpack --json https://github.com/Mergifyio/mergify-cli/archive/727ce50b8fb3be8a9a24025807e159d644dbba80.tar.gz`.

Expected: JSON whose `hash` is `sha256-BQl5L61m6uSr7y7fXoUsEwELmmSmHvs0jJMH22Zm82A=`.

Run: `gh-axi api 'repos/Mergifyio/mergify-cli/git/trees/727ce50b8fb3be8a9a24025807e159d644dbba80?recursive=1' --jq '.tree[] | select(.path | startswith("skills/mergify-stack/")) | .path'`.

Expected: only `skills/mergify-stack/SKILL.md` appears as the upstream skill payload.

- [ ] **Step 3: Add the source-only package using the resolved values.**

Use this complete package shape with the resolved full revision and fixed-output hash.

```nix
{
  fetchFromGitHub,
}:

fetchFromGitHub {
  pname = "agent-plugins-mergify-cli";
  version = "2026.8.31.1";
  owner = "Mergifyio";
  repo = "mergify-cli";
  rev = "727ce50b8fb3be8a9a24025807e159d644dbba80";
  hash = "sha256-BQl5L61m6uSr7y7fXoUsEwELmmSmHvs0jJMH22Zm82A=";
  passthru.releaseTag = "2026.8.31.1";
}
```

- [ ] **Step 4: Evaluate release alignment and the full revision.**

Run: `test "$(nix eval --option builders '' --option allow-import-from-derivation false --raw .#packages.aarch64-darwin.agent-plugins-mergify-cli.version)" = "$(nix eval --option builders '' --option allow-import-from-derivation false --raw .#packages.aarch64-darwin.mergify-cli-bin.version)"`.

Expected: exit status 0 with both values equal to `2026.8.31.1`.

Run: `nix eval --option builders '' --option allow-import-from-derivation false --raw .#packages.aarch64-darwin.agent-plugins-mergify-cli.rev | rg '^727ce50b8fb3be8a9a24025807e159d644dbba80$'`.

Expected: the full revision from Step 2 followed by exit status 0.

- [ ] **Step 5: Build and inspect the source output.**

Run: `MERGIFY_SRC=$(nix build --option builders '' .#agent-plugins-mergify-cli --no-link --print-out-paths) && test -f "$MERGIFY_SRC/skills/mergify-stack/SKILL.md"`.

Expected: the build and entry-point assertion exit 0.

- [ ] **Step 6: Commit only the source package.**

Run: `git add pkgs/by-name/agent-plugins/mergify-cli/package.nix && git commit -m "feat(agent-plugins): pin Mergify skill source"`.

Expected: `git diff-tree --no-commit-id --name-only -r HEAD` prints only `pkgs/by-name/agent-plugins/mergify-cli/package.nix`.

Rollback: revert this one commit after reverting any later consumer commits.

### Task 2: Compose and register the unedited upstream skill

**Files:**

- Modify: `modules/home/ai/plugins/version-control-and-forge/apm.yml`
- Modify: `pkgs/by-name/apm-skills-compose/package.nix`
- Modify: `modules/home/ai/plugins/README.md`
- Reference: `openspec/changes/integrate-mergify-stacked-landing/specs/third-party-plugin-dependency/spec.md`

**Interfaces:**

- Consumes: Task 1's source derivation, 40-character `rev`, and exact `skills/mergify-stack/SKILL.md` entry point.
- Produces: a remote-style apm lock record resolved entirely from the sole pre-warmed shard keyed by APM's normalized lowercase URL.
- Produces: unedited `mergify-stack` trees under `.claude/skills` and `.agents/skills` inside the Nix output for Task 3 and Nix consumers, not the root-lock-driven repository-local `.agents/` tree.

- [ ] **Step 1: Add the upstream dependency declaration.**

Add this object beneath `dependencies.apm`.

```yaml
    - git: Mergifyio/mergify-cli
      ref: 727ce50b8fb3be8a9a24025807e159d644dbba80
      skills: [mergify-stack]
```

Retain the mixed-case owner spelling in the manifest because it records the upstream repository identity independently from APM's cache-key normalization.

- [ ] **Step 2: Verify and commit the manifest alone.**

Run: `rg -n -A2 'Mergifyio/mergify-cli' modules/home/ai/plugins/version-control-and-forge/apm.yml`.

Expected: one dependency selects only `mergify-stack` and uses Task 1's full revision.

Run: `git add modules/home/ai/plugins/version-control-and-forge/apm.yml && git commit -m "feat(agent-skills): declare upstream Mergify skill"`.

Expected: `git diff-tree --no-commit-id --name-only -r HEAD` prints only the manifest path.

- [ ] **Step 3: Add the Mergify source interface to the composition derivation.**

Follow the existing `ghStackSrc` and `ghStackRev` argument pattern and add these exact argument names.

```nix
  mergifyCliSrc ? inputs.self.packages.${stdenv.hostPlatform.system}.agent-plugins-mergify-cli,
  mergifyCliRev ? mergifyCliSrc.rev,
```

Expected: later shell code refers only to `mergifyCliSrc` and `mergifyCliRev`, so the Nix package remains the single pin source.

- [ ] **Step 4: Pre-warm the Mergify checkout and reject declaration drift.**

APM 0.29.0 lowercases GitHub owner and repository components in `cache/url_normalize.py` before deriving the checkout-cache key.
Add a block parallel to the `GH_SHA` block that hashes only the normalized lowercase URL, because hashing the mixed-case manifest spelling pre-warms an unused shard and causes offline resolution to attempt the network.

```bash
    MF_SHA=${mergifyCliRev}
    SHARD_MF=$(printf '%s' 'https://github.com/mergifyio/mergify-cli' | sha256sum | cut -c1-16)
    CK_MF="$APM_CACHE_DIR/git/checkouts_v1/$SHARD_MF/$MF_SHA/full"
    mkdir -p "$CK_MF"
    cp -RL ${mergifyCliSrc}/. "$CK_MF"/
    chmod -R u+w "$CK_MF"

    if ! rg -q "ref: $MF_SHA" ${../../modules/home/ai/plugins/version-control-and-forge/apm.yml}; then
      echo "apm-skills-compose: mergify-cli SHA drift — version-control-and-forge/apm.yml does not pin $MF_SHA" >&2
      exit 1
    fi
```

Adapt only the manifest path expression if the surrounding derivation already binds that path under a different exact Nix expression.

- [ ] **Step 5: Assert both delivered entry points.**

Extend the existing output-file assertion loop with `.claude/skills/mergify-stack/SKILL.md` and `.agents/skills/mergify-stack/SKILL.md`.

Run: `rg -n "SHARD_MF=.*https://github.com/mergifyio/mergify-cli" pkgs/by-name/apm-skills-compose/package.nix`.

Expected: one Mergify shard hashes the normalized lowercase URL, and no mixed-case or dual pre-warm is present.

Run: `nix build --option builders '' .#apm-skills-compose --no-link --print-out-paths`.

Expected: the build resolves offline through the normalized shard, exits 0 without a network attempt, and generates a lock inside the Nix output identifying manifest dependency `Mergifyio/mergify-cli` at Task 1's revision with per-file hashes.

- [ ] **Step 6: Confirm the delivered tree is unedited.**

Run: `COMPOSED=$(nix build --option builders '' .#apm-skills-compose --no-link --print-out-paths) && gh-axi api 'repos/Mergifyio/mergify-cli/contents/skills/mergify-stack/SKILL.md?ref=727ce50b8fb3be8a9a24025807e159d644dbba80' --jq '.content' | base64 --decode | cmp - "$COMPOSED/.claude/skills/mergify-stack/SKILL.md"`.

Expected: `cmp` exits 0 and emits no output.

- [ ] **Step 7: Commit only the composition derivation.**

Run: `git add pkgs/by-name/apm-skills-compose/package.nix && git commit -m "feat(agent-skills): compose upstream Mergify skill"`.

Expected: `git diff-tree --no-commit-id --name-only -r HEAD` prints only `pkgs/by-name/apm-skills-compose/package.nix`.

- [ ] **Step 8: Register the two ownership boundaries in the plugin README.**

Add `mergify-stack` as an upstream mechanism skill from `Mergifyio/mergify-cli` and keep `git-stacked-pr-integration` registered as the first-party policy, role, VCS-routing, and evidence owner in the `version-control-and-forge` package.

Run: `rg -n 'mergify-stack|git-stacked-pr-integration|version-control-and-forge' modules/home/ai/plugins/README.md`.

Expected: both skill names, their distinct owners, and the package appear without describing either as a replacement for the other.

- [ ] **Step 9: Commit only the README.**

Run: `git add modules/home/ai/plugins/README.md && git commit -m "docs(agent-skills): register Mergify mechanism skill"`.

Expected: `git diff-tree --no-commit-id --name-only -r HEAD` prints only `modules/home/ai/plugins/README.md`.

Rollback: revert the README, composition, and manifest commits in reverse order, then leave Task 1's unused source pin intact or revert it separately.

### Task 3: Converge the first-party policy skill

**Files:**

- Modify: `modules/home/ai/plugins/version-control-and-forge/.apm/skills/git-stacked-pr-integration/SKILL.md`
- Reference: Task 1's pinned `skills/mergify-stack/SKILL.md`.
- Reference: `pkgs/by-name/stack-land/stack-land.sh`
- Reference: `modules/home/tools/stack-land.nix`
- Reference: `openspec/changes/integrate-mergify-stacked-landing/specs/first-party-skill-distribution/spec.md`

**Interfaces:**

- Consumes: the upstream skill delivered by Task 2 and the existing `stack-land --tip REV PR...` command.
- Produces: the first-party requirement-to-mechanism map and worker-orchestrator contract consumed by the generated user-context protocol in Task 4.

- [ ] **Step 1: Capture the protected evidence sentence from the fixed base.**

Run: `git show 33f94e2ce:modules/home/ai/plugins/version-control-and-forge/.apm/skills/git-stacked-pr-integration/SKILL.md | rg 'The pattern was verified'`.

Expected: the following evidence sentence appears exactly.

```text
The pattern was verified landing PRs 2738, 2739, and 2740 in cameronraysmith/vanixiets on 2026-08-18: main was fast-forwarded to fe5a4b71 and GitHub merged all three PRs by reachability within one second.
```

- [ ] **Step 2: Add the requirement-to-mechanism map and role contract.**

State that a worker prepares and verifies one independently shippable change, commits it, and returns its ref and evidence without publishing or landing.

State that the orchestrator alone orders refs, publishes their pull-request stack, rechecks repository mode and landing preconditions, and invokes the selected landing mechanism.

Refer to `mergify-stack` for Mergify command mechanics, and map the checked final effect to the landed repository `stack-land --tip REV PR...` command plus its dry-run mode.

Keep the upstream skill unedited, keep both skills visible, and do not copy the upstream recipe into the first-party skill.

- [ ] **Step 3: Preserve the evidence sentence and add the literal soft note byte-for-byte.**

Run: `for sentence in "The pattern was verified landing PRs 2738, 2739, and 2740 in cameronraysmith/vanixiets on 2026-08-18: main was fast-forwarded to fe5a4b71 and GitHub merged all three PRs by reachability within one second." 'we start with git… The `Change-Id` format is shared, so switching the orchestrator or individual workers to jj changes nothing about identity, PR bookkeeping, or landing. The signal to switch is conflict volume in the orchestrator step, not preference.'; do test "$(rg -Fxc "$sentence" modules/home/ai/plugins/version-control-and-forge/.apm/skills/git-stacked-pr-integration/SKILL.md)" = 1; done`.

Expected: exit status 0 confirms one byte-identical copy of the base evidence sentence and one byte-identical copy of the transcript-prescribed soft note.

- [ ] **Step 4: Verify the authored and composed contracts.**

Run: `rg -n 'worker|orchestrator|mergify-stack|stack-land --tip' modules/home/ai/plugins/version-control-and-forge/.apm/skills/git-stacked-pr-integration/SKILL.md`.

Expected: every ownership boundary and role appears in the first-party source.

Run: `COMPOSED=$(nix build --option builders '' .#apm-skills-compose --no-link --print-out-paths) && rg -n 'mergify-stack|stack-land --tip' "$COMPOSED/.claude/skills/git-stacked-pr-integration/SKILL.md"`.

Expected: the composed first-party skill contains both pointers, and the build exits 0.

- [ ] **Step 5: Commit only the first-party skill.**

Run: `git add modules/home/ai/plugins/version-control-and-forge/.apm/skills/git-stacked-pr-integration/SKILL.md && git commit -m "docs(agent-skills): converge stacked landing policy"`.

Expected: `git diff-tree --no-commit-id --name-only -r HEAD` prints only the first-party skill path.

Rollback: revert this prose commit without changing the delivered upstream skill.

### Task 4: Emit the role-conditioned stacked landing protocol

**Files:**

- Modify: `modules/home/tools/agents-md.nix`
- Reference: `openspec/changes/integrate-mergify-stacked-landing/specs/skill-corpus-interface/spec.md`
- Reference: `modules/home/ai/plugins/version-control-and-forge/.apm/skills/git-stacked-pr-integration/SKILL.md`

**Interfaces:**

- Consumes: Task 3's worker-orchestrator contract, the existing dispatch-unit, VCS-detection, generic commit, jj working-copy, hazard, recovery, worktree-interop, and OMP containment rules, and both skill names.
- Produces: a short user-context-tier protocol in the rendered AGENTS text with one publication owner, explicit stacked-delivery precedence, and no project-level superset.

- [ ] **Step 1: Locate every governing paragraph before editing.**

Run: `rg -n 'Dispatch unit and version control mode|Commit behavior override|Making changes in jj-managed|Working-copy hazards|Worktree interop|containment de-duplication' modules/home/tools/agents-md.nix`.

Expected: every existing contract is found under `Version control and work dispatch` or its OMP containment source.

- [ ] **Step 2: Add the concise subsection under `Version control and work dispatch`.**

Use this role content, adjusting only Markdown heading depth to match the surrounding Nix string.

```markdown
## Stacked landing protocol

This user-context tier assigns stacked-delivery roles, and project context must never become a superset of the user-level context.
The dispatched unit remains an OpenSpec change, normally bound to one Linear story; each independently shippable delivery step is encoded as one commit and one pull request.
A worker prepares and verifies one step, maintains its one delivery commit, and returns its ref and evidence without publishing or landing.
Corrections amend or update that same delivery commit; this narrowly overrides the generic atomic-commit and no-amend rule for the stack unit, but never permits rewriting unrelated history outside it.
The orchestrator alone orders the delivery commits, publishes the pull-request stack, confirms the active VCS mode and landing preconditions, and invokes the selected landing mechanism.
Repository-mode detection selects local authoring and working-copy mechanics; it does not change stack identity, pull-request bookkeeping, or the landing contract.
In a git-native repository, consult `git-stacked-pr-integration` for fleet policy and `mergify-stack` for the upstream mechanism, then use the existing `stack-land --tip REV PR...` handler for the checked final operation.
In a repository containing `.jj/`, the existing development-join, shared working-copy, hazard, recovery, and worktree-interop rules remain authoritative for local operations.
we start with git… The `Change-Id` format is shared, so switching the orchestrator or individual workers to jj changes nothing about identity, PR bookkeeping, or landing. The signal to switch is conflict volume in the orchestrator step, not preference.
```

- [ ] **Step 3: Check the subsection's precedence against every surrounding contract.**

Run: `rg -n 'Dispatch unit and version control mode|Commit behavior override|Making changes in jj-managed|Working-copy hazards|Worktree interop|containment de-duplication|Stacked landing protocol' modules/home/tools/agents-md.nix`.

Expected: every governing section remains present once; the OpenSpec dispatch unit and one-commit/one-PR encoding are explicit; VCS detection changes only local mechanics; the stacked protocol narrowly overrides the generic commit rule for its delivery commit; unrelated history is protected; jj working-copy, hazard, recovery, and worktree rules remain authoritative; and project context cannot become a superset of user-level context.

Run: `nix eval --option builders '' --option allow-import-from-derivation false --raw .#darwinConfigurations.stibnite.config.home-manager.users.crs58.programs.agents-md.settings.text | rg -Fxc 'we start with git… The `Change-Id` format is shared, so switching the orchestrator or individual workers to jj changes nothing about identity, PR bookkeeping, or landing. The signal to switch is conflict volume in the orchestrator step, not preference.'`.

Expected: `1`.

- [ ] **Step 4: Evaluate the rendered user context.**

Run: `nix eval --option builders '' --option allow-import-from-derivation false --raw .#darwinConfigurations.stibnite.config.home-manager.users.crs58.programs.agents-md.settings.text | rg -n -A20 -B3 'Stacked landing protocol'`.

Expected: the rendered text contains the role, precedence, routing, authoritative-jj-contract, literal soft-note, and OMP-containment statements under `Version control and work dispatch`.

- [ ] **Step 5: Commit only the generator source.**

Run: `git add modules/home/tools/agents-md.nix && git commit -m "docs(agents): add stacked landing role protocol"`.

Expected: `git diff-tree --no-commit-id --name-only -r HEAD` prints only `modules/home/tools/agents-md.nix`.

Rollback: revert this generator commit without editing any generated `AGENTS.md` file.

### Task 5: Verify the integrated planning contract without landing

**Files:**

- Verify: `openspec/changes/integrate-mergify-stacked-landing/`
- Verify: the six pre-review implementation paths in the File Map.

**Interfaces:**

- Consumes: the first four independently shippable implementation steps and their commits before review remediation.
- Produces: evidence for the later `verify.md` artifact without activating a configuration or landing a pull-request stack.

- [ ] **Step 1: Validate the OpenSpec change.**

Run: `openspec validate integrate-mergify-stacked-landing --strict`.

Expected: strict validation succeeds with no errors.

- [ ] **Step 2: Re-run source and binary release alignment.**

Run: `test "$(nix eval --option builders '' --option allow-import-from-derivation false --raw .#packages.aarch64-darwin.agent-plugins-mergify-cli.version)" = "$(nix eval --option builders '' --option allow-import-from-derivation false --raw .#packages.aarch64-darwin.mergify-cli-bin.version)"`.

Expected: exit status 0 and the common value is `2026.8.31.1`.

- [ ] **Step 3: Rebuild the composed corpus and inspect both owners.**

Run: `COMPOSED=$(nix build --option builders '' .#apm-skills-compose --no-link --print-out-paths) && test -f "$COMPOSED/.claude/skills/mergify-stack/SKILL.md" && test -f "$COMPOSED/.claude/skills/git-stacked-pr-integration/SKILL.md" && test -f "$COMPOSED/.agents/skills/mergify-stack/SKILL.md" && test -f "$COMPOSED/.agents/skills/git-stacked-pr-integration/SKILL.md"`.

Expected: the build and all four file assertions exit 0.

- [ ] **Step 4: Re-evaluate the generated protocol.**

Run: `nix eval --option builders '' --option allow-import-from-derivation false --raw .#darwinConfigurations.stibnite.config.home-manager.users.crs58.programs.agents-md.settings.text | rg -n -A12 -B3 'Stacked landing protocol'`.

Expected: the rendered user context contains the worker, orchestrator, Git-native, jj, skill, and `stack-land` routing statements.

- [ ] **Step 5: Confirm all canonical distribution conflicts remain explicit and undischarged.**

Run: `rg -n 'agent-skills.*claude.*codex.*hermes|apm MUST NOT run|~70 absolute' openspec/specs/first-party-skill-distribution/spec.md && rg -n '0efe4489f4|953b0ff9c1|6961d7a4d9|Deferred canonical reconciliation' openspec/changes/integrate-mergify-stacked-landing/design.md`.

Expected: the change records the two-target-plus-fan-out, apm-execution, and absolute-autoload-reference conflicts, while the older canonical requirements remain unchanged for later reconciliation.

- [ ] **Step 6: Audit the exclusions against the integrated-main boundary.**

Commit `47ca9d8dec2cf10a985e8e6587e10a87c3df741b` is the recorded integrated-main boundary after the deliberate `origin/main` integration.
Its changes to `pkgs/by-name/stack-land/stack-land.sh` and `pkgs/by-name/stack-land/test-stack-land.sh` are integrated-main provenance, not CAM-41 feature edits.

Run: `git diff --name-only 47ca9d8dec2cf10a985e8e6587e10a87c3df741b..HEAD`.

Expected after Task 6: the implementation portion contains only the seven feature paths in the File Map, while the same range also contains this change's OpenSpec artifacts.
The earlier Task 5 checkpoint contained the six pre-review paths before Task 6 added the release-alignment check.

Expected: no path names Cognee, `pkgs/by-name/mergify-cli-bin/`, a home-manager Mergify installation, `pkgs/by-name/stack-land/`, `modules/home/tools/stack-land.nix`, nixbot or ruleset settings, or `apm.lock.yaml`.

- [ ] **Step 7: Confirm each implementation commit is independently reversible.**

Run: `git log --format='%h %s' -- pkgs/by-name/agent-plugins/mergify-cli/package.nix modules/home/ai/plugins/version-control-and-forge/apm.yml pkgs/by-name/apm-skills-compose/package.nix modules/home/ai/plugins/README.md modules/home/ai/plugins/version-control-and-forge/.apm/skills/git-stacked-pr-integration/SKILL.md modules/home/tools/agents-md.nix`.

Expected: each newly edited file first appears in its own atomic commit, and no commit mixes two File Map paths.

- [ ] **Step 8: Stop before activation or landing.**

Do not activate home-manager, invoke `stack-land`, mutate GitHub, change Linear, or create a real pull-request stack as part of this change's acceptance evidence.

### Task 6: Reconcile accepted review findings before reverification

**Files:**

- Modify: `modules/home/ai/plugins/version-control-and-forge/.apm/skills/git-stacked-pr-integration/SKILL.md`
- Modify: `modules/home/tools/agents-md.nix`
- Create: `modules/checks/structure/mergify-release-alignment.nix`
- Correct without tracking: `.superpowers/sdd/task-2-report.md`
- Verify unchanged: `apm.lock.yaml`
- Verify unchanged from Task 2: `pkgs/by-name/apm-skills-compose/package.nix`
- Reference: `pkgs/by-name/stack-land/stack-land.sh`
- Reference: `pkgs/by-name/stack-land/test-stack-land.sh`

**Interfaces:**

- Consumes: the reported-check predicate in merged `stack-land`, the reviewed role boundary, both Mergify package versions from the fully composed per-system output, and the separate Nix-composed and root-lock materialization paths.
- Produces: one publication owner, exact reported-check policy, scoped empirical evidence, a build-time release-alignment check with a genuine failing-case control, and evidence for a fresh verification report.

- [ ] **Step 1: Confirm the merged handler's reported-check predicate.**

Run: `git show origin/main:pkgs/by-name/stack-land/stack-land.sh | rg -n 'SUCCESS|NEUTRAL|SKIPPED|state !='`.

Run: `git show origin/main:pkgs/by-name/stack-land/test-stack-land.sh | rg -n 'neutral check|skipped check|failing|undecided|unrecognised'`.

Expected: every supplied pull request must report at least one check; only `SUCCESS`, `NEUTRAL`, and `SKIPPED` pass; failing, pending, and unrecognized conclusions block.

- [ ] **Step 2: Correct the first-party policy and its evidence boundary.**

Make the worker prepare and verify one change and return its ref and evidence without publishing or landing.
Make the orchestrator alone order the refs, publish the pull-request stack through `mergify-stack`, and invoke `stack-land` for landing.
In `Checked landing boundary`, replace the all-`SUCCESS` claim with the exact nonempty `SUCCESS`/`NEUTRAL`/`SKIPPED` predicate and state that pending, failing, and other conclusions block.
Keep the following base sentence byte-identical and add adjacent prose limiting it to the observed fast-forward landing and GitHub reachability, not Mergify authoring or publication.

```text
The pattern was verified landing PRs 2738, 2739, and 2740 in cameronraysmith/vanixiets on 2026-08-18: main was fast-forwarded to fe5a4b71 and GitHub merged all three PRs by reachability within one second.
```

Run: `rg -n 'Role contracts|Requirement-to-mechanism map|Checked landing boundary|SUCCESS|NEUTRAL|SKIPPED|pending|publish' modules/home/ai/plugins/version-control-and-forge/.apm/skills/git-stacked-pr-integration/SKILL.md`.

Expected: the named sections expose one publication owner and the exact check-state boundary without copying the upstream recipe.

- [ ] **Step 3: Commit only the corrected first-party skill.**

Run: `git add modules/home/ai/plugins/version-control-and-forge/.apm/skills/git-stacked-pr-integration/SKILL.md && git commit -m "docs(agent-skills): correct stacked landing policy"`.

Expected: `git diff-tree --no-commit-id --name-only -r HEAD` prints only the skill path.

- [ ] **Step 4: Correct and evaluate the generated user-context owner.**

In `Stacked landing protocol`, state that the worker returns its delivery commit and evidence without publishing and that the orchestrator alone orders refs, publishes their pull-request stack, and lands it.
Keep the surrounding dispatch-unit, stacked-commit precedence, VCS, jj, worktree, and OMP containment contracts unchanged.

Run: `nix eval --option builders '' --option allow-import-from-derivation false --raw .#darwinConfigurations.stibnite.config.home-manager.users.crs58.programs.agents-md.settings.text | rg -n -A12 -B3 'Stacked landing protocol'`.

Expected: the rendered section exposes the corrected publication owner and all retained boundaries.

- [ ] **Step 5: Commit only the corrected generator.**

Run: `git add modules/home/tools/agents-md.nix && git commit -m "docs(agents): assign stack publication to orchestrator"`.

Expected: `git diff-tree --no-commit-id --name-only -r HEAD` prints only `modules/home/tools/agents-md.nix`.

- [ ] **Step 6: Enforce release alignment from the full flake output.**

Keep `pkgs/by-name/apm-skills-compose/package.nix` at its committed Task 2 state.
Remove the uncommitted package-level assertion attempt before staging the new check.
Do not add a package-level version assertion: reaching the binary through the flake output from inside the package re-enters the package fixpoint.
Create `modules/checks/structure/mergify-release-alignment.nix`; `import-tree` auto-discovers the module, so no central registration file changes.

Follow the full-flake structure-check routing documented by `modules/lib/mk-eval-check.nix` and the custom `runCommand` comparison pattern in `modules/checks/aeneas-toolchain.nix`.
The module must define one shared checker and register both check attributes in this shape.

```nix
{ ... }:
{
  perSystem =
    { pkgs, self', ... }:
    let
      checkAlignment = pkgs.writeShellScript "check-mergify-release-alignment" ''
        set -u
        sourceVersion="$1"
        binaryVersion="$2"

        if [ "$sourceVersion" != "$binaryVersion" ]; then
          echo "structure-mergify-release-alignment: release mismatch" >&2
          echo "  agent-plugins-mergify-cli: $sourceVersion" >&2
          echo "  mergify-cli-bin: $binaryVersion" >&2
          exit 1
        fi
      '';

      mkAlignmentCheck =
        {
          name,
          sourceVersion,
          binaryVersion,
        }:
        pkgs.runCommand name
          {
            inherit sourceVersion binaryVersion;
          }
          ''
            set -euo pipefail
            ${checkAlignment} "$sourceVersion" "$binaryVersion"
            touch "$out"
          '';
    in
    {
      checks = {
        structure-mergify-release-alignment = mkAlignmentCheck {
          name = "structure-mergify-release-alignment";
          sourceVersion = self'.packages.agent-plugins-mergify-cli.version;
          binaryVersion = self'.packages.mergify-cli-bin.version;
        };

        structure-mergify-release-alignment-neg =
          pkgs.runCommand "structure-mergify-release-alignment-neg"
            {
              nativeBuildInputs = [ pkgs.gnugrep ];
            }
            ''
              set -euo pipefail
              mismatchLog="$TMPDIR/mismatch.log"
              if ${checkAlignment} source-fixture binary-fixture 2>"$mismatchLog"; then
                echo "release-alignment checker accepted unequal fixtures" >&2
                exit 1
              fi
              grep -F 'agent-plugins-mergify-cli: source-fixture' "$mismatchLog"
              grep -F 'mergify-cli-bin: binary-fixture' "$mismatchLog"
              touch "$out"
            '';
      };
    };
}
```

`self'.packages` is the per-system projection of the fully composed flake package output.
The normal derivation therefore receives the evaluated package versions without making either package depend on the flake output that contains it.
The negative control invokes the same executable comparison logic with unequal fixtures, requires that invocation to fail, and checks that its diagnostic names both values.

Run: `nix build --option builders '' .#checks.aarch64-darwin.structure-mergify-release-alignment-neg --no-link --print-out-paths`.

Expected: the negative-control build succeeds only because the shared checker rejects `source-fixture` versus `binary-fixture` and reports both values.

Run: `nix build --option builders '' .#checks.aarch64-darwin.structure-mergify-release-alignment --no-link --print-out-paths`.

Expected: the normal check reads both package versions as `2026.8.31.1` after full flake evaluation and builds successfully.

Run: `nix build --option builders '' .#apm-skills-compose --no-link --print-out-paths`.

Expected: composition succeeds and retains both `mergify-stack/SKILL.md` outputs without a package-level release assertion.

- [ ] **Step 7: Commit only the release-alignment check.**

Run: `git add modules/checks/structure/mergify-release-alignment.nix && git commit -m "test(checks): enforce Mergify release alignment"`.

Expected: `git diff-tree --no-commit-id --name-only -r HEAD` prints only `modules/checks/structure/mergify-release-alignment.nix`, while `git diff --quiet HEAD -- pkgs/by-name/apm-skills-compose/package.nix` confirms that the composition derivation retains its Task 2 state.

- [ ] **Step 8: Preserve and report the repository-local materialization boundary.**

Run: `git diff --quiet 33f94e2ce..HEAD -- apm.lock.yaml && ! rg -q 'Mergifyio/mergify-cli|mergify-stack' apm.lock.yaml`.

Expected: the root lock is unchanged and still lacks the new upstream dependency.
The unchanged root lock establishes only that a fresh frozen `just agents-install` before relock would materialize the pre-change set; do not infer the contents of any existing ignored repository-local `.agents/` tree.
Record the mandatory follow-up: after this change reaches `main`, run `just agents-relock` on a separate branch, review and commit the generated root lock, and only then use the frozen producer path as repository-local `mergify-stack` delivery evidence.

- [ ] **Step 9: Correct the ignored Task 2 report without committing it.**

Replace the final sentence claiming GREEN remains blocked with a conclusion consistent with its recorded normalized-shard success.

Run: `git check-ignore -q .superpowers/sdd/task-2-report.md && ! rg -q 'GREEN remains blocked' .superpowers/sdd/task-2-report.md`.

Expected: the contradiction is absent and `git status --short` does not list the ignored report.

- [ ] **Step 10: Revalidate and hand evidence to post-Task-6 verification.**

Run: `openspec validate integrate-mergify-stacked-landing --strict`.

Expected: strict validation succeeds after all Task 6 corrections, and fresh builds of `structure-mergify-release-alignment-neg` and `structure-mergify-release-alignment` pass.
Hand the focused Task 6 outputs to the subsequent verifier.
Completing Task 6 records this handoff; it does not regenerate `verify.md`.
The subsequent verifier owns regeneration and MUST produce a fresh `verify.md` before final acceptance.
That report must identify evidence by named check attribute, package attribute, Markdown section, or command and must not cite implementation line numbers.

Rollback: revert the release-alignment check, generated-context correction, and first-party policy correction commits in reverse order; the ignored report correction and post-merge relock follow-up require no rollback in this branch.
