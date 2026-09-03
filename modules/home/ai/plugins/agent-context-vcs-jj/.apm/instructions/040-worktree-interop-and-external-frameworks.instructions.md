---
description: Task-dispatch isolation defaults to the diamond join; worktree creation is ask-gated with exclusive branch ownership and return-by-ref, and jj-state-protecting prohibitions on force-checkout, branch deletion, prune, and stash.
---

## Worktree interop and external frameworks

Subagent dispatch in jj-mode repositories omits the `isolation` parameter by default, because the diamond development join already supplies the isolation; setting `isolation: "worktree"` raises an ask and is warranted only when the subagent genuinely needs its own filesystem tree.

Worktree creation is ask-gated: answer affirmatively only when a separate filesystem tree is itself the point; otherwise stay on the development join.
In a flake repository that tree must be a git worktree rather than `jj workspace add`.
The discipline is exclusive branch ownership — a branch belongs to the jj primary or to one worktree, never both — and return-by-ref: commit in the worktree, integrate by ref in the primary.
The primary's HEAD stays detached throughout; never reattach it, force-checkout, delete branches, `git fetch --prune`, or `git stash` in a jj working copy.
An external agent framework such as firstmate gets its own clone rather than a symlink to a working copy we also use, because its fleet-sync runs exactly the operations forbidden above.
Full mechanics and recovery: the `jj-version-control` skill §"Worktree interop".
