# Retrospective: pyrite-baremetal-nixos

> Written: 2026-08-01 (after verify passed)
> Commit range: the change's jj chain on bookmark `pyrite-baremetal-nixos`; change ids are not enumerated here (see §0)
> Worktree: jj diamond development join on bookmark `pyrite-baremetal-nixos` (no git worktree; worktree-creating surfaces are hook-blocked in jj mode)

---

## 0. Evidence

> Up-front quantified data; the sections below reference these figures rather than re-citing them per line.

- **Commit range**: not enumerated in this artifact.
  Version control is orchestrator-owned for this change and this artifact was authored under a no-VCS-command constraint, which is the same reason `verify.md:129` records the range as "the change's jj chain; change ids are not enumerated by this step".
- **Diff size**: not collected, for the reason above.
  The implementation surface is `modules/machines/nixos/pyrite/default.nix` (21367 bytes) and `disko.nix` (8554 bytes), the static `machines/pyrite/facter.json` (78036 bytes), the 1033-line `docs/notes/development/hardware/pyrite-install-runbook.md`, and single-line or few-line registrations across nine hand-maintained lists enumerated at `verify.md:198`.
- **Tasks done**: 66/75 (`grep -cE '^\s*- \[x\]' tasks.md` → 66; `grep -cE '^\s*- \[ \]'` → 9).
  The nine unchecked are one `(retired)`, seven `(superseded)`, and one `(non-goal)`, itemized with their reasons at `verify.md:52-64`; none names work the implementation still owes.
- **Active hours**: not instrumented.
- **Subagent dispatches**: not instrumented as a total.
  Two fan-outs are load-bearing to the analysis below and are counted: an independent refutation pass over fifteen reconciled tasks, and six parallel document-correction agents.
- **New external dependencies**: one — `nixos-hardware` (`github:NixOS/nixos-hardware`, CC0-1.0 per its `COPYING`, pinned in `flake.lock` at `779c32a00155`), declared at `flake.nix:86-87` with `inputs.nixpkgs.follows = "nixpkgs"`.
- **Bugs encountered post-merge**: none post-archive (not yet archived at write time).
  Two defects were found and closed pre-archive: the FIDO2 enrollment inside disko aborting post-`luksFormat`, and an initrd `brcmfmac` defect that task 7.16 fixed and then verified unattended across a cold boot.
- **OpenSpec validate state at archive**: pass (pre-archive).
  `openspec validate pyrite-baremetal-nixos --strict` exits 0 with "Change 'pyrite-baremetal-nixos' is valid"; the four delta-spec capabilities report "pending sync" at `verify.md:73-78`, which archive resolves.
- **Test coverage signal**: no executable unit-test suite; this change's deliverable is a machine configuration and an irreversible install path.
  The severe checks are disko's own `installTest` VM harness against pyrite's layout (task 3.11, exit 0, eight of eight assertions), `nix eval` against the built configuration for every eval-decidable clause of all 24 delta-spec requirements, `nix build` of the toplevel, and read-only inspection of the installed machine over the ZeroTier mesh.

Commit chain (chronological):

```
not enumerated — see the Commit range bullet above
```

---

## 1. Wins

- [§0 tasks; verify.md:274]
  All 24 requirements across the four delta specs are satisfied with no requirement unmet, on a change whose central task was irreversible and executed exactly once.
  The verdict names the mix of evidence it rests on — `nix eval` for eval-decidable clauses, live read-only inspection for the container's keyslots, the pool, the network association and the running units, and cited tasks for on-hardware observations — so a reader can judge its strength per claim rather than in aggregate.

- [§0 subagent dispatches]
  Adversarial verification changed outcomes rather than confirming them.
  A reconciliation pass judged fifteen tasks complete, and an independent pass instructed to refute rather than confirm overturned four of those judgements.
  The grounds were not stylistic: evidence that addressed a superseded version of the criterion, and evidence that proved an adjacent proposition rather than the stated one.
  A confirmatory second reading would have passed all fifteen.

- [§2, third bullet; verify.md:165]
  Several tasks were rewritten mid-change to remove verifications that could not fail.
  A bare `zpool import` was replaced by comparing pool GUIDs across the wipe, which is what distinguishes a created pool from a surviving one; the check now reads `14433194292156182684` live against the pre-wipe `14727267720509425254`.
  A `clan machines update` that moves no closure was recognized as proving only that a connection opened.
  The same discipline is visible in the verify artifact, which records that the `installTest` harness asserts a second format against a surviving container leaves data intact — an assertion that is "actively misleading" here, because it is the exact code path the recorded `blkdiscard` exists to foreclose.

- [verify.md:165, §7]
  The single-execution install path is stated as compliance rather than smuggled in as a discharged claim.
  The delta spec says re-runnability is a property of the recorded text, and `verify.md` §7 enumerates what the VM harness does not reach — the FIDO2 path, the `_1` namespace, Apple's ESP-by-type discovery, `blkdiscard`, the SPI keyboard, and the 4096-byte sector premise — instead of letting an exit-0 harness stand for a second destructive install.

- [design.md:411 D25; verify.md:213]
  Key material is treated as a maintained artifact rather than an install-time byproduct.
  The LUKS header backup is stored off the machine as key material with no `age` layer, re-taken after every enrollment change, and the keyslot inventory is recorded at enrollment, with capture, restore, inventory and revoke procedures at four separate points in the runbook.

## 2. Misses

- [high] [blocking | §0 test coverage; verify.md:124]
  The machine had no fallback for its entire bring-up: one system generation, one boot entry, no specialisation, no initrd network, and no TPM.
  Every deploy during that window went to a machine recoverable only by a person at the keyboard with external media, and the first routine deploy after the install is what created a second selectable generation.
  This was not identified as a risk in its own right before the destructive step; it was a property of the situation that became visible in retrospect.

- [high] [blocking | §5, first four bullets]
  Four claims were written into the design, the delta specs, the task text and the runbook that the hardware then disproved.
  Each was written in good faith from documentation or from reading source, and each was falsified the first time hardware answered the question.
  The cost was not only correction: two of them (the `crypttabExtraOpts` requirement and the single-PCI-address d3cold unit) had propagated into acceptance criteria that then became unjudgeable as written.

- [med] [painful | §0 tasks; verify.md:38-51]
  Nine of the seventy-five boxes end unchecked because their criteria are unjudgeable as written rather than unsatisfied, and the ledger had no way to say so.
  The `(retired)` / `(superseded)` / `(non-goal)` marker vocabulary that now heads `tasks.md` was acquired at the end of the change, after the ambiguity had already been carried through several reconciliation passes.
  Before it existed, "not done" and "no longer meaningful" were the same unchecked box.

- [med] [painful | §0 subagent dispatches]
  Six agents correcting documents in parallel each produced internally correct work that contradicted across the boundaries.
  The sharpest instance was a delta spec requiring that a unit MUST NOT be enabled while a design decision still specified it.
  Independent correctness of each part is not coherence of the whole, and nothing in the dispatch shape enforced the latter.

- [med] [painful | verify.md:107; plan.md:3-9]
  Artifact drift was recorded rather than repaired in two places, deliberately, and both are real costs even though the decision was right.
  Tasks 9.1 through 9.4 still describe superseded forms in their checkbox lines while `design.md` and the delta spec are reconciled to what is implemented, and `plan.md` is marked superseded in place with five enumerated staleness modes rather than corrected.
  The alternative — rewriting acceptance criteria after the fact, and maintaining a second plan competing with `tasks.md` — is worse, but the residue is that two artifacts now require their own headers to be read before their bodies.

- [low] [nit | verify.md:221-230]
  One evidentiary claim rests on construction and the install log rather than a captured reading: the gate command establishing that the container held zero `systemd-fido2` tokens ran between pool import and first enrollment, but its stdout was not captured, and the header now carries two tokens.
  The inference is severe against the failure it exists to catch, since the container's `luksUUID` differs from the pre-wipe value, but a captured reading would have cost nothing at the time.

## 3. Plan deviations

| Plan task | What changed | Why |
|---|---|---|
| plan.md as a whole | Marked superseded in place and retained as a record; `tasks.md` became the operative ledger and the runbook the operative procedure | Correcting it would have produced a second artifact competing with `tasks.md` rather than a better plan; the two checklists do not enumerate the same steps and `tasks.md` carries a ninth phase the plan has no counterpart for |
| Task 3 Step 3 (ZFS native encryption, `aes-256-gcm`, `postCreateHook` flipping `keylocation` to `prompt`) | Replaced by a LUKS2 container holding the pool, with no dataset-level encryption at all | D1. The revision landed after tasks had already passed against the superseded design |
| Task 7 (FIDO2 enrollment inside disko) | `enrollFido2 = false`; both tokens enrolled by hand on the booted machine, each guarded by a presence check with the other token physically removed | D30, after the in-disko enrollment aborted post-`luksFormat` with `FIDO_ERR_OPERATION_DENIED`; the install became non-interactive as a consequence |
| Task 7 Step 2 (`--phases disko`) | Forbidden outright | Zeroing the kexec phase rewrites the ssh connection to `root@` and hangs indefinitely on key upload after the wipe |
| Task 7 Step 12 (second proving install) | Dropped; the destructive path executes exactly once | D29. Re-runnability is stated as a property of the recorded text rather than a demonstrated claim |
| Task 7.12b (`crypttabExtraOpts = [ "fido2-device=auto" ]`) | Deliberately not set; the option evaluates to `[]` on the installed machine | The premise that nothing else turns token unlock on is falsified — see §5. Setting it would migrate the unlock onto systemd's own FIDO2 path and invalidate the token unlock and passphrase fallback already observed |
| Plan "Out of scope" (the d3cold suspend workaround) | Brought into scope as design Goal 5 and tasks Phase 9 | D21 and D22 |
| Task 9.1 (one `disable-nvme-d3cold` unit on one PCI address) | Three units sweeping the whole PCI tree, with the upstream profile's endpoint-scoped block left dormant | A live test found the resume wedged with the Thunderbolt switch and the WiFi still at `d3cold_allowed = 1`; the endpoint-only form is not sufficient |
| Task 9.2 (permanent panic-on-hung-task sysctls) | Declined; `kernel.panic` is set and pstore archival is available, the hang knobs are not permanent | False-positive-prone on ZFS scrubs and long nix builds; `design.md:388` and the delta spec are amended down to that |
| Task 5 Step 1 (stand up a dedicated fleet SSID) | Not done; the pre-existing household network is used under the internal `fleet` identifier | Operator decision, recorded at task 5.1 and D14 |
| Audio Non-Goal rationale | The Non-Goal stands for this change; its stated rationale is withdrawn and audio is taken up as its own change | The rationale was found to be factually wrong — see §5 |

## 4. Skill / workflow compliance

| Skill                                            | Used |
|--------------------------------------------------|------|
| superpowers:brainstorming                        | yes  |
| superpowers:writing-plans                        | yes (superseded in flight) |
| superpowers:using-git-worktrees                  | no (diamond-adapted) |
| superpowers:subagent-driven-development          | yes  |
| (transitive) superpowers:test-driven-development | no (irreversible hardware target) |
| (transitive) superpowers:requesting-code-review  | yes  |
| superpowers:finishing-a-development-branch       | no (diamond-adapted) |

> **Default expectation**: all yes.
> Two skips are jj-mode boundary conditions repeating from the previous cycle, and one is an irreversible-hardware boundary condition new to this cycle.

### Deliberately Skipped Skills

- **`superpowers:using-git-worktrees`**
  - **What was skipped**: the `git worktree add` isolation step.
    Apply ran in a jj diamond development join with orchestrator-routed commits onto the `pyrite-baremetal-nixos` chain, as `plan.md:36` states.
  - **Why this cycle**: the repository is jj-colocated, and the harness denies `EnterWorktree`, `ExitWorktree`, and worktree-isolated Task dispatches at the PreToolUse layer, so the skill resolves to a hook-blocked command.
    This is the identical trigger recorded in the previous cycle's retrospective for this schema.
  - **How to prevent recurrence**: `schema graph fix`.
    This is the second consecutive cycle skipping this skill for the same reason with the same prevention answer, which by the §4-to-§6 rule makes it a schema PR motivator rather than a norm to keep re-recording; it is carried into §6 with its severity raised.

- **`superpowers:finishing-a-development-branch`**
  - **What was skipped**: the autonomous PR-open step.
    Integration is jj-native onto the chain and commits and pushes are orchestrator-owned.
  - **Why this cycle**: the same jj-mode condition.
    `verify.md:131` records the pushed checkbox left unchecked on exactly this ground — "push is owned by the orchestrator and is not a verify precondition" — so the skip is visible in the verify artifact rather than inferred.
  - **How to prevent recurrence**: `schema graph fix`, folded into the same §6 candidate as the row above, since the two skips share a trigger and a remedy.

- **`(transitive) superpowers:test-driven-development`**
  - **What was skipped**: writing a failing test before the implementation.
  - **Why this cycle**: the unit under test is a physical machine and the central operation is irreversible.
    A red phase for the install path means running `blkdiscard` against the only disk of a machine that has nothing to fall back to, which `plan.md:32` names as the change's point of no return.
    The type-appropriate severe check was built instead: disko's `installTest` VM harness exercised the layout, the container-on-mapper nesting, the passphrase unlock, and the pool properties before the destructive run (task 3.11, eight of eight assertions).
  - **How to prevent recurrence**: `scope-judgment rule`.
    When the target is irreversible hardware, route to a VM harness that exercises the layout ahead of the destructive run, and require the artifact to enumerate which propositions the harness cannot reach — as `verify.md` §7 does — so the harness is not silently read as a stand-in for the real path.
    The failure mode this guards against is specific and was observed here: one harness assertion, that a second format against a surviving container leaves data intact, is the precise code path the recorded wipe exists to foreclose, and taken at face value it argues against the wipe.

## 5. Surprises

- The design argued that `crypttabExtraOpts = [ "fido2-device=auto" ]` was required for FIDO2 unlock, on the reasoning that libcryptsetup's compiled token directory is empty while the plugin ships under the systemd prefix, so the token plugin could not be found.
  Unlock works with `crypttabExtraOpts` evaluating to `[]` and no `fido2-device=` in the generated initrd crypttab.
  The mechanism is that nixpkgs applies `pkgs/by-name/cr/cryptsetup/relative-token-path.patch`, which rewrites the plugin lookup from `crypt_token_external_path()` to a bare soname on the linker search path, and `nixos/modules/system/boot/systemd/fido2.nix:26-30` puts the plugin and `libfido2.so.1` into the initrd.
  The claim had propagated into `design.md`, three delta specs, the task text, and the machine module before hardware answered it.

- The audio Non-Goal rested on the claim that the only out-of-tree module carrying the CS8409 amplifier init tops out below this repository's pinned kernel.
  The module has no such hard ceiling and builds clean against that kernel.
  The Non-Goal itself stands for this change; the rationale is withdrawn rather than carried forward, and audio is taken up as its own change.

- D25 claimed the FIDO2 serial-to-slot mapping was unreconstructable once both tokens were enrolled, which is why the mapping was recorded by hand at enrollment.
  Each token names its own keyslot in the header: `cryptsetup token export` binds the two `systemd-fido2` tokens to keyslots 1 and 2 respectively.

- The runbook stated that `blkdiscard` proceeds past its partition-table warning, and instructed the reader not to go looking for a force flag.
  `blkdiscard` from util-linux 2.42 refuses the bare invocation against a disk that still carries a signature, and `-f` is what makes it run.
  This is a documentation deliverable carrying a runnable-correctness bug in the single most consequential command in the change, which is the same class the previous cycle's retrospective flagged as an unchecked promote candidate.

- FIDO2 enrollment inside disko aborted after `luksFormat` with `FIDO_ERR_OPERATION_DENIED`.
  The container therefore existed with a passphrase keyslot and no tokens, which produced D30's deferral of enrollment to first boot and made the install non-interactive.

- `clan machines install` commits `inventory.json` mid-run.
  Under a jj development join this gives the join a second child, so the change exists twice — once as the working-copy snapshot and once as clan's own commit — and requires repair before the chain can be routed.

- The two lid-related claims are not the same claim.
  Suspend and resume work across three cycles in one boot with the pool intact, and a warm reboot taken after a suspend still loses the Thunderbolt and PCIe subtree.
  The delta spec states the distinction explicitly rather than averaging them, which is what keeps task 9.6 declined instead of quietly satisfied.

## 6. Promote candidates → long-term learning

- [ ] [high] **A claim written before the hardware can answer it is a conjecture, and must be labelled as one in the artifact that carries it** → **Promote to memory** (type: feedback)
  > **Why**: four independent claims in this change — the `crypttabExtraOpts` requirement, the CS8409 kernel ceiling, D25's unreconstructable slot map, and the runbook's `blkdiscard` force-flag instruction — were each written confidently and in good faith from documentation or from reading source, and each was falsified the first time hardware answered.
  > **How to apply**: when writing a design decision, delta spec, or runbook step for hardware not yet in hand, mark each claim with how it was established (read from source, read from docs, measured) and treat the unmeasured ones as provisional; re-check them against the machine before they harden into acceptance criteria, because two of these four had already propagated into criteria that became unjudgeable rather than merely wrong.

- [ ] [high] **A verification that cannot fail proves nothing; state what each check would catch before accepting it** → **Promote to skill** (`verification-before-completion`)
  > **Why**: this change replaced a bare `zpool import` (which cannot distinguish a created pool from a surviving one) with a GUID comparison across the wipe, and recognized that a `clan machines update` moving no closure proves only that a connection opened; separately, one VM-harness assertion argues for the exact code path the recorded wipe exists to foreclose.
  > **How to apply**: at the moment a check is written into a task's acceptance criterion, name the failure it would catch and confirm the check discriminates against that failure; a check that passes identically under the success and the failure it is meant to detect is not evidence.

- [ ] [high] **Before the first irreversible deploy, name the recovery path and how many selectable generations exist** → **Promote to project CLAUDE.md** (vanixiets, machine-fleet section)
  > **Why**: pyrite's entire bring-up ran against one system generation, one boot entry, no specialisation, no initrd network and no TPM, so every deploy in that window was to a machine recoverable only in person with external media; the second selectable generation appeared only as a side effect of the first routine post-install deploy.
  > **How to apply**: at the point a machine is first installed and before each deploy until a second generation exists, state the recovery path explicitly; for a laptop with no ethernet port and no fallback OS, that is the operative blast radius, not a formality.

- [ ] [med] **A ledger needs a vocabulary for "no longer meaningful", distinct from "not done"** → **Promote to schema** (superpowers-bridge, tasks artifact)
  > **Why**: a mid-flight design revision (D1's move to a LUKS2 container and D30's deferral of FIDO2 enrollment) reopened work that had already passed against the superseded design, leaving nine of seventy-five boxes unchecked for reasons that are not outstanding work; the `(retired)` / `(superseded)` / `(non-goal)` markers that now head `tasks.md` were acquired only at the end.
  > **How to apply**: when a design decision lands after tasks have been checked against its predecessor, mark the affected criteria immediately with which of the three conditions applies and append the continuation stating what replaced them, rather than leaving an unchecked box to be re-litigated at verify.

- [ ] [med] **Independent parallel work needs a reconciliation step before application, not after** → **Promote to memory** (type: feedback)
  > **Why**: six agents correcting documents in parallel each produced internally correct work that contradicted across the boundaries, most sharply a delta spec requiring that a unit MUST NOT be enabled while a design decision still specified it; a reconciliation pass between independent work and application caught it.
  > **How to apply**: when fanning out edits across documents that reference each other, add an explicit reconciliation step that reads the union of the outputs before any of them is applied, and check the cross-document propositions specifically — a per-agent review confirms only local correctness.

- [ ] [med] **Instruct the verification pass to refute, not to confirm** → **Promote to memory** (type: feedback)
  > **Why**: a reconciliation pass judged fifteen tasks complete and an independent pass instructed to refute overturned four of them, on grounds a confirmatory reading does not surface — evidence addressing a superseded version of the criterion, and evidence proving an adjacent proposition rather than the stated one.
  > **How to apply**: when dispatching a verification or reconciliation pass over already-judged work, make the brief adversarial by construction; the two failure modes to name explicitly are stale-criterion evidence and adjacent-proposition evidence.

- [ ] [med] **Codify the jj diamond development join as the schema's sanctioned worktree substitute** → **Promote to schema** (superpowers-bridge apply/finish phases)
  > **Why**: carried forward from the previous cycle's retrospective, where it was raised on the same two skills for the same reason and left unchecked; this is now the second consecutive cycle in which `using-git-worktrees` and `finishing-a-development-branch` are both skipped because the harness hook-blocks worktree surfaces in jj mode, which is the pattern the §4-to-§6 rule says must not accumulate into a norm.
  > **How to apply**: at the apply gate when `.jj/` is present, the schema should branch to the diamond development join and orchestrator-owned integration rather than to git-worktree isolation and an autonomous PR.

- [ ] [med] **Documentation deliverables carry runnable-correctness bugs; red-team the literal commands against the tool** → **Promote to memory** (type: feedback)
  > **Why**: carried forward from the previous cycle's retrospective and now recurring with a materially higher stake — there the defects were a JSON-parse shape and a missing scope flag in a skill's recipe text, here it is `blkdiscard` documented as proceeding past its warning with an explicit instruction not to look for a force flag, in the one command that destroys the disk.
  > **How to apply**: when a runbook or skill embeds literal commands, verify each against the tool's `--help` or source at the pinned version rather than reading it as prose; escalate the check for any command that is irreversible or that the surrounding text tells the reader not to second-guess.

- [x] [low] **`clan machines install` commits `inventory.json` mid-run and forks a jj development join** → **Realized** (already in memory)
  > **Why**: the mid-run commit gives the join a second child, so the change exists twice — as the working-copy snapshot and as clan's own commit — and the fold order is load-bearing when repairing it.
  > **How to apply**: before running `clan machines install` under a development join, expect the fork and plan the repair; this is recorded in memory and is listed here only so the retrospective's audit trail shows it was surfaced by this cycle.

### Deferred work, follow-ups, and non-goals

The records below are carried forward so they are not lost.
Each is deferred or out of scope by deliberate decision rather than by omission.

niri is deferred to its own successor change under D19 and is excluded here by an explicit Non-Goal.
The desktop this change ships is stock GNOME under GDM, which is what the delta spec requires, and everything niri's shell would need beyond the compositor is out of scope by name in `design.md:180`.

Audio is a Non-Goal of this change and stays one.
Its recorded rationale is factually wrong and is withdrawn rather than carried forward; audio is taken up as its own change, where the rationale is corrected.

Task 9.6, restoring the lid handlers to `"suspend"`, is declined by operator decision under an existing Non-Goal.
The handlers stay at `"lock"`, `"lock"`, and `"ignore"` while a warm reboot taken after a suspend still loses the Thunderbolt subtree, because a lid close is the most common way to reach the suspend path.
The decline is revisited when a suspend followed by a warm reboot leaves the subtree intact.

pyrite loses `wlp2s0` from the PCI bus across a warm reboot, and only a full power cycle restores it.
This is distinct from the initrd `brcmfmac` defect task 7.16 fixed, which is resolved and verified unattended across a cold boot.

Bluetooth is untracked.
It is diagnosed as a UART bring-up race, and there is no fix written, no task carrying it, and no Non-Goal declining it; it is named so its absence from the artifact set is deliberate rather than something a later reader has to rediscover.

A panic actually written to EFI variables and archived on the next boot is an on-hardware observation this change does not make.
The reboot-on-panic setting and the pstore archival path are configured and eval-decidable, and that is the whole of what the requirement covers.

Four further items are out of scope by name and unchanged by this cycle: hibernation, correcting `base`'s cloud-VM initrd assumptions for the fleet, regenerating facter reports on this hardware, and a terranix entry for pyrite.
The pre-existing justfile defects a new machine walks into — `check-uncached-machine` hardcodes four hosts and already omits magnetite — are likewise left for their own change.
