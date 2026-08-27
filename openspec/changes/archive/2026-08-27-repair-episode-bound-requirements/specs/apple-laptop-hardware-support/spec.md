## MODIFIED Requirements

### Requirement: The stage-1 initrd force-loads the four SPI/SMC modules that make the unlock prompt answerable

The initrd SHALL force-load `applespi`, `spi_pxa2xx_platform`, `intel_lpss_pci`, and `applesmc` via `boot.initrd.kernelModules`, which the imported profile supplies at `apple/macbook-pro/14-1/default.nix:19-24`.
The facter report MUST NOT be relied upon for these, and the fleet's `base` module MUST NOT be relied upon for these.
The dependency is at least as strong under a LUKS container as it was under a typed ZFS passphrase, across the pre-enrollment and post-enrollment credential states.
Between the install and the enrollment of a token (D30), every boot is the committed clan-vars passphrase typed on this keyboard and there is no other credential.
After both tokens are enrolled, every boot is a FIDO2 client PIN typed on this keyboard followed by a touch, because both tokens carry a client PIN and `systemd-cryptenroll` defaults to `--fido2-with-client-pin=yes`, with the passphrase as the fallback typed on the same keyboard.
The fallback is reached by pressing Enter on an empty PIN at the token prompt, which is itself a keypress on this keyboard, so no credential path on this machine avoids it.
The requirement is decidable by `nix eval` of `.#nixosConfigurations.pyrite.config.boot.initrd.kernelModules` against the built configuration and does not require the hardware.

#### Scenario: the profile supplies the modules that base does not

- **WHEN** `modules/system/initrd-networking.nix:33-37` contributes only `virtio_pci` and `virtio_net` to `boot.initrd.kernelModules` for every NixOS machine
- **THEN** the SPI modules arrive from the imported profile instead, which sets `boot.initrd.kernelModules` — the option that force-loads — rather than `availableKernelModules`, which only makes a module present
- **AND** a two-way evaluation carrying the facter report and differing only by the import gives `["dm_mod" "i915"]` without the profile and `["applesmc" "applespi" "dm_mod" "i915" "intel_lpss_pci" "spi_pxa2xx_platform"]` with it, so all four are the profile's marginal contribution and none is supplied elsewhere

#### Scenario: facter supplies no SPI keyboard modules

- **WHEN** the committed facter report is evaluated
- **THEN** it contributes no `applespi` or `intel_lpss` initrd modules, because `nixos/modules/hardware/facter/keyboard.nix` sources initrd keyboard modules from the USB controller report only and the keyboard on this machine is SPI-attached
