#!/usr/bin/env nix-shell
#!nix-shell --pure -i bash -p curl jq cacert git nix gnused coreutils gnugrep
# shellcheck shell=bash
#
# Update linear-cli (schpet/linear-cli) to the latest release.
#
# Rewrites, in package.nix:
#   1. the `version = "...";` let-binding
#   2. the two Darwin prebuilt-binary `hash = "...";` lines (one per platform,
#      paired to each preceding `url` line)
#   3. the `src` fetchFromGitHub `hash = "...";` line (the hash following
#      the `rev = "v$VERSION";` line)
#   4. the Linux source build's `denoDeps.outputHash`
#
# Usage: ./update.sh [VERSION]   (VERSION overrides the latest-release lookup)

set -euo pipefail

REPO="schpet/linear-cli"
REPO_ROOT="$(git rev-parse --show-toplevel)"
PKG_NIX="${REPO_ROOT}/pkgs/by-name/linear-cli/package.nix"

current_version="$(sed -n 's/.*version = "\(.*\)";/\1/p' "$PKG_NIX" | head -1)"

if [[ $# -ge 1 ]]; then
  latest_version="${1#v}"
else
  latest_tag="$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO}/releases/latest" \
    | jq -r .tag_name)"
  latest_version="${latest_tag#v}"
fi

if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
  echo "error: failed to discover a release tag from GitHub" >&2
  exit 1
fi

if [[ "$current_version" == "$latest_version" ]]; then
  echo "linear-cli is already at version ${current_version}; refreshing hashes anyway"
else
  echo "Updating linear-cli: ${current_version} -> ${latest_version}"
  sed -i'' -e "s/version = \"${current_version}\"/version = \"${latest_version}\"/" "$PKG_NIX"
fi

# Platform map: nix system -> release artifact filename (URL leaf segment)
declare -A platform_map=(
  ["aarch64-darwin"]="linear-aarch64-apple-darwin.tar.xz"
  ["x86_64-darwin"]="linear-x86_64-apple-darwin.tar.xz"
  ["x86_64-linux"]="linear-x86_64-unknown-linux-gnu.tar.xz"
  ["aarch64-linux"]="linear-aarch64-unknown-linux-gnu.tar.xz"
)

for platform in "${!platform_map[@]}"; do
  artifact="${platform_map[$platform]}"
  url="https://github.com/${REPO}/releases/download/v${latest_version}/${artifact}"

  echo "Prefetching ${platform} (${artifact})..."
  sri_hash="$(nix store prefetch-file --json --hash-type sha256 "$url" | jq -r .hash)"

  if [[ -z "$sri_hash" || "$sri_hash" == "null" ]]; then
    echo "error: failed to compute hash for ${platform} from ${url}" >&2
    exit 1
  fi

  # Match the URL line (which contains the artifact filename), advance to the
  # following `hash =` line, and substitute. Layout in package.nix is one url
  # line immediately followed by one hash line per platform.
  sed -i'' -e "/${artifact}/{ n; s|hash = \"sha256-[^\"]*\"|hash = \"${sri_hash}\"|; }" "$PKG_NIX"

  echo "  ${platform}: ${sri_hash}"
done

# Source tree hash for the `src` fetchFromGitHub block. Match the
# `rev = "v$VERSION";` line, advance to the following `hash =` line, and
# substitute (distinct from the four binary hashes above).
echo "Prefetching source tree (v${latest_version})..."
src_raw="$(nix-prefetch-url --unpack "https://github.com/${REPO}/archive/refs/tags/v${latest_version}.tar.gz")"
src_sri="$(nix hash to-sri --type sha256 "$src_raw")"

if [[ -z "$src_sri" || "$src_sri" == "null" ]]; then
  echo "error: failed to compute source-tree hash for v${latest_version}" >&2
  exit 1
fi

sed -i'' -e "/rev = \"v\${version}\"/{ n; s|hash = \"sha256-[^\"]*\"|hash = \"${src_sri}\"|; }" "$PKG_NIX"
echo "  src: ${src_sri}"

echo "Prefetching x86_64-linux Deno dependencies..."
fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
sed -i'' -e "s|outputHash = \"sha256-[^\"]*\";|outputHash = \"${fake_hash}\";|" "$PKG_NIX"

if ! grep -qF "outputHash = \"${fake_hash}\";" "$PKG_NIX"; then
  echo "error: failed to replace denoDeps.outputHash with the probe hash" >&2
  exit 1
fi

deno_deps_log="$(mktemp)"
trap 'rm -f "$deno_deps_log"' EXIT

if nix build "${REPO_ROOT}#packages.x86_64-linux.linear-cli.denoDeps" \
  --max-jobs 0 \
  --no-link \
  -L 2>&1 | tee "$deno_deps_log"; then
  echo "error: denoDeps unexpectedly matched the probe hash" >&2
  exit 1
fi

deno_deps_hash="$(sed -n 's/^[[:space:]]*got:[[:space:]]*\(sha256-[^[:space:]]*\)$/\1/p' "$deno_deps_log" | tail -1)"

if [[ -z "$deno_deps_hash" ]]; then
  echo "error: x86_64-linux denoDeps build failed without producing a fixed-output hash" >&2
  exit 1
fi

sed -i'' -e "s|outputHash = \"${fake_hash}\";|outputHash = \"${deno_deps_hash}\";|" "$PKG_NIX"
echo "  denoDeps (x86_64-linux): ${deno_deps_hash}"

echo "Updated linear-cli to ${latest_version}"
