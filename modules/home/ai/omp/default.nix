# omp (oh-my-pi), a coding agent, as a member of the homeManager.ai aggregate.
#
# oh-my-pi is a fork of pi and does ship a home-manager module, exported from
# its own flake as homeManagerModules.omp. This file deliberately does not
# import it, which is the opposite of what hunk and worktrunk do with theirs.
#
# That module carries three options. Two of them, enable and package, are the
# declarations below, and the third is the reason to decline it: `settings`
# writes ~/.omp/agent/config.yml as a read-only store symlink, while omp's
# settings singleton persists to that same file in the background
# (packages/coding-agent/src/config/settings.ts). Its own option description
# concedes the result -- changes made from inside omp "replace it but revert on
# the next home-manager switch". That is the conflict this repository has
# already resolved twice in the other direction: programs.pi-coding-agent.
# mutableSettings installs a writable copy, and atomic merges rather than
# installs so its first-run wizard is not re-armed on every activation.
# Importing would therefore add a flake input, and nix-bun as a new lock node,
# to obtain an enable flag, a package option, and one home.packages entry,
# because the only option with content in it is the one we would refuse.
#
# If upstream's module later grows options worth having, adopting it is
# deleting these two declarations and adding one imports line; the cost of
# waiting is that migration, against an input carried from now until then. If a
# key ever needs to be declared rather than left to omp, the shape that fits is
# modules/home/ai/atomic/default.nix' merge activation with yq, not upstream's
# writer.
#
# No configuration file is written here. omp resolves .omp, .claude, .codex,
# and .gemini as configuration bases at both user and project level and scans
# each for commands, agents, and skills (packages/coding-agent/src/config.ts),
# so the skills delivered to ~/.claude/skills reach it with nothing declared.
# It does not inherit ~/.pi/agent as a configuration root the way atomic does;
# only the LSP loader consults ~/.pi/agent/lsp.* (src/lsp/config.ts), so
# aiAgentSettings.piOnlyExtensions has no bearing on it.
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
      };

      config = {
        programs.omp.enable = lib.mkDefault true;

        home.packages = lib.mkIf cfg.enable [ cfg.package ];
      };
    };
}
