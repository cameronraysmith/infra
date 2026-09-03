{ ... }:
{
  flake.modules.homeManager.tools =
    { lib, pkgs, ... }:
    {
      # `services.gpg-agent.enable` launches the agent via `gpg-agent
      # --supervised`, which on launchd (no inherited LISTEN_FDS socket)
      # exits immediately and gets endlessly respawned; systemd's user
      # instance does supply that socket, so the agent only works on Linux.
      services.gpg-agent = {
        enable = pkgs.stdenv.hostPlatform.isLinux;

        defaultCacheTtl = 43200; # 12 hours for normal cache
        maxCacheTtl = 86400; # 1 day maximum cache lifetime

        pinentry.package = pkgs.pinentry-tty;

        extraConfig = "";
      };

      # home-manager only writes gpg-agent.conf when services.gpg-agent.enable
      # is true (it's under that module's `mkIf cfg.enable`), so on darwin -
      # where the service above stays disabled - this reproduces the same
      # settings for on-demand invocation by either nixpkgs gpg or GPG Suite.
      home.file.".gnupg/gpg-agent.conf" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        text = ''
          default-cache-ttl 43200
          max-cache-ttl 86400
          pinentry-program ${pkgs.pinentry-tty}/bin/pinentry-tty
        '';
      };

      programs.gpg = {
        enable = true;
      };
    };
}
