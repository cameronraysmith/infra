# Extract world assumptions implementation plan

> **For agentic workers:** use `superpowers:subagent-driven-development` to work this plan task-by-task, or execute it directly since it is a single-reviewer documentation change with no code.

**Goal:** extract the eight indicative world assumptions embedded in `pi-agent-environment` into a new `world-assumptions` capability, and restate the six dependent requirements to name them, without changing any behavioral content.

**Architecture:** two OpenSpec delta specs (`specs/world-assumptions/spec.md` ADDED, `specs/pi-agent-environment/spec.md` MODIFIED) plus the planning artifacts that justify and verify them; no code, no Nix module, no runtime component.

**Tech Stack:** OpenSpec CLI 1.10.0, the `superpowers-bridge-wrspm` schema, markdown.

---

## Task 1: Delta review

- [ ] **Step 1:** For each of the six modified `pi-agent-environment` requirements, list its content nouns and check each against the `world-assumptions` designation table.
- [ ] **Step 2:** For every noun that does not resolve, confirm it names a machine-side artifact belonging to the deferred interface follow-up (`design.md` D4) rather than a missing world designation.
- [ ] **Step 3:** Record the resulting resolved/unresolved noun lists in `verify.md` §8a.
- [ ] **Step 4:** For each of A1-A8, confirm its scenario's `THEN` clause names exactly the requirements listed in `design.md` §D0's dependency-map row.
- [ ] **Step 5:** Diff each modified requirement's MUST/SHALL sentences against `openspec/specs/pi-agent-environment/spec.md`'s current text, confirming zero normative deltas, and record the result in `verify.md` §4.

## Task 2: Structural validation

- [ ] **Step 1:** Run `openspec validate extract-world-assumptions --type change --json`.
- [ ] **Step 2:** Fix any reported structural issue and re-run until `"valid": true`.
- [ ] **Step 3:** Run `openspec validate --all --json` and confirm no sibling capability regressed.
- [ ] **Step 4:** Paste both JSON outputs into `verify.md` §1.

## Task 3: Human arbitration and follow-up filing

- [ ] **Step 1:** Send the prompt-class contradiction (`design.md` Open Question 1) to Cameron for a decision.
- [ ] **Step 2:** Record the decision, or an explicit re-affirmed deferral, in `design.md` and update the corresponding undischarged rows in `verify.md` §8b.
- [ ] **Step 3:** File the `stratify-pi-agent-environment-interface` follow-up as a change stub or tracked issue.
- [ ] **Step 4:** Link the follow-up from `design.md`'s Migration Plan.

## Task 4: Archive readiness

- [ ] **Step 1:** Re-run section 8 (8a, 8b, 8c) against the final delta content and refresh `verify.md`.
- [ ] **Step 2:** Confirm every `tasks.md` checkbox above is checked, or record why a remaining `[ ]` does not block archive.
- [ ] **Step 3:** Do not run `openspec archive` until task 3's arbitration step is resolved rather than silently skipped.

---

No task in this plan is marked `[~]` deferred: this is a documentation-only change with no manual dogfood or live-environment step, so `verify.md` §7 is left blank per that section's own instruction.
