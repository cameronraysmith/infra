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
      # coderabbit-cli = flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.coderabbit-cli;
      # crush = flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.crush;
      apm = flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.apm;
      cursor-agent = flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.cursor-agent;
      # opencode: disabled - bun node_modules cleanup fails during build
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
        # backlog-md disabled: auto-patchelf fails on rosetta-builder (elftools issue)
        # ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
        #   flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.backlog-md
        # ]
        # claudebox requires bubblewrap which is Linux-only
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claudebox
        ];
    };
}
