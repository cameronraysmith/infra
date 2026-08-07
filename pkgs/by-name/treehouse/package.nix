{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  nix-update-script,
  versionCheckHook,
}:

buildGoModule (finalAttrs: {
  pname = "treehouse";
  version = "2.1.1";

  src = fetchFromGitHub {
    owner = "kunchenguid";
    repo = "treehouse";
    tag = "v${finalAttrs.version}";
    hash = "sha256-nybPc6SXPxw5MZIFrjrmJDno9aMH2R4uZz0U8rayAOo=";
  };

  vendorHash = "sha256-z8IndcHcZ6nLqhLtAYul3ppddpOA4AHGQWIlfYY/pfI=";

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${finalAttrs.version}"
  ];

  nativeBuildInputs = [ makeWrapper ];

  # The test suite drives real git worktrees and long-running e2e daemons.
  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/treehouse \
      --set-default TREEHOUSE_NO_UPDATE_CHECK 1
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Manage git worktrees without managing worktrees";
    homepage = "https://github.com/kunchenguid/treehouse";
    changelog = "https://github.com/kunchenguid/treehouse/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    mainProgram = "treehouse";
    platforms = lib.platforms.unix;
  };
})
