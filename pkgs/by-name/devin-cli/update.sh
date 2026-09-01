#!/usr/bin/env nix-shell
#!nix-shell --pure -i bash -p bash curl jq cacert git nix
# shellcheck shell=bash

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
PKG_NIX="${REPO_ROOT}/pkgs/by-name/devin-cli/package.nix"

current_version="$(sed -n 's/.*version = "\(.*\)";/\1/p' "$PKG_NIX" | head -1)"

latest_version="$(curl -fsSL https://static.devin.ai/cli/current/manifest.json | jq -r '.version')"

if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
  echo "error: failed to discover a version from https://static.devin.ai/cli/current/manifest.json" >&2
  exit 1
fi

if [[ "$current_version" == "$latest_version" ]]; then
  echo "devin-cli is already at version ${current_version}; refreshing hashes anyway"
else
  echo "Updating devin-cli: ${current_version} -> ${latest_version}"
  sed -i'' -e "s/version = \"${current_version}\"/version = \"${latest_version}\"/" "$PKG_NIX"
fi

# Platform map: nix system -> release asset triple. Upstream publishes no
# x86_64-darwin asset, so that system stays absent from package.nix and hits
# its throwSystem branch.
declare -A platform_map=(
  ["x86_64-linux"]="x86_64-unknown-linux"
  ["aarch64-linux"]="aarch64-unknown-linux"
  ["aarch64-darwin"]="aarch64-apple-darwin"
)

for platform in "${!platform_map[@]}"; do
  triple="${platform_map[$platform]}"
  url="https://static.devin.ai/cli/${latest_version}/devin-${latest_version}-${triple}.tar.gz"

  echo "Prefetching ${platform} (devin-${latest_version}-${triple}.tar.gz)..."
  sri_hash="$(nix store prefetch-file --json --hash-type sha256 "$url" | jq -r .hash)"

  if [[ -z "$sri_hash" || "$sri_hash" == "null" ]]; then
    echo "error: failed to compute hash for ${platform} from ${url}" >&2
    exit 1
  fi

  # The url line interpolates ${version} in Nix source, so each asset triple is
  # a literal that appears exactly once; advance to the following hash line and
  # substitute there.
  sed -i'' -e "\|-${triple}\.tar\.gz|{ n; s|hash = \"sha256-[^\"]*\"|hash = \"${sri_hash}\"|; }" "$PKG_NIX"

  echo "  ${platform}: ${sri_hash}"
done

echo "Updated devin-cli to ${latest_version}"
