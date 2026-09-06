{ ... }:
{
  flake.modules.homeManager.terminal =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        curl
        restic
        autorestic
        wget
      ];
    };
}
