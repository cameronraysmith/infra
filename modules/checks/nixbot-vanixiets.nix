# Structural check for nixbot's vanixiets wiring.
#
# It guards the secret name transform, a failure mode indistinguishable from
# success by inspection. nixbot derives the systemd credential name it looks a
# repository's secrets up under by substituting ":" and "/" in the
# perRepoSecretFiles key; when that name does not match, the daemon finds no
# secrets, delivers an empty set, and every effect stops at its own
# missing-secret guard — exactly what an unwired service does. The check reads
# the name off the evaluated unit, so it exercises nixbot's own module code
# rather than a transcription of it, and also pins the allowlist, the cache
# step, the shared secrets file, and the deliberately empty sandbox options.
#
# There is deliberately no nixbot.toml: nixbot falls back to buildbot-nix.toml,
# whose dispatch keys both services need to agree on anyway, and a second file
# holding identical values could only drift.
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

      # Each service's own repository filter, transcribed with its citation so
      # the two selections can be asserted rather than described. Both take
      # the topic first and then the allowlists; only the allowlist stage is
      # modelled here, because a forge topic is not visible to evaluation.
      # Both repositories below carry the topic, so the allowlist stage is
      # what each service's selection reduces to.
      owner = fullName: builtins.head (lib.splitString "/" fullName);

      # buildbot_nix/buildbot_nix/common.py:138-148, with full_name as the
      # repo accessor (github_projects.py:225). The two allowlists are OR'd.
      buildbotAdmits =
        fullName:
        let
          f = buildbot.github;
        in
        (f.userAllowlist == null && f.repoAllowlist == null)
        || (f.userAllowlist != null && builtins.elem (owner fullName) f.userAllowlist)
        || (f.repoAllowlist != null && builtins.elem fullName f.repoAllowlist);

      # nixbot/nixbot/forge/base.py:128-141, the same shape.
      nixbotAdmits =
        fullName:
        let
          f = nixbot.github;
        in
        (f.userAllowlist == null && f.repoAllowlist == null)
        || (f.userAllowlist != null && builtins.elem (owner fullName) f.userAllowlist)
        || (f.repoAllowlist != null && builtins.elem fullName f.repoAllowlist);
    in
    {
      checks = lib.optionalAttrs (system == "x86_64-linux") {
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

            # The cut itself. buildbot stays authoritative for ironstar while
            # nixbot also admits it, so the two selections overlap there and
            # differ on vanixiets.
            buildbotAdmitsVanixiets = buildbotAdmits "cameronraysmith/vanixiets";
            buildbotAdmitsIronstar = buildbotAdmits "sciexp/ironstar";
            nixbotAdmitsVanixiets = nixbotAdmits "cameronraysmith/vanixiets";
            nixbotAdmitsIronstar = nixbotAdmits "sciexp/ironstar";

            # An owner allowlist would readmit vanixiets regardless of the
            # repository list, because the two are OR'd.
            buildbotUserAllowlist = buildbot.github.userAllowlist;
            buildbotRepoAllowlist = buildbot.github.repoAllowlist;
            nixbotRepoAllowlist = nixbot.github.repoAllowlist;
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
            # ironstar's secrets file is wired only to buildbot's convention,
            # so nixbot loads no credential for it: admitted for evaluation,
            # building and caching, with its effects failing closed.
            effectsCredentialNames = [
              "effects-secret__github_colon_cameronraysmith_slash_vanixiets"
            ];
            nixbotSecretKeys = [ "github:cameronraysmith/vanixiets" ];
            buildbotSecretKeys = [
              "github:cameronraysmith/vanixiets"
              "github:sciexp/ironstar"
            ];
            oneSecretsFileForBothServices = true;
            buildbotAdmitsVanixiets = false;
            buildbotAdmitsIronstar = true;
            nixbotAdmitsVanixiets = true;
            nixbotAdmitsIronstar = true;
            buildbotUserAllowlist = null;
            buildbotRepoAllowlist = [ "sciexp/ironstar" ];
            nixbotRepoAllowlist = [
              "cameronraysmith/vanixiets"
              "sciexp/ironstar"
            ];
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
