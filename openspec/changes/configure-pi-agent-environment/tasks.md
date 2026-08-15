## 1. Independent check surfaces and source-only package

- [x] 1.1 Create `modules/checks/pi-agent-environment.nix` as one ordinary flake-parts logical-group module exposing exactly three independent derivations with separate inputs and cache boundaries: `pi-agent-environment-structural`, `pi-agent-environment-policy`, and `pi-agent-environment-smoke`.
- [x] 1.2 Add an evaluable assertion-level structural RED for evaluated Pi package version `0.84.1` and the absent compact package/configuration values without importing absent files or recursively evaluating the check set.
- [x] 1.3 Create `pkgs/by-name/pi-agent-extensions/package.nix` at commit `c700f300707db5345727052682c88e3064030aa2` with hash `sha256-RLtDi9ahKONSJBuuYkYo/oIIxDX6PWiZ7rlevOStUUk=`, a copy-only install phase, and an explicit rejection of `node_modules`.
- [x] 1.4 Leave `modules/checks/packages.nix` unmodified and verify its existing auto-map exposes `package-pi-agent-extensions` by final external check enumeration; preserve ordinary package realization and separately prove by pre-activation scope and diff scan that this is exactly one new by-name package and no flake input was added.
- [x] 1.5 Add structural RED rows, then configure the ordered six positive extension paths, `-fetch/index.ts`, `-notify/index.ts`, empty skills/prompts/themes for the package, retained separate compaction entry, and exactly five `extraPackages`.
- [x] 1.6 Add explicit structural RED coverage for Nix-owned global instructions, the canonical `~/.agents/skills` sink, and the absence of `~/.pi/agent/skills`.

## 2. State ownership and Catppuccin theme

- [x] 2.1 Use `flake.lib.mkStructuralCheck` from `modules/lib/mk-structural-check.nix` to compare one compact serialized evaluated Nix/Home Manager value with a literal oracle.
- [x] 2.2 Add assertion-level RED rows for mutable-copy settings activation; runtime-managed categories under Pi-managed paths that are not converted into immutable executable-resource links; immutable policy/theme/extensions/global-instruction resources; selected theme; theme digest; and canonical skills, without claiming live writability or exhaustive path enumeration.
- [x] 2.3 Within Pi-managed paths, preserve the mutable settings copy and do not convert runtime-managed settings, sessions, compaction, authentication, project trust, model selection, thinking preferences, or extension state into immutable executable-resource links; keep executable policy, theme, extensions, and global instructions immutable.
- [x] 2.4 Copy `themes/catppuccin-mocha.json` byte-for-byte from `aldoborrero/pi-agent-kit` commit `128c4c08396961ea8f934111ba1aad0b33c525b2`, verify SHA-256 `5858d086e155246d48e5b7a2ac372988fe2d1a028d2b77b5f0a7670088a8642b`, link it immutably, and select `catppuccin-mocha` without a standalone package.
- [x] 2.5 Make the structural regulator GREEN only for compact configuration facts; leave runtime loading, live writability, upstream provenance beyond reviewed source acquisition, package-output behavior, and final check enumeration to their declared evidence routes.

## 3. Table-driven pure safety policy

- [x] 3.1 Add `pkgs.writeText`-backed table-driven assertion-level RED cases following `modules/checks/hooks.nix` for safe commands, dangerous classes, semantic mutating HTTP forms, direct and composed `rm`, worktree creation, Pi package mutation, and the pinned permission-gate project-trust boundary.
- [x] 3.2 Implement Nix-owned rules through the pinned permission-gate parser, helpers, and rule API, with `rip` guidance, Nix-pin guidance, interactive prompt decisions for mutating HTTP and worktree creation, and headless blocks.
- [x] 3.3 Add pure decision-core RED cases for direct Pi `edit` and `write` calls against mutable paths, `/nix/store`, other immutable roots, Git feature branches, Git `main` and `master`, and a typed discriminated repository-state input covering outside-repository, Git, ordinary jj, diamond-managed jj, and invalid diagnostic variants.
  Include literal jj rows in this order: ordinary healthy; ordinary healthy with nonempty `@`; ordinary conflict; ordinary divergent `@`; ordinary `main`/`master` at `@`; an actual healthy empty `@` `[wip]` over an empty six-parent `@-` join; healthy nonempty `[wip]`; healthy conflict-resolved nonempty join; classified-diamond missing, moved, or divergent `wip`; non-single-parent `[wip]`; single-parent join; conflicted join; conflicted immediate join parent; join-parent count mismatch; and malformed or failing join probe.
  Common health requires canonical repository identity and target containment, unambiguous conflict-free `@`, non-divergent current `@` identity, neither default bookmark at `@`, and successful unambiguous probes.
  Classify a repository as diamond-managed only after a separate bookmark-listing probe reports the `wip` convention, including a divergent indicator; only then run the unique `wip`-resolution probe and admit healthy or absent/moved/divergent results.
  Keep a repository with no `wip` report eligible for ordinary mode and ensure it never reaches missing-`wip` failure.
  Require diamond `@` to be the `[wip]` commit with exactly one parent and exactly one non-divergent `wip` bookmark pointing to it.
  Probe `@-` separately as the `[merge]` join, require it to be nonconflicted with at least two parents, and require a separate `parents(@-)` probe to return a conflict-free set whose count matches the join report.
  Require neither `@` nor `@-` to be empty and impose no working-copy-cleanliness requirement in diamond mode.
  Require no `wip`, diamond-topology, emptiness, or working-copy-cleanliness predicate in ordinary mode.
- [x] 3.4 Add executable adapter RED cases, then implement one compact pure edit/write decision core with injected filesystem, Git, jj, and interaction capabilities plus a thin Pi `tool_call` adapter exported through a directly invocable factory or handler seam.
  Cover synthetic edit/write allow translation, edit/write diagnostic block translation, unrelated-tool pass-through, malformed tool input, and core or capability exceptions that fail closed; add no delegated-tool policy or unrelated event registrations.
- [x] 3.5 Record every jj argv emitted by injected capabilities and require every read-only command to start with `jj --ignore-working-copy`; make failed, malformed, or ambiguously parsed probes block diagnostically.
- [x] 3.6 Preserve permission-gate's untrusted project-config behavior explicitly, including refusal to weaken protected/block behavior and fail-closed handling where headless prompt rules cannot be disabled.
- [x] 3.7 Make parser errors, core or adapter exceptions, ambiguous repository state, malformed tool input, missing or throwing capabilities, and unavailable interaction return diagnostic blocks.
- [x] 3.8 Link policy sources immutably and make every pure-core and executable-adapter row GREEN inside the single independent policy derivation without starting a Pi process per row.

## 4. One-process aggregate smoke

- [x] 4.1 Add an assertion-level RED/prototype gate in `pi-agent-environment-smoke` that hermetically reproduces the discovery-characterized exact deployed Pi 0.84.1 Bun wrapper with explicit `--model review-local/review-model` and readiness without credentials or a provider request; do not accept a default `unknown/unknown` model state.
  Record the discovery characterization without a concrete Nix store hash: the current locked package ran in a disposable `HOME` with `models.json` provider `review-local`, model id `review-model`, inert base URL `http://127.0.0.1:9/v1`, API `openai-completions`, no `apiKey`; `get_state` returned that model, no prompt or provider request occurred, and stdin closure exited zero.
- [x] 4.2 Do not rely on the aggregate smoke contract until the assertion-level hermetic reproduction establishes the supported invocation, request sequence, readiness signal, stdin-close behavior, and clean exit status.
  Use the same credential-free inert registration solely to establish selected startup state; add no secret or API key and send no prompt or provider-facing request.
  If hermetic reproduction differs from discovery characterization, including an exact deployed-package mismatch, stop and ask rather than weakening the contract.
- [x] 4.3 After the reproduction passes, create one valid aggregate environment with a fresh writable `HOME` and agent directory, exact store-backed resources/settings, a sentinel scan input representing a direnv runtime value, `PI_OFFLINE=1`, and the Nix sandbox as the actual network boundary; do not require direnv to supply the sentinel to Pi.
- [x] 4.4 Start one Pi process only with explicit `--model review-local/review-model`, send no prompt or compaction request, issue `get_state` and `get_commands`, assert the selected registered model and visible extension/skill commands where RPC supports them, and require no resource or extension diagnostic.
- [x] 4.5 Structurally assert runtime environment indirection and assert the sentinel value does not occur in Nix expressions, generated configuration, or store-backed content; also assert that Pi makes no provider request, without claiming upstream direnv value-supply behavior or that `PI_OFFLINE=1` alone proves network isolation.
- [x] 4.6 After the supported queries, close stdin and require a bounded clean exit status.
  Leave questionnaire tool registration, stash shortcuts, hooks, and theme introspection to structural or policy evidence because RPC does not expose them fully.
- [x] 4.7 Add no `modules/checks/fixtures` directory, per-extension process, or failure-isolation case.

## 5. Provenance, traceability, and pre-activation verification

- [x] 5.1 Add explicit assertion-level RED scans that name stale Pi 0.83 references in both `modules/home/ai/pi/default.nix` and `docs/notes/development/ai-agents/pi-integration-reconnaissance.md` before changing either file.
- [x] 5.2 After observing both expected RED failures, update both files to Pi 0.84.1 and make the stale-reference assertions GREEN.
- [x] 5.3 Externally enumerate current-system checks and require exactly `pi-agent-environment-policy`, `pi-agent-environment-smoke`, and `pi-agent-environment-structural` plus the existing auto-mapped `package-pi-agent-extensions`; do not make the structural regulator inspect the check set recursively.
- [x] 5.4 Scan implementation, generated configuration, and the diff for extra packages, broad filters, unintended `fetch` or `notify` enablement, a Pi-specific skill sink, secret literals, runtime package mutation guidance, extra custom Pi checks, fixture-tree creation, or Herdr changes; prove that `pi-agent-extensions` is exactly one new by-name package, no flake input was added, and `modules/checks/packages.nix` is unchanged.
- [x] 5.5 Verify all 25 requirements have exactly one scenario, the same exact name and order in D10 and the plan trace, and explicit checklist and plan routes with Pi package version `0.84.1`, source-only package realization plus scope evidence, mutable settings, canonical skills, secret-safe direnv, executable adapter evidence, ordinary no-`wip` eligibility, and classified-diamond unique-`wip` modalities aligned.
- [x] 5.6 Run formatting, `package-pi-agent-extensions`, the three independent regulators, the relevant Home Manager evaluation/build, and `just check-fast` or an approved targeted equivalent; require fresh exit-zero evidence before reporting pre-activation success.
- [x] 5.7 Validate OpenSpec status and strict conformance through a trap-cleaned dereferenced temporary `/tmp` `XDG_DATA_HOME` copy and add no schema workaround to the repository.

## 6. Human activation boundary and rollback

- [x] 6.1 After every pre-activation check passes, record the complete, nonempty single-line outputs of `readlink /nix/var/nix/profiles/system` and `readlink -f /nix/var/nix/profiles/system` without `sudo` or activation; require the first to name the current `system-N-link` and the second its resolved `darwin-system` store path.
- [x] 6.2 Stop and ask Cameron to run `just activate --ask`; the implementation agent MUST NOT run that command.
- [x] 6.3 Keep every live-state probe blocked and every post-activation task incomplete until Cameron explicitly confirms successful activation.
- [x] 6.4 After confirmation, inspect representative Pi-managed targets to verify the mutable settings copy, runtime-managed state not converted into immutable executable-resource links, immutable policy/theme/extensions/global-instruction resources, canonical `~/.agents/skills`, absent `~/.pi/agent/skills`, exact selected resources, policy behavior, exclusions, sentinel-secret absence, and slow-mode opt-in with unique non-destructive probes cleaned by `rip`; do not claim exhaustive coverage of every possible Pi path.
- [x] 6.5 After activation, confirm `/nix/var/nix/profiles/system` points to the new active `system-N-link`, the link recorded in 6.1 is the immediately previous `system-(N-1)-link`, and that recorded link remains present and resolvable for rollback.

## 7. Post-activation review remediation

- [x] 7.1 Add exact RED rows proving that `curl --expand-data`, an unclassified future curl long option, and persistent Git/jj alias invocations with no literal `add` fail open on the activated implementation; retain the complete named failure transcript.
- [x] 7.2 Make unclassified curl long options and unresolved Git/jj alias-shaped subcommands prompt while preserving explicit safe curl behavior, injected aliases, worktree/workspace built-ins, and recognized ordinary Git/jj commands; make the independent policy regulator GREEN.
- [x] 7.3 Correct stale brainstorm rollback wording, add a structural literal for the absence of default slow-mode activation settings, and add explicit missing-capability and throwing-capability-factory diagnostic block cases.
- [x] 7.4 Run automated pre-activation revalidation: formatting, package, independent policy/structural/smoke regulators, relevant Home Manager evaluation/build, approved fast checks, strict temporary-XDG OpenSpec validation, 25-requirement trace/order audit, scope audit, and final diff checks; record the current nix-darwin system profile link and resolved store path without activating.
- [ ] 7.5 Stop and ask Cameron to run `just activate --ask` for the remediated generation; the implementation agent MUST NOT run activation or inspect live Pi targets before explicit confirmation.
- [ ] 7.6 After explicit confirmation, verify representative live policy, immutable-resource, slow-mode, and rollback behavior for the remediated generation.

## 8. Recognized shell reads and slow-mode evidence

- [x] 8.1 Add allow regression rows for common safe curl long flags, representative safe short clusters, `grep`, `blame`, `rev-parse`, `ls-files`, `archive`, `show-ref`, and Git global informational options; retain the exact current-policy overprompt RED transcript before production edits.
- [x] 8.2 Classify reviewed no-value curl flags explicitly, make unclassified long and short options prompt, and replace the partial Git command list with the exact deployed Git 2.55.0 `git --list-cmds=builtins,nohelpers` inventory while excluding aliases and helpers.
- [x] 8.3 Replace the lexical slow-mode settings check with an exact top-level settings shape and require the pinned selected slow-mode source to initialize its only `enabled` state declaration to `false` before its toggle transition.
- [x] 8.4 Re-run policy, structural, smoke, treefmt, approved fast checks, strict temporary-XDG OpenSpec validation, and exact requirement, trace, inventory, scope, and diff audits; retain the `system-53-link` rollback record without activation or live probes.
