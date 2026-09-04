# Flake app: activate a home-manager profile from a flake reference, seeding the
# age key that decrypts its sops secrets where that key exists. No checkout of
# this repository is required.
#
# The two modes are split by coeffect. Activation itself needs only network and
# the binary cache; installing secrets additionally needs the age key, and
# base-sops skips that step when the key file is absent. An image or snapshot
# build has the first resource and not the second, so it runs --without-secrets
# and the image carries the generation but nothing decrypted. A session start has
# both, so it runs the default mode, which seeds the key and reactivates over a
# store the earlier activation already warmed.
#
# This is an app rather than a home-manager activation script or a shell-profile
# hook because it must run before any home-manager generation exists: the key it
# writes is what lets sops-nix decrypt the profile's secrets during the very
# activation it then performs. A home-manager-generated hook that re-enters
# activation is a fixpoint with no fixed point on first run.
#
# One-shot: no stamp file, no retry loop, no backgrounding. Idempotent, so a
# warm-start path can re-run it to pick up a rotated secret and a newer commit.
{ ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    {
      apps.home-bootstrap = {
        type = "app";
        program = lib.getExe (
          pkgs.writeShellApplication {
            name = "home-bootstrap";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.gnused
              # The seed step is shared with the ubuntu profile's session hook so
              # that both normalize a rotated key the same way.
              pkgs.seed-age-key
              # `nix` is in runtimeInputs for the same reason as bootstrap.nix:
              # the activation step shells out to `nix run <flake>#home`, and the
              # hermetic PATH would otherwise not carry a nix client. Both modes
              # reach it.
              pkgs.nix
            ];
            meta.description = "Activate a home-manager profile from a flake ref, seeding its age key from SOPS_AGE_KEY where one exists";
            text = builtins.readFile ./home-bootstrap.sh;
          }
        );
      };
    };
}
