---
name: satisfaction-argument-audit
description: >
  Milestone audit of the satisfaction argument that a program meets a specification meets stated intent, generalized across proof institutions (Lean, Rust via Charon/Aeneas, Dafny, Verus). Use before a release or a milestone; before writing an external claim about what is verified, in a README, a design document's promise section, or a customer conversation; when inventorying a trust surface of sorry, axiom, unsafe, or assume declarations, or any opt-in verification mode that silently skips unmarked units; or when checking a formal specification against its stated intent by blind informalization. Runs in fresh context, after the proof gate is green, and produces a report that never gates on an exit code and never changes code. Points up to preferences-requirements-engineering for the WRSPM ontology this audit's gates discharge.
---

# Satisfaction argument audit

The satisfaction argument is the chain by which a program's behavior is claimed to meet a specification and that specification is claimed to meet a stated intent.
This skill audits that chain: it discharges the argument's two links per proof institution, inventories what the verification model bypasses, checks each externally-stated claim for vacuity, and drafts the wording a team may safely put in front of a reader who was not in the room.
It is a milestone audit, not an inner-loop check — it does not run on every edit, and running it there would waste its own cost, since it re-reads the whole surface from a clean context by design.

## When to use, when not

Reach for this skill before a release or a stopping point in a verification effort, before writing an external claim about what is verified — a README, a design document's promise section, a customer conversation — and whenever a trust-surface or spec-versus-intent question is on the table.
Do not reach for it as an inner-loop check: the per-edit proof-obligation gate and the per-annotation specification-versus-intent gate both belong to gate one and gate two below, run far more often and far more cheaply than this skill's own milestone pass.

This skill points up to `preferences-requirements-engineering` for the WRSPM pentad, the two discharge obligations, and the alphabet side conditions the gates below discharge; it does not restate them.
It points across to `refinement-driven-development` for gate one's Lean-to-Rust mechanics and check tiers, to `preferences-theoretical-foundations` for the institution-theory formalization behind stating an obligation per institution, to `preferences-essential-complexity` for the sorry-debt discipline the trust-surface inventory generalizes, to `bdd-gherkin-formulation` for the independent-literal-oracle rule the co-vacuity check specializes, and to `preferences-validation-assurance` for the severity criterion that calibrates the confidence this audit's evidence supports.

## The three gates

Three gates chain to close the satisfaction argument, and each is discharged differently.

**Gate one, program satisfies specification (`P ⊨ S`), discharged per institution.**
A Lean model discharges under `lake build`; a Rust implementation discharges under `cargo` plus the Charon-and-Aeneas lift-and-check round trip; a Dafny model discharges under `dafny verify`; a Verus model discharges under `verus`.
`refinement-driven-development` owns this leg's mechanics for the Lean-to-Rust institution, including its three check tiers from mechanical proof down to LLM triage — point there, do not restate.
One discipline travels with gate one regardless of institution: never verify against a stale generated artifact, because a green check on a proof emitted from an earlier version of the code certifies proofs about code that is no longer the code, so any regeneration step in the toolchain runs before the verifier, every time.
Runs on every edit that touches a verified artifact, as the innermost loop.
Does not run as a one-time gate before a milestone — by the time a milestone is reached, gate one has already been green continuously, and this skill's own re-verification in gate three is a confirmation, not a first check.

**Gate two, specification satisfies intent (`S ⊨ intent`), by blind informalization.**
This is the leg this skill exists to make reproducible, since no formal checker can discharge it: the specification typechecks and the theorem proves regardless of whether the formalizer captured what was meant.
The procedure, the four verdicts, and the three operational rules that govern it are below.
Runs whenever a formal obligation's text — a `requires`/`ensures` pair, a Lean theorem statement, a contract clause — changes, and its own verdicts are cached against that text so it need not re-run on unrelated proof work.
Does not run before gate one is green: a confirmed verdict on an obligation with no discharging proof is a claim about the specification, not about the code, and reporting it as though it were the latter overstates what happened.

**Gate three, the milestone audit.**
This is the whole skill's namesake activity: in a fresh context with no prior conversation, re-run gate one, inventory the trust surface, walk the claims status table, and draft safe external wording.
Runs at a stopping point — before a release, before an external claim, after a proof push that flips a roadmap stage to verified, or whenever the promise a design document makes has moved since the last audit.
Does not run in the edit-prove loop and does not run per proof iteration: its cost is the cost of reading everything from scratch, and that cost is only justified when the state is stable enough that the reading will not be invalidated by the next commit.

## Blind informalization, the reproducible procedure

Extract the formal obligation's text — the `requires`/`ensures` pair, the theorem statement, the contract clause under test.
Have a model back-translate that text to English without showing it the intent statement the obligation is supposed to discharge; only after the back-translation exists, compare it against the intent.
Emit exactly one of four verdicts.

| Verdict | Meaning |
|---|---|
| Confirmed | the back-translation matches the stated intent; record it as a vetted discharge |
| Disputed | the obligation says less, or something else, than the intent; carries a weakening type describing the discrepancy |
| Gap | an intent statement exists with no formal obligation backing it |
| Unchecked | a backed obligation whose round trip never returned a verdict — a backend or LLM failure, not a judgment |

Three operational rules travel with every run of this procedure.
The direction rule is fixed: the intent statement is ground truth, and a disputed verdict is resolved by strengthening the formal specification toward the intent, never by softening the intent to match what the specification happened to say — softening the intent makes both sides agree about the wrong thing.
The caching rule follows from the verdicts being a pure function of the obligation and intent text: no re-run is needed after later proof work unless the obligation's text or the intent statement itself changed, so a proof-only commit does not invalidate an existing verdict.
The no-exit-code-gating rule is absolute: an automated pipeline must never gate on this check's exit code, because a disputed or gap verdict is a finding for a human to look at, not a pass/fail signal, and findings live in the report the procedure produces, never in a process return value.

## The trust-surface inventory

Enumerate every construct that weakens or bypasses the verification model, per backend, each with its justification or a flag for missing one.
Lean: `sorry`, `axiom`, `native_decide` — the last of these also adds the compiler to the trusted base and surfaces as a new entry under `#print axioms` for anything depending on it.
Rust: `unsafe` blocks, and any invariant the surrounding proof assumes rather than derives.
Dafny: `assume` statements and `{:axiom}`-attributed declarations.
Verus: `assume`.

One category generalizes across every one of these institutions and is easy to miss because it produces no visible marker: any opt-in verification mode that lets one annotated unit pull a file into scope silently skips every unmarked unit in that file, so a clean report from such a mode can read as complete while covering only a fraction of the surface.
The set of unmarked units under such a mode is itself part of the trust surface, and the inventory must state what fraction of each file the report actually covers rather than only listing the explicit bypasses.

This inventory is the existing sorry-debt discipline generalized across institutions; `preferences-essential-complexity` owns that discipline in its general form — point there, do not restate it.

## The claims status table

One row per claim stated somewhere external to the proof — a design document's promise section, a README, a properties catalog — mapping it to whether the proof chain actually supports it, with three checks run before any claim is marked supported.

Is the precondition satisfiable: a `requires` clause that no input can satisfy makes the paired `ensures` vacuously true and the claim proves nothing.
Is the postcondition non-vacuous: could the `ensures` clause hold for a plausibly wrong implementation, or is it phrased so loosely that anything would satisfy it.
Is the pair co-vacuous: were the design claim and the formal specification derived from the same guess about what the system should do, rather than one checking the other — two artifacts that agree can both be wrong, and an audit run in fresh context by someone who did not write either is precisely the check that would catch it.

Co-vacuity is the same failure `bdd-gherkin-formulation` blocks at the scenario level with its independent-literal-oracle rule: an assertion that re-derives its expected value through the same path that produced the claim can only confirm the claim equals itself, whether that path is a production function or a specification written from the same guess as the prose it is meant to check.
The two checks are siblings and should cite each other rather than each re-deriving the argument for why a self-referential check is worthless.

## Safe external wording, and the prohibition

Gate three's deliverable is two paired statements: a claim precise enough to be quotable and exactly true given the current state of the proof chain, and an explicit list of what may not yet be claimed.
Draft the claim from what the claims status table actually supports, not from what the design document originally promised — the audit's job is to narrow the gap between the two, not to paper over it.

The prohibition is absolute and admits no institution-specific exception: never claim a guarantee end to end.
A trust-surface bypass, an unverified backend, or a gate-two gap anywhere in the chain breaks an end-to-end claim regardless of how much of the chain is solid.
State the boundary in both places a reader might encounter the claim: the promise section of whatever design document states what is guaranteed, and a boundary section stating what is not, so a reader who only sees one of the two still sees the limit.

## Calibration

Gate two is a model round trip, not a theorem, and every verdict it emits is LLM judgment rather than a proof — a confirmed verdict narrows the intent-to-specification gap without eliminating it, and a disputed verdict is a prompt to look, not evidence of a bug.
Stating this plainly matters more here than elsewhere in the corpus: a skill whose subject is honest claims about what is verified would be self-refuting if it overclaimed what its own central procedure establishes.

This audit is not validation in the mechanical sense that `openspec validate` or a type checker performs.
It produces evidence toward a confidence judgment, and the calibration of that judgment — how much confidence a given severity of evidence actually buys, and when evidence has decayed past the point of being credible — is owned by `preferences-validation-assurance`, the home of the severity criterion; point there rather than inventing a severity scale for this skill alone.

Gate one is per-institution because a satisfaction obligation is only meaningful once it is stated over an institution: what counts as a sentence, a model, and a satisfaction relation between them is fixed by the institution, not by this skill.
`preferences-theoretical-foundations` owns that formalization, including `references/institution-theory.md`; point there rather than re-deriving Goguen-and-Burstall institution theory here.

## Where the audit runs in our workflow

The OpenSpec schema `superpowers-bridge-wrspm` carries a non-blocking section eight in its `verify` artifact instruction: a designation lint, discharge coherence, and an alphabet check.
That section and this skill's gate three are not the same check running at different volumes; they differ in what they check and when.
Section eight is per-change and scoped to that change's own delta specs — it lints whether a `behavioral` capability's content nouns resolve against the designation table, and whether every requirement added or modified in the change names what discharges it, running at every verify step of every change as a lightweight, mechanically-checkable pass.
Gate three is the milestone audit over the accumulated corpus, run in fresh context at a stopping point, and it checks something section eight cannot: it re-runs the actual proof gate, inventories what the verification model bypasses, and produces wording fit for a reader outside the project — none of which a lint over vocabulary grounding can establish, because a spec can pass every designation and alphabet check and still be unverified, or verified against the wrong intent.

The satisfaction projection at `docs/development/traceability/satisfaction.md` follows a regeneration discipline for the same reason section eight's discharge-coherence table does: it is rebuilt wholesale from the synced main specs at archive time and never patched.
A rebuilt discharge table is trustworthy because every row reflects the current corpus; a patched one accumulates exactly the staleness the artifact exists to prevent, one unrefreshed row at a time.
Gate three's own report is a different artifact from this projection — it is a qualitative milestone audit including LLM judgment and human-facing wording that no mechanical rebuild can produce — but the discipline of never patching a derived discharge table applies to gate three's output for the same reason it applies to `satisfaction.md`.

## See also

- `preferences-requirements-engineering` — the WRSPM pentad, the two discharge obligations, the alphabet side conditions, and the designation table this audit's gates check against; the ontology owner this skill points up to.
- `refinement-driven-development` — the Lean-to-Rust mechanics and the three check tiers that discharge gate one for that institution.
- `preferences-theoretical-foundations` — institution theory, the formalization behind stating an obligation over an institution rather than in the abstract.
- `preferences-essential-complexity` — the sorry-debt discipline this skill's trust-surface inventory generalizes across institutions.
- `bdd-gherkin-formulation` — the independent-literal-oracle rule the co-vacuity check specializes to formal specifications.
- `preferences-validation-assurance` — the severity criterion and confidence promotion chain that calibrate what this audit's evidence is worth.
