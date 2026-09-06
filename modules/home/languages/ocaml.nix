{ ... }:
{
  flake.modules.homeManager.languages =
    { pkgs, ... }:
    {
      programs.opam = {
        enable = true;
        enableBashIntegration = false;
        enableZshIntegration = false;
        enableFishIntegration = false;
      };

      home.packages = with pkgs; [
        ocaml
        dune_3
      ];
    };
}
