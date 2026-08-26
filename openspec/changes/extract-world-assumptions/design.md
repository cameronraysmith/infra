## Context

`openspec/specs/pi-agent-environment/spec.md` is a 25-requirement capability authored months before this repository adopted WRSPM (the Gunter-Gunter-Jackson-Zave requirements framework; see `preferences-requirements-engineering`).
`docs/notes/development/methodology/meta-requirements-framework-integration.md` records the framework's own falsification test, run against this capability as a severe case precisely because it was written without the framework in mind.
That test found two things at once: several requirements name machine-side artifacts rather than world vocabulary, and `Fail-open policy` embeds two indicative assumptions as justification prose inside an optative MUST — "because Pi has no permission system and an unanswerable dialog on an autonomous session stalls it indefinitely."
A closer read of the full capability for this change finds six more assumptions doing the same work without an explicit "because" clause, spread across five more requirements.
This change extracts all eight into a new `world-assumptions` capability and restates the six dependent requirements to name them.

This is a source-versus-delivered and vendored-boundary-free change: it touches only `openspec/changes/extract-world-assumptions/specs/`, no Nix module, and no generated artifact, so the two boundaries this repository's own convention flags as its main source of rework do not apply here.

## Goals / Non-Goals

**Goals:**

- Extract the eight indicative assumptions `pi-agent-environment` currently embeds into a new `world-assumptions` capability, each with a violation-condition scenario in the `WHEN <drift> THEN <void, discharge lost>` grammar.
- Restate the six `pi-agent-environment` requirements that rest on those assumptions so each names its dependency explicitly, without changing any MUST/SHALL clause's normative content.
- Build the designation table, disambiguating the ten double-sensed terms (`session`, `package`, `policy`, `@`, `mutation`, `activation`, `probe`, `machine`, `host`, `interface`) explicitly.
- Resolve the prompt-class contradiction between `Additional shell policy` and `Fail-open policy`; originally recorded as an open question for human arbitration, resolved once a source lookup against the pinned `permission-gate` engine settled what its headless behavior actually does (see D5).
- Decide, and justify, whether this change also relocates the interface-flavored requirements the same dogfood run found.

**Non-Goals:**

- Changing any `pi-agent-environment` requirement's behavior. This is a restatement, not a behavioral change.
- Relocating interface-stratum requirements into a separate capability. See D4 below; declined, deferred indefinitely rather than scheduled to a named follow-up.
- Correcting the `A5` sharp edge (untracked, gitignored targets) in the shipped policy. See D6 below; flagged, not fixed, because fixing it would change behavioral content.
- Touching any Nix module, package, or generated context file.

## Decisions

### D0: Assumption inventory and dependency map

Each assumption's falsification condition and the requirements that lose their discharge argument if it fires, established by close reading of `openspec/specs/pi-agent-environment/spec.md` rather than assumed from the source note's shorter list:

| # | Assumption | Falsification condition | `pi-agent-environment` requirements losing discharge |
|---|---|---|---|
| A1 | Pi has no native permission system | A Pi release ships a built-in gate/approve/defer mechanism for tool calls | `Permission-gate reuse`, `Non-Bash edit and write policy`, `Fail-open policy` |
| A2 | An unanswerable dialog stalls a session with UI but no human present | Pi or its harness gains a way to hold an unresolved prompt open on such a session without blocking session progress | `Additional shell policy` (prompt class), `Non-Bash edit and write policy` (notify-and-allow class), `Fail-open policy` (no-interactive-answer clause) |
| A3 | Policy failure carries no safety evidence | A specific failure mode is shown to correlate with an actually unsafe mutation | `Non-Bash edit and write policy`, `Git default-branch boundary`, `Jj diamond boundary`, `Fail-open policy` |
| A4 | Refusing on ambiguity has a real cost and prevents nothing | An audit finds a refusal on ambiguity that actually prevented an unsafe mutation | `Non-Bash edit and write policy`, `Fail-open policy` |
| A5 | A tracked target is recoverable from repository history | A target is inside a repository but untracked and gitignored, so no history entry covers it (already known to fire; see D6) | `Non-Bash edit and write policy`, `Git default-branch boundary`, `Jj diamond boundary` |
| A6 | Atomic inherits Pi's configuration root unconditionally | A future atomic release adds its own configuration root or makes extension loading conditional | `Non-Bash edit and write policy` |
| A7 | Pi's enumerated path forms are exhaustive | Pi's path resolution accepts a form outside `@`, `~`, `file://`, Unicode-space variants | `Non-Bash edit and write policy`, `Git default-branch boundary`, `Jj diamond boundary` |
| A8 | Jj's outside-repository diagnostic is stable | A jj release changes the diagnostic's wording, exit code, or trailing `Hint:` shape | `Git default-branch boundary`, `Jj diamond boundary` |

The union of the right-hand column is exactly six requirements — `Permission-gate reuse`, `Additional shell policy`, `Non-Bash edit and write policy`, `Git default-branch boundary`, `Jj diamond boundary`, `Fail-open policy` — which is why the specs delta touches exactly those six and no others.

### D1: Phrase world assumptions indicatively while satisfying the SHALL/MUST validator

OpenSpec's zod schema requires every Requirement sentence to contain SHALL or MUST, but a WRSPM world assumption is indicative, not optative.
The pattern already established in this repository's own `requirements-stratification` capability resolves this: state the indicative fact first, then close with a SHALL/MUST sentence directed at the agent tracking discharge ("any requirement whose discharge depends on this fact SHALL name it explicitly... SHALL be treated as losing its discharge") rather than at the world.
Alternative considered and rejected: phrasing the assumption itself as a MUST on the environment ("Pi MUST have no permission system") — rejected because it inverts the direction of truth; the world is not obligated to be a certain way, it simply is, and stating it as an obligation would misrepresent an indicative fact as an optative one, exactly the fusion this framework exists to prevent.

### D2: Replace inline justification prose where it exists; add naming sentences where it does not

Two requirements carry a literal "because" clause that states an assumption as justification: `Fail-open policy` (A1, A2, A3, A4) and `Jj diamond boundary` (A5).
Those clauses are reworded to name the assumption by ID rather than restate its content inline, preserving the same information while making it traceable.
Four requirements — `Permission-gate reuse`, `Additional shell policy`, `Non-Bash edit and write policy`, `Git default-branch boundary` — depend on one or more assumptions without any inline prose to replace; those requirements gain an added naming sentence instead, and no existing sentence is removed.
In every case, every original MUST/SHALL sentence survives verbatim; only justification prose is reworded or a naming sentence is appended.

### D3: Tag `pi-agent-environment` `behavioral` in the proposal despite retained interface vocabulary

The six restated requirements are behavioral in nature — statements of what the system must do — which is the honest tag per the proposal instruction's "tag honestly" rule, even though they retain machine-side nouns (`permission-gate`, `atomic`, jj probe argv, the `@` prefix) that a strict `behavioral`-vocabulary-purity rule would push into a separate interface capability.
The alternative — tagging the capability `interface`, or inventing a fourth "mixed" tag — was rejected: these requirements are not interface-alphabet guarantee statements, and the schema offers exactly three strata.
The consequence is accepted deliberately: the designation lint (verify.md §8a) will report real unresolved nouns on its first run against these six requirements, which is the correct, non-vacuous finding this framework's own falsification criteria anticipate, not a defect to silence.
This also clarifies a point worth stating explicitly: "world" is relative to what this repository is building.
Atomic, jj, and Pi itself are all environment from this repository's own build's perspective, even though they are software; a fact about how they behave (A6, A7, A8) is legitimate content for a `world`-stratum assumption, because it is true regardless of what this repository builds, exactly like a fact about physical hardware would be.

### D4: Decline interface-stratum relocation; deferred indefinitely, not scheduled

**Recommendation, reconsidered: decline rather than merely defer.**
This change originally recommended deferring the interface-flavored content of `Permission-gate reuse`, `Additional shell policy`, `Non-Bash edit and write policy`, `Git default-branch boundary`, and `Jj diamond boundary` to a named follow-up change (`stratify-pi-agent-environment-interface`), scoped to relocate that content into a separate `machine-interface` capability.
On reconsideration, no such follow-up is being filed.
The one concretely demonstrated defect motivating relocation was the `Fail-open policy` scope ambiguity — its fail-open and no-interactive-answer guarantees read as though they governed the upstream Bash engine as well as the first-party non-Bash core they actually cover — and D8/D5 above already correct that defect in place, with a scope-marking sentence, at the cost of two added sentences rather than a capability restructuring.
Restructuring 25 requirements that archived changes already reference, to relocate machine-side vocabulary whose only demonstrated cost was that one now-corrected ambiguity, does not pay for itself against that alternative.

**Trade-off accepted by declining:** `pi-agent-environment` remains a capability whose stratum tag (`behavioral`) and actual vocabulary do not fully agree, indefinitely rather than for one bounded cycle, and the designation lint (§8a) will keep reporting the same unresolved-noun finding with no scheduled change to close it.
That is a known, accepted incompleteness, not a silent one — `verify.md` §8a and §8c both surface it explicitly on every run.

**Revival condition, stated so a future reader can test it, not as intent:** this decision is reopened only if a second defect traceable to `pi-agent-environment`'s mixed behavioral/interface vocabulary is demonstrated — a concrete instance where the mixed stratum produced a wrong reading of a requirement, an incorrect discharge argument, or a defect of the same kind the `Fail-open policy` scope ambiguity was — not by the designation lint's unresolved-noun finding recurring on its own, since that finding is expected and non-vacuous by design (D3) and recurs on every run regardless of whether a further real defect exists.
A change that finds such a second defect should relocate the specific requirements it implicates, scoped to that defect, rather than reviving the original five-requirement `machine-interface` capability wholesale.

### D5: Resolve the prompt-class contradiction — the pinned engine's headless behavior dissolves it

`Additional shell policy` requires mutating HTTP and worktree requests to reach a `prompt` decision class.
`Fail-open policy` forbids requiring an interactive answer to permit a mutation, under A1 and A2.
Read without a scope distinction for `Fail-open policy`, these appeared to conflict: how can Bash's mutating-HTTP/worktree requests be prompted if nothing may ever require an interactive answer to permit a mutation?

D8's source lookup against the pinned `permission-gate` engine (`permission-gate/index.ts` lines 105-106, rev `c700f300707db5345727052682c88e3064030aa2`) settles this directly: the `tool_call` handler's `if (!ctx.hasUI) { return { block: true, reason: ... }; }` guard returns a block before `showReviewPrompt` is ever called, so a session without a UI channel never reaches an interactive prompt at all — no dialog is shown, so none is left unanswered, so no mutation there is ever made to wait on an interactive answer.
The contradiction dissolves once `Fail-open policy` is read at the scope D8 already assigns it: both of its clauses are a guarantee this repository makes about the first-party non-Bash decision core (`Non-Bash edit and write policy`), which by its own spec only ever returns allow, notify-and-allow, or block and structurally never prompts — not a guarantee about the upstream `permission-gate` engine `Additional shell policy` governs.
Scoped that way, the two requirements govern disjoint reachable conditions rather than conflicting ones: `Additional shell policy`'s prompt class is satisfied by permission-gate's actual behavior (prompt when a UI channel is present, block when it is not), and `Fail-open policy`'s no-interactive-answer clause is satisfied by the first-party core, which has no interactive answer to require in the first place.

This does not eliminate the stall risk A2 records: a session with a UI channel but no human present still reaches `showReviewPrompt` and can still stall waiting for an answer nobody will give.
That risk is real, and is exactly the reachable condition A2's sharpened text (D8) now states.
It is a fact about the environment this repository's Bash tooling runs in, not a violation of anything this repository requires of itself: `Additional shell policy` requires Bash mutating-HTTP/worktree requests to be prompted, and permission-gate does prompt them whenever a UI channel is present; `Fail-open policy`, correctly scoped, never claimed to police that engine's behavior.

**Resolution, not a re-affirmed deferral:** `Additional shell policy` and `Fail-open policy` are simultaneously satisfiable as written, given `Fail-open policy`'s scope from D8; `specs/pi-agent-environment/spec.md` records this reconciliation in both requirements' text, and `verify.md` §8b drops the "undischarged pending arbitration" status for both rows.

### D6: A5's sharp edge — the requirement is wrong as written, not merely under-specified

`Non-Bash edit and write policy`'s own text states two things that are not equivalent for one real case.
Its first sentence states the governing precept: "MUST refuse only a mutation version control could not recover."
Its second sentence operationalizes that as: "MUST announce rather than refuse every condition whose target is inside a repository."
For a target that is inside a repository's working tree, untracked, and matched by an ignore rule, "inside a repository" is true while "recoverable by that repository's history" is false — no commit, stash, or reflog entry of that repository covers it.
Applying the second sentence to that target announces and allows exactly the mutation the first sentence says should be refused.
That is the requirement contradicting its own governing clause for a specific, findable case, which makes it wrong as written for that case rather than merely resting on an unstated assumption elsewhere in the document.
The correction — testing recoverability (tracked, or otherwise reachable through the repository's history) rather than mere directory containment — is a behavioral change and therefore out of this change's scope; it is recorded here as a follow-up for whichever change next touches `Non-Bash edit and write policy`, and `verify.md` §8b records this edge as a known gap in A5's current discharge rather than a clean pass.

### D7: A7 as a Parnas four-variable instance

`Non-Bash edit and write policy`'s path-normalization clause is the clearest instance in this capability of a measurement-fidelity assumption in Parnas' sense.
The monitored quantity (NAT) is the path Pi's own resolver actually opens when it executes a tool call; the register the policy reads (IN) is the normalized path the policy computes from the raw tool-call argument.
A7 is the assumption that the enumerated forms (`@` prefix, leading `~`, `file://` URL, Unicode space variants) are the complete correspondence between the two — that normalizing through this enumeration always reproduces the path Pi actually opens.
Framing it this way makes explicit what the requirement's own text already implies but does not name: the policy never directly observes the path Pi opens, only a register standing in for it, and the fidelity of that correspondence is exactly what A7 asserts and what its violation condition (a path form outside the enumeration) would break.

### D8: Post-planning finding — pinned permission-gate source clarifies A2's reach and Fail-open policy's scope

A source lookup against the pinned rytswd permission-gate engine (`pkgs/by-name/pi-agent-extensions/package.nix` rev `c700f300707db5345727052682c88e3064030aa2`, `permission-gate/index.ts`, local clone `~/ghq/github.com/rytswd/pi-agent-extensions`) arrived after the artifacts above were first drafted and settles two points the original scan left open.

First, in the `tool_call` handler's prompt-class branch, `if (!ctx.hasUI) { return { block: true, reason: ... "no UI" }; }` sits before the call to `showReviewPrompt` (lines 105-113 of `permission-gate/index.ts`), so a session without a UI never reaches the dialog at all.
A2's original phrasing — "an autonomous Pi session" — read as though the stall condition covers any session run without a human, including a headless one; the source shows a headless session never shows a dialog and therefore never stalls on one.
The reachable condition is the inverse: a session that has a UI channel but no human present.
A2 is restated to say this precisely; see `specs/world-assumptions/spec.md`.

Second, the same handler's `matchRules` exception path (lines 84-91 of `permission-gate/index.ts`) returns `{ block: true, reason: "Blocked: permission-gate rule evaluation failed..." }` on a throwing rule — the Bash engine fails closed on its own parser and rule-evaluation exceptions.
`Fail-open policy`'s first MUST clause, read without qualification, claims the opposite for "parser errors, core or adapter exceptions" generally.
That claim can only be a guarantee this repository makes about the first-party non-Bash decision core it builds; it cannot be a guarantee about the upstream permission-gate engine, whose exception handling this repository does not control and which is now known to behave the opposite way.
`Fail-open policy` is restated to mark that scope explicitly; see `specs/pi-agent-environment/spec.md`.
No MUST/SHALL sentence changes in either edit: both add a scoping or naming sentence and reword non-normative justification prose, per D2's established pattern.

This finding resolves the prompt-class contradiction (D5): it establishes that a session without a UI channel never reaches an interactive prompt, which is what makes `Fail-open policy`, correctly scoped to the first-party non-Bash core, and `Additional shell policy`'s Bash prompt class simultaneously satisfiable.
It does not eliminate the UI-present-no-human stall risk A2 now states explicitly — that risk is real and is exactly what A2 records — but D5 explains why that risk is not a requirement violation.

## Risks / Trade-offs

[Risk] Restating six requirements with added naming prose could accidentally reword a MUST clause → Mitigation: every original normative sentence is preserved verbatim in the delta; `tasks.md` 1.3 requires a manual sentence-by-sentence comparison against the archived main spec before this change is considered ready, and that comparison is recorded in `verify.md` §4.

[Risk] Declining the interface relocation leaves the designation lint permanently reporting unresolved machine nouns in a `behavioral`-tagged capability with no scheduled change to close it → Mitigation: `verify.md` §8a records this explicitly as the expected, non-vacuous finding rather than a defect, per D3 and D4 above; D4 also states a falsifiable revival condition rather than leaving the decision unbounded.

[Trade-off] Doing the interface relocation now would close the vocabulary gap immediately, at the cost of roughly doubling this change's diff and mixing two extraction concerns in one review → declined per D4's reconsidered decision; the vocabulary gap remains open indefinitely rather than closed by a scheduled follow-up.

[Risk] Resolving the prompt-class contradiction via D5's scope-based reading could be taken on faith rather than checked → Mitigation: D5 cites the exact guard location and line numbers the resolution rests on, and states plainly what it does and does not eliminate (the UI-present-no-human stall risk A2 records remains real); a future reader can check the citation rather than accept the conclusion unverified.

[Risk] A5's sharp edge ships unfixed in the deployed policy for another cycle → Mitigation: recorded as a named follow-up in D6 and as an undischarged-edge row in `verify.md` §8b, rather than silently accepted as a clean discharge.

[Risk] Declining the interface-stratum relocation (D4) after having recommended it could look like an unexamined reversal → Mitigation: D4 records the specific reasoning (the one demonstrated defect is now corrected in place at low cost) and states a falsifiable revival condition a future reader can test, rather than silently dropping the earlier recommendation.

[Risk] The pin for `pi-agent-extensions` could move to a rev where `permission-gate`'s headless and exception-handling behavior differs from what D8 records → Mitigation: D8 cites the exact rev and file lines it read; re-verifying D8's two claims is required work for whichever change next bumps that pin, not assumed evergreen here.

## Migration Plan

N/A — this change touches only `openspec/changes/extract-world-assumptions/specs/`; it involves no Nix module, package, activation, or rollback.
At archive time, `operations.archive.guidance` in `openspec/config.yaml` regenerates `packages/docs/src/content/docs/development/traceability/satisfaction.md` wholesale from the post-sync corpus, which will then carry this change's new discharge rows, including the one undischarged row this change leaves open (A5's sharp edge); the prompt-class contradiction that previously left `Additional shell policy` undischarged is resolved per D5, and no interface-relocation follow-up is scheduled per D4's reconsidered decision.

## Open Questions

1. Whether A3 ("policy failure carries no safety evidence") should eventually be split into one assumption per specific failure mode rather than stated as one blanket claim, now that D0's dependency map shows it underwrites four requirements at once. Not resolved here; noted as a possible refinement for a future change if evidence ever narrows the claim for one failure mode without the others (see A3's own violation-condition scenario, which is already written per-failure-mode for exactly this reason).
2. Whether a future interface-relocation change, should D4's revival condition ever trigger one, should also absorb the packaging and regulator requirements this document explicitly recommends against including. Not resolved here, and no longer scheduled to be resolved by a named follow-up per D4; left to whichever future change's own proposal phase D4's revival condition triggers, which should weigh whether declaring a Nix artifact by name is itself an interface-alphabet statement or simply intermediate-grain behavioral content.
