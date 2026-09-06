{ ... }:
{
  flake.modules.homeManager.languages =
    { pkgs, ... }:
    {
      programs.sbt = {
        enable = true;
        package = pkgs.sbt.override { jre = pkgs.temurin-bin-21; };
      };
    };
}
