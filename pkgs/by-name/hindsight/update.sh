#!/usr/bin/env nix-shell
#!nix-shell --pure -i bash -p curl jq cacert nix
# shellcheck shell=bash
#
# Bumps pkgs/by-name/hindsight to the latest upstream release: rewrites the
# version and each platform's asset hash in package.nix.
# Invoked via `nix run .#update-hindsight` (passthru.updateScript).

set -euo pipefail

# Resolve package.nix relative to this script so the updater edits the correct
# file regardless of the caller's working directory (e.g. nixpkgs update
# machinery, which does not cd into the package directory).
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PKG_NIX="${SCRIPT_DIR}/package.nix"

current_version="$(sed -n 's/.*version = "\(.*\)";/\1/p' "$PKG_NIX" | head -1)"

# The monorepo scopes sub-component tags with a slash prefix (integrations/...,
# tools/...) and reserves bare vMAJOR.MINOR.PATCH for whole-repo releases, which
# is what the CLI assets are attached to, so filter to that form rather than
# trusting releases/latest.
latest_tag="$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/vectorize-io/hindsight/releases?per_page=100" \
  | jq -r '[.[] | select(.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))] | .[0].tag_name')"
latest_version="${latest_tag#v}"

if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
  echo "error: failed to discover a semver tag from GitHub releases" >&2
  exit 1
fi

if [[ "$current_version" == "$latest_version" ]]; then
  echo "hindsight is already at version ${current_version}; refreshing hashes anyway"
else
  echo "Updating hindsight: ${current_version} -> ${latest_version}"
  sed -i'' -e "s/version = \"${current_version}\"/version = \"${latest_version}\"/" "$PKG_NIX"
fi

# Platform map: nix system -> upstream asset label (asset is a bare executable
# named hindsight-<label>).
declare -A platform_map=(
  ["x86_64-linux"]="linux-amd64"
  ["aarch64-linux"]="linux-arm64"
  ["x86_64-darwin"]="darwin-amd64"
  ["aarch64-darwin"]="darwin-arm64"
)

for platform in "${!platform_map[@]}"; do
  asset="${platform_map[$platform]}"
  url="https://github.com/vectorize-io/hindsight/releases/download/v${latest_version}/hindsight-${asset}"

  echo "Prefetching ${platform} (hindsight-${asset})..."
  sri_hash="$(nix store prefetch-file --json --hash-type sha256 "$url" | jq -r .hash)"

  if [[ -z "$sri_hash" || "$sri_hash" == "null" ]]; then
    echo "error: failed to compute hash for ${platform} from ${url}" >&2
    exit 1
  fi

  # Anchor on this platform's `asset = "<label>";` line, advance to the
  # immediately-following `hash =` line, and substitute. Each label is unique to
  # a single block in package.nix, so exactly one hash line is rewritten.
  sed -i'' -e "/asset = \"${asset}\";/{ n; s|hash = \"sha256-[^\"]*\"|hash = \"${sri_hash}\"|; }" "$PKG_NIX"

  echo "  ${platform}: ${sri_hash}"
done

echo "Updated hindsight to ${latest_version}"
