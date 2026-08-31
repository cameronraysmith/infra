#!/usr/bin/env nix-shell
#!nix-shell --pure -i bash -p curl cacert git nix gnused coreutils
# shellcheck shell=bash
#
# Bumps pkgs/by-name/moshi-hook to the latest vendor release: rewrites the
# version and each platform's asset hash in package.nix.
# Invoked via `nix run .#update-moshi-hook` (passthru.updateScript).

set -euo pipefail

CDN="https://cdn.getmoshi.app/hook"

repo_root="$(git rev-parse --show-toplevel)"
PKG_NIX="${repo_root}/pkgs/by-name/moshi-hook/package.nix"

current_version="$(sed -n 's/.*version = "\(.*\)";/\1/p' "$PKG_NIX" | head -1)"

latest_tag="$(curl -fsSL "${CDN}/latest/version.txt" | tr -d '[:space:]')"
latest_version="${latest_tag#v}"

if [[ -z "$latest_version" ]]; then
  echo "error: failed to resolve a version from ${CDN}/latest/version.txt" >&2
  exit 1
fi

if [[ "$current_version" == "$latest_version" ]]; then
  echo "moshi-hook is already at version ${current_version}; refreshing hashes anyway"
else
  echo "Updating moshi-hook: ${current_version} -> ${latest_version}"
  sed -i'' -e "s/version = \"${current_version}\"/version = \"${latest_version}\"/" "$PKG_NIX"
fi

# The vendor publishes one checksums.txt per release covering every asset, so a
# single fetch replaces four downloads and pins exactly the digests the vendor
# signed off on rather than whatever a re-download happened to yield.
checksums="$(curl -fsSL "${CDN}/v${latest_version}/checksums.txt")"

for label in Darwin_arm64 Darwin_x86_64 Linux_arm64 Linux_x86_64; do
  hex="$(printf '%s\n' "$checksums" | awk -v a="moshi-hook_${label}.tar.gz" '$2 == a { print $1 }')"

  if [[ -z "$hex" ]]; then
    echo "error: checksums.txt has no entry for moshi-hook_${label}.tar.gz" >&2
    exit 1
  fi

  sri_hash="$(nix hash convert --hash-algo sha256 --to sri "$hex")"

  # Anchor on this platform's `label = "<label>";` line, advance to the
  # immediately-following `hash =` line, and substitute. Each label appears
  # exactly once, so exactly one hash line is rewritten.
  sed -i'' -e "/label = \"${label}\";/{ n; s|hash = \"sha256-[^\"]*\"|hash = \"${sri_hash}\"|; }" "$PKG_NIX"

  echo "  ${label}: ${sri_hash}"
done

echo "Updated moshi-hook to ${latest_version}"
