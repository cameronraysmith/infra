# One structural regulator for the atomic/pi extension divergence.
#
# The atomic analogue of modules/checks/pi-agent-environment.nix, sharing its
# mechanism: mkStructuralCheck diffs eval-time home-manager values against a
# literal oracle, so a failure names the violated claim as a unified diff.
#
# What this guards. modules/home/ai/agent-settings.nix generates one settings
# payload for two agents, and `packages` is the single key they do not share
# verbatim: atomic takes packagesForAtomic, which appends
# atomicExtensionExclusions as `-`-prefixed force-excludes. The divergence is
# deliberate and one-sided, and both halves have to hold at once — atomic must
# exclude statusline because atomic 0.9.13's isolated interactive engine refuses
# ctx.ui.setFooter, and pi must keep it because pi honours that call in-process.
# Asserting only atomic's half would pass a change that silently disarmed the
# extension for both agents.
#
# Falsifiability: dropping "statusline/index.ts" from atomicExtensionExclusions
# flips atomicNegativeExtensions against the literal below; propagating the
# exclusion to pi flips piNegativeExtensions.
#
# The retraction claim is why atomicDeclaresPackages is asserted separately
# rather than inferred from the selector lists. modules/home/ai/atomic/
# merge-settings.sh can update a nix-owned key but not retract one, so a change
# that stopped declaring `packages` would leave whatever value last reached
# ~/.atomic/agent/settings.json frozen there. That failure is invisible in the
# generated payload and visible only as the key's absence.
#
# Evidence boundary. This claims declaration shape alone: that the two agents'
# settings carry the selectors named below. It does not claim that atomic
# resolves those selectors as intended at runtime, which is upstream behavior
# (core/package-manager-resource-patterns.ts applies force-excludes last), nor
# that the extension package's contents are what its name suggests.
{ self, lib, ... }:
{
  perSystem =
    {
      pkgs,
      self',
      system,
      ...
    }:
    let
      mkCheck = self.lib.mkStructuralCheck pkgs;
      homeConfig = self.homeConfigurations."crs58@${system}".config;
      atomicConfig = homeConfig.programs.atomic;
      piConfig = homeConfig.programs.pi-coding-agent;
      extensionPackage = self'.packages.pi-agent-extensions or null;
      extensionSource = if extensionPackage == null then null else toString extensionPackage;
      selectorsFor =
        settings:
        let
          entry = lib.findFirst (
            candidate: builtins.isAttrs candidate && (candidate.source or null) == extensionSource
          ) null (settings.packages or [ ]);
        in
        if entry == null then [ ] else entry.extensions or [ ];
      atomicSelectors = selectorsFor atomicConfig.settings;
      piSelectors = selectorsFor piConfig.settings;
      positive = builtins.filter (selector: !lib.hasPrefix "-" selector);
      negative = builtins.filter (selector: lib.hasPrefix "-" selector);
    in
    {
      checks = {
        atomic-agent-environment-structural = mkCheck {
          name = "atomic-agent-environment";
          actual = {
            atomicDeclaresPackages = builtins.hasAttr "packages" atomicConfig.settings;
            atomicPositiveExtensions = positive atomicSelectors;
            atomicNegativeExtensions = negative atomicSelectors;
            piPositiveExtensions = positive piSelectors;
            piNegativeExtensions = negative piSelectors;
            # The divergence must live in the selectors, not in a forked package:
            # two sources would make the lists incomparable and the exclusion
            # meaningless.
            sharedExtensionSource = atomicSelectors != [ ] && piSelectors != [ ];
          };
          expected = {
            atomicDeclaresPackages = true;
            atomicPositiveExtensions = [
              "direnv/index.ts"
              "permission-gate/index.ts"
              "questionnaire/index.ts"
              "slow-mode/index.ts"
              "stash/index.ts"
              "statusline/index.ts"
            ];
            # statusline is force-excluded rather than removed from the positive
            # list: atomic applies `-` entries last and unconditionally, so the
            # exclusion survives a later change that widens the include set.
            atomicNegativeExtensions = [
              "-fetch/index.ts"
              "-notify/index.ts"
              "-statusline/index.ts"
            ];
            piPositiveExtensions = [
              "direnv/index.ts"
              "permission-gate/index.ts"
              "questionnaire/index.ts"
              "slow-mode/index.ts"
              "stash/index.ts"
              "statusline/index.ts"
            ];
            piNegativeExtensions = [
              "-fetch/index.ts"
              "-notify/index.ts"
            ];
            sharedExtensionSource = true;
          };
        };
      };
    };
}
