#!/usr/bin/env bash
# shellcheck shell=bash
# Consumers: CI effects + justfile wrappers.
set -euo pipefail

case "${1:-}" in
  -h|--help)
    cat <<'EOF'
Usage: nixidy-build [ENVIRONMENT] [--help]

Invokes `nixidy build .#ENVIRONMENT`, producing a ./result/ symlink at the
working directory that materializes the rendered manifest tree.

ENVIRONMENT defaults to local-k3d, which targets the private manifest repo.
Pass local-k3d-ci to target the file:///manifests mount instead; the two are
defined side by side in modules/nixidy.nix.
EOF
    exit 0
    ;;
esac

exec nixidy build ".#${1:-local-k3d}"
