#!/usr/bin/env bash
# shellcheck shell=bash
#
# Writes an age secret key to a file, idempotently. Factored out of
# home-bootstrap so that the session hook the ubuntu profile generates seeds the
# key exactly as the bootstrap app does; a second implementation of the
# normalization below would let the two disagree about whether a key changed and
# rewrite the file past each other.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: seed-age-key --key-file PATH [--help]

Reads an age secret key from SOPS_AGE_KEY, or from the file named by
SOPS_AGE_KEY_FILE, and writes it to PATH at mode 0600. Rewrites PATH only when
its content differs, so a rotated secret is detected and a stable one is left
alone. Exits non-zero when no key source is set or the value carries no
AGE-SECRET-KEY- line.

Options:
  --key-file PATH  Destination for the key (required).
  -h, --help       Print this message.
EOF
}

key_file=''

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --key-file)
      if [ $# -lt 2 ]; then
        printf 'error: --key-file requires a value\n\n' >&2
        usage >&2
        exit 2
      fi
      key_file="$2"
      shift 2
      ;;
    *)
      printf 'error: unknown argument: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "${key_file}" ]; then
  printf 'error: --key-file is required\n\n' >&2
  usage >&2
  exit 2
fi

if [ -n "${SOPS_AGE_KEY:-}" ]; then
  key_source='SOPS_AGE_KEY'
  key_body="${SOPS_AGE_KEY}"
elif [ -n "${SOPS_AGE_KEY_FILE:-}" ]; then
  key_source="${SOPS_AGE_KEY_FILE}"
  if [ ! -s "${SOPS_AGE_KEY_FILE}" ]; then
    printf 'error: SOPS_AGE_KEY_FILE names a missing or empty file: %s\n\n' \
      "${SOPS_AGE_KEY_FILE}" >&2
    usage >&2
    exit 1
  fi
  key_body="$(cat -- "${SOPS_AGE_KEY_FILE}")"
else
  printf 'error: no age key source; set SOPS_AGE_KEY or SOPS_AGE_KEY_FILE\n\n' >&2
  usage >&2
  exit 1
fi

# Trailing whitespace is stripped per line, and command substitution drops the
# trailing newlines, so `desired` is the exact byte sequence written below minus
# its final newline. The comparison against the existing file is then between
# two identically normalized values. Comparing a raw secret against
# "$(cat "$key_file")" instead would report a difference on every run whenever
# the secret carries a trailing newline, rewriting the key each time.
desired="$(printf '%s\n' "${key_body}" | sed 's/[[:space:]]*$//')"

if ! printf '%s\n' "${desired}" | grep -q '^AGE-SECRET-KEY-'; then
  printf 'error: value from %s contains no AGE-SECRET-KEY- line\n' "${key_source}" >&2
  exit 1
fi

if [ -f "${key_file}" ] && [ "$(cat -- "${key_file}")" = "${desired}" ]; then
  printf 'age key at %s already matches %s\n' "${key_file}" "${key_source}"
else
  mkdir -p "$(dirname "${key_file}")"
  (
    umask 077
    printf '%s\n' "${desired}" > "${key_file}.new"
  )
  mv -f "${key_file}.new" "${key_file}"
  printf 'wrote age key to %s from %s\n' "${key_file}" "${key_source}"
fi
chmod 600 "${key_file}"
