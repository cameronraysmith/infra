## 1. Delta review

- [x] 1.1 Confirm every content noun in the six restated `pi-agent-environment` requirements resolves against the `world-assumptions` designation table, or is explicitly recorded as an unresolved machine noun under `design.md` D4's declined-but-revivable interface relocation — verify: re-run section 8a's designation lint against `specs/pi-agent-environment/spec.md` and `specs/world-assumptions/spec.md` and confirm the finding list in `verify.md` §8a is unchanged or improved
- [x] 1.2 Confirm each of the eight `world-assumptions` requirements (A1-A8) is phrased indicatively (states what is true) and carries exactly one `WHEN`/`THEN` violation-condition scenario naming the `pi-agent-environment` requirements that lose discharge — verify: read-through of `specs/world-assumptions/spec.md` against the dependency-map table in `design.md` §D0, confirming each row's right-hand column matches the corresponding scenario's `THEN` clause
- [x] 1.3 Confirm no `MODIFIED` requirement in `specs/pi-agent-environment/spec.md` changed a MUST/SHALL clause's normative content relative to `openspec/specs/pi-agent-environment/spec.md` — verify: sentence-by-sentence comparison of each of the six modified requirements against the archived main spec, recording zero normative deltas in `verify.md` §4

## 2. Structural validation

- [x] 2.1 Run `openspec validate extract-world-assumptions --type change --json` and resolve any reported issue — verify: command exits 0 and the JSON reports `"valid": true`
- [x] 2.2 Run `openspec validate --all --json` to confirm this change does not break sibling capability validation — verify: JSON reports every item `"valid": true` — re-run after `annotate-discharge-evidence` landed its delta: 16/16 items pass, 0 failed

## 3. Prompt-class resolution and interface-relocation decision

- [x] 3.1 Resolve the prompt-class contradiction (`Additional shell policy`'s prompt decision class versus `Fail-open policy`'s no-interactive-answer rule) using the pinned `permission-gate` engine's actual headless behavior — verify: `design.md` D5 cites `permission-gate/index.ts` lines 105-106 (rev `c700f300707db5345727052682c88e3064030aa2`) showing the `!ctx.hasUI` guard blocks before `showReviewPrompt` is called; `specs/pi-agent-environment/spec.md`'s `Additional shell policy` and `Fail-open policy` both record the reconciliation instead of "not yet reconciled"; `verify.md` §8b drops the undischarged-pending-arbitration status for both rows — SATISFIED
- [x] 3.2 Confirm no `stratify-pi-agent-environment-interface` follow-up is filed, `design.md` D4 records the reconsidered decision to decline it with a falsifiable revival condition, and `proposal.md`'s deferral language matches (no promised scheduled follow-up) — verify: `design.md` D4 states the decision and the revival condition in testable terms; `proposal.md`'s "Deferred indefinitely, not scheduled" paragraph and Impact section state the same, not a named-follow-up promise — SATISFIED

## 4. Archive readiness

- [x] 4.1 Confirm section 8 (designation lint, discharge coherence, alphabet check) in `verify.md` is current against the final content of `specs/world-assumptions/spec.md` and `specs/pi-agent-environment/spec.md` — verify: `verify.md`'s §8 tables were regenerated after the last edit to either delta file
- [ ] 4.2 Run `openspec archive extract-world-assumptions` only after every task above is checked — verify: the archive command succeeds and `packages/docs/src/content/docs/development/traceability/satisfaction.md` is regenerated carrying this change's discharge rows, per `operations.archive.guidance` in `openspec/config.yaml` — NOT SATISFIED: every gating task above is now checked, but running `openspec archive` is explicitly out of scope for this pass regardless of the gate, per this change's own non-goals; left for the orchestrator

## Integration Verification

- [x] 5.1 Verify the full discharge chain end to end: every one of the eight `world-assumptions` requirements names at least one `pi-agent-environment` requirement it underwrites, every underwritten requirement's restated text names that assumption back, and `verify.md` §8b's discharge table shows no requirement silently dropped between the two deltas — verify: cross-reference `design.md`'s D0 dependency-map table against `verify.md` §8b row-by-row and confirm identical requirement coverage in both directions
