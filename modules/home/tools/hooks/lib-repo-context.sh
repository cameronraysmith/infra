# shellcheck shell=bash
# Shared repository-context helpers for PreToolUse hooks.
# Prepended to hook scripts by modules/home/tools/hooks/default.nix; not a
# standalone executable and not on PATH.
#
# The helpers answer three questions a hook needs before it can decide anything:
# which repository a command actually targets, whether that repository is
# jj-managed, and whether the caller is sitting inside a linked git worktree.

# Strip the contents of quoted segments, replacing each quoted run with a single
# space and leaving unquoted text (including newlines) verbatim.
# Command-position matching has to run against unquoted text only: a shell
# operator inside a quoted argument is data, not a command boundary, and a
# regex alone cannot tell the two apart.
hook_strip_quoted() {
  local s="$1" out="" head body q
  while [ -n "$s" ]; do
    head="${s%%[\"\']*}"
    if [ "$head" = "$s" ]; then
      out+="$s"
      break
    fi
    out+="$head"
    s="${s:${#head}}"
    q="${s:0:1}"
    s="${s:1}"
    if [ "$q" = "'" ]; then
      body="${s%%\'*}"
    else
      body="${s%%\"*}"
    fi
    if [ "$body" = "$s" ]; then
      s=""
    else
      s="${s:$((${#body} + 1))}"
    fi
    out+=" "
  done
  printf '%s' "$out"
}

# Resolve the directory a shell command targets: `git -C <dir>`, `git
# --git-dir=<dir>`, or a leading `cd <dir>`, falling back to the supplied
# session directory. Prints an absolute path.
# COMMAND must be a single command segment. The option scan takes the last match
# anywhere in the string with no association to a particular invocation, so
# passing a whole command line lets an unrelated later `git -C` decide the
# answer; callers split on shell operators and newlines first.
hook_target_dir() {
  local command="$1" cwd="$2" dir=""
  if [[ "$command" =~ ^[[:blank:]]*cd[[:blank:]]+([^[:space:]\;\&\|]+) ]]; then
    dir="${BASH_REMATCH[1]}"
  fi
  if [[ "$command" =~ (^|[[:blank:]])--git-dir[=[:blank:]]([^[:space:]\;\&\|]+) ]]; then
    dir="${BASH_REMATCH[2]}"
  fi
  if [[ "$command" =~ (^|[[:blank:]])-C[[:blank:]]+([^[:space:]\;\&\|]+) ]]; then
    dir="${BASH_REMATCH[2]}"
  fi
  dir="${dir%\"}"
  dir="${dir#\"}"
  dir="${dir%\'}"
  dir="${dir#\'}"
  case "$dir" in
    */.git | */.git/) dir="${dir%/}"; dir="${dir%/.git}" ;;
  esac
  if [ -z "$dir" ]; then
    printf '%s' "$cwd"
    return 0
  fi
  case "$dir" in
    /*) printf '%s' "$dir" ;;
    ~*) printf '%s' "$dir" ;;
    *) printf '%s' "$cwd/$dir" ;;
  esac
}

# Print the working-tree root of the repository containing DIR, resolved through
# --git-common-dir so that a linked worktree resolves to its primary. Returns 1
# when DIR is not in a git repository.
hook_repo_root() {
  local dir="$1" common
  while [ -n "$dir" ] && [ ! -d "$dir" ] && [ "$dir" != "/" ]; do
    dir=$(dirname "$dir")
  done
  common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  [ -n "$common" ] || return 1
  common="${common%/}"
  case "$common" in
    */.git) printf '%s' "${common%/.git}" ;;
    *) printf '%s' "$(dirname "$common")" ;;
  esac
}

# Print the jj workspace root at or above DIR, or return 1 when there is none.
hook_jj_root() {
  local dir="$1"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -d "$dir/.jj" ]; then
      printf '%s' "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  if [ -d "/.jj" ]; then
    printf '/'
    return 0
  fi
  return 1
}

# Resolve DIR (or the session cwd) to a repository root and report the jj root
# governing it, or return 1 when that repository is not jj-managed.
hook_target_jj_root() {
  local dir="$1" root
  root=$(hook_repo_root "$dir") || root="$dir"
  hook_jj_root "$root"
}

# True when DIR sits inside a linked git worktree rather than the primary
# working tree. jj knows nothing about linked worktrees, so jj-mode hooks that
# would otherwise fire on the primary must no-op here.
hook_in_linked_worktree() {
  local dir="${1:-$PWD}" gitdir commondir
  gitdir=$(git -C "$dir" rev-parse --path-format=absolute --git-dir 2>/dev/null) || return 1
  commondir=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  [ "${gitdir%/}" != "${commondir%/}" ]
}
