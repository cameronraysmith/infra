# omp (oh-my-pi), a coding agent, as a member of the homeManager.ai aggregate.
#
# oh-my-pi is a fork of pi and does ship a home-manager module, exported from
# its own flake as homeManagerModules.omp. This file deliberately does not
# import it, which is the opposite of what hunk and worktrunk do with theirs.
#
# That module carries three options. Two of them, enable and package, are the
# declarations below, and the third is the reason to decline it: its `settings`
# writes ~/.omp/agent/config.yml as a read-only store symlink, while omp's
# settings singleton persists to that same file in the background
# (packages/coding-agent/src/config/settings.ts). Its own option description
# concedes the result -- changes made from inside omp "replace it but revert on
# the next home-manager switch". The activation below takes the other route
# this repository has twice chosen instead, merging rather than installing, so
# that setupVersion and anything else omp owns survives a switch.
#
# If upstream's module later grows options worth having, adopting it is
# deleting these declarations and adding one imports line; the cost of waiting
# is that migration, against an input carried from now until then.
#
# Two files are nix-owned, both at user scope, and omp writes both at runtime:
# config.yml from the /settings, /model, and /theme screens, and WATCHDOG.yml
# whole from the /advisor editor (src/modes/components/advisor-config.ts). The
# merge shape and its retract limitation are documented in merge-config.sh.
# WATCHDOG.yml is discovered at ${configDir}/WATCHDOG.yml and combined with any
# project-level roster rather than overridden by it (src/advisor/watchdog.ts
# collectConfigCandidates), so what is declared here is the fleet-wide baseline.
#
# Nothing else is written. omp resolves .omp, .claude, .codex, and .gemini as
# configuration bases at both user and project level and scans each for
# commands, agents, and skills (packages/coding-agent/src/config.ts), so the
# skills delivered to ~/.claude/skills reach it with nothing declared. It does
# not inherit ~/.pi/agent as a configuration root the way atomic does; only the
# LSP loader consults ~/.pi/agent/lsp.* (src/lsp/config.ts), so
# aiAgentSettings.piOnlyExtensions has no bearing on it.
#
# LSP servers are not declared here either. omp auto-detects them from its
# 54-entry registry (src/lsp/defaults.json) by requiring a root marker in the
# project and a resolvable binary, so the roster follows whatever PATH omp is
# launched with. Pinning it would mean an lsp.yml, which unlike config.yml omp
# only ever reads, so it would not need this merge.
{ ... }:
{
  flake.modules.homeManager.ai =
    {
      pkgs,
      lib,
      config,
      flake,
      ...
    }:
    let
      cfg = config.programs.omp;
      yamlFormat = pkgs.formats.yaml { };
      mergeConfig = pkgs.writeShellApplication {
        name = "omp-merge-config";
        runtimeInputs = [ pkgs.yq-go ];
        text = builtins.readFile ./merge-config.sh;
      };
    in
    {
      options.programs.omp = {
        enable = lib.mkEnableOption "omp, a coding agent forked from pi with an IDE, LSP, and DAP surface wired in";

        package = lib.mkOption {
          type = lib.types.package;
          default = flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp;
          defaultText = lib.literalExpression "inputs.llm-agents.packages.\${pkgs.stdenv.hostPlatform.system}.omp";
          description = ''
            The omp package to install. Sourced from the llm-agents input rather
            than oh-my-pi's own flake, whose module defaults its package option to
            that flake's build: llm-agents is covered by the numtide cache this
            fleet already substitutes from (lib/caches.nix), so a version bump
            arrives as a substitution instead of a source build.
          '';
        };

        configDir = lib.mkOption {
          type = lib.types.str;
          default = "${config.home.homeDirectory}/.omp/agent";
          description = "Directory omp reads its configuration and runtime state from.";
        };

        settings = lib.mkOption {
          type = yamlFormat.type;
          default = { };
          description = ''
            Nix-owned subset of {file}`config.yml`. Each declared key wins on
            activation; every key omp writes and nix does not declare, setupVersion
            among them, survives untouched.
          '';
        };

        watchdog = lib.mkOption {
          type = yamlFormat.type;
          default = { };
          description = ''
            Nix-owned subset of {file}`WATCHDOG.yml`, the advisor roster the
            {command}`/advisor` editor reads and rewrites.

            `advisors` is a sequence, and sequences are replaced rather than merged,
            so this states the roster outright. Disable one entry with
            `enabled = false` rather than removing it: merge-config.sh cannot retract
            a key, and a dropped advisor would otherwise persist from the last
            activation that declared it.
          '';
        };
      };

      config = {
        programs.omp = {
          enable = lib.mkDefault true;

          settings = {
            # omp kept pi's key name and semantics for this one
            # (src/config/settings-schema.ts), so the fleet-wide default reaches a
            # third pi-lineage agent from the same expression.
            hideThinkingBlock = lib.mkDefault config.aiAgentSettings.hideThinkingBlock;
            symbolPreset = lib.mkDefault "nerd";
            # Named for omp's own theme registry rather than the catppuccin flavor
            # aiAgentSettings.theme carries, which pi and atomic resolve against a
            # vendored theme file; the two are not interchangeable strings.
            theme.dark = lib.mkDefault "dark-catppuccin";
            modelRoles = {
              default = lib.mkDefault "zai/glm-5.3:high";
              advisor = lib.mkDefault "openai-codex/gpt-5.6-sol:xhigh";
              plan = lib.mkDefault "anthropic/claude-opus-5:xhigh";
              designer = lib.mkDefault "anthropic/claude-opus-5:xhigh";
              smol = lib.mkDefault "openrouter/moonshotai/kimi-k3:high";
              slow = lib.mkDefault "openai-codex/gpt-5.6-sol:xhigh";
              vision = lib.mkDefault "openrouter/google/gemini-3.7-flash:high";
              commit = lib.mkDefault "openai-codex/gpt-5.6-luna:medium";
              tiny = lib.mkDefault "openai-codex/gpt-5.6-luna:medium";
              task = lib.mkDefault "anthropic/claude-sonnet-5:high";
            };
            # Hindsight is omp's native memory backend, reached over HTTP by a
            # hand-rolled client (src/hindsight/backend.ts) with no MCP server in
            # the path. Only backend and apiUrl change behaviour; the remaining six
            # restate the schema defaults omp carries at 17.3.5, declared so an
            # upstream default change surfaces as a diff here rather than as a
            # silent shift in what the fleet retains.
            #
            # bankId is deliberately left unset. Under per-project-tagged scoping
            # that resolves to the base bank `omp` (src/hindsight/bank.ts), one
            # shared bank whose entries are tagged with the project name, which is
            # what recall across the fleet's repositories wants.
            memory.backend = lib.mkDefault "hindsight";
            hindsight = {
              apiUrl = lib.mkDefault "https://api.hindsight.vectorize.io";
              scoping = lib.mkDefault "per-project-tagged";
              retainMode = lib.mkDefault "full-session";
              autoRecall = lib.mkDefault true;
              autoRetain = lib.mkDefault true;
              mentalModelsEnabled = lib.mkDefault true;
              mentalModelAutoSeed = lib.mkDefault true;
            };
          };

          watchdog = {
            instructions = lib.mkDefault "Shared review baseline for all advisors.";
            advisors = lib.mkDefault [
              {
                name = "Watchdog";
                model = "openai-codex/gpt-5.6-sol:xhigh";
                instructions = "Continuous duty: wrong-direction detection, missing constraints, hallucinated APIs, plan/todo drift. Prefer concern over nit.";
              }
              {
                name = "Fable";
                model = "anthropic/claude-fable-5:xhigh";
                instructions = "Deep-review duty: architectural soundness, subtle correctness, cross-module invariants. Invoked deliberately; be thorough.";
                enabled = false;
              }
            ];
          };
        };

        home.packages = lib.mkIf cfg.enable [ cfg.package ];

        # The Hindsight token reaches omp through the environment and never
        # through settings above. omp parses config.yml as plain YAML and expands
        # nothing, so a `${HINDSIGHT_API_TOKEN}` written into hindsight.apiToken is
        # sent verbatim as the bearer token; docs/memory.md shows that form anyway,
        # and it fails as a literal string whenever the variable is unset and is
        # dead configuration whenever it is set, because the environment outranks
        # the settings file (src/hindsight/config.ts). A real token written there
        # would be worse still: cfg.settings renders into a world-readable store
        # path, and merge-config.sh leaves the target at 0644.
        #
        # ~/.omp/.env is the fourth of the five sources omp's loader consults --
        # process environment, project .env, ${configDir}/.env, ~/.omp/.env,
        # ~/.env -- each filling only keys still unset, so every launch path picks
        # the token up with no wrapper. Rendering it as a sops template keeps the
        # plaintext out of the nix store entirely.
        sops.templates = lib.mkIf cfg.enable {
          omp-env = {
            mode = "0400";
            path = "${config.home.homeDirectory}/.omp/.env";
            content = "HINDSIGHT_API_TOKEN=${config.sops.placeholder."hindsight-api-token"}\n";
          };
        };

        home.activation.ompMergeConfig = lib.mkIf cfg.enable (
          let
            merge =
              declared: target: "$DRY_RUN_CMD ${lib.getExe mergeConfig} ${declared} ${cfg.configDir}/${target}";
          in
          lib.hm.dag.entryAfter [ "writeBoundary" ] (
            lib.concatStringsSep "\n" (
              lib.optional (cfg.settings != { }) (
                merge (yamlFormat.generate "omp-config.yml" cfg.settings) "config.yml"
              )
              ++ lib.optional (cfg.watchdog != { }) (
                merge (yamlFormat.generate "omp-watchdog.yml" cfg.watchdog) "WATCHDOG.yml"
              )
            )
          )
        );
      };
    };
}
