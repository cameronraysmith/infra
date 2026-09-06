{ ... }:
{
  flake.modules.homeManager.languages =
    { pkgs, ... }:
    {
      programs.sbt = {
        enable = true;
        # pin sbt to specific JDK
        package = pkgs.sbt.override { jre = pkgs.temurin-bin-21; };
      };
    };
}
