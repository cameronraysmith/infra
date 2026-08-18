# SSH server (Apple Remote Login) for Darwin machines
# The clan sshd service only provides nixosModule for the server role;
# this module declares the darwin equivalent. nix-darwin's openssh module
# enables Apple's built-in sshd (com.openssh.sshd) via launchd, which
# listens on all interfaces including zerotier. Host keys are generated
# by the nix-darwin defaults; per-user keys come from each host's
# users.users.<name>.openssh.authorizedKeys.keys wiring (meta.sshKeys).
{
  flake.modules.darwin.sshd-server =
    { ... }:
    {
      services.openssh.enable = true;
    };
}
