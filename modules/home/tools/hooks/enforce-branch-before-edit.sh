# shellcheck shell=bash
# Hook: Enforce feature branch before file edits
# Prevents editing tracked files on main/master branch.
# Allows configuration, plan, and issue tracking files unconditionally.
# PreToolUse:Edit|Write|MultiEdit (sync) -- reads JSON context from stdin.

set -euo pipefail

INPUT=$(cat)

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Allow edits if no file path (shouldn't happen, but fail open)
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Allow list: always permit edits to these paths. `/.worktrees/` is the
# git-native isolation convention described in
# ~/.claude/skills/preferences-git-version-control/01-git-native-mode.md, where
# the branch checked out in the worktree carries the ID-descriptor name; the
# path allowance covers editing such a tree from a session whose own cwd is the
# primary. The harness places its own worktrees under `.claude/worktrees/`,
# already covered by `/.claude/`.
ALLOWED_PATHS='(/\.claude/|/\.worktrees/|CLAUDE\.md$|CLAUDE\.local\.md$|/plans/|/\.beads/)'
if [[ "$FILE_PATH" =~ $ALLOWED_PATHS ]]; then
  exit 0
fi

# Allow if the session sits inside a linked worktree; isolation branches there
# are named by the worktree tooling and are never main/master.
if hook_in_linked_worktree "$(pwd)"; then
  exit 0
fi

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# Get current branch name
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [ -z "$BRANCH" ]; then
  # Detached HEAD or other non-branch state; allow the edit
  exit 0
fi

# Block edits on main or master
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  cat << EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Cannot edit files on $BRANCH. Create a working branch named for the Linear story or OpenSpec change this implements -- git checkout -b <ID>-descriptor -- then retry the edit. See ~/.claude/skills/preferences-git-version-control/SKILL.md (branch workflow)."}}
EOF
  exit 0
fi

# On a feature branch; allow the edit
exit 0
