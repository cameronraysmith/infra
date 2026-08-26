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
- Record the prompt-class contradiction between `Additional shell policy` and `Fail-open policy` as an open question for human arbitration.
- Decide, and justify, whether this change also relocates the interface-flavored requirements the same dogfood run found.

**Non-Goals:**

- Changing any `pi-agent-environment` requirement's behavior. This is a restatement, not a behavioral change.
- Resolving the prompt-class contradiction. That arbitration belongs to Cameron; see Open Questions.
- Relocating interface-stratum requirements into a separate capability. See D4 below; deferred with a named follow-up.
- Correcting the `A5` sharp edge (untracked, gitignored targets) in the shipped policy. See D6 below; flagged, not fixed, because fixing it would change behavioral content.
- Touching any Nix module, package, or generated context file.

## Decisions

### D0: Assumption inventory and dependency map

Each assumption's falsification condition and the requirements that lose their discharge argument if it fires, established by close reading of `openspec/specs/pi-agent-environment/spec.md` rather than assumed from the source note's shorter list:

| # | Assumption | Falsification condition | `pi-agent-environment` requirements losing discharge |
|---|---|---|---|
| A1 | Pi has no native permission system | A Pi release ships a built-in gate/approve/defer mechanism for tool calls | `Permission-gate reuse`, `Non-Bash edit and write policy`, `Fail-open policy` |
| A2 | An unanswerable dialog stalls an autonomous session | Pi or its harness gains a way to hold an unresolved prompt open without blocking session progress | `Additional shell policy` (prompt class), `Non-Bash edit and write policy` (notify-and-allow class), `Fail-open policy` (no-interactive-answer clause) |
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

### D4: Defer interface-stratum relocation to a named follow-up

**Recommendation: defer.**
Relocating the interface-flavored content of `Permission-gate reuse`, `Additional shell policy`, `Non-Bash edit and write policy`, `Git default-branch boundary`, and `Jj diamond boundary` into a separate `machine-interface` capability (naming the first-party policy extension, injected repository capabilities, and probe exit codes at the shared alphabet, with an explicit trust-boundary statement) is real, identified scope — but doing it in this change roughly doubles the delta's size and folds two distinct extraction concerns (naming world assumptions; separating interface vocabulary) into one review.
It also raises the risk that relocating five requirements' worth of dense, interlocking probe and argv detail introduces an incidental behavioral drift, which directly conflicts with this change's "no behavioral change" mandate.

**Trade-off accepted by deferring:** `pi-agent-environment` remains a capability whose stratum tag (`behavioral`) and actual vocabulary do not fully agree for one more cycle, and the designation lint will keep reporting the same unresolved-noun finding until the follow-up lands.
That is a known, recorded incompleteness, not a silent one — verify.md §8a and §8c both surface it explicitly on every run until the follow-up closes it.

**Follow-up:** a change named `stratify-pi-agent-environment-interface` (or equivalent), scoped narrowly to the same five requirements this dependency map already identifies as carrying machine-side vocabulary — `Permission-gate reuse`, `Additional shell policy`, `Non-Bash edit and write policy`, `Git default-branch boundary`, `Jj diamond boundary` — plus a trust-boundary statement for the new `interface`-tagged capability.
It should not also absorb the packaging and regulator requirements (`Nix-owned Pi resources`, `Source-only extension package`, `Selected extensions`, `Nix-owned runtime executables`, `Excluded extension resources`, `Consolidated custom regulators`, `Offline aggregate smoke`, and similar): those name Nix artifacts as a direct statement of what the system must deliver, which is a legitimate behavioral requirement at intermediate grain, not a specification-alphabet guarantee statement; whether any of them also warrants interface-stratum treatment is a decision for that follow-up's own proposal phase, not this document.

### D5: Record, not resolve, the prompt-class contradiction

`Additional shell policy` requires mutating HTTP and worktree requests to reach a `prompt` decision class.
`Fail-open policy` forbids requiring an interactive answer to permit a mutation, under A1 and A2.
`Permission-gate reuse` names permission-gate's "headless behavior" as the enforcement surface but this spec never specifies what that behavior actually does when no human is present to answer a prompt — that is the unstated bridge between the two requirements, and it is a human decision (what "prompt" degrades to under headless execution: deny, allow-with-notice, or something else) rather than something this change can infer from the text.
See Open Questions below; `verify.md` §8b records `Additional shell policy` and the no-interactive-answer clause of `Fail-open policy` as undischarged pending that arbitration.

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

## Risks / Trade-offs

[Risk] Restating six requirements with added naming prose could accidentally reword a MUST clause → Mitigation: every original normative sentence is preserved verbatim in the delta; `tasks.md` 1.3 requires a manual sentence-by-sentence comparison against the archived main spec before this change is considered ready, and that comparison is recorded in `verify.md` §4.

[Risk] Deferring the interface relocation leaves the designation lint permanently reporting unresolved machine nouns in a `behavioral`-tagged capability until the follow-up lands → Mitigation: `verify.md` §8a records this explicitly as the expected, non-vacuous first-run finding rather than a defect, per D3 and D4 above.

[Trade-off] Doing the interface relocation now would close the vocabulary gap immediately, at the cost of roughly doubling this change's diff and mixing two extraction concerns in one review → accepted deferral per D4; the follow-up is named rather than left implicit.

[Risk] The prompt-class contradiction remains genuinely unresolved after this change lands → Mitigation: `tasks.md` 3.1 routes it to Cameron before archive; `verify.md` §8b names the specific undischarged rows so the gap is visible rather than absorbed.

[Risk] A5's sharp edge ships unfixed in the deployed policy for another cycle → Mitigation: recorded as a named follow-up in D6 and as an undischarged-edge row in `verify.md` §8b, rather than silently accepted as a clean discharge.

## Migration Plan

N/A — this change touches only `openspec/changes/extract-world-assumptions/specs/`; it involves no Nix module, package, activation, or rollback.
At archive time, `operations.archive.guidance` in `openspec/config.yaml` regenerates `packages/docs/src/content/docs/development/traceability/satisfaction.md` wholesale from the post-sync corpus, which will then carry this change's new discharge rows, including the two undischarged ones (`Additional shell policy`'s prompt-class row and A5's sharp edge).

## Open Questions

1. **The prompt-class contradiction (unresolved, requires human arbitration).** `Additional shell policy` requires a `prompt` decision class for mutating HTTP requests and worktree creation. `Fail-open policy` forbids requiring an interactive answer to permit a mutation, because Pi has no permission system (A1) and an unanswerable dialog on an autonomous session stalls it indefinitely (A2). `Permission-gate reuse` names permission-gate's "headless behavior" as the bridge between the two but this capability never specifies what that behavior does. This is explicitly not resolved by this change; it is Cameron's call what "prompt" degrades to when no human is present, and `verify.md` §8b records the affected requirements as undischarged until that call is made.
2. Whether A3 ("policy failure carries no safety evidence") should eventually be split into one assumption per specific failure mode rather than stated as one blanket claim, now that D0's dependency map shows it underwrites four requirements at once. Not resolved here; noted as a possible refinement for a future change if evidence ever narrows the claim for one failure mode without the others (see A3's own violation-condition scenario, which is already written per-failure-mode for exactly this reason).
3. Whether the interface-relocation follow-up (D4) should also absorb the packaging and regulator requirements this document explicitly recommends against including. Not resolved here; left to that follow-up's own proposal phase, which should weigh whether declaring a Nix artifact by name is itself an interface-alphabet statement or simply intermediate-grain behavioral content, as D4 currently assumes.
