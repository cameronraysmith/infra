#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

case "${1:-}" in
  -h|--help)
    cat <<'EOF'
Usage: nixidy-bootstrap [ENVIRONMENT] [--help]

Equivalent to:
  nixidy bootstrap .#ENVIRONMENT | kubectl apply -f -

Transitions Phase 3 (kluctl-driven) infrastructure to Phase 4 (ArgoCD
app-of-apps). ArgoCD must already be Available before invoking.

ENVIRONMENT defaults to local-k3d, whose rendered Application CR points at
the private manifest repo, so ArgoCD needs credentials for it. local-k3d-ci
points at the file:///manifests mount and needs none.
EOF
    exit 0
    ;;
esac

nixidy bootstrap ".#${1:-local-k3d}" | kubectl apply -f -
