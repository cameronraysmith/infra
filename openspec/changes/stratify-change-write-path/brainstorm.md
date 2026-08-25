# Brainstorm — stratify the change write path

Raw capture of the design session. The full specification lives in
`docs/notes/development/methodology/meta-requirements-framework-integration.md`;
this file records the decision chain that produced it and is not a second copy of it.

## Background

The goal is to adopt a meta-requirements framework for formal-verification-driven development:
WRSPM (Gunter–Gunter–Jackson–Zave) as the ontology, with assume-guarantee contracts supplying the
composition algebra across heterogeneous verification tools, institution theory supplying
logic-independence, KAOS goal-obstacle analysis governing the layer above requirements, and AMDiRE
as the artefact-organizational macro-form. The two obligations are `W ∧ S ⇒ R` (the satisfaction
argument) and `P ⇒ S` (refinement).

The predecessor on disk is `docs/notes/development/methodology/acceptance-to-proof-co-optimization.md`,
which already models this territory as a closure operator over a Galois connection. This framework
names the layer that note left implicit: the requirements side of the connection.

This change is the first of three and carries only the write path — the schema and project config.
It must run under schema v1 because it authors v2, and nothing can author itself.

## Decision chain

**Q1 — Which framework, and is it one thing or several?**
Five artifacts (W, R, S, P, M) with two entailment obligations, plus three logic-agnostic
supplements and one artefact-organizational macro-form. The decisive property is that its
meta-requirements are themselves entailment obligations rather than stylistic advice, which is
what makes them checkable.

**Q2 — Where does it attach in the existing skill corpus?**
A search across all 133 first-party skills for the framework's vocabulary returns nothing —
`WRSPM`, `Zave`, `satisfaction argument`, `designation`, `indicative`, `optative`,
`shared phenomena`, `assume-guarantee`, `institution`, `KAOS`, `Parnas`, `four-variable` are all
absent. Everything adjacent we own is adjacent, not overlapping. Ownership therefore assigns
without contest: two new skills, thirteen edited targets, three named-but-unchanged, five
forbidden because they are CLI-generated.

**Q3 — Can the satisfaction argument live in the corpus as `openspec/satisfaction.md`?**
No. Verified at three enforcement layers: `relativePathSchema` rejects absolute paths and `..`
segments, `resolveArtifactOutputPath` joins to the change directory then asserts containment, and
glob resolution re-asserts canonical containment with symlink-cycle rejection. The only sanctioned
corpus writers are the CLI archive merge and the agent-driven sync skill, both delta-mediated and
both scoped to `openspec/specs/`. The projection goes to `docs/development/traceability/` instead;
the W and S strata go into the corpus as capabilities, which the delta machinery does reach.

**Q4 — Are the claimed collisions between the AMDiRE docs tree and the corpus real?**
Three of four are hypothetical. `requirements.md` and `context.md` do not exist (sharded away);
`work-items/` was never instantiated despite being prescribed in four places. Only the
architecture overlap is real, and only as stratum-role overlap with zero textual restatement. The
actual defect is different: divergence by abandonment, the hand-maintained layer frozen 2025-12
against a corpus live 2026-08, on disjoint subjects with no cross-references. The work is migration
and citation wiring, not deduplication.

**Q5 — Given omp asserts process discipline at the system level, should the generated context file shrink?**
No. omp does assert tool policy, delegation gates, verification, and a completeness contract — and
names our context file as the explicit opt-in channel for subagent work. But atomic's entire fixed
guidance is "Be concise in your responses" and "Show file paths clearly", with delegation and
workflow policy arriving only when those extensions are active. The generated file is atomic's only
process-discipline layer, so changes are additive.

**Q6 — Author v2 first and dogfood it, or specify everything before touching the schema?**
Author first. The schema is the only mechanically enforced artifact in the plan — the `requires[]`
DAG, output containment, and the delta grammar are enforced by code, while everything else is
prompt-ware that degrades silently. Sequence: this change under v1, then the skills change and the
routing change under v2. The skills change is the strongest dogfood because the skills it authors
are exactly what v2's new instructions reference.

**Q7 — Does dogfooding require a nix activation cycle mid-flight?**
No. `openspec schema fork` is unusable against a nix-store source: it copies mode-444 files while
preserving permissions, so its own staging temp file is unwritable and the fork aborts with EACCES.
A whole-directory symlink at the project tier works, reports `Source: project`, and validates clean.
It should be permanent rather than torn down: this repository owns the schema, so resolving it from
its own tree removes activation lag and makes testing a stale copy impossible. Activation is needed
exactly once across the three changes, at the boundary between the skills change and the routing
change.

**Q8 — Is the toolchain actually at 1.10.0?**
Four surfaces, not one. The CLI on PATH is 1.10.0 and the flake-pinned version the refresh app
injects is also 1.10.0. The vendored `openspec-*` skills were `generatedBy: 1.9.0` and have been
regenerated. The schema bundle's declared baseline is 1.4.1 and is bumped by this change. The
status JSON contract the schema's preconditions consume is intact on 1.10.0, so the dead
`workspace-planning` guard is dead and harmless rather than a correctness defect.

**Q9 — What did regenerating the vendored skills reveal?**
One substantive change across twelve files: upstream's tasks template now carries per-task
verification evidence, and renames its second group to "Integration Verification". That is
discharge coherence at task granularity, converged on independently. It does not reach us because
this schema ships its own bare `templates/tasks.md`, so the convention becomes a fifth framework
edit here. The two skills this schema's verify and apply steps invoke changed frontmatter only.

**Q10 — Does the cited evidence support the motivating premise?**
Partially, and the gap matters. The paper's definitions, its out-of-scope bracketing, and the
9%-too-weak / 15%-poor-translation figures are confirmed verbatim. But the causal attribution
belongs to a different, unquantified paragraph, the statistic rests on roughly 125 manually
inspected items with no stated aggregate N, and the paper makes no claim that intent-to-spec is
harder than spec-to-program — it declines to study the former at all. What it establishes is
narrower and sufficient: spec defects survive the `P ⇒ S` gate, because the rate is conditioned on
vericoding success. The step to "binding constraint" is our inference and must be attributed as
ours.

## Trade-offs accepted

Section 8's designation lint and discharge coherence are agent-executed, non-blocking, and
warn-and-record. `openspec validate` checks markdown structure and delta well-formedness and does
not check vocabulary grounding, alphabet discipline, or entailment. This change therefore buys
structure and instruction, not verification, and should not be described as buying more.

Five changes are already in flight and two carry artifact drift, so this change lands alone rather
than concurrently with the skills and routing changes.

## Falsification criteria for the dogfood

Committed in advance so the exercise cannot pass by construction:

- If every capability tags `behavioral`, the stratum tag is dead weight and should be deleted.
- If the designation lint reports clean on its first run, it is vacuous — no designation table
  exists yet, so a clean report is impossible if the lint works.
- If discharge coherence yields zero undischarged rows, suspect co-vacuity in the instrument
  itself, which is the same check section 8 imposes on specs.

## Open question carried forward

The Linear project binding. No existing project fits; the proposed key and name are
`satisfaction-argument` / "Ground requirements in a maintained satisfaction argument". Creating it
is an external artifact requiring explicit approval, so this change proceeds locally and Linear
catches up in a single transition via catch-up reconciliation.
