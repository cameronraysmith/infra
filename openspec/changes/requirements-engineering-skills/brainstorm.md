# Brainstorm — requirements engineering skills

Raw capture. The design was settled in the session recorded at
`docs/notes/development/methodology/meta-requirements-framework-integration.md` and in the
preceding change `stratify-change-write-path`, whose brainstorm carries the full decision chain.
This file records only what is specific to authoring the skills, and is not a second copy of either.

## What this change is

The second of three. `stratify-change-write-path` carried the write path — the schema and project
config. This change carries the skill content: two new skills, plus the two framework components
assigned to an existing skill.

It is also the dogfood. The skills authored here are exactly what the previous change's new schema
instructions reference, so if the stratum tag, the designation lint, or the discharge check are
unworkable, authoring these skills under them is the most favourable possible case in which to
find out.

## Ownership, and why it is two skills rather than one

A search across all 133 first-party skills for the framework's vocabulary returned nothing, so
ownership assigns without contest. The split follows the corpus convention that pairs a conceptual
`preferences-*` skill with a bare-named operational one, as `preferences-validation-assurance`
pairs with `verification-before-completion` and `preferences-event-modeling` pairs with
`event-modeling-greenfield`.

The hub is loaded when authoring or reviewing requirements — it holds the ontology and the
obligations. The audit is loaded at a milestone, before an external claim, or at the verify gate —
it holds a procedure that produces a report. Those are genuinely different triggers at genuinely
different times, which is what makes two skills pay rent rather than one skill with two moods.

Both are hosted in `formal-specification-and-refinement` so that they sit beside
`refinement-driven-development`, which owns the `P ⇒ S` obligation. Placing them together means
both obligations live in one plugin group and each is discoverable from the other.

`preferences-domain-driven-architecture` was considered and rejected: it is the requirements
*discovery* home, whereas WRSPM is a verification-obligation ontology.

## Content decisions specific to authoring

The hub owns the pentad, the two obligations and their alphabet side conditions, the four dark
corners as checkable discipline, the designation table, indicative-versus-optative separation,
KAOS goal-obstacle analysis, Parnas' four-variable model for the physical-world case, and the
WRSPM-versus-AMDiRE shear. The shear matters concretely rather than academically: it is why
`docs/development/requirements/` is specification-side today and why genuinely world-referent
requirements have no home in it.

The audit owns the three gates generalized across institutions. Gate one is `P ⇒ S` discharged per
backend. Gate two is specification-versus-intent by blind informalization — back-translate the
formal obligation to English without seeing the intent statement, then compare. Gate three is the
milestone audit: re-verify in fresh context, inventory the trust surface, check the claims table,
produce safe external wording.

Three items in the audit have no current owner anywhere in the corpus and are the reason it earns
its place. The trust-surface inventory generalizes our existing sorry-debt discipline across
backends. The co-vacuity check asks whether the design claim and the formal specification were
derived from the same guess, since two artifacts that agree can both be wrong — which is the same
failure our Gherkin discipline blocks with the independent-literal-oracle rule, so the two should
cite each other. And the prohibition on claiming a guarantee end to end is stated nowhere in our
corpus today.

## The evidence caveat that must survive into the skills

The vericoding benchmark establishes that specification defects survive the `P ⇒ S` gate, because
its defect rate is measured conditioned on vericoding success. It does not establish that the
intent-to-specification direction is harder than the specification-to-program direction; it
declines to study the former at all. The step from the former to the latter is our inference and
both skills must attribute it as ours. The statistic also rests on roughly 125 manually inspected
items with no stated aggregate N, which makes it suggestive rather than strong.

## Open question carried forward

Whether the two skills' mutual routing should be symmetric. The corpus idiom is one-directional
pointers — a skill points up to its orchestrator and across to anchor owners without installing a
downward pointer back. Between a conceptual hub and its own operational sibling, the direction is
not obvious, and the answer should follow whichever existing pair is closest in shape.
