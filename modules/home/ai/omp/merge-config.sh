set -euo pipefail

# Overlay the nix-declared keys onto an omp configuration file that omp also
# writes at runtime, so a declared key is authoritative after activation and
# every key omp owns is left as omp wrote it. config.yml carries setupVersion
# and whatever the /settings, /model, and /theme screens persist; WATCHDOG.yml
# is rewritten whole by the /advisor editor.
#
# Merge shape: mappings merge key by key, while sequences and scalars are
# replaced by the declared side. modelRoles therefore keeps a role omp added
# that nix does not name, and the WATCHDOG advisors sequence is a roster nix
# states outright rather than one it appends to.
#
# Limitation, shared with modules/home/ai/atomic/merge-settings.sh: this adds or
# updates a nix-owned key but cannot retract one. A key nix stops declaring
# keeps whatever value it last had, because nothing here records which keys nix
# used to own.

if [ "$#" -ne 2 ]; then
  echo "usage: ${0##*/} <declared.yaml> <target.yaml>" >&2
  exit 2
fi

declared=$1
target=$2

mkdir -p "$(dirname "$target")"

if [ -s "$target" ]; then
  # The target holds omp's own runtime state, so a parse failure aborts the
  # activation rather than replacing a file whose contents could not be read.
  # A multi-document file also fails this test, which is the intended answer:
  # omp writes a single mapping and anything else is not ours to rewrite.
  tag=$(yq eval 'tag' "$target" 2>/dev/null || true)
  if [ "$tag" != '!!map' ]; then
    echo "${0##*/}: $target is not a YAML mapping; refusing to overwrite it" >&2
    exit 1
  fi
  merged=$(yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$target" "$declared")
else
  merged=$(yq eval '.' "$declared")
fi

tmp=$(mktemp "$target.XXXXXX")
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$merged" >"$tmp"
chmod 644 "$tmp"
mv -f "$tmp" "$target"
trap - EXIT
