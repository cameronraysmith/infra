#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

case "${1:-}" in
  -h|--help)
    cat <<'EOF'
Usage: nixidy-push [--help]

Prerequisites:
  - `nixidy-build` has run in the current directory, producing ./result
  - Push access to the local-k3d manifest repo

rsync copies result/ → $LOCAL_K3D_REPO/ with --delete, dereferencing
nix-store symlinks and normalizing permissions. Exits 0 cleanly when
there is nothing to push (no changes detected).

The target is cloned when absent, so no directory needs to pre-exist.

Environment:
  LOCAL_K3D_REPO   target repo path
                   (default: sibling of this worktree, ../local-k3d)
EOF
    exit 0
    ;;
esac

LOCAL_K3D_REPO="${LOCAL_K3D_REPO:-$(dirname "$(git rev-parse --show-toplevel)")/local-k3d}"

if [[ ! -d "result" ]]; then
  echo "Error: result/ directory not found. Run 'just nixidy-build' first." >&2
  exit 1
fi

# Test for .git, not the directory: an empty directory left behind by a
# previous run would otherwise pass the guard and fail later at git add.
if [[ ! -d "$LOCAL_K3D_REPO/.git" ]]; then
  echo "Cloning local-k3d manifest repo to $LOCAL_K3D_REPO..."
  git clone git@github.com:cameronraysmith/local-k3d.git "$LOCAL_K3D_REPO"
fi

echo "Syncing rendered manifests to $LOCAL_K3D_REPO..."
# -L dereferences symlinks (nix store paths) to copy actual content
# --checksum compares by content hash (Nix store files have epoch timestamps)
# --chmod fixes read-only permissions from nix store
rsync -aL --delete --checksum --chmod=Du+w,Fu+w --exclude='.git' result/ "$LOCAL_K3D_REPO/"

echo "Committing and pushing to local-k3d repo..."
cd "$LOCAL_K3D_REPO"
git add -A
if git diff --cached --quiet; then
  echo "No changes to push."
else
  git commit -m "chore: update rendered manifests from vanixiets"
  git push
  echo "Manifests pushed to local-k3d repo."
fi
