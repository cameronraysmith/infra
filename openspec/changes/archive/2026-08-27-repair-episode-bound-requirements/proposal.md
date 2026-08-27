## Why

An audit of all 77 requirements across the 10 capabilities in `openspec/specs/` found a cluster that fail the corpus's durability test: true of the system, checkable at any time, still meaningful after any one implementation episode ends. Three requirements in `pi-agent-environment` were synced verbatim from an archived change's closing task rows and constrain "Implementation," a one-episode role. Five other capabilities carry `this change` references predating this session that dangle once their originating change moves under `archive/`. Left uncorrected, the corpus keeps accumulating requirements a later reader cannot check without first excavating change history that may no longer exist.

## What Changes

**Stale one-time task, deleted**
- From: `pi-agent-environment` carries `Stale Pi version cleanup`, a one-time task naming an aging Pi 0.83/0.84.1 version pair.
- To: the requirement is removed; nothing is lost because the archived change carries it verbatim with its own design row, task mapping, and verify coverage naming the standing check locations.
- Reason: a completed one-time task is not a standing property of the system.
- Impact: non-breaking; `openspec/specs/pi-agent-environment/spec.md` loses one requirement and its scenario.

**Episode-bound activation policy, replaced with durable requirements**
- From: `Human-only activation` and `Confirmation-gated live verification` constrain "Implementation" (the one episode's implementing agent) and name "Cameron" by name.
- To: two new requirements, `Activation requires explicit permission` and `Post-activation confirmation gate`, state the same standing policy about "an agent" and "the human operator" generally, using the user's verbatim wording as normative content with the permission carve-out preserved.
- Reason: the underlying policy is real and recorded nowhere else in the repository; deletion alone would silently drop it.
- Impact: non-breaking; the policy strengthens (durable, generic) rather than weakens.

**Rollback preservation, rephrased**
- From: ties the durable rollback-availability property to a link "recorded before activation."
- To: states the same property as a post-activation link comparison with no dependency on a prior recording step.
- Reason: the asserted property was already durable; only the phrasing was episode-bound.
- Impact: non-breaking; same guarantee, checkable at any later time.

**Change-fencing stripped from graphical-desktop-session**
- From: "niri ... MUST NOT be assembled into this change" and "no home-manager desktop toggle is added by this change," plus "deferred to a separate, reversible follow-up change" planning language.
- To: the durable boundary claim alone — niri is not part of this capability; home-manager carries no desktop toggle.
- Reason: the fencing and planning language go stale once any follow-up change lands or archives.
- Impact: non-breaking; the durable claim is unchanged, only the episode-bound wrapper is removed.

**Outward `this change` references removed corpus-wide**
- From: `apple-laptop-hardware-support`, `bare-metal-install-path`, `encrypted-zfs-root`, `graphical-desktop-session`, and `stratified-change-authoring` carry eleven literal `this change` references predating this session.
- To: each is stated inline, repointed at an in-corpus sibling requirement, or dropped, per instance (see design.md's outward-reference table). Two instances (`bare-metal-install-path:25`, `encrypted-zfs-root:148`) are date-anchored narration of an already-completed console session with a durable normative core and are left unchanged, recorded as a deliberate decision.
- Reason: a corpus requirement may reference another corpus requirement but never a change, because a change's directory moves under `archive/` and the reference dangles.
- Impact: non-breaking; prose-only clarification, no requirement semantics change except where explicitly noted above.

**Schema and skill: outward-reference constraint added at the point text enters the corpus (session-scope addition)**
- From: no schema instruction or skill stated the self-containment/no-change-reference constraint anywhere; a mechanical check enforcing it was proposed, then rejected as repository-local and non-portable against a user-global schema bundle.
- To: `modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml` states the procedural constraint in its `specs` artifact instruction and its archive-step instruction (one to two sentences each, at the two points where text enters or crosses into the corpus); `modules/home/ai/plugins/formal-specification-and-refinement/.apm/skills/preferences-requirements-engineering/SKILL.md` states the underlying principle once, next to the designation-table section.
- Reason: prose in a user-global schema bundle reaches every consuming repository; a check in this one flake reaches only this repository.
- Impact: non-breaking; both are additive prose, verified by `openspec schema validate superpowers-bridge-wrspm`.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `pi-agent-environment` (behavioral): remove `Stale Pi version cleanup`; replace `Human-only activation` and `Confirmation-gated live verification` with two durable requirements; rephrase `Rollback preservation`.
- `graphical-desktop-session` (behavioral): strip change-fencing and stale planning language from two requirement/scenario clauses while preserving the durable niri/home-manager boundary claim; remove one further outward `this change` reference.
- `apple-laptop-hardware-support` (behavioral): remove one outward `this change` reference, restated inline as the two credential states already named in the surrounding text.
- `bare-metal-install-path` (behavioral): remove four outward `this change` references (one requirement-level, three scenario-level), leaving one explicitly-excepted date-anchored narration line unchanged.
- `encrypted-zfs-root` (behavioral): remove one outward `this change` reference, leaving one explicitly-excepted date-anchored narration line unchanged.
- `stratified-change-authoring` (behavioral): normalize one generic schema-role reference from "this change" to "the change" for internal consistency with the same sentence's existing "the change folder."

## Impact

Affected: `openspec/specs/pi-agent-environment/spec.md`, `openspec/specs/graphical-desktop-session/spec.md`, `openspec/specs/apple-laptop-hardware-support/spec.md`, `openspec/specs/bare-metal-install-path/spec.md`, `openspec/specs/encrypted-zfs-root/spec.md`, `openspec/specs/stratified-change-authoring/spec.md`, via delta specs under this change's `specs/` directory. No code, module, or flake-check paths are touched; this is a prose-only corpus-hygiene change. A separate, session-scoped addition (outside `openspec/specs/`, authorized mid-session) touches the schema bundle and one skill file under `modules/home/ai/`, recorded above and in design.md, to state the durability constraint at its two points of ingress into any project's corpus.
