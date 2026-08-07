{
  lib,
  buildNpmPackage,
  fetchurl,
  gh,
  git,
  jq,
  makeWrapper,
  nodejs_22,
  runCommand,
}:

let
  version = "0.1.29";

  # The npm registry tarball carries the built dist/ tree but no lockfile, and
  # the GitHub repo carries a pnpm-lock.yaml that buildNpmPackage cannot read.
  # Splice in a package-lock.json generated from the published package.json with
  # devDependencies removed, so `npm ci` resolves runtime deps only. The scripts
  # block goes too: npmInstallHook's `npm pack` fires prepack/prepare, which run
  # `tsc` against a src/ tree the registry tarball does not ship, and npm 10
  # runs `prepare` even under --ignore-scripts.
  src = runCommand "gh-axi-source-${version}" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/gh-axi/-/gh-axi-${version}.tgz";
        hash = "sha256-2GMZ59vDc4LCdWBHkRT3hKgqnJtHl4af/wGUhQikw20=";
      }
    } -C $out --strip-components=1
    jq 'del(.devDependencies, .scripts)' $out/package.json > $out/package.json.stripped
    mv $out/package.json.stripped $out/package.json
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "gh-axi";
  inherit version src;

  nodejs = nodejs_22;

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-RwgGz7V6F5+f35XqHBP6qcjGEYd4pgwA4jDTgDtL9R0=";

  makeCacheWritable = true;

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  # dist/src/gh.js shells out to `gh` and dist/src/host.js to `git`.
  postInstall = ''
    wrapProgram $out/bin/gh-axi \
      --prefix PATH : ${
        lib.makeBinPath [
          gh
          git
        ]
      }
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "GitHub CLI for agents, designed with AXI (Agent eXperience Interface)";
    homepage = "https://github.com/kunchenguid/gh-axi";
    changelog = "https://github.com/kunchenguid/gh-axi/releases/tag/v${version}";
    downloadPage = "https://www.npmjs.com/package/gh-axi";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "gh-axi";
    platforms = lib.platforms.unix;
  };
}
