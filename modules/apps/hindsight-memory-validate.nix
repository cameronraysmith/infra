# End-to-end validation flake-app for omp's Hindsight memory backend.
#
# Manually runnable proof that the token, the endpoint, and omp's own memory
# lifecycle all work, against a throwaway bank and a throwaway $HOME that never
# touch the real ~/.omp or the shared `omp` bank.
#
#   nix run .#hindsight-memory-validate                     # tier 0 only
#   nix run .#hindsight-memory-validate -- --tier1          # tier 0 then tier 1
#   nix run .#hindsight-memory-validate -- --tier1 --model anthropic/claude-sonnet-5
#
# Both tiers need HINDSIGHT_API_TOKEN in the environment. That token is not yet
# in secrets.yaml, so this cannot run in CI and is not wired as a flake check;
# it is the operator-run gate that closes out the wiring once the value lands.
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
      apps.hindsight-memory-validate = {
        type = "app";
        program = lib.getExe (
          pkgs.writeShellApplication {
            name = "hindsight-memory-validate";
            runtimeInputs = [
              pkgs.curl
              pkgs.jq
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.cacert
              # Tier 1 drives the same omp build the home configuration installs,
              # so a pass here is a statement about the packaged agent rather than
              # about whatever omp happens to be on the caller's PATH.
              inputs'.llm-agents.packages.omp
            ];
            runtimeEnv = {
              SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
            };
            text = builtins.readFile ./hindsight-memory-validate.sh;
          }
        );
      };
    };
}
