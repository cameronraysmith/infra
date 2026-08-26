## 1. Delta review

- [ ] 1.1 Confirm every content noun in the six restated `pi-agent-environment` requirements resolves against the `world-assumptions` designation table, or is explicitly recorded as an interface-stratum noun deferred to the `stratify-pi-agent-environment-interface` follow-up — verify: re-run section 8a's designation lint against `specs/pi-agent-environment/spec.md` and `specs/world-assumptions/spec.md` and confirm the finding list in `verify.md` §8a is unchanged or improved
- [ ] 1.2 Confirm each of the eight `world-assumptions` requirements (A1-A8) is phrased indicatively (states what is true) and carries exactly one `WHEN`/`THEN` violation-condition scenario naming the `pi-agent-environment` requirements that lose discharge — verify: read-through of `specs/world-assumptions/spec.md` against the dependency-map table in `design.md` §D0, confirming each row's right-hand column matches the corresponding scenario's `THEN` clause
- [ ] 1.3 Confirm no `MODIFIED` requirement in `specs/pi-agent-environment/spec.md` changed a MUST/SHALL clause's normative content relative to `openspec/specs/pi-agent-environment/spec.md` — verify: sentence-by-sentence comparison of each of the six modified requirements against the archived main spec, recording zero normative deltas in `verify.md` §4

## 2. Structural validation

- [ ] 2.1 Run `openspec validate extract-world-assumptions --type change --json` and resolve any reported issue — verify: command exits 0 and the JSON reports `"valid": true`
- [ ] 2.2 Run `openspec validate --all --json` to confirm this change does not break sibling capability validation — verify: JSON reports every item `"valid": true`

## 3. Human arbitration routing

- [ ] 3.1 Route the prompt-class contradiction (`Additional shell policy`'s prompt decision class versus `Fail-open policy`'s no-interactive-answer rule, per `design.md` Open Question 1) to Cameron for arbitration — verify: a recorded decision (message, issue comment, or a `design.md` update citing it) resolving or explicitly re-affirming the deferral exists and is linked from this change before archive
- [ ] 3.2 File the `stratify-pi-agent-environment-interface` follow-up (`design.md` D4) as its own OpenSpec change stub or tracked issue so the deferred relocation is not lost — verify: a change id or `issue://<N>` link exists and is recorded in `design.md`'s Migration Plan

## 4. Archive readiness

- [ ] 4.1 Confirm section 8 (designation lint, discharge coherence, alphabet check) in `verify.md` is current against the final content of `specs/world-assumptions/spec.md` and `specs/pi-agent-environment/spec.md` — verify: `verify.md`'s §8 tables were regenerated after the last edit to either delta file
- [ ] 4.2 Run `openspec archive extract-world-assumptions` only after task 3.1 is resolved (not silently deferred) and every task above is checked — verify: the archive command succeeds and `packages/docs/src/content/docs/development/traceability/satisfaction.md` is regenerated carrying this change's discharge rows, per `operations.archive.guidance` in `openspec/config.yaml`

## Integration Verification

- [ ] 5.1 Verify the full discharge chain end to end: every one of the eight `world-assumptions` requirements names at least one `pi-agent-environment` requirement it underwrites, every underwritten requirement's restated text names that assumption back, and `verify.md` §8b's discharge table shows no requirement silently dropped between the two deltas — verify: cross-reference `design.md`'s D0 dependency-map table against `verify.md` §8b row-by-row and confirm identical requirement coverage in both directions
