{ ... }:
{
  flake.modules.homeManager.terminal =
    { ... }:
    {
      programs.ripgrep.enable = true;
    };
}
