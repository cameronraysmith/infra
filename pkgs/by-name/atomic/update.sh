#!/usr/bin/env nix-shell
#!nix-shell --pure -i bash -p curl jq cacert git python3 nodejs nix
# shellcheck shell=bash

# Update pkgs/by-name/atomic to the latest npm release of @bastani/atomic:
#   1. resolve the version from the registry's latest dist-tag,
#   2. verify the tarball against the registry's published sha512 integrity,
#   3. re-derive npm-dist-repairs.patch for that tarball (the integrity
#      backfill for @bastani/atomic-natives* entries and the devDependencies
#      removal - see package.nix for why both are needed),
#   4. write manifest.json and the src hash into package.nix,
#   5. run one build cycle to learn the new npmDepsHash from the mismatch
#      (a no-op when the dependency closure is unchanged), then a verifying
#      build.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
PKG_DIR="${REPO_ROOT}/pkgs/by-name/atomic"
ENC_PACKAGE="%40bastani%2Fatomic"

version="$(curl -fsSL "https://registry.npmjs.org/${ENC_PACKAGE}" | jq -r '.["dist-tags"].latest')"
[ -n "$version" ] || { echo "error: empty latest version" >&2; exit 1; }
tarball="https://registry.npmjs.org/@bastani/atomic/-/atomic-${version}.tgz"
echo "updating @bastani/atomic to ${version}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl -fsSL "$tarball" -o "$work/atomic.tgz"
mkdir -p "$work/package"
tar -xzf "$work/atomic.tgz" -C "$work/package" --strip-components=1

python3 - "$work" "$PKG_DIR/npm-dist-repairs.patch" "$version" <<'PY'
import base64, difflib, hashlib, json, re, sys, urllib.parse, urllib.request

work, patch_path, version = sys.argv[1], sys.argv[2], sys.argv[3]
pkg_dir = f"{work}/package"

def registry(path):
    with urllib.request.urlopen(f"https://registry.npmjs.org/{path}") as r:
        return json.load(r)

# The bytes the nix hash is derived from must match the registry's published
# integrity for the same version.
meta = registry(urllib.parse.quote("@bastani/atomic", safe="") + "/" + version)
digest = "sha512-" + base64.b64encode(
    hashlib.sha512(open(f"{work}/atomic.tgz", "rb").read()).digest()
).decode()
assert digest == meta["dist"]["integrity"], "tarball does not match registry integrity"

# Repair 1: backfill integrity for entries the shrinkwrap generator left
# without one (the workspace-internal @bastani/* packages).
shrink_src = open(f"{pkg_dir}/npm-shrinkwrap.json").read()
shrink = json.loads(shrink_src)
integ = {}
for key, entry in shrink["packages"].items():
    if key == "" or "integrity" in entry:
        continue
    resolved = entry.get("resolved", "")
    m = re.match(r"https://registry\.npmjs\.org/(.+)/-/.+\.tgz$", resolved)
    if not m:
        sys.exit(f"error: non-registry entry without integrity: {key}")
    dist = registry(f"{urllib.parse.quote(m.group(1), safe='')}/{entry['version']}")["dist"]
    if dist["tarball"] != resolved:
        sys.exit(f"error: registry tarball moved for {key}")
    integ[m.group(1)] = dist["integrity"]

out = []
for line in shrink_src.split("\n"):
    out.append(line)
    m = re.match(r'^(\t+)"resolved": "(https://registry\.npmjs\.org/(.+)/-/.+\.tgz)",$', line)
    if m and m.group(3) in integ:
        out.append(f'{m.group(1)}"integrity": "{integ[m.group(3)]}",')
shrink_new = "\n".join(out)
json.loads(shrink_new)  # validate

# Repair 2: delete the devDependencies object, which the generated shrinkwrap
# does not cover and `npm ci` would try to resolve from the network.
pkg_src = open(f"{pkg_dir}/package.json").read()
m = re.search(r'^(\s*)"devDependencies": \{\s*$', pkg_src, re.M)
if m:
    i = pkg_src.index("{", m.start())
    depth = 0
    for j in range(i, len(pkg_src)):
        if pkg_src[j] == "{":
            depth += 1
        elif pkg_src[j] == "}":
            depth -= 1
            if depth == 0:
                end = j + 1
                if pkg_src[end : end + 1] == ",":
                    end += 1
                break
    pkg_new = re.sub(r"\n{3,}", "\n\n", pkg_src[: m.start()] + pkg_src[end:])
    json.loads(pkg_new)  # validate
else:
    pkg_new = pkg_src

def unified(a, b, name):
    lines = list(difflib.unified_diff(a.split("\n"), b.split("\n"), n=3, lineterm=""))
    return f"--- a/{name}\n+++ b/{name}\n" + "\n".join(lines[2:]) + "\n"

open(patch_path, "w").write(
    unified(shrink_src, shrink_new, "npm-shrinkwrap.json")
    + unified(pkg_src, pkg_new, "package.json")
)
print(f"regenerated npm-dist-repairs.patch ({len(integ)} integrity backfills)")
PY

jq -n --arg version "$version" '{version: $version}' > "$PKG_DIR/manifest.json"

src_hash="$(nix store prefetch-file --json "$tarball" | jq -r .hash)"
python3 - "$PKG_DIR/package.nix" "$src_hash" <<'PY'
import re, sys
path, src_hash = sys.argv[1], sys.argv[2]
s = open(path).read()
s, n = re.subn(r'(hash = )"?sha256-[A-Za-z0-9+/=]+"?;', rf'\g<1>"{src_hash}";', s, count=1)
assert n == 1, "src hash line not found"
open(path, "w").write(s)
print(f"wrote src hash {src_hash}")
PY

# npmDepsHash: a bumped closure makes the committed hash mismatch; the error
# carries the correct value. An unchanged closure builds clean and skips this.
got="$(nix build --no-link "$REPO_ROOT#atomic" 2>&1 || true)"
got="$(printf '%s' "$got" | grep -oE 'got: +sha256-[A-Za-z0-9+/=]+' | head -1 | tr -d ' ' | sed 's/^got://' || true)"
if [ -n "$got" ]; then
  python3 - "$PKG_DIR/package.nix" "$got" <<'PY'
import re, sys
path, got = sys.argv[1], sys.argv[2]
s = open(path).read()
s, n = re.subn(r'(npmDepsHash = )"sha256-[A-Za-z0-9+/=]+";', rf'\g<1>"{got}";', s, count=1)
assert n == 1, "npmDepsHash line not found"
open(path, "w").write(s)
print(f"wrote npmDepsHash {got}")
PY
fi

echo "verifying build"
nix build -L --no-link "$REPO_ROOT#atomic"
echo "atomic updated to ${version}; run the checks before pushing"
