{ ... }:
{
  flake.modules.homeManager.agents =
    {
      pkgs,
      lib,
      flake,
      ...
    }:
    let
      # apm comes from pkgs, which carries the apm-skill-bundle-workaround patch
      # (Linear CAM-55) in modules/nixpkgs/overlays/apm.nix, unlike the raw
      # llm-agents package the other three bind here.
      cursor-agent = flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.cursor-agent;
      droid = flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.droid;
      gemini-cli = flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.gemini-cli;
    in
    {
      home.packages =
        with pkgs;
        [
          claude-monitor
          apm
          cursor-agent
          droid
          gemini-cli
          golem-binary
          hindsight
          ouroboros
        ]
        # backlog-md is absent: auto-patchelf fails on rosetta-builder
        # claudebox requires bubblewrap which is Linux-only
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claudebox
        ];
    };
}
