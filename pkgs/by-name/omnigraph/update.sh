#!/usr/bin/env nix-shell
#!nix-shell --pure -i bash -p curl jq cacert git nix-prefetch-github gnused coreutils
# shellcheck shell=bash
#
# Bumps pkgs/by-name/omnigraph to the current tip of upstream main: rewrites the
# version, rev and src hash in package.nix, and blanks cargoHash.
# Invoked via `nix run .#update-omnigraph` (passthru.updateScript).
#
# Upstream publishes no releases, so the version is the crate version declared
# at the new rev suffixed with that commit's date.

set -euo pipefail

owner="ModernRelay"
repo="omnigraph"
branch="main"
fake_sri="sha256-0000000000000000000000000000000000000000000="

repo_root="$(git rev-parse --show-toplevel)"
pkg_nix="${repo_root}/pkgs/by-name/omnigraph/package.nix"

current_version="$(sed -n 's/^  version = "\(.*\)";$/\1/p' "$pkg_nix" | head -1)"
current_rev="$(sed -n 's/^    rev = "\(.*\)";$/\1/p' "$pkg_nix" | head -1)"
if [[ -z "$current_version" || -z "$current_rev" ]]; then
  echo "error: could not read the current version and rev from ${pkg_nix}" >&2
  exit 1
fi

commit_json="$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${owner}/${repo}/commits/${branch}")"

new_rev="$(printf '%s' "$commit_json" | jq -r '.sha')"
commit_date="$(printf '%s' "$commit_json" | jq -r '.commit.committer.date[0:10]')"
if [[ -z "$new_rev" || "$new_rev" == "null" || -z "$commit_date" || "$commit_date" == "null" ]]; then
  echo "error: could not resolve ${branch} to a commit sha and date" >&2
  exit 1
fi

if [[ "$current_rev" == "$new_rev" ]]; then
  echo "omnigraph is already at rev ${current_rev} (${current_version})"
  exit 0
fi

crate_version="$(curl -fsSL \
  "https://raw.githubusercontent.com/${owner}/${repo}/${new_rev}/crates/omnigraph-server/Cargo.toml" \
  | sed -n 's/^version = "\(.*\)"$/\1/p' | head -1)"
if [[ ! "$crate_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: no semver version found in crates/omnigraph-server/Cargo.toml at ${new_rev}" >&2
  echo "observed: ${crate_version:-<empty>}" >&2
  exit 1
fi

new_version="${crate_version}-unstable-${commit_date}"

echo "Updating omnigraph: ${current_version} -> ${new_version}"

echo "Computing source hash for rev ${new_rev}..."
new_sri="$(nix-prefetch-github "$owner" "$repo" --rev "$new_rev" | jq -r '.hash')"
if [[ -z "$new_sri" || "$new_sri" == "null" ]]; then
  echo "error: nix-prefetch-github did not return a hash" >&2
  exit 1
fi

# package.nix carries two SRI lines. Anchor each rewrite on its indentation so
# the src hash and cargoHash cannot be confused.
sed -i'' -e "s|^  version = \"[^\"]*\";\$|  version = \"${new_version}\";|" "$pkg_nix"
sed -i'' -e "s|^    rev = \"[0-9a-f]\{40\}\";\$|    rev = \"${new_rev}\";|" "$pkg_nix"
sed -i'' -e "s|^    hash = \"sha256-[^\"]*\";\$|    hash = \"${new_sri}\";|" "$pkg_nix"
sed -i'' -e "s|^  cargoHash = \"sha256-[^\"]*\";\$|  cargoHash = \"${fake_sri}\";|" "$pkg_nix"

# Fail loudly if any rewrite did not take, rather than reporting success on a no-op.
grep -q "^  version = \"${new_version}\";\$" "$pkg_nix" \
  || { echo "error: version was not updated in package.nix" >&2; exit 1; }
grep -q "^    rev = \"${new_rev}\";\$" "$pkg_nix" \
  || { echo "error: rev was not updated in package.nix" >&2; exit 1; }
grep -q "^    hash = \"${new_sri}\";\$" "$pkg_nix" \
  || { echo "error: src hash was not updated in package.nix" >&2; exit 1; }
grep -q "^  cargoHash = \"${fake_sri}\";\$" "$pkg_nix" \
  || { echo "error: cargoHash was not reset in package.nix" >&2; exit 1; }

echo "Updated omnigraph to ${new_version}"
echo "  rev:      ${new_rev}"
echo "  src hash: ${new_sri}"
echo
echo "cargoHash was reset to the placeholder and must be recomputed:"
echo "  nix build .#omnigraph.cargoDeps"
echo "then copy the reported got: hash into cargoHash."
