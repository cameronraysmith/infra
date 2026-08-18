# lajarre/pi-vim, packaged from the published npm distribution.
#
# The npm tarball rather than fetchFromGitHub, for three independent reasons.
# The repository ships a top-level `doc/` directory, which stdenv's
# `forceShare = [ "man" "doc" "info" ]` silently relocates to share/doc during
# fixup; the tarball's `files` list excludes it. Upstream has 7 git tags against
# 24 npm versions with a hole from 0.3.2 to 0.13.0, so a tag-tracking
# nix-update-script would never fire. And upstream publishes no GitHub releases,
# so a `changelog` meta line would 404.
#
# The tarball unpacks to `package/`, hence sourceRoot; its sha256 is
# cross-checkable against the registry's published dist.integrity.
{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pi-vim";
  version = "0.14.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/pi-vim/-/pi-vim-${finalAttrs.version}.tgz";
    hash = "sha256-gAsnQvbaNS7ug9tQPFQhwhXtHLrrO2mHBiNQLh9ZGQs=";
  };

  sourceRoot = "package";

  dontConfigure = true;
  dontBuild = true;
  strictDeps = true;

  # clipboard-mirror.ts resolves the host agent's module URL at module scope, to
  # embed it in the source of a clipboard helper child process. `import.meta.resolve`
  # throws on a specifier pi satisfies through its virtual-module map rather than
  # through node_modules, and a throw at module scope is a fatal extension-load
  # error for the whole extension, not just the clipboard mirror. The bare
  # specifier is what the child would need anyway; it degrades the OS-clipboard
  # mirror instead of the editor. Re-derive this call site on every version bump:
  # --replace-fail turns a moved or reworded call into a build failure rather
  # than a silently unpatched output.
  postPatch = ''
    substituteInPlace clipboard-mirror.ts --replace-fail \
      'import.meta.resolve(
      "@earendil-works/pi-coding-agent",
    )' \
      '"@earendil-works/pi-coding-agent"'
  '';

  installPhase = ''
    runHook preInstall

    sourceNodeModules=$(find . -type d -name node_modules -print -quit)
    if [ -n "$sourceNodeModules" ]; then
      echo "pi-vim source contains node_modules: $sourceNodeModules" >&2
      exit 1
    fi

    mkdir -p "$out"
    cp -R . "$out/"

    runHook postInstall
  '';

  meta = {
    description = "Vim-style modal editing for Pi's TUI editor";
    homepage = "https://github.com/lajarre/pi-vim";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
  };
})
