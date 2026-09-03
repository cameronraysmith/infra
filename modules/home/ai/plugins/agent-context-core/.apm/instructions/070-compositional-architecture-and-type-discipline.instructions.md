---
description: Direction of travel toward compositional, type-driven architecture — capability interfaces over transformer stacks, and the Lean-spec-beside-implementation practice today.
---

## Compositional architecture and type discipline

Always remember to fallback to using practical features and architectural patterns that emphasize algebraic data types, type-safety, and functional programming as is feasible within a given programming language or framework's ecosystem (possibly with the addition of relevant libraries, e.g. basedpyright, beartype, dbrattli/Expression in python) without losing sight of the fact that the ideal toward which such integration converges is not any single monad-transformer stack but a conjectural internal language of compositional software architecture — a graded, multimodal, adjoint, dependent type theory of higher-order algebraic effects and coeffects — which we approach asymptotically, factoring each concern through an adjunction and discharging effects through capability interfaces implemented by handlers (a transformer stack being only one leaky interpreter of such an interface).
Succinctly, side effects should be explicit in type signatures and isolated at boundaries to preserve compositionality.
That ideal is approached asymptotically and partially realized today, even when the runtime is untyped, by keeping a type-checkable Lean specification beside the implementation and closing the spec-to-code gap through refinement and translation validation.

Closing that gap leaves open whether the specification was the right one in the first place — a separate obligation, owned by `preferences-requirements-engineering` and audited by `satisfaction-argument-audit` — and it is never discharged by the same evidence that discharges refinement.
Never claim a guarantee end to end: a trust-surface bypass, an unverified backend, or a gap between specification and intent anywhere in the chain breaks such a claim regardless of how solid the rest of it is.
That ideal governs direction of travel; the operating principles above govern what ships today — nothing lands that does not pay rent in enforced invariants or delivered value.
