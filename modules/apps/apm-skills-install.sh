#!/usr/bin/env bash
# shellcheck shell=bash
#
# producer-path materialization for the vanixiets apm skills marketplace.
#
# materializes the marketplace this repo publishes back into the repo it is
# published from: the 18 packages under modules/home/ai/plugins/ are declared
# as apm.yml `dependencies.apm` entries pointing at
# cameronraysmith/vanixiets/modules/home/ai/plugins/<group>#main, so a run of
# this script resolves them from github `main` rather than the local
# worktree. that makes the committed apm.lock.yaml reproduce identically in
# any environment (ephemeral dev shells included), independent of what the
# local checkout happens to contain at run time.
#
# `apm init` and positional-argument `apm install <pkg>` are never invoked
# here: both write apm.yml back through apm's ruamel-based writer, which
# would reflow the over-80-column `source:` values in the existing
# `marketplace:` publishing block or, in `apm init`'s case, overwrite the
# whole manifest. `apm compile` is never invoked either: it replaces the
# `AGENTS.md` path with a fresh regular file via `os.replace`, which would
# sever the repo's existing symlink to the planning-repo context file.
#
# unlike apm-marketplace-validate.sh, this script deliberately does NOT
# isolate $HOME or override APM_CACHE_DIR: it targets the shared warm apm
# git cache at the platform cache dir, which is what lets a lock-honoring
# `apm install --frozen` succeed without network access; validate isolates
# because it is exercising the cold consumer path instead.
#
# two mutually exclusive modes:
#   (default)  apm install --frozen   materialize from the committed lockfile.
#   --relock   full re-resolution     rebuild the lockfile from scratch so a
#              newly appeared transitive dependency is discovered.
#
# grep-able marker: APM-SKILLS-INSTALL-OK
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: apm-skills-install [--relock] [-h|--help]

Materializes this repo's own 18 apm skill packages (declared in apm.yml
`dependencies.apm`, resolved from github cameronraysmith/vanixiets `main`)
into .agents/skills/, using the shared warm apm git cache. Never isolates
$HOME or APM_CACHE_DIR.

Modes:
  (default)  apm install --frozen  — install strictly from the committed
             apm.lock.yaml; fails if manifest and lock disagree.
  --relock   full re-resolution — rebuild the lockfile from scratch so a
             newly appeared transitive dependency is discovered.

Options:
  -h, --help  show this help and exit.
EOF
}

mode=frozen
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --relock) mode=refresh ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

repo_root="$(git rev-parse --show-toplevel)"
cd "${repo_root}"

# guard: refuse to run against anything but this repository's producer
# manifest, so a misplaced invocation cannot install into an unrelated
# project's apm_modules/.
if [ ! -f apm.yml ]; then
  echo "apm-skills-install: no apm.yml at repo root ${repo_root}" >&2
  exit 1
fi
manifest_output="$(yq -r '.marketplace.output' apm.yml)"
if [ "${manifest_output}" != ".github/plugin/marketplace.json" ]; then
  echo "apm-skills-install: apm.yml at ${repo_root} is not the vanixiets producer manifest (marketplace.output=${manifest_output})" >&2
  exit 1
fi

echo "=== apm-skills-install (mode=${mode}) ==="
echo "repo_root: ${repo_root}"
apm --version | head -1 || true
echo ""

if [ "${mode}" = frozen ]; then
  if [ ! -f apm.lock.yaml ]; then
    echo "apm-skills-install: apm.lock.yaml is missing; run 'just agents-relock' first" >&2
    exit 1
  fi
  apm install --frozen
else
  # Relock re-solves the graph from scratch rather than using --refresh,
  # because --refresh only re-resolves pins that are ALREADY in the lockfile
  # and silently ignores a transitive dependency that has since appeared in a
  # package's own manifest. That is not hypothetical: a mergify-stack skill
  # dependency added upstream stayed invisible across a --refresh whose diff
  # was exactly 57 insertions and 57 deletions, pure substitution with no
  # additions, until the lockfile was removed and resolution rerun.
  #
  # The lockfile is preserved and restored if resolution fails, so a network
  # or upstream error cannot leave the repository without one.
  lock_backup="$(mktemp)"
  if [ -f apm.lock.yaml ]; then
    cp apm.lock.yaml "${lock_backup}"
    rm -f apm.lock.yaml
  fi
  if ! apm install; then
    if [ -s "${lock_backup}" ]; then
      cp "${lock_backup}" apm.lock.yaml
      echo "apm-skills-install: resolution failed; restored the previous apm.lock.yaml" >&2
    fi
    rm -f "${lock_backup}"
    exit 1
  fi
  rm -f "${lock_backup}"
fi
echo ""

mapfile -t skill_files < <(find "${repo_root}/.agents/skills" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | sort)
skill_count="${#skill_files[@]}"

echo "deployed skill count: ${skill_count}"
echo "paths written:"
echo "  ${repo_root}/.agents/skills"
if [ -d "${repo_root}/apm_modules" ]; then
  echo "  ${repo_root}/apm_modules"
fi

if [ "${mode}" = refresh ]; then
  echo ""
  echo "apm.lock.yaml diff:"
  git diff --stat -- apm.lock.yaml || true
fi

echo ""
echo "APM-SKILLS-INSTALL-OK: ${skill_count} skill(s) deployed to .agents/skills/"
