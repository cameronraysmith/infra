# Stacked landing mechanism and settings review

This review is for the maintainer who will authorize the first live stacked landing.
The settings below are proposals only; this change does not apply them.
The mechanism was validated structurally against a local bare remote, and no commit was pushed to GitHub `main`.

## Mechanism

Run `just stack-land --dry-run --tip <stack-tip> <pr>...` to validate a stack without pushing.
Run the same command without `--dry-run` to make one fast-forward-only update of `main` through `git push origin <tip>:refs/heads/main`.

The script fails unless the fetched target base is an ancestor of the tip, every commit in the range carries exactly one valid `Change-Id`, every member PR has a non-empty JSON check set whose states are all `SUCCESS`, and every member PR reports `MERGED` with `mergedAt` set after the push.
It fetches and repeats the ancestry check after the forge checks and immediately before the push.
The push has no force option, so a competing non-fast-forward update is rejected by the remote.

`bash scripts/test-stack-land.sh` creates its repository and bare `origin` below `.scratch/`, then removes that fixture when it exits.
The test demonstrates failures for divergent ancestry, missing, duplicate, and malformed trailers, a `CANCELLED` check, an empty check set, a target change between the first and second ancestry checks, a target change in the pre-push race, and an open PR after a successful push.
It also demonstrates a dry run that leaves `main` unchanged and a real local landing that advances `main` to the tip and observes all PRs as merged.

The test is focused local evidence, not regression protection.
The standing protection constraint leaves one design question for the flake/nixbot owner: expose this test as a nix flake check or add equivalent coverage in nixbot before making it mandatory.
A GitHub Actions workflow or a command wrapper would not satisfy that constraint and was not added.

## Nixbot proposal

The unapplied repository diff is:

```diff
-effects_branches = ["*"]
-effects_on_pull_requests = true
+effects_branches = ["main"]
+effects_on_pull_requests = false
```

The source review used `Mic92/nixbot` at `7235d8d43408c5f9cf9a43e1693256f067e3c188`, fetched read-only on 2026-09-02.
The shallow clone's `git log --follow -1` records that boundary commit at `2026-09-01 22:12:57 +0200` for the files cited below.

`nixbot/nixbot/repo_config.py:32-41` leaves `build_branches` unset unless the repository supplies it.
`nixbot/nixbot/service.py:302-326` sends non-PR, non-default, non-merge-queue pushes through either the repository's `build_branches` or the service-wide branch rules.
`nixbot/nixbot/webhooks.py:45-58` admits only the default branch, explicit branch rules, and the four merge-queue patterns.
The deployed `services.nixbot.branches` evaluates to `{}`, using:

```sh
nix eval --json .#nixosConfigurations.magnetite.config.services.nixbot.branches \
  --option builders '' \
  --option allow-import-from-derivation false
```

Therefore pushes to `wip/*` and `stack/*` match neither the empty explicit rule set nor a merge-queue pattern and do not build.
Pull requests still build because `service.py:308-326` applies that branch filter only when `pr_number` is absent.

`nixbot/nixbot/effects.py:75-93` checks PR events first, so `effects_on_pull_requests = false` prevents PR effects even when the PR targets `main`.
The same function always admits a non-PR default-branch event before consulting `effects_branches`, while `effects_branches = ["main"]` admits no additional effect branch.
`nixbot/nixbot/effects_run.py:64-121` reads this gate from the default branch configuration before discovering and enqueueing effects.

Nixbot creates a PR worktree at the current base and merges the head in `nixbot/nixbot/orchestrator.py:234-286` and `nixbot/nixbot/gitrepo.py:455-476`.
It identifies the result by `HEAD^{tree}` in `gitrepo.py:205-207`.
When the base is an ancestor of the head, a local `git merge --no-ff` probe produced the same tree for the PR merge and the head commit: `188fd7d3a743ca5b739852c31e0a74ce6da46343`.
A fast-forward push of that head produces the same tree, so `orchestrator.py:268-286` selects the existing tree-keyed build rather than creating a second build.
`nixbot/nixbot/build_reuse.py:124-177` then runs `maybe_run_effects` when the reused PR build has not started effects, which makes a reused `main` build deploy instead of merely replaying build checks.

## Main ruleset proposal

The live `nixbot` ruleset was read with `gh-axi api repos/cameronraysmith/vanixiets/rulesets/16212553` on 2026-09-02.
It currently contains deletion protection, non-fast-forward protection, and only `nixbot/nix-build` as a required check.
Its `strict_required_status_checks_policy` is already `false`.
Its only bypass actor is repository role `5` in `always` mode, and the API reports `current_user_can_bypass: always` for the authenticated landing identity `cameronraysmith`.

Apply this semantic diff to that ruleset, preserving its name, active enforcement, default-branch condition, deletion rule, non-fast-forward rule, and existing bypass actor:

```diff
 rules:
   - type: deletion
   - type: non_fast_forward
+  - type: required_linear_history
+  - type: pull_request
+    parameters:
+      allowed_merge_methods:
+        - squash
+        - rebase
+      dismiss_stale_reviews_on_push: false
+      require_code_owner_review: false
+      require_last_push_approval: false
+      required_approving_review_count: 0
+      required_review_thread_resolution: false
   - type: required_status_checks
     parameters:
       strict_required_status_checks_policy: false
       do_not_enforce_on_create: false
       required_status_checks:
+        - context: nixbot/nix-eval
+          integration_id: 4743700
         - context: nixbot/nix-build
           integration_id: 4743700
```

The unchanged `strict_required_status_checks_policy: false` keeps “require branches to be up to date” off.
The unchanged repository-role bypass lets the current administrator landing identity perform the one direct push despite the new pull-request rule.
The diff adds no `merge_queue` rule, so GitHub's native merge queue remains disabled.
The existing `.github/mergify.yml` describes Mergify queues for other PR traffic; the landing script does not call that service or its queue.

Classic branch protection currently reports `required_linear_history.enabled: true`, while the named ruleset does not contain that rule.
Adding it to the ruleset makes the requested ruleset self-describing without relying on the parallel classic layer.
Classic protection also reports `allow_force_pushes.enabled: true`, but the active ruleset's `non_fast_forward` rule is the newer, ruleset-level prohibition relevant to this proposal.

## Repository setting

`gh-axi api repos/cameronraysmith/vanixiets` returned `delete_branch_on_merge: true` on 2026-09-02.
“Automatically delete head branches” is already on, so the unapplied diff is empty.
No repository-setting request is needed.

## Mergify CLI settings

All three repository-local keys are currently unset.
The source review used `Mergifyio/mergify-cli` at `727ce50b8fb3be8a9a24025807e159d644dbba80`, whose shallow history boundary is dated `2026-08-27 12:50:49 +0200`.

The original planning brief's line 32 says the CLI opens drafts by default.
That conflicts with the executable source at `stack_context.rs:237-248`, which defaults the setting to `false`.
The planning brief is not in a git repository, so its embedded “checked on 2026-09-02” statement has no git provenance to compare with the source commit.
This review follows the executable source and leaves the policy choice explicit; a newer upstream commit changing `resolve_default_create_as_draft` would change that conclusion.

`crates/mergify-stack/src/stack_context.rs:207-235` maps an unset `mergify-cli.stack-branch-prefix` to `stack/<author>`.
Leave that key unset; its unapplied diff is empty.

`stack_context.rs:237-248` maps an unset `mergify-cli.stack-create-as-draft` to `false` and recognizes only the literal value `true` as enabled.
`crates/mergify-stack/src/changes.rs:187-196` shows that the setting marks newly created PRs as drafts while preserving the draft state of existing PRs.
The mechanism does not determine review-readiness policy, so the owner must choose between these unapplied alternatives:

```diff
 # Keep the upstream behavior: new stack PRs are ready immediately.
 mergify-cli.stack-create-as-draft = <unset>
```

```diff
 # Opt in: new stack PRs are drafts.
-mergify-cli.stack-create-as-draft = <unset>
+mergify-cli.stack-create-as-draft = true
```

`stack_context.rs:261-270` maps an unset `mergify-cli.stack-revision-history` to `true`; only the literal value `false` disables it.
`crates/mergify-stack/src/commands/push.rs:359-550` records updated revisions in git notes and prepares the sticky PR revision-history comment before publishing.
Leave the key unset to keep revision history on; its unapplied diff is empty.

## Verification boundary

Structural verification consists of `bash scripts/test-stack-land.sh`, `shellcheck scripts/stack-land.sh scripts/test-stack-land.sh`, the targeted Nix evaluation above, and `prek run --all-files` before publication.
Runtime verification against held pull requests 2890, 2915, and 2916 remains absent because this lane has no authorization to push their tip to GitHub `main`.
