---
linear_story_id: "d5376668-ffd7-4d84-b838-b30cd642d7f8"
linear_story_identifier: "CAM-37"
linear_story_title: "Extract world assumptions embedded in the Pi agent environment spec"
linear_story_url: "https://linear.app/cameronraysmith/issue/CAM-37/extract-world-assumptions-embedded-in-the-pi-agent-environment-spec"
linear_story_state: "Backlog"
linear_team: "CAM"
linear_project: "requirements-engineering"
last_synced_state: "Backlog"
last_synced_at: "2026-08-26T18:45:03Z"
review_round: 0
attempt_log:
  - { at: "2026-08-26T18:45:03Z", transition: "Backlog->Backlog", outcome: "posted", note: "retroactive bind; planning and implementation artifacts complete before binding; archiving in this pass" }
---

## Why

Eight indicative world assumptions are embedded inside six `pi-agent-environment` requirements, most visibly "Pi has no permission system" inside `Fail-open policy`'s justification prose.
Nothing currently records the condition under which one of these assumptions would stop holding, so a requirement's rationale can evaporate without anyone noticing.
Extracting them into a dedicated `world-assumptions` capability with violation-condition scenarios turns each assumption into a standing, checkable claim, and the designation table this introduces gives the repository's designation lint its first real, non-empty target.

## What Changes

**World-assumptions capability**
- From: no capability holds indicative world assumptions or a designation table; the assumptions live as unattributed justification prose inside `pi-agent-environment` requirements.
- To: a new `world-assumptions` capability states the eight indicative assumptions `pi-agent-environment` currently embeds, each with a violation-condition scenario naming the requirements that lose discharge if it fails, plus a designation table grounding the double-sensed terms `session`, `package`, `policy`, `@`, `mutation`, `activation`, `probe`, `machine`, `host`, and `interface`.
- Reason: an assumption recorded nowhere it can be invalidated cannot be monitored; a justification clause fused into an optative MUST is the four-dark-corners violation this repository's own stratum-tag dogfood run already found in `pi-agent-environment`.
- Impact: additive; no existing requirement's normative content changes.

**Pi-agent-environment capability**
- From: `Permission-gate reuse`, `Additional shell policy`, `Non-Bash edit and write policy`, `Git default-branch boundary`, `Jj diamond boundary`, and `Fail-open policy` rest on or state assumptions without naming them; two of the six carry the assumption as inline "because" justification prose.
- To: the same six requirements are restated, with identical MUST/SHALL content, to name the specific `world-assumptions` requirement(s) their discharge depends on, replacing inline justification prose where it exists and adding a naming sentence where it does not.
- Reason: makes each requirement's discharge argument checkable rather than implicit, per `stratified-change-authoring`'s discharge-coherence discipline.
- Impact: non-behavioral. This change does not alter what the Pi agent environment does; it changes only what its requirements say about why.

**Deferred indefinitely, not scheduled**: this dogfood run also finds that the tool-call policy requirements — `Permission-gate reuse`, `Additional shell policy`, `Non-Bash edit and write policy`, `Git default-branch boundary`, and `Jj diamond boundary` — name machine-side artifacts — `permission-gate`, `atomic`, jj probe argv, the `@` prefix — that a strict `behavioral`-vocabulary rule would relocate to a separate interface-stratum capability.
That relocation is declined for this change and is not scheduled to any named follow-up; `design.md` D4 records the reasoning and states a falsifiable revival condition — a second defect traceable to `pi-agent-environment`'s mixed behavioral/interface vocabulary, of the same kind the `Fail-open policy` scope ambiguity this change corrects was, not the designation lint's routine unresolved-noun finding recurring on its own.
The prompt-class contradiction between `Additional shell policy`'s `prompt` decision class and `Fail-open policy`'s no-interactive-answer rule, previously recorded as an open question for human arbitration, is resolved by this change: a source lookup against the pinned `permission-gate` engine confirmed a session without a UI channel never reaches an interactive prompt, so the two requirements govern disjoint reachable conditions rather than conflicting ones; see `design.md` D5.

## Capabilities

### New Capabilities

- `world-assumptions` (stratum: world): the eight indicative assumptions this repository's Pi tooling rests on, each with a violation-condition scenario, plus the designation table grounding the terms `pi-agent-environment`'s behavioral requirements use.

### Modified Capabilities

- `pi-agent-environment` (stratum: behavioral): six requirements restated to name the `world-assumptions` requirement(s) their discharge depends on; no requirement's MUST/SHALL content changes.

## Impact

This change touches only `openspec/changes/extract-world-assumptions/specs/`; it adds or modifies no Nix module, no package, and no generated context file, so it requires no activation and no rollback plan.
At archive time, `operations.archive.guidance` in `openspec/config.yaml` regenerates `packages/docs/src/content/docs/development/traceability/satisfaction.md` from the post-sync corpus, which will carry this change's discharge rows.
One item is deliberately left open rather than closed by this change: the interface-stratum relocation for the tool-call policy requirements (`Permission-gate reuse`, `Additional shell policy`, `Non-Bash edit and write policy`, `Git default-branch boundary`, `Jj diamond boundary`), declined and deferred indefinitely per `design.md` D4's falsifiable revival condition rather than promised to a scheduled follow-up.
`verify.md` §8b records the affected rows as undischarged for that reason, rather than omitting or silently accepting the gap; the prompt-class contradiction that previously left `Additional shell policy` undischarged is resolved per `design.md` D5 and no longer contributes to that status.
