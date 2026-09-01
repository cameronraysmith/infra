# Devin CLI, vendored from nixpkgs pkgs/by-name/de/devin-cli.
#
# The derivation body is upstream's, unmodified. It lives here because the
# pinned nixpkgs channel carries 3000.3.22 while the Outposts worker surface
# this repository declares (`services.devin-worker`) is documented against the
# 3000.6 CLI. modules/nixpkgs/compose.nix merges the by-name set into
# flake.overlays.default after the channel overlays, so this attribute shadows
# the channel's `devin-cli` on every machine; `nix run .#update-devin-cli`
# keeps it current independently of the channel bump.
{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  versionCheckHook,
}:

let
  version = "3000.6.7";

  throwSystem = throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}";

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://static.devin.ai/cli/${version}/devin-${version}-x86_64-unknown-linux.tar.gz";
      hash = "sha256-+I7azqaSVTkQ1y8nVRW9C1K10nHVUlCYGwxBARFC0ns=";
    };

    aarch64-linux = fetchurl {
      url = "https://static.devin.ai/cli/${version}/devin-${version}-aarch64-unknown-linux.tar.gz";
      hash = "sha256-jelew2I9k+bzywg0+mWf19ZpjU/v8/t+dS6XerxApuA=";
    };

    aarch64-darwin = fetchurl {
      url = "https://static.devin.ai/cli/${version}/devin-${version}-aarch64-apple-darwin.tar.gz";
      hash = "sha256-/dBoEgd9XP7lZM7XolbQueJD7kZ9VSGUJmKXFETF2lQ=";
    };
  };
in

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "devin-cli";
  inherit version;

  outputs = [
    "out"
    "man"
    "doc"
  ];

  strictDeps = true;
  __structuredAttrs = true;

  src = srcs.${stdenvNoCC.hostPlatform.system} or throwSystem;

  sourceRoot = ".";

  nativeBuildInputs = [ installShellFiles ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    installBin ./bin/devin
    installManPage ./share/man/man1/*.1

    mkdir -p $out/share/doc

    mv ./share/devin/docs/* $out/share/doc

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Cognition's Devin Agent CLI";
    homepage = "https://devin.ai/cli";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = with lib.maintainers; [
      ethancedwards8
      nhshah15
    ];
    mainProgram = "devin";
  };
})
