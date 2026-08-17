set -euo pipefail

# Overlay the nix-declared keys onto an agent settings file that the agent also
# writes at runtime, replacing each declared key wholesale and leaving every
# other key as the agent left it.
#
# Limitation: this can add or update a nix-owned key but not retract one. A key
# that nix stops declaring keeps whatever value it last had in the target file,
# because nothing here records which keys nix used to own.

if [ "$#" -ne 2 ]; then
  echo "usage: ${0##*/} <declared.json> <target.json>" >&2
  exit 2
fi

declared=$1
target=$2

mkdir -p "$(dirname "$target")"

if [ -e "$target" ]; then
  # The target sits beside credential state, so a parse failure aborts the
  # activation rather than replacing a file whose contents we could not read.
  if ! jq -e 'type == "object"' "$target" >/dev/null 2>&1; then
    echo "${0##*/}: $target is not a JSON object; refusing to overwrite it" >&2
    exit 1
  fi
  merged=$(jq --sort-keys --slurpfile declared "$declared" '. + $declared[0]' "$target")
else
  merged=$(jq --sort-keys . "$declared")
fi

tmp=$(mktemp "$target.XXXXXX")
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$merged" >"$tmp"
chmod 644 "$tmp"
mv -f "$tmp" "$target"
trap - EXIT
