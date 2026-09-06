{ ... }:
{
  flake.modules.homeManager.terminal =
    { ... }:
    {
      programs.sesh = {
        enable = true;
        enableAlias = false;
        enableTmuxIntegration = false;
        fzfPackage = null;
        zoxidePackage = null;
      };

      home.shellAliases.s = "sesh connect \"$(sesh list -i | gum filter --limit 1 --placeholder 'Pick a sesh' --prompt='⚡')\"";
    };
}
