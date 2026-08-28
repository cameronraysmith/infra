# herculesCI effect: docs deployment branch-dispatcher (preview vs promote).
{
  config,
  inputs,
  lib,
  withSystem,
  ...
}:
{
  herculesCI =
    herculesCI:
    let
      # Nullable: null on tag pushes (no branch).
      branch = herculesCI.config.repo.branch;
      shortRev = herculesCI.config.repo.shortRev;
      rev = herculesCI.config.repo.rev;

      runContext = config.flake.lib.effectRunContext;
    in
    {
      onPush.default.outputs.effects.deploy-docs = withSystem "x86_64-linux" (
        { config, pkgs, ... }:
        let
          hci-effects = inputs.hercules-ci-effects.lib.withPkgs pkgs;

          deployDocsProgram = config.apps.deploy-docs.program;

          # The branch a preview is named after is resolved at runtime, since
          # only then is a pull request distinguishable from a push to its
          # base branch.
          fallbackPreviewBranch = shortRev;
        in
        hci-effects.mkEffect {
          name = "deploy-docs";

          # Declaring an audience is what makes nixbot expose its identity
          # endpoint to this effect; the token's claims are the only way the
          # script can tell a pull request from a push to the base branch.
          # Must be a JSON-array string: a bare nix list serialises
          # space-separated and nixbot rejects it before the sandbox starts.
          # buildbot-nix has no such endpoint and ignores this attribute.
          idTokenAudiences = builtins.toJSON [ runContext.audience ];

          # Why: mkEffect's defaultInputs cover jq but not curl or coreutils,
          # which the run-context fragment needs.
          inputs = [
            pkgs.curl
            pkgs.coreutils
          ];

          # nixbot enforces hercules-ci secretsMap semantics: only the
          # destinations named here are written into
          # $HERCULES_CI_SECRETS_JSON, and mkEffect declares an empty map when
          # the caller omits one, which grants nothing at all. buildbot-nix
          # ignores the map and passes the whole file, so this narrows what
          # the script can read under nixbot and changes nothing under
          # buildbot-nix. Left-hand names are what the script reads;
          # right-hand names are keys in the composed secrets file.
          secretsMap = {
            CLOUDFLARE_API_TOKEN = "CLOUDFLARE_API_TOKEN";
            CLOUDFLARE_ACCOUNT_ID = "CLOUDFLARE_ACCOUNT_ID";
          };

          effectScript = ''
            set -euo pipefail

            ${runContext.mkScript { inherit branch; }}

            echo "=== effects.deploy-docs (docs deployment dispatcher) ==="
            echo "branch:   $CI_BRANCH"
            echo "rev:      ${lib.escapeShellArg (toString rev)}"
            echo "shortRev: ${lib.escapeShellArg (toString shortRev)}"
            echo "isMain:   $CI_IS_MAIN"

            if [ "$CI_IS_MAIN" = true ]; then
              echo "DEPLOY-DOCS-ACTION: promote"
            else
              echo "DEPLOY-DOCS-ACTION: preview-upload"
            fi

            export CLOUDFLARE_API_TOKEN="$(jq -r '.CLOUDFLARE_API_TOKEN.data.value' "$HERCULES_CI_SECRETS_JSON")"
            export CLOUDFLARE_ACCOUNT_ID="$(jq -r '.CLOUDFLARE_ACCOUNT_ID.data.value' "$HERCULES_CI_SECRETS_JSON")"

            export GIT_REV=${lib.escapeShellArg (toString rev)}
            export GIT_REV_SHORT=${lib.escapeShellArg (toString shortRev)}
            export GIT_REV_SHORT12=${lib.escapeShellArg (builtins.substring 0 12 (toString rev))}
            export GIT_BRANCH="$CI_BRANCH"
            export GIT_COMMIT_MSG=${lib.escapeShellArg "effect deploy from rev ${toString shortRev}"}
            export GIT_WORKTREE_STATUS=clean

            # Why: whoami/hostname not on bwrap PATH; supply hard-coded values.
            export DEPLOY_DEPLOYER=hercules-ci-effects
            export DEPLOY_HOST=magnetite

            if [ -z "''${CLOUDFLARE_API_TOKEN:-}" ] || [ "$CLOUDFLARE_API_TOKEN" = "null" ]; then
              echo "error: CLOUDFLARE_API_TOKEN missing from \$HERCULES_CI_SECRETS_JSON" >&2
              exit 1
            fi
            if [ -z "''${CLOUDFLARE_ACCOUNT_ID:-}" ] || [ "$CLOUDFLARE_ACCOUNT_ID" = "null" ]; then
              echo "error: CLOUDFLARE_ACCOUNT_ID missing from \$HERCULES_CI_SECRETS_JSON" >&2
              exit 1
            fi

            # Why: bwrap sandbox does not bind working tree; .# cannot resolve. Use eval-time /nix/store path.
            DEPLOY_DOCS=${deployDocsProgram}

            if [ "$CI_IS_MAIN" = true ]; then
              # release.sh's production subcommand re-emits "falling back to direct deploy" on the fresh-deploy fallback; the dispatcher grep below depends on that exact substring.
              deploy_log="$(mktemp -t deploy-docs-prod.XXXXXX.log)"
              set +e
              "$DEPLOY_DOCS" production 2>&1 | tee "$deploy_log"
              deploy_rc=''${PIPESTATUS[0]}
              set -e
              if grep -q "falling back to direct deploy" "$deploy_log"; then
                echo "DEPLOY-DOCS-ACTION: fresh-deploy-and-promote"
              fi
              if [ "$deploy_rc" -ne 0 ]; then
                echo "error: deploy-docs production exited $deploy_rc" >&2
                exit "$deploy_rc"
              fi
            else
              preview_branch="$CI_BRANCH"
              if [ -z "$preview_branch" ]; then
                preview_branch=${lib.escapeShellArg fallbackPreviewBranch}
              fi
              preview_log="$(mktemp -t deploy-docs-preview.XXXXXX.log)"
              set +e
              "$DEPLOY_DOCS" preview "$preview_branch" 2>&1 | tee "$preview_log"
              upload_rc=''${PIPESTATUS[0]}
              set -e
              preview_url="$(grep -oE 'Preview URL: https://[^[:space:]]+' "$preview_log" | head -1 | awk '{print $3}' || true)"
              if [ -n "$preview_url" ]; then
                echo "DEPLOY-DOCS-PREVIEW-URL: $preview_url"
              else
                echo "warning: could not parse preview URL from deploy.sh output" >&2
              fi
              if [ "$upload_rc" -ne 0 ]; then
                echo "error: deploy-docs preview exited $upload_rc" >&2
                exit "$upload_rc"
              fi
            fi

            echo "=== deploy-docs effect complete (exit 0) ==="
          '';
        }
      );
    };
}
