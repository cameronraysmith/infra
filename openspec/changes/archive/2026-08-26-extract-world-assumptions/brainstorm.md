> Provenance note: this capture is a solo decision log rather than a transcript of a live interactive `superpowers:brainstorming` session.
> The decisions below were already reached during the design session recorded in `docs/notes/development/methodology/meta-requirements-framework-integration.md`, and this file organizes that evidence into the Q1-Qn shape the schema expects, adding the analysis specific to this change (the dependency map, the sharp edges, the interface-relocation call) that the source note left as an identified-but-undone follow-up.
> Where a claim rests on re-reading `openspec/specs/pi-agent-environment/spec.md` directly rather than on the source note, that is stated inline.

## Background

`docs/notes/development/methodology/meta-requirements-framework-integration.md` records the decision to adopt WRSPM as this repository's meta-requirements ontology, and its "Falsification criteria" section reports the first real result of applying the `world | interface | behavioral` stratum tag to a mature capability authored before the framework existed.
Tagging `pi-agent-environment` — 25 requirements, written months earlier — partitioned it non-trivially: several requirements name machine-side artifacts (the first-party policy extension, injected repository capabilities, the jj probe's exit codes) rather than world vocabulary, and the `Fail-open policy` requirement embeds two indicative assumptions as justification prose inside an optative MUST.
That is the four-dark-corners violation the framework exists to catch: an assumption fused into an obligation is invisible to anyone auditing the obligation, so when the assumption stops holding, nothing notices.
The source note identifies the fix — extracting the embedded assumptions into a `world-assumptions` capability — as scope it found but did not do, and names it as its own change.
This change is that change.

## Q1: Which assumptions actually need extracting, and on what evidence?

The source note names two assumptions explicitly (no native permission system; an unanswerable dialog stalls an autonomous session) because those two are the ones with literal "because" clauses in `Fail-open policy`'s text.
A closer, requirement-by-requirement read of the full 25-requirement spec, done for this change, finds six more assumptions doing the same work without being phrased as inline justification: policy failure carrying no safety evidence, refusal-on-ambiguity having a real cost and no offsetting benefit, a repository's history recovering a tracked target, atomic's unconditional inheritance of Pi's configuration root, the enumerated path forms being exhaustive of Pi's own resolution, and jj's outside-repository diagnostic having a stable shape.
Each of these is textually traceable to specific sentences in `Permission-gate reuse`, `Additional shell policy`, `Non-Bash edit and write policy`, `Git default-branch boundary`, and `Jj diamond boundary` — the dependency map in `design.md` cites the exact clause for each.
Eight assumptions, six requirements: that is the scope, not a round number chosen in advance.

## Q2: How should an indicative assumption be phrased so it still satisfies OpenSpec's SHALL/MUST validator?

OpenSpec's zod schema requires every Requirement sentence to contain SHALL or MUST, but a WRSPM world assumption is indicative — a statement of what is true — not optative.
`requirements-stratification`'s own `Discharge of a requirement is stated, not implied` requirement already resolves this tension in this repository's own corpus: it phrases the obligation on the *agent* tracking discharge ("an agent MUST be able to state which specification properties and world assumptions discharge it"), not on the world itself.
The same pattern applies here: each world-assumption requirement states the indicative fact first, then closes with a SHALL/MUST sentence directing any requirement that relies on it to name it explicitly and to be treated as losing discharge when the violation condition fires.
The indicative content survives; the grammar satisfies the validator; nothing is asserted about the world using an obligation verb.

## Q3: Should this change also relocate the interface-flavored requirements the same dogfood run found?

No — deferred, with a named follow-up.
The six requirements this change touches (`Permission-gate reuse`, `Additional shell policy`, `Non-Bash edit and write policy`, `Git default-branch boundary`, `Jj diamond boundary`, `Fail-open policy`) all name machine-side artifacts — `permission-gate`, `atomic`, jj probe argv, the `@` prefix — that a strict `behavioral` vocabulary purity rule would push into a separate `interface`/`machine-interface` capability.
Doing that relocation in the same change roughly doubles its size, mixes two extraction concerns (naming world assumptions versus separating interface vocabulary) in one review, and raises the odds of an incidental behavioral change sneaking into six requirements that must otherwise stay byte-identical in normative content.
Deferring it means the designation lint will report a real, expected finding — unresolved machine nouns in a `behavioral`-tagged capability — on this change's first run, rather than a false clean pass; `design.md` records that as the correct, non-vacuous first result rather than a defect to silence.
`design.md` names the follow-up change.

## Q4: What about the direct contradiction between `Additional shell policy`'s prompt class and `Fail-open policy`'s no-interactive-answer rule?

Recorded, not resolved.
`Additional shell policy` requires mutating HTTP and worktree requests to reach a `prompt` decision class.
`Fail-open policy` forbids requiring an interactive answer to permit a mutation, because Pi has no permission system and an unanswerable dialog on an autonomous session stalls it indefinitely.
`permission-gate`'s "headless behavior" is named in `Permission-gate reuse` as the enforcement surface but is never specified anywhere in this spec — it is the unstated bridge between "prompt" and "an autonomous session has no one to answer."
That gap is a human arbitration call (what does "prompt" mean when no human is present — deny, allow-with-notice, or something else), not a textual inference this change can make safely.
`design.md`'s Open Questions section records it, and `Additional shell policy` is recorded undischarged in `verify.md` §8b pending that arbitration.

## Q5: Is `A5` (a target inside a repository is recoverable from its history) actually sound as the pi-agent-environment spec currently operationalizes it?

No, not for one case, and that is worth stating plainly rather than hedging.
`Non-Bash edit and write policy`'s own first sentence states the correct precept — refuse only a mutation version control could not recover — and its second sentence operationalizes that as "announce rather than refuse every condition whose target is inside a repository."
Those two sentences are not equivalent: a file inside a repository's working tree that is both untracked and gitignored is covered by no commit, stash, or reflog entry, so "inside a repository" does not imply "recoverable by that repository's history" for it.
Applying the second sentence to that case announces and allows exactly the mutation the first sentence says should be refused.
This is the requirement being internally inconsistent for a real, findable edge case, not merely resting on an unstated assumption elsewhere — `design.md` records the reasoning and recommends a follow-up correction, and does not attempt the fix here, because fixing it would change normative behavioral content, which is out of this change's scope.

## Agreed approach

Add one new `world`-stratum capability, `world-assumptions`, carrying eight indicative assumption requirements (each with a violation-condition scenario naming the `pi-agent-environment` requirements that lose discharge) plus a designation table.
Restate the six `pi-agent-environment` requirements that rest on those assumptions so each names its dependency explicitly, replacing inline "because" prose where it exists and adding a naming sentence where it does not, without changing any MUST/SHALL clause's normative content.
Tag `pi-agent-environment` `behavioral` in the proposal despite the deferred interface vocabulary, because that is what these six requirements actually are (statements of what the system must do), and let the designation lint report the resulting, expected finding rather than forcing a false purity.
Record the prompt-class contradiction and the `A5` sharp edge as open items rather than resolving either inside this change.

## Design trade-offs

Choosing to defer the interface relocation keeps this change reviewable as one thing — assumption extraction — at the cost of leaving `pi-agent-environment` a capability whose stratum tag and vocabulary do not yet fully agree, for one more cycle.
Choosing to record rather than resolve the prompt-class contradiction keeps a genuine human decision with the human, at the cost of leaving `Additional shell policy` (and part of `Fail-open policy`) formally undischarged until that decision lands.
Choosing to flag rather than fix the `A5` sharp edge respects the "no behavioral change" boundary this change was given, at the cost of leaving a known-real edge case in the shipped policy for a following change to close.
