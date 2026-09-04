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

The key is written at mode 0600 to the path the target configuration's
sops.age.keyFile names, and only rewritten when its content differs, so a
rotated secret is detected and a stable one is left alone.

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
  # The key path is read from the configuration rather than assumed: profiles
  # differ on where sops.age.keyFile points, and a key written anywhere else is
  # a key sops-nix will not find. `nix eval` is the whole of the coupling, so
  # there is no path argument for a caller to get wrong.
  system="$(nix config show system)"
  key_file="$(nix --accept-flake-config eval --raw \
    "${flake}#homeConfigurations.\"${user}@${system}\".config.sops.age.keyFile")"

  seed-age-key --key-file "${key_file}"
fi

if [ "${activate}" -eq 0 ]; then
  printf 'skipping home-manager activation (--no-activate)\n'
  exit 0
fi

# Goes through the `home` app rather than calling nh directly, so the activation
# is the one `just activate-home` performs.
exec nix --accept-flake-config run "${flake}#home" -- "${user}" "${flake}"
