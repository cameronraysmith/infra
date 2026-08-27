## MODIFIED Requirements

### Requirement: The install path is recorded in the repository, and is written to be re-runnable without being shown to be

A bare-metal install path SHALL be recorded in the repository as a runnable artifact, not performed ad hoc.
It targets a stock NixOS installer ISO booted on the machine with sshd reachable.
It SHALL be written so that running it a second time destroys and recreates rather than reusing what an earlier run left behind.
D29 drops the second proving install, so the path is executed exactly once here: re-runnability is a property of the recorded text and not a claim discharged by evidence, and a later reader MUST NOT treat it as established when planning a reinstall of this machine or an install of a sibling MacBook.
What the change does establish about surviving artifacts is narrower and is recorded in the create-path requirement below: the surviving-pool arm is live on this disk and is checked, while the three surviving-LUKS-header arms are recorded as properties of the layout for a future reinstall rather than as acceptance criteria.
It SHALL discard the disk explicitly, at every offset rather than only at the partition table, before invoking `clan machines install`.

#### Scenario: the wipe is blkdiscard, because zapping the GPT first disables disko's own pool destroy

- **WHEN** the recorded path wipes the disk on the installer before invoking `clan machines install`
- **THEN** it uses `blkdiscard -f` against the namespace-explicit `_1` path, adapting the form clan-core's own encrypted-root guide prescribes at `docs/src/guides/disk-encryption.md:84-88`, which is a bare `blkdiscard` with no flag
- **AND** the `-f` is required rather than optional against this disk: bare `blkdiscard` refuses a device carrying a partition table with "contains existing partition (gpt) ... Use the -f option to override" and discards nothing, while `blkdiscard -f` prints "Operation forced, data will be lost!" and proceeds — both observed on the console of the run this change performed
- **AND** it MUST NOT use `sgdisk --zap-all` or `wipefs -a` on the whole disk for this purpose, and the ground is restated under LUKS rather than carried over: with the pool inside a LUKS2 container, p2's `fstype` is `crypto_LUKS`, not `zfs_member`, so disko's `disk-deactivate/disk-deactivate.jq` `remove` falls through to `[]` at `:26-27` and the `zpool destroy -f` / `zpool labelclear -f` branch at `:7-9` is unreachable for p2 by type rather than by absence of children
- **AND** what runs against p2 instead is `deactivate`'s partition arm at `:42-45`, a bare `wipefs --all -f`, which erases the primary LUKS2 signature while the secondary header and the whole default 16 MiB keyslot area are left in place, so the old keyslots — the clan-vars passphrase and the enrolled FIDO2 credential — survive a wipe an operator would read as complete
- **AND** a disk whose partition table was zapped first is worse still, because `:71-78` enumerates the nodes `deactivate` visits as children reported by `lsblk`, so with no partition table there are no children, the p2 arm never runs at all, and the whole-disk `wipefs` at `:38` and `dd bs=440` at `:40` touch only disk offsets — after which disko recreates its deterministic layout, p2 reappears at the same offset with its header intact, `lib/types/luks.nix:202`'s `if ! blkid "$dev" || ! cryptsetup isLuks "$dev"` guard finds a valid container and skips `luksFormat`, and `:275-276`'s `if ! systemd-cryptenroll "$dev" | grep -qw fido2` finds the surviving enrollment and skips that too, so the install reuses the old container under the old credentials, which is p…
- **AND** if `blkdiscard` is unavailable, the fallback order is `zpool labelclear -f <device>-part2`, then `zpool import` confirming that no `zroot` is listed, then `cryptsetup luksErase --batch-mode <device>-part2`, then `dd if=/dev/zero of=<device>-part2 bs=1M count=32`, then `sgdisk --zap-all`, then `wipefs -a`, in that order — `labelclear` first because it is the only step reaching the tail of the partition, `zpool import` immediately after it because once `sgdisk --zap-all` has run there is no `-part2` node left to read, `luksErase` next because it needs a header that still probes and every step below it destroys the magic, the 32 MiB overwrite next because it covers both LUKS2 headers and the whole default 16 MiB keyslot area rather than the primary si…
- **AND** `zpool labelclear -f <device>-part2` is retained as the first step rather than removed, because the block serves two disk states and each of its first two steps is the live arm in one of them: p2 now carries the LUKS2 container the aborted 2026-07-30 attempt created, so `luksErase` is the live arm, while on a disk in the other state — a pre-D1 `zroot` with no header — the arms swap and `luksErase` reports that the device is not a valid LUKS device. `labelclear` is retained regardless, because whether any of the pre-D1 pool's tail labels survived that reformat has not been established and it is the only arm that would reach them
- **AND** the ZFS-labels-are-unreachable-under-LUKS ground on which an earlier revision of this requirement dropped `labelclear` is therefore true only of the reinstall state and false of the state this LUKS install meets, and dropping the step would leave the tail labels L2 and L3 in the last 512 KiB of the partition for a subsequent `zpool import -N -f "zroot"` at disko's `lib/types/zpool.nix:298` to find, producing the surviving-pool skip the create-path requirement below forbids
- **AND** running both steps in either state is safe, because `zpool_clear_label` (`lib/libzfs/libzfs_import.c:136-221`) reads each of the four label slots and skips any whose embedded nvlist fails to unpack, yields no valid `ZPOOL_CONFIG_GUID`, or yields a `ZPOOL_CONFIG_POOL_STATE` above `POOL_STATE_L2CACHE` (`:167-179`), so against a LUKS-bearing p2 it writes nothing and cannot pre-empt the `luksErase` below it

#### Scenario: the wipe is retained even though the default disko mode already destroys

- **WHEN** `clan_lib/machines/install.py` passes no `--disko-mode` — zero hits across clan-core at rev `d332b69` — so `src/nixos-anywhere.sh:419` sets `diskoMode=disko`, `:422` forms `diskoAttr="${diskoMode}Script"`, and disko's `lib/default.nix:889-894` `diskoScript` runs `_disko`, which `lib/default.nix:1094-1098` composes as `_legacyDestroy` then `_create` then `_mount`
- **THEN** the wipe is belt-and-braces on the happy path rather than load-bearing, and it is retained anyway
- **AND** it is retained because `_legacyDestroy` runs without `set -e`, so a destroy that fails silently falls through to `_create`, where `lib/types/gpt.nix:282-284` skips `sgdisk --clear` on a surviving Apple GPT because `blkid` succeeds, the subsequent `sgdisk --new` calls re-typecode Apple's partitions in place, `lib/types/filesystem.nix:54-58` skips `mkfs.vfat` on an ESP already reporting a `TYPE=`, and the machine boots Apple's 300 MiB ESP rather than the declared layout
- **AND** it is retained because the explicit wipe is the only step whose success the operator can independently observe before committing to an irreversible install

#### Scenario: the recorded path replaces the terranix invocation that does not apply

- **WHEN** `modules/terranix/{hetzner,gcp}.nix` hold the repository's only recorded `clan machines install` invocation, as a cloud-only `null_resource` local-exec, and no justfile recipe or other invocation site exists
- **THEN** pyrite gains its own recorded invocation carrying the target host, the identity file, and the no-facter-regeneration specifics, because without one the machine ships as a one-off manual install

#### Scenario: pyrite needs no terranix entry

- **WHEN** the machine has no cloud resource to provision
- **THEN** no terranix entry is added, because nothing in the clan inventory or any flake check reads one, and three existing NixOS machines already evaluate and check clean with `enabled = false` entries whose resources do not exist

#### Scenario: install-time ssh access is reconstituted by hand

- **WHEN** terranix would otherwise mint a deploy keypair, register the public half with the cloud provider, and enable root login via cloud-init
- **THEN** the recorded path instead authorizes a key against the booted installer session by hand, and documents that this authorization does not survive rebooting the installer

#### Scenario: clan subcommands that fight the nix-declared inventory are skipped

- **WHEN** the upstream physical-machine guide directs `clan init`, `clan machines create`, and `clan templates apply disk`
- **THEN** all three are skipped, because the first two write through `InventoryStore` against this repository's nix-declared inventory and the third writes `machines/pyrite/disko.nix`, which clan-core would auto-import alongside this repository's own disko module

---

### Requirement: An install is accepted as evidence only if it exercised the create path

The install SHALL be verified to have exercised the create path rather than reused what was on the disk, and the verification SHALL be made from inside the run rather than by comparison with a later one.
`zpool history zroot` MUST open with a `zpool create` entry timestamped inside the install session, and `zpool get -H -o value guid zroot` MUST differ from the pool GUID recorded before the wipe.
A run that reused a surviving pool MUST NOT be accepted as evidence, whatever else it reports.
No second install is performed to establish this: the ISO-boot-to-installed-machine path was demonstrated by the install of 2026-07-19, and re-proving it would cost another irreversible destroy-and-recreate cycle while establishing nothing new.
That install ran the pre-D1 ZFS-native layout, so it is evidence for the ISO-boot-to-installed-machine path and for nothing about the LUKS2 container, the FIDO2 enrollment, or `additionalKeyFiles` (D29).
This LUKS install is therefore the first exercise of the create path on this machine, not a repeat of one, and it runs on a machine with no fallback operating system.

#### Scenario: a run that reuses what is on the disk proves nothing

- **WHEN** disko's `lib/types/zpool.nix:298` reuses a pool that already imports, logging "not creating zpool as a pool with that name already exists", `lib/types/zfs_fs.nix:94`'s `zfs get type` probe skips creation of datasets that already exist, and — on any disk carrying a LUKS header — `lib/types/luks.nix:202`'s `if ! blkid "$dev" || ! cryptsetup isLuks "$dev"` skips `luksFormat`, `:275-276`'s `if ! systemd-cryptenroll "$dev" | grep -qw fido2` skips the FIDO2 enrollment, and `:257-258`'s `cryptsetup open --test-passphrase` adds no key
- **THEN** the run re-applies neither the container's format nor any of its keyslots nor `ashift` nor any create-time dataset property, so it goes green having exercised no create path at all
- **AND** such a run is NOT accepted, because the criterion would be satisfied tautologically
- **AND** the pool arm is the one live on this machine, because the disk carries a pre-D1 `zroot` whose ZFS labels a `blkdiscard` that did not reach the media would leave in place
- **AND** the surviving-header arm is live rather than hypothetical, because the aborted attempt of 2026-07-30 left a valid LUKS2 container on p2: `lib/types/luks.nix:202`'s `if ! blkid "$dev" || ! cryptsetup isLuks "$dev"` now evaluates false against it, so `luksFormat` would be skipped and the run would reuse the old container under the old passphrase. Closing the mapping and discarding the media before the install, and confirming `cryptsetup isLuks` returns non-zero afterward, is what forecloses it
- **AND** the FIDO2 skip arm at `:275-276` is unreachable from this configuration under D30 for an independent reason — the block is `lib.optionalString config.enrollFido2`-gated and is not emitted — so it is recorded as a property of the layout for any future run that re-enables enrollment rather than as an acceptance criterion here

#### Scenario: the wipe precedes the install so the create path runs

- **WHEN** the recorded path is executed
- **THEN** the disk is wiped as its first step, per the wipe requirement above, so the install formats a new LUKS container and creates the pool and datasets from scratch
- **AND** the pool GUID is recorded before the wipe, from `zpool import`'s listing on the installer, because after the wipe there is nothing left to read a baseline from
- **AND** the checks after the install confirm that `zpool history zroot` opens with a create entry inside the session, that the pool GUID differs from that baseline, that `cryptsetup luksDump <device>-part2` shows **no** `systemd-fido2` token and a keyslot set holding only the clan-vars passphrase, and that `zpool get ashift zroot` returns `12`, since those are the properties a skipped create path would silently leave unverified
- **AND** the token criterion is stated as zero rather than one because `enrollFido2 = false` (D30): no throwaway `openssl rand` key is minted, `SLOT_ZERO_TO_DELETE` is never exported, and no `--wipe-slot=0` runs, so the passphrase occupies slot 0 directly and a `fido2` row at this point would mean a pre-existing enrollment survived the wipe
- **AND** either one or two `password` rows is accepted, because a trailing newline in the materialized `/run/partitioning-secrets/zfs/key` would fail the `cryptsetup open --test-passphrase --key-file=<path>` guard at `lib/types/luks.nix:258` and re-activate the `luksAddKey` at `:259`, yielding a stripped slot 0 and a raw slot 1; recovery and non-interactivity hold in both layouts and only the slot numbering differs, so the layout observed is recorded rather than required
- **AND** `cryptsetup luksUUID <device>-part2` is recorded both as the container's identity for the header-backup filename and as a discriminator, and the ground an earlier revision gave for it being only the former — that no earlier UUID exists on this disk to differ from — is false: the aborted attempt of 2026-07-30 left a valid LUKS2 container on p2, so a pre-wipe UUID exists, is recorded before the wipe, and an equal value afterward means `luksFormat` was skipped at `lib/types/luks.nix:202` against the surviving header
- **AND** both tokens' enrollments and the LUKS2 header backup are created against this container afterward, because disko enrolls no token under D30 and no header backup can predate the container or usefully predate the keyslot set it freezes
- **AND** no crypttab `fido2-device=auto` option joins them, because token unlock works against the enrolled header with `crypttabExtraOpts` unset; see the boot-time-unlock scenario in `encrypted-zfs-root`

---

### Requirement: Network association is declarative, and the credentials are sops-encrypted clan vars

pyrite SHALL associate with the fleet's wireless network through clan-core's wifi clanService, instanced in `modules/clan/inventory/services/wifi.nix` and targeting `roles.default.machines."pyrite"`, so that the machine associates with no operator typing credentials into the installed system.
That network's SSID and PSK SHALL be clan vars, sops-encrypted and committed, and MUST NOT be entered interactively on the machine nor stored only in its `/var/lib`.
Neither value may appear as plaintext in this repository or in a world-readable store path; the SSID is a var for the same reason the PSK is, since the NetworkManager profile the service emits is world-readable.
The credentials are shared clan vars — `clanServices/wifi/default.nix:88` sets `share = true` on the per-network generator carrying both prompts, and `roles.default.interface` exposes no setting through which an instance declines it — so both land under `vars/shared/wifi.<name>/` rather than `vars/per-machine/pyrite/`, which is the intent here, since the network exists to serve the fleet.
Which network the `fleet` identifier denotes, and the origination reasoning that the choice of the pre-existing household network supersedes, are settled in design.md's D14 and are recorded there rather than imposed here.
The first and third scenarios below are decidable by `nix eval` against the built configuration; the second, fourth, and fifth are observed at install and first boot.

#### Scenario: the built configuration carries NetworkManager and the declared profile

- **WHEN** `nix eval .#nixosConfigurations.pyrite.config.networking.networkmanager.enable` is evaluated
- **THEN** it returns `true`, which `clanServices/wifi/default.nix:96` sets unconditionally — not as a `mkDefault` — inside the `lib.mkIf (settings.networks != {})` opened at `:92`, making pyrite the fleet's first NetworkManager host
- **AND** `nix eval --json .#nixosConfigurations.pyrite.config.networking.networkmanager.ensureProfiles.profiles --apply builtins.attrNames` returns the declared network's identifier, and `networking.useDHCP` evaluates to `false`, forced by `nixos/modules/services/networking/networkmanager.nix:690`

#### Scenario: the credentials survive the wipe because they are repository state

- **WHEN** the recorded install path runs from a fresh ISO boot and its `blkdiscard` first step destroys `/var/lib` along with the rest of the disk
- **THEN** the SSID and the PSK are unaffected, because they are sops-encrypted clan vars in the repository rather than state on the machine
- **AND** the installed machine associates with no operator entering credentials, which is what makes the post-install association check an observation that can fail rather than a step that produces its own result

#### Scenario: the zerotier unmanaged rule is already correct and nothing is added for it

- **WHEN** `nix eval --json .#nixosConfigurations.pyrite.config.networking.networkmanager.unmanaged` is evaluated
- **THEN** it contains `interface-name:zt*`, which `clanServices/zerotier/default.nix:461` sets unconditionally and which has been inert fleet-wide because no machine enabled NetworkManager
- **AND** the pyrite configuration declares no additional `unmanaged` entry, because zerotier's `systemd.network.networks."09-zerotier"` (`:450-457`) means networkd is intended to own `zt*` and the existing entry is what keeps NetworkManager off it

#### Scenario: the association is declarative, from committed vars, with nothing typed into the installed system

- **WHEN** the installed machine is cold-booted and its wireless state is inspected
- **THEN** the active connection is the fleet network on `wlp2s0`, reached unattended across the boot, with no operator having entered an SSID or a PSK into the installed system at any point
- **AND** the profile backing it is `/var/run/NetworkManager/system-connections/fleet.nmconnection` — the path `ensureProfiles` writes, under `/run` — so the profile came from the built configuration rather than from the machine
- **AND** `/etc/NetworkManager/system-connections/` is empty, which is what separates a declared profile from one an operator added by hand through `nmcli` after the fact
- **AND** the SSID and PSK it interpolates come from the sops-encrypted `wifi.fleet` generator's files under `vars/shared/`, per the `shared` path fragment `clan_lib/vars/_types.py:41-49` returns, so neither value exists as plaintext in the repository or in the world-readable store path holding the profile

#### Scenario: unattended association depends on the router serving the SSID and the vars existing before the deploy

- **WHEN** the fleet SSID is broadcasting with the PSK the router serves, and `clan vars generate pyrite` has run against those values and its output has been committed before `clan machines install`
- **THEN** the machine associates unattended at first boot, because `autoConnect` defaults true (`clanServices/wifi/default.nix:30-33`) and lands as `connection.autoconnect` in the profile (`:107`)
- **AND** if the vars do not exist the profile interpolates empty strings and association fails silently, because no assertion and no eval-time error guards the condition
- **AND** if the SSID recorded in the var is not the one the router serves the interface never associates, which is equally unguarded, because the SSID reaches the var through a prompt the operator types and nothing compares it against the network
