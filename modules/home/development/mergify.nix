# The Mergify CLI, as a member of the homeManager.development aggregate.
#
# Upstream ships no home-manager, nixos, or darwin module, so this file declares
# options.programs.mergify itself and owns the package: nothing installs
# mergify from a shared package aggregate.
{ ... }:
{
  flake.modules.homeManager.development =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.programs.mergify;
    in
    {
      options.programs.mergify = {
        enable = lib.mkEnableOption "the Mergify CLI, whose `mergify stack` subcommand drives stacked-pull-request landing";

        package = lib.mkPackageOption pkgs "mergify-cli-bin" { };
      };

      config = {
        # Self-enabling, matching gh: every development user gets it. mkDefault
        # so a machine or user module can disable it without a definition
        # collision.
        programs.mergify.enable = lib.mkDefault true;

        home.packages = lib.mkIf cfg.enable [ cfg.package ];

        # No configuration file is managed: every API-touching command resolves
        # its credential from MERGIFY_TOKEN, GITHUB_TOKEN, or a per-command
        # --token, so there is no non-secret settings surface to render.
      };
    };
}
