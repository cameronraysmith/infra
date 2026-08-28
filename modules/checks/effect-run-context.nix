# Behavioural check for the effects' runtime CI-event normalisation.
#
# The fragment in modules/lib/effect-run-context.nix decides, at effect
# runtime, whether a run is a pull request. Two properties matter and neither
# is visible by reading the generated script.
#
# Under buildbot-nix nothing sets the identity-endpoint variables, so the
# fragment must reduce to the derivation the effects previously performed at
# eval time: `branch == "main"` for the production path, and
# `^refs/pull/([0-9]+)/merge$` for a pull request. Rows 1-4 assert that against
# the branch strings buildbot-nix actually supplies.
#
# Under nixbot the eval-time branch of a pull request is its BASE ref, so a
# pull request against main arrives indistinguishable from a push to main. Row
# 5 is the one that matters: same seed as row 1, opposite verdict, because the
# token says so. Without the fragment that row deploys unmerged code to
# production.
#
# curl is stubbed. What is under test is claim decoding and branch
# resolution, not curl's argument handling; the request form itself matches
# nixbot's own end-to-end check, and a build sandbox has no server to call.
{ self, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      runContext = self.lib.effectRunContext;

      # A JWT is header.payload.signature with an unpadded base64url payload.
      # Only the payload is read, so the other two fields are placeholders.
      mkTokenResponse = claims: ''
        payload="$(printf '%s' ${lib.escapeShellArg (builtins.toJSON claims)} \
          | base64 -w0 | tr '+/' '-_' | tr -d '=')"
        printf '{"token":"eyJhbGciOiJSUzI1NiJ9.%s.signature"}' "$payload" > "$PWD/token.json"
      '';

      # Each row runs the fragment in a subshell and diffs the four exported
      # variables against a literal expectation.
      row =
        {
          name,
          branch,
          claims ? null,
          expected,
        }:
        ''
          echo "--- ${name}"
          (
            set -euo pipefail
            ${if claims == null then "" else mkTokenResponse claims}
            ${
              if claims == null then
                ''
                  unset NIXBOT_ID_TOKEN_REQUEST_URL NIXBOT_ID_TOKEN_REQUEST_TOKEN || true
                ''
              else
                ''
                  export NIXBOT_ID_TOKEN_REQUEST_URL="https://nixbot.invalid/api/v1/id-token"
                  export NIXBOT_ID_TOKEN_REQUEST_TOKEN="task-token"
                ''
            }
            ${runContext.mkScript { inherit branch; }} > /dev/null
            printf '%s|%s|%s|%s\n' "$CI_BRANCH" "$CI_IS_MAIN" "$CI_IS_PR" "$CI_PR_NUMBER" > actual
          )
          printf '%s\n' ${lib.escapeShellArg expected} > expected
          if ! diff -u expected actual; then
            echo "run-context row '${name}' produced the wrong verdict" >&2
            exit 1
          fi
        '';
    in
    {
      checks.effect-run-context =
        pkgs.runCommand "effect-run-context"
          {
            nativeBuildInputs = [
              pkgs.jq
              pkgs.coreutils
              pkgs.diffutils
            ];
            meta.description = "behavioural check: effect run-context resolution";
          }
          ''
            mkdir -p "$TMPDIR/work" "$TMPDIR/bin" && cd "$TMPDIR/work"

            # The fragment's only network call. It reads the response body from a
            # file the row wrote, so the decode path downstream is exercised whole.
            cat > "$TMPDIR/bin/curl" <<'STUB'
            #!/bin/sh
            cat "$PWD/token.json"
            STUB
            chmod +x "$TMPDIR/bin/curl"
            export PATH="$TMPDIR/bin:$PATH"

            ${lib.concatMapStrings row [
              {
                name = "buildbot: push to main";
                branch = "main";
                expected = "main|true|false|";
              }
              {
                name = "buildbot: pull request";
                branch = "refs/pull/42/merge";
                expected = "refs/pull/42/merge|false|true|42";
              }
              {
                name = "buildbot: push to a feature branch";
                branch = "feature/widget";
                expected = "feature/widget|false|false|";
              }
              {
                name = "buildbot: tag push carries no branch";
                branch = null;
                expected = "|false|false|";
              }
              {
                name = "nixbot: pull request against main resolves as a pull request";
                branch = "main";
                claims = {
                  event = "pull_request";
                  pr_number = 42;
                  base_ref = "refs/heads/main";
                };
                expected = "refs/pull/42/merge|false|true|42";
              }
              {
                name = "nixbot: push to main resolves as main";
                branch = "main";
                claims = {
                  event = "push";
                  ref = "refs/heads/main";
                };
                expected = "main|true|false|";
              }
              {
                name = "nixbot: push to a feature branch";
                branch = "feature/widget";
                claims = {
                  event = "push";
                  ref = "refs/heads/feature/widget";
                };
                expected = "feature/widget|false|false|";
              }
            ]}

            touch $out
          '';
    };
}
