# Verification Report

> This file is produced by the `openspec-verify-change` skill after apply completes, to confirm that the
> implementation is consistent with the specs / design / tasks. Any failed check must be returned to its
> corresponding artifact for correction before re-running verify.

**Change**: `pyrite-baremetal-nixos`
**Verified at**: `2026-07-31`
**Verifier**: `Claude Code subagent (openspec-verify-change against the built configuration and the installed machine)`

---

## 1. Structural Validation (`openspec validate --strict`)

- [x] All items report valid

**Result**:

```text
$ openspec validate pyrite-baremetal-nixos --strict
Change 'pyrite-baremetal-nixos' is valid
exit=0
```

If any items fail, list their id and issues:

| Item | Type | Issues |
|---|---|---|
| — | — | — |

---

## 2. Task Completion (`tasks.md`)

- [x] Every remaining `- [ ]` is accounted for as something other than pending work

66 of 75 checkboxes are `- [x]`.
The nine that remain unchecked are not nine units of outstanding work, and distinguishing them is the substance of this section rather than a caveat to it.
tasks.md declares three markers in its opening register — `(retired)`, `(superseded)`, and `(non-goal)` — each of which keeps an unchecked box because the criterion the task carries was never discharged as written, and each of which means something different.
The three groups below are the whole of the remainder, and none of them names work the implementation still owes.

One task is retired.
Its acceptance criterion no longer applies to any run, and its reasoning was relocated rather than dropped.

Seven are superseded.
Each was written against a design or a mechanism that a later decision or a later on-hardware observation replaced, so each is unjudgeable as written rather than unsatisfied.
Every one carries an appended continuation stating what replaced it, and in each case the requirement the task was meant to implement is met by the implementation and verified in section 8.
The point is worth stating plainly because it is the one a reader is most likely to get wrong: a superseded task is stale text, not a missing capability.

One is declined by operator decision under an existing Non-Goal.

**Incomplete tasks**:

| Task | Reason incomplete | Blocks archive? |
|---|---|---|
| 7.2a | Retired. It gated the pre-wipe window on a seated FIDO2 token; D30 sets `enrollFido2 = false`, so the install performs no enrollment for a token to be present for. Its reasoning relocated to 7.12a, which guards each manual enrollment instead. | no |
| 7.2e | Superseded. Its post-`blkdiscard` criterion named `<device>-part2`, a node a whole-disk `blkdiscard` removes, so it cannot be issued where the task places it. The header-absence proposition was discharged instead by disko's own `isLuks`-then-`luksFormat` gate in the install log and by 7.4's UUID comparison. | no |
| 7.6 | Superseded. Its keyslot gate is not readable in the present tense: 7.12a's enrollments added two `systemd-fido2` tokens, so the clause reading a `fido2` row as a failure names a condition that can hold only before the first enrollment. The gate must be time-indexed to the install-to-first-enrollment window to be judged. Its remaining arms read back live and are cited in section 8. | no |
| 7.12b | Superseded. Its premise — that nothing but a hand-written `crypttabExtraOpts` line turns token unlock on — is falsified by the installed machine, which reaches the token through the libcryptsetup plugin path with `crypttabExtraOpts` evaluating to `[]`. The action half is therefore not performed and the option is deliberately not set; the verification half is complete in both directions. | no |
| 9.1 | Superseded. It named a single `disable-nvme-d3cold` unit scoped to one PCI address. A live test found the resume wedged with the Thunderbolt switch and the WiFi still at `d3cold_allowed = 1`, and the implementation is three units sweeping the whole PCI tree. `design.md:379` and the delta spec are reconciled to that form; the task text is not. | no |
| 9.2 | Superseded. It required panic-on-hung-task sysctls to be permanent. They are declined as false-positive-prone on ZFS scrubs and long nix builds, and `design.md:388` and the delta spec are both amended down to that decision. | no |
| 9.3 | Superseded. Two of its four eval checks are not issuable: the attribute it names does not exist under 9.1's supersession, and the panic setting lives in `boot.kernel.sysctl` rather than `boot.kernelParams`. The eval-side halves that do exist are verified in section 8. | no |
| 9.4 | Superseded. Its observable no longer discriminates: the sweep is wanted by the sleep units rather than by `multi-user.target`, so the attribute reads the kernel default on a booted-but-never-suspended machine and the guard makes any other reading impossible on one that has slept. | no |
| 9.6 | Declined by operator decision under an existing Non-Goal (`design.md:173`), which is scope rather than outstanding work. The lid handlers stay at `"lock"` while a warm reboot taken after a suspend still loses the Thunderbolt subtree; see section 9. | no |

---

## 3. Delta Spec Sync State

For each capability directory under `openspec/changes/pyrite-baremetal-nixos/specs/`, compare against
`openspec/specs/<capability>/spec.md`:

| Capability | Sync status | Notes |
|---|---|---|
| apple-laptop-hardware-support | pending sync | ADDED requirements; `openspec/specs/` does not exist in this repository yet. Deltas are synced at archive time by the lifecycle. |
| bare-metal-install-path | pending sync | ADDED requirements; no main spec yet. Synced at archive time. |
| encrypted-zfs-root | pending sync | ADDED requirements; no main spec yet. Synced at archive time. |
| graphical-desktop-session | pending sync | ADDED requirements; no main spec yet. Synced at archive time. |

> Verify runs before archive, so "pending sync" is the expected pre-archive state and is non-blocking.

---

## 4. Design / Specs Coherence Spot Check

Spot-check whether the decisions in `design.md` are reflected in the Requirements and Scenarios of
`specs/*.md`.
The requirement-to-implementation axis is separate and is section 8.

| Sampled item | design description | specs correspondence | Gap |
|---|---|---|---|
| D1 LUKS2 container under the ZFS pool | 100% partition carries `type = "luks"`, pool takes the `/dev/mapper` device, three keyslots, no ZFS native encryption | encrypted-zfs-root "The pool sits inside a LUKS2 container..." and "A sibling partition carries the ZFS content..." | none |
| D30 deferred FIDO2 enrollment | `enrollFido2 = false`; the install formats with the passphrase alone and both tokens are enrolled afterward on the booted machine | encrypted-zfs-root's format-credential scenario; bare-metal-install-path "A FIDO2 token is verified present before each enrollment" | none |
| D2 explicit `ashift = "12"` | 4096-byte sectors; the mapper reports its own geometry, so autodetect is more hazardous under LUKS rather than less | encrypted-zfs-root "The root is a ZFS pool created with an explicit ashift" | none |
| D3 namespace-explicit by-id path | the `_1` suffix names the 465.9 GiB namespace and `_2` is an 8 KiB sibling | encrypted-zfs-root "The pool device is named by a namespace-explicit by-id path" | none |
| D11 no plymouth | plymouth swaps the ask-password agent away from the verified console path | graphical-desktop-session "enabling GDM does not perturb the stage-1 unlock prompt" | none |
| D14 the `fleet` identifier | the internal identifier denotes the pre-existing household network; SSID and PSK are prompted shared vars | bare-metal-install-path "Network association is declarative, and the credentials are sops-encrypted clan vars" | none |
| D19 GNOME under GDM, niri deferred | stock GNOME is the desktop this change ships; niri lands as its own reversible follow-up | graphical-desktop-session's requirement text and `design.md:180`'s Non-Goal | none |
| D21 three sleep units | `disable-d3cold-all`, `nvme-d3cold-suspend-guard`, `disable-lid-wakeup`, with the profile's own endpoint-scoped block left dormant | apple-laptop-hardware-support "The sleep path is gated by three units the machine module defines itself" | none |
| D22 panic reboot through EFI pstore | nonzero `kernel.panic`, pstore and archival at nixpkgs defaults, the panic-on-hang knobs deliberately not permanent | apple-laptop-hardware-support "A panic that outlives the disk is recorded through EFI pstore" | none |
| D25/D26/D31 header and slot inventory | the slot index is recorded at enrollment, the header backup is stored off the machine as key material with no `age` layer, and it is re-taken after every enrollment change | encrypted-zfs-root "The LUKS header and the keyslot inventory are maintained artifacts" | none |
| D27 layout-stable delimiter and the newline trim | `xkcdpass --delimiter -` with `| tr -d "\n"`, because disko's two key paths disagree about the trailing byte | encrypted-zfs-root's generator scenarios | none |
| D29 no second proving install | the path is executed once; re-runnability is a property of the recorded text | bare-metal-install-path "written to be re-runnable without being shown to be" | none |

**Drift warnings** (non-blocking):

- Tasks 9.1 through 9.4 still describe the superseded single-unit and permanent-panic-sysctl forms in their checkbox lines, while `design.md:379` and `:388` and the delta spec have both been reconciled to what is implemented. The continuations state the supersession, so the drift is between a task's checkbox line and its own appended text rather than between design and specs. It is recorded here rather than repaired, since repairing it would mean rewriting acceptance criteria after the fact.
- The audio Non-Goal at `design.md:172` rests on a rationale that was subsequently found to be factually wrong. The Non-Goal itself stands for this change; audio is being taken up as its own change, where the rationale is corrected rather than carried forward. See section 9.

---

## 5. Implementation Signal

- [x] No unstaged implementation files in the worktree
- [ ] All related commits have been pushed

The implementation paths (`modules/machines/nixos/pyrite/`, `machines/pyrite/`) report clean, so the
configuration verified here is the committed one rather than a working-copy variant.
The only working-copy modifications at verify time are this file and the 7.12a checkbox in `tasks.md`,
which the orchestrator routes.

Two facts about deployment state are recorded so a later reader does not infer more than holds.
The machine's `/run/booted-system` is generation 1's toplevel, so pyrite has not rebooted since the
install and generations 2 and 3 were activated live; generation 3 is current.
The current tree evaluates to a toplevel that is not the one activated on the machine, which is the
ordinary state of a repository that has moved since its last deploy and is not a criterion of any
requirement here.

**Commit range** (if known): the change's jj chain; change ids are not enumerated by this step.

Pushed checkbox left unchecked: push is owned by the orchestrator and is not a verify precondition.

---

## 6. Front-Door Routing Leak Detector (warning, non-blocking)

Design output should not land in `docs/superpowers/specs/`.

Detect:

```bash
ls docs/superpowers/specs/*.md 2>/dev/null
```

- [x] No files

The directory does not exist and the glob matches nothing. No leak.

**Leak list** (if any):

| File | Content captured into change? | Recommended action |
|---|---|---|
| — | — | — |

---

## 7. Deferred Manual Dogfood vs Automated Test Equivalence

`plan.md` carries no rows marked `[~]`, which is a pass by the section's own rule.
One item is recorded anyway, because it is the same shape and a reader looking for it here should find it
rather than conclude nothing was deferred.

| Deferred item | Equivalent coverage | Coverage assessment | Real gap? |
|---|---|---|---|
| A second proving install, dropped by D29 — so the destroy-and-recreate path is executed exactly once and its re-runnability is not demonstrated | Task 3.11 ran disko's own `installTest` VM harness against pyrite's layout, exit 0 with eight of eight assertions, proving the container-on-mapper nesting, that the `additionalKeyFiles` slot opens the container, that stage 1 renders the prompt and the passphrase unlocks it, that `zpool import` finds `dm-name-cryptroot`, and `ashift=12`/`xattr=sa`/`acltype=posix`/`encryption=off` | Covers the layout and the passphrase unlock without a second irreversible cycle. It does not cover the FIDO2 path, which the harness forces off by construction, nor the `_1` namespace, the Apple ESP-by-type requirement, `blkdiscard`, the SPI keyboard, or the 4096-byte sector premise | no — the delta spec states re-runnability as a property of the recorded text rather than a discharged claim, so the single execution is compliance rather than a shortfall |

---

## 8. Requirement-by-Requirement Implementation Evidence

Every requirement in each of the four delta specs is listed with its verdict and the evidence.
Where a requirement was checkable at verify time it was checked rather than asserted: `nix eval` against
the built configuration, read-only inspection of the installed machine over the ZeroTier mesh, and
`openspec validate`.
Where it rests on an on-hardware observation the task that records it is cited.

### apple-laptop-hardware-support

| Requirement | Verdict | Evidence |
|---|---|---|
| The pyrite host module imports the upstream model profile with its unwanted firmware pulls disabled | satisfied | `flake.nix:86-87` declares `nixos-hardware` with `inputs.nixpkgs.follows = "nixpkgs"`; `modules/machines/nixos/pyrite/default.nix:23` imports `apple-macbook-pro-14-1`; `:163` and `:167` set both values as plain `false`. `nix eval` returns `networking.enableB43Firmware = false` and `hardware.facetimehd.enable = false` while the initrd module list still carries the profile's four SPI/SMC modules, so the plain definitions won at normal priority and the profile's contribution survives |
| The machine module states its firmware affirmations rather than inheriting them | satisfied | `default.nix:177-178`. `nix eval` returns `hardware.enableRedistributableFirmware = true` and `hardware.cpu.intel.updateMicrocode = true`, and `builtins.any` over `hardware.firmware.paths` matching `linux-firmware.*` returns `true`, so the blob the BCM4350 needs is in the closure |
| The stage-1 initrd force-loads the four SPI/SMC modules that make the unlock prompt answerable | satisfied | `nix eval --json ...boot.initrd.kernelModules` returns `["applesmc","applespi","dm_mod","i915","intel_lpss_pci","spi_pxa2xx_platform","virtio_net","virtio_pci","zfs"]`. On hardware, task 7.14 attributes the keystrokes answering the stage-1 queries to `Apple SPI Keyboard` at `input0`, on a boot where no USB device attached before the greeter |
| `boot.initrd.kernelModules` is never overridden with mkForce | satisfied | the same eval carries `base`'s `virtio_net`/`virtio_pci` pair alongside the profile's four and `i915`, which is the spec's own stated compliance criterion — a `mkForce` would have discarded every definition it did not name |
| A USB-C keyboard and the clan-vars passphrase are prerequisites of the first boot | satisfied | `docs/notes/development/hardware/pyrite-install-runbook.md:45-46` states the keyboard as a gate and records that the machine has no USB-A port, `:736-738` carries the udev-autoloading mechanism, and `:24-36` documents the empty-PIN keypress that reaches the passphrase prompt when no token is in hand |
| The machine's configuration is never seeded from nixos-generate-config | satisfied | `machines/pyrite/facter.json` is the only tracked file under `machines/pyrite/`, and no `machines/pyrite/hardware-configuration.nix` exists |
| The sleep path is gated by three units the machine module defines itself | satisfied | `default.nix:217`, `:246`, `:278`. `nix eval` over `systemd.services` returns the sweep `oneshot`, `before` and `wantedBy` `systemd-suspend.service`, `systemd-hybrid-sleep.service`, and `systemd-suspend-then-hibernate.service`; the guard `oneshot`, `after = ["disable-d3cold-all.service"]`, `before` and `requiredBy` those same three; and `disable-lid-wakeup` `oneshot` with `RemainAfterExit`, `wantedBy = ["multi-user.target"]` |
| Suspend is entered through the systemd-sleep path and resumes with the pool intact | satisfied | task 9.5 records three suspend and resume cycles in one boot with a journal spanning each suspended interval. Live, `/sys/power/mem_sleep` reports `s2idle [deep]`, so `deep` is the state exercised and it is recorded rather than averaged; `zpool status -x zroot` reports the pool healthy and `/dev/mapper/cryptroot` is open. `nix eval` returns the lid handlers at `"lock"`, `"lock"`, `"ignore"` and a `boot.kernelParams` carrying `i915.enable_psr=0`, `i915.enable_fbc=0`, `i915.enable_dc=0`, `nvme_core.default_ps_max_latency_us=0`, `nvme.noacpi=1`, and `pci=noaer`, with `i915.enable_guc=2` restored by hand and the kaby-lake module's `enable_fbc=1`/`enable_psr=2` pair absent |
| A panic that outlives the disk is recorded through EFI pstore | satisfied as scoped | `nix eval` returns `boot.kernel.sysctl."kernel.panic" = 20` with `hung_task_panic`, `softlockup_panic`, and `hardlockup_panic` all absent from the attrset, and `boot.kernelParams` carrying no panic setting. Live, `/sys/fs/pstore` is mounted and `systemd-pstore` is enabled. The requirement covers what the built configuration carries; a record actually written to EFI variables is a separate claim and an explicit Non-Goal |

### bare-metal-install-path

| Requirement | Verdict | Evidence |
|---|---|---|
| The install path is recorded in the repository, and is written to be re-runnable without being shown to be | satisfied | `pyrite-install-runbook.md` is a 1033-line recorded artifact carrying `blkdiscard -f` against the `_1` by-id path at `:461` and `clan machines install pyrite --target-host nixos@<installer-ip>` at `:491-492`, with `--update-hardware-config` left at its default and the `--phases disko` form forbidden at `:261` and `:276`. The requirement states that re-runnability is not demonstrated by this change, so a single execution is compliance |
| An install is accepted as evidence only if it exercised the create path | satisfied | live `zpool get guid zroot` returns `14433194292156182684` against the pre-wipe `14727267720509425254` recorded at task 7.2c; live `cryptsetup luksUUID` returns `a84e811f-c3a4-4e13-9a04-dacb547b1110` against a pre-wipe value beginning `aeea80c6`; task 7.4 records `zpool history zroot` opening with a create entry inside the install session; live `zpool get ashift` returns `12`. The zero-token half is qualified below the tables |
| The hardware report is committed as static data and never regenerated on the target | satisfied | `machines/pyrite/facter.json` is committed and git-tracked with no import line and no flake input, and the runbook leaves `--update-hardware-config` at `none` |
| The machine is registered across every hand-maintained list a new machine touches | satisfied | `modules/clan/machines.nix:24-25`; `modules/clan/inventory/machines.nix:64` and `:72` (`deploy.targetHost = "root@pyrite.zt"`); both hardcoded lists at `modules/checks/structure/flake-shape.nix:37` and `:52`; `modules/clan/inventory/services/users/cameron.nix:22`; the `&pyrite` anchor at `.sops.yaml:27` and the bridge rule at `:110`; `modules/machines/nixos/cinnabar/zt-dns.nix:53`; `modules/system/ssh-known-hosts.nix:66-72`; `modules/home/core/ssh.nix:107-110` |
| Network association is declarative, and the credentials are sops-encrypted clan vars | satisfied | `modules/clan/inventory/services/wifi.nix` instances the clan-core wifi service at `roles.default.machines."pyrite"` with `settings.networks.fleet`. `nix eval` returns `networking.networkmanager.enable = true`, `ensureProfiles.profiles` naming `fleet`, `networking.useDHCP = false`, and `unmanaged = ["interface-name:zt*"]`. Live, `wlp2s0` holds `192.168.50.122/24`, the active connection is `furtadosmith` on `wlp2s0`, and `/etc/NetworkManager/system-connections/` is empty, which is what separates a declared profile from a hand-added one. Task 7.16 obtained this unattended across a cold boot with the profile resolving to the `/var/run` `ensureProfiles` path |
| ZeroTier admission requires redeploying the controller | satisfied | the inventory entry carries the `peer` tag and `deploy.targetHost = "root@pyrite.zt"` and adds no `allowedIps`; task 5.6 records the cinnabar redeploy carrying a real payload with member `7e80678028` authorized at the controller; live `zerotierone` is active, and this verification reached the machine over `pyrite.zt` |
| A FIDO2 token is verified present before each enrollment, and disko's own guard is never that verification | satisfied | `disko.nix:101` sets `enrollFido2 = false`, and `logs/pyrite-install-20260730-215831.log` carries zero occurrences of `systemd-cryptenroll`, `wait_for_token`, or `hidraw`, so the install invoked no enrollment and required no seated token. Task 7.12a records `fido2-token -L` and `ykman fido info` run before each of the two manual enrollments, performed sequentially with the other token physically removed so `--fido2-device=auto` resolves unambiguously |

### encrypted-zfs-root

| Requirement | Verdict | Evidence |
|---|---|---|
| The root is a ZFS pool created with an explicit ashift matching the disk's 4096-byte sectors | satisfied | `disko.nix:124` sets `options.ashift = "12"` with the sector-size coupling recorded at `:116`; `:139-140` set `xattr = "sa"` and `acltype = "posixacl"`; `:136` records the `normalization` decline. The datasets `root`, `root/nixos`, `root/home`, and `root/nix` are declared at `/`, `/home`, and `/nix`. Live, `ashift` is `12`, `xattr` is `sa`, and `acltype` is `posix` |
| The ESP is typed EF00 and sized 1G | satisfied | `disko.nix:62` and `:68`, each carrying the comment the scenario requires; task 7.4 read the geometry back with `sgdisk -p` after the install, and `nix eval` returns `boot.loader.systemd-boot.enable = true` with `canTouchEfiVariables = true` |
| A sibling partition carries the ZFS content that becomes the pool's vdev | satisfied | `disko.nix:84` sets `size = "100%"`, `:86` the LUKS content, and `:106` the nested `type = "zfs"`. Live, `/dev/mapper/cryptroot` exists and `zroot` is healthy on it, which is the nesting the requirement turns on |
| The pool device is named by a namespace-explicit by-id path | satisfied | `disko.nix:57` names the `_1`-suffixed path with the `_2` namespace recorded in the comment; `nix eval` returns `boot.zfs.devNodes = "/dev/disk/by-id"` |
| The pool sits inside a LUKS2 container holding the clan-vars passphrase in slot 0 and a FIDO2 token in each of slots 1 and 2 | satisfied | live `systemd-cryptenroll` reports slot 0 `password`, slot 1 `fido2`, slot 2 `fido2`; `cryptsetup luksDump` reports LUKS2 with keyslot 0 under argon2id and keyslots 1 and 2 under pbkdf2, plus two `systemd-fido2` tokens that `cryptsetup token export` binds to keyslots 1 and 2 respectively. `disko.nix:89-90` set `allowDiscards` and `bypassWorkqueues`, `:101-102` set `enrollFido2` and `enrollRecovery` false, `:103-104` name the generator path in both `passwordFile` and `additionalKeyFiles`, and `:46` emits the passphrase with `| tr -d "\n"`. Live `zfs get encryption zroot/root` returns `off` and the layout carries no `postCreateHook`. `nix eval` returns `crypttabExtraOpts = []`, `networking.hostId = "8425e349"` inherited from clan-core, and `boot.zfs.forceImportRoot = true`. Both boot paths were exercised on hardware: token unlock with both tokens seated and with each token alone, and the passphrase reached through an empty PIN with no token seated (7.12b) |
| The costs and the gains of the LUKS layer are both recorded rather than discovered later | satisfied | `design.md:186-192` records the multi-keyslot model and the post-install enrollment property, the metadata-encryption gain, the unauthenticated `aes-xts-plain64` cost against ZFS's authenticated `aes-256-gcm`, and the header as a single point of failure with no ZFS-native counterpart |
| The LUKS header and the keyslot inventory are maintained artifacts, not install-time byproducts | satisfied | task 7.12a records the header backup taken after both enrollments, stored off the machine as key material on the `pyrite/zfs-root` entry, and the slot map recorded at enrollment. The runbook's key-lifecycle section carries capture at `:901`, restore at `:964`, the slot inventory at `:983`, and the re-take-and-revoke rule at `:1007`. The live header corroborates the slot structure; the serial-to-slot pairing rests on the operator's statement, which is what the spec's own scenario states it is, with the seat-one-token-and-test procedure recorded as the verification |

### graphical-desktop-session

| Requirement | Verdict | Evidence |
|---|---|---|
| The pyrite host provides a local GNOME desktop under GDM | satisfied | `default.nix:338-339`. `nix eval` returns `services.displayManager.gdm.enable` and `services.desktopManager.gnome.enable` both `true`, and the evals resolve at the post-rename paths, which is part of the check. No home-manager desktop module is added. `boot.plymouth.enable` returns `false`. Task 7.13 records a greeter rendered on the internal Retina panel and `cameron` reaching an interactive GNOME session with no restart-loop; task 7.14 records the stage-1 unlock and the greeter on one boot with the keystrokes attributed to the internal SPI keyboard. Live, `display-manager` is active. niri is excluded by the Non-Goal at `design.md:180` and nothing niri-related is present |

One evidentiary qualification, recorded rather than glossed.
The install-window criterion that the container held zero `systemd-fido2` tokens is established by
construction and by the install log rather than by a captured `luksDump`: `enrollFido2 = false` means
disko emits no enrollment block, and the install log carries zero occurrences of `systemd-cryptenroll`,
so no token could have been enrolled by the install.
The gate command itself ran between the pool import and the first enrollment but its stdout was not
captured, and the header now carries two tokens, so that reading is not recoverable in the present tense.
The inference is severe against the failure it exists to catch — a surviving pre-wipe enrollment — because
the container's `luksUUID` differs from the pre-wipe value, so the container in front of the operator is
the one this install created.

---

## 9. Residual Items, Known and Accepted

These are recorded because a reader who takes the verdict above without them would over-read it.
None of them is a spec requirement that went unmet; each is a known behaviour or an acknowledged absence.

A warm reboot taken after a suspend still loses the Thunderbolt and PCIe subtree, and `dmesg` carries
`Unable to change power state from D3cold to D0, device inaccessible` against `pcieport 0000:00:1c.4`
after each resume.
Suspend-and-resume working is a different claim from that one, and the delta spec states the distinction
explicitly rather than averaging them.
This is why 9.6 is declined: a lid close is the most common way to reach the suspend path, and moving the
handlers to `"suspend"` would put the residual failure on the ordinary path.
The decline is revisited when a suspend followed by a warm reboot leaves the subtree intact.

pyrite loses `wlp2s0` from the PCI bus across a warm reboot, and a full power cycle restores it.
This is distinct from the initrd `brcmfmac` defect task 7.16 fixed, which is resolved and verified
unattended across a cold boot.

Bluetooth is untracked.
It is diagnosed as a UART bring-up race, and there is no fix written, no task carrying it, and no
Non-Goal declining it.
It is named here so its absence from the artifact set is deliberate rather than an oversight a later
reader has to rediscover.

Audio is a Non-Goal of this change, and the rationale recorded for it at `design.md:172` was found to be
factually wrong.
The Non-Goal stands for this change — no audio work is in scope here — and audio is being taken up as its
own change, where the rationale is corrected rather than carried forward.

niri is deferred to its own successor change under D19 and is excluded by an explicit Non-Goal.
The desktop this change ships is stock GNOME under GDM, and that is what the delta spec requires.

---

## Overall Decision

- [ ] (pass) PASS — may proceed to finishing-a-development-branch and archive
- [x] (warn) PASS WITH WARNINGS — may proceed to subsequent steps but note the drift and residuals below
- [ ] (fail) FAIL — return to the failed artifact, correct it, then re-run verify

All 24 requirements across the four delta specs are satisfied, and no requirement is unmet.
The verdict rests on three kinds of evidence, and the mix is stated so its strength can be judged:
`nix eval` against the built configuration for every eval-decidable clause; read-only inspection of the
installed machine for the container's keyslots and tokens, the pool's properties and health, the network
association, and the running units; and the tasks that record on-hardware observations for the four
unlock paths, the three suspend cycles, the greeter, and the bare `clan machines update` over the mesh.
`openspec validate pyrite-baremetal-nixos --strict` exits 0 and the ledger stands at 66 of 75.

The warnings are the two drifts in section 4 and the residuals in section 9.
None of them is a shortfall against a requirement: the task-text drift is stale acceptance criteria whose
own continuations record the supersession, the audio Non-Goal's wrong rationale is being corrected in the
change that takes audio up, and the residuals are behaviours the delta specs either name explicitly or
leave out of scope by an existing Non-Goal.
The nine unchecked boxes are one retirement, seven supersessions, and one operator decision, and none of
them is outstanding work.

**Next step**:

Proceed to write `retrospective.md`, then run `openspec archive`, which syncs the four delta-spec
capabilities and resolves the section-3 pending state.
The verify-phase working-copy edits — this file and the 7.12a checkbox — are sealed by the orchestrator on
the change's jj chain.
