{
  # OUTER: Flake-parts module signature
  ...
}:
let
  content =
    {
      # INNER: Home-manager module signature
      config,
      lib,
      flake, # from extraSpecialArgs
      ...
    }:
    {
      home.stateVersion = "23.11";

      # Devin owns ~/.bashrc and ~/.bash_profile and rewrites them at session
      # start, and agent shells are non-interactive, so home-manager's bash
      # configuration is unreachable here and only collides with them.
      programs.bash.enable = lib.mkForce false;

      # The sandbox runs standalone home-manager with no session bus and no
      # systemd user manager, so sops-nix's user unit never starts and its
      # secrets would never be installed.
      sopsInstallWithoutSystemd.enable = true;

      sops = {
        defaultSopsFile = flake.inputs.self + "/secrets/home-manager/users/ubuntu/secrets.yaml";
        secrets = {
          # Git and jujutsu signing read the private key directly on Linux, and
          # `development/radicle.nix` places it at ~/.radicle/keys/radicle.
          ssh-signing-key = {
            mode = "0400";
          };
          linear-api-key-personal = { };
          linear-api-key-work = { };
          linear-workspace-personal = { };
          linear-workspace-work = { };
        };

        templates."linear-credentials.toml" = flake.lib.mkLinearCredentialsTemplate config;
      };

      # The other users render allowed_signers through a sops placeholder
      # because their signing key's public half is itself withheld. This one is
      # already published as a GitHub signing key, so it is written directly and
      # costs no secret. `development/git.nix` points
      # `gpg.ssh.allowedSignersFile` at this path.
      xdg.configFile."git/allowed_signers".text = ''
        ${flake.users.ubuntu.meta.email} namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBTeBMUfte7k9yugPtmVLJONiwxZtyoNotfwBOMAEHGz
      '';

      programs.git.settings = {
        user.name = flake.users.ubuntu.meta.fullname;
        user.email = flake.users.ubuntu.meta.email;
      };
    };
in
{
  flake.users.ubuntu.contentPrivate = content;
}
