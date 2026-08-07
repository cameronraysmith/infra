# shellcheck shell=bash
# Hook: Ask before `git worktree add` in jj-managed repositories
# A git worktree in a colocated repo is a plain-git tree: jj is unavailable
# inside it and the diamond conventions do not apply. That is a trade-off worth
# surfacing, so the decision goes to the operator rather than being refused.
# Only `git worktree add` is gated; `git worktree list/remove/prune` are allowed.
#
# The command is split into segments at shell operators and newlines, and each
# segment is judged on its own. A segment's repository comes from that segment's
# own `-C` or `--git-dir` plus the directory established by any preceding `cd`,
# so an unrelated later invocation cannot retarget the gate away from a real
# worktree add, and a command aimed at a pure-git repository is still allowed
# even when the session sits in a jj repo. A `cd` inside a subshell is undone at
# the closing paren, as the shell undoes it.
#
# The gate's only product is an ask. Claude Code's documentation directs a hard
# allow or deny to the permission system rather than to a hook, so this is not a
# security boundary and claims no completeness: it recognizes ordinary command
# shapes, and a command written to evade it succeeds. The shapes it is known not
# to catch:
#   - Quoted text is stripped before matching, so `bash -c "git worktree add x"`
#     is not gated. Inside a quoted run a shell operator is data, not a command
#     boundary, and a regex cannot distinguish the two, so command-position
#     matching requires stripping quoted runs first. Closing this gap would mean
#     recursively parsing nested shell, which the gate does not attempt.
#   - The first segment of a continuation line must start at column zero, so an
#     indented occurrence (inside a multi-line `for`/`do` block, or in unquoted
#     heredoc body text) is not gated. Unquoted heredoc bodies are typically
#     indented, and matching indented lines produces false positives on text
#     that only mentions the command.
#   - Command position is recognized through fixed sets of wrappers and shell
#     keywords. Anything outside those sets -- `xargs`, `parallel`, `flock`, a
#     shell function, an alias -- leaves the following `git` unmatched.
#   - The literal `git` token has to be present, so indirection through a
#     variable (`$GIT worktree add`), an alias, or a script is not resolved.
#   - The target directory comes only from `-C`, `--git-dir`, or a preceding
#     `cd`. The environment-variable forms `GIT_DIR` and `GIT_WORK_TREE` are not
#     read, so a command using them is judged against the session directory and
#     can ask about a pure-git target.
# PreToolUse:Bash (sync) -- reads JSON context from stdin.

set -euo pipefail

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Claude Code documents no behavior for a hook-returned "ask" under
# bypassPermissions, so emitting one there would leave the outcome undefined.
# This hook's only product is a prompt, and bypassPermissions is the operator
# removing the prompt channel outright; with nothing to contribute it allows.
# A hard block in that mode belongs in permissions.deny, which the docs state
# applies in every mode including bypassPermissions.
# gate-worktree-surfaces.sh applies the same guard for the same reason.
PERMISSION_MODE=$(echo "$INPUT" | jq -r '.permission_mode // empty' 2>/dev/null || true)
if [ "$PERMISSION_MODE" = "bypassPermissions" ]; then
  exit 0
fi

# The CLAUDE_JJ_WORKSPACE_ISOLATION hatch that gate-worktree-surfaces.sh carries
# is deliberately absent here. That variable redirects the harness isolation
# surfaces to the WorktreeCreate hook, which builds a jj workspace in place of a
# git worktree. A `git worktree add` typed into Bash does not pass through
# WorktreeCreate, so the variable changes nothing about what the command
# produces and the trade-off this gate surfaces still applies in full.

CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
if [ -z "$CWD" ]; then
  CWD="$PWD"
fi

NEWLINE=$'\n'
# Held in variables because bash's ${var//pat/repl} parser ends the expansion at
# the first `}`, including one inside a bracket expression written inline, and
# reads an inline `(` as the start of an extended glob.
OPERATORS='[;&|(){}]'
LPAREN='('
RPAREN=')'
# Subshell boundaries are rewritten to sentinels before the operator split so
# that they survive as segment prefixes. A directory established by `cd` inside
# a subshell has to be discarded at the closing paren.
LMARK=$'\001'
RMARK=$'\002'
# An option token and its optional value. Intervening tokens are restricted to
# this shape so a match cannot span a command boundary.
OPTION='-[^[:space:];&|()]*([[:blank:]]+[^-[:space:];&|()][^[:space:];&|()]*)?'
ASSIGNMENT='[A-Za-z_][A-Za-z_0-9]*=[^[:space:];&|()]*'
# A command-position wrapper: `sudo`, `env FOO=1`, `nice -n 10`, and friends all
# leave the wrapped `git` in command position. `timeout` is spelled separately
# because its duration argument is a bare word rather than an option or an
# assignment.
WRAPPER="((sudo|doas|command|env|nice|time|nohup|stdbuf)([[:blank:]]+(${OPTION}|${ASSIGNMENT}))*|timeout([[:blank:]]+${OPTION})*[[:blank:]]+[0-9]+(\\.[0-9]+)?[smhd]?)[[:blank:]]+"
# Shell keywords that occupy the head of a segment without displacing the
# command that follows them from command position.
KEYWORD='(then|do|else|elif)[[:blank:]]+'
GIT_TOKEN="git([[:blank:]]+${OPTION})*[[:blank:]]+worktree[[:blank:]]+add([[:blank:]]|$)"

ASK=""
EFFECTIVE_CWD="$CWD"
SUBSHELL_CWD=()
LINE_NO=0
while IFS= read -r LINE; do
  MARKED="${LINE//"$LPAREN"/"$NEWLINE$LMARK"}"
  MARKED="${MARKED//"$RPAREN"/"$NEWLINE$RMARK"}"
  SEG_NO=0
  while IFS= read -r SEGMENT; do
    if [ "$LINE_NO" -gt 0 ] && [ "$SEG_NO" -eq 0 ]; then
      ANCHOR="^"
    else
      ANCHOR="^[[:blank:]]*"
    fi
    SEG_NO=$((SEG_NO + 1))

    # Every sentinel is emitted right after an inserted newline, so at most one
    # can lead a segment.
    case "$SEGMENT" in
      "$LMARK"*)
        SUBSHELL_CWD+=("$EFFECTIVE_CWD")
        SEGMENT="${SEGMENT#"$LMARK"}"
        ;;
      "$RMARK"*)
        if [ "${#SUBSHELL_CWD[@]}" -gt 0 ]; then
          EFFECTIVE_CWD="${SUBSHELL_CWD[-1]}"
          unset 'SUBSHELL_CWD[-1]'
        fi
        SEGMENT="${SEGMENT#"$RMARK"}"
        ;;
    esac

    if [[ "$SEGMENT" =~ ^[[:blank:]]*cd([[:blank:]]|$) ]]; then
      EFFECTIVE_CWD=$(hook_target_dir "$SEGMENT" "$EFFECTIVE_CWD")
      continue
    fi

    RE="${ANCHOR}(${KEYWORD})*(${ASSIGNMENT}[[:blank:]]+)*(${WRAPPER})*${GIT_TOKEN}"
    if [[ "$SEGMENT" =~ $RE ]]; then
      TARGET=$(hook_target_dir "$SEGMENT" "$EFFECTIVE_CWD")
      if hook_target_jj_root "$TARGET" >/dev/null; then
        ASK=1
        break
      fi
    fi
  done <<< "${MARKED//$OPERATORS/$NEWLINE}"
  if [ -n "$ASK" ]; then
    break
  fi
  LINE_NO=$((LINE_NO + 1))
done <<< "$(hook_strip_quoted "$COMMAND")"

if [ -z "$ASK" ]; then
  exit 0
fi

REASON="A git worktree here is a plain-git tree: jj is unavailable inside it and the diamond conventions do not apply. Prefer the diamond development join for parallel chains, and take a worktree when a separate filesystem tree is itself the point. See ~/.claude/skills/jj-version-control/SKILL.md."

cat << EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"$REASON"}}
EOF
exit 0
