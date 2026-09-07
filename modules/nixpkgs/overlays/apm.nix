# apm-skill-bundle-workaround: patch apm so SKILL_BUNDLE dependencies install
#
# Upstream: https://github.com/microsoft/apm — the 0.29.1 download-validation
# gate rejects nested skills/<name>/SKILL.md packages, which breaks
# pkgs.apm-skills-compose (github/gh-stack) and every darwin activation with it.
# Full regression narrative in ./apm-skill-bundle-download.patch. Linear CAM-55.
# TODO: Remove this module and the patch beside it when upstream's cascade
# handles PackageType.SKILL_BUNDLE. The expiry signal is the patch failing to
# apply, which fails the build: either upstream handled SKILL_BUNDLE, in which
# case revert the whole apm-skill-bundle-workaround commit, or upstream only
# refactored that region, in which case rebase the patch.
# Date added: 2026-09-07
#
# The src re-pin is a second, independent breakage: microsoft/apm moved the
# v0.30.0 tag after numtide/llm-agents.nix pinned its hash, so the input's own
# fetch no longer resolves. The rev below reproduces today's v0.30.0 tag. It is
# applied only while the input still claims 0.30.0, and a version bump degrades
# to a warning rather than an error because llm-agents is bumped frequently.
{ inputs, ... }:
{
  nixpkgsOverlays = [
    (
      final: prev:
      let
        inherit (prev) lib;
        upstream = inputs.llm-agents.packages.${prev.stdenv.hostPlatform.system}.apm;
        brokenSrcVersion = "0.30.0";
        srcFix = lib.optionalAttrs (upstream.version == brokenSrcVersion) {
          src = final.fetchFromGitHub {
            owner = "microsoft";
            repo = "apm";
            rev = "8c2e0d9c352e2ed0e8c56b40063a63e1dd4a1937";
            hash = "sha256-RbrqY7JampXAe3tfPnjx4FXSEi0K4b5fQ00yGeov5k8=";
          };
        };
      in
      {
        apm =
          lib.warnIf (upstream.version != brokenSrcVersion)
            ''
              apm-skill-bundle-workaround: apm is ${upstream.version}, src re-pin recorded for ${brokenSrcVersion}.
              Using the input's own src; the SKILL_BUNDLE patch still applies.
            ''
            (
              upstream.overrideAttrs (
                old:
                srcFix
                // {
                  patches = (old.patches or [ ]) ++ [ ./apm-skill-bundle-download.patch ];
                }
              )
            );
      }
    )
  ];
}
