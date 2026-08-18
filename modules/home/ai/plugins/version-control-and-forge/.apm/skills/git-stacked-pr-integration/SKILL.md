---
name: git-stacked-pr-integration
description: Git-native stacked-base PR integration with an aggregate PR landing the whole stack by one fast-forward push of main. Covers base chaining via gh pr edit, plain-git force-with-lease rebasing pinned to recorded SHAs, ancestry-based topology verification, and the frozen-lower-branch precondition. Use when landing a git-native (non-jj) PR stack or reviewing how stacked PRs integrate without merge commits.
---

# Git-native stacked-base + aggregate PR integration

This is the git-and-GitHub complement to the colocated-jj stacked integration documented in the `jj-version-control` skill ("N+1 stacked-base PR submission" under Integration strategies at completion, automated there by `jj-stack-submit` and `jj-linearize-join`).
The same shape — N stacked-base chain PRs plus one aggregate PR — is expressed here entirely with plain git, `gh`, and GitHub's base-chaining, with no jj state and no merge commits.
The `gh-stack` skill documents the upstream `gh stack` CLI for viewing and managing the stack representation; this skill covers the integration mechanics, including where `gh stack push` must be avoided.

The pattern was verified landing PRs 2738, 2739, and 2740 in cameronraysmith/vanixiets on 2026-08-18: main was fast-forwarded to fe5a4b71 and GitHub merged all three PRs by reachability within one second.

## The pattern

Given a lower branch `lower` and an upper branch `upper` (each with its own PR), plus an aggregate PR whose head is the same commit as the stack tip:

1. Chain the upper PR's base to the lower PR's branch:

```bash
gh pr edit <upper-pr> --base <lower-branch>
```

GitHub's base-chaining is the stack representation reviewers see, and `gh stack` views and manages that representation.
Do not maintain a parallel local notion of stack structure; the forge's base pointers are the source of truth.

2. Rebase the upper commits onto the lower tip and publish with plain git, pinning the lease to an independently recorded old SHA:

```bash
git fetch origin <upper-branch>
OLD_SHA=$(git rev-parse origin/<upper-branch>)   # record BEFORE rebasing
git rebase <lower-tip> <upper-branch>
git push --force-with-lease=<upper-branch>:$OLD_SHA origin <upper-branch>
```

Never use `gh stack push` for this step: its lease refresh can overwrite third-party updates to the branch.
The upper PR's SHAs replay exactly once — unavoidable when its base moves — while the lower PR's SHAs stay byte-exact.

3. Create the aggregate PR with its head branch pointing at the SAME commit as the stack tip, targeting main:

```bash
gh pr create -B main -H <stack-tip-branch> -t "..." -b ""
```

4. Land everything with one local fast-forward push of main to the aggregate head SHA.
This lands every commit with no merge commit, and the forge merges every PR in the stack by reachability — GitHub auto-closes a PR as merged when its head commit becomes reachable from the default branch, regardless of the PR's base.
The aggregate PR is therefore a completely fast-forwardable integration gate: the git-native equivalent of a merge queue's synthetic merge, without any synthetic commit.

```bash
git push origin <stack-tip-sha>:main
```

## Verification and preconditions

Verify topology with plain-git ancestry, never with stored stack metadata:

```bash
git merge-base --is-ancestor main <lower-branch> &&
git merge-base --is-ancestor <lower-branch> <upper-branch> &&
git merge-base --is-ancestor <upper-branch> <aggregate-head>
```

Precondition: the lower branch must be frozen.
Any push to it stales every branch stacked above, forcing another replay of the upper SHAs.
Before rebasing, confirm `origin/<lower-branch>` still matches the tip the upper commits were rebased onto.

## Relationship to the jj tooling

In colocated-jj repositories, the equivalent flow is the N+1 stacked-base + aggregate pattern from the `jj-version-control` skill: push N chain bookmarks plus one aggregate bookmark, create N stacked-base chain PRs plus one aggregate PR targeting main, advance main to the aggregate tip, and exit the development join.
The tools `jj-stack-submit` (submission) and `jj-linearize-join` (exit) automate it.
Use that path whenever `.jj/` is present; use this skill's plain-git mechanics only in git-native repositories where no jj state exists.
