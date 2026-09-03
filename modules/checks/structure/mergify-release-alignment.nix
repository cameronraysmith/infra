{ ... }:
{
  perSystem =
    { pkgs, self', ... }:
    let
      checkAlignment = pkgs.writeShellScript "check-mergify-release-alignment" ''
        set -u
        sourceVersion="$1"
        binaryVersion="$2"

        if [ "$sourceVersion" != "$binaryVersion" ]; then
          echo "structure-mergify-release-alignment: release mismatch" >&2
          echo "  agent-plugins-mergify-cli: $sourceVersion" >&2
          echo "  mergify-cli-bin: $binaryVersion" >&2
          exit 1
        fi
      '';

      mkAlignmentCheck =
        {
          name,
          sourceVersion,
          binaryVersion,
        }:
        pkgs.runCommand name
          {
            inherit sourceVersion binaryVersion;
          }
          ''
            set -euo pipefail
            ${checkAlignment} "$sourceVersion" "$binaryVersion"
            touch "$out"
          '';
    in
    {
      checks = {
        structure-mergify-release-alignment = mkAlignmentCheck {
          name = "structure-mergify-release-alignment";
          sourceVersion = self'.packages.agent-plugins-mergify-cli.version;
          binaryVersion = self'.packages.mergify-cli-bin.version;
        };

        structure-mergify-release-alignment-neg =
          pkgs.runCommand "structure-mergify-release-alignment-neg"
            {
              nativeBuildInputs = [ pkgs.gnugrep ];
            }
            ''
              set -euo pipefail
              mismatchLog="$TMPDIR/mismatch.log"
              if ${checkAlignment} source-fixture binary-fixture 2>"$mismatchLog"; then
                echo "release-alignment checker accepted unequal fixtures" >&2
                exit 1
              fi
              grep -F 'agent-plugins-mergify-cli: source-fixture' "$mismatchLog"
              grep -F 'mergify-cli-bin: binary-fixture' "$mismatchLog"
              touch "$out"
            '';
      };
    };
}
