---
title: Satisfaction argument
description: Discharge status for every requirement in the OpenSpec corpus
generated: 2026-08-26
---

# Satisfaction argument

This file is a projection over `openspec/specs/`, regenerated wholesale at archive time and never patched.
A patched discharge table accumulates exactly the staleness the artifact exists to prevent, so any edit here is lost on the next regeneration.

It records, per requirement, which specification properties and which world assumptions discharge it — the `W ∧ S ⇒ R` obligation.
An undischarged requirement is recorded as such rather than omitted.

A discharge cell (`Discharged by (S)` or `Under (W)`) names a concrete artifact — a named check, a named scenario execution, a proof obligation, or a dated manual inspection — or it is left empty.
A capability-level characterisation is not evidence and is never written into a per-requirement cell.

## Correction

The regeneration before this one (`generated: 2026-08-25`) marked 19 of 68 requirements as discharged or partially discharged.
Every one of those 19 cells held one of exactly two phrases — `skill-corpus-interface: resolvability, trigger surface` or `own interface properties` — repeated verbatim across requirements in different capabilities.
Neither phrase names a check, a scenario execution, a proof obligation, or a dated inspection; both are capability-level characterisations restated as if they were per-requirement evidence, and no such per-requirement evidence exists anywhere in the corpus for these 19 rows.
This regeneration removes both phrases and leaves the affected cells empty.

- Before: 68 requirements across 9 capabilities. 9 discharged (S only), 10 partially discharged, 49 undischarged. 19 rows carried discharge text; all 19 carried the same two fabricated phrases.
- After: 77 requirements across 10 capabilities (`world-assumptions`, added by `extract-world-assumptions`, contributes 9). 0 discharged, 0 partially discharged. 6 requirements now name a concrete world assumption (`Under (W)`) but remain undischarged because no specification-side artifact (`Discharged by (S)`) has been established for them. 62 requirements are undischarged with both cells empty. The 9 `world-assumptions` rows are indicative claims, not `R`-side requirements, and are reported separately rather than folded into the discharged/undischarged tally.

The lower count is a correction, not a regression: the 19 discharged and partially-discharged rows in the prior generation were never actually backed by the evidence they cited.
The 6 new `Under (W)` cells are a genuine gain, made possible by `extract-world-assumptions` naming, for the first time, which world assumption each affected `pi-agent-environment` requirement's discharge argument rests on.

## Status

- 77 requirements across 10 capabilities: 68 `R`-side requirements (behavioral or interface stratum) plus 9 `world`-stratum assumption requirements.
- 0 of the 68 `R`-side requirements are discharged (S established).
- 6 of the 68 name a concrete world assumption under `Under (W)` but remain undischarged pending a specification-side artifact.
- 62 of the 68 are undischarged with both `Discharged by (S)` and `Under (W)` empty.
- The 9 `world-assumptions` rows are the corpus's first non-empty designation table and its first indicative assumptions; they are not themselves discharged or undischarged in the `R`-sense and are reported in their own section.

Of the 68 `R`-side requirements, 19 were authored under the stratum discipline (`skill-corpus-interface`, `requirements-stratification`, `satisfaction-argument-audit`, `stratified-change-authoring`) and 49 predate it; the latter are shown at their inferred stratum and have not been re-audited.
Guard level across every stratum-discipline capability remains `none`: no automated check currently guards any requirement in `skill-corpus-interface`, `requirements-stratification`, `satisfaction-argument-audit`, or `stratified-change-authoring`.

## apple-laptop-hardware-support

Predates the stratum discipline; not yet audited against it.

| Requirement | Stratum | Discharged by (S) | Under (W) | Status |
|---|---|---|---|---|
| The pyrite host module imports the upstream model profile with its unwanted firmware pulls disabled | behavioral | — | — | undischarged |
| The machine module states its firmware affirmations rather than inheriting them | behavioral | — | — | undischarged |
| The stage-1 initrd force-loads the four SPI/SMC modules that make the unlock prompt answerable | behavioral | — | — | undischarged |
| boot.initrd.kernelModules is never overridden with mkForce | behavioral | — | — | undischarged |
| A USB-C keyboard and the clan-vars passphrase are prerequisites of the first boot, not recoveries improvised afterward | behavioral | — | — | undischarged |
| The machine's configuration is never seeded from nixos-generate-config | behavioral | — | — | undischarged |
| The sleep path is gated by three units the machine module defines itself | behavioral | — | — | undischarged |
| Suspend is entered through the systemd-sleep path and resumes with the pool intact | behavioral | — | — | undischarged |
| A panic that outlives the disk is recorded through EFI pstore, because every other channel is unavailable on this machine | behavioral | — | — | undischarged |

## bare-metal-install-path

Predates the stratum discipline; not yet audited against it.

| Requirement | Stratum | Discharged by (S) | Under (W) | Status |
|---|---|---|---|---|
| The install path is recorded in the repository, and is written to be re-runnable without being shown to be | behavioral | — | — | undischarged |
| An install is accepted as evidence only if it exercised the create path | behavioral | — | — | undischarged |
| The hardware report is committed as static data and never regenerated on the target | behavioral | — | — | undischarged |
| The machine is registered across every hand-maintained list a new machine touches | behavioral | — | — | undischarged |
| Network association is declarative, and the credentials are sops-encrypted clan vars | behavioral | — | — | undischarged |
| ZeroTier admission requires redeploying the controller | behavioral | — | — | undischarged |
| A FIDO2 token is verified present before each enrollment, and disko's own guard is never that verification | behavioral | — | — | undischarged |

## encrypted-zfs-root

Predates the stratum discipline; not yet audited against it.

| Requirement | Stratum | Discharged by (S) | Under (W) | Status |
|---|---|---|---|---|
| The root is a ZFS pool created with an explicit ashift matching the disk's 4096-byte sectors | behavioral | — | — | undischarged |
| The ESP is typed EF00 and sized 1G | behavioral | — | — | undischarged |
| A sibling partition carries the ZFS content that becomes the pool's vdev | behavioral | — | — | undischarged |
| The pool device is named by a namespace-explicit by-id path | behavioral | — | — | undischarged |
| The pool sits inside a LUKS2 container holding the clan-vars passphrase in slot 0 and a FIDO2 token in each of slots 1 and 2 | behavioral | — | — | undischarged |
| The costs and the gains of the LUKS layer are both recorded rather than discovered later | behavioral | — | — | undischarged |
| The LUKS header and the keyslot inventory are maintained artifacts, not install-time byproducts | behavioral | — | — | undischarged |

## graphical-desktop-session

Predates the stratum discipline; not yet audited against it.

| Requirement | Stratum | Discharged by (S) | Under (W) | Status |
|---|---|---|---|---|
| The pyrite host provides a local GNOME desktop under GDM | behavioral | — | — | undischarged |

## pi-agent-environment

Predates the stratum discipline for its `Discharged by (S)` column; no specification-side artifact has been audited or established for any of the 25 requirements below.
`extract-world-assumptions` restated six of these requirements to name the specific `world-assumptions` requirement(s) their discharge depends on, so those six now carry a concrete `Under (W)` citation; the other 19 name no world assumption in their text and their `Under (W)` cell stays empty.
Naming `W` alone does not discharge a requirement — `W ∧ S ⇒ R` needs both — so every row below remains undischarged.

| Requirement | Stratum | Discharged by (S) | Under (W) | Status |
|---|---|---|---|---|
| Nix-owned Pi resources | behavioral | — | — | undischarged |
| Mutable settings seed | behavioral | — | — | undischarged |
| Runtime state boundary | behavioral | — | — | undischarged |
| Source-only extension package | behavioral | — | — | undischarged |
| Selected extensions | behavioral | — | — | undischarged |
| Nix-owned runtime executables | behavioral | — | — | undischarged |
| Excluded extension resources | behavioral | — | — | undischarged |
| Retained compaction extension | behavioral | — | — | undischarged |
| Canonical skill sink | behavioral | — | — | undischarged |
| Catppuccin source provenance | behavioral | — | — | undischarged |
| Catppuccin theme delivery | behavioral | — | — | undischarged |
| Permission-gate reuse | behavioral | — | world-assumptions A1 | undischarged (W named, S pending) |
| Additional shell policy | behavioral | — | world-assumptions A2 | undischarged (W named, S pending) |
| Non-Bash edit and write policy | behavioral | — | world-assumptions A1, A2, A3, A4, A5, A6, A7 | undischarged (W named, S pending) |
| Git default-branch boundary | behavioral | — | world-assumptions A3, A5, A7, A8 | undischarged (W named, S pending) |
| Jj diamond boundary | behavioral | — | world-assumptions A3, A5, A7, A8 | undischarged (W named, S pending) |
| Fail-open policy | behavioral | — | world-assumptions A1, A2, A3, A4 | undischarged (W named, S pending) |
| Secret-safe direnv | behavioral | — | — | undischarged |
| Opt-in slow mode | behavioral | — | — | undischarged |
| Consolidated custom regulators | behavioral | — | — | undischarged |
| Offline aggregate smoke | behavioral | — | — | undischarged |
| Stale Pi version cleanup | behavioral | — | — | undischarged |
| Human-only activation | behavioral | — | — | undischarged |
| Confirmation-gated live verification | behavioral | — | — | undischarged |
| Rollback preservation | behavioral | — | — | undischarged |

## world-assumptions

Added by `extract-world-assumptions`.
These 9 requirements are the `W` side of the argument, not `R`-side requirements: an assumption is not itself discharged by a specification property, so `Discharged by (S)` and `Under (W)` are not applicable and are shown as `—` for every row in this section.
Each assumption's own truth is asserted in its requirement text; no independent check, scenario execution, proof obligation, or dated inspection in the corpus verifies any of A1 through A8 against Pi's actual behavior, so `Status` records them as self-attested rather than discharged.
The `Discharges (R)` column lists which `pi-agent-environment` requirements lose their discharge argument if the assumption is falsified, copied from each requirement's own violation-condition scenario.

| Requirement | Stratum | Discharges (R) | Status |
|---|---|---|---|
| A1 — No native permission system | world | Permission-gate reuse, Non-Bash edit and write policy, Fail-open policy | self-attested |
| A2 — Unanswerable dialog stalls a session with UI but no human present | world | Additional shell policy, Non-Bash edit and write policy, Fail-open policy | self-attested |
| A3 — Policy failure carries no safety evidence | world | Non-Bash edit and write policy, Git default-branch boundary, Jj diamond boundary, Fail-open policy | self-attested |
| A4 — Refusing on ambiguity has a real cost and prevents nothing | world | Non-Bash edit and write policy, Fail-open policy | self-attested |
| A5 — A tracked target is recoverable from repository history | world | Non-Bash edit and write policy, Git default-branch boundary, Jj diamond boundary | self-attested |
| A6 — Atomic inherits Pi's configuration root unconditionally | world | Non-Bash edit and write policy | self-attested |
| A7 — Pi's enumerated path forms are exhaustive | world | Non-Bash edit and write policy, Git default-branch boundary, Jj diamond boundary | self-attested |
| A8 — Jj's outside-repository diagnostic is stable | world | Git default-branch boundary, Jj diamond boundary | self-attested |
| Grounded vocabulary for behavioral requirements (designation table) | world | (grounds every behavioral requirement's content nouns; not requirement-scoped) | self-attested |

## requirements-stratification

`skill-corpus-interface` establishes that the guidance reaches an agent, not that it is applied correctly, and no automated check guards this capability (guard level: none).
The prior generation's `Discharged by (S)` cells for all five rows below held the phrase `skill-corpus-interface: resolvability, trigger surface`, identical across all five and identical to the phrase used for the unrelated `satisfaction-argument-audit` capability; that phrase names no check, scenario execution, proof obligation, or inspection specific to any one of these five requirements, so every cell is now empty.

| Requirement | Stratum | Discharged by (S) | Under (W) | Status |
|---|---|---|---|---|
| Stratum assignment for any requirement-like statement | behavioral | — | — | undischarged |
| Grounding of terms used in requirements | behavioral | — | — | undischarged |
| Separation of what is assumed from what is wanted | behavioral | — | — | undischarged |
| Discharge of a requirement is stated, not implied | behavioral | — | — | undischarged |
| Obstacle analysis produces the boundary and open questions | behavioral | — | — | undischarged |

## satisfaction-argument-audit

`skill-corpus-interface` establishes that the guidance reaches an agent, not that it is applied correctly, and no automated check guards this capability (guard level: none).
The prior generation's `Discharged by (S)` cells for all five rows below held the same `skill-corpus-interface: resolvability, trigger surface` phrase described above, for the same reason now empty.

| Requirement | Stratum | Discharged by (S) | Under (W) | Status |
|---|---|---|---|---|
| Specification is checked against intent independently | behavioral | — | — | undischarged |
| Everything the argument depends on unverified is enumerated | behavioral | — | — | undischarged |
| Agreement between two artifacts is not treated as confirmation | behavioral | — | — | undischarged |
| External claims are bounded by what was actually established | behavioral | — | — | undischarged |
| The audit runs at a boundary, not continuously | behavioral | — | — | undischarged |

## skill-corpus-interface

Interface stratum. No automated check guards this capability (guard level: none).
The prior generation's `Discharged by (S)` cells for all three rows below held the phrase `own interface properties`, identical across all three and identical to the phrase used for the unrelated `stratified-change-authoring` capability; that phrase names no check, scenario execution, proof obligation, or inspection specific to any one of these three requirements, so every cell is now empty.

| Requirement | Stratum | Discharged by (S) | Under (W) | Status |
|---|---|---|---|---|
| A named skill is resolvable in the delivered corpus | interface | — | — | undischarged |
| A skill's trigger surface admits the situations it must fire on | interface | — | — | undischarged |
| Stated ownership boundaries hold across the corpus | interface | — | — | undischarged |

## stratified-change-authoring

Interface stratum. No automated check guards this capability (guard level: none).
The prior generation's `Discharged by (S)` cells for all six rows below held the same `own interface properties` phrase described above, for the same reason now empty.

| Requirement | Stratum | Discharged by (S) | Under (W) | Status |
|---|---|---|---|---|
| Proposal artifact records a stratum tag per capability | interface | — | — | undischarged |
| Specs artifact applies stratum-conditional vocabulary rules | interface | — | — | undischarged |
| Verify artifact runs non-blocking stratum checks | interface | — | — | undischarged |
| Archive step regenerates the satisfaction projection | interface | — | — | undischarged |
| Tasks artifact records per-task verification | interface | — | — | undischarged |
| The stratum layer states its own trust boundary | interface | — | — | undischarged |

## Known limits of this argument

No `R`-side requirement in this corpus carries a `Discharged by (S)` citation: no named check, scenario execution, proof obligation, or dated manual inspection has been recorded against any of the 68 requirements at the level of an individual requirement.
The three named checks `pi-agent-environment-structural`, `pi-agent-environment-policy`, and `pi-agent-environment-smoke` exist (see `pi-agent-environment`'s `Consolidated custom regulators` requirement) but no per-requirement mapping from any of the 25 `pi-agent-environment` requirements to a specific one of those three checks has been established in this corpus; asserting such a mapping here without that audit would reproduce the defect this regeneration corrects, so `pi-agent-environment`'s `Discharged by (S)` column stays empty pending that audit.
Six `pi-agent-environment` requirements now name a concrete world assumption under `Under (W)`, the first non-empty `Under (W)` cells this projection has ever carried; this closes part of the gap the prior generation's own "Known limits" section named but does not by itself discharge any requirement, because `W ∧ S ⇒ R` still needs `S`.
The nine `world-assumptions` rows are self-attested: their own truth as claims about the world is not independently checked by anything in this corpus.
Guard level across every stratum-discipline capability (`skill-corpus-interface`, `requirements-stratification`, `satisfaction-argument-audit`, `stratified-change-authoring`) is `none`.
Nothing here is a guarantee about the system end to end.
