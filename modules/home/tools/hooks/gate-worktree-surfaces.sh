# shellcheck shell=bash
# Hook: Gate worktree-creating tool surfaces in jj mode
# Fires on EnterWorktree and on Agent dispatches with tool_input.isolation ==
# "worktree" when the target repository is jj-managed. ExitWorktree is not
# gated: leaving a worktree carries none of the trade-off, and gating it strands
# worktrees created by tooling that cleans up after itself.
# PreToolUse (sync) -- reads JSON context from stdin.

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
if [ -z "$CWD" ]; then
  CWD="$PWD"
fi
TARGET=$(echo "$INPUT" | jq -r '.tool_input.path // empty' 2>/dev/null || true)
if [ -z "$TARGET" ]; then
  TARGET="$CWD"
fi

if ! hook_target_jj_root "$TARGET" >/dev/null; then
  # Not a jj repo; worktrees are documented git-native workflow.
  exit 0
fi

# Escape hatch: when CLAUDE_JJ_WORKSPACE_ISOLATION=1, let the harness isolation
# surfaces through to the WorktreeCreate hook, which redirects creation to a jj
# workspace. Kept byte-identical to the same gate in jj-worktree-create.sh.
if [ "${CLAUDE_JJ_WORKSPACE_ISOLATION:-0}" = "1" ]; then
  exit 0
fi

# Claude Code documents no behavior for a hook-returned "ask" under
# bypassPermissions, so emitting one there would leave the outcome undefined.
# This hook's only product is a prompt, and bypassPermissions is the operator
# removing the prompt channel outright; with nothing to contribute it allows.
# A hard block in that mode belongs in permissions.deny, which the docs state
# applies in every mode including bypassPermissions.
PERMISSION_MODE=$(echo "$INPUT" | jq -r '.permission_mode // empty' 2>/dev/null || true)
if [ "$PERMISSION_MODE" = "bypassPermissions" ]; then
  exit 0
fi

TRADEOFF="Prefer the diamond development join for parallel chains, and take a worktree when a separate filesystem tree is itself the point. See ~/.claude/skills/jj-version-control/SKILL.md."

case "$TOOL_NAME" in
  EnterWorktree)
    REASON="EnterWorktree makes a plain-git tree here: jj is unavailable inside it and the diamond conventions do not apply. $TRADEOFF"
    cat << EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"$REASON"}}
EOF
    exit 0
    ;;
  Agent)
    ISOLATION=$(echo "$INPUT" | jq -r '.tool_input.isolation // empty' 2>/dev/null || true)
    if [ "$ISOLATION" = "worktree" ]; then
      REASON="isolation=\\\"worktree\\\" makes a plain-git tree here; without it the subagent inherits cwd and operates on the same jj working copy. $TRADEOFF"
      cat << EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"$REASON"}}
EOF
      exit 0
    fi
    ;;
esac

# All other cases allow.
exit 0
