# Author the WRSPM requirements hub and satisfaction-argument audit skills

## Why

A search across all 133 first-party skills for the vocabulary of the WRSPM framework returns
nothing. `WRSPM`, `Zave`, `satisfaction argument`, `designation`, `indicative`, `optative`,
`shared phenomena`, `assume-guarantee`, `institution`, `KAOS`, `Parnas`, and `four-variable` are
absent from the corpus. The preceding change taught the write path to ask for a stratum tag, a
designation lint, and a discharge argument, but nothing in the corpus explains what those are or
how to produce one. This change supplies the missing content.

The gap is not symmetric across the two obligations. `refinement-driven-development` owns
`P ⇒ S` — the program-refines-specification leg — thoroughly, including its three check tiers and
the honest position that mechanical proof is the ideal rather than a requirement. Nothing owns
`W ∧ S ⇒ R`. `preferences-validation-assurance` comes closest, stating the refinement order over a
specification-implementation pair, but it names only `P` and `S` and has neither the world nor the
implication direction. `preferences-compositional-continuous-verification` names the question and
then explicitly disclaims it, distinguishing verification from validation and declaring itself a
verification discipline that treats validation as an upstream channel it does not own.

The evidence that the requirements-to-specification bridge deserves this attention is narrower
than it is often stated. The vericoding benchmark measures its specification-defect rate
conditioned on vericoding success, which establishes that specification defects survive the
`P ⇒ S` gate. It does not compare the difficulty of the two directions and declines to study
intent-to-specification at all. The inference that the bridge is therefore the binding constraint
is ours, and both skills must attribute it as ours rather than to the paper.

## What Changes

Two new skills are added to the `formal-specification-and-refinement` package, placing them beside
`refinement-driven-development` so both obligations live in one group.

`preferences-requirements-engineering` is the conceptual hub. It owns the W/R/S/P/M pentad, the two
entailment obligations with their alphabet side conditions, the four dark corners rendered as
checkable discipline, the designation table as the enforcement artifact, indicative-versus-optative
separation, KAOS goal-obstacle analysis as the layer above requirements, Parnas' four-variable
model as the physical-world specialization, and the WRSPM-versus-AMDiRE shear.

`satisfaction-argument-audit` is the operational sibling. It owns the three-gate chain generalized
across institutions, blind informalization for the specification-versus-intent gate, the
trust-surface inventory, the claims status table with its satisfiability, non-vacuity, and
co-vacuity checks, safe external wording, and the prohibition on claiming a guarantee end to end.

Existing skills are edited only where an unlisted concept would silently rot. This change carries
the two framework components assigned to `preferences-theoretical-foundations` — assume-guarantee
contract meta-theory and institution-theoretic logic-independence — together with the single
disambiguation clause that `executable-specification-testing` requires, because its
design-by-contract section declares that holding the senses of "contract" apart is part of what it
owns. The remaining routing edits are deferred to the third change.

## Capabilities

### New Capabilities

- `requirements-stratification` — **behavioral**. The discipline the hub skill provides: what the
  strata are, which vocabulary each admits, and how a requirement is grounded and discharged.
- `satisfaction-argument-audit` — **behavioral**. The audit procedure and its report, named 1:1
  with its skill following the `openspec-linear-sync` precedent where a skill and its capability
  share a name.
- `skill-corpus-interface` — **interface**. What the delivered corpus must expose at the boundary
  between a developer and the artifact they load: that a skill with a given name is resolvable,
  that its trigger surface admits the situations it must fire on, and that its stated ownership
  boundaries hold. This is the stratum against which the two behavioral capabilities' requirements
  are discharged.

### Modified Capabilities

None. `first-party-skill-distribution` is owned by the in-flight `apm-skills-marketplace` change
and governs how skills are packaged and delivered, which this change does not alter — it adds
skills through the existing mechanism rather than changing it.

### Stratum tagging note, corrected

This section originally recorded both capabilities as `behavioral` with no `world` or `interface`
capability, and argued that was legitimate because the subject is the agent instruction corpus,
which has no machine boundary. That argument was wrong, and the discharge coherence check
contradicted it.

Running the check by hand returned ten requirements, all of them undischarged, against zero
interface capabilities. A requirement of the form "an agent must be able to determine which stratum
a statement belongs to" is discharged by a property of the delivered corpus — that it contains a
skill whose content states the stratum rules — and that is an interface property at the boundary
between the developer and the artifact they load. The boundary was there. The original note argued
it away, and did so after the first falsification criterion had already flagged the same
rationalisation as suspect.

`skill-corpus-interface` is therefore added above, and the change is no longer all-behavioral.

No `world` capability is introduced, and that omission is deliberate rather than another
rationalisation. The indicative assumptions this change would rest on — that a harness reads the
delivered skill tree, that a description under the length limit is presented to the model — are
assumptions about the harnesses rather than about this change's subject, and they belong in a
`world-assumptions` capability extracted from `pi-agent-environment`, which the decision record
identifies as its own separate change. Introducing a partial one here would fragment it.

The first falsification criterion consequently does not fire, and not for the reason originally
given. The tag partitions this change once the check is applied honestly, and it partitions
`pi-agent-environment` non-trivially when applied retrospectively.

## Impact

New skill sources under
`modules/home/ai/plugins/formal-specification-and-refinement/.apm/skills/`, and edits to
`preferences-theoretical-foundations` and `executable-specification-testing`. All are nix-managed
sources whose delivered counterparts under `~/.claude/skills/` are read-only store symlinks, so the
new skills are not loadable until activation. Activation is therefore a task in this change and a
precondition of the third change, which invokes them.

No behavior outside the agent instruction corpus changes. No package, module, or machine
configuration is touched. The dependency on the preceding change is one-directional: this change's
artifacts are authored under the schema that change installed.
