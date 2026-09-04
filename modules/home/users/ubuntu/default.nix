{
  flake.users.ubuntu.contentPrivate =
    {
      config,
      pkgs,
      lib,
      flake,
      ...
    }:
    let
      keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
      sopsEnvironment = lib.concatStringsSep " " (
        lib.mapAttrsToList (
          name: value: "${name}=${lib.escapeShellArg (toString value)}"
        ) config.sops.environment
      );
      sopsExecStart = lib.head config.systemd.user.services.sops-nix.Service.ExecStart;
    in
    {
      imports = [ flake.inputs.nix-index-database.homeModules.nix-index ];

      home.stateVersion = "26.11";

      home.packages = [
        pkgs.just
        pkgs.linear-cli
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.apm
      ];

      sops = {
        defaultSopsFile = flake.inputs.self + "/secrets/home-manager/users/ubuntu/secrets.yaml";
        age.keyFile = keyFile;
        secrets = {
          linear-api-key-personal = { };
          linear-api-key-work = { };
        };
        templates."linear-credentials.toml" = {
          mode = "0400";
          path = "${config.xdg.configHome}/linear/credentials.toml";
          content = ''
            default = "cameronraysmith"

            cameronraysmith = "${config.sops.placeholder."linear-api-key-personal"}"
            parametricbio = "${config.sops.placeholder."linear-api-key-work"}"
          '';
        };
      };

      home.activation.sopsNixWithoutSystemd =
        lib.hm.dag.entryAfter
          [
            "sops-nix"
            "writeBoundary"
          ]
          ''
            systemdStatus=$(${config.systemd.user.systemctlPath} --user is-system-running 2>&1 || true)
            if [[ $systemdStatus == running || $systemdStatus == degraded ]]; then
              echo "sops-nix user systemd is active; no direct activation needed"
            elif [[ -s "${keyFile}" ]]; then
              runtimeDir="''${XDG_RUNTIME_DIR:-${config.xdg.stateHome}/sops-nix/runtime}"
              if [[ -z ''${XDG_RUNTIME_DIR:-} ]]; then
                run mkdir -p -m 0700 "$runtimeDir"
              fi
              run env XDG_RUNTIME_DIR="$runtimeDir" ${sopsEnvironment} ${sopsExecStart}
            else
              echo "sops-nix fallback skipped: age key file is absent"
            fi
            unset systemdStatus
          '';

      xdg.configFile."vanixiets/devin-bash-env.sh".text = ''
        if [ -n "''${VANIXIETS_DEVIN_BASH_ENV:-}" ]; then
          return 0 2>/dev/null || exit 0
        fi
        export VANIXIETS_DEVIN_BASH_ENV=1

        if [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
          . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi

        for hmSessionVars in \
          "$HOME/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh" \
          "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
        do
          if [ -r "$hmSessionVars" ]; then
            . "$hmSessionVars"
            break
          fi
        done

        case ":''${PATH:-}:" in
          *":$HOME/.nix-profile/bin:"*) ;;
          *) PATH="$HOME/.nix-profile/bin:''${PATH:-}"; export PATH ;;
        esac

        keyFile="${keyFile}"
        if [ -n "''${SOPS_AGE_KEY_UBUNTU:-}" ] && [ ! -s "$keyFile" ]; then
          (
            umask 077
            mkdir -p "$(dirname "$keyFile")"
            printf '%s\n' "$SOPS_AGE_KEY_UBUNTU" > "$keyFile"
          )

          logFile="$HOME/.local/state/vanixiets/devin-reactivate.log"
          mkdir -p "$(dirname "$logFile")"
          activate=""
          for homeManagerProfile in \
            "$HOME/.local/state/nix/profiles/home-manager" \
            "/nix/var/nix/profiles/per-user/$USER/home-manager"
          do
            if [ -x "$homeManagerProfile/activate" ]; then
              activate="$homeManagerProfile/activate"
              break
            fi
          done

          if [ -n "$activate" ]; then
            if ! "$activate" >> "$logFile" 2>&1; then
              printf '%s\n' "home-manager reactivation failed; see $logFile" >&2
            fi
          else
            printf '%s\n' "home-manager activation profile not found" >&2
          fi
        fi
      '';
    };
}
