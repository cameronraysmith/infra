## Context

The current Home Manager module supplies Pi 0.84.1 through `llm-agents`, shared Nix-owned global instructions, disabled install telemetry, a mutable `settings.json` seed refreshed at activation, and the retained `pi-openai-server-compaction` package.
Pi already discovers `~/.agents/skills`, so a second Pi-specific sink would shadow rather than extend the canonical skill tree.
The remaining design must add one pinned extension source, exact resource filtering, Catppuccin Mocha, harness-neutral safety policy, three independent hermetic regulators, and a human-controlled activation boundary without putting secrets or writable application state in `/nix/store`.

External delegation remains available through the existing Herdr environment and is unchanged and outside scope.
Integration of `nicobailon/pi-subagents` is deferred to a separate future change because the stronger atomic admission contract considered during discovery would require a maintained fork.
This is not a claim that upstream is generally unsafe, and the integration can be reconsidered when upstream public seams warrant it.

## Goals / Non-Goals

Goals:

- Reproduce Pi 0.84.1, the selected extension source and filters, runtime executables, theme, policy baseline, canonical skills, and global instructions through Nix and Home Manager.
- Within Pi-managed paths, preserve the mutable settings copy and runtime-managed state outside immutable executable-resource links while keeping executable policy, theme, extensions, and global instructions immutable.
- Preserve the pinned permission-gate parser, built-in rules, project-trust boundary, and headless behavior while adding only the compact Pi-native edit and write boundary required by this change.
- Expose exactly three independent custom derivations from one ordinary flake-parts logical-group module.
- Preserve assertion-level RED for every new behavior and the human-only activation and rollback boundary.

Non-goals:

- Installing or updating Pi packages at runtime.
- Adding a flake input, aggregate Pi package, standalone theme package, Pi-specific skill sink, `pi-ultracode`, or any `modules/checks/fixtures` directory.
- Adding a process per extension or any failure-isolation acceptance requirement.
- Adding local delegated-execution machinery or delegated-tool policy.
- Changing any Herdr package, configuration, or runtime integration.
- Porting Claude-specific hook events, notification hooks, memory capture, vague-request clarification, or session-start advice.
- Putting authentication data, sentinel secret values, or generated credentials in the Nix store or generated configuration.
- Running `just activate --ask` from an implementation agent.

## Decisions

### D1: Separate immutable resources from mutable state

- Choice: Nix and Home Manager own Pi source selection, extension filters, runtime executables, theme, policy source, canonical skills, and global instructions.
- Choice: Home Manager continues to replace `settings.json` with a generated mutable copy on activation.
- Choice: Within Pi-managed paths, Home Manager does not convert runtime-managed settings, sessions, compaction, authentication, project trust, model selection, thinking preferences, or extension state into immutable executable-resource links.
- Choice: Executable policy, theme, extensions, and global instructions remain immutable.
- Rationale: Executable and policy inputs require reviewable immutability, while Pi's normal state transitions require writable runtime-managed state.
- Alternatives considered: Making the full agent directory immutable breaks valid state transitions; leaving resources mutable defeats reproducibility.

### D2: Add one source-only extension package

- Choice: `pkgs/by-name/pi-agent-extensions/package.nix` uses `fetchFromGitHub` for `rytswd/pi-agent-extensions` commit `c700f300707db5345727052682c88e3064030aa2` with hash `sha256-RLtDi9ahKONSJBuuYkYo/oIIxDX6PWiZ7rlevOStUUk=`.
- Choice: The derivation copies source only, performs no npm installation, and rejects any `node_modules` content.
- Choice: This is the only new by-name package and adds no flake input.
- Choice: The existing `modules/checks/packages.nix` auto-map exposes `package-pi-agent-extensions` and remains unmodified.
- Evidence boundary: Ordinary package realization proves the exact fixed-output source, source-only output, and `node_modules` rejection; a pre-activation scope and diff scan proves exactly one new by-name package, no flake input, and no change to the ordinary package map.
- Rationale: The selected files use Node built-ins and Pi-supplied imports, so a dependency installation phase would add mutable or unnecessary closure surface.
- Alternatives considered: Pi-managed installation adds runtime source movement; an aggregate package couples unrelated resources.

### D3: Use exact positive extension filters

The package filter uses this literal extension list:

```json
[
  "direnv/index.ts",
  "permission-gate/index.ts",
  "questionnaire/index.ts",
  "slow-mode/index.ts",
  "stash/index.ts",
  "statusline/index.ts",
  "-fetch/index.ts",
  "-notify/index.ts"
]
```

- Choice: The six positive selectors are exact package-relative paths.
- Choice: `fetch` and `notify` remain explicit negative selectors, and skills, prompts, and themes from the package remain empty.
- Choice: `pi-openai-server-compaction` remains a separate enabled package entry.
- Choice: `extraPackages` remains exactly `direnv`, `diffutils`, `git`, `jujutsu`, and `rip2`.
- Rationale: Literal positive selection closes the enabled inventory against undeclared upstream additions while the negative entries retain review-visible exclusions.
- Alternatives considered: Broad globs would admit future resources without review.

### D4: Pin Catppuccin content and delivery

- Choice: `modules/home/ai/pi/themes/catppuccin-mocha.json` is copied byte-for-byte from `aldoborrero/pi-agent-kit` commit `128c4c08396961ea8f934111ba1aad0b33c525b2`, path `themes/catppuccin-mocha.json`.
- Choice: Its required SHA-256 is `5858d086e155246d48e5b7a2ac372988fe2d1a028d2b77b5f0a7670088a8642b`.
- Choice: Home Manager links the file immutably and settings select `catppuccin-mocha` without a standalone package.
- Rationale: One presentation file needs exact source review and content identity but not an independent package lifecycle.
- Evidence boundary: The structural digest proves checked-in content identity, while reviewed acquisition from the pinned commit and path supports upstream provenance; metadata alone does not.
- Alternatives considered: An adapted unpinned copy loses provenance; a package adds needless surface.

### D5: Split Bash parsing from non-Bash tool policy

- Choice: The pinned rytswd permission-gate parser and rule API remain the Bash parser, built-in-rule engine, project-trust boundary, and headless enforcement surface.
- Choice: Nix-owned permission-gate rules classify dangerous commands, semantic mutating HTTP requests, direct `rm`, worktree creation, and Pi package mutation.
- Choice: Direct `rm` blocks with `rip` guidance, mutating HTTP and worktree creation prompt interactively, and Pi package mutation blocks with Nix-pin guidance.
- Choice: One compact first-party pure decision core handles only non-Bash `edit` and `write` calls, while a thin Pi adapter translates `tool_call` events and decisions through an exported factory or handler seam that the policy regulator can invoke directly.
- Rationale: This preserves the mature parser while keeping policy logic independently testable without starting Pi for each case.
- Alternatives considered: Replacing permission-gate duplicates existing parsing; copying Claude hook protocols preserves the wrong interface.

### D6: Inject effects and fail closed

- Choice: The pure edit/write decision core receives filesystem, Git, jj, and interaction capabilities instead of performing effects directly.
- Choice: Repository inspection lowers into a typed discriminated input with variants for outside-repository state, Git state, ordinary jj state, diamond-managed jj state, and invalid diagnostic state; the decision core exhaustively handles every variant.
- Choice: Non-Bash edit and write calls block targets beneath `/nix/store` or another declared immutable resource root.
- Choice: Git repositories block edits and writes on `main` and `master`.
- Choice: Common jj health requires a canonical repository identity containing the canonical target; unambiguous resolution of `@`; conflict-free `@`; a non-divergent current `@` change identity; neither `main` nor `master` pointing directly to `@`; and successful, unambiguous parsing of every read-only probe.
- Choice: Every read-only jj probe starts with `jj --ignore-working-copy`, and policy tests record the complete argv.
- Choice: A separate bookmark-listing classification probe must first report the `wip` convention, including a divergent `wip` indicator, before a repository is classified as diamond-managed.
- Choice: Only a repository already classified as diamond-managed runs the unique `wip`-resolution probe and can produce absent, moved, or divergent `wip` failures.
- Choice: A repository with no `wip` report remains eligible for ordinary classification and never reaches a missing-`wip` failure.
- Choice: Diamond health adds a stored `@` that is an empty merge commit with at least two parents, exactly one non-divergent `wip` bookmark pointing to `@`, and conflict-free `@` plus immediate parents.
- Choice: Ordinary jj health adds no `wip`, empty-merge, or multi-parent requirement.
- Choice: Neither jj mode requires working-copy cleanliness because probes ignore the working copy and Pi may perform repeated edit or write calls.
- Choice: Literal policy rows cover ordinary healthy, ordinary conflict, ordinary divergent `@`, ordinary `main`/`master` at `@`, diamond healthy, classified-diamond missing/moved/divergent `wip`, nonempty/single-parent/conflicted join, and malformed/failing/ambiguous probe states.
- Choice: Parser errors, policy or adapter exceptions, ambiguous repository state, missing or throwing capabilities, and prompt-class decisions without usable interaction block with a diagnostic reason.
- Choice: Adapter evidence directly invokes the exported Pi factory or handler seam for synthetic edit/write allow and block translation, unrelated-tool pass-through, malformed tool input, and core or capability exceptions that fail closed; pure-core cases remain separately table-driven without a Pi process per row.
- Rationale: Capability injection isolates the pure decision algebra from Pi and process execution while executable adapter evidence proves the actual integration boundary rather than only adapter-shaped inputs.
- Alternatives considered: Instructions alone are bypassable; raw shell regexes cannot cover non-Bash tool calls; requiring every jj repository to be a clean diamond join would reject healthy ordinary repositories and repeated tool calls.

### D7: Keep secrets dynamic and optional behavior opt-in

- Choice: Pi is configured with runtime environment indirection through direnv, but Nix expressions, store files, and generated configuration contain no sentinel secret values.
- Choice: Credentials remain in Pi auth state, environment indirection, or runtime secret files.
- Evidence boundary: Structural evidence proves the configured indirection and smoke scans prove sentinel absence; this change does not claim or test upstream direnv value-supply behavior.
- Choice: Slow-mode loads but remains inactive until the operator invokes it.
- Rationale: Declarative executable provenance does not require declarative secret values or mandatory slow behavior.
- Alternatives considered: Rendering secret-bearing JSON through Nix exposes values; enabling slow-mode by default changes ordinary editing behavior.

### D8: Expose three independent regulators from one logical-group module

- Choice: `modules/checks/pi-agent-environment.nix` is an ordinary flake-parts module that exposes exactly `pi-agent-environment-structural`, `pi-agent-environment-policy`, and `pi-agent-environment-smoke`.
- Choice: Each check is a separate derivation with only its own declared inputs, so each has an independent cache boundary even though all three definitions are physically co-located.
- Choice: The structural regulator uses `flake.lib.mkStructuralCheck` from `modules/lib/mk-structural-check.nix` to compare compact serialized evaluated Nix/Home Manager values with a literal oracle.
- Choice: The structural value owns evaluated Pi package version `0.84.1`, the ordered six positives, two negative selectors, empty unselected resource kinds, five `extraPackages`, retained compaction, mutable-copy activation, immutable policy/theme/extensions/global instructions, selected theme and digest, canonical `~/.agents/skills`, and absent `~/.pi/agent/skills`.
- Choice: Structural evidence does not claim runtime loading, live writability, upstream provenance from metadata alone, package-output behavior, package-scope evidence, or recursively inspect the check set.
- Choice: The policy regulator follows the table-driven `modules/checks/hooks.nix` and `pkgs.writeText` precedent, invokes the pinned parser/rule API plus the pure edit/write core without a Pi process per row, and directly invokes the exported thin-adapter seam for executable adapter cases.
- Choice: The smoke regulator starts one actual deployed Pi 0.84.1 Bun process in one valid aggregate environment with explicit `--model review-local/review-model`, closes stdin after the supported queries, and requires clean exit status.
- Choice: `modules/checks/packages.nix` remains unmodified, the package derivation rejects `node_modules`, and final external enumeration confirms the three custom checks plus `package-pi-agent-extensions`.
- Rationale: Distinct derivations align with distinct structural, policy, and runtime failure modes; physical co-location only groups related definitions.
- Alternatives considered: One monolithic derivation couples invalidation and diagnostics; one check per extension proliferates processes and attributes.

### D9: Prototype RPC feasibility, preserve RED, and gate activation

- Choice: Every new-behavior witness is introduced before its production behavior and remains evaluable through optional lookup, existence guards, or sentinels.
- Choice: RED fails through an explicit expected assertion, not a missing attribute, absent import, undefined binding, evaluator error, module-not-found exception, or malformed harness.
- Choice: Before either stale file changes, explicit scans must fail and name the Pi 0.83 reference in both `modules/home/ai/pi/default.nix` and `docs/notes/development/ai-agents/pi-integration-reconnaissance.md`.
- Discovery characterization: The exact installed/deployed Pi 0.84.1 wrapper from the current locked package ran in a disposable `HOME` with a `models.json` entry for credential-free provider `review-local`, model id `review-model`, inert base URL `http://127.0.0.1:9/v1`, API `openai-completions`, no `apiKey`, and explicit `--model review-local/review-model`.
- Discovery observation: `get_state` returned that model, no prompt or provider request occurred, stdin closure exited zero, and no concrete Nix store hash is part of the future contract.
- Choice: Smoke work begins with an assertion-level RED/prototype gate using the exact deployed Pi binary to reproduce that invocation hermetically, because the disposable characterization is discovery evidence rather than assertion-level derivation evidence and default settings may report `unknown/unknown`.
- Choice: The hermetic registration adds no secret or API key, sends no prompt or provider-facing request, and retains the Nix sandbox as the network boundary.
- Choice: After the supported queries, the harness closes stdin and requires a clean exit status.
- Choice: The aggregate smoke does not rely on the invocation until that reproduction passes, and implementation stops with a question rather than weakening the contract if hermetic behavior differs from the discovery characterization, including a deployed-package mismatch.
- Choice: Implementation completes pre-activation verification, records the current Home Manager generation, and stops.
- Choice: Only Cameron runs `just activate --ask`; live probes wait for explicit success confirmation and preserve the recorded prior generation for rollback.
- Rationale: A severe witness must distinguish discovery characterization from hermetic assertion-level evidence, and live activation is an operator-owned effect.
- Alternatives considered: Treating the disposable characterization as derivation proof would skip the required RED witness; agent-run activation crosses the authority boundary.

### D10: Map each atomic requirement to one scenario and explicit evidence

The delta spec contains 25 atomic requirements, each with exactly one scenario.
The requirement names and order below are canonical for the plan trace.

| Requirement | Modality | Witness |
|---|---|---|
| Nix-owned Pi resources | structural | Compare evaluated Pi package version `0.84.1` plus compact executable-resource, policy, theme, skill, and global-instruction ownership with a literal oracle. |
| Mutable settings seed | structural + manual | Assert the activation copy form, then inspect the confirmed live target after human activation. |
| Runtime state boundary | structural + manual | Assert, within Pi-managed paths, the mutable-copy declaration, runtime-managed categories not converted into immutable executable-resource links, and immutable executable resource declarations, then inspect representative live targets after confirmation. |
| Source-only extension package | package build + scope scan | Realize `package-pi-agent-extensions` from the exact fixed-output source and reject `node_modules`, then prove by pre-activation scope and diff scan that exactly one by-name package and no flake input were added. |
| Selected extensions | structural | Compare the ordered six positive selectors with the literal oracle. |
| Nix-owned runtime executables | structural | Compare evaluated package names with the ordered five-name oracle. |
| Excluded extension resources | structural | Compare both negative selectors and empty skills, prompts, and themes with the literal oracle. |
| Retained compaction extension | structural | Assert the existing package remains a separate configured entry. |
| Canonical skill sink | structural + manual | Assert canonical and absent sink declarations, then inspect confirmed live links. |
| Catppuccin source provenance | source review + structural | Acquire from the pinned commit/path and compare the checked-in digest with the literal oracle. |
| Catppuccin theme delivery | structural | Assert immutable delivery, selected name, digest, and absent standalone package. |
| Permission-gate reuse | policy | Run parser/rule and project-trust rows through the pinned pure APIs. |
| Additional shell policy | policy | Exercise semantic dangerous, HTTP, `rm`, worktree, and Pi-mutation rows. |
| Non-Bash edit and write policy | policy | Exercise pure-core cases and directly invoke the exported Pi adapter seam for allow/block translation, unrelated-tool pass-through, malformed input, and exception fail-closed behavior. |
| Git default-branch boundary | policy | Compare feature-branch allow cases with `main` and `master` blocks. |
| Jj diamond boundary | policy | Record every jj argv; prove no-`wip` reports remain ordinary; and cover classification-reported diamond state followed by healthy or absent/moved/divergent unique-`wip` resolution, plus conflict, divergence, default-bookmark, join-shape, and malformed/failing/ambiguous-probe rows. |
| Fail-closed policy | policy | Inject parser, decision, adapter, repository, capability, and headless failures and require diagnostic blocks. |
| Secret-safe direnv | structural + smoke | Compare runtime-indirection configuration and scan the aggregate environment for an absent sentinel secret. |
| Opt-in slow mode | structural | Assert slow-mode is selected without a default activation setting. |
| Consolidated custom regulators | external enumeration | Enumerate the exact three custom Pi checks and existing ordinary package-map result outside the regulators. |
| Offline aggregate smoke | smoke | Hermetically reproduce the discovery-characterized credential-free RPC readiness once with explicit `review-local/review-model`, query supported state/command surfaces, close stdin, and require clean exit. |
| Stale Pi version cleanup | structural | Observe assertion-level RED in both files, then require Pi 0.84.1 with no Pi 0.83 reference. |
| Human-only activation | manual | Record the prior generation, stop, and request Cameron's command. |
| Confirmation-gated live verification | manual | Require explicit activation success before any live probe. |
| Rollback preservation | manual | Confirm the recorded prior generation remains immediately available. |

## Risks / Trade-offs

- [Risk] Pi may report `unknown/unknown` when the model is left to default settings, or hermetic derivation behavior may differ from the discovery-characterized installed wrapper.
  Mitigation: Reproduce explicit `--model review-local/review-model` through the RED/prototype gate with the same credential-free inert registration, and stop with a question on any behavioral or deployed-package mismatch rather than weakening the contract.
- [Risk] RPC does not expose every registration or presentation surface.
  Mitigation: Limit smoke claims to `get_state`, `get_commands`, diagnostics, process readiness, and shutdown; structural and policy regulators own questionnaire tool, stash shortcut, hook, theme, and exact-filter evidence.
- [Risk] A future Pi package-filter implementation changes canonical paths.
  Mitigation: The structural value compares exact ordered selectors against a literal oracle before activation.
- [Risk] Policy parsing or repository inspection throws.
  Mitigation: Pure policy tables inject failures and require a diagnostic block.
- [Risk] The copied theme drifts from reviewed provenance.
  Mitigation: Source acquisition records the pinned commit/path and the structural regulator checks the exact digest.
- [Trade-off] Positive selectors require a code review to enable future resources.
  This is accepted because deliberate enablement is the purpose of the Nix-first boundary.
- [Trade-off] `settings.json` remains mutable between activations.
  This is accepted because Pi legitimately updates user preferences and Home Manager restores the declared baseline on activation.

## Migration Plan

1. Create the one logical-group check module and expose three independently input-addressed derivations.
2. Add structural assertion-level RED using compact evaluated values, then add the source-only package and exact Home Manager composition without modifying `modules/checks/packages.nix`.
3. Add policy assertion-level RED tables for the pure core, typed ordinary and diamond jj states, and direct adapter execution, then implement pinned permission-gate rules and the pure edit/write decision core with its thin adapter.
4. Reproduce the discovery-characterized actual-binary credential-free RPC invocation with explicit `--model review-local/review-model` in the assertion-level hermetic RED/prototype gate before relying on the aggregate smoke contract; if it differs, stop and ask, otherwise build the one-process smoke without fixtures and close stdin for clean exit.
5. Add explicit stale-version RED scans for both files before updating either Pi 0.83 reference.
6. Externally enumerate checks, run the package build and three regulators, prove exactly one new by-name package and no flake input by scope and diff scan, audit all 25 routes, and complete remaining pre-activation checks.
7. Validate OpenSpec strictly through a trap-cleaned dereferenced temporary XDG data tree.
8. Record the current Home Manager generation, stop, and ask Cameron to run `just activate --ask`.
9. After explicit confirmation, run non-destructive live probes and confirm rollback availability.

Rollback uses the Home Manager generation recorded immediately before Cameron's activation.
Reverting to it restores the prior theme and package set while preserving separately stored mutable session and authentication state.

## Open Questions

Discovery characterized the installed/deployed Pi 0.84.1 wrapper from the current locked package with explicit `--model review-local/review-model`, no prompt or provider-facing request, and clean exit after stdin closure.
Implementation must still reproduce that behavior in the assertion-level hermetic RED/prototype gate against the exact deployed package.
If hermetic reproduction differs, including a deployed-package mismatch, stop and ask rather than substituting credentials, an API key, a provider request, a hardcoded Nix store hash, or a weaker assertion.
