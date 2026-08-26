## 1. Unblock and edit the schema

- [ ] 1.1 Confirm no in-flight change is still pinned to `schemaName: superpowers-bridge-wrspm` in a
      not-yet-archived state (or that schema versioning has been introduced so a pinned change is
      unaffected by an edit to the latest version) — verify: `grep -l 'schemaName: superpowers-bridge-wrspm'
      openspec/changes/*/.openspec.yaml` (excluding `openspec/changes/archive/`) enumerates only changes
      this task's author has confirmed are safe to proceed alongside, or the list is empty.
- [ ] 1.2 Edit `modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml`'s `specs`
      artifact instruction to document the `**Discharged by**:` convention (optional, one free-text
      form, four example kinds, bare-assertion rejection) — verify: the edited instruction text, diffed
      against this change's ADDED requirement "Specs artifact records optional discharge evidence
      inline" in `specs/stratified-change-authoring/spec.md`, states the same contract.
- [ ] 1.3 Edit the `verify` artifact instruction's §8b (discharge coherence) to read each requirement's
      `**Discharged by**:` annotation into the `Discharged by (S)` column, verbatim, in place of
      composing capability-level justification text — verify: diffed against this change's MODIFIED
      "Verify artifact runs non-blocking stratum checks" text.
- [ ] 1.4 Edit the archive step's `apply.instruction` (step 5, satisfaction-projection rebuild) to the
      same substitution and to state explicitly that the archive step SHALL NOT infer discharge from a
      requirement's stratum tag or capability trust-boundary statement alone — verify: diffed against
      this change's MODIFIED "Archive step regenerates the satisfaction projection" text.
- [ ] 1.5 Rebuild/activate so the edited schema is delivered to `~/.local/share/openspec/schemas/` —
      verify: `diff modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml
      ~/.local/share/openspec/schemas/superpowers-bridge-wrspm/schema.yaml` reports no difference after
      activation (this repo's `openspec/config.yaml` context section states schema edits take effect on
      the next activation, not immediately).

## 2. Archive this change

- [ ] 2.1 Run `openspec archive annotate-discharge-evidence` — verify:
      `openspec/specs/stratified-change-authoring/spec.md` contains the ADDED requirement and both
      MODIFIED requirements from this change's delta spec, and
      `openspec/changes/archive/<date>-annotate-discharge-evidence/` exists in place of the pre-archive
      change directory.

## 3. Integration Verification

- [ ] 3.1 Verify the schema's `specs`, `verify`, and archive instructions produce a real
      `Discharged by (S)` value end to end — with `**Discharged by**:` in this task, and the schema edits
      of Task 1 both in place, annotate one currently-undischarged requirement in the corpus (e.g. one of
      the `pi-agent-environment` rows in `packages/docs/src/content/docs/development/traceability/
      satisfaction.md`) with a `**Discharged by**:` line naming a real, existing check for that
      requirement, take that annotation through a full plan→apply→verify→archive cycle, and confirm the
      regenerated `satisfaction.md` row for that requirement shows the annotation's own value in
      `Discharged by (S)` rather than an empty cell or a capability-level gloss like `own interface
      properties` — verify: the regenerated `satisfaction.md`'s diff for that one row, pasted into that
      demonstration change's retrospective.
