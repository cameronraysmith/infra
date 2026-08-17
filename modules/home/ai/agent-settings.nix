# Settings shared by the pi-lineage agents in the homeManager.ai aggregate.
#
# atomic reads ~/.pi/agent as a legacy config root, but only while its own root
# is empty: a populated ~/.atomic/agent/settings.json overrides the pi one
# rather than merging with it, so every key atomic is meant to honour has to be
# written into atomic's own file. Holding the values here rather than in either
# consumer is what stops the two files drifting the way they already did once,
# when atomic's first-run wizard copied a snapshot of this package set across
# and then froze it with theme "dark" against the declared catppuccin-mocha.
#
# Where the two agents genuinely need different values, the divergence is named
# here as its own option rather than patched into a consumer, so that one file
# still answers what each agent is given and why.
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

        atomicExtensionExclusions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "statusline/index.ts" ];
          description = ''
            Extensions from `packages` that atomic must not load, while pi still does.

            atomic 0.9.13 runs every interactive session's extensions in an isolated
            RPC engine child whose `ctx.ui.setFooter` is a warn-once no-op
            (packages/coding-agent/src/modes/rpc/rpc-extension-ui.ts:232). The
            statusline extension calls it to evict atomic's native footer, so under
            atomic the call warns at startup and the native footer stays docked
            beneath the extension's own bar. atomic exposes no setting that
            suppresses the native footer and no way to disable engine isolation, so
            not loading the extension is the only local remedy. pi runs the same
            extension in-process, where the call is honoured.
          '';
        };

        packagesForAtomic = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str jsonFormat.type);
          default =
            let
              forceExcludes = map (extension: "-${extension}") config.aiAgentSettings.atomicExtensionExclusions;
              excludeFrom =
                entry:
                if lib.isAttrs entry && entry ? extensions then
                  entry // { extensions = entry.extensions ++ forceExcludes; }
                else
                  entry;
            in
            map excludeFrom config.aiAgentSettings.packages;
          description = ''
            `packages` as atomic receives it, with `atomicExtensionExclusions` appended
            as `-`-prefixed force-excludes to every entry that selects extensions.

            atomic applies force-excludes last and unconditionally
            (packages/coding-agent/src/core/package-manager-resource-patterns.ts:143),
            so an entry named here loses even though the same list includes it by
            name. A pattern matching nothing is inert, so this stays correct if an
            excluded extension later leaves `packages`.
          '';
        };
      };
    };
}
