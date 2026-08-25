---
title: Meta-requirements framework integration decision
description: Which skills change, how, and what moves in agents-md.nix to adopt WRSPM as the meta-requirements layer of formal-verification-driven development
created: 2026-08-25
---

# Meta-requirements framework integration decision

This note records three decisions and the evidence behind them: which skills change, precisely how each changes, and what changes in `modules/home/tools/agents-md.nix`.
The framework being adopted is WRSPM (the Gunter–Gunter–Jackson–Zave reference model) as the meta-requirements ontology, with assume-guarantee contracts supplying the composition algebra, institution theory supplying logic-independence, KAOS goal-obstacle analysis governing the layer above requirements, and AMDiRE supplying the artefact-organizational macro-form.
Its predecessor on disk is `acceptance-to-proof-co-optimization.md`, which already models the same territory as a closure operator over a Galois connection; this framework names the layer that note left implicit — the requirements side of the connection.

## Evidence that shaped the decision

Four findings changed the plan that entered this session.

The skill corpus contains zero of the framework's vocabulary.
A search across all 133 first-party skills for `WRSPM`, `Zave`, `Jackson`, `four dark corners`, `satisfaction argument`, `designation`, `indicative`, `optative`, `shared phenomena`, `problem frame`, `assume-guarantee`, `Benveniste`, `institution`, `Goguen`, `KAOS`, `van Lamsweerde`, `obstacle analysis`, `Parnas`, and `four-variable` returns nothing.
Every adjacent concept we already own is adjacent, not overlapping, so ownership can be assigned without contest and no existing skill needs its scope renegotiated.

OpenSpec cannot host a corpus-level satisfaction artifact.
`resolveArtifactOutputPath` joins `generates` to the change directory and then asserts containment, `relativePathSchema` rejects absolute paths and any `..` segment, and glob output resolution re-asserts canonical containment with symlink-cycle rejection — three independent enforcement layers.
The only sanctioned corpus writers are the CLI's archive merge and the agent-driven sync-specs skill, both delta-mediated and both scoped to `openspec/specs/`.
So `openspec/satisfaction.md` has no lifecycle: it could only be written by instruction prose that nothing polices.
A `specs/world/` capability, by contrast, is fully reachable through the delta machinery and inherits `openspec validate`.

The four claimed collisions between the AMDiRE docs tree and the OpenSpec corpus are mostly hypothetical, and the real problem is different.
`docs/development/requirements/requirements.md` and `context/context.md` do not exist — both were sharded per the skill's own growth rule.
`work-items/` was never instantiated at all, even though `preferences-documentation` still prescribes it in four places.
Only the architecture collision is real, and only as stratum-role overlap: `architecture.md` is titled "System Specification" and carries an Interface Model and a Behavior Model, which is specification-side material, while the corpus carries specification-side material too — on entirely disjoint subjects, with zero restatement.
The actual defect is divergence by abandonment: the hand-maintained layer last moved in December 2025 while the corpus is the August 2026 live surface, and neither tree references the other.
The work is therefore migration and citation wiring, not deduplication.

Our two primary harnesses have opposite coverage, which settles whether the generated context file should shrink.
The omp system prompt already asserts tool policy, delegation gates, verification discipline, a completeness contract, and cleanup rules at the system level, and it names our context file as the explicit opt-in channel for subagent work: "No subagents unless user or applicable AGENTS.md/skill explicitly requests subagents, delegation, or parallel agent work."
Atomic's core prompt asserts almost none of it — the entire fixed guidance is "Be concise in your responses" and "Show file paths clearly when working with files", with delegation and workflow policy arriving only when those extensions are active.
The generated file is therefore the only layer carrying process discipline to atomic, and subtraction is off the table.

## Decision 1 — which skills change

Two new skills, thirteen edited targets, three named-but-unchanged, five forbidden.

### New

| Skill | Group | Owns |
|---|---|---|
| `preferences-requirements-engineering` | `formal-specification-and-refinement` | The WRSPM pentad and its two obligations; the four dark corners as checkable discipline; the designation table; indicative/optative separation; shared-phenomena alphabet restriction; KAOS goal-obstacle analysis; Parnas four-variable; the WRSPM/AMDiRE shear |
| `satisfaction-argument-audit` | `formal-specification-and-refinement` | The three-gate chain generalized across institutions; blind informalization for specification-versus-intent; the trust-surface inventory; the claims status table with vacuity and co-vacuity checks; safe external wording and the never-claim-end-to-end prohibition |

The split follows the corpus convention that pairs a conceptual `preferences-*` skill with a bare-named operational one, as `preferences-validation-assurance` pairs with `verification-before-completion`.
The hub is loaded when authoring or reviewing requirements; the audit is loaded at a milestone, before an external claim, or at the verify gate.

Hosting both in `formal-specification-and-refinement` places them beside `refinement-driven-development`, which owns the program-refines-specification obligation, so the two obligations sit in one group and are discoverable from either end.
`preferences-domain-driven-architecture` was considered and rejected: it is the requirements *discovery* home, whereas WRSPM is a verification-obligation ontology.

### Edited

| Target | Edit | Why here |
|---|---|---|
| `preferences-theoretical-foundations` | Gains assume-guarantee contract meta-theory and institution theory | `refinement-driven-development` already attests this skill owns the heterogeneous-specification stance; its Rule 7 states institutions informally |
| `preferences-validation-assurance` | "Refinement and freedom preservation" gains the second obligation; the assurance-case section gains the satisfaction argument as top goal node | The section already names program and specification and states the refinement order; it lacks only the world and the implication direction |
| `preferences-compositional-continuous-verification` | "Verification is not validation" gains a forward pointer; the operating envelope is named as the assumption half of a contract | It currently disclaims the validation leg with nowhere to send the reader |
| `executable-specification-testing` | The six-senses contract disambiguation gains a seventh clause | Mandatory: it declares that holding the senses apart is part of what it owns, so an unlisted sense rots the passage |
| `refinement-driven-development` | One sentence naming the companion obligation and its owner | Makes the obligation pair discoverable from the mechanical end |
| `preferences-documentation` | Records the shear at the requirements-directory comment; states the docs-to-corpus relationship; resolves the work-items contradiction | It is the AMDiRE owner and mentions OpenSpec zero times |
| `atdd-outer-loop` | Gate 1 gains a specification-strength verdict; the spec-leakage audit is named as the shared-phenomena discipline | Its audit rule already removes anything that names the machine — that *is* the alphabet restriction |
| `preferences-discovery-process` | Step 1 gains designation-table output; Step 7 gains the obligation statement; KAOS attaches here | Step 1 already establishes the universe of discourse; Step 7 is already the bridge to formal artifacts |
| `ubiquitous-language` | Glossary schema gains world-phenomenon and stratum columns; gains a cross-reference section | Its glossary is a designation table missing two columns, and it currently routes nowhere |
| `nucleus-platform` | One delegation bullet | Thin router; restates nothing |
| `openspec-bdd-bridge` | Modality verdict table gains the stratum dimension | Its table is the pattern the stratum tag copies |
| `superpowers-bridge/schema.yaml` | Version 2: four framework edits plus two corrections | The write path for the whole corpus |
| `openspec/config.yaml` | Populate `context`, `rules`, and `operations.archive.guidance` | All three are currently unset — the free lever |

### Named but deliberately unchanged

`preferences-algebraic-laws` is silent on all six components, and its "laws are contracts" sense must stay distinct from the Benveniste sense; editing it would blur the disambiguation that `executable-specification-testing` maintains.
`preferences-workflow-orchestration-algebra` is silent on all six; its honesty discipline is a local assume-guarantee instance but its scope is data-pipeline orchestration, and a pointer would buy nothing.
`preferences-adaptive-planning` has an adjacent verification-and-validation section, but the framework adds nothing to planning theory.

### Forbidden

The five CLI-derived skills `openspec-propose`, `openspec-new-change`, `openspec-verify-change`, `openspec-archive-change`, and `openspec-sync-specs` carry `generatedBy` frontmatter and are regenerated by `modules/apps/openspec-refresh-vendored-artifacts.sh`.
Framework content rides the schema, the project config, and the first-party bridge and router skills instead.

## Decision 2 — precisely how

### The hub skill

Its spine is the pentad, the two obligations, and the side conditions that make them checkable: every term in requirements grounded in a designated world phenomenon, world assumptions separated into indicative and optative, specification restricted to shared phenomena, and no requirement smuggled into the specification that references unobservable world state.
Above requirements sits KAOS: goals refine through AND/OR graphs down to requirements assignable to agents, and obstacle analysis systematically negates goals to find the world behaviors under which the satisfaction argument fails.
That is the disciplined generator of the trust-boundary and open-questions sections, which otherwise fall to taste.
Parnas' four-variable model is the specialization to reach for when the world is physical.

The shear against AMDiRE is stated precisely because it changes where our own documents belong.
AMDiRE's Context Specification is approximately the world plus goals, its Requirements layer is approximately the requirements-specification interface zone, and its System Specification is the specification refined toward the program.
The consequence for us is concrete: `docs/development/requirements/` is specification-side today, and genuinely world-referent requirements have no home in it.

The designation lint is the single highest-value mechanizable check and is named as such: verifying that every content noun in a behavioral delta resolves against the world capability's designation table is a lexer pass, not a semantic one.

### The audit skill

Gate one is the program-refines-specification check, discharged per institution — `lake build` for a Lean model, `cargo` plus the Charon and Aeneas round trip for Rust, `dafny verify`, `verus`.
It carries one discipline verbatim from LemmaScript: never verify against a stale generated artifact, because a green check on last week's emitted proof certifies proofs about code that is not the code.

Gate two is specification-versus-intent by blind informalization.
Extract the formal obligation text; have a model back-translate it to English without seeing the intent statement; compare the back-translation to the intent; emit one of confirmed, disputed, gap, or unchecked, with a weakening type on disputed.
The direction rule is fixed: treat the intent as ground truth and strengthen the formal specification toward it, never soften the intent.
Three operational rules travel with it — verdicts are a pure function of the annotations, so no re-run is needed after later proof work unless an obligation or intent line changed; the gate must run after gate one is green; and an exit code must never gate the check, because findings live in the report, not the status.

Gate three is the milestone audit in fresh context: re-verify, inventory the trust surface, check the claims table, and produce safe external wording.
The trust surface enumerates every proof bypass per backend with its justification — Lean `sorry`, `axiom`, `native_decide`; Rust `unsafe` and any assumed invariant; Dafny `assume` and `{:axiom}`; Verus `assume`; plus every opt-in-verification mode's silent skip of unmarked functions.
This is our existing sorry-debt discipline generalized across institutions.

The claims table carries three checks the corpus does not currently name: is the precondition satisfiable, is the postcondition non-vacuous, and — the interesting one — co-vacuity, meaning were the design claim and the formal specification derived from the same guess, because two artifacts that agree can both be wrong.
Co-vacuity is the same failure our Gherkin discipline already blocks with the independent-literal-oracle rule, and the two should cite each other.

The prohibition is absolute and is stated in both the promise section and the boundary section of any design document: never claim verified end-to-end.

### The schema, version 2

Four framework edits, at the sites the design conversation identified:

The `proposal` artifact's Capabilities bullets gain a stratum tag per capability — `world`, `interface`, or `behavioral` — which makes the shear-aware taxonomy the contract between the proposal and specs phases, exactly as that instruction already treats Capabilities.

The `specs` artifact's delta instruction gains stratum-conditional rules appended to the existing operations block.
Behavioral deltas use world vocabulary only and name no interface phenomena.
World deltas state indicative assumptions whose scenarios are violation and monitoring conditions, in the form "WHEN this assumption drifts THEN the assumption is void and these requirements lose their discharge" — obstacle analysis rendered native to the Requirement-and-Scenario grammar, which also satisfies the validator's every-requirement-needs-a-scenario rule.
Interface deltas respect the trust boundary and the shared alphabet.
Project-invariant rules go in the schema; project-specific designation discipline goes in each `config.yaml` under `rules.specs`, which is what that field is for.

The `verify` artifact gains a section eight beside the existing seven, with the same non-blocking-with-recorded-gap philosophy as section seven: the designation lint, and discharge coherence, meaning every added or modified requirement names its discharging specification properties and world assumptions or is recorded as undischarged with a follow-up.
Undischarged rows feed the retrospective's promote-candidates section, where world-assumption and architecture-decision become two new promotion destinations.

The `apply` phase's archive step gains satisfaction regeneration before the folder moves, so the pull-request diff's complete cycle state includes it.

Two corrections the evidence forces, independent of the framework:

The `workspace-planning` precondition guard appears at three sites — the verify instruction, the retrospective instruction, and the apply phase — and is dead code on the installed CLI, where `ActionContext.mode` is the single literal `repo-local`.
Drop it.

The bundle's declared OpenSpec baseline is 1.4.1 while the shipped CLI is 1.10.0, six minor versions ahead, and the schema has never been re-validated against 1.10.0 semantics.
Bump and re-validate.

A fifth framework edit, found by regenerating the vendored skills at 1.10.0 before touching anything.
Upstream's own tasks template now carries per-task verification evidence — each task gains "— verify: [test, command, observable behavior, or delivered artifact]", and its second group is renamed from "Verify" to "Integration Verification".
That is discharge coherence at task granularity, which upstream converged on independently of this framework.
It does not reach us, because `superpowers-bridge` ships its own bare `templates/tasks.md`, so the convention must be carried into that template and the `tasks` artifact instruction deliberately.
Doing so gives the section-eight discharge check a task-level anchor it otherwise lacks, and stops our schema regressing against upstream's default as later conventions accumulate.

The regeneration also settled the staleness question the baseline bump was hedging against.
Six minor versions of drift in the delegated surface amount to exactly that one template convention plus frontmatter: `openspec-verify-change` and `openspec-archive-change`, the two skills the schema's verify and apply steps invoke, changed frontmatter only.
The dead `workspace-planning` guard is therefore dead and harmless rather than a correctness defect, because it degrades to always-proceed, and the status JSON contract the precondition checks consume — `actionContext.mode`, `actionContext.allowedEditRoots`, and `artifactPaths.<id>.existingOutputPaths` — is intact on 1.10.0.

### Staging the schema without an activation cycle

`openspec schema fork` is unusable against a nix-store source: it copies mode-444 files while preserving permissions, so its own staging temp file is unwritable and the fork aborts with EACCES.
It also renames the result, so it would not have shadowed the original in any case.

The mechanism that works is a whole-directory symlink at the project tier, from `openspec/schemas/superpowers-bridge` into the repository's own schema source, which `openspec schema which` then reports as `Source: project` shadowing the user tier.
This should be committed as a permanent arrangement rather than torn down after staging.
The repository owns the schema, so resolving it from its own tree removes activation lag here and makes it impossible for this repository to test a stale copy of the artifact for which it is the source of truth.
It cannot drift, because it is the source rather than a copy of it, which is also what keeps it inside the no-two-committed-copies invariant.
The relative symlink resolves in a bare clone, so it is strictly less fragile than the XDG dependency it shadows.

Activation is consequently needed exactly once across the three changes, at the boundary between the skill-authoring change and the routing change, so the two new skills become loadable for the routing work that invokes them.
It is not needed for the schema change at all.

### Where the satisfaction projection lives

Not `openspec/satisfaction.md`, which has no mechanism.
It lives at `packages/docs/src/content/docs/development/traceability/satisfaction.md`, regenerated wholesale at archive time through `operations.archive.guidance`.

Four reasons this is the right home rather than a concession.
The traceability directory already exists and is populated, and it is the prescribed AMDiRE traceability stratum whose maintenance model was always the unresolved problem — this gives it one.
The discharge argument is a projection with semantic content of its own, so it is the one derived artifact that earns persistence, unlike a rendered requirements copy or a work dashboard.
It is developer documentation humans read, which is the stated frame for these artifacts.
And the maintenance rule is the whole point: a discharge table that is rebuilt is trustworthy, while one that is patched accumulates exactly the staleness the artifact exists to prevent, so it must be regenerated and never edited.

The world and interface strata, by contrast, live inside the corpus as capabilities at `openspec/specs/world/` and `openspec/specs/interface/`, because the delta machinery reaches them and `openspec validate` then applies to them.

### The governing invariant

The repository never contains two committed copies of the same information.
Everything normative, transactional, or delta-derived lives under `openspec/`; the documentation site is a lens over the corpus, not a destination for it; and the only persisted projection is the discharge argument, because it alone adds semantic content.
Renderings are build-time views that are never committed; duplicates are second persistent copies that can drift.
Under that rule the residual documentation tree is honest about its nature: narrative context, architecture narrative with its decision records, and pre-transaction backlog intent — all human-authored, none of it normative.

## Decision 3 — agents-md.nix

The generator is a single indented nix string at `settings.body`, fanned byte-identically to seven markdown destinations plus pi's `context` option.
A new top-level section is a literal-string insertion at ten-space indent; a new index entry is one bullet in the guidelines block.
There are no section lists, no per-agent conditionals, and no concatenation helpers, so insertion mechanics are trivial and ordering is file order.

Harness wiring is already correct and needs no change.
Omp resolves one user-level context file by provider priority and finds `~/.claude/CLAUDE.md` at priority eighty, since we write nothing to `~/.omp/agent/`.
Atomic concatenates every user agent directory and finds `~/.pi/agent/AGENTS.md`, written by pi's `context`, while `~/.atomic/agent/` stays empty — so atomic receives the content exactly once with no duplication.
Two hazards are worth recording rather than fixing: adding an `~/.omp/agent/AGENTS.md` destination would silently shadow the Claude file at priority one hundred, and omp's containment dedupe will drop the user-level file entirely if a project file's full paragraph sequence contains it.

Four content changes.

Add the two new skills to the guidelines index, glossed in house style.

Amend the operating principles with one sentence making the satisfaction argument a stated obligation: every requirement names the world assumptions and specification properties that discharge it, and an undischarged requirement is recorded as such rather than left implicit.
This belongs in the principles section because it is a principle, and because that section already scales care by blast radius.

Amend the compositional-architecture standard, which already commits us to keeping a type-checkable Lean specification beside the implementation and closing the specification-to-code gap through refinement and translation validation.
Extend it with the companion obligation and the never-claim-end-to-end prohibition, since this is exactly where the ideal-versus-ships-today calibration already lives.

Adopt the reference prompts' genuine gaps selectively.
Worth taking: no flattery, praise, or agreement without reason, paired with its positive counterpart of challenging incorrect assumptions directly and explaining why — verified absent from all 133 skills and from the portable layer.
Worth taking: a compact scope rule for the seven non-omp consumers, which currently receive nothing equivalent to omp's contract block.
Worth taking: one worked do-and-do-not example pair, on unrequested scope expansion, since our body currently contains zero examples and the reference author's own validation finding is that the model pattern-matches examples harder than rules.
Worth taking: long-running-command routing, which the portable layer lacks entirely.

Explicitly rejected, with reasons.
Banning the phrase "load-bearing" conflicts with three deliberate in-body uses of it as a term of art.
Banning analogies and mandating the simplest non-overloaded terminology both contradict our expert register, which deliberately names a graded, multimodal, adjoint, dependent type theory in the same paragraph.
Banning em dashes and semicolons contradicts house style, though the narrower anti-chaining half is compatible.
Reference codes and alias expansion duplicate machinery the harnesses already supply better.

Two defects to fix while in the file.
The at-prefix comment claims auto-loading requires the prefix on full paths, but only two of roughly seventy-two index entries carry it; prefixing all of them would auto-load seventy-two skill files into every Claude Code session, so the comment is what is wrong, not the entries.
Separately, `preferences-nix-development` recommends verifying with `nix flake check` while `nix-flake-pr-cycle` says flake check is too slow and routes to targeted probes and `just check-fast` — our own corpus contradicts itself on one point, and the recent skill wins.

One structural observation, not a decision.
The generator writes markdown only and manages no settings file, hooks, or permissions.
Rules that are mechanically enforceable — the commit co-author suppression being the clean example — have no home in it today, and prose is a weak substitute for a configuration flag.

## Vericoding evidence, verified and corrected

The paper was acquired from the arXiv LaTeX source and is at `~/Downloads/arxiv-2509.22908/src/vericoding.tex`.
Three of the four claims the framework leans on are confirmed verbatim, and three corrections bind how the new skills may be worded.

The definitions are confirmed at section 3.1: documentation "describes the intent (intended behavior)", and a specification "is a representation of the intent in a formal language".
The out-of-scope bracketing is confirmed at section 2: "We acknowledge that spec generation is an important problem, but focus on the task of generating implementations and formal proofs in this work."
The core statistic is confirmed verbatim at section 4: "Across Dafny, Verus and Lean, conditioned on vericoding success, roughly 9% of the specs were too weak and another 15% had poor translations."

First correction: the causal attribution must be decoupled from the statistic.
The phrase about lossy transpilation and incomplete human-authored specifications is a real quote, but it belongs to a separate, unquantified finding in section 3.3 describing "a handful of specifications" that admitted trivial solutions.
The 9-and-15-percent figures come from a different paragraph and carry different, language-specific attributions.
Citing them as one sentence would fabricate a causal link the paper does not draw.

Second correction: the statistic rests on a small manual sample.
The method was manual inspection of five randomly chosen successful outputs per language and data source, which works out to roughly 125 items, and the paper states no aggregate sample size.
By our own severity discipline that is suggestive rather than strong evidence, and the skills must say so when citing it rather than presenting the percentages as settled measurement.

Third correction, and the one that matters most: the motivating asymmetry is not the paper's claim.
Nothing in the paper compares the difficulty of the intent-to-specification direction against the specification-to-program direction, and it explicitly declines to study the former at all.
The paper's contribution to our argument is narrower and still sufficient: specification defects survive the program-refines-specification gate, because the defect rate is measured *conditioned on vericoding success*.
The step from there to "the requirements-to-specification bridge is the binding constraint" is our inference and must be attributed to us, not to the paper.

One incidental correction to the earlier reconnaissance: `midspiral/lemmascript-skills` is present locally at `~/ghq/github.com/midspiral/LemmaScript-skills`, clean at `b5ae5e9`.
The earlier report of a failed clone was a sandbox artifact of that agent's session, not a missing dependency.

## Falsification criteria, and the first result

Committed in advance so the dogfood cannot pass by construction. If every capability in a change
tags `behavioral`, the stratum tag is dead weight and should be deleted. If the designation lint
reports clean on its first run, it is vacuous, because no designation table exists yet and a clean
report is impossible if the lint works. If discharge coherence yields zero undischarged rows,
suspect co-vacuity in the instrument itself — the same check section eight imposes on specs.

The first criterion fired immediately, and then survived a severer test.

The `requirements-engineering-skills` change tags both of its capabilities `behavioral` and
introduces no `world` or `interface` capability. Taken at face value that is the criterion firing.
The available defence — that this change's subject is the agent instruction corpus, which has no
machine boundary — is exactly the "the test does not apply here" move that makes a falsification
criterion worthless, so it was not accepted on its own.

The severer test applies the tag to a mature capability authored without the framework:
`openspec/specs/pi-agent-environment/spec.md`, 25 requirements written months earlier. The tag
partitions it non-trivially. Requirements naming the first-party policy extension, injected
repository capabilities, and the jj probe's exit codes sit at the machine interface rather than in
world vocabulary. And the `Fail-open policy` requirement embeds two indicative assumptions as
justification prose inside an optative MUST: that Pi has no permission system, and that an
unanswerable dialog on an autonomous session stalls it indefinitely. Both are true regardless of
what we build.

That is the four-dark-corners violation the framework names, found in our own corpus without
looking for it. Its consequence is concrete rather than stylistic: if Pi ever gains a permission
system, the requirement's rationale evaporates and nothing would notice, because the assumption is
recorded nowhere it can be invalidated. A `world-assumptions` capability with violation-condition
scenarios is exactly the artifact that would notice.

So the criterion does not fire: the tag has content, and the all-behavioral outcome was a property
of an unrepresentative subject rather than of the instrument. The finding also adds scope that was
not previously identified — extracting the indicative assumptions currently embedded in
`pi-agent-environment` into a `world-assumptions` capability, which is its own change and is not
part of the three planned here.

A second finding came from authoring the delta specs themselves. Writing both capabilities'
requirements in world vocabulary was achievable without contortion: the specs name an agent, a
requirement-like statement, and a designation record, and never name a `SKILL.md`, a frontmatter
field, or nix. So the alphabet restriction is satisfiable on a subject where it might plausibly
have failed, which is weak positive evidence that the rule is workable rather than aspirational.

The cost is visible and worth stating rather than hiding. Requirements written in world vocabulary
are markedly more abstract than the interface-flavoured requirements we habitually write, and they
are correspondingly less immediately testable. That is precisely the tension WRSPM predicts and
precisely why requirements drift specification-ward without a rule holding them back: interface
vocabulary is concrete and checkable, so it feels like progress. The compensation is durability —
these requirements do not break when a file format changes — but the trade is real, and a reader
adopting the discipline should expect it rather than discover it.

The remaining two criteria were evaluated by running section eight's checks by hand against
`requirements-engineering-skills`, which is what the instruction asks an agent to do. Neither
fires, and the second produced the most useful result of the exercise.

The designation lint does not report clean. No `world-assumptions` capability exists, so the lint
reports the absence of the designation table as its finding, which is exactly the behaviour the
instruction mandates and the reason that mandate was written. Had it reported clean, the criterion
would have condemned it as vacuous.

Discharge coherence returns ten requirements, every one undischarged, against zero interface
capabilities. The criterion asked whether the check would return zero undischarged rows, and it
does not, so the criterion does not fire. But the interesting part is what ten out of ten means.

It means the change's requirements have no discharge argument at all, and the reason is a claim
made in its own proposal. That proposal argued that no `interface` capability was warranted because
the subject is the agent instruction corpus, which has no machine boundary. The discharge check
contradicts that directly. A requirement of the form "an agent must be able to determine which
stratum a statement belongs to" is discharged by a property of the delivered corpus — that it
contains a skill whose content states the stratum rules — and that is an interface property, at the
boundary between the developer and the delivered artifact. The boundary was there; the proposal
argued it away.

So the instrument caught its own author rationalising, one section after the same rationalisation
had already been flagged as suspect when the first criterion fired. That is the strongest evidence
available that section eight has content: it disagreed with the person who wrote it, about the
change that introduced it, on a point that person had already defended once.

The consequence is a correction to `requirements-engineering-skills` rather than to the instrument.
It needs an `interface` capability naming what the delivered corpus must expose, and its
stratum-tagging note must be rewritten to record that the all-behavioral tagging was wrong on its
own terms. Both criteria remain unfired, and the tag, the lint, and the discharge check all survive
their first exercise.
