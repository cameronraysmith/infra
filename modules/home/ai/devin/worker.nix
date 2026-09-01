# Devin Outposts workers: one option surface, two service backends.
#
# An outpost is a named QUEUE of sessions in Devin Cloud, not a machine. A
# worker is a process that watches one queue, claims a session, and executes
# every command, file edit, and repository operation locally while Devin's
# planning loop stays in their cloud; it needs outbound HTTPS only. N workers
# on one outpost therefore serve N concurrent sessions.
#
# That is why `outposts` is a registry of queues and `workers` is a count, and
# why queues are NOT named per machine index. Naming them `stibnite-1`,
# `stibnite-2` would partition the queue: a session dispatched to a busy queue
# would wait while its sibling queue sat idle, because the operator picks a
# queue when starting the session and cannot know which worker is free.
# Concurrency belongs on the worker count.
#
# Per host the platform decides the supervisor:
#
#   * darwin gets a launchd USER AGENT, deliberately not a system daemon.
#     Devin's computer-use features drive the machine's existing desktop
#     session and need Screen Recording (screenshots) and Accessibility
#     (input) granted to the worker process. A system daemon has no desktop
#     session, so those features would fail with no configuration error to
#     point at. Note that macOS keys those grants to the executable, which is
#     a store path here: a CLI version bump changes the path and the grants
#     have to be given again.
#
#   * linux gets a user-scoped systemd service. A user manager stops with the
#     last login session, so a host serving a queue with nobody logged in also
#     needs `users.users.<name>.linger = true`. That is a NixOS-level option
#     this module cannot reach from home-manager; for the machines in this
#     repository the clan users inventory already sets it (see
#     modules/clan/inventory/services/users/cameron.nix, which lingers
#     cameron on magnetite among others), so the seam is closed at the layer
#     that owns system users rather than duplicated here.
#
# Each worker instance gets its own working directory because a session's
# repositories are checked out under `$(pwd)/repos`: two workers sharing a
# directory would race on the same checkout. Each also gets its own explicit
# acceptor id, since the upstream default is generated per worker DATA
# directory -- which the instances on one host share -- and an id must never
# be shared, across instances or across machines.
{ ... }:
{
  flake.modules.homeManager.devin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.devin-worker;

      hostOutpostPlatform = if pkgs.stdenv.hostPlatform.isDarwin then "macos" else "linux";

      platformOutposts = lib.attrNames (
        lib.filterAttrs (_: outpost: outpost.platform == hostOutpostPlatform) cfg.outposts
      );

      selected = if cfg.outpost == null then null else cfg.outposts.${cfg.outpost} or null;

      indices = lib.genList (index: index + 1) cfg.workers;

      unitName = index: "devin-worker-${toString index}";

      workDir = index: "${cfg.workRoot}/${cfg.outpost}-${toString index}";

      logFile = index: "${cfg.stateDir}/${unitName index}.log";

      # Exit code the launcher uses for a missing credential, distinguishing a
      # permanently misconfigured worker from a transient failure so systemd
      # can decline to restart it. EX_CONFIG from sysexits(3).
      configErrorExit = 78;

      launcher =
        index:
        pkgs.writeShellApplication {
          name = unitName index;
          runtimeInputs = [
            cfg.package
            pkgs.coreutils
            # Required, not optional: every repository operation in a session
            # is a git invocation on this machine.
            pkgs.git
          ];
          meta.description = "Devin Outposts worker ${toString index} for the ${toString cfg.outpost} queue";
          text = ''
            work_dir=${lib.escapeShellArg (workDir index)}
            install -d -m 0700 "$work_dir/repos"

            # The token reaches the process from a sops-rendered file read
            # here, at start, and never from the unit definition: a launchd
            # plist and a systemd unit both land in the world-readable Nix
            # store, so a credential written into either is a credential
            # published to every user on the machine.
            token_file=${lib.escapeShellArg (if cfg.tokenFile == null then "" else cfg.tokenFile)}
            if [ ! -s "$token_file" ]; then
              echo "${unitName index}: no Outposts token at '$token_file'." >&2
              echo "${unitName index}: set services.devin-worker.tokenFile to the sops-nix path holding a v3 API token whose service-user role grants Outposts read and write scope." >&2
              echo "${unitName index}: refusing to start. Without a token the CLI would fall back to the operator's interactive login, authenticating as a person rather than this machine and implicitly creating an outpost upstream." >&2
              exit ${toString configErrorExit}
            fi
            DEVIN_OUTPOSTS_TOKEN="$(cat "$token_file")"
            export DEVIN_OUTPOSTS_TOKEN

            # Stable across restarts, distinct per instance, and carrying the
            # machine's own name so it cannot collide with a worker elsewhere
            # in the fleet. Read at runtime rather than at eval time because
            # home-manager has no hostname to read.
            nodename="$(uname -n)"
            DEVIN_WORKER_ACCEPTOR_ID="''${nodename%%.*}-${cfg.outpost}-${toString index}"
            export DEVIN_WORKER_ACCEPTOR_ID

            cd "$work_dir"
            exec devin worker start --outpost=${lib.escapeShellArg cfg.outpost} ${lib.escapeShellArgs cfg.extraArgs}
          '';
        };

      # launchd and a user systemd unit both start with a minimal PATH, and a
      # session shells out to whatever the repository's own tooling needs.
      servicePath = lib.concatStringsSep ":" (
        [ "${config.home.profileDirectory}/bin" ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          "/usr/local/bin"
          "/opt/homebrew/bin"
        ]
        ++ [
          "/usr/bin"
          "/bin"
          "/usr/sbin"
          "/sbin"
        ]
      );
    in
    {
      options.services.devin-worker = {
        enable = lib.mkEnableOption ''
          long-running Devin Outposts workers serving one outpost queue on this
          host. Off by default: a worker is owned execution capacity that
          claims sessions and runs them with this user's permissions, so
          enabling it is a per-host decision taken alongside minting its token
        '';

        package = lib.mkPackageOption pkgs "devin-cli" { };

        outposts = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                platform = lib.mkOption {
                  type = lib.types.enum [
                    "linux"
                    "macos"
                    "windows"
                  ];
                  description = ''
                    Machine platform the queue was created for. The worker
                    refuses a queue whose platform does not match the machine
                    it runs on, so this is asserted at evaluation time rather
                    than discovered when a session is claimed and released.
                  '';
                };

                description = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                  description = "Human-readable description, as shown for the outpost in the Devin web app.";
                };
              };
            }
          );
          default = {
            stibnite = {
              platform = "macos";
              description = "Apple silicon workstation with a live desktop session for computer use";
            };
            magnetite = {
              platform = "linux";
              description = "x86_64 server capacity for headless sessions";
            };
          };
          description = ''
            Outpost queues this repository knows about, keyed by the name they
            carry in Devin Cloud. Recording them here is a declaration, not a
            creation: creating and deleting an outpost is an account-level
            action taken through the web app or `devin worker outpost create`,
            and nothing in this module reaches upstream to do it.
          '';
        };

        outpost = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = if lib.length platformOutposts == 1 then lib.head platformOutposts else null;
          defaultText = lib.literalMD ''
            the single entry of `outposts` whose `platform` matches this host,
            or `null` when zero or several match
          '';
          example = "magnetite";
          description = ''
            Queue this host's workers serve. The default resolves whenever the
            registry holds exactly one queue for this platform, which is what
            makes the two hosts in this repository work without configuration;
            a third host of an existing platform has to name its own queue,
            because serving another machine's queue would send that machine's
            sessions here.
          '';
        };

        workers = lib.mkOption {
          type = lib.types.ints.positive;
          default = 1;
          description = ''
            Number of worker instances on this host, and therefore the number
            of sessions it serves concurrently; further sessions wait in the
            queue. Each instance gets its own working directory and acceptor
            id.

            Raising this above one on a macOS host is only useful for sessions
            that do not use computer use: instances share the machine's single
            desktop session, so two of them driving mouse and keyboard would
            fight over it.
          '';
        };

        tokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = lib.literalExpression ''config.sops.secrets."devin-outposts-token".path'';
          description = ''
            Path to a file holding the worker's v3 API token, normally a
            sops-nix secret rendered at activation. The token belongs to a
            service user whose role grants Outposts read and write scope.

            It is a bearer credential, so it must never be written into a Nix
            store path: not into a rendered configuration file, and not into a
            launchd plist's EnvironmentVariables or a systemd unit's
            Environment, both of which are store files readable by every user
            on the machine. The launcher reads this file at start and passes
            the value through DEVIN_OUTPOSTS_TOKEN, and refuses to start when
            the file is missing or empty rather than falling back to the CLI's
            interactive login.

            Left null deliberately: minting the token is an account-level
            action for the operator, and until it exists this option has
            nothing correct to point at.
          '';
        };

        workRoot = lib.mkOption {
          type = lib.types.path;
          default = "${config.home.homeDirectory}/devin/workers";
          defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/devin/workers"'';
          description = ''
            Parent directory of the per-instance working directories, each
            `<workRoot>/<outpost>-<index>`. Sessions check their repositories
            out under an instance's `repos` subdirectory and are free to write
            anywhere beneath it, so this is deliberately a plain directory in
            the user's home rather than anything this repository manages
            declaratively.
          '';
        };

        stateDir = lib.mkOption {
          type = lib.types.path;
          default = "${config.xdg.stateHome}/devin-worker";
          defaultText = lib.literalExpression ''"''${config.xdg.stateHome}/devin-worker"'';
          description = "Directory holding each instance's service log.";
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "--poll-interval-secs=15" ];
          description = "Extra arguments appended to `devin worker start`.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.outpost != null;
            message = ''
              services.devin-worker.outpost is unset and no default resolved:
              services.devin-worker.outposts holds ${toString (lib.length platformOutposts)} queues for this host's platform (${hostOutpostPlatform}). Name the queue this host serves.
            '';
          }
          {
            assertion = cfg.outpost == null || selected != null;
            message = ''
              services.devin-worker.outpost is "${toString cfg.outpost}", which is not a key of
              services.devin-worker.outposts (${lib.concatStringsSep ", " (lib.attrNames cfg.outposts)}).
            '';
          }
          {
            assertion = cfg.outpost == null || selected == null || selected.platform == hostOutpostPlatform;
            message = ''
              services.devin-worker.outpost "${toString cfg.outpost}" is registered for platform
              "${toString (selected.platform or null)}" but this host is "${hostOutpostPlatform}". The worker
              validates the machine's OS against the outpost's platform and refuses to serve a mismatch.
            '';
          }
          {
            assertion = cfg.tokenFile != null;
            message = ''
              services.devin-worker is enabled but services.devin-worker.tokenFile is null.
              Point it at the sops-nix path holding the Outposts token, e.g.

                sops.secrets."devin-outposts-token" = { };
                services.devin-worker.tokenFile = config.sops.secrets."devin-outposts-token".path;

              Starting without a token is not a fallback worth taking: the CLI would authenticate as
              the operator's personal login and implicitly create an outpost upstream.
            '';
          }
        ];

        # launchd opens the log file and systemd enters the working directory
        # before the launcher runs, so neither can be left to the launcher to
        # create on first start.
        home.activation.devinWorkerDirectories =
          lib.hm.dag.entryBefore
            [
              "setupLaunchAgents"
              "reloadSystemd"
            ]
            ''
              $DRY_RUN_CMD install -d -m 0700 ${lib.escapeShellArg cfg.stateDir} ${
                lib.escapeShellArgs (map (index: workDir index) indices)
              }
            '';

        launchd.agents = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
          lib.listToAttrs (
            map (
              index:
              lib.nameValuePair (unitName index) {
                enable = true;
                config = {
                  ProgramArguments = [ (lib.getExe (launcher index)) ];
                  RunAtLoad = true;
                  KeepAlive = true;
                  WorkingDirectory = workDir index;
                  StandardOutPath = logFile index;
                  StandardErrorPath = logFile index;
                  # Not "Background": that class caps CPU and I/O priority,
                  # and a session on this worker runs the repository's builds
                  # and tests.
                  ProcessType = "Standard";
                  # PATH only. A credential here would be a store-published
                  # credential; see services.devin-worker.tokenFile.
                  EnvironmentVariables.PATH = servicePath;
                };
              }
            ) indices
          )
        );

        systemd.user.services = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
          lib.listToAttrs (
            map (
              index:
              lib.nameValuePair (unitName index) {
                Unit = {
                  Description = "Devin Outposts worker ${toString index} serving the ${toString cfg.outpost} queue";
                  After = [ "network-online.target" ];
                  Wants = [ "network-online.target" ];
                };
                Service = {
                  ExecStart = lib.getExe (launcher index);
                  WorkingDirectory = workDir index;
                  Restart = "on-failure";
                  # A worker that cannot authenticate stays down instead of
                  # polling the API on a loop; every other failure is treated
                  # as transient and retried on a slow cadence.
                  RestartPreventExitStatus = configErrorExit;
                  RestartSec = 30;
                  Environment = [ "PATH=${servicePath}" ];
                };
                Install.WantedBy = [ "default.target" ];
              }
            ) indices
          )
        );
      };
    };
}
