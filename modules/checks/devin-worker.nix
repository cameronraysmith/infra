# Structural check for `flake.modules.homeManager.devin`'s worker surface
# (see modules/home/ai/devin/worker.nix).
#
# The module lands disabled on every host, so nothing in the machine
# configurations exercises it. What the module promises when enabled is
# checked here instead, with a dummy token path standing in for the sops-nix
# secret the operator has yet to mint. Only names, counts, and booleans are
# serialized into the diff, so this check evaluates and never builds a
# worker's launcher.
#
# Two evaluation vehicles, for two different reasons.
#
#   * The positive claims run through a minimal real
#     `homeManagerConfiguration` on both platforms, so launchd plist keys and
#     systemd unit sections are validated by the actual option types rather
#     than by a stub of them.
#
#   * The assertion claims run through a bare `lib.evalModules` against the
#     same deferred module. home-manager throws on the whole configuration
#     when any assertion fails, which makes the failure observable but hides
#     WHICH clause fired; outside that wrapper the resolved `assertions` list
#     is an ordinary value and each clause can be identified.
#
# Claims exercised:
#
# 1. Platform routing and instance fan-out: `workers = 2` produces exactly two
#    launchd agents and no systemd units on darwin, and exactly two systemd
#    user services and no launchd agents on linux.
#
# 2. No credential in the unit definition. A launchd plist and a systemd unit
#    are Nix store files readable by every user on the machine, which is why
#    the token is read from a file by the launcher at start. The service
#    environment is therefore required to carry PATH and nothing else.
#
# 3. Per-instance working directories: session repositories live under
#    `$(pwd)/repos`, so two instances sharing a working directory would race
#    on the same checkout.
#
# 4. Each assertion clause fires on exactly its own malformed input, and a
#    well-formed configuration fires none.
#
# Severity rationale (Mayo): each claim fails under a plausible incorrect
# implementation. Dropping the `mkIf isDarwin` / `mkIf isLinux` gates puts
# units on both platforms and breaks claim 1. Moving the token into
# `EnvironmentVariables` or `Environment` -- the shortcut this module exists
# to refuse -- adds a key and breaks claim 2. Deriving the working directory
# from the outpost alone rather than from the instance index collapses the two
# paths and breaks claim 3. Weakening any assertion to a tautology empties its
# fired-clause list, and strengthening one into an always-firing predicate
# populates `wellFormed`, so claim 4 is falsifiable in both directions.
{ inputs, self, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      lib = pkgs.lib;
      mkCheck = self.lib.mkStructuralCheck pkgs;

      dummyTokenPath = "/run/secrets/devin-outposts-token.dummy";

      # The same package set the home configurations get (see
      # modules/home/mk-home.nix): `self.legacyPackages` is the channel before
      # flake.overlays.default is applied, where `devin-cli` would resolve to
      # the channel's older build rather than the one this repository vendors.
      probePkgs =
        system:
        import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ self.overlays.default ];
        };

      # Real home-manager evaluation: option types enforced, assertions
      # required to pass (home-manager throws otherwise, so reaching the
      # values below is itself part of the positive claim).
      evalHome =
        {
          system,
          homeDirectory,
          worker,
        }:
        (inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = probePkgs system;
          modules = [
            self.modules.homeManager.devin
            {
              home = {
                username = "probe";
                inherit homeDirectory;
                stateVersion = "25.05";
              };
              services.devin-worker = worker;
            }
          ];
        }).config;

      # Bare module evaluation, for inspecting the assertions themselves.
      evalBare =
        system: worker:
        (lib.evalModules {
          modules = [
            self.modules.homeManager.devin
            {
              _module.check = false;
              _module.args.pkgs = probePkgs system;
              freeformType = lib.types.lazyAttrsOf lib.types.raw;
            }
            { services.devin-worker = worker; }
          ];
        }).config;

      darwin = evalHome {
        system = "aarch64-darwin";
        homeDirectory = "/Users/probe";
        worker = {
          enable = true;
          workers = 2;
          tokenFile = dummyTokenPath;
        };
      };

      linux = evalHome {
        system = "x86_64-linux";
        homeDirectory = "/home/probe";
        worker = {
          enable = true;
          workers = 2;
          tokenFile = dummyTokenPath;
        };
      };

      agents = config: lib.attrNames (config.launchd.agents or { });
      units = config: lib.attrNames (config.systemd.user.services or { });

      # Failing clauses, named by a distinctive substring of their message so
      # the diff identifies the clause instead of embedding whole prose.
      firedClauses =
        config:
        map (
          message:
          if lib.hasInfix "tokenFile is null" message then
            "token"
          else if lib.hasInfix "registered for platform" message then
            "platform"
          else if lib.hasInfix "not a key of" message then
            "unknown-outpost"
          else if lib.hasInfix "no default resolved" message then
            "unset-outpost"
          else
            "unrecognized: ${message}"
        ) (map (a: a.message) (lib.filter (a: !a.assertion) config.assertions));

      distinctWorkDirs = paths: paths != [ ] && lib.length (lib.unique paths) == lib.length paths;
    in
    {
      checks.devin-worker-structural = mkCheck {
        name = "devin-worker-structural";
        actual = {
          darwinAgents = agents darwin;
          darwinUnits = units darwin;
          darwinPlistEnvKeys =
            lib.attrNames
              darwin.launchd.agents."devin-worker-1".config.EnvironmentVariables;
          darwinWorkDirsDistinct = distinctWorkDirs (
            map (name: darwin.launchd.agents.${name}.config.WorkingDirectory) (agents darwin)
          );

          linuxUnits = units linux;
          linuxAgents = agents linux;
          linuxUnitEnvNames = map (
            entry: lib.head (lib.splitString "=" entry)
          ) linux.systemd.user.services."devin-worker-1".Service.Environment;
          linuxWorkDirsDistinct = distinctWorkDirs (
            map (name: linux.systemd.user.services.${name}.Service.WorkingDirectory) (units linux)
          );

          wellFormed = firedClauses (
            evalBare "aarch64-darwin" {
              enable = true;
              tokenFile = dummyTokenPath;
            }
          );
          tokenless = firedClauses (
            evalBare "aarch64-darwin" {
              enable = true;
              tokenFile = null;
            }
          );
          platformMismatch = firedClauses (
            evalBare "aarch64-darwin" {
              enable = true;
              outpost = "magnetite";
              tokenFile = dummyTokenPath;
            }
          );
          unknownOutpost = firedClauses (
            evalBare "aarch64-darwin" {
              enable = true;
              outpost = "no-such-queue";
              tokenFile = dummyTokenPath;
            }
          );
          unresolvedOutpost = firedClauses (
            evalBare "aarch64-darwin" {
              enable = true;
              outposts = { };
              tokenFile = dummyTokenPath;
            }
          );
        };
        expected = {
          darwinAgents = [
            "devin-worker-1"
            "devin-worker-2"
          ];
          darwinUnits = [ ];
          darwinPlistEnvKeys = [ "PATH" ];
          darwinWorkDirsDistinct = true;

          linuxUnits = [
            "devin-worker-1"
            "devin-worker-2"
          ];
          linuxAgents = [ ];
          linuxUnitEnvNames = [ "PATH" ];
          linuxWorkDirsDistinct = true;

          wellFormed = [ ];
          tokenless = [ "token" ];
          platformMismatch = [ "platform" ];
          unknownOutpost = [ "unknown-outpost" ];
          unresolvedOutpost = [ "unset-outpost" ];
        };
      };
    };
}
