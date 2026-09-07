# Serverless vector database for AI applications
#
# Carried locally because nixpkgs' lancedb 0.32.0 does not build. It vendors
# ethnum 1.5.2 (transitively: lance-arrow -> jsonb 0.5.6 -> ethnum), whose
# tfie() constructs TryFromIntError with `mem::transmute(())`. A standard
# library layout change gave TryFromIntError a non-zero size, so that transmute
# fails E0512 under the rustc 1.97.0 this nixpkgs pin ships:
#
#   error[E0512]: cannot transmute between types of different sizes
#     --> ethnum-1.5.2/src/error.rs:16:14
#     source type: `()` (0 bits) / target type: `TryFromIntError` (8 bits)
#
# Fixed by https://github.com/nlordell/ethnum-rs/pull/58, released as ethnum
# 1.5.3, which builds the error via `u8::try_from(-1i8).unwrap_err()`.
# Upstream report: https://github.com/lance-format/lance/issues/6573
#
# lancedb 0.36.0 locks ethnum to 1.5.3. jsonb still requests "1.5.2", so the
# fix comes from the lockfile rather than a raised requirement; inspecting
# dependency requirements alone will not show it.
#
# Remove this package once nixpkgs ships a lancedb whose vendored ethnum is
# >= 1.5.3. The python3Packages.lancedb cross-reference this note referred to
# lived in modules/nixpkgs/overlays/python-overrides.nix, which no longer
# exists (deleted 2026-09-06 once its last binding was inert), so nothing
# routes lancedb away from nixpkgs today.
#
# Source: https://github.com/lancedb/lancedb
{
  lib,
  python3Packages,
  fetchFromGitHub,
  rustPlatform,
  openssl,
  pkg-config,
  protobuf,
  nix-update-script,
}:

python3Packages.buildPythonPackage (finalAttrs: {
  pname = "lancedb";
  version = "0.36.0";
  pyproject = true;
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "lancedb";
    repo = "lancedb";
    tag = "python-v${finalAttrs.version}";
    hash = "sha256-JOUrLHoVBZs4B8UGYFZIs00kzBnxFFAkTXFIz2bOZ7w=";
  };

  buildAndTestSubdir = "python";

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-KEczUf/e3+Eb53pouOzajp+yVjWctDUNbdVEgQVoCZE=";
  };

  build-system = [ rustPlatform.maturinBuildHook ];

  nativeBuildInputs = [
    pkg-config
    protobuf
    rustPlatform.cargoSetupHook
  ];

  buildInputs = [
    openssl
  ];

  dependencies =
    with python3Packages;
    [
      deprecation
      lance-namespace
      numpy
      packaging
      pyarrow
      pydantic
      tqdm
    ]
    ++ lib.optionals (python3Packages.pythonOlder "3.12") [
      python3Packages.overrides
    ];

  pythonImportsCheck = [ "lancedb" ];

  # The 0.36.0 test extra requires pylance ==9.0.0, datafusion >=54,<55, and
  # polars <=1.3.0; this nixpkgs pin provides 8.0.0, 53.0.0, and 1.42.1. To
  # restore nixpkgs cache parity, set doCheck to true and port the
  # nativeCheckInputs, preCheck, and disabled-test configuration from
  # pkgs/development/python-modules/lancedb/default.nix, recalibrating the
  # disabled-test list against this version.
  doCheck = false;

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "python-v(.*)"
    ];
  };

  meta = {
    description = "Developer-friendly, serverless vector database for AI applications";
    homepage = "https://github.com/lancedb/lancedb";
    changelog = "https://github.com/lancedb/lancedb/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ natsukium ];
  };
})
