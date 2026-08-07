{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  nix-update-script,
  versionCheckHook,
}:

buildGoModule (finalAttrs: {
  pname = "no-mistakes";
  version = "1.45.4";

  src = fetchFromGitHub {
    owner = "kunchenguid";
    repo = "no-mistakes";
    tag = "v${finalAttrs.version}";
    hash = "sha256-pfR60vack5oLItPfu4zDYYk76S8qhDOJP/uiudo7kVI=";
  };

  vendorHash = "sha256-NZOYxNYvt4192uqKBdKRxdgrKFvWx3585psdCnRdPSM=";

  env.CGO_ENABLED = "0";

  # Upstream's Makefile bakes an Umami analytics endpoint into the binary via
  # -X buildinfo.TelemetryHost and -X buildinfo.TelemetryWebsiteID. Omitting
  # both leaves the source defaults (empty), which disables the reporter.
  ldflags = [
    "-s"
    "-w"
    "-X github.com/kunchenguid/no-mistakes/internal/buildinfo.Version=v${finalAttrs.version}"
  ];

  subPackages = [ "cmd/no-mistakes" ];

  doCheck = false;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/no-mistakes \
      --set-default NO_MISTAKES_TELEMETRY 0 \
      --set-default NO_MISTAKES_NO_UPDATE_CHECK 1
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Pre-push guard that runs a repository's checks before code leaves the machine";
    homepage = "https://github.com/kunchenguid/no-mistakes";
    changelog = "https://github.com/kunchenguid/no-mistakes/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    mainProgram = "no-mistakes";
    platforms = lib.platforms.unix;
  };
})
