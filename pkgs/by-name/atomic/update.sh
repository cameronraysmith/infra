#!/usr/bin/env nix-shell
#!nix-shell --pure -i bash -p curl jq cacert git
# shellcheck shell=bash

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
MANIFEST="${REPO_ROOT}/pkgs/by-name/atomic/manifest.json"

REPO="bastani-inc/atomic"
RELEASES_API="https://api.github.com/repos/${REPO}/releases"
DOWNLOADS="https://github.com/${REPO}/releases/download"

# /releases/latest is the newest non-prerelease; atomic publishes -alpha.N tags
# continuously between stable releases, so listing tags would track those too.
version="$(curl -fsSL "${RELEASES_API}/latest" | jq -r '.tag_name')"

# Upstream publishes a SHA256SUMS asset covering every archive in the release,
# so the checksums are read rather than recomputed by fetching each tarball.
manifest="$(
  curl -fsSL "${DOWNLOADS}/${version}/SHA256SUMS" \
    | jq -Rn --arg version "$version" '
      {
        $version,
        platforms: [
          inputs
          | split(" ")
          | map(select(length > 0))
          | select(length == 2)
          | select(.[1] | test("^atomic-(darwin|linux)-(x64|arm64)\\.tar\\.gz$"))
          | {
            key: (.[1] | ltrimstr("atomic-") | rtrimstr(".tar.gz")),
            value: { checksum: .[0] }
          }
        ] | from_entries
      }'
)"

if [[ "$(jq '.platforms | length' <<<"$manifest")" -eq 0 ]]; then
  echo "error: no matching archives in SHA256SUMS for ${version}" >&2
  exit 1
fi

echo "$manifest" > "$MANIFEST"
echo "atomic manifest updated to ${version}"
