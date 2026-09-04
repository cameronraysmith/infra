# Catppuccin theme configuration
# Extracted from vanixiets/modules/home/all/terminal/default.nix lines 302-303
{ inputs, ... }:
{
  # Two aggregates need the upstream module: `core` sets the global theme
  # below, and `shell/tmux.nix` sets `catppuccin.tmux`. Importing the same
  # attrset module from both files applies it twice, because the module system
  # deduplicates on `key` and an anonymous import is assigned a fresh one, and
  # the second application redefines the tmux plugin. Exporting one value with
  # an explicit key makes the two imports collapse into one.
  flake.lib.catppuccinHomeModule = {
    key = "vanixiets/catppuccin-home-module";
    imports = [ inputs.catppuccin.homeModules.catppuccin ];
  };

  flake.modules.homeManager.core =
    { flake, ... }:
    {
      imports = [ flake.lib.catppuccinHomeModule ];

      # Global catppuccin theme enable
      # Individual programs (tmux, bat, etc.) will use this theme automatically
      catppuccin = {
        enable = true;
        autoEnable = true;
        flavor = "mocha";
      };
    };
}
