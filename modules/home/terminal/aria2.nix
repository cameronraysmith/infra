{ ... }:
{
  flake.modules.homeManager.terminal =
    { ... }:
    {
      programs.aria2.enable = true;
    };
}
