# HIL apply-phase isolation under jj mode

The HIL mode delegates to the openspec-* and superpowers skills via the superpowers-bridge.
The bridge apply node reaches superpowers:using-git-worktrees, which resolves to a raw git worktree add.
In this jj-mode environment that surface is ask-gated rather than denied, so the router states which mechanism the apply phase should use rather than letting the bridge's default decide.

This file owns the isolation policy for the HIL apply phase.
The board states and gates live in references/board-and-gates.md; the per-mode entry criteria live in references/execution-modes.md.

## How git worktree add behaves here

The repository runs jujutsu in colocated mode.
The harness ask-gates the worktree-creating surfaces when the target repository is jj-colocated: `git worktree add`, EnterWorktree, and subagent dispatch (tool name `Agent`) with `isolation: "worktree"` each raise an ask, and ExitWorktree is ungated.
The harness's WorktreeCreate path creates a real git worktree under `<jj-root>/.claude/worktrees/<name>`; with CLAUDE_JJ_WORKSPACE_ISOLATION=1 it creates an in-tree jj workspace instead.
superpowers:using-git-worktrees already prefers the harness's native worktree tool over raw git worktree add and its step 0 detects existing isolation, so the ask usually surfaces at the harness tool rather than at the shell command.

## The jj diamond development join is the default

The default for the HIL apply phase is the diamond development join.
Parallel chains of work share a single working copy: a multi-parent working-copy commit merges the active chains, edits route as new commits onto a chain, and jj auto-rebases the join and the working-copy commit after each routed commit.
Where the superpowers worktree skill would create an isolated worktree per task, the diamond routes the unit of work onto its chain inside the one working copy.
For a sequential, orchestrator-routed apply this is the right tool and no separate tree is created.

## When a separate tree is warranted instead

Answer the worktree ask affirmatively when a separate filesystem tree is itself the requirement rather than a convenience.
The qualifying cases are an external agent framework driving its own process against the repository, a long-running build that must not observe ongoing edits, and a side-by-side comparison of two states.
Multiple writers concurrently touching the shared working copy is not one of them by default: the preventive mechanic (pre-dispatch concurrent-agent coordination, orchestrator-routed `jj squash --from @`, scoped `jj absorb`) is the parallel-agent coordination protocol in the jj-version-control skill, and it applies whenever the writers can be serialized through the orchestrator.

In a flake repository the separate tree must be a git worktree, because a jj workspace has no `.git` and flake evaluation there degrades to a `path:` source with no revision.
CLAUDE_JJ_WORKSPACE_ISOLATION=1 therefore selects the jj-workspace form only for non-flake repositories.
A worktree and the diamond nest rather than compete: the tree gives an isolated checkout, the diamond integrates chains inside whichever tree holds them.

A worktree carries obligations the diamond does not.
A branch is owned by exactly one working copy; work returns from the worktree by ref rather than by checkout; and the primary's HEAD stays detached throughout.
Read `~/.claude/skills/jj-version-control/SKILL.md` §"Worktree interop" before creating one — it is the authority for the ownership rules, the return path, the forbidden operations against the primary, and the recovery commands.

## The apply gate confirms the choice

The mechanical default stands: the diamond development join for the common case of a sequential, orchestrator-routed apply, and a separate tree only under the triggers above.
The apply executor confirms the choice at the apply gate per the change's Risks and Open Questions rather than assuming it, because whether an external process needs its own tree is a property of the change and not of the router.

## Orchestrator-routed commits and no autonomous PR

Commits during the HIL apply phase are orchestrator-routed onto the chain.
The orchestrator routes each commit as a new commit onto the unit's chain inside the shared working copy, rather than the bridge's subagent-driven auto-commit-and-PR flow running unattended.

Routing is always downward from the shared empty `[wip]` at `@`, never by mutating `@` itself.
In development-join mode `@` is the empty `[wip]` commit atop the frozen multi-parent merge, and that `[wip]` is the shared coordination surface every editor writes; content leaves it by routing DOWN into the owning chain with `@` left in place and empty.
Do not consume the wip with `jj describe @`, and do not relocate `@` below the join with a positional `jj rebase -r @ --insert-before/--insert-after`; either drift removes the surface other actors are concurrently writing.
For the canonical invariant and the editor-safe routing-down command templates (`jj absorb`, `jj squash --from @ … --keep-emptied`, `jj split`), see the development-join invariant (iii-b) in `jj-version-control/SKILL.md`.

Integration is jj-native and user-gated.
The bridge's finishing-a-development-branch step would open a PR; under jj the chain is instead linearized onto main by sequential rebase at completion, and that integration is a user-gated decision.
There is no autonomous PR: the router does not open a pull request as a side effect of the apply phase.
A PR into the monorepo remains one realization of the terminal artifact when the human elects the PR-when-warranted path, but it is never an automatic consequence of reaching In Review.
