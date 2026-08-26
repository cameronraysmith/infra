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

**Deferred, not done here**: this dogfood run also finds that several of the same six requirements name machine-side artifacts — `permission-gate`, `atomic`, jj probe argv, the `@` prefix — that a strict `behavioral`-vocabulary rule would relocate to a separate interface-stratum capability.
That relocation is out of scope for this change; `design.md` records the decision to defer it and names the follow-up.
The prompt-class contradiction between `Additional shell policy`'s `prompt` decision class and `Fail-open policy`'s no-interactive-answer rule is likewise recorded as an open question for human arbitration, not resolved here.

## Capabilities

### New Capabilities

- `world-assumptions` (stratum: world): the eight indicative assumptions this repository's Pi tooling rests on, each with a violation-condition scenario, plus the designation table grounding the terms `pi-agent-environment`'s behavioral requirements use.

### Modified Capabilities

- `pi-agent-environment` (stratum: behavioral): six requirements restated to name the `world-assumptions` requirement(s) their discharge depends on; no requirement's MUST/SHALL content changes.

## Impact

This change touches only `openspec/changes/extract-world-assumptions/specs/`; it adds or modifies no Nix module, no package, and no generated context file, so it requires no activation and no rollback plan.
At archive time, `operations.archive.guidance` in `openspec/config.yaml` regenerates `packages/docs/src/content/docs/development/traceability/satisfaction.md` from the post-sync corpus, which will carry this change's discharge rows.
Two items are deliberately left open rather than closed by this change: the interface-stratum relocation for the six touched requirements (deferred to a named follow-up change) and the prompt-class contradiction between `Additional shell policy` and `Fail-open policy` (routed to human arbitration).
`verify.md` §8b records both as undischarged rows with their respective follow-up references, rather than omitting or silently accepting either gap.
