## Context

`openspec/specs/` is meant to hold requirements that are durable: true of the system, checkable at any time, and still meaningful after any one implementation episode ends. An audit of all 77 requirements across the 10 existing capabilities found a cluster that fails that test.

Three requirements in `pi-agent-environment` — `Stale Pi version cleanup`, `Human-only activation`, `Confirmation-gated live verification` — were synced verbatim from the closing task rows of the archived change `2026-08-15-configure-pi-agent-environment`. They constrain "Implementation" (that change's own implementing agent, in that one episode) or name a specific human by name and a specific command. A fourth, `Rollback preservation`, states a durable property but phrases it as depending on a value "recorded before activation," which reads as episode-bound even though the property itself is not.

Five further capabilities — `apple-laptop-hardware-support`, `bare-metal-install-path`, `encrypted-zfs-root`, `graphical-desktop-session`, `stratified-change-authoring` — carry eleven literal `this change` references predating this session. A `this change` reference is a deictic pointer to whichever OpenSpec change was active when the sentence was written; once that change's directory moves under `archive/`, the reference has no stable target from a corpus reader's position, even though the archived directory itself remains readable at a fixed path.

Mid-session, the user (relayed by the orchestrator) raised and then withdrew a proposal to enforce the "no `openspec/specs/` reference into `openspec/changes/`" rule mechanically as a flake check. That reversal, and the schema/skill prose it was replaced with, are both part of this change's scope and are recorded under Decisions below.

## Goals / Non-Goals

**Goals:**
- Every requirement this change touches states a property true of the system, checkable at any time, independent of which change wrote it.
- The two standing policies embedded in `Human-only activation` and `Confirmation-gated live verification` survive as durable requirements rather than being silently dropped along with their episode-bound phrasing.
- Every `this change` reference in the five named capabilities gets an explicit, individually justified disposition; none are silently left in place by omission.
- The `Stale Pi version cleanup` deletion is verified safe by confirming the archived change carries the requirement, its design row, its task mapping, and its verify coverage (naming the standing check locations) before deletion.
- The outward-reference constraint this audit surfaces is stated durably at the two points text enters or crosses into any project's corpus that selects this schema: the `specs` artifact instruction and the archive step's instruction in `modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml`, plus the underlying principle in `preferences-requirements-engineering`'s `SKILL.md`.

**Non-Goals:**
- This change does not rewrite `bare-metal-install-path` or `encrypted-zfs-root`'s dense narrative style, their date-anchored evidentiary prose, or any content beyond the specific `this change` clauses identified below. A broader rewrite was not authorized and was not asked for.
- This change does not add a mechanical check, lint, or derivation enforcing the outward-reference constraint. See D7.
- This change does not run `openspec archive`. It stops at a passing `verify.md`.
- This change does not touch `openspec/specs/` directly (delta specs are the only mechanism) or `openspec/linear.yaml`.
- This change does not touch `modules/` beyond the two session-authorized files named above (the schema bundle and the requirements-engineering skill), both edited outside `openspec/specs/`'s own delta mechanism because they are schema/skill infrastructure, not corpus content.

## Decisions

### D1: Delete `Stale Pi version cleanup` outright, no replacement

- **Choice**: Remove the requirement and its scenario from `pi-agent-environment/spec.md` via a `REMOVED Requirements` delta, with no replacement text.
- **Rationale**: It is a one-time task ("remove Pi 0.83 references from two named files, preserve 0.84.1") with no standing policy behind it. Verified before deletion: the archived change carries it verbatim at `openspec/changes/archive/2026-08-15-configure-pi-agent-environment/specs/pi-agent-environment/spec.md:205-212`, with a design row at `design.md:183` ("Observe assertion-level RED in both files, then require Pi 0.84.1 with no Pi 0.83 reference"), a task mapping at `tasks.md:54-55`, and verify coverage at `verify.md:122` naming the standing check locations (`modules/checks/pi-agent-environment.nix:2382-2383,2427-2429`). Nothing is lost by deleting the corpus copy.
- **Alternatives considered**: Rewriting it as a durable requirement (e.g., "the system MUST reference no Pi version older than 0.84.1") was rejected — it would either duplicate the already-durable `Nix-owned Pi resources` requirement (which already pins `0.84.1`) or invent a floor-version policy nobody asked for.

### D2: Replace `Human-only activation` and `Confirmation-gated live verification` with two requirements carrying the user's verbatim policy

- **Choice**: Two new requirements, `Activation requires explicit permission` and `Post-activation confirmation gate`, split the user's supplied policy sentence at its natural clause boundary (permission-gated activation with pre-activation recording; confirmation-gated post-activation probing), one requirement per original being replaced. "You" is rendered as "the human operator." Every modality (MUST NOT / MUST / MUST NOT) and the "unless given explicit permission to do so" carve-out survive unchanged. Episode-bound specifics — "Implementation," "Cameron," `just activate --ask` — are dropped, since the user's wording did not name them and they are exactly what made the originals episode-bound.
- **Rationale**: Each original carried a standing policy recorded nowhere else in the repository. Deletion alone (as with D1) would silently drop live policy rather than expired task narration.
- **Alternatives considered**: A single merged requirement carrying the whole quoted sentence was rejected — it would need a scenario testing two independently-triggerable violation conditions (activation without permission; probing without confirmation) at once, weakening falsifiability. Keeping "Cameron" and `just activate --ask` for continuity with the original was rejected — the user's own wording is generic ("an agent," "you"/"the human operator," "system activation"), and reintroducing specifics not present in that wording would recreate the same episode-binding this change exists to remove.

### D3: Rephrase `Rollback preservation` as a post-activation link comparison

- **Choice**: State the requirement as: after activation, the active link points to `system-N-link`, and the immediately previous `system-(N-1)-link` remains present and resolvable. Drop "recorded before activation" and the "Cameron confirms activation" scenario trigger.
- **Rationale**: The asserted property already passes the durability test — it is checkable at any later time by comparing two links on disk. Only the phrasing tied it to a prior recording step and a named person's confirmation.
- **Alternatives considered**: Keeping "recorded before activation" as an assumption while durability-testing only the outcome was rejected — the recording step is not itself needed to check the property; requiring it would reintroduce an unnecessary episode dependency for no gain in rigor.

### D4: Strip change-fencing from `graphical-desktop-session`, keep the boundary claim

- **Choice**: Remove "and MUST NOT be assembled into this change" and "niri is the eventual daily-driver target and is deferred to a separate, reversible follow-up change deployed via `clan machines update`," leaving "niri and its Wayland shell assembly are NOT part of this capability." Remove "and no home-manager desktop toggle is added by this change," restating the surviving claim as "home-manager carries no desktop toggle."
- **Rationale**: The durable boundary claim — niri is not part of this capability — survives standalone. The fencing clause and the follow-up-change planning language both go stale the moment any such follow-up change lands (its directory moves to `archive/`, at which point "this change" and "a separate ... follow-up change" both stop resolving to anything a reader can check).
- **Alternatives considered**: Repointing "this change" at the (not-yet-existing) niri follow-up change was rejected outright — there is no in-corpus sibling to repoint to, and inventing a forward reference to unstarted work is exactly the anti-pattern this change exists to remove.

### D5: Resolve all eleven `this change` references, one disposition per instance

- **Choice**: Preference order per the assignment: state the substance inline; else repoint to an in-corpus sibling requirement; else drop. Full table:

  | # | File:line | Original clause (excerpt) | Disposition | Reason |
  |---|---|---|---|---|
  | 1 | `apple-laptop-hardware-support:82` | "...in both of the states this change passes through." | State inline → "...across the pre-enrollment and post-enrollment credential states." | The two states are already named explicitly in the next two sentences (lines 83–84); the change reference is redundant with them. |
  | 2 | `bare-metal-install-path:16` | "...and that property is NOT demonstrated by this change." | State inline → merge into the following sentence, dropping the clause. | Line 17 already states the identical substance ("re-runnability is a property of the recorded text and not a claim discharged by evidence"); the clause was a redundant restatement via an outward reference. |
  | 3 | `bare-metal-install-path:25` | "...both observed on the console of the run this change performed" | **Left unchanged.** | Date-anchored narration of an already-completed console session with a durable normative core (the explicit-wipe requirement). Named explicitly in the assignment as a deliberately-kept example. See D6. |
  | 4 | `bare-metal-install-path:31` | "...false of the state the install of this change meets..." | State inline → "...false of the state this LUKS install meets..." | Self-descriptive substitution; "this LUKS install" names the concrete subject without depending on any change entity's continued existence. |
  | 5 | `bare-metal-install-path:70` | "The install this change performs is therefore the first exercise..." | State inline → "This LUKS install is therefore the first exercise..." | Same substitution as #4, for consistency within the same requirement's scenarios. |
  | 6 | `bare-metal-install-path:166` | "...this change declares no additional `unmanaged` entry..." | State inline → "...the pyrite configuration declares no additional `unmanaged` entry..." | States the durable subject (pyrite's built configuration) instead of the change that authored it. |
  | 7 | `encrypted-zfs-root:148` | "...this is an acceptance criterion of this change rather than only a property of the layout..." | **Left unchanged.** | Date-anchored narration of the same already-completed install episode, durable normative core (the reformat-on-reinstall guard). Named explicitly in the assignment as a deliberately-kept example. See D6. |
  | 8 | `encrypted-zfs-root:179` | "...is accepted because hibernation is a non-goal of this change." | State inline → "...is accepted because hibernation is not a goal of pyrite's configuration." | States the durable subject (pyrite's configuration) instead of the change. |
  | 9 | `graphical-desktop-session:16` | "...and MUST NOT be assembled into this change." / "...deferred to a separate, reversible follow-up change..." | Drop. | Covered by D4: the durable boundary claim survives without the fencing or planning language. |
  | 10 | `graphical-desktop-session:28` | "...and no home-manager desktop toggle is added by this change" | State inline → "...home-manager carries no desktop toggle." | Covered by D4: states the current durable fact instead of what a change "added." |
  | 11 | `stratified-change-authoring:80` | "...finishes syncing this change's delta specs..." | State inline → "...finishes syncing the change's delta specs..." | This use is a bound variable inside a WHEN-clause describing `openspec archive`'s own generic behavior — it never names a specific frozen change, so it does not dangle the way #1–#10 do. Normalized from "this" to "the" only for consistency with the same sentence's existing "the change folder," to keep the corpus free of the surface pattern a future audit would otherwise re-flag. |

- **Rationale**: per-instance disposition, rather than a blanket find-and-replace, because the eleven instances are not textually or semantically uniform — four are genuine dangling pointers to a change's identity or role (1, 4, 5, 6, 8), two are fencing/planning language with a clean durable core underneath (9, 10 — see D4), two are deliberately-excepted narration (3, 7 — see D6), one is redundant with adjacent text (2), and one is a non-dangling generic role reference normalized only for surface consistency (11).
- **Alternatives considered**: Repointing any of 1–8 at an in-corpus sibling requirement (the second-preference disposition) was considered for each and rejected in favor of stating the substance inline, because in every case the substance was short enough to state directly without indirection, and no case needed a sibling requirement's authority to be correct on its own.

### D6: Leave two date-anchored narration lines unrewritten, on the record

- **Choice**: `bare-metal-install-path:25` and `encrypted-zfs-root:148` are not rewritten, despite containing the literal string "this change."
- **Rationale**: Both are narration of an already-completed, specific console session (the pyrite LUKS install and the aborted 2026-07-30 attempt it followed), embedded in scenarios whose surrounding requirement has a durable normative core (`The install path is recorded in the repository, and is written to be re-runnable without being shown to be`; `The pool sits inside a LUKS2 container holding the clan-vars passphrase in slot 0 and a FIDO2 token in each of slots 1 and 2`). The claims themselves are historical facts ("this was observed on the console of the run performed") that remain true forever regardless of whether the originating change is later archived; rewriting the surrounding sentence to avoid the words "this change" would be pure prose churn with no correctness gain. Recorded here so a later reader does not re-litigate it or mistake the omission for an oversight.
- **Alternatives considered**: Rewriting both for uniformity with D5's other nine dispositions was rejected as unauthorized scope expansion — the assignment named these two specifically as lines to leave, and the distinction (episode-identity reference vs. historical-fact narration) is real, not cosmetic.

### D7: Reject a mechanical outward-reference check; state the constraint in schema and skill prose instead

- **Choice**: No flake check, lint, or derivation enforcing "no `openspec/specs/` reference into `openspec/changes/`" is added anywhere in this repository. Instead, the constraint is stated as prose at the two points text enters or crosses into the corpus: the `specs` artifact instruction and the archive step's instruction in `modules/home/ai/openspec/assets/schemas/superpowers-bridge-wrspm/schema.yaml` (one to two sentences each), plus the underlying principle once in `modules/home/ai/plugins/formal-specification-and-refinement/.apm/skills/preferences-requirements-engineering/SKILL.md`, next to its designation-table section.
- **Rationale** (relayed mid-session from the user via the orchestrator, after an earlier proposal for the mechanical check was withdrawn): a mechanical check is repository-local — it lives in this one flake's checks and reaches only this one repository. The OpenSpec schema bundle, by contrast, is delivered user-global to `~/.local/share/openspec/schemas/`, the same collection every repository that selects this schema resolves from. Prose stated in the schema's own instructions reaches every consumer of the schema on the next activation; a check confined to this flake would not port to any of them. A check is also more convoluted to maintain than two sentences of instruction prose for a constraint this narrow.
- **Boundary named**: source-versus-delivered. The schema and skill files edited here are the authored source under `modules/home/ai/`; the delivered copy every repository actually reads is under `~/.local/share/openspec/schemas/` (schema) and the corresponding activated skill path (skill), populated by nix-darwin activation. This change edits only the source; the constraint takes effect fleet-wide on next activation, not immediately in this repository's current session.
- **Alternatives considered**: The originally proposed flake check was rejected for the portability reason above. Splitting the constraint's statement into the schema alone (no skill addition) was rejected once the audit found the underlying principle was stated nowhere — omitting the skill addition would leave the *procedure* (schema) without the *concept* (skill) it enacts, and a future schema not selected by a project would carry no discipline at all. Conversely, stating the constraint only in the skill (no schema addition) was rejected because a skill is read at authoring time by whoever chooses to load it, while the schema's instruction prose is read by every agent following that schema's own workflow, whether or not the requirements-engineering skill is separately loaded.

## Risks / Trade-offs

- [Risk] The eleven-instance table in D5 required per-instance judgment rather than a mechanical rule; a different reviewer might disposition one or two instances differently (e.g., instance 11's "left as generic, normalized only" call). → Mitigation: each row states its reason inline in the table, and instance 11 in particular is called out as a boundary case with its distinguishing test spelled out, so a disagreement can be raised against a stated argument rather than against silence.
- [Trade-off] Leaving `bare-metal-install-path` and `encrypted-zfs-root`'s dense narrative style otherwise untouched, rather than reformatting them toward the corpus's more common concise style, trades stylistic uniformity for a diff scoped exactly to the defect class this change repairs. → Accepted: a broader rewrite was not authorized and risks introducing unrelated regressions in two of the corpus's most detailed capabilities.
- [Risk] The schema and skill edits (D7) take effect fleet-wide only after the next nix-darwin activation of any consuming repository, per `openspec/config.yaml`'s own context note. → Mitigation: this is documented behavior for this schema bundle already (see that config's context section), not a new risk this change introduces; no repository observes the new instruction prose until it activates the updated derivation.

## Migration Plan

N/A — this is a prose-only corpus and schema/skill edit with no code, data, or deployment surface. No rollback beyond reverting the edited files is needed; none of the changes are load-bearing for any running system.

## Open Questions

None outstanding. The one open question raised mid-session (whether a mechanical check should enforce the outward-reference constraint) was resolved and recorded as D7.
