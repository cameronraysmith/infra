#!/usr/bin/env bash
# shellcheck shell=bash
#
# Env-or-file contract, mirroring modules/apps/cluster/k3d-bootstrap-secrets.sh:
#   SOPS_AGE_KEY        (env)  age secret key for the profile being activated
#   SOPS_AGE_KEY_FILE   (path) a file holding the same value
#
# The env branch is the sandbox pathway: a hosted agent environment exposes its
# secrets in the environment. The file branch exists so the app can be exercised
# outside such an environment without putting a key in a shell history or
# process table.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: home-bootstrap [--flake REF] [--user NAME] [--no-activate] [--help]
       home-bootstrap --without-secrets [--flake REF] [--user NAME]

Activates a home-manager profile, seeding the age key that decrypts its sops
secrets when that key is available. Needs no checkout: it reads everything it
activates from the flake reference, which defaults to the published repository.

Two modes, split by whether the environment supplies the secret.

The default mode requires a key, writes it, and activates. Secrets are
installed during that activation. This is the session-start path.

--without-secrets requires no key, writes none, and activates. The generation
that lands carries the profile's packages, files, and session variables; the
sops install step reports that it is skipping and continues, so nothing
decrypted is produced. This is the image and snapshot build path, where no
secret exists. An activation in the default mode must follow at session start;
that is what installs the secrets.

Runs once and exits: it never loops, retries, or writes a stamp file. Any
failure exits non-zero.

Key source in the default mode (first found):
  SOPS_AGE_KEY            environment variable
  SOPS_AGE_KEY_FILE       path to a file holding the key

The key is written to ~/.config/sops/age/keys.txt at mode 0600, and only
rewritten when its content differs, so a rotated secret is detected and a
stable one is left alone.

Options:
  --flake REF        Flake reference to activate from
                     (default: github:cameronraysmith/vanixiets).
                     The ref floats; github:cameronraysmith/vanixiets/<rev>
                     pins it.
  --user NAME        home-manager user to activate (default: ubuntu).
  --without-secrets  Activate without seeding a key, for an environment that
                     has none.
  --no-activate      Seed the key and exit without activating home-manager.
  -h, --help         Print this message.

Example, from a hosted agent sandbox with no checkout of this repository:
  SOPS_AGE_KEY=... nix run --accept-flake-config \
    github:cameronraysmith/vanixiets#home-bootstrap
EOF
}

activate=1
flake='github:cameronraysmith/vanixiets'
user='ubuntu'
without_secrets=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --flake)
      if [ $# -lt 2 ]; then
        printf 'error: --flake requires a value\n\n' >&2
        usage >&2
        exit 2
      fi
      flake="$2"
      shift 2
      ;;
    --user)
      if [ $# -lt 2 ]; then
        printf 'error: --user requires a value\n\n' >&2
        usage >&2
        exit 2
      fi
      user="$2"
      shift 2
      ;;
    --without-secrets)
      without_secrets=1
      shift
      ;;
    --no-activate)
      activate=0
      shift
      ;;
    *)
      printf 'error: unknown argument: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "${without_secrets}" -eq 1 ] && [ "${activate}" -eq 0 ]; then
  printf 'error: --without-secrets and --no-activate together leave nothing to do\n\n' >&2
  usage >&2
  exit 2
fi

printf 'home-bootstrap: user=%s flake=%s\n' "${user}" "${flake}"

if [ "${without_secrets}" -eq 1 ]; then
  printf 'seeding no age key (--without-secrets); the profile activates and its sops install step skips\n'
else
  # home-manager's xdg.configHome defaults to ${home.homeDirectory}/.config and
  # ignores the ambient XDG_CONFIG_HOME (home-manager modules/misc/xdg/default.nix),
  # so base-sops resolves sops.age.keyFile from HOME. Deriving it from
  # XDG_CONFIG_HOME here would put the key somewhere sops-nix does not read.
  key_file="${HOME}/.config/sops/age/keys.txt"

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
fi

if [ "${activate}" -eq 0 ]; then
  printf 'skipping home-manager activation (--no-activate)\n'
  exit 0
fi

# Goes through the `home` app rather than calling nh directly, so the activation
# is the one `just activate-home` performs.
exec nix --accept-flake-config run "${flake}#home" -- "${user}" "${flake}"
