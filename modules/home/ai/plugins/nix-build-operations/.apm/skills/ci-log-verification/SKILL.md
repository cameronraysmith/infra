---
name: ci-log-verification
description: Verify CI results by downloading and analyzing complete workflow logs across both CI backends (GitHub Actions and buildbot-nix), rather than piecing together fragments via repeated API calls. Use when validating a branch or PR for merge, when a check fails and log evidence is needed, or when triaging which backend a failing check lives on from gh pr checks output.
---

# CI log verification

When validating changes for merge, verify CI results by downloading and analyzing complete workflow logs rather than piecing together fragments via repeated API calls.

## Wait and download

Wait for relevant workflows to complete:

```bash
gh run watch <run_id>
# or poll with: gh run list --branch <branch> --status completed
```

Download the complete logs archive:

```bash
run_id=<run_id>
mkdir -p logs
gh api "repos/<owner>/<repo>/actions/runs/${run_id}/logs" > "logs/gha-${run_id}.zip"
unzip -d "logs/gha-${run_id}" "logs/gha-${run_id}.zip"
```

Survey available jobs and steps:

```bash
tree --du -ah "logs/gha-${run_id}"
```

## Unified PR check log retrieval

Given only a pull request number, the unified entry point for discovering which checks ran and where their logs live is `PAGER=cat gh pr checks <N>`.
This command emits one row per check with a direct link, spanning both CI backends used by repositories in this workspace.
GitHub Actions rows link to `https://github.com/<owner>/<repo>/actions/runs/<run_id>/job/<job_id>`.
Buildbot-nix rows link to `https://buildbot.scientistexperience.net/#/builders/<builder_id>/builds/<build_number>` and correspond to the `buildbot/nix-eval` and `buildbot/nix-build` status checks described in `preferences-nix-ci-cd-integration`.

Use the JSON output to separate the two categories and drive automation:

```bash
gh pr checks <N> --json name,link \
  | jq -r '.[] | select(.name | test("^buildbot/")) | .link'
gh pr checks <N> --json name,link \
  | jq -r '.[] | select(.link | test("/actions/runs/")) | .link'
```

Route each link to its backend-specific log-download recipe, writing artifacts under a single `logs/` directory (already gitignored):

```bash
mkdir -p logs

# GitHub Actions — extract <run_id> from the /runs/<run_id>/job/... URL path
run_id=<run_id>
gh api "repos/<owner>/<repo>/actions/runs/${run_id}/logs" > "logs/gha-${run_id}.zip"
unzip -d "logs/gha-${run_id}" "logs/gha-${run_id}.zip"

# Buildbot-nix — extract <builder_id> and <build_number> from the fragment
# /#/builders/<builder_id>/builds/<build_number>
builder_id=<builder_id>
build_number=<build_number>
buildbot-logs "${builder_id}" "${build_number}" > "logs/buildbot-${builder_id}-${build_number}.log"
```

The `buildbot-logs` shell application is defined in the vanixiets repository; see `preferences-nix-ci-cd-integration` for its interface, ssh transport, and authentication model.

## Analyze

After download, survey each artifact before dispatching subagents for targeted analysis:

```bash
tree --du -ah "logs/gha-${run_id}"
rg "error:" "logs/buildbot-${builder_id}-${build_number}.log"
```

Dispatch subagent Tasks to analyze specific log files for the problem at hand rather than manually reading large logs inline.
This approach provides a complete, well-organized view of CI results and avoids the antipattern of fragmented API-based log retrieval that never yields a clear picture of what happened.
