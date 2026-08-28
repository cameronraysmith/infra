# Structural checks for nixbot's vanixiets wiring.
#
# Both assertions guard failure modes that are indistinguishable from success
# by inspection, which is why they are regulators rather than a one-off
# verification.
#
# nixbot-vanixiets-repo-config guards the repository-root nixbot.toml. nixbot
# swallows a TOML parse error and a schema violation alike, returning all
# defaults rather than falling back to buildbot-nix.toml, so a typo there
# silently restores the whole-flake evaluation and pull-request effect dispatch
# the file exists to prevent. Parsing at eval time turns that into a diff.
#
# nixbot-vanixiets-wiring guards the secret name transform. nixbot derives the
# systemd credential name it looks a repository's secrets up under by
# substituting ":" and "/" in the perRepoSecretFiles key; when that name does
# not match, the daemon finds no secrets, delivers an empty set, and every
# effect stops at its own missing-secret guard — exactly what an unwired
# service does. The check reads the name off the evaluated unit, so it
# exercises nixbot's own module code rather than a transcription of it.
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
      sortedNames = attrset: lib.naturalSort (builtins.attrNames attrset);

      magnetite = self.nixosConfigurations.magnetite.config;
      nixbot = magnetite.services.nixbot;
      buildbot = magnetite.services.buildbot-nix.master;

      repoKey = "github:cameronraysmith/vanixiets";

      # LoadCredential entries are "<name>:<source path>". The name never
      # contains a colon, because the transform that builds it replaces every
      # colon in the repository key, so the first field is exact. Keeping only
      # the name also keeps the oracle free of activation-time paths.
      credentialName = entry: builtins.head (lib.splitString ":" entry);
      effectsCredentialNames = lib.naturalSort (
        builtins.filter (lib.hasPrefix "effects-secret__") (
          map credentialName magnetite.systemd.services.nixbot.serviceConfig.LoadCredential
        )
      );
    in
    {
      checks = {
        nixbot-vanixiets-repo-config = mkCheck {
          name = "nixbot-vanixiets-repo-config";
          actual = builtins.fromTOML (builtins.readFile ../../nixbot.toml);
          expected = {
            attribute = "checks.x86_64-linux";
            effects_branches = [ ];
            effects_on_pull_requests = false;
          };
        };
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        nixbot-vanixiets-wiring = mkCheck {
          name = "nixbot-vanixiets-wiring";
          actual = {
            effectsCredentialNames = effectsCredentialNames;
            nixbotSecretKeys = sortedNames nixbot.effects.perRepoSecretFiles;
            buildbotSecretKeys = sortedNames buildbot.effects.perRepoSecretFiles;

            # A boolean rather than the path itself: the assertion is that the
            # two services read one file, and the path is activation-time state
            # that would churn the oracle without adding evidence.
            oneSecretsFileForBothServices =
              nixbot.effects.perRepoSecretFiles.${repoKey} == buildbot.effects.perRepoSecretFiles.${repoKey};

            repoAllowlist = nixbot.github.repoAllowlist;
            postBuildStepNames = map (step: step.name) nixbot.postBuildSteps;
            niks3ServerUrl = nixbot.niks3.serverUrl;

            # Effects run in the sandbox the service configures. Nothing
            # vanixiets' effects do needs widening it, and recording the empty
            # state makes a later widening a reviewable diff rather than a
            # silent grant.
            extraSandboxPaths = nixbot.effects.extraSandboxPaths;
            mountables = sortedNames nixbot.effects.mountables;
            extraNixOptions = sortedNames nixbot.effects.extraNixOptions;
          };
          expected = {
            # ironstar stays on buildbot-nix, so its secrets file is wired
            # only there and nixbot never loads a credential for it.
            effectsCredentialNames = [
              "effects-secret__github_colon_cameronraysmith_slash_vanixiets"
            ];
            nixbotSecretKeys = [ "github:cameronraysmith/vanixiets" ];
            buildbotSecretKeys = [
              "github:cameronraysmith/vanixiets"
              "github:sciexp/ironstar"
            ];
            oneSecretsFileForBothServices = true;
            repoAllowlist = [ "cameronraysmith/vanixiets" ];
            postBuildStepNames = [ "Upload to niks3" ];
            niks3ServerUrl = "https://niks3.scientistexperience.net";
            extraSandboxPaths = [ ];
            mountables = [ ];
            extraNixOptions = [ ];
          };
        };
      };
    };
}
