# The firstmate toolchain, as a member of the homeManager.ai aggregate.
#
# These are placed on the ai aggregate rather than the shared packages
# aggregate because packages reaches all five users while ai reaches only the
# user who runs agents. The tools serve firstmate and have no standalone use,
# so putting them on packages would install agent tooling for four people who
# never invoke an agent.
{ ... }:
{
  flake.modules.homeManager.ai =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        chrome-devtools-axi
        gh-axi
        lavish-axi
        no-mistakes
        quota-axi
        tasks-axi
        treehouse
      ];
    };
}
