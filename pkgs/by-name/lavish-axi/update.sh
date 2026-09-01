#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq cacert git nodejs_22 nix
# shellcheck shell=bash

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
PKG_DIR="${REPO_ROOT}/pkgs/by-name/lavish-axi"
PKG="${PKG_DIR##*/}"
PKG_NIX="${PKG_DIR}/package.nix"

current_version="$(sed -n 's/.*version = "\(.*\)";/\1/p' "$PKG_NIX" | head -1)"
latest_version="$(curl -fsSL "https://registry.npmjs.org/${PKG}/latest" | jq -r '.version')"

if [[ "$current_version" == "$latest_version" ]]; then
  echo "${PKG} is already at version ${current_version}"
  exit 0
fi

echo "Updating ${PKG}: ${current_version} -> ${latest_version}"

workdir="$(mktemp -d)"
trap 'chmod -R u+w "$workdir" 2>/dev/null || true; command rm -rf "$workdir"' EXIT

tarball="${workdir}/${PKG}.tgz"
curl -fsSL "https://registry.npmjs.org/${PKG}/-/${PKG}-${latest_version}.tgz" -o "$tarball"
new_sri="$(nix hash file --type sha256 --sri "$tarball")"

mkdir -p "${workdir}/src"
tar -xzf "$tarball" -C "${workdir}/src" --strip-components=1

# Regenerate the lockfile against the same dev-stripped package.json the
# derivation splices in, so `npm ci` sees a consistent pair.
(
  cd "${workdir}/src"
  jq 'del(.devDependencies, .scripts)' package.json > package.json.stripped
  mv package.json.stripped package.json
  npm install --package-lock-only --ignore-scripts >/dev/null 2>&1
)
cp "${workdir}/src/package-lock.json" "${PKG_DIR}/package-lock.json"

sed -i'' -e "s/version = \"${current_version}\"/version = \"${latest_version}\"/" "$PKG_NIX"
sed -i'' -e "s|hash = \"sha256-[A-Za-z0-9+/=]*\"|hash = \"${new_sri}\"|" "$PKG_NIX"

DUMMY_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
sed -i'' -e "s|npmDepsHash = \"sha256-[A-Za-z0-9+/=]*\"|npmDepsHash = \"${DUMMY_HASH}\"|" "$PKG_NIX"

echo "Computing npmDepsHash (this triggers a build that will fail with the correct hash)..."
correct_hash="$(cd "$REPO_ROOT" && nix build ".#${PKG}" 2>&1 \
  | grep -o 'got:.*sha256-[A-Za-z0-9+/=]*' \
  | head -1 \
  | sed 's/got:[[:space:]]*//')" || true

if [[ -z "$correct_hash" ]]; then
  echo "ERROR: Could not extract npmDepsHash from build output."
  echo "The version, src hash, and lockfile have been updated."
  echo "npmDepsHash is left at the placeholder \"${DUMMY_HASH}\"."
  echo "Rerun 'nix build .#${PKG}' and read the correct hash from the mismatch error."
  exit 1
fi

sed -i'' -e "s|npmDepsHash = \"${DUMMY_HASH}\"|npmDepsHash = \"${correct_hash}\"|" "$PKG_NIX"

echo "Updated ${PKG} to ${latest_version}"
echo "  src hash:    ${new_sri}"
echo "  npmDepsHash: ${correct_hash}"
echo "  package-lock.json regenerated"
