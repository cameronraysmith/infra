# Structural check for stibnite's aarch64-darwin build access.
#
# It guards the pairing between two machines' configurations, which no single
# machine's evaluation can catch. magnetite generates two keypairs and stibnite
# authorizes them under two different accounts; swapping them, or authorizing
# the build key without its forced command, produces a configuration that
# builds and activates and is wrong in the one way that matters — the build
# key would carry an interactive login, or the independently revocable
# identities would be assigned to the wrong accounts.
#
# It also pins the two mechanisms to one account: the nix.buildMachines entry
# (result copied back to the caller) and the remote-store URI (build stays in
# stibnite's store) must name the same user and the same ssh alias, or one of
# them silently reaches an account that authorizes nothing.
{
  self,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      mkCheck = self.lib.mkStructuralCheck pkgs;

      magnetite = self.nixosConfigurations.magnetite.config;
      stibnite = self.darwinConfigurations.stibnite.config;

      buildKey =
        lib.removeSuffix "\n"
          magnetite.clan.core.vars.generators.stibnite-nix-build.files."key.pub".value;
      sessionKey =
        lib.removeSuffix "\n"
          magnetite.clan.core.vars.generators.stibnite-agent-session.files."key.pub".value;

      authorized = user: stibnite.environment.etc."ssh/nix_authorized_keys.d/${user}".text;
      authorizedLines = user: builtins.filter (line: line != "") (lib.splitString "\n" (authorized user));

      darwinEntries = builtins.filter (
        m: builtins.elem "aarch64-darwin" m.systems
      ) magnetite.nix.buildMachines;
      darwinEntry = builtins.head darwinEntries;

      # The forced command names an activation-time store path, so the oracle
      # asserts its shape: the key options, and that the program is the
      # nix-daemon of the nix package stibnite activates.
      buildLine = builtins.head (authorizedLines "nixbuild");
      forcedCommand = ''restrict,command="${stibnite.nix.package}/bin/nix-daemon --stdio"'';
    in
    {
      checks =
        lib.optionalAttrs
          (builtins.elem system [
            "x86_64-linux"
            "aarch64-darwin"
          ])
          {
            stibnite-access-wiring = mkCheck {
              name = "stibnite-access-wiring";
              actual = {
                darwinBuilderCount = builtins.length darwinEntries;
                darwinBuilder = {
                  inherit (darwinEntry)
                    hostName
                    sshUser
                    protocol
                    systems
                    maxJobs
                    supportedFeatures
                    ;
                };

                # Both mechanisms, one account and one alias.
                storeUriNamesBuildAccount =
                  magnetite.environment.etc."nix/stibnite-store-uri".text
                  == "ssh-ng://${darwinEntry.sshUser}@${darwinEntry.hostName}?ssh-key=${darwinEntry.sshKey}\n";

                # Key separation, asserted in both directions.
                buildAccountAuthorizes = authorizedLines "nixbuild";
                sessionKeyIsNotABuildKey = !(lib.hasInfix sessionKey (authorized "nixbuild"));
                buildKeyIsNotASessionKey = !(lib.hasInfix buildKey (authorized "crs58"));
                sessionKeyAuthorizedForSessions = lib.hasInfix sessionKey (authorized "crs58");

                # The build key carries a forced command and nothing else.
                buildLineIsRestrictedToTheProtocol = buildLine == "${forcedCommand} ${buildKey}";

                buildAccountIsTrusted = builtins.elem "nixbuild" stibnite.nix.settings.trusted-users;
                buildAccountIsManaged = builtins.elem "nixbuild" stibnite.users.knownUsers;
              };
              expected = {
                darwinBuilderCount = 1;
                darwinBuilder = {
                  hostName = "stibnite-builder";
                  sshUser = "nixbuild";
                  protocol = "ssh-ng";
                  systems = [ "aarch64-darwin" ];
                  maxJobs = 4;
                  supportedFeatures = [
                    "apple-virt"
                    "big-parallel"
                  ];
                };
                storeUriNamesBuildAccount = true;
                buildAccountAuthorizes = [ "${forcedCommand} ${buildKey}" ];
                sessionKeyIsNotABuildKey = true;
                buildKeyIsNotASessionKey = true;
                sessionKeyAuthorizedForSessions = true;
                buildLineIsRestrictedToTheProtocol = true;
                buildAccountIsTrusted = true;
                buildAccountIsManaged = true;
              };
            };
          };
    };
}
