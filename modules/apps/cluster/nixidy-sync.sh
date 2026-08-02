#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

case "${1:-}" in
  -h|--help)
    cat <<'EOF'
Usage: nixidy-sync [--help]

Runs `nixidy-build` then `nixidy-push` in-process (no just/nix run
indirection). Requires the same preconditions as the two sub-apps:

  - A configured LOCAL_K3D_REPO directory with a git remote
  - A current directory writable to receive ./result (nixidy-build)

This is the ADR-006 deploy path, which always targets the private manifest
repo. Integration testing against the file:///manifests mount goes through
k3d-integration-ci and does not use this script.

See `nixidy-build --help` and `nixidy-push --help` for details.
EOF
    exit 0
    ;;
esac

nixidy-build
nixidy-push
