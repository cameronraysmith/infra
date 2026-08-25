## Context

The corpus of first-party skills has no vocabulary for the WRSPM (Gunter–Gunter–Jackson–Zave) requirements framework.
A search across all 133 first-party skills for `WRSPM`, `Zave`, `satisfaction argument`, `designation`, `indicative`, `optative`, `shared phenomena`, `assume-guarantee`, `institution`, `KAOS`, `Parnas`, and `four-variable` returned nothing (recorded in the design record, `docs/notes/development/methodology/meta-requirements-framework-integration.md`).
The preceding change, `stratify-change-write-path`, taught the OpenSpec write path — the `superpowers-bridge-wrspm` schema — to ask for a stratum tag on every capability, a designation lint, and a discharge argument in `verify.md` section 8, but nothing in the corpus explained what those terms mean or how to produce the artifacts they require.
This change supplies that missing content.

The gap between the two entailment obligations WRSPM names is not symmetric.
`refinement-driven-development` already owns `P ⇒ S`, the program-refines-specification leg, thoroughly: three check tiers, the Lean-to-Rust round trip, and the position that mechanical proof is the ideal rather than a requirement.
Nothing in the corpus owned `W ∧ S ⇒ R`, the satisfaction argument.
`preferences-validation-assurance` came closest, stating a refinement order over a specification-implementation pair, but names only `P` and `S`.
`preferences-compositional-continuous-verification` named the question and explicitly disclaimed it as an upstream channel outside its own scope.

This change is also this repository's own dogfood of the schema it is implemented under: the two new skills are exactly what `superpowers-bridge-wrspm`'s instructions reference by name, so if the stratum tag, the designation lint, or the discharge check were unworkable, authoring under them was the most favourable case in which to find out.
Both new capabilities were initially tagged `behavioral`, and that tagging turned out to be wrong on its own terms once the discharge check the schema itself mandates was run by hand against this change.
Section "Decisions", D3, records that finding; it is the design decision this document exists to preserve, not an incidental footnote.

## Goals / Non-Goals

**Goals:**

Author `preferences-requirements-engineering` as the conceptual hub owning the WRSPM pentad, the two obligations and their alphabet side conditions, the four dark corners as checkable discipline, the designation table, indicative/optative separation, KAOS goal-obstacle analysis, Parnas' four-variable model, and the WRSPM-versus-AMDiRE shear.

Author `satisfaction-argument-audit` as the operational sibling owning the three-gate chain generalized across proof institutions, blind informalization for specification-versus-intent, the trust-surface inventory, the claims status table with satisfiability/non-vacuity/co-vacuity checks, safe external wording, and the never-claim-end-to-end prohibition.

Extend `preferences-theoretical-foundations` with assume-guarantee contract meta-theory and institution theory, and extend `executable-specification-testing`'s contract-senses disambiguation with the one clause it was missing, because that skill states holding the senses apart is part of what it owns.

Wire routing edits from every existing skill that would otherwise send a reader nowhere for these concepts, and from `modules/home/tools/agents-md.nix`, so the corpus and the generated agent context both reach the new owners.

Correct the proposal's stratum tagging once the discharge-coherence check contradicted it, and record that correction rather than silently fixing it.

**Non-Goals:**

This change does not modify `first-party-skill-distribution` (owned by the in-flight `apm-skills-marketplace` change) — it adds skills through the existing packaging mechanism, not a new one.

This change does not introduce a `world-assumptions` capability. The indicative assumptions a full satisfaction argument for this corpus would eventually rest on — that a harness reads the delivered skill tree, that a description under the length limit is presented to the model — are assumptions about the harnesses (`pi-agent-environment`'s subject), not about this change's subject, and the design record identifies their extraction as a separate, later change.

This change does not alter the `superpowers-bridge-wrspm` schema itself (owned by the preceding change, `stratify-change-write-path`) or the vendored `openspec-*` skills.

## Decisions

### D1: Two skills, not one

**Choice**: Split the framework into a conceptual hub (`preferences-requirements-engineering`) and a bare-named operational sibling (`satisfaction-argument-audit`), following the corpus convention `preferences-validation-assurance` / `verification-before-completion` and `preferences-event-modeling` / `event-modeling-greenfield`.

**Rationale**: The hub is loaded when authoring or reviewing requirements — it holds the ontology and the two obligations. The audit is loaded at a milestone, before an external claim, or at the verify gate — it holds a procedure that produces a report. Those are genuinely different triggers at genuinely different times: an agent authoring a requirements document has no use for the trust-surface inventory or blind-informalization procedure mid-draft, and an agent running a milestone audit has no use for re-deriving the pentad. Two skills that each fire on their own trigger pay rent; one skill with two moods would fire on the union of both triggers and load content the caller does not need on either occasion.

**Alternatives considered**: A single skill covering both. Rejected because it would load the audit's institution-generalized gate mechanics into every requirements-authoring session and vice versa, and because it would blur the "this skill states obligations, that skill checks them" separation both skills' own Scope sections now state explicitly (`preferences-requirements-engineering` SKILL.md lines 137–145; `satisfaction-argument-audit` SKILL.md lines 13–16).

**Boundary**: source-versus-delivered. Both skills are authored at `modules/home/ai/plugins/formal-specification-and-refinement/.apm/skills/<name>/SKILL.md` and reach `~/.claude/skills/<name>/` only as read-only nix-store symlinks after `nix build .#apm-skills-compose` and activation; nothing under the delivered path was edited directly, and both source files were confirmed present and both delivered symlinks confirmed resolving before this design document was written.

### D2: Host location — `formal-specification-and-refinement`, not `preferences-domain-driven-architecture`

**Choice**: Place both new skills in the `formal-specification-and-refinement` plugin group, beside `refinement-driven-development`.

**Rationale**: `refinement-driven-development` already owns the other half of the two-obligation pair, `P ⇒ S`. Hosting both obligations in one group means each is discoverable from the other without a cross-group jump, and the routing edit `refinement-driven-development` gained (SKILL.md line 59: "its companion, `W ∧ S ⇒ R`... is owned by `preferences-requirements-engineering`") makes that discoverability concrete rather than aspirational.

**Alternatives considered**: `preferences-domain-driven-architecture`, rejected because it is the requirements *discovery* home (EventStorming, Domain Storytelling, the activity that produces requirements), whereas WRSPM is a verification-obligation ontology (what a requirements document must satisfy once it exists) — adjacent territory, not the same territory.

**Boundary**: source-versus-delivered, same as D1 — this is a choice of which `.apm/skills/` subtree under `modules/home/ai/plugins/` the source files live in, not a vendored-content decision; `formal-specification-and-refinement` is a first-party group with no `generatedBy` frontmatter anywhere in it.

### D3: The stratum-tagging correction — the finding this document exists to preserve

**Original claim**: The proposal originally tagged both new capabilities `behavioral` and argued no `interface` capability was warranted because the subject — the agent instruction corpus — has no machine boundary.

**What falsified it**: Running section 8's discharge-coherence check by hand against this change (as the schema instructs an agent to do at verify time) returned ten requirements, every one undischarged, against zero interface capabilities. The check does not merely fail to endorse the original claim; it contradicts it. A requirement of the form "an agent must be able to determine which stratum a statement belongs to" is discharged by a property of the *delivered corpus* — that it contains a skill whose content states the stratum rules and that the skill is resolvable and triggers correctly — and that is an interface property, at the boundary between a developer and the artifact they load, not a behavioral property about world conduct.

**Why the error is significant, not incidental**: The design record notes this is the second time the same rationalisation was caught. The first falsification criterion — "if every capability in a change tags `behavioral`, the tag is dead weight" — fired on this exact same all-behavioral tagging, and the "the subject has no machine boundary" defense was explicitly not accepted on its own the first time, because it is the generic "the test does not apply here" move that makes a falsification criterion worthless. The proposal's author then re-asserted the same defense in the Capabilities section anyway. The discharge-coherence check, one section later, caught the same rationalisation a second time — this time by contradiction rather than by suspicion. That an instrument disagreed with the person who wrote it, about the change that introduced it, on a point that person had already defended once, is the strongest available evidence that section 8 has content rather than being ceremony.

**Choice**: Add `skill-corpus-interface` as a third capability, tagged `interface`, naming exactly what the delivered corpus must expose at the developer/artifact boundary: that a claimed skill name resolves, that its trigger surface admits the situations it must fire on within the harness's length limit, and that stated ownership boundaries and pointers hold across the corpus. The proposal's "Stratum tagging note, corrected" section rewrites the original argument rather than silently deleting it.

**What was deliberately not added**: A `world` capability. The indicative assumptions a complete argument would eventually need — that a harness reads the delivered skill tree, that it presents a description under its length limit to the model — are assumptions about the harnesses, which is `pi-agent-environment`'s subject, not this change's. The design record identifies extracting them into a `world-assumptions` capability as a separate future change; introducing a partial one here, scoped only to this change's own requirements, would fragment that future extraction rather than anticipate it. This is a second-order application of the same discipline: having been caught rationalising the interface omission, the temptation is to overcorrect and pad in a `world` capability too. That pull was noticed and declined, and the boundary properties named in `skill-corpus-interface`'s own Trust boundary section (spec.md lines 57–64) are honest about what they do *not* reach: content correctness, whether guidance is followed, and whether following it produces a correct outcome.

**Boundary**: This decision does not sit on the vendored-versus-first-party or source-versus-delivered boundary; it is a capability-ontology decision about what the delta specs claim, not about which files are edited or where they are delivered from.

### D4: Pull the eleven routing edits into this change rather than deferring them to a third change

**Choice**: An earlier plan deferred the cross-corpus routing edits (pointers from nine existing skills, plus `agents-md.nix`, to the two new owners) to a later change. This change withdraws that deferral and carries them itself.

**Rationale**: The routing edits produce no capability of their own — they are not a new thing a reader can invoke. They are instead the acceptance evidence for this change's own `skill-corpus-interface` requirement that "stated ownership boundaries hold across the corpus" and that "a pointer names an owner that does not carry the concept" never occurs. Deferring them to a separate change would mean shipping a requirement in this change with no evidence discharging it until a later, unscheduled change landed — an undischarged requirement left implicit rather than recorded as such, which is exactly what the requirements-stratification capability's own "Discharge of a requirement is stated, not implied" requirement forbids. Carrying them here means the requirement and its discharge evidence land in the same change.

**Alternatives considered**: Ship the two new skills alone and route to them later. Rejected per the rationale above — verified by inspection during this verify pass (see `verify.md` §8b) that all nine routing-edit targets named in the proposal do in fact carry the concept they are pointed at, closing the loop within this change rather than leaving it open.

**Boundary**: source-versus-delivered. All nine routing-edit targets and `agents-md.nix` are first-party sources under `modules/home/ai/plugins/` and `modules/home/tools/`; none of the routing edits touch a vendored `openspec-*` skill or anything under an `assets/` path, both of which are on this change's forbidden list.

### D5: Attribute the requirements-to-specification asymmetry as our inference, not the vericoding paper's claim

**Choice**: Both new skills state the vericoding benchmark's finding narrowly — specification defects survive the `P ⇒ S` gate because the defect rate is measured conditioned on vericoding success (roughly 9% too weak, a further 15% poorly translated) — and explicitly attribute the stronger claim, that the requirements-to-specification bridge is therefore the binding constraint, as this project's own inference rather than the paper's.

**Rationale**: The paper (`~/Downloads/arxiv-2509.22908/src/vericoding.tex`, verified against the source in the design record) declines to study the intent-to-specification direction at all; it only measures defects downstream of a successful `P ⇒ S` proof. Presenting the stronger asymmetry as an established finding would overclaim what the source supports. The figures also rest on manual inspection of roughly 125 items with no stated aggregate sample size, which the skills describe as suggestive rather than strong (`preferences-requirements-engineering` SKILL.md, "What the evidence actually supports", lines 125–135).

**Boundary**: N/A — an evidentiary-calibration decision, not a filesystem-boundary one.

## Risks / Trade-offs

[Risk] The requirements written in world vocabulary under this discipline are markedly more abstract than the interface-flavoured requirements the corpus habitually writes, and correspondingly less immediately testable, which could discourage adoption → Mitigation: this cost is stated plainly in the design record rather than hidden, so an adopter expects the trade rather than discovering it mid-change; the durability payoff (requirements that do not break when a file format changes) is named alongside the cost.

[Risk] Two new skills add to an already large corpus (177 skills post-delivery), increasing the chance of trigger-surface collision or a reader loading the wrong one → Mitigation: both frontmatter descriptions state precise, mutually exclusive "reach for this / do not reach for this" boundaries (`preferences-requirements-engineering` SKILL.md "Scope" section; `satisfaction-argument-audit` SKILL.md "When to use, when not" section), and `skill-corpus-interface`'s own requirements make trigger-surface adequacy and ownership-boundary consistency first-class, checkable properties rather than an unstated hope.

[Trade-off] No automated test guards any of this content — the skills are prose, and the guard level is `none` → accepted because the corpus-wide convention for skill content is prose reviewed by the routing and ownership checks `skill-corpus-interface` now names, not unit tests over natural-language guidance; the honest position, stated in `satisfaction-argument-audit` itself ("Calibration" section), is that a skill about honest claims regarding what is verified would be self-refuting if it overclaimed what its own procedures establish, and the same restraint applies to claiming test coverage this change does not have.

[Trade-off] `skill-corpus-interface`'s three requirements are discharged only for delivery mechanics (resolvability, trigger-surface length, ownership-pointer consistency spot-checked across the routing edits), not for content correctness — whether following a skill's guidance actually produces correct agent behaviour is explicitly out of its trust boundary → accepted deliberately; see `verify.md` §8b for the full discharge table and the partial-discharge status recorded against every behavioral requirement.

## Migration Plan

No deployment, endpoint, or database change. This change adds two skill sources and edits eleven existing first-party sources plus `agents-md.nix`, all delivered through the existing `nix build .#apm-skills-compose` mechanism and the existing home-manager activation path.

Activation was performed as part of this change's implementation, prior to this design document being written: `nix build .#apm-skills-compose` was confirmed to produce 177 skills including both new ones, and both `~/.claude/skills/preferences-requirements-engineering` and `~/.claude/skills/satisfaction-argument-audit` were confirmed to resolve as nix-store symlinks. No further activation step is required by this change; the schema's own note (`superpowers-bridge-wrspm`'s `context`) states the schema resolves from this repository's own tree via a project-tier symlink and needs no activation cycle of its own, and that is orthogonal to the skill-delivery activation already performed.

Rollback, if ever needed, is a plain source revert of the nine routing-edit files, the two new skill directories, the `preferences-theoretical-foundations` reference additions, the `executable-specification-testing` clause, and `agents-md.nix`, followed by a rebuild — no data migration or state to roll back.

## Open Questions

The brainstorm (`brainstorm.md`, "Open question carried forward") left one question open: whether the two new skills' mutual routing should be symmetric, given the corpus idiom of one-directional pointers from a skill up to its orchestrator and across to anchor owners, without an installed downward pointer back. As delivered, both skills do point to each other (`preferences-requirements-engineering` SKILL.md "See also" line 149; `satisfaction-argument-audit` SKILL.md "See also" line 118), which resolves the question toward symmetric routing for a hub/operational-sibling pair specifically, rather than the general one-directional idiom. This resolution is recorded here rather than re-litigated, since the delivered content already reflects it; a future skill-corpus audit may want to confirm whether this precedent should generalize to other hub/sibling pairs in the corpus (`preferences-validation-assurance` / `verification-before-completion` was not re-audited under it as part of this change).

Whether the `world-assumptions` capability extraction from `pi-agent-environment`, deferred in D3 above, should be scheduled as the next change in this sequence is left to the orchestrator; this design document does not schedule it, only records why it was not done here.
