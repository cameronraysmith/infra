# Nix-first Pi agent environment implementation plan

> **For agentic workers:** Execute this plan task-by-task, preserve assertion-level RED before production behavior, and stop before activation.

**Goal:** Configure Pi 0.84.1 as a reproducible Nix-first environment with one source-only extension package, exact resources, Catppuccin Mocha, compact fail-closed policy, three independent regulators, and a human-only activation boundary.

**Architecture:** Home Manager composes one pinned rytswd source package, exact positive filters, retained compaction, canonical skills, immutable theme and policy resources, Nix-owned global instructions, and a mutable settings seed.
One ordinary flake-parts logical-group module exposes three separately input-addressed derivations: a compact structural oracle comparison, a pure table-driven policy check, and one actual-binary aggregate RPC smoke.
Permission-gate owns Bash parsing and project-trust behavior, while a pure first-party decision core plus thin Pi adapter owns direct non-Bash edit and write boundaries.

**Tech Stack:** Nix, flake-parts/import-tree, Home Manager, `fetchFromGitHub`, TypeScript, Pi 0.84.1 extension and RPC APIs, Bun-compiled Pi, and hermetic flake checks.

## Global constraints

- Preserve Pi 0.84.1 through `llm-agents`.
- Add exactly one new by-name package: source-only `pi-agent-extensions` at commit `c700f300707db5345727052682c88e3064030aa2` with hash `sha256-RLtDi9ahKONSJBuuYkYo/oIIxDX6PWiZ7rlevOStUUk=`.
- Reject `node_modules` in the package derivation and perform no npm installation.
- Preserve ordinary package realization and add pre-activation scope and diff evidence for exactly one new by-name package and no flake input.
- Leave `modules/checks/packages.nix` unmodified; its existing auto-map must expose `package-pi-agent-extensions`.
- Add no flake input, aggregate Pi package, standalone theme package, `pi-ultracode`, or `~/.pi/agent/skills` sink.
- Add no `modules/checks/fixtures` directory or failure-isolation behavior.
- Enable exactly `direnv`, `permission-gate`, `questionnaire`, `slow-mode`, `stash`, and `statusline` through full package-relative positive paths.
- Retain explicit exclusions for `fetch` and `notify` and retain `pi-openai-server-compaction`.
- Add exactly `direnv`, `diffutils`, `git`, `jujutsu`, and `rip2` to Pi's Nix runtime PATH.
- Configure runtime environment indirection through direnv while keeping sentinel secret values out of Nix expressions, store files, and generated configuration; do not claim upstream direnv value-supply behavior.
- Keep slow-mode opt-in.
- Reuse the pinned permission-gate parser, rule API, built-in rules, project-trust boundary, and headless behavior for Bash.
- Implement non-Bash edit/write policy as a pure decision core over typed discriminated repository state with injected capabilities and a thin Pi adapter exported through a directly invocable factory or handler seam.
- Admit healthy ordinary and diamond-managed jj repositories under distinct predicates; do not require working-copy cleanliness.
- Classify a repository as diamond-managed only after a separate bookmark-listing probe reports the `wip` convention, including a divergent indicator; only then run unique `wip` resolution and admit absent/moved/divergent failure rows.
- Keep repositories with no `wip` report eligible for ordinary classification and never route them through missing-`wip` failure.
- Use `jj --ignore-working-copy` at the start of every read-only jj policy probe and block failed, malformed, or ambiguous probe results diagnostically.
- Execute the actual adapter seam for synthetic allow/block translation, unrelated-tool pass-through, malformed input, and core or capability exceptions while retaining separate pure-core cases and no Pi process per policy row.
- Define exactly three custom Pi derivations in `modules/checks/pi-agent-environment.nix`: structural, policy, and smoke.
- Keep each derivation's declared inputs and cache boundary independent despite physical co-location.
- Introduce every new-behavior witness before production behavior.
- Every RED witness must evaluate and fail through its expected assertion, never a missing attribute, absent import, undefined binding, evaluator error, module-not-found exception, or malformed harness.
- Treat the Nix sandbox, not `PI_OFFLINE=1` alone, as the smoke regulator's network boundary.
- Treat the disposable discovery run as characterization, not assertion-level hermetic proof: the exact installed/deployed Pi 0.84.1 wrapper from the current locked package used credential-free provider `review-local`, model id `review-model`, inert base URL `http://127.0.0.1:9/v1`, API `openai-completions`, no `apiKey`, and explicit `--model review-local/review-model`; `get_state` returned that model, no prompt or provider request occurred, and stdin closure exited zero.
- Do not hardcode the discovered Nix store hash as a future contract.
- Reproduce that behavior in the assertion-level hermetic derivation because default settings may report `unknown/unknown`.
- After the supported RPC queries, close stdin and require clean exit status.
- If hermetic reproduction differs from the discovery characterization, including an exact deployed-package mismatch, stop and ask rather than weakening the contract.
- Limit RPC claims to supported state, command, diagnostic, readiness, and process-exit surfaces.
- External delegation remains available through existing Herdr and is unchanged and outside scope; make no Herdr package or configuration changes.
- Integration of `nicobailon/pi-subagents` remains deferred to a separate future change and is not a general safety judgment about upstream.
- Never run `just activate --ask`; only Cameron may run it.

---

## Task 1: Establish independent check surfaces and the source-only package

**Files:**

- Create: `modules/checks/pi-agent-environment.nix`
- Create: `pkgs/by-name/pi-agent-extensions/package.nix`
- Modify ledger only: `openspec/changes/configure-pi-agent-environment/tasks.md`
- Leave unmodified: `modules/checks/packages.nix`

**Interfaces:**

- Produces `packages.pi-agent-extensions` and the existing auto-mapped `checks.package-pi-agent-extensions`.
- Produces custom check attributes `pi-agent-environment-structural`, `pi-agent-environment-policy`, and `pi-agent-environment-smoke` as three independent derivations.
- Supplies the pinned package source to later Home Manager and policy tasks.

- [ ] **Step 1: Scaffold exactly three independent check attributes**

Create one ordinary `perSystem` logical-group module.
Define three derivations separately rather than wrapping one derivation around three scripts.
Give each derivation only its own inputs; policy and smoke begin as evaluable sentinel harnesses.
Do not evaluate `self'.checks` from the structural check.

- [ ] **Step 2: Add compact structural assertion-level RED**

Import `flake.lib.mkStructuralCheck` from the flake library surface established by `modules/lib/mk-structural-check.nix`.
Construct an `actual` attrset from guarded evaluated values and an `expected` literal attrset.
Include evaluated `programs.pi-coding-agent.package` version `0.84.1` in the compact literal oracle.
Serialize only compact values such as the package version, ordered selector strings, booleans, package names, target paths, and digests.

Run:

```bash
system=$(nix eval --impure --raw --expr builtins.currentSystem)
nix build ".#checks.${system}.pi-agent-environment-structural"
```

Expected: evaluation succeeds and the derivation fails with the unified diff from `mkStructuralCheck`, naming the missing compact fields rather than failing on an absent import or attribute.

- [ ] **Step 3: Create the source-only package**

Implement `pkgs/by-name/pi-agent-extensions/package.nix` with `fetchFromGitHub`, the exact commit and hash, and a copy-only install phase.
Add a derivation-time assertion that fails if the fetched or installed tree contains a `node_modules` directory.
Do not run npm, add a package-local test derivation, or add another flake input.

- [ ] **Step 4: Confirm the ordinary auto-map without modifying it**

Evaluate the current-system check names and verify that `package-pi-agent-extensions` appears because `modules/checks/packages.nix` maps all non-blacklisted packages.
Do not add an explicit entry to that file.

Run:

```bash
system=$(nix eval --impure --raw --expr builtins.currentSystem)
nix eval --json ".#checks.${system}" --apply builtins.attrNames \
  | jaq -e 'index("package-pi-agent-extensions") != null'
```

Expected: `true` with exit zero.
This proves ordinary package-map exposure, not the final exactly-one-package or no-flake-input scope claim, which remains assigned to the pre-activation diff scan.

- [ ] **Step 5: Realize the package**

Run:

```bash
system=$(nix eval --impure --raw --expr builtins.currentSystem)
nix build ".#checks.${system}.package-pi-agent-extensions"
```

Expected: the fixed-output source realizes, the copy-only installation succeeds, and the `node_modules` rejection remains silent because no such directory exists.

- [ ] **Step 6: Record the atomic commit**

Commit only the logical-group check module, package derivation, and tasks ledger for this task.
The commit must not include `modules/checks/packages.nix` or any fixture path.

Suggested message: `feat(pi): package pinned extension sources`

## Task 2: Compose exact resources, state ownership, global instructions, and Catppuccin

**Files:**

- Modify: `modules/checks/pi-agent-environment.nix`
- Modify: `modules/home/ai/pi/default.nix`
- Create: `modules/home/ai/pi/themes/catppuccin-mocha.json`
- Modify ledger only: `openspec/changes/configure-pi-agent-environment/tasks.md`

**Interfaces:**

- Consumes `pi-agent-extensions` from Task 1.
- Produces the exact Home Manager package filter, runtime executable set, mutable-copy activation form, immutable resource links, canonical skill relationship, selected theme, and Nix-owned global instructions.
- Supplies compact evaluated values to the structural derivation and one valid aggregate configuration to the later smoke derivation.

- [ ] **Step 1: Add exact resource assertion-level RED**

Extend the compact structural `actual` value with guarded fields for:

```nix
{
  piPackageVersion = "0.84.1";
  positiveExtensions = [
    "direnv/index.ts"
    "permission-gate/index.ts"
    "questionnaire/index.ts"
    "slow-mode/index.ts"
    "stash/index.ts"
    "statusline/index.ts"
  ];
  negativeExtensions = [ "-fetch/index.ts" "-notify/index.ts" ];
  packageSkills = [ ];
  packagePrompts = [ ];
  packageThemes = [ ];
  extraPackages = [ "direnv" "diffutils" "git" "jujutsu" "rip2" ];
  compactionRetained = true;
  globalInstructionsNixOwned = true;
  canonicalSkills = "~/.agents/skills";
  piSpecificSkillsPresent = false;
}
```

Run the structural derivation.
Expected: a named JSON diff shows the absent or stale evaluated Pi package version and resource composition while evaluation remains valid.

- [ ] **Step 2: Configure exact package resources**

Use the literal ordered filter with six positive selectors followed by `-fetch/index.ts` and `-notify/index.ts`.
Set skills, prompts, and themes from `pi-agent-extensions` to empty lists.
Retain `pi-openai-server-compaction` as a separate package entry.
Set `extraPackages` to exactly `direnv`, `diffutils`, `git`, `jujutsu`, and `rip2`.

- [ ] **Step 3: Add ownership and state assertion-level RED**

Add compact structural fields for the mutable `settings.json` activation copy; the Pi-managed runtime-state categories that Home Manager does not convert into immutable executable-resource links; immutable policy, theme, extension, and global-instruction targets; Nix-owned `context`; the canonical skill sink; and the absent Pi-specific skill sink.
Represent live writability as outside the structural oracle; the structural value may assert declarations, representative target paths, and activation form, not runtime permissions or an exhaustive inventory of every possible Pi path.

Run the structural derivation.
Expected: the diff identifies each missing ownership field, including global instructions.

- [ ] **Step 4: Preserve mutable settings and runtime state declarations**

Keep the `lib.hm.dag.entryAfter [ "writeBoundary" ]` replacement copy for `settings.json`.
Within Pi-managed paths, do not convert runtime-managed settings, sessions, compaction, authentication, project trust, model selection, thinking preferences, or extension state into immutable executable-resource links.
Keep executable policy, theme, extensions, and global instructions immutable.
Keep global instructions supplied through `programs.pi-coding-agent.context` from the Nix-managed agents-md text.
Add no `.pi/agent/AGENTS.md` destination elsewhere.

- [ ] **Step 5: Add theme assertion-level RED**

Guard the absent destination and compare the selected name, target immutability, SHA-256, and absence of a standalone theme package with literals.
Do not claim that commit/path metadata alone proves upstream provenance.

Run the structural derivation.
Expected: the unified diff names the missing theme content and delivery fields.

- [ ] **Step 6: Acquire and link Catppuccin**

Read `themes/catppuccin-mocha.json` at `aldoborrero/pi-agent-kit` commit `128c4c08396961ea8f934111ba1aad0b33c525b2`, copy it byte-for-byte, and verify:

```text
5858d086e155246d48e5b7a2ac372988fe2d1a028d2b77b5f0a7670088a8642b
```

Link the checked-in file immutably and select `catppuccin-mocha`.
Create no standalone package.

- [ ] **Step 7: Make structural composition GREEN**

Run the structural derivation and relevant Home Manager evaluation or build.
Expected: evaluated Pi package version `0.84.1`, exact filters, empty resource kinds, runtime executables, compaction, mutable-copy activation, immutable policy/theme/extensions/global instructions, canonical skills, selected theme, and digest match the compact oracle.
The result does not claim runtime loading, live writability, package-output behavior, or upstream provenance beyond the reviewed acquisition record.

- [ ] **Step 8: Record the atomic commit**

Commit the Pi Home Manager module, theme file, structural-check update, and tasks ledger.

Suggested message: `feat(pi): compose exact Nix-owned resources`

## Task 3: Implement table-driven Bash and non-Bash policy

**Files:**

- Modify: `modules/checks/pi-agent-environment.nix`
- Create: `modules/home/ai/pi/policy/permission-rules.ts`
- Create: `modules/home/ai/pi/policy/edit-write-policy.ts`
- Modify: `modules/home/ai/pi/default.nix`
- Modify ledger only: `openspec/changes/configure-pi-agent-environment/tasks.md`

**Interfaces:**

- Consumes the pinned permission-gate source from Task 1.
- Produces Nix-owned shell rules using the pinned parser/rule API.
- Produces a pure edit/write decision function over injected filesystem, Git, jj, and interaction capabilities lowered into typed discriminated repository state, plus a thin Pi `tool_call` adapter with an exported factory or handler seam.
- Produces one `pkgs.writeText`-backed case table consumed only by `pi-agent-environment-policy`, including separate pure-core rows and direct executable-adapter rows.

- [ ] **Step 1: Add Bash table assertion-level RED**

Follow `modules/checks/hooks.nix`: serialize cases with `pkgs.writeText`, iterate rows inside one derivation, collect failures, and fail once with all mismatches.
Cover literal `allow`, `prompt`, and `block` outcomes for safe commands, dangerous built-ins, direct and composed `rm`, worktree creation, Pi `install`/`remove`/`uninstall`/`update`, and semantic curl/wget mutation forms including separate values, `--name=value`, and glued short options.
Import the pinned parser and rule modules through guarded inputs so the initial failure is a named missing-policy assertion.

- [ ] **Step 2: Add project-trust boundary RED**

Add rows for untrusted project JSON attempts to replace rules, disable block rules, disable protected prompt rules, and disable headless prompt rules.
Require the pinned compile path to refuse or surface each weakening attempt according to its existing contract.

Run:

```bash
system=$(nix eval --impure --raw --expr builtins.currentSystem)
nix build ".#checks.${system}.pi-agent-environment-policy"
```

Expected: the derivation runs the table and fails only named missing/custom-decision rows.

- [ ] **Step 3: Implement semantic shell rules**

Use the pinned permission-gate `GateHelpers` and `RuleEntry` interfaces.
Classify mutating HTTP requests through parsed argv rather than raw substring matching.
Block `rm` with `rip` guidance, block Pi package mutation with Nix-pin guidance, and return prompt decisions for mutating HTTP and worktree creation.
Preserve the pinned project-trust merge and headless behavior unchanged.

- [ ] **Step 4: Add pure non-Bash and typed-repository RED tables**

Define direct core inputs for `edit` and `write` and injected capability results for mutable paths, `/nix/store`, declared immutable roots, Git feature branches, Git `main`, and Git `master`.
Lower repository inspection into an exhaustively handled discriminated input with outside-repository, Git, ordinary jj, diamond-managed jj, and invalid diagnostic variants.
Add literal jj rows in this order: ordinary healthy; ordinary healthy with nonempty `@`; ordinary conflict; ordinary divergent `@`; ordinary `main`/`master` at `@`; an actual healthy empty `@` `[wip]` over an empty six-parent `@-` join; healthy nonempty `[wip]`; healthy conflict-resolved nonempty join; classified-diamond missing, moved, or divergent `wip`; non-single-parent `[wip]`; single-parent join; conflicted join; conflicted immediate join parent; join-parent count mismatch; and malformed or failing join probe.
Common jj health requires canonical repository identity and canonical target containment, unambiguous conflict-free `@`, non-divergent current `@` identity, neither `main` nor `master` pointing directly to `@`, and successful unambiguous probes.
A separate bookmark-listing classification probe selects diamond mode only when it reports the `wip` convention, including a divergent indicator.
Only then does the unique `wip`-resolution probe return the healthy, absent, moved, or divergent result used by diamond rows.
A repository with no `wip` report remains eligible for ordinary mode and never reaches a missing-`wip` row.
Diamond mode additionally requires `@` to be the `[wip]` commit with exactly one parent and exactly one non-divergent `wip` bookmark pointing to it.
It probes `@-` separately as the `[merge]` join, requires that join to be nonconflicted with at least two parents, and probes `parents(@-)` separately to require conflict-free immediate parents whose count matches the join report.
Neither `@` nor `@-` must be empty, and diamond mode imposes no working-copy-cleanliness requirement.
Ordinary mode has no `wip`, diamond-topology, emptiness, or working-copy-cleanliness requirement.
Record every process argv in the fake capability and compare the complete ordered argv list with a literal oracle in addition to requiring every read-only jj argv to start with `jj --ignore-working-copy`.

- [ ] **Step 5: Add executable thin-adapter RED, then implement the core and adapter**

Invoke the exported adapter factory or handler directly with synthetic Pi tool calls before production behavior exists.
Cover edit and write allow translation, edit and write diagnostic block translation, unrelated-tool pass-through, malformed tool input, and core or capability exceptions.
Keep the pure-core table separate and start no Pi process per policy row.
Expected RED: named adapter assertions fail before the adapter exists or translates all cases, without a missing import or malformed harness.
Then keep filesystem, Git, jj, and interaction effects behind injected interfaces, return an explicit allow/prompt/block decision from the pure core, and exhaustively match repository-state variants.
Translate only Pi `edit` and `write` `tool_call` events in the adapter, pass unrelated tools through, translate blocks to Pi's `{ block: true, reason }` result, and turn malformed input plus core or capability exceptions into diagnostic blocks.
Register no delegated-tool policy or unrelated events.

- [ ] **Step 6: Make every fail-closed row GREEN**

Require parser errors, core or adapter exceptions, repository ambiguity, malformed or failed probes, malformed tool input, capability absence/failure, and unavailable interaction to become named diagnostic blocks rather than uncaught exceptions or permission.
Run the policy derivation and inspect complete output.
Expected: every shell, project-trust, pure-core, executable-adapter, Git, ordinary-jj, diamond-jj, argv, and failure row passes without starting Pi per row.

- [ ] **Step 7: Link policy sources immutably and make structural ownership GREEN**

Link both policy files from Nix-owned Home Manager inputs.
Run structural and policy derivations.
Expected: structural ownership, pure policy behavior, and adapter integration behavior pass independently.

- [ ] **Step 8: Record the atomic commit**

Commit the policy source files, Pi Home Manager links, policy/structural check update, and tasks ledger.

Suggested message: `feat(pi): enforce fail-closed mutation policy`

## Task 4: Prove and build one actual-binary aggregate RPC smoke

**Files:**

- Modify: `modules/checks/pi-agent-environment.nix`
- Modify ledger only: `openspec/changes/configure-pi-agent-environment/tasks.md`
- Create no other file.

**Interfaces:**

- Consumes the exact store-backed Home Manager resources and settings from Tasks 2 and 3.
- Produces one independent `pi-agent-environment-smoke` derivation that starts the deployed Pi 0.84.1 Bun binary once.
- Exposes only evidence supported by RPC and process status: readiness, selected model state, visible commands where supported, diagnostics, no provider request, stdin closure, and clean exit.

- [ ] **Step 1: Write the hermetic RPC reproduction RED**

Use the actual `programs.pi-coding-agent.package` binary, a fresh writable `HOME`, a fresh `PI_CODING_AGENT_DIR`, `PI_OFFLINE=1`, no credentials, and the discovery-characterized RPC argv shape:

```text
pi --mode rpc --no-session --no-approve --model review-local/review-model
```

Seed only exact store-backed resources/settings and `models.json` with credential-free provider `review-local`, model id `review-model`, inert base URL `http://127.0.0.1:9/v1`, API `openai-completions`, and no `apiKey`.
The exact installed/deployed Pi 0.84.1 wrapper from the current locked package already returned that model from `get_state`, made no prompt or provider request, and exited zero after stdin closure in a disposable `HOME`; treat that as discovery characterization and do not embed its concrete Nix store hash.
Send no prompt, bash, compaction, or provider-facing command.
The initial assertion must fail by naming the absent hermetic readiness/selected-model evidence, not by timing out silently or parsing malformed JSONL.

- [ ] **Step 2: Reproduce the characterized invocation or stop with a question**

Drive strict LF-delimited JSONL as documented by Pi 0.84.1.
Test `get_state` and `get_commands` before any model call.
Capture the exact supported argv, settings shape, request order, readiness response, selected-model representation, stdin closure, and clean exit status in the smoke derivation itself.
Default settings may report `unknown/unknown`, so explicit `--model review-local/review-model` is mandatory.
Use the credential-free inert registration only for selected startup state and send no prompt or provider-facing request.
If the hermetic reproduction differs from the discovery characterization, including an exact deployed-package mismatch, stop and ask rather than fake success, add credentials, make a provider request, hardcode a store hash, or weaken the assertion.

- [ ] **Step 3: Build one valid aggregate environment**

After Step 2 passes, copy/link the exact generated settings and store-backed extensions, policy, theme, global instructions, and canonical skills into a fresh writable home/agent layout.
Add a unique sentinel only as scan input representing a runtime direnv value; do not require direnv to supply it to Pi.
Keep the sentinel absent from Nix expressions, generated settings, copied configuration, and store-backed resources while structurally asserting runtime-indirection configuration.

- [ ] **Step 4: Start one Pi process and query supported surfaces**

Start exactly one Pi process under the Nix sandbox with `PI_OFFLINE=1` and explicit `--model review-local/review-model`.
Issue `get_state` and `get_commands` only.
Assert Pi 0.84.1 reaches RPC readiness, reports the selected registered model, shows extension/skill commands where RPC exposes them, emits no `extension_error` or resource diagnostic, and makes no provider request.
Do not infer questionnaire tool registration, stash shortcuts, hooks, or theme loading from RPC silence or command output.

- [ ] **Step 5: Prove the actual network and secret boundaries**

Treat the sandbox as the network boundary and `PI_OFFLINE=1` as Pi startup configuration.
Scan generated and copied content for the sentinel secret and require no match.
Keep provider-call commands absent from the request stream.

- [ ] **Step 6: Close stdin and require clean exit**

Close stdin after the supported queries and require a bounded clean exit status with no resource or extension diagnostics.

- [ ] **Step 7: Run the smoke derivation**

Run:

```bash
system=$(nix eval --impure --raw --expr builtins.currentSystem)
nix build ".#checks.${system}.pi-agent-environment-smoke"
```

Expected: one aggregate Pi process reaches readiness, returns supported state/commands, performs no provider call, contains no serialized sentinel secret, and exits cleanly.

- [ ] **Step 8: Record the smoke-only atomic commit**

This commit modifies only `modules/checks/pi-agent-environment.nix` and `openspec/changes/configure-pi-agent-environment/tasks.md`.
It adds no fixture file and no `modules/checks/fixtures` directory.

Suggested message: `test(pi): add aggregate offline RPC smoke`

## Task 5: Remove stale Pi 0.83 provenance through explicit RED

**Files:**

- Modify: `modules/checks/pi-agent-environment.nix`
- Modify: `modules/home/ai/pi/default.nix`
- Modify: `docs/notes/development/ai-agents/pi-integration-reconnaissance.md`
- Modify ledger only: `openspec/changes/configure-pi-agent-environment/tasks.md`

**Interfaces:**

- Produces assertion-level stale-reference evidence inside the structural derivation.
- Produces Pi 0.84.1-only active provenance in both named files.

- [ ] **Step 1: Add both stale-reference assertions before editing either source**

Extend the compact structural value with separate booleans for absence of Pi 0.83 in `modules/home/ai/pi/default.nix` and the reconnaissance note.
Expected literals are `true`; initial guarded actual values must be `false` because both files still carry stale references.

- [ ] **Step 2: Run RED and inspect both named failures**

Run the structural derivation.
Expected: the compact diff identifies both stale-file booleans as false while the check harness itself evaluates correctly.
Do not edit either stale reference until both failures are observed.

- [ ] **Step 3: Update both files to Pi 0.84.1**

Remove active Pi 0.83 references while preserving the approved `llm-agents` package source and accurate historical distinctions.
Do not broaden the change into unrelated reconnaissance cleanup.

- [ ] **Step 4: Run GREEN**

Run the structural derivation and direct stale-reference scans.
Expected: both compact booleans are true and active provenance names Pi 0.84.1.

- [ ] **Step 5: Record the atomic commit**

Commit the two provenance updates, structural scan, and tasks ledger.

Suggested message: `docs(pi): reconcile deployed version provenance`

## Task 6: Reconcile scope and run consolidated pre-activation verification

**Files:**

- Modify task checkboxes only when implementation evidence exists.
- Create no new planning, schema, fixture, or implementation artifact.

**Interfaces:**

- Consumes all implementation tasks.
- Produces external enumeration, scope, traceability, OpenSpec, and pre-activation evidence.

- [ ] **Step 1: Enumerate exactly three custom Pi checks externally**

Run:

```bash
system=$(nix eval --impure --raw --expr builtins.currentSystem)
nix eval --json ".#checks.${system}" --apply builtins.attrNames \
  | jaq -r '.[]' \
  | rg '^pi-agent-environment-'
```

Expected output is exactly:

```text
pi-agent-environment-policy
pi-agent-environment-smoke
pi-agent-environment-structural
```

Also require `package-pi-agent-extensions` in the full check list.
This enumeration remains outside the structural regulator to avoid recursive self-inspection.

- [ ] **Step 2: Run scope scans**

Scan for broad selectors, unexpected packages, unintended positive `fetch`/`notify`, `~/.pi/agent/skills`, secret literals, Pi package mutation instructions, extra custom Pi checks, `modules/checks/fixtures`, reintroduced failure-isolation behavior, and Herdr changes.
Require diff evidence that `pkgs/by-name/pi-agent-extensions/package.nix` is the only new by-name package and that no flake input was added.
Require explicit evidence that the exported adapter seam is invoked and that no-`wip` ordinary eligibility, classified-diamond unique-`wip` resolution, and every literal policy row are present.
Treat the approved negative selectors and policy match literals as intentional data.
Require `git diff --name-only -- modules/checks/packages.nix` to be empty.

- [ ] **Step 3: Run the 25-requirement trace audit**

Parse requirement and scenario headers from the delta spec.
Parse D10 and plan-trace first columns.
Require 25 requirements, 25 scenarios, one scenario per requirement, exact requirement-name equality and order across all three sources, and non-empty checklist/plan routes for every row.
Specifically compare the modalities and routes for `Mutable settings seed`, `Canonical skill sink`, `Secret-safe direnv`, `Non-Bash edit and write policy`, and `Jj diamond boundary`.

- [ ] **Step 4: Run all pre-activation checks**

Run formatting, `package-pi-agent-extensions`, each of the three custom regulators independently, the relevant Home Manager evaluation/build, and `just check-fast` or an approved targeted equivalent.
Read complete output and require fresh exit zero before reporting success.

- [ ] **Step 5: Validate OpenSpec through a temporary XDG tree**

Run status and strict validation with a trap-cleaned, dereferenced copy of `${XDG_DATA_HOME:-$HOME/.local/share}/openspec` under `/tmp`.
Do not add a schema workaround to the repository.

- [ ] **Step 6: Audit the final diff**

Run `git diff --check` and inspect the complete implementation diff.
Require no fixture tree, no `modules/checks/packages.nix` change, exactly one new by-name package, no flake input, exactly three custom Pi derivations, and no unrelated file.

## Task 7: Stop for human activation and preserve rollback

**Files:**

- Modify task state only after the corresponding evidence exists.
- Do not edit production files unless a verified defect begins a new RED-GREEN cycle.

**Interfaces:**

- Consumes fresh pre-activation evidence from Task 6.
- Produces a recorded nix-darwin rollback system profile, human activation request, confirmation-gated live evidence, and rollback confirmation.

- [ ] **Step 1: Record rollback without activating**

Run both commands without `sudo` and retain both complete, nonempty single-line outputs in the handoff:

```bash
readlink /nix/var/nix/profiles/system
readlink -f /nix/var/nix/profiles/system
```

Require the first line to name the current `system-N-link` and the second to name its resolved `darwin-system` store path.
Do not run `just activate --ask`.

- [ ] **Step 2: Stop for the human command**

Ask Cameron to run `just activate --ask` and report whether it succeeds.
Run no live-state probe before explicit success confirmation.

- [ ] **Step 3: Verify live state only after confirmation**

Within Pi-managed paths, use unique non-destructive probes to inspect the mutable settings copy, representative runtime-managed state that was not converted into immutable executable-resource links, immutable policy/theme/extensions/global-instruction links, exact selected resources, policy behavior, canonical `~/.agents/skills`, absent `~/.pi/agent/skills`, exclusions, secret-sentinel absence, and slow-mode opt-in.
Do not treat this as an exhaustive enumeration of every possible Pi runtime path.
Clean every probe with `rip`.

- [ ] **Step 4: Confirm rollback**

After Cameron confirms activation, inspect `/nix/var/nix/profiles/system` with `readlink` and `readlink -f`.
Require it to point to the new active `system-N-link`, require the link recorded in Step 1 to be `system-(N-1)-link`, and require that recorded link to remain present and resolvable as the immediately previous system available for rollback.

## Task 8: Remediate post-activation policy review findings

**Files:**

- Modify: `modules/checks/pi-agent-environment.nix`
- Modify: `modules/home/ai/pi/policy/permission-rules.ts`
- Modify: `openspec/changes/configure-pi-agent-environment/brainstorm.md`
- Modify: `openspec/changes/configure-pi-agent-environment/plan.md`
- Modify: `openspec/changes/configure-pi-agent-environment/tasks.md`

**Interfaces:**

- Consumes the pinned permission-gate parser, helpers, and rule API without replacing or copying them.
- Produces fail-closed curl option classification and fail-closed unresolved Git/jj subcommand classification while preserving recognized ordinary commands.
- Adds structural and adapter evidence for the three minor review findings.
- Produces automated pre-activation evidence for a second human-controlled activation cycle, while leaving activation and live verification open.

- [ ] **Step 1: Add exact policy RED rows**

Add rows for `curl --expand-data`, an unclassified future curl long option, a persistent Git alias invocation with no literal `add`, and a persistent jj alias invocation with no literal `add`.
Add ordinary recognized Git and jj rows that must remain allowed.
Run the policy regulator before editing `permission-rules.ts` and retain the four named allow-versus-prompt failures.

- [ ] **Step 2: Implement the smallest fail-closed policy correction**

Make any unclassified curl long option prompt unless the option is explicitly classified safe.
Make unknown Git/jj leading options and unresolved alias-shaped subcommands prompt while preserving injected alias handling, exact worktree/workspace built-ins, and recognized commands.
Run the policy regulator independently and require every row to pass.

- [ ] **Step 3: Add the minor review regressions**

Correct the stale nix-darwin rollback wording in `brainstorm.md`.
Add a structural literal proving no top-level slow-mode activation setting exists.
Add explicit adapter cases for a missing filesystem capability and a throwing capability factory, both of which must block diagnostically.

- [ ] **Step 4: Revalidate before a second activation**

Run formatting, the policy and structural regulators independently, the aggregate smoke, the package check, relevant Home Manager evaluation/build, and the approved fast check set.
Run strict OpenSpec validation from a trap-cleaned temporary XDG tree.
Audit all 25 requirement/scenario names and order, scope, exact traces, and the final diff.
Record the current nix-darwin system profile link and resolved store path without activating.

- [ ] **Step 5: Stop for the second human activation**

Ask Cameron to run `just activate --ask`.
The implementation agent must not run activation or inspect live Pi targets before explicit success confirmation.

- [ ] **Step 6: Verify the remediated live environment after confirmation**

After Cameron confirms the second activation, rerun the representative policy, immutable-resource, slow-mode, and rollback probes.
Keep this step open until that evidence exists.

## Commit plan

| Commit | Purpose | Paths |
|---|---|---|
| `feat(pi): package pinned extension sources` | Add the source-only package and three independent check surfaces. | `pkgs/by-name/pi-agent-extensions/package.nix`, `modules/checks/pi-agent-environment.nix`, tasks ledger |
| `feat(pi): compose exact Nix-owned resources` | Add exact filters, state ownership, global instructions coverage, and Catppuccin. | `modules/home/ai/pi/default.nix`, theme file, check module, tasks ledger |
| `feat(pi): enforce fail-closed mutation policy` | Add pinned-parser rules, pure edit/write core, thin adapter, and policy rows. | Pi policy files, Pi module, check module, tasks ledger |
| `test(pi): add aggregate offline RPC smoke` | Add one actual-binary aggregate smoke after the prototype gate. | `modules/checks/pi-agent-environment.nix`, tasks ledger only; no fixtures |
| `docs(pi): reconcile deployed version provenance` | Add stale-version scan and update both Pi 0.83 references after RED. | Pi module, reconnaissance note, check module, tasks ledger |

`modules/checks/packages.nix` is not modified by any commit.
No commit creates `modules/checks/fixtures` or a fixture file.

## Requirement trace

| Requirement | Plan witness | Checklist route | Primary evidence |
|---|---|---|---|
| Nix-owned Pi resources | Task 1 step 2; Task 2 steps 1 and 7 | 1.2, 2.1–2.5 | structural |
| Mutable settings seed | Task 2 steps 3–4; Task 7 step 3 | 2.2–2.3, 6.4 | structural + manual |
| Runtime state boundary | Task 2 steps 3–4; Task 7 step 3 | 2.2–2.3, 6.4 | structural + manual |
| Source-only extension package | Task 1 steps 3–5; Task 6 steps 2 and 6 | 1.3–1.4, 5.4 | package build + scope scan |
| Selected extensions | Task 2 steps 1–2 | 1.5 | structural |
| Nix-owned runtime executables | Task 2 steps 1–2 | 1.5 | structural |
| Excluded extension resources | Task 2 steps 1–2 | 1.5 | structural |
| Retained compaction extension | Task 2 steps 1–2 | 1.5 | structural |
| Canonical skill sink | Task 2 steps 1 and 3–4; Task 7 step 3 | 1.6, 2.2–2.3, 6.4 | structural + manual |
| Catppuccin source provenance | Task 2 steps 5–6 | 2.2, 2.4 | source review + structural |
| Catppuccin theme delivery | Task 2 steps 5–7 | 2.2, 2.4–2.5 | structural |
| Permission-gate reuse | Task 3 steps 1–3 | 3.1–3.2, 3.6 | policy |
| Additional shell policy | Task 3 steps 1 and 3 | 3.1–3.2 | policy |
| Non-Bash edit and write policy | Task 3 steps 4–5 | 3.3–3.4 | policy |
| Git default-branch boundary | Task 3 steps 4–6 | 3.3–3.5 | policy |
| Jj diamond boundary | Task 3 steps 4–6 | 3.3, 3.5 | policy |
| Fail-closed policy | Task 3 steps 4–7 | 3.3–3.8 | policy |
| Secret-safe direnv | Task 2 steps 3–4; Task 4 steps 3 and 5 | 2.2–2.3, 4.3, 4.5 | structural + smoke |
| Opt-in slow mode | Task 2 steps 1–2 | 1.5 | structural |
| Consolidated custom regulators | Tasks 1 and 6 | 1.1, 1.4, 5.3 | external enumeration |
| Offline aggregate smoke | Task 4 steps 1–7 | 4.1–4.6 | smoke |
| Stale Pi version cleanup | Task 5 steps 1–4 | 5.1–5.2 | structural |
| Human-only activation | Task 7 steps 1–2 | 6.1–6.2 | manual |
| Confirmation-gated live verification | Task 7 steps 2–3 | 6.3–6.4 | manual |
| Rollback preservation | Task 7 steps 1 and 4 | 6.1, 6.5 | manual |
