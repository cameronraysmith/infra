# atomic is Bastani's terminal coding agent, packaged from the upstream
# prebuilt release tarball. Each archive is produced by `bun build --compile`
# as a split launcher: a small `atomic` executable that resolves `app.js` and a
# prebundled node_modules relative to the directory of its own execPath. Bun
# resolves execPath through symlinks, but the launcher is wrapped rather than
# symlinked so the runtime tool lookups below can be satisfied. The napi
# natives ship prebuilt in that bundle, so nothing here needs a Rust toolchain
# and the release archive is preferred over the published npm package.
#
# Version and per-platform checksums live in manifest.json alongside this file
# rather than in this expression.
#
# update: nix run .#update-atomic
# source: https://github.com/bastani-inc/atomic
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  jq,
  fd,
  ripgrep,
}:
let
  manifest = lib.importJSON ./manifest.json;
  platforms = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    aarch64-darwin = "darwin-arm64";
  };
  platform = platforms.${stdenv.hostPlatform.system} or null;
in
# The flake forces `checks.<system>` for every system it evaluates, so a system
# outside the map has to make this attribute absent rather than throw when the
# derivation is forced.
if platform == null then
  null
else
  stdenv.mkDerivation (finalAttrs: {
    pname = "atomic";
    inherit (manifest) version;

    src = fetchurl {
      url = "https://github.com/bastani-inc/atomic/releases/download/${finalAttrs.version}/atomic-${platform}.tar.gz";
      sha256 = manifest.platforms.${platform}.checksum;
    };

    sourceRoot = "atomic";

    dontConfigure = true;
    dontBuild = true;

    # the launcher carries its bytecode payload past the end of the executable
    # image, which stripping discards
    dontStrip = true;

    nativeBuildInputs = [
      makeBinaryWrapper
    ]
    ++ lib.optionals stdenv.hostPlatform.isElf [
      autoPatchelfHook
      jq
    ];

    buildInputs = lib.optionals stdenv.hostPlatform.isElf [
      stdenv.cc.cc.lib
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib"
      cp -R . "$out/lib/atomic"

      # atomic resolves fd and rg from PATH and otherwise downloads a release
      # binary from GitHub at first use, which cannot run against this libc.
      # PATH is suffixed so the caller's own tools still win.
      makeWrapper "$out/lib/atomic/atomic" "$out/bin/atomic" \
        --set ATOMIC_SKIP_VERSION_CHECK 1 \
        --suffix PATH : ${
          lib.makeBinPath [
            fd
            ripgrep
          ]
        }

      runHook postInstall
    '';

    # @embedded-postgres carries its shared libraries as versioned files with
    # the SONAME links recorded in native/pg-symlinks.json, which upstream's
    # npm postinstall recreates; a release tarball never runs that script, so
    # the links are absent. The postgres binaries resolve their libraries
    # through an $ORIGIN-relative rpath, so without the links autoPatchelf
    # cannot satisfy libicuuc.so.60 and the durable-workflow database has no
    # runtime. Upstream ships this payload in the linux-x64 archive only.
    postInstall = lib.optionalString stdenv.hostPlatform.isElf ''
      for pkgdir in "$out"/lib/atomic/node_modules/@embedded-postgres/*/; do
        [ -f "$pkgdir/native/pg-symlinks.json" ] || continue
        jq -r '.[] | [.source, .target] | @tsv' "$pkgdir/native/pg-symlinks.json" \
          | while IFS=$'\t' read -r source target; do
            ln -s "$(basename "$source")" "$pkgdir$target"
          done
      done
    '';

    # postgres's procedural-language handlers link against the interpreters of
    # the distribution that built them. atomic loads no PL handler, and nixpkgs
    # carries none of these interpreter versions.
    autoPatchelfIgnoreMissingDeps = [
      "libperl.so.5.26"
      "libpython3.6m.so.1.0"
      "libtcl8.6.so"
    ];

    nativeInstallCheckInputs = [
      versionCheckHook
      writableTmpDirAsHomeHook
    ];
    versionCheckKeepEnvironment = [ "HOME" ];
    doInstallCheck = true;

    # the launcher answers --version itself, before importing the sidecar
    # bundle, so only --help proves the payload resolved
    postInstallCheck = ''
      "$out/bin/atomic" --help | grep -q "AI coding assistant"
    '';

    strictDeps = true;

    passthru.updateScript = ./update.sh;

    meta = {
      description = "Coding agent CLI with read, bash, edit, and write tools and session management";
      homepage = "https://github.com/bastani-inc/atomic";
      changelog = "https://github.com/bastani-inc/atomic/releases/tag/${finalAttrs.version}";
      # LICENSE is the MIT text plus a clause requiring a product above 100
      # million monthly active users or $20 million monthly revenue to display
      # 'Atomic' in its interface. That condition is not part of MIT and has no
      # SPDX identifier, so lib.licenses.mit would misstate the terms; the
      # repository's package.json nonetheless declares MIT and GitHub reports
      # the license as NOASSERTION.
      license = {
        shortName = "MIT-with-atomic-attribution";
        fullName = "MIT License with Atomic attribution requirement";
        url = "https://github.com/bastani-inc/atomic/blob/main/LICENSE";
        free = true;
        redistributable = true;
      };
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      mainProgram = "atomic";
      platforms = lib.attrNames platforms;
      maintainers = with lib.maintainers; [ cameronraysmith ];
    };
  })
