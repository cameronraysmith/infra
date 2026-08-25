# Stratify the change write path — implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development
> to implement this plan task-by-task.

**Goal:** Fork `superpowers-bridge` to a first-party `superpowers-bridge-wrspm` bundle that adds a
WRSPM stratum layer to the OpenSpec change write path, corrects the parent bundle's provenance, and
delivers both bundles so no in-flight change is stranded.

**Architecture:** A single-file schema (`schema.yaml`) plus a `templates/` directory, resolved by the
OpenSpec CLI through a project-tier symlink at `openspec/schemas/superpowers-bridge-wrspm`, delivered
to other machines via a nix home-manager module option (`schemaDirs`, `attrsOf path`). Project-level
instruction injection flows through `openspec/config.yaml`'s `context` and `rules`.

**Tech Stack:** OpenSpec CLI 1.10.0, nix flake-parts home-manager module, jj-colocated git.

---

## Task 1: Fork the schema bundle and add the WRSPM stratum layer

- [x] **Step 1:** Copy `assets/schemas/superpowers-bridge/{schema.yaml,README.md,VERSION,templates/}`
  to `modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/` as the starting point for the fork
  (`openspec schema fork` itself aborts with `EACCES` against the mode-444 nix-store source, so the
  copy was done directly rather than through that CLI subcommand).
- [x] **Step 2:** In the `proposal` artifact's instruction, add the stratum-tag requirement
  (`world`/`interface`/`behavioral`) under the Capabilities section, with the honest-tagging note.
- [x] **Step 3:** In the `specs` artifact's instruction, add the three stratum-conditional vocabulary
  blocks (behavioral/world/interface) plus the pointer to `rules.specs` in project config.
- [x] **Step 4:** In the `verify` artifact's instruction, add section 8 (designation lint, discharge
  coherence, alphabet check), each marked non-blocking, with the vacuous-clean-report guard for an
  absent `world-assumptions` capability.
- [x] **Step 5:** In the `apply` instruction's archive step, add the satisfaction-projection rebuild:
  regenerate `docs/development/traceability/satisfaction.md` from the post-sync corpus before the
  change folder moves.
- [x] **Step 6:** Remove the three `actionContext.mode == "workspace-planning"` guards from the fork's
  apply/verify/retrospective entry points; confirm they remain untouched in the frozen parent.
- [x] **Step 7:** Bump the compatibility badge and table in the fork's `README.md` from `1.4.1` to
  `1.10.0`, and add the 1.10.0-migration note explaining the guard removal.
- [x] **Step 8:** Create the project-tier symlink `openspec/schemas/superpowers-bridge-wrspm` and pin
  `openspec/config.yaml`'s `schema:` field to the new bundle name.

## Task 2: Add the per-task discharge convention

- [x] **Step 1:** Add `— verify: <...>` to every task line and rename the closing group to
  `## Integration Verification` in `templates/tasks.md`.
- [x] **Step 2:** Add the matching instruction text (`Each task MUST carry its verification...`) to
  the `tasks` artifact's `schema.yaml` instruction.

## Task 3: Populate project config

- [x] **Step 1:** Write `openspec/config.yaml`'s `context:` block — the vendored-versus-first-party
  and source-versus-delivered boundaries, jj working-copy discipline, schema-resolution path, and the
  `rules.tasks` dead-letter note.
- [x] **Step 2:** Write `rules.proposal`, `rules.specs`, `rules.design`, `rules.verify`.
- [x] **Step 3:** Write `operations.archive.guidance` — the three-item satisfaction-projection rebuild
  guidance.
- [x] **Step 4:** Confirm `rules.tasks` is deliberately omitted (not silently missing) by checking
  `openspec instructions tasks --json` for the dropped-`rules`-key defect before deciding where the
  nix-verification guidance belongs.

## Task 4: Deliver both schema bundles from nix

- [x] **Step 1:** Rename `programs.openspec.schemaDir` (`lib.types.path`) to `schemaDirs`
  (`lib.types.attrsOf lib.types.path`) in `modules/home/ai/openspec/default.nix`.
- [x] **Step 2:** Default `schemaDirs` to both bundles: `superpowers-bridge` at
  `assetsDir + "/schemas/superpowers-bridge"`, `superpowers-bridge-wrspm` at the new first-party path.
- [x] **Step 3:** Update the `home.file` binding to map over `cfg.schemaDirs` via `lib.mapAttrs'`,
  producing one `.local/share/openspec/schemas/<name>` symlink per bundle.
- [x] **Step 4:** Document, in the option's description, why both bundles are delivered deliberately
  (the never-repinned schema pin hazard).

## Task 5: Correct schema bundle provenance

- [x] **Step 1:** Rewrite `modules/home/ai/openspec/assets/schemas/README.md` to record the actual
  fork lineage (fork of `github.com/JiangWay/openspec-schemas`, upstream head `f5d4040`, diverged
  +79/−29 lines in `schema.yaml`) in place of the vendored/`0366ed5` description.
- [x] **Step 2:** Remove the stale `cp -R` refresh recipe (pointing at a non-existent path) rather
  than repairing it; record why in prose (it would have discarded local changes).
- [x] **Step 3:** Update `modules/home/ai/openspec/schemas/README.md` to describe both directories as
  ours to edit, differing only in lifecycle (live fork vs. frozen reference).
- [x] **Step 4:** Update the wrspm bundle's own `README.md` provenance section to name its two-forks-
  deep ancestry.

## Task 6: Dogfood and validate

- [x] **Step 1:** Author this change's own seven planning artifacts (brainstorm was already present;
  proposal, design, specs, tasks, plan, verify, retrospective produced here) under the newly forked
  schema, as the falsification exercise the brainstorm committed to in advance.
- [x] **Step 2:** Run `openspec validate stratify-change-write-path --type change` and confirm a clean
  pass.
- [x] **Step 3:** Run `openspec validate --all --json` and confirm no existing change or spec
  regressed.
