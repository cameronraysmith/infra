# Access to stibnite (aarch64-darwin) from the fleet, in three separable pieces.
#
# stibnite is the fleet's only aarch64-darwin machine, and until this module
# nothing declared it as a build target: magnetite is x86_64-linux and cannot
# build darwin derivations, and stibnite's own nix.buildMachines list carries
# only the rosetta VM and magnetite. The two mechanisms below are the two ways
# a caller can reach stibnite's store, and they are not interchangeable.
#
# services.stibnite-builder — remote BUILDER (nix.buildMachines).
#   The caller's nix daemon copies the input closure to stibnite, builds there,
#   and copies the output closure back, so the result exists in the CALLER's
#   store. Callers: developers and operators who need an aarch64-darwin result
#   locally, for example to build or test Darwin configurations from magnetite.
#
# services.stibnite-builder.storeUri — remote STORE (--store ssh-ng://).
#   The whole build happens inside stibnite's store; evaluation stays with the
#   caller and no closure is copied back. Callers: a machine whose own store is
#   empty and stays empty — an ephemeral CI runner, a fresh container, an
#   installer image — where a remote builder would spend the whole job
#   populating a store that is about to be discarded. Nothing lands locally, so
#   a caller that needs the output path locally wants the builder above.
#
# services.stibnite-session — an unrestricted login as admin-group crs58, who
#   is already a Nix trusted user, so it grants build authority plus shell. Its
#   key is separately authorized for independent revocation and rotation; only
#   the build key is confined to the Nix protocol by `restrict` and a forced
#   command.
#
# services.stibnite-build-host — the stibnite side: the account restricted to
#   nix-daemon at the SSH boundary and trusted with store-root-equivalent
#   authority, plus the authorization for both keypairs.
{ lib, ... }:
let
  # Deterministic ZeroTier IPv6, matching modules/system/ssh-known-hosts.nix
  # and modules/machines/nixos/cinnabar/zt-dns.nix.
  stibniteZt = "fddb:4344:343b:14b9:399:9324:19d9:3451";

  # clan's public var values carry the trailing newline of the file they were
  # read from, and an authorized_keys entry is one line.
  trimKey = key: lib.removeSuffix "\n" key;

  mkSshBlock = args: ''
    Host ${args.hostAlias}
      HostName ${stibniteZt}
      User ${args.sshUser}
      IdentityFile ${args.sshKeyPath}
      IdentitiesOnly yes
      HostKeyAlias stibnite.zt
  '';

  builderOptions =
    config:
    let
      cfg = config.services.stibnite-builder;
      sshKeyPath = config.clan.core.vars.generators.stibnite-nix-build.files.key.path;
    in
    {
      options.services.stibnite-builder = {
        enable = lib.mkEnableOption "build access to stibnite, the fleet's aarch64-darwin machine";

        systems = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          # aarch64-darwin only. `nix config show extra-platforms` on stibnite
          # reports aarch64-darwin and nothing else, so advertising
          # x86_64-darwin would route derivations the machine refuses to build.
          default = [ "aarch64-darwin" ];
          description = "Systems stibnite can build for.";
        };

        maxJobs = lib.mkOption {
          type = lib.types.int;
          # stibnite has 18 logical cores (12 performance + 6 efficiency) and
          # 64 GiB of memory. It is also a laptop in interactive use that
          # commits 12 cores and 48 GiB to the rosetta builder VM and the same
          # again to colima when either is running, so the remote share is
          # deliberately a minority of the machine: 4 concurrent jobs, each
          # free to use every core through the daemon's own `cores` setting.
          default = 4;
          description = "Maximum simultaneous build jobs dispatched to stibnite.";
        };

        speedFactor = lib.mkOption {
          type = lib.types.int;
          # Inert while stibnite is the only aarch64-darwin builder: nix
          # compares speedFactor among machines that can build the same system,
          # and there is no second darwin machine to compare against. 1 is the
          # neutral value to raise if one appears.
          default = 1;
          description = "Scheduler weight, compared only against other aarch64-darwin builders.";
        };

        supportedFeatures = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          # Measured with `nix config show system-features` on stibnite, minus
          # what the value means rather than what nix prints. apple-virt is
          # real and stibnite is the only machine in the fleet that has it.
          # big-parallel is real on 18 cores. "benchmark" is dropped because
          # timings taken on a laptop under interactive load are not
          # measurements, and "nixos-test" is dropped because it is a Linux
          # sandbox capability that nix lists unconditionally.
          default = [
            "apple-virt"
            "big-parallel"
          ];
          description = "Build features stibnite advertises to the scheduler.";
        };

        sshUser = lib.mkOption {
          type = lib.types.str;
          default = "nixbuild";
          description = "Build account restricted to nix-daemon at the SSH boundary and trusted with store-root-equivalent authority; see services.stibnite-build-host.user.";
        };

        hostAlias = lib.mkOption {
          type = lib.types.str;
          # Distinct from the "stibnite" / "stibnite.zt" aliases an interactive
          # session uses, so the build identity and the session identity cannot
          # be reached through each other's alias by accident.
          default = "stibnite-builder";
          description = "ssh Host alias the nix daemon resolves to stibnite's ZeroTier address.";
        };

        buildMachines = lib.mkOption {
          type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
          default =
            if cfg.enable then
              [
                {
                  hostName = cfg.hostAlias;
                  sshUser = cfg.sshUser;
                  protocol = "ssh-ng";
                  sshKey = sshKeyPath;
                  systems = cfg.systems;
                  maxJobs = cfg.maxJobs;
                  speedFactor = cfg.speedFactor;
                  supportedFeatures = cfg.supportedFeatures;
                  mandatoryFeatures = [ ];
                }
              ]
            else
              [ ];
          defaultText = lib.literalExpression "single-element stibnite buildMachines entry when enabled, else []";
          description = "Computed nix.buildMachines entry. Consumers splice this into their own nix.buildMachines; this module never sets nix.buildMachines itself.";
        };

        storeUri = lib.mkOption {
          type = lib.types.str;
          default = "ssh-ng://${cfg.sshUser}@${cfg.hostAlias}?ssh-key=${sshKeyPath}";
          defaultText = lib.literalExpression "ssh-ng URI naming the build account, the ssh alias and the build key";
          readOnly = true;
          description = ''
            Remote-store URI for `nix build --store`, the other mechanism.
            Materialized at /etc/nix/stibnite-store-uri so a caller reads the
            key path from configuration rather than retyping it. The key is
            root-owned, so a non-root caller needs `sudo -E`.
          '';
        };
      };
    };

  # Generated rather than operator-populated: no plaintext private half leaves
  # magnetite. Clan commits the encrypted private half and public value, and
  # only magnetite and authorized users can decrypt the private half. This
  # avoids manual transcription. The operator step is `clan vars generate
  # <machine>` plus committing both outputs; stibnite reads the public value at
  # evaluation time.
  mkBuildKeyGenerator = pkgs: {
    clan.core.vars.generators.stibnite-nix-build = {
      files.key = { };
      files."key.pub".secret = false;
      runtimeInputs = [ pkgs.openssh ];
      script = ''
        ssh-keygen -t ed25519 -N "" -C "stibnite-nix-build" -f "$out"/key
      '';
    };
  };

  sessionOptions = {
    options.services.stibnite-session = {
      enable = lib.mkEnableOption "interactive ssh access to stibnite under a dedicated keypair";

      sshUser = lib.mkOption {
        type = lib.types.str;
        default = "crs58";
        description = "Account on stibnite this key logs in as.";
      };

      hostAlias = lib.mkOption {
        type = lib.types.str;
        default = "stibnite-session";
        description = "ssh Host alias for the session identity, distinct from the builder alias.";
      };
    };
  };

  mkSessionKeyGenerator = pkgs: {
    clan.core.vars.generators.stibnite-agent-session = {
      files.key = { };
      files."key.pub".secret = false;
      runtimeInputs = [ pkgs.openssh ];
      script = ''
        ssh-keygen -t ed25519 -N "" -C "stibnite-agent-session" -f "$out"/key
      '';
    };
  };
in
{
  flake.modules.nixos.stibnite-builder =
    { config, pkgs, ... }:
    let
      cfg = config.services.stibnite-builder;
      sshKeyPath = config.clan.core.vars.generators.stibnite-nix-build.files.key.path;
    in
    (builderOptions config)
    // {
      config = lib.mkIf cfg.enable (
        (mkBuildKeyGenerator pkgs)
        // {
          nix.distributedBuilds = true;

          # stibnite subscribes to the same binary cache, so a dependency it can
          # substitute itself is not worth shipping to it over ZeroTier.
          nix.settings.builders-use-substitutes = true;

          programs.ssh.extraConfig = mkSshBlock {
            inherit (cfg) hostAlias sshUser;
            inherit sshKeyPath;
          };

          environment.etc."nix/stibnite-store-uri".text = "${cfg.storeUri}\n";
        }
      );
    };

  flake.modules.nixos.stibnite-session =
    { config, pkgs, ... }:
    let
      cfg = config.services.stibnite-session;
      sshKeyPath = config.clan.core.vars.generators.stibnite-agent-session.files.key.path;
    in
    sessionOptions
    // {
      config = lib.mkIf cfg.enable (
        (mkSessionKeyGenerator pkgs)
        // {
          programs.ssh.extraConfig = mkSshBlock {
            inherit (cfg) hostAlias sshUser;
            inherit sshKeyPath;
          };
        }
      );
    };

  # stibnite's own side: one account both build mechanisms land in, and the
  # authorization for the two keypairs above.
  flake.modules.darwin.stibnite-build-host =
    { config, lib, ... }:
    let
      cfg = config.services.stibnite-build-host;
    in
    {
      options.services.stibnite-build-host = {
        enable = lib.mkEnableOption "the remote build account restricted to nix-daemon at the SSH boundary and trusted with store-root-equivalent authority";

        user = lib.mkOption {
          type = lib.types.str;
          default = "nixbuild";
          description = "Account the nix build protocol is served under.";
        };

        uid = lib.mkOption {
          type = lib.types.int;
          # Free on stibnite as of 2026-08-31: 501 crs58, 502 runner,
          # 535 _dnscrypt-proxy are the only accounts at or above 500.
          default = 530;
          description = "UID for the build account.";
        };

        buildKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Public keys authorized to speak the nix build protocol. Each is
            installed with a forced command and `restrict`, so it can run the
            protocol and nothing else at the SSH boundary. This restricts which
            program the key starts, not the nix daemon's authority. The account
            is a Nix trusted user with store-root-equivalent authority: it can
            cause arbitrary paths to enter the store and influence what the
            daemon trusts. This grant is required to receive caller-evaluated
            unsigned paths.
          '';
        };

        sessionUser = lib.mkOption {
          type = lib.types.str;
          default = "crs58";
          description = "Account the session keys below log in as.";
        };

        sessionKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Public keys authorized for an ordinary interactive login, with no forced command.";
        };

        authorizeSshAccessGroup = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Add the build account to macOS's `com.apple.access_ssh` service
            ACL at activation. On stibnite that ACL nests only the admin
            group, and the build account is deliberately not an admin, so
            without this every dispatch fails as `Permission denied
            (publickey)` with a correct key installed. Set false to manage the
            ACL by hand with
            `dseditgroup -o edit -a <user> -t user com.apple.access_ssh`.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        users.users.${cfg.user} = {
          inherit (cfg) uid;
          description = "Remote nix build account";
          # sshd runs a forced command through the account's shell, so
          # /usr/bin/false (nix-darwin's default for shell = null) would break
          # the build protocol rather than harden it. Interactive use is
          # foreclosed by the key options below, which sshd applies before the
          # shell ever runs.
          shell = "/bin/sh";
          # nix-daemon --stdio is exactly what an ssh-ng caller would have
          # invoked (`remote-program` defaults to nix-daemon), so forcing it
          # serves both the remote-builder and the remote-store mechanism and
          # discards anything else the client asks for. Legacy `ssh://`, which
          # would run `nix-store --serve`, is deliberately not served.
          openssh.authorizedKeys.keys = map (
            key: ''restrict,command="${config.nix.package}/bin/nix-daemon --stdio" ${trimKey key}''
          ) cfg.buildKeys;
        };

        users.knownUsers = [ cfg.user ];

        # This deliberate trusted-user grant is store-root-equivalent on
        # stibnite: the account can cause arbitrary paths to enter the store and
        # influence what the daemon trusts. The forced SSH command restricts
        # which program the key starts, not that program's authority. The grant
        # is required because an untrusted build account cannot receive unsigned
        # caller-evaluated paths, matching magnetite's builder account.
        nix.settings.trusted-users = [ cfg.user ];

        users.users.${cfg.sessionUser}.openssh.authorizedKeys.keys = map trimKey cfg.sessionKeys;

        system.activationScripts.postActivation.text = lib.mkIf cfg.authorizeSshAccessGroup ''
          if ! /usr/sbin/dseditgroup -o checkmember -m ${cfg.user} com.apple.access_ssh >/dev/null 2>&1; then
            echo "Adding ${cfg.user} to the com.apple.access_ssh service ACL..."
            /usr/sbin/dseditgroup -o edit -a ${cfg.user} -t user com.apple.access_ssh
          fi
        '';
      };
    };
}
