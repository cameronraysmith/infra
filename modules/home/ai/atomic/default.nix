# atomic, a terminal coding agent, as a member of the homeManager.ai aggregate.
#
# atomic ships no upstream home-manager, nixos, or darwin module, so this file
# declares options.programs.atomic itself.
#
# The package is this repository's own pkgs/by-name/atomic rather than a flake
# input, so lib.mkPackageOption resolves it: modules/nixpkgs/compose.nix merges
# the perSystem packages set into flake.overlays.default, which
# modules/nixpkgs/base-defaults.nix wires into every machine's nixpkgs.overlays.
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
