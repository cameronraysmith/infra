#!/usr/bin/env nix-shell
#!nix-shell --pure -i bash -p curl jq cacert git nix-prefetch-github gnused coreutils
# shellcheck shell=bash
#
# Bumps pkgs/by-name/buzz/source to the newest desktop-v release: rewrites the
# version, the src hash and the recorded rev in package.nix, and blanks the
# vendor hash.
# Invoked via `nix run .#update-buzz-source` (passthru.updateScript).
#
# Upstream also publishes mobile-v* and chart-v* releases, so this filters on
# the desktop-v prefix rather than calling releases/latest, which returns the
# right answer today only by publication-order coincidence.
#
# No lockfile is generated: upstream ships Cargo.lock, and the vendored
# dependency set is derived from it by rustPlatform.fetchCargoVendor.

set -euo pipefail

owner="block"
repo="buzz"
fake_sri="sha256-0000000000000000000000000000000000000000000="

repo_root="$(git rev-parse --show-toplevel)"
pkg_dir="${repo_root}/pkgs/by-name/buzz/source"
pkg_nix="${pkg_dir}/package.nix"

current_version="$(sed -n 's/^  version = "\(.*\)";$/\1/p' "$pkg_nix" | head -1)"
if [[ -z "$current_version" ]]; then
  echo "error: could not read the current version from ${pkg_nix}" >&2
  exit 1
fi

releases_json="$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${owner}/${repo}/releases?per_page=100")"

mapfile -t desktop_versions < <(
  printf '%s' "$releases_json" \
    | jq -r '.[] | select(.draft | not) | select(.prerelease | not) | .tag_name' \
    | sed -n 's/^desktop-v//p' \
    | sort -V
)

# The desktop-v namespace is only days old and has already been renamed twice,
# so an empty filtered set means the naming moved rather than that no release
# exists. Fail loudly with the evidence instead of silently reporting no-op.
if [[ ${#desktop_versions[@]} -eq 0 ]]; then
  echo "error: no non-prerelease release matching desktop-v* was found" >&2
  echo "observed release tags:" >&2
  printf '%s' "$releases_json" | jq -r '.[].tag_name' | sed 's/^/  /' >&2
  exit 1
fi

latest_version="${desktop_versions[-1]}"
latest_tag="desktop-v${latest_version}"

if [[ "$current_version" == "$latest_version" ]]; then
  echo "buzz source is already at version ${current_version}"
  exit 0
fi

echo "Updating buzz source: ${current_version} -> ${latest_version}"

echo "Computing source hash for tag ${latest_tag}..."
new_sri="$(nix-prefetch-github "$owner" "$repo" --rev "$latest_tag" | jq -r '.hash')"
if [[ -z "$new_sri" || "$new_sri" == "null" ]]; then
  echo "error: nix-prefetch-github did not return a hash" >&2
  exit 1
fi

new_rev="$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${owner}/${repo}/git/ref/tags/${latest_tag}" \
  | jq -r '.object.sha')"
if [[ -z "$new_rev" || "$new_rev" == "null" ]]; then
  echo "error: could not resolve ${latest_tag} to a commit sha" >&2
  exit 1
fi

# package.nix carries two `hash =` lines. Scope each rewrite to one side of the
# passthru block so the src hash and the vendor hash cannot be confused.
passthru_line="$(grep -n '^    passthru = {$' "$pkg_nix" | head -1 | cut -d: -f1)"
if [[ -z "$passthru_line" ]]; then
  echo "error: could not locate the passthru block in ${pkg_nix}" >&2
  exit 1
fi

sed -i'' -e "s|^  version = \"${current_version}\";\$|  version = \"${latest_version}\";|" "$pkg_nix"
sed -i'' -e "1,${passthru_line}s|hash = \"sha256-[^\"]*\"|hash = \"${new_sri}\"|" "$pkg_nix"
sed -i'' -e "${passthru_line},\$s|hash = \"sha256-[^\"]*\"|hash = \"${fake_sri}\"|" "$pkg_nix"
sed -i'' -e "s|rev = \"[0-9a-f]\{40\}\"|rev = \"${new_rev}\"|" "$pkg_nix"

# Fail loudly if any rewrite did not take, rather than reporting success on a no-op.
grep -q "version = \"${latest_version}\"" "$pkg_nix" \
  || { echo "error: version was not updated in package.nix" >&2; exit 1; }
grep -q "hash = \"${new_sri}\"" "$pkg_nix" \
  || { echo "error: src hash was not updated in package.nix" >&2; exit 1; }
grep -q "hash = \"${fake_sri}\"" "$pkg_nix" \
  || { echo "error: vendor hash was not reset in package.nix" >&2; exit 1; }
grep -q "rev = \"${new_rev}\"" "$pkg_nix" \
  || { echo "error: rev was not updated in package.nix" >&2; exit 1; }

echo "Updated buzz source to ${latest_version}"
echo "  tag:      ${latest_tag}"
echo "  rev:      ${new_rev}"
echo "  src hash: ${new_sri}"
echo
echo "The vendor hash was reset to the placeholder and must be recomputed:"
echo "  nix build .#buzz-git-credential-nostr.cargoDeps.vendorStaging"
echo "then copy the reported got: hash into passthru.cargoDeps.hash."
