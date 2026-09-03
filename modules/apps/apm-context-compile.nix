# Composes this repo's agent-context-* apm packages into the repo-root
# AGENTS.md (+ a CLAUDE.md pointer). Mirrors the apm-skills-install +
# co-located .sh sidecar convention.
{ ... }:
{
  perSystem =
    {
      inputs',
      pkgs,
      lib,
      ...
    }:
    {
      apps.apm-context-compile = {
        type = "app";
        program = lib.getExe (
          pkgs.writeShellApplication {
            name = "apm-context-compile";
            runtimeInputs = [
              inputs'.llm-agents.packages.apm
              pkgs.git # repo root resolution
              pkgs.yq-go
              pkgs.coreutils
              pkgs.findutils
              pkgs.gnugrep
            ];
            text = builtins.readFile ./apm-context-compile.sh;
          }
        );
      };
    };
}
