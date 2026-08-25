---
title: Institutions and logic-independent specification
---

## Contents

- [Signatures, sentences, models](#signatures-sentences-models)
- [The satisfaction condition](#the-satisfaction-condition)
- [Refinement as theory interpretation](#refinement-as-theory-interpretation)
- [Why this formalizes Rule 7](#why-this-formalizes-rule-7)
- [What this buys](#what-this-buys)
- [Scope and citation](#scope-and-citation)

This file is on the foundations spine.
It develops one claim: the choice of proving logic can be factored out of a specification's statement entirely, and institution theory is where that factoring is made precise rather than assumed.

## Signatures, sentences, models

An institution (Goguen and Burstall, *Institutions: Abstract Model Theory for Specification and Programming*, Journal of the ACM 39(1), 1992) is a category of signatures `Sig`, a functor `Sen : Sig → Set` assigning each signature `Σ` the sentences that can be stated over its vocabulary, a functor `Mod : Sig^op → Cat` assigning each signature `Σ` the category of `Σ`-structures (models) and their homomorphisms, and, for each signature `Σ`, a satisfaction relation `⊨_Σ` between `Σ`-models and `Σ`-sentences.
A specification, in this framework, is a *theory*: a signature together with a set of sentences over it, its axioms.
"Theory" here is the technical signature-plus-axioms pairing this literature uses throughout, not the everyday sense.

## The satisfaction condition

The one law that turns the four-part bundle above into an institution, rather than an arbitrary tuple, is the satisfaction condition: for any signature morphism `f : Σ → Σ′`, any `Σ′`-model `M′`, and any `Σ`-sentence `φ`,

```
M′ ⊨_Σ′ Sen(f)(φ)   ⟺   Mod(f)(M′) ⊨_Σ φ
```

Translating a sentence forward along `f` and checking it against a `Σ′`-model gives the same verdict as reducing the `Σ′`-model backward along `f` and checking the original sentence against it.
Truth is invariant under change of notation.

That single law is the entire generalization, and it is stated with no fixed syntax, no fixed proof system, and no fixed model class named anywhere in it.
Lean's dependent-type judgments, Dafny's Hoare-logic verification conditions, Verus's linear ghost-state assertions, and a row-typed language's record-calculus subtyping obligations are each a candidate institution: each supplies its own `Sig`, `Sen`, `Mod`, and `⊨`, and each is required only to satisfy the one condition above to qualify as one.

## Refinement as theory interpretation

Given two theories `(Σ, Ax)` and `(Σ′, Ax′)`, possibly in different institutions, a refinement from the first to the second is exhibited as a theory interpretation: a signature morphism (within one institution) or an institution morphism/comorphism (across institutions) under which every model of the target theory reduces to a model that satisfies the source theory's axioms.
The Sannella–Tarlecki structured-specification program (Sannella and Tarlecki, *Foundations of Algebraic Specification and Formal Software Development*, Springer, 2012) develops this move in full for building and refining specifications compositionally: refinement is not a bespoke notion re-invented per tool but a single theory-interpretation move, defined once at the institution-theoretic level and instantiated per logic.

## Why this formalizes Rule 7

Rule 7 of this skill states the practitioner move without naming the theory: "keep a type-checkable Lean architecture spec the implementation mirrors, regardless of runtime language."
"Regardless of runtime language" is exactly the institution-independence claim.
The Lean spec is a theory over Lean's own institution — its signature is the Lean type-and-term vocabulary, its models are the type-theoretic structures Lean's kernel accepts, and satisfaction is type-checking.
Mirroring that spec in a Python, Rust, or TypeScript implementation asserts a theory interpretation from Lean's institution into whichever institution the implementation's own verification apparatus supplies: Dafny's Hoare-logic institution for a Dafny component, Verus's institution for a Rust component under linear ghost state, or an untyped-but-icontract-checked institution (the design-by-contract rung of executable-specification-testing) for a Python component whose refinement types are only a value-level residue.
The mirror is trustworthy exactly to the extent that a genuine theory interpretation, and not merely an informal resemblance, holds between the two institutions, and the correspondence check refinement-driven-development performs for the Rust leg is one concrete discharge of that interpretation, mechanical when the Charon/Aeneas round trip is tractable and differential or LLM-compared otherwise.

## What this buys

Two payoffs follow from stating the obligation at the institution level rather than against one tool.
First, the *shape* of an obligation — a signature and a satisfaction relation to check against it — survives a change of proof assistant or verification backend; only the interpretation changes, not the obligation's statement.
Second, it licenses one composite theorem across an assume-guarantee product whose legs live in different institutions (see assume-guarantee-contracts.md): each leg's guarantee is a sentence over its own component's institution, and the product-level claim that the assumption-discharge chain closes is a claim about satisfaction relations, not about any single leg's syntax.

The concrete, per-language placement of which technique (property test, contract, SMT/concolic check, mechanical proof) discharges an obligation in which language is a tool-placement matrix owned by `executable-specification-testing/references/cross-language-verification.md`; this file states the logic-independence principle that matrix is one instance of, and does not restate the matrix.

## Scope and citation

Grounded on Goguen and Burstall 1992 for the institution definition and the satisfaction condition, and on Sannella and Tarlecki 2012 for the structured-specification and refinement-as-theory-interpretation development.
Scope: this file grounds the abstract framework and the satisfaction condition as stated in the primary literature; both citations are corroborated through citing secondary literature and standard institution-theory expositions rather than page-checked against the primary texts directly in this authoring.
It does not certify that any particular pairing among this repository's verification backends (Lean into Dafny, Dafny into Verus, or any other) has been mechanically exhibited as an institution comorphism; that remains a per-project, per-pair verification obligation, most concretely the Rust leg refinement-driven-development already performs.
