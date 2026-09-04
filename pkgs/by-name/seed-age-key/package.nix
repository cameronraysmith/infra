{
  lib,
  writeShellApplication,
  coreutils,
  gnugrep,
  gnused,
}:
writeShellApplication {
  name = "seed-age-key";
  runtimeInputs = [
    coreutils
    gnugrep
    gnused
  ];
  text = builtins.readFile ./seed-age-key.sh;
  meta = {
    description = "Write the age key from SOPS_AGE_KEY or SOPS_AGE_KEY_FILE to a path at mode 0600, idempotently";
    license = lib.licenses.mit;
    mainProgram = "seed-age-key";
  };
}
