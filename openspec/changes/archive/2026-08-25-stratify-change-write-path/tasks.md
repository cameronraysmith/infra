## 1. Fork the schema bundle and add the WRSPM stratum layer

- [x] 1.1 Fork `superpowers-bridge` to a new first-party tree at `modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/` (schema.yaml, README.md, VERSION, templates/) — verify: `jj show 677e05ff78bb --stat` shows the 12-file, 1849-insertion addition of the bundle plus the project-tier symlink.
- [x] 1.2 Add a per-capability `world`/`interface`/`behavioral` stratum tag requirement to the `proposal` artifact instruction — verify: `grep -n "Tag each with its stratum" modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/schema.yaml` returns a match in the `proposal` artifact block.
- [x] 1.3 Add stratum-conditional vocabulary rules to the `specs` artifact instruction (behavioral/world/interface) — verify: `grep -n "Stratum-conditional rules" modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/schema.yaml` returns a match, followed by the three stratum blocks.
- [x] 1.4 Add non-blocking section 8 (designation lint, discharge coherence, alphabet check) to the `verify` artifact instruction — verify: `grep -n "Designation lint and discharge coherence" modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/schema.yaml` returns a match; `openspec instructions verify --change stratify-change-write-path --json` (once dependencies are present) includes the §8 text.
- [x] 1.5 Add satisfaction-projection regeneration to the apply phase's archive step — verify: `grep -n "Then regenerate the satisfaction projection" modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/schema.yaml` returns a match in the `apply.instruction` block.
- [x] 1.6 Remove the three unreachable `actionContext.mode == "workspace-planning"` guards from the fork's apply/verify/retrospective entry points — verify: `grep -c "workspace-planning" modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/schema.yaml` returns `0`, versus `grep -c "workspace-planning" modules/home/ai/openspec/assets/schemas/superpowers-bridge/schema.yaml` returning `6` in the frozen parent.
- [x] 1.7 Bump the declared OpenSpec baseline from 1.4.1 to 1.10.0 — verify: `grep -n "1.10.0" modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/README.md` shows the compatibility table row `| v1 | \`1.10.0\` | \`v5.1.0\` | 2026-08-25 |`.

## 2. Add the per-task discharge convention

- [x] 2.1 Add the `— verify: <...>` clause requirement and the `## Integration Verification` closing group to `templates/tasks.md` — verify: `read modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/templates/tasks.md` shows every task line ending in `— verify: <...>` and a final `## 3. Integration Verification` group.
- [x] 2.2 Add the same convention to the `tasks` artifact instruction in `schema.yaml` — verify: `grep -n "MUST carry its verification" modules/home/ai/openspec/schemas/superpowers-bridge-wrspm/schema.yaml` returns a match.

## 3. Populate project config

- [x] 3.1 Populate `openspec/config.yaml`'s `context` (boundaries, jj discipline, schema resolution, `rules.tasks` dead-letter explanation) — verify: `jj show 653740701270 --stat` shows `openspec/config.yaml | 89 +++...` (69 insertions, 20 deletions); `read openspec/config.yaml` shows a non-empty `context:` block.
- [x] 3.2 Populate `rules.proposal`, `rules.specs`, `rules.design`, `rules.verify` — verify: `openspec instructions proposal --change stratify-change-write-path` includes a `<rules>` block with the stratum-tagging and trust-boundary rules.
- [x] 3.3 Populate `operations.archive.guidance` for the satisfaction-projection rebuild — verify: `read openspec/config.yaml` lines 64-69 show the three-item `operations.archive.guidance` list.
- [x] 3.4 Deliberately omit `rules.tasks` and record why — verify: `openspec instructions tasks --change stratify-change-write-path --json 2>&1 | jq 'has("rules")'` returns `false` while the same query for `proposal`/`specs`/`design`/`verify` returns `true`, confirming the omission is intentional rather than an oversight.

## 4. Deliver both schema bundles from nix

- [x] 4.1 Convert `programs.openspec.schemaDir` (single path) to `schemaDirs` (`attrsOf path`) in `modules/home/ai/openspec/default.nix`, defaulting to both bundles — verify: `nix eval .#homeConfigurations.\"crs58@aarch64-darwin\".config.programs.openspec.schemaDirs --apply builtins.attrNames --json` returns `["superpowers-bridge","superpowers-bridge-wrspm"]`.
- [x] 4.2 Keep the frozen `superpowers-bridge` bundle deliverable so the four in-flight changes pinned to it keep resolving — verify: `for d in openspec/changes/*/; do grep -H "^schema:" "$d.openspec.yaml" 2>/dev/null; done` lists `agentic-planning-development-management-skills`, `apm-skills-marketplace`, `declarative-cognee-endpoint`, and `validate-harborize-instrument` still pinned to `superpowers-bridge`, and `schemaDirs.superpowers-bridge` in `default.nix` still points at `assetsDir + "/schemas/superpowers-bridge"`.

## 5. Correct schema bundle provenance

- [x] 5.1 Correct `modules/home/ai/openspec/schemas/README.md`, `modules/home/ai/openspec/assets/schemas/README.md`, and the wrspm bundle's own `README.md` to record the actual fork lineage (first-party fork of `github.com/JiangWay/openspec-schemas`, diverged +79/−29 lines in `schema.yaml` at upstream head `f5d4040`, not vendored third-party content pinned to `0366ed5`) — verify: `jj show a3719f84c210 --stat` shows the 3-file, 68-insertion/36-deletion correction; `grep -n "f5d4040" modules/home/ai/openspec/assets/schemas/README.md` returns a match.
- [x] 5.2 Remove the stale runnable `cp -R` refresh recipe pointing at a non-existent path, rather than repairing it — verify: `grep -n "cp -R" modules/home/ai/openspec/assets/schemas/README.md` returns exactly one line, and it is prose narrating the removal ("was a blind `cp -R` that would have discarded every local change... It has been removed rather than repaired"), not a runnable code block; the former path `~/projects/planning-workspace/openspec-schemas-superpowers-bridge/` survives only inside that same historical sentence, and `ls ~/projects/planning-workspace/openspec-schemas-superpowers-bridge/ 2>&1` confirms the path does not exist on disk.

## 6. Integration Verification

- [x] 6.1 Full change validates under OpenSpec's structural checks after all seven planning artifacts exist — verify: `openspec validate stratify-change-write-path --type change` reports `Change 'stratify-change-write-path' is valid`.
- [x] 6.2 The forked schema resolves and renders instructions for every artifact in dependency order without error — verify: `openspec instructions <artifact> --change stratify-change-write-path` succeeds for `brainstorm`, `proposal`, `design`, `specs`, `tasks`, `plan`, `verify`, `retrospective` (all eight ids present in `schema.yaml`'s `artifacts:` list plus `apply`).
- [x] 6.3 No existing change's schema resolution regressed — verify: `openspec validate --all --json | jq '.summary'` reports `{"totals":{"items":12,"passed":12,"failed":0},"byType":{"change":{"items":7,"passed":7,"failed":0},"spec":{"items":5,"passed":5,"failed":0}}}`; `openspec validate --all --json | jq -r '.items[] | select(.valid != true) | .id'` returns no lines.
