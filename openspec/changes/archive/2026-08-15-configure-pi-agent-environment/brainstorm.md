The current Pi integration enables the Home Manager `programs.pi-coding-agent` module, supplies Pi 0.84.1 through `llm-agents`, writes Nix-owned global instructions through `context`, seeds a mutable `settings.json`, disables install telemetry, uses the built-in dark theme, and loads `pi-openai-server-compaction`.
Pi 0.84.1 already discovers the canonical `~/.agents/skills` tree, so a second `~/.pi/agent/skills` sink would duplicate and shadow resources rather than extend them.

The approved outcome is a Nix-first Pi environment with one new source-only package.
Nix and Home Manager own source pins, enabled extensions, runtime executables, the safety-policy baseline, the theme, canonical skills, and global instructions.
Pi must not install packages or update source at runtime.
Within Pi-managed paths, Home Manager continues to replace `settings.json` with a Nix-generated mutable copy at activation and does not convert runtime-managed settings, sessions, compaction, authentication, project trust, model selection, thinking preferences, or extension state into immutable executable-resource links.
Executable policy, theme, extensions, and global instructions remain immutable.

Three extension-source approaches were considered.
Allowing Pi to install npm or git packages would preserve upstream installation flows but introduce runtime network access and mutable source resolution, so it was rejected.
Creating one aggregate package would simplify one settings entry but couple unrelated sources and obscure filtering, so it was rejected.
The selected approach adds only `pkgs/by-name/pi-agent-extensions/package.nix`, a source-only package pinning `rytswd/pi-agent-extensions` at commit `c700f300707db5345727052682c88e3064030aa2` with hash `sha256-RLtDi9ahKONSJBuuYkYo/oIIxDX6PWiZ7rlevOStUUk=`.
The derivation rejects any `node_modules` content and performs no npm installation.
The existing `modules/checks/packages.nix` automatically maps the package to `package-pi-agent-extensions` and remains unmodified.
The ordinary package realization proves the source-only output, while a pre-activation scope and diff scan proves that this is exactly one new by-name package and that no flake input was added.

The package filter loads exactly six positive paths: `direnv/index.ts`, `permission-gate/index.ts`, `questionnaire/index.ts`, `slow-mode/index.ts`, `stash/index.ts`, and `statusline/index.ts`.
It retains explicit negative selectors for `fetch/index.ts` and `notify/index.ts`, and every unselected resource kind remains empty.
The existing `pi-openai-server-compaction` package remains enabled as a separate package entry.
The Pi runtime PATH adds exactly the Nix packages `direnv`, `diffutils`, `git`, `jujutsu`, and `rip2`.

The first-party theme lives at `modules/home/ai/pi/themes/catppuccin-mocha.json` and is linked immutably by Home Manager.
It is copied byte-for-byte from `aldoborrero/pi-agent-kit` commit `128c4c08396961ea8f934111ba1aad0b33c525b2`, path `themes/catppuccin-mocha.json`, with SHA-256 `5858d086e155246d48e5b7a2ac372988fe2d1a028d2b77b5f0a7670088a8642b`.
Settings select `catppuccin-mocha`, and no standalone theme package is created.

Three safety-policy approaches were considered.
Copying Claude-specific hooks would couple Pi to unrelated event protocols, so it was rejected.
Replacing rytswd permission-gate would duplicate its shell parser, built-in rules, project-trust boundary, and headless handling, so it was rejected.
The selected split keeps the pinned permission-gate parser and rule API for Bash and adds compact Nix-owned shell rules plus one first-party Pi extension for non-Bash `edit` and `write` calls.

The Bash rules cover dangerous classes, semantic mutating HTTP requests, direct `rm` denial with `rip` guidance, a prompt for worktree creation, and denial of Pi package mutation commands.
Policy tests explicitly preserve permission-gate's untrusted project-config boundary.
The non-Bash policy is a pure decision core with injected filesystem and typed, discriminated repository-state capabilities plus a thin Pi `tool_call` adapter.
It protects immutable paths, blocks edits on Git `main` or `master`, and admits healthy ordinary or diamond-managed jj repositories under mode-specific predicates.
Common jj health requires canonical repository identity and target containment, an unambiguous conflict-free `@` whose change identity is not divergent, neither `main` nor `master` pointing directly to `@`, and successful unambiguous read-only probes whose argv all begin with `jj --ignore-working-copy`.
A separate bookmark-listing classification probe must first report the `wip` convention, including a divergent `wip` indicator, before a repository is classified as diamond-managed.
Only after that report does the unique `wip`-resolution probe produce the absent, moved, or divergent `wip` failure rows.
A repository with no `wip` report remains eligible for ordinary classification and never reaches a missing-`wip` failure row.
Diamond health additionally requires `@` to be the nonconflicted, nondivergent `[wip]` commit with exactly one parent and exactly one non-divergent `wip` bookmark pointing to it.
It probes `@-` separately as the `[merge]` join, requires that join to be nonconflicted with at least two parents, and probes `parents(@-)` separately to require conflict-free immediate parents whose count matches the join report.
Neither `@` nor `@-` must be empty, and diamond health imposes no working-copy-cleanliness requirement.
Ordinary jj repositories have no `wip`, diamond-topology, emptiness, or working-copy-cleanliness requirement.
Malformed, failing, or ambiguous probes, parser failures, capability failures, and prompt decisions without usable interaction block diagnostically rather than fall through.
No delegated-tool policy is introduced.

The configuration provides runtime environment indirection through `direnv`, while sentinel secret values and generated credentials remain absent from Nix expressions, store paths, and generated configuration.
This requirement does not claim or test upstream `direnv` value-supply behavior.
`slow-mode` is installed and remains opt-in.
Herdr remains available and unchanged.
Integration of `nicobailon/pi-subagents` is deferred entirely to a separate future change and is not a general safety judgment about upstream.

Validation uses one ordinary flake-parts logical-group module, `modules/checks/pi-agent-environment.nix`, that exposes exactly three independent derivations with separate declared inputs and cache boundaries.
Physical co-location does not make them one monolithic check.
The structural regulator follows `modules/lib/mk-structural-check.nix` and compares a compact serialized evaluated Nix/Home Manager value, including evaluated Pi package version `0.84.1`, to a literal oracle.
It owns configuration structure, not runtime loading or writability, upstream provenance inferred from metadata, package-output behavior, package-scope evidence, or recursive inspection of its own check set.
The policy regulator follows the table-driven `modules/checks/hooks.nix` and `pkgs.writeText` precedent, retains pure-core rows without starting Pi once per row, and directly invokes the thin Pi adapter through its exported factory or handler seam for synthetic allow/block translation, unrelated-tool pass-through, malformed tool input, and core or capability exceptions that must fail closed.
The exact installed/deployed Pi 0.84.1 wrapper from the current locked package was empirically characterized during discovery in a disposable `HOME`.
Its `models.json` registered credential-free provider `review-local` with model id `review-model`, inert base URL `http://127.0.0.1:9/v1`, API `openai-completions`, and no `apiKey`; explicit `--model review-local/review-model` made `get_state` return that model, no prompt or provider request occurred, closing stdin exited zero, and the disposable characterization recorded no Nix store hash as a future contract.
The smoke regulator must reproduce that characterized behavior at assertion level inside its hermetic derivation against the exact deployed Pi 0.84.1 Bun binary, in one valid aggregate environment, while also querying `get_commands` and observing only surfaces RPC supports.
`PI_OFFLINE=1` disables Pi startup network behavior, while the Nix sandbox is the actual network boundary.
RPC cannot fully introspect the questionnaire tool, stash shortcuts, hooks, or themes, so structural and policy evidence carry those claims.
No `modules/checks/fixtures` directory is added.

Every new behavior begins with an evaluable assertion-level RED witness.
The stale Pi 0.83 cleanup begins with explicit failing scans of both `modules/home/ai/pi/default.nix` and `docs/notes/development/ai-agents/pi-integration-reconnaissance.md` before either file changes.
The smoke work begins with an assertion-level RED/prototype gate that must reproduce the discovery characterization for the exact deployed Pi 0.84.1 RPC invocation with explicit `--model review-local/review-model`, because default settings may report `unknown/unknown` and the disposable discovery run is not assertion-level hermetic evidence.
The credential-free registration and inert base URL establish only selected startup state; the harness sends no prompt or provider-facing request, adds no secret or API key, and relies on the Nix sandbox as the network boundary.
If the hermetic reproduction differs from the discovery characterization, including a deployed-package mismatch, implementation stops and asks rather than weakening the contract.

Rollout has a hard human gate.
Implementation stops after pre-activation checks, records the current nix-darwin system profile link and its resolved `darwin-system` store path, and asks Cameron to run `just activate --ask`.
No live-state probe runs before Cameron confirms success, and the recorded system profile link remains the rollback target.
