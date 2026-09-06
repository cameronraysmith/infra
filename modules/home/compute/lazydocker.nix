{ ... }:
{
  flake.modules.homeManager.compute =
    { ... }:
    {
      programs.lazydocker.enable = true;
    };
}
