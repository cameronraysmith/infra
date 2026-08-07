# pi coding agent, as a member of the homeManager.ai aggregate.
#
# Global instructions arrive through the upstream `context` option, which writes
# AGENTS.md into configDir — the path pi already reads. programs.agents-md must
# therefore NOT gain a ~/.pi/agent/AGENTS.md destination of its own; two
# declarations of one target trip home-manager's duplicate-file assertion.
#
# No skills are declared here either. pi discovers ~/.agents/skills, which
# modules/home/ai/skills/default.nix populates; a second sink under
# ~/.pi/agent/skills would take precedence over it and shadow the real tree.
{ ... }:
{
  flake.modules.homeManager.ai =
    {
      pkgs,
      config,
      lib,
      flake,
      ...
    }:
    let
      cfg = config.programs.pi-coding-agent;
      jsonFormat = pkgs.formats.json { };
    in
    {
      options.programs.pi-coding-agent.mutableSettings = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use a mutable copy instead of an immutable nix store symlink for settings.json. Allows pi to write to its settings at runtime at the cost of nix-declared state being overwritten between activations.";
      };

      config = {
        programs.pi-coding-agent = {
          enable = true;
          mutableSettings = true;
          package = flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;

          context = config.programs.agents-md.settings.text;

          # https://pi.dev/docs/latest/settings
          settings = {
            theme = "dark";
            # Anonymous install/update ping to pi.dev on first install and after
            # each changelog-detected update; the store path is replaced by
            # home-manager, so every generation bump would emit one.
            enableInstallTelemetry = false;
          };
        };

        # Mutable settings: suppress the upstream symlink-style home.file entry on
        # the ABSOLUTE key upstream actually writes to, "${cfg.configDir}/settings.json"
        # (home-manager modules/programs/pi-coding-agent.nix). A relative key is a
        # silent no-op that leaves the store symlink in place and only surfaces
        # later as a checkLinkTargets backup conflict. Mirrors
        # modules/home/ai/claude-code/default.nix.
        #
        # The copy is required because pi rewrites this file in place — /settings,
        # /model, /theme, and `pi install` all persist to it — and a read-only
        # store symlink makes those writes fail. Scoped to settings.json: pi has
        # no writer for keybindings.json or models.json.
        home.file."${cfg.configDir}/settings.json".enable = lib.mkIf cfg.mutableSettings (
          lib.mkForce false
        );

        home.activation.piCodingAgentMutableSettings = lib.mkIf cfg.mutableSettings (
          let
            settingsFile = jsonFormat.generate "pi-coding-agent-settings.json" cfg.settings;
          in
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD install -Dm644 ${settingsFile} ${cfg.configDir}/settings.json
          ''
        );
      };
    };
}
