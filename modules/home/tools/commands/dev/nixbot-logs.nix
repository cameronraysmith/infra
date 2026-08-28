{ ... }:
{
  flake.modules.homeManager.tools =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "nixbot-logs";
          runtimeInputs = with pkgs; [
            coreutils
            curl
            jq
          ];
          text = builtins.readFile ./nixbot-logs.sh;
          meta.description = "Fetch nixbot build, attribute, and effect logs over its HTTP API";
        })
      ];
    };
}
