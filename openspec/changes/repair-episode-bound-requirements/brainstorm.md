Raw capture. This change was scoped directly by the user in conversation with the orchestrator rather than through an interactive brainstorming session with this agent; the decisions below are recorded in decision-log form to match the artifact's usual shape.

## Background

An audit of all 77 requirements across the 10 capabilities in `openspec/specs/` found a small cluster that fail the durability test a corpus requirement must pass: true of the system, checkable at any time, still meaningful after any one implementation episode ends. The cluster traces to two sources.

First, one archived change (`2026-08-15-configure-pi-agent-environment`) synced three of its closing task rows into `pi-agent-environment/spec.md` verbatim. Those rows constrain "Implementation" — the change's own implementing agent, in one episode — rather than the system.

Second, five other capabilities (`apple-laptop-hardware-support`, `bare-metal-install-path`, `encrypted-zfs-root`, `graphical-desktop-session`, `stratified-change-authoring`) carry `this change` references that predate this session: deictic pointers to whichever change was active when the requirement was written. Once that change moves to `archive/`, the reference has nothing stable to resolve against from a corpus reader's position.

## Decision chain

Q1: Can `Stale Pi version cleanup` simply be deleted?
A1: Yes. It is a one-time task ("remove Pi 0.83 references from two named files") with no standing policy behind it — Pi is now at 0.84.1 and the two named files were the only cited targets. The archived change carries the requirement verbatim at `openspec/changes/archive/2026-08-15-configure-pi-agent-environment/specs/pi-agent-environment/spec.md:205-212`, with a design row (`design.md:183`), a task mapping (`tasks.md:54-55`), and verify coverage naming the standing check locations (`verify.md:122`, citing `modules/checks/pi-agent-environment.nix:2382-2383,2427-2429`). Nothing is lost by deleting the corpus copy; the historical record and the standing check locations are both preserved elsewhere.

Q2: Can `Human-only activation` and `Confirmation-gated live verification` also simply be deleted?
A2: No. Each carries a standing policy — never activate without permission, record system-profile state first, never probe post-activation state before confirmation — that is not recorded anywhere else in the repository. Deleting them would silently drop real, still-applicable policy rather than expired task-completion narration. They need replacement requirements stating the policy durably (about "an agent" and "the human operator" in general, not "Implementation" and "Cameron" in one episode) rather than deletion.

Q3: What wording governs the replacement requirements?
A3: The user supplied the policy verbatim: "an agent MUST NOT run system activation unless given explicit permission to do so, MUST record the current `/nix/var/nix/profiles/system` link and its resolved store path before asking you to run it, and MUST NOT begin any post-activation live-state probe until you explicitly confirm the activation succeeded; nothing broader than activation and post-activation probing is claimed." This is used as the normative content, split across two requirements at its natural clause boundary (permission-gated activation; confirmation-gated probing), with "you" rendered as "the human operator" and every modality (MUST NOT / MUST / MUST NOT) and the permission carve-out preserved exactly.

Q4: Does `Rollback preservation` need replacement or just a rewrite?
A4: Rewrite only. Its asserted property — the previous generation stays present and resolvable behind the active one after activation — is already durable and checkable at any time. Only the phrase "recorded before activation" ties it to one episode's recording step. Restating it as a post-activation link comparison (active generation vs. immediately-previous generation, both queried after the fact) removes the episode dependency without changing what the requirement actually guarantees.

Q5: What about the two change-fencing clauses in `graphical-desktop-session`?
A5: Strip them, keep the underlying boundary claim. "niri ... MUST NOT be assembled into this change" and "no home-manager desktop toggle is added by this change" both fence against a change, and the "deferred to a separate, reversible follow-up change" language goes stale the moment that follow-up lands. The durable claim underneath both — niri is not part of this capability; home-manager carries no desktop toggle — survives standalone.

Q6: How should the eleven `this change` references (11 total: 1 apple-laptop-hardware-support, 5 bare-metal-install-path, 2 encrypted-zfs-root, 2 graphical-desktop-session, 1 stratified-change-authoring) be resolved?
A6: Per-instance, in stated order of preference (state substance inline > repoint to an in-corpus sibling requirement > drop), with two explicit exceptions left untouched: `bare-metal-install-path:25` and `encrypted-zfs-root:148` are date-anchored narration of an already-completed, one-time console session (the actual pyrite install and its aborted 2026-07-30 predecessor). Both have durable normative cores; rewriting the narration around them would be pure churn with no correctness gain, so they are recorded as deliberately unchanged rather than silently skipped. `stratified-change-authoring:80` uses "this change" as a bound variable inside a WHEN-clause describing `openspec archive`'s own generic behavior (whichever change is being archived) — it never names a specific frozen change and does not dangle, but is normalized from "this change's" to "the change's" for consistency with the adjacent "the change folder" in the same sentence. The remaining eight instances point at a specific past or planned change and get one of the three dispositions per-instance (see design.md's outward-reference table).

Q7 (mid-execution steering from the user, relayed by the orchestrator): should a mechanical check enforce "no `openspec/specs/` reference into `openspec/changes/`"?
A7: No. Rejected on portability grounds: such a check is repository-local (one flake, one repo) while the OpenSpec schema bundle is delivered user-global (`~/.local/share/openspec/schemas/`) and consumed by every repository that selects it. Stating the constraint in the schema's own instruction prose reaches every consumer; a check in this flake's checks reaches only this one. The constraint is instead stated in the schema's specs-artifact instruction (where corpus text originates) and its archive-step instruction (where text crosses into the living corpus), each in one to two sentences, without restating the full durability discipline.

## Design trade-offs

Splitting the user's one-sentence policy quote into two requirements (rather than one merged requirement, or three including the scope disclaimer as its own requirement) mirrors the two requirements being replaced one-for-one, keeps each requirement's scenario narrowly falsifiable, and avoids a requirement whose scenario would have to test two independently-triggerable violation conditions at once.

Leaving `bare-metal-install-path` and `encrypted-zfs-root`'s dense narrative style otherwise untouched (fixing only the literal `this change` clauses, not the surrounding sentence structure or the broader date-anchored evidentiary prose) trades stylistic uniformity for minimizing the diff to exactly the defect class this change exists to repair; a broader rewrite was not authorized and was not asked for.
