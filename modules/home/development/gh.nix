{ ... }:
{
  flake.modules.homeManager.development =
    { pkgs, ... }:
    {
      programs.gh = {
        enable = true;
        extensions = [ pkgs.gh-stack ];
        gitCredentialHelper.enable = false;
      };
    };
}
