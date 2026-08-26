# Discharge-evidence annotation: schema edit and rollout — Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development
> to implement this plan task-by-task.

> **Fallback notice**: `superpowers:writing-plans` runs interactively with a human, breaking work into
> micro-steps through back-and-forth. This change was authored by a subagent with no interactive user
> available. Per this schema's own documented fallback ("or that they can explicitly opt to write plan.md
> manually using the template below"), this plan is written manually from tasks.md and design.md.
> This plan describes deferred work (schema is currently pinned by name in in-flight changes; see
> design.md Decision D1 and the Migration Plan) — it is not executed by this authoring pass.

**Goal:** Give the satisfaction-projection generator a real, per-requirement discharge-evidence source to
read, and prove the read path works end to end on at least one real requirement.

**Architecture:** Two-phase. Phase A edits the pinned schema's three instruction blocks (`specs`,
`verify` §8b, archive step) to define and consume the `**Discharged by**:` annotation. Phase B is a single
demonstration cycle — annotate one real requirement, run it through plan→apply→verify→archive, and diff
the regenerated projection row — that closes the loop from "annotation exists" to "projection uses it."

**Tech Stack:** Markdown (schema instruction text, spec deltas), the `openspec` CLI (validate/archive),
nix activation (schema delivery to `~/.local/share/openspec/schemas/`).

---

## Task 1: Unblock the schema edit

- [ ] **Step 1:** List every `openspec/changes/*/.openspec.yaml` (excluding `archive/`) and grep each for
      `schemaName: superpowers-bridge-wrspm`.
- [ ] **Step 2:** For each match, confirm it is archived, abandoned, or otherwise no longer reading
      instructions live — a change that is still being actively planned or applied against this schema
      blocks Step 3 below.
- [ ] **Step 3:** Once the list is empty (or schema versioning removes the conflict — see design.md's
      Open Questions), proceed to Task 2. Commit point: none (read-only check).

## Task 2: Edit the specs artifact instruction

- [ ] **Step 1:** Open
      `modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml`, locate the `specs`
      artifact's `instruction` block.
- [ ] **Step 2:** Add the `**Discharged by**:` convention paragraph, matching this change's ADDED
      requirement text in `specs/stratified-change-authoring/spec.md` (optional; one free-text form; four
      example kinds — check/test name, scenario reference, proof obligation, dated manual inspection; a
      bare assertion naming nothing is treated as absent).
- [ ] **Step 3:** `nix build`/activate per this repo's nix-managed-output convention (see
      `openspec/config.yaml` context section: verify by evaluating/building/inspecting the delivered
      path, never by reading source alone).
- [ ] **Step 4:** Diff `modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml`
      against `~/.local/share/openspec/schemas/superpowers-bridge-wrspm/schema.yaml` — expect no
      difference. Commit point: schema `specs` instruction edit.

## Task 3: Edit verify's §8b and the archive step

- [ ] **Step 1:** In the same schema file, locate the `verify` artifact instruction's §8b (discharge
      coherence) paragraph.
- [ ] **Step 2:** Add the read-the-annotation sentence, matching this change's MODIFIED "Verify artifact
      runs non-blocking stratum checks" text.
- [ ] **Step 3:** Locate `apply.instruction`, step 5 (archive: satisfaction-projection rebuild).
- [ ] **Step 4:** Add the same substitution plus the "SHALL NOT infer from stratum/capability alone"
      sentence, matching this change's MODIFIED "Archive step regenerates the satisfaction projection"
      text.
- [ ] **Step 5:** Rebuild/activate; diff delivered path against source, as in Task 2 Step 3–4. Commit
      point: schema `verify`/archive instruction edit.

## Task 4: Archive this change

- [ ] **Step 1:** Run `openspec validate --all` from the repo root; confirm this change's item is
      `"valid": true`.
- [ ] **Step 2:** Run `openspec archive annotate-discharge-evidence`.
- [ ] **Step 3:** Confirm `openspec/specs/stratified-change-authoring/spec.md` contains the synced
      requirements and the change directory moved under `openspec/changes/archive/`. Commit point:
      archive sync.

## Task 5: Demonstrate the read path end to end

- [ ] **Step 1:** Pick one currently-undischarged requirement with a real, nameable discharging artifact
      (e.g. a `pi-agent-environment` requirement backed by an existing nix check).
- [ ] **Step 2:** Add a `**Discharged by**:` line naming that artifact to the requirement, via a small
      follow-up change (not this one — this one's scope is the annotation contract and the read path, not
      the retrofit; see design.md Non-Goals).
- [ ] **Step 3:** Take that follow-up change through plan → apply → verify → archive.
- [ ] **Step 4:** Diff the regenerated `packages/docs/src/content/docs/development/traceability/
      satisfaction.md` for that one requirement's row; confirm `Discharged by (S)` now shows the
      annotation's value.
- [ ] **Step 5:** Paste that diff into the follow-up change's retrospective as the closing evidence.
      Commit point: none additional — the follow-up change's own commits cover this.
