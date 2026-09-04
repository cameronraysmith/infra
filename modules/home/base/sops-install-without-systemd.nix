{ ... }:
{
  flake.modules.homeManager.base-sops =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.sopsInstallWithoutSystemd;

      # sops-nix builds a single script that renders the secrets manifest and
      # runs sops-install-secrets against it, then hands the same script to
      # three consumers: the systemd user unit, the launchd agent, and its own
      # activation entry. Only the launchd agent exposes it through a declared
      # option, and sops-nix sets that agent on every platform, so
      # `launchd.agents.sops-nix.config.Program` is the one public handle on
      # the script. Reading it costs nothing on Linux, where home-manager
      # renders no launchd agents.
      installScript = config.launchd.agents.sops-nix.config.Program;

      environment = lib.concatStringsSep " " (
        lib.mapAttrsToList (name: value: "'${name}=${value}'") config.sops.environment
      );
    in
    {
      options.sopsInstallWithoutSystemd.enable = lib.mkEnableOption ''
        installing sops secrets from a home-manager activation entry when no
        systemd user manager is running.

        On Linux sops-nix installs secrets through a systemd user service, and
        its own activation entry only restarts that unit. Where standalone
        home-manager runs without a session bus and user manager, as in a
        container or a hosted agent sandbox, the unit never starts and secrets
        are never installed. This option runs the same sops-nix install script
        directly instead.

        The entry probes `systemctl --user is-system-running` first and does
        nothing when a user manager is present, so enabling it on a NixOS
        workstation is harmless. It has no effect on darwin, where sops-nix
        already bootstraps its launchd agent from its own activation entry, and
        none when no secrets are declared.

        The entry runs after `writeBoundary`. Activation entries that read the
        installed secrets should declare `entryAfter [ "sopsInstallWithoutSystemd" ]`
        rather than relying on entry order.
      '';

      config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isLinux && config.sops.secrets != { }) {
        home.activation.sopsInstallWithoutSystemd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          systemdStatus=$(${config.systemd.user.systemctlPath} --user is-system-running 2>&1 || true)

          if [[ $systemdStatus == 'running' || $systemdStatus == 'degraded' ]]; then
            verboseEcho "sops-nix: user systemd manager is $systemdStatus; the sops-nix unit installs secrets"
          else
            verboseEcho "sops-nix: no user systemd manager; installing secrets directly"
            run env ${environment} ${installScript}
          fi

          unset systemdStatus
        '';
      };
    };
}
