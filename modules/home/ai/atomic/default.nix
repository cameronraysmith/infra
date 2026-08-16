# atomic, a terminal coding agent, as a member of the homeManager.ai aggregate.
#
# atomic ships no upstream home-manager, nixos, or darwin module, so this file
# declares options.programs.atomic itself, following tuicr rather than hunk.
#
# Unlike tuicr, whose package comes from the llm-agents input, atomic is
# packaged in this repository at pkgs/by-name/atomic. Those derivations reach
# machine and home-manager `pkgs` through flake.overlays.default, which merges
# the perSystem packages set into the overlay chain
# (modules/nixpkgs/compose.nix), so lib.mkPackageOption resolves the local
# derivation and no input accessor is needed.
#
# Self-enabling, matching tuicr and hunk: every ai user gets it. The enable
# flag is defined with lib.mkDefault so a machine or user module can disable
# the program without a definition collision.
#
# No configuration surface is declared. The wrapper in
# pkgs/by-name/atomic/package.nix already supplies the runtime tool lookups and
# suppresses the update check, and that package's tests.help exercises the
# finished store path against nothing but a writable $HOME.
{ ... }:
{
  flake.modules.homeManager.ai =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.programs.atomic;
    in
    {
      options.programs.atomic = {
        enable = lib.mkEnableOption "atomic, a terminal coding agent with read, bash, edit, and write tools and session management";

        package = lib.mkPackageOption pkgs "atomic" { };
      };

      config = {
        programs.atomic.enable = lib.mkDefault true;

        home.packages = lib.mkIf cfg.enable [ cfg.package ];
      };
    };
}
