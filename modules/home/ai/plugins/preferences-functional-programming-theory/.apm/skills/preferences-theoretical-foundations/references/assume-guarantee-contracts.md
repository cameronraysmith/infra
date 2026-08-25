---
title: Assume-guarantee contracts as the composition algebra
---

## Contents

- [The contract as an assumption-guarantee pair](#the-contract-as-an-assumption-guarantee-pair)
- [The operators: refinement, parallel composition, conjunction](#the-operators-refinement-parallel-composition-conjunction)
- [Why the algebra is semantic, not syntactic](#why-the-algebra-is-semantic-not-syntactic)
- [Relation to the capability-interface and adjunction framing](#relation-to-the-capability-interface-and-adjunction-framing)
- [Where the system-level realization lives](#where-the-system-level-realization-lives)
- [Scope and citation](#scope-and-citation)

This file is on the foundations spine.
It develops one claim: independently built and independently verified components compose into one statable system-level theorem via an assume-guarantee contract algebra, defined once, semantically, over any component model rather than any one proof tool.

## The contract as an assumption-guarantee pair

A contract `C = (A, G)` pairs the assumptions `A` a component makes about the behavior of its environment with the guarantees `G` it then commits to providing that environment, on the condition that `A` holds (Benveniste, Caillaud, Delahaye, Passerone, Raclet, Reinkemeier, Sangiovanni-Vincentelli, Damm, Henzinger, and Larsen, *Contracts for System Design*, Foundations and Trends in Electronic Design Automation 12(2-3), 2018).
The meta-theory keeps "component" and "compatibility" deliberately abstract notions rather than fixing them to any concrete formalism, which is what lets the same algebra range over a Dafny method, a Lean-mirrored Rust module, an SMT-checked contract in Meyer's runtime sense (see executable-specification-testing), or a component with no formal treatment at all.

## The operators: refinement, parallel composition, conjunction

Refinement `⪰` orders contracts by substitutability: `C′ ⪰ C` ("`C′` refines `C`") holds when `C′` assumes no more than `C` and guarantees no less — `C′` accepts every environment `C` accepts, and under that broader acceptance still promises everything `C` promised.
The literature states the same order with the set inclusions running the other way on assumptions and guarantees (a refining contract's assumption set is a superset, its guarantee set a subset, of the refined contract's), which is the standard "require no more, promise no less" substitutability shape; the labelling convention (`⪰` versus the literature's `⪯` pointed the other way) varies by source, the content does not.
A component satisfying a refining contract can always be substituted wherever the refined contract was assumed.

Parallel composition `⊗` derives the contract of an interacting pair of components from their own.
Given compatible contracts `R1 = (A1, G1)` and `R2 = (A2, G2)`, the composite `R1 ⊗ R2` has guarantee `G_{R1⊗R2} = G1 ∧ G2` — both hold — and assumption `A_{R1⊗R2}`, the weakest condition the *environment of the pair* must still supply once each component's own guarantee has been used to help discharge the other's assumption.
Concretely, `A_{R1⊗R2}` is the maximal `A` such that `A ∧ G2 ⇒ A1` and `A ∧ G1 ⇒ A2`: everything either component assumed that the other component's guarantee already supplies drops out of the composite's residual assumption, which is exactly circular assume-guarantee reasoning made algebraic (the composition is reported as reminiscent of the Abadi–Lamport composition axiom).
`⊗` is defined only for compatible contracts; incompatibility is itself a checkable condition of the algebra, not a silent default.

Conjunction `∧` is the greatest lower bound of the refinement order: given two contracts stated on the same component from different viewpoints — a safety property and a timing property, say — `C1 ∧ C2` is the most general contract that refines both, letting several concern-specific specifications on one component combine into one without redeclaring the component.

## Why the algebra is semantic, not syntactic

None of the three operators reference how `A` or `G` is established.
A guarantee can be discharged by a Dafny postcondition proof, by the Lean-to-Rust correspondence refinement-driven-development performs, by a runtime-checked icontract predicate (see executable-specification-testing), or by nothing more than documentation for an unverified component; the algebra composes the contracts regardless.
This is exactly what licenses one statable theorem about a product system containing a Dafny-verified kernel, an Aeneas-verified Rust component, and an unverified UI: `⊗` composes their three contracts into one, and the resulting theorem states only that the assumption-discharge chain closes across the product, never how any one leg's guarantee was discharged.

## Relation to the capability-interface and adjunction framing

This skill's thesis treats the capability interface as the stable primitive at one component's boundary and any carrier that discharges it — a transformer stack, a handler record, an algebraic-effect runner — as an interchangeable interpreter never itself the interface.
A contract's guarantee `G` is that same move stated at the boundary *between* components rather than within one: the obligation is named at the interface, and refinement `⪰` is the order in which one discharge mechanism can always be swapped for a stricter one wherever the looser contract was assumed, mirroring how a stricter handler can always stand in for a looser one.
Composition `⊗` is the corresponding move for assembling several such interfaces into a system: it is a routing heuristic for reading the composite's residual assumption as the "forgetful" part left undischarged internally and the composite's guarantee as the "free" join of what each side already provides, offered as an organizing analogy to the capability-interface move rather than as an asserted functorial correspondence with it.

## Where the system-level realization lives

`preferences-compositional-continuous-verification` owns the system-level realization of this algebra: its operating-envelope-plus-regulator pairs compose into a single closure operator, and the operating envelope is precisely the assumption half `A` of a contract, checked by an automated regulator rather than by a proof.
This file states the composition theory; that skill states the realization, and is not restated here.

The word "contract" carries other senses this file does not use: `preferences-bounded-context-design` owns the data-contract and published-language dialects that govern schema and semantics crossing a context boundary, and `preferences-algebraic-laws` owns the "laws are contracts" sense of ∀-quantified equational obligations verified by property tests.
Neither is restated here; the Benveniste sense above is a further, distinct sense, disambiguated alongside the others in `executable-specification-testing`'s design-by-contract section.

## Scope and citation

Grounded on Benveniste et al. 2018, the assume-guarantee contract monograph, for the `(A, G)` pair, the refinement order, and the `⊗`/`∧` operators.
Scope: the exact set-theoretic formulas above (the refinement inclusions; the maximal-`A` residual formula for `⊗`) are corroborated through citing secondary literature (Incer, *The Algebra of Contracts*, UC Berkeley EECS-2022-99; the arXiv treatments of mechanically verified and tensor-product readings of contract composition) rather than page-checked against the monograph directly in this authoring.
Treat the formulas as an accurate secondary-sourced statement of the theory, not as independently re-verified against the primary text.
