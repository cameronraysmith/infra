{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  protobuf,
  cmake,
  pkg-config,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "omnigraph";
  version = "0.9.0-unstable-2026-08-05";

  src = fetchFromGitHub {
    owner = "ModernRelay";
    repo = "omnigraph";
    rev = "12a8596626c80a7dceed0fd72182d421052ff8d1";
    hash = "sha256-Llw1i4q4R84zn1NDZNPiv010RxcTicu/aWC7vDwmTK4=";
  };

  cargoHash = "sha256-Nrir7HamhM/A86TNFD8hkqzS8V7bG9BkRSgF+Agd7/A=";

  # Workaround for the stdarch/LLVM 21 signature mismatch on the AVX-512 VNNI intrinsics retyped by
  # https://github.com/llvm/llvm-project/pull/155194; the deleted lines are runtime-dispatch arms,
  # so removing them falls back to the AVX2 and scalar kernels.
  postPatch = ''
    lanceDistance="$cargoDepsCopy/source-registry-0/lance-linalg-9.0.0/src/distance"

    substituteInPlace "$lanceDistance/dot_u8.rs" \
      --replace-fail "return |a, b| unsafe { x86::dot_u8_avx512_vnni(a, b) };" ""

    substituteInPlace "$lanceDistance/l2_u8.rs" \
      --replace-fail "return |a, b| unsafe { x86::l2_u8_avx512_vnni(a, b) };" ""

    substituteInPlace "$lanceDistance/cosine_u8.rs" \
      --replace-fail "return |a, b| unsafe { x86::cosine_u8_accum_avx512_vnni(a, b) };" ""
  '';

  nativeBuildInputs = [
    protobuf
    cmake
    pkg-config
  ];

  cargoBuildFlags = [
    "-p"
    "omnigraph-cli"
    "-p"
    "omnigraph-server"
  ];

  env = {
    OMNIGRAPH_SOURCE_VERSION = finalAttrs.src.rev;
  }
  # ctor emits its constructor into __TEXT,__text_startup, past the +/-128 MiB reach of the ARM64
  # b/bl branching back into __text, and ld64's island pass skips that section; upstream's macos-14
  # release job sets the same flag. force-frame-pointers is restated because setting RUSTFLAGS
  # suppresses rather than merges with nixpkgs' [target.<triple>].rustflags.
  // lib.optionalAttrs stdenv.hostPlatform.isDarwin {
    RUSTFLAGS = "-C code-model=large -C force-frame-pointers=yes";
  };

  doCheck = false;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    "$out/bin/omnigraph" --help > /dev/null
    "$out/bin/omnigraph-server" --help > /dev/null

    runHook postInstallCheck
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    homepage = "https://github.com/ModernRelay/omnigraph";
    description = "Lakehouse graph database server and CLI";
    license = lib.licenses.mit;
    mainProgram = "omnigraph";
    maintainers = with lib.maintainers; [ cameronraysmith ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
