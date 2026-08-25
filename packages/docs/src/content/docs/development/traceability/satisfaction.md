---
title: Satisfaction argument
description: Discharge status for every requirement in the OpenSpec corpus
generated: 2026-08-25
---

# Satisfaction argument

This file is a projection over `openspec/specs/`, regenerated wholesale at archive time and never patched.
A patched discharge table accumulates exactly the staleness the artifact exists to prevent, so any edit here is lost on the next regeneration.

It records, per requirement, which specification properties and which world assumptions discharge it — the `W ∧ S ⇒ R` obligation.
An undischarged requirement is recorded as such rather than omitted.

## Status

- 68 requirements across 9 capabilities.
- 9 discharged against artifacts observable at the machine interface.
- 10 partially discharged: delivery established, content correctness not.
- 49 undischarged.

No `world-assumptions` capability exists, so **no requirement anywhere in this corpus names a discharging world assumption**.
Every row's `Under (W)` column is therefore empty, which is the single largest gap in this argument and is why no requirement below is fully discharged.
Extracting the indicative assumptions currently embedded as justification prose in `pi-agent-environment` is the first step toward closing it.

Of the 68 requirements, 19 were authored under the stratum discipline and 49 predate it; the latter are shown at their inferred stratum and have not been re-audited.

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

Predates the stratum discipline; not yet audited against it.

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
| Permission-gate reuse | behavioral | — | — | undischarged |
| Additional shell policy | behavioral | — | — | undischarged |
| Non-Bash edit and write policy | behavioral | — | — | undischarged |
| Git default-branch boundary | behavioral | — | — | undischarged |
| Jj diamond boundary | behavioral | — | — | undischarged |
| Fail-open policy | behavioral | — | — | undischarged |
| Secret-safe direnv | behavioral | — | — | undischarged |
| Opt-in slow mode | behavioral | — | — | undischarged |
| Consolidated custom regulators | behavioral | — | — | undischarged |
| Offline aggregate smoke | behavioral | — | — | undischarged |
| Stale Pi version cleanup | behavioral | — | — | undischarged |
| Human-only activation | behavioral | — | — | undischarged |
| Confirmation-gated live verification | behavioral | — | — | undischarged |
| Rollback preservation | behavioral | — | — | undischarged |

## requirements-stratification

skill-corpus-interface establishes that the guidance reaches an agent, not that it is applied correctly.

| Requirement | Stratum | Discharged by (S) | Under (W) | Status |
|---|---|---|---|---|
| Stratum assignment for any requirement-like statement | behavioral | skill-corpus-interface: resolvability, trigger surface | — | partially discharged |
| Grounding of terms used in requirements | behavioral | skill-corpus-interface: resolvability, trigger surface | — | partially discharged |
| Separation of what is assumed from what is wanted | behavioral | skill-corpus-interface: resolvability, trigger surface | — | partially discharged |
| Discharge of a requirement is stated, not implied | behavioral | skill-corpus-interface: resolvability, trigger surface | — | partially discharged |
| Obstacle analysis produces the boundary and open questions | behavioral | skill-corpus-interface: resolvability, trigger surface | — | partially discharged |

## satisfaction-argument-audit

skill-corpus-interface establishes that the guidance reaches an agent, not that it is applied correctly.

| Requirement | Stratum | Discharged by (S) | Under (W) | Status |
|---|---|---|---|---|
| Specification is checked against intent independently | behavioral | skill-corpus-interface: resolvability, trigger surface | — | partially discharged |
| Everything the argument depends on unverified is enumerated | behavioral | skill-corpus-interface: resolvability, trigger surface | — | partially discharged |
| Agreement between two artifacts is not treated as confirmation | behavioral | skill-corpus-interface: resolvability, trigger surface | — | partially discharged |
| External claims are bounded by what was actually established | behavioral | skill-corpus-interface: resolvability, trigger surface | — | partially discharged |
| The audit runs at a boundary, not continuously | behavioral | skill-corpus-interface: resolvability, trigger surface | — | partially discharged |

## skill-corpus-interface

Interface stratum: discharged directly against delivered build and activation artifacts.

| Requirement | Stratum | Discharged by (S) | Under (W) | Status |
|---|---|---|---|---|
| A named skill is resolvable in the delivered corpus | interface | own interface properties | — | discharged (S only) |
| A skill's trigger surface admits the situations it must fire on | interface | own interface properties | — | discharged (S only) |
| Stated ownership boundaries hold across the corpus | interface | own interface properties | — | discharged (S only) |

## stratified-change-authoring

Interface stratum: discharged directly against the schema and config artifacts it constrains.

| Requirement | Stratum | Discharged by (S) | Under (W) | Status |
|---|---|---|---|---|
| Proposal artifact records a stratum tag per capability | interface | own interface properties | — | discharged (S only) |
| Specs artifact applies stratum-conditional vocabulary rules | interface | own interface properties | — | discharged (S only) |
| Verify artifact runs non-blocking stratum checks | interface | own interface properties | — | discharged (S only) |
| Archive step regenerates the satisfaction projection | interface | own interface properties | — | discharged (S only) |
| Tasks artifact records per-task verification | interface | own interface properties | — | discharged (S only) |
| The stratum layer states its own trust boundary | interface | own interface properties | — | discharged (S only) |

## Known limits of this argument

Every `Under (W)` cell is empty, so no row constitutes a complete satisfaction argument in the `W ∧ S ⇒ R` sense; the rows record what is established about `S` alone.
The partially-discharged rows rest on `skill-corpus-interface`, whose own trust boundary explicitly disclaims reaching content correctness, so they establish that guidance is delivered rather than that it is right.
No automated check guards any row: the guard level across this corpus is `none` for the four capabilities authored under the stratum discipline.
Nothing here is a guarantee about the system end to end.
