# Runtime CI-event normalisation for the herculesCI effects.
#
# The two build services describe a pull request differently. buildbot-nix
# reports refs/pull/<N>/merge as the branch, so the branch string alone
# identifies the event and carries the number. nixbot reports the pull
# request's base ref, so a pull request against main is indistinguishable from
# a push to main by branch; an effect that trusts that value takes the
# production path against unmerged code.
#
# nixbot does supply a discriminator, but only at runtime and only on request.
# An effect declaring idTokenAudiences receives NIXBOT_ID_TOKEN_REQUEST_URL and
# NIXBOT_ID_TOKEN_REQUEST_TOKEN in its environment, and the token minted from
# that endpoint carries either event=pull_request with an integer pr_number, or
# event=push with a ref.
#
# This fragment resolves both services onto buildbot-nix's convention, which
# the effect scripts already speak, and then derives every decision from that
# one string. The eval-time branch is the seed; the token overrides it only
# when nixbot's endpoint is present, which never happens under buildbot-nix
# because nothing there sets those variables. So the buildbot-nix path reduces
# to the same derivation the effects previously performed at eval time, over
# the same input.
#
# Exports CI_BRANCH, CI_IS_MAIN, CI_IS_PR and CI_PR_NUMBER.
#
# The effect reads its own token's claims without verifying the signature. It
# fetched the token directly from the issuer over an authenticated endpoint
# reachable only inside its own sandbox, so a signature check would re-verify
# the transport it already trusts. Nothing here is a third-party assertion.
#
# A failed fetch aborts the effect under `set -e` rather than falling back.
# Falling back would mean resolving a pull request as its base branch, which is
# the production path: failing loudly is the safe direction.
{ lib, ... }:
{
  flake.lib.effectRunContext = {
    # Any string works; nixbot checks only that the requested audience is one
    # the effect declared, and imposes no format.
    audience = "vanixiets-ci";

    mkScript =
      { branch }:
      ''
        CI_BRANCH=${lib.escapeShellArg (if branch == null then "" else toString branch)}

        if [ -n "''${NIXBOT_ID_TOKEN_REQUEST_URL:-}" ] && [ -n "''${NIXBOT_ID_TOKEN_REQUEST_TOKEN:-}" ]; then
          _ci_token="$(curl -fsS -X POST "$NIXBOT_ID_TOKEN_REQUEST_URL" \
            -H "Authorization: Bearer $NIXBOT_ID_TOKEN_REQUEST_TOKEN" \
            -H 'Content-Type: application/json' \
            --data '{"audience":"vanixiets-ci"}' | jq -re .token)"

          # JWT payloads are unpadded base64url.
          _ci_payload="$(printf '%s' "$_ci_token" | cut -d. -f2 | tr '_-' '/+')"
          case $(( ''${#_ci_payload} % 4 )) in
            2) _ci_payload="$_ci_payload==" ;;
            3) _ci_payload="$_ci_payload=" ;;
          esac
          _ci_claims="$(printf '%s' "$_ci_payload" | base64 -d)"

          if [ "$(printf '%s' "$_ci_claims" | jq -re .event)" = pull_request ]; then
            CI_BRANCH="refs/pull/$(printf '%s' "$_ci_claims" | jq -re .pr_number)/merge"
          else
            CI_BRANCH="$(printf '%s' "$_ci_claims" | jq -re .ref)"
            CI_BRANCH="''${CI_BRANCH#refs/heads/}"
          fi
          unset _ci_token _ci_payload _ci_claims
        fi

        CI_PR_NUMBER="''${CI_BRANCH#refs/pull/}"
        CI_PR_NUMBER="''${CI_PR_NUMBER%/merge}"
        if [ "$CI_PR_NUMBER" = "$CI_BRANCH" ]; then
          CI_PR_NUMBER=""
        fi
        # Digits only, matching the ^refs/pull/([0-9]+)/merge$ the effects used.
        case "$CI_PR_NUMBER" in
          "" | *[!0-9]*) CI_PR_NUMBER="" ;;
        esac
        if [ -n "$CI_PR_NUMBER" ]; then CI_IS_PR=true; else CI_IS_PR=false; fi
        if [ "$CI_BRANCH" = main ]; then CI_IS_MAIN=true; else CI_IS_MAIN=false; fi

        export CI_BRANCH CI_IS_MAIN CI_IS_PR CI_PR_NUMBER
        echo "CI-RUN-CONTEXT: branch=$CI_BRANCH is_main=$CI_IS_MAIN is_pr=$CI_IS_PR pr_number=$CI_PR_NUMBER"
      '';
  };
}
