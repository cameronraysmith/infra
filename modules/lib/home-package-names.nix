# homePackageNames: the sorted `lib.getName` of every `home.packages` entry,
# keyed `user@system`, for the homeConfigurations of one system.
# Read by `just home-package-names`; diff its output across two revisions to
# review a change that claims to relocate declarations without altering them.
{ self, lib, ... }:
{
  flake.lib.homePackageNames =
    system:
    lib.mapAttrs (
      _: home: builtins.sort builtins.lessThan (map lib.getName home.config.home.packages)
    ) (lib.filterAttrs (key: _: lib.hasSuffix "@${system}" key) self.homeConfigurations);
}
