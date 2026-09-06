{ ... }:
{
  flake.modules.homeManager.languages =
    { pkgs, ... }:
    {
      programs.bun.enable = true;

      home.packages = with pkgs; [
        nodejs_22
        pnpm
        tailwindcss_4
        yarn-berry
      ];
    };
}
