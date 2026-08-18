---
name: preferences-essential-complexity
description: Complexity must pay rent in domain invariants or value delivered to its consumer. Use when designing or reviewing abstractions, type signatures, module boundaries, specifications, or proofs; when deciding what to delete versus keep; when scaling review rigor by refinement-chain position (Lean spec, public API, schema, persisted data, spec-constrained implementation); or when handling sorry, admit, unsafe, or vacuous-proof debt.
---

# Essential complexity

Shared root: every element of an artifact — a type, an abstraction, a sentence, a qualifier — must pay rent in invariants enforced or value delivered to its consumer.
Stated confidence must match evidence.
Uncertainty is information to state precisely, never a substitute for a decision: commit, state the tradeoff taken and what would change your mind.
Scale care to blast radius: what binds others (specs, APIs, published prose) gets strong care; what a spec already constrains gets fast decisions.

## Complexity must pay rent; domain invariants are the rent

Whatever encodes domain invariants — types, proofs, Decider-style structure — is essential; never strip it.
Everything else must trace to a spec construct or a present need stated in one sentence, or be deleted.
No speculative generality: one-instance typeclasses, unused parametricity, forwarding layers, unasked-for configurability all fail the rent test.

## Commit; scale care to position in the refinement chain

The Lean spec layer binds everything downstream — change it only with explicit invariants and a flagged review request.
Public APIs, schemas, and persisted data get strong care.
Implementation already constrained by a spec gets fast decisions: decide, note assumptions in the commit, do not stop to ask.
This governs artifact-level choices within confirmed intent; task-level ambiguity still routes through the session protocol's ask-first rule.

## Rigor must be falsifiable

The spec is the source of truth; divergence is a defect, not a fork.
Every `sorry`, `admit`, or `unsafe` is flagged debt, never silent.
Never weaken a statement or strengthen a hypothesis to close a proof — if the honest theorem won't go through, stop and say so.
Check theorems aren't vacuous; derive tests from spec properties, not from the code.
A proof of the wrong theorem is worse than none.

## Related skills

For the Lean-to-Rust refinement mechanics this policy governs, see `refinement-driven-development`.
For severity and evidence-quality criteria, see `preferences-validation-assurance`.
For the asymptotic architectural ideal this rent rule bounds, see `preferences-theoretical-foundations`: the ideal governs direction of travel; this skill governs what ships today.
