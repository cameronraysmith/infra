# Repair episode-bound requirements — Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development
> to implement this plan task-by-task.
>
> **Adaptation note:** This change is a prose-only OpenSpec corpus and schema/skill edit with no
> production code, so the usual RED-GREEN-REFACTOR cycle does not apply per micro-step. Each step's
> "test" is a `read`/`grep`/`openspec validate` observation against the exact text asserted, run
> before the step is marked done. Commit points are named but not executed in this session: the
> session's constraints prohibit jj/git write commands, so commits are the orchestrator's to make.

**Goal:** Remove the episode-bound requirement defects the corpus audit found — one archived
change's verbatim task rows in `pi-agent-environment`, and eleven dangling `this change` references
across five other capabilities — replacing each with a durable requirement or an inline substance
statement, and state the underlying no-change-reference constraint at the schema's two points of
corpus ingress.

**Architecture:** One OpenSpec change (`repair-episode-bound-requirements`) carrying six delta spec
files under `specs/<capability>/spec.md`, each using `ADDED`/`MODIFIED`/`REMOVED` delta operations
against the corresponding living spec in `openspec/specs/<capability>/spec.md`. A separate,
session-authorized pair of edits lands outside the delta mechanism, directly in
`modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml` and
`modules/home/ai/plugins/formal-specification-and-refinement/.apm/skills/preferences-requirements-engineering/SKILL.md`,
since those are schema/skill infrastructure rather than corpus content and have no delta mechanism
of their own.

**Tech Stack:** OpenSpec CLI 1.10.0 (`spec-driven`/`superpowers-bridge-wrspm` schema), Markdown delta
specs, YAML schema instructions.

---

## Task 1: Pre-deletion safety check (tasks.md §1)

- [x] **Step 1:** Read `openspec/changes/archive/2026-08-15-configure-pi-agent-environment/specs/pi-agent-environment/spec.md:205-212` and diff it against the current `Stale Pi version cleanup` requirement in `openspec/specs/pi-agent-environment/spec.md:247-254`. Confirmed byte-for-byte identical requirement and scenario text.
- [x] **Step 2:** Grep the same archived change's `design.md`, `tasks.md`, `verify.md` for the requirement's design row, task mapping, and verify coverage. Found `design.md:183`, `tasks.md:54-55`, `verify.md:122` (naming `modules/checks/pi-agent-environment.nix:2382-2383,2427-2429`).
- Commit point: none — read-only reconnaissance, no file changed.

## Task 2: `pi-agent-environment` delta spec (tasks.md §2)

- [x] **Step 1:** Create `specs/pi-agent-environment/spec.md`, `## REMOVED Requirements` section, with `Stale Pi version cleanup`, `Human-only activation`, `Confirmation-gated live verification`, each carrying `**Reason**` and `**Migration**` lines per D1/D2 in design.md.
- [x] **Step 2:** Add `## ADDED Requirements` with `Activation requires explicit permission` and `Post-activation confirmation gate`, transcribing the user's verbatim policy sentence split at its clause boundary, rendering "you" as "the human operator," and keeping "unless given explicit permission to do so" intact.
- [x] **Step 3:** Add one checkable-violation scenario per new requirement (`Activation is proposed without explicit permission`; `Activation success is unconfirmed`).
- [x] **Step 4:** Add `## MODIFIED Requirements` with `Rollback preservation` restated as a post-activation link comparison, dropping "recorded before activation" and the named-human scenario trigger.
- [x] **Step 5 (verify):** `grep -n "unless given explicit permission to do so"`, `grep -c "recorded before activation"` (expect 0), `grep -c "Cameron"` (expect 0) against the delta file. All confirmed as expected.
- Commit point: "specs(pi-agent-environment): remove archived-episode task rows, replace with durable activation policy" (deferred to orchestrator).

## Task 3: `graphical-desktop-session` delta spec (tasks.md §3)

- [x] **Step 1:** Create `specs/graphical-desktop-session/spec.md`, `## MODIFIED Requirements`, with the full requirement text copied from the living spec, editing only the requirement-body fencing clause and the one scenario bullet named in the assignment.
- [x] **Step 2 (verify):** `grep -c "MUST NOT be assembled\|follow-up change\|added by this"` returns 0; `grep` for "NOT part of this capability" and "no desktop toggle" both return one hit each. Confirmed.
- Commit point: "specs(graphical-desktop-session): strip change-fencing, keep durable niri/home-manager boundary" (deferred).

## Task 4: Outward-reference cleanup in the remaining four capabilities (tasks.md §4)

- [x] **Step 1 (`apple-laptop-hardware-support`):** Copy the full `The stage-1 initrd force-loads...` requirement, editing only the body sentence naming "this change" to name the two credential states directly. Verify: `grep -c "this change"` on the delta returns 0; `grep` for "pre-enrollment and post-enrollment" returns 1.
- [x] **Step 2 (`bare-metal-install-path`):** Copy all three affected requirements (`The install path is recorded...`, `An install is accepted as evidence...`, `Network association is declarative...`) in full, editing lines 16, 31, 70, 166 per design.md's D5 table while leaving line 25 byte-for-byte unchanged. Verify: `grep -c "this change"` on the delta returns exactly 1, matching original line 25 verbatim.
- [x] **Step 3 (`encrypted-zfs-root`):** Copy the full `The pool sits inside a LUKS2 container...` requirement (all 11 scenarios), editing only line 179 while leaving line 148 byte-for-byte unchanged. Verify: `grep -c "this change"` on the delta returns exactly 1, matching original line 148 verbatim.
- [x] **Step 4 (`stratified-change-authoring`):** Copy the full `Archive step regenerates the satisfaction projection` requirement, normalizing "this change's" to "the change's" at the one instance. Verify: `grep -c "this change"` returns 0; `grep` for "the change's delta specs" returns 1.
- Commit point: "specs(apple-laptop-hardware-support,bare-metal-install-path,encrypted-zfs-root,stratified-change-authoring): remove dangling change references" (deferred).

## Task 5: Schema and skill — outward-reference constraint at the corpus's two ingress points (tasks.md §5)

- [x] **Step 1:** Insert one sentence into the `specs` artifact instruction's `Format requirements` block in `modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml`, after "Every requirement MUST have at least one scenario," stating the self-containment/no-change-reference constraint.
- [x] **Step 2:** Insert the matching procedural sentence-group into the archive step's instruction in the `apply:` block of the same file, after the sync/move bullets and before the satisfaction-projection paragraph.
- [x] **Step 3 (verify):** `openspec schema validate superpowers-bridge-wrspm` — confirmed "✓ Schema 'superpowers-bridge-wrspm' is valid" after both inserts.
- [x] **Step 4:** Insert one sentence into `modules/home/ai/plugins/formal-specification-and-refinement/.apm/skills/preferences-requirements-engineering/SKILL.md`, immediately after the designation-table section's closing paragraph and before `## Obstacle analysis`, stating the underlying principle.
- [x] **Step 5:** Record the rejected-mechanical-check decision (D7) in this change's `design.md`, naming the source-versus-delivered boundary and the portability rationale relayed from the user.
- Commit point: "schema+skill: state corpus self-containment constraint at the two points text enters the corpus" (deferred). Note: per `openspec/config.yaml`'s own context section, this edit takes effect fleet-wide only on the next nix-darwin activation of a consuming repository, not immediately.

## Task 6: Corpus-wide and schema validation (tasks.md §6)

- [x] **Step 1:** `openspec validate repair-episode-bound-requirements --type change --strict` → "Change 'repair-episode-bound-requirements' is valid".
- [x] **Step 2:** `openspec validate --all` → "Totals: 17 passed, 0 failed (17 items)".
- [x] **Step 3:** `openspec schema validate superpowers-bridge-wrspm` (final re-run) → "✓ Schema 'superpowers-bridge-wrspm' is valid".
- Commit point: none — validation only, no file changed in this task.

## Integration Verification

- [x] **Step 1:** Cross-check design.md's D5 table (11 rows) and D6 (2 named exceptions) against a fresh `grep -n "this change"` over the five *living* spec files (not yet touched, since this change has not been archived) — confirms the table is exhaustive against the original audit surface, not just against what this change happened to touch. 11 hits found, at exactly the 11 lines the table names; the 2 lines D6 excepts are among them.
