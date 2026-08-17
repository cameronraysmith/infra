# The sole runtime dependency, `ws`, is deliberately not vendored: it is imported
# lazily (src/openai-ws-connection.ts) from a WebSocket transport that the
# isDirectOpenAIResponsesModel gate makes unreachable on the Codex provider, and
# its absence degrades to SSE rather than failing.
{
  fetchFromGitHub,
  jq,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "pi-openai-server-compaction";
  version = "0.1.0-unstable-2026-07-23";

  src = fetchFromGitHub {
    owner = "algal";
    repo = "pi-openai-server-compaction";
    rev = "8a3de2f3b0c178fdd6f73f2f94172dfc3943e466";
    hash = "sha256-HFzG+GMriPhoMinjji+3sklQ7Nq0yRHCz/t9Re/TksU=";
  };

  nativeBuildInputs = [ jq ];

  dontConfigure = true;
  dontBuild = true;
  strictDeps = true;

  # atomic reads package.json#atomic before falling back to package.json#pi
  # (packages/coding-agent/src/core/package-manager-manifest.ts:24-27), while pi
  # reads only package.json#pi, so an empty `atomic.extensions` makes this
  # package contribute nothing to atomic while remaining fully active under pi.
  # atomic 0.9.13 omits @earendil-works/pi-coding-agent from its virtualModules
  # map and src/remote-compaction.ts imports that specifier as a value, so
  # without this block every atomic startup is a fatal extension-load error.
  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R . "$out/"
    jq '. + {atomic: {extensions: []}}' package.json > "$out/package.json"

    runHook postInstall
  '';

  meta = {
    description = "Pi extension for OpenAI server-side compaction with Codex-quality continuity";
    homepage = "https://github.com/algal/pi-openai-server-compaction";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
  };
}
