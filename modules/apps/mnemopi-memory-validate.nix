# End-to-end validation flake-app for omp's mnemopi memory backend.
#
# Manually runnable proof that omp's own memory lifecycle works, against a
# throwaway SQLite store that never touches the production one.
#
#   nix run .#mnemopi-memory-validate
#   nix run .#mnemopi-memory-validate -- --model openai-codex/gpt-5.6-luna
#   nix run .#mnemopi-memory-validate -- --embeddings --keep-scratch
#
# Needs no token: mnemopi is local, so the only credential in the run is the
# one the model turn itself needs, which the real profile already holds. That
# is the difference from the hindsight-memory-validate app this replaces, whose
# first tier existed to prove a vendor credential and endpoint that no longer
# take part in memory.
#
# Mirrors the apm-marketplace-validate flake-app + co-located .sh sidecar
# convention. Read-only with respect to the repo; all writes land in a scratch
# tmpdir cleaned up on exit.
{ ... }:
{
  perSystem =
    {
      inputs',
      pkgs,
      lib,
      ...
    }:
    {
      apps.mnemopi-memory-validate = {
        type = "app";
        program = lib.getExe (
          pkgs.writeShellApplication {
            name = "mnemopi-memory-validate";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.cacert
              # Drives the same omp build the home configuration installs, so a
              # pass here is a statement about the packaged agent rather than
              # about whatever omp happens to be on the caller's PATH.
              inputs'.llm-agents.packages.omp
            ];
            runtimeEnv = {
              SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
            };
            text = builtins.readFile ./mnemopi-memory-validate.sh;
          }
        );
      };
    };
}
