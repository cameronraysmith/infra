# Settings shared by the pi-lineage agents in the homeManager.ai aggregate.
#
# atomic reads ~/.pi/agent as a legacy config root, but only while its own root
# is empty: a populated ~/.atomic/agent/settings.json overrides the pi one
# rather than merging with it, so every key atomic is meant to honour has to be
# written into atomic's own file. Holding the values here rather than in either
# consumer is what stops the two files drifting the way they already did once,
# when atomic's first-run wizard copied a snapshot of this package set across
# and then froze it with theme "dark" against the declared catppuccin-mocha.
{ ... }:
{
  flake.modules.homeManager.ai =
    {
      pkgs,
      lib,
      ...
    }:
    let
      jsonFormat = pkgs.formats.json { };
    in
    {
      options.aiAgentSettings = {
        theme = lib.mkOption {
          type = lib.types.str;
          default = "catppuccin-mocha";
          description = "Theme name written into every pi-lineage agent's settings.json. pi loads it from the vendored ~/.pi/agent/themes/catppuccin-mocha.json; atomic ships the same flavor built in.";
        };

        enableInstallTelemetry = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Anonymous install/update ping on first install and after each changelog-detected update. The store path is replaced by home-manager, so every generation bump would emit one.";
        };

        packages = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str jsonFormat.type);
          default = [
            {
              source = "${pkgs.pi-agent-extensions}";
              extensions = [
                "direnv/index.ts"
                "permission-gate/index.ts"
                "questionnaire/index.ts"
                "slow-mode/index.ts"
                "stash/index.ts"
                "statusline/index.ts"
                "-fetch/index.ts"
                "-notify/index.ts"
              ];
              skills = [ ];
              prompts = [ ];
              themes = [ ];
            }
            # Algal declares Pi >=0.80.9 <0.81.0; the fleet evaluates Pi 0.84.1,
            # outside that range. Its fallback compact() argument order still
            # matches exact Pi 0.84.1, while broader API drift remains a
            # calibrated risk. The derivation injects an empty atomic.extensions
            # manifest key, so registering it here contributes nothing to atomic
            # while remaining fully active under pi.
            "${pkgs.pi-openai-server-compaction}"
          ];
          description = "Extension packages registered with every pi-lineage agent, in pi's settings.json packages format.";
        };
      };
    };
}
