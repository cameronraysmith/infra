# Parity check for the committed rust-toolchain marker against the aeneas bundle.
#
# modules/nixpkgs/overlays/aeneas.nix seeds a slim host nightly from the
# committed ./rust-toolchain marker beside it, while the prebuilt charon-driver
# inside the release bundle is already linked against the librustc_driver of the
# channel recorded in the bundle's own top-level rust-toolchain. The two must
# name the same channel, or charon-driver resolves a librustc_driver it was not
# linked against.
#
# On darwin the mismatch builds successfully — the rpath edit and re-sign apply
# to whatever toolchain the marker names — and surfaces only at runtime as a
# dyld "Library not loaded: @rpath/librustc_driver-<hash>.dylib". buildbot
# builds x86_64-linux only, so the check runs on every system in the overlay's
# asset set to cover the darwin consumer, where the failure is silent.
#
# The comparison happens inside a derivation, unpacking the bundle's marker in a
# build rather than at eval time, because the repo avoids import-from-derivation.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.aeneas-toolchain-marker =
        pkgs.runCommand "aeneas-toolchain-marker"
          {
            inherit (pkgs.charon.passthru) bundle rustChannel;
          }
          ''
            set -euo pipefail

            tar tzf "$bundle" > entries.txt
            marker=$(awk '/^(\.\/)?rust-toolchain$/ { print; exit }' entries.txt)
            if [ -z "$marker" ]; then
              echo "aeneas-toolchain-marker: no top-level rust-toolchain in $bundle" >&2
              echo "The bundle layout changed; the version bump procedure at the top of" >&2
              echo "modules/nixpkgs/overlays/aeneas.nix needs revisiting." >&2
              exit 1
            fi

            tar xzOf "$bundle" "$marker" > bundle-marker.toml
            bundleChannel=$(awk -F'"' '/^[[:space:]]*channel[[:space:]]*=/ { print $2; exit }' bundle-marker.toml)
            if [ -z "$bundleChannel" ]; then
              echo "aeneas-toolchain-marker: no channel key in the bundle's $marker" >&2
              cat bundle-marker.toml >&2
              exit 1
            fi

            if [ "$bundleChannel" != "$rustChannel" ]; then
              echo "aeneas-toolchain-marker: rust-toolchain channel drift" >&2
              echo "  committed modules/nixpkgs/overlays/rust-toolchain: $rustChannel" >&2
              echo "  bundle $marker ($bundle): $bundleChannel" >&2
              echo >&2
              echo "The committed marker seeds the slim host toolchain supplying the" >&2
              echo "librustc_driver that the prebuilt charon-driver links against, so a" >&2
              echo "mismatch links the wrong library. On linux autoPatchelf fails the" >&2
              echo "build; on darwin the build succeeds and charon fails at runtime with" >&2
              echo "dyld: Library not loaded: @rpath/librustc_driver-<hash>.dylib" >&2
              echo >&2
              echo "Remediation: set channel = \"$bundleChannel\" in" >&2
              echo "modules/nixpkgs/overlays/rust-toolchain, then re-verify charon-driver's" >&2
              echo "rpath and re-signing wiring per the version bump procedure at the top of" >&2
              echo "modules/nixpkgs/overlays/aeneas.nix." >&2
              exit 1
            fi

            echo "$rustChannel" > $out
          '';
    };
}
