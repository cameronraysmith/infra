#!/usr/bin/env bash
set -euo pipefail

subject="$(command -v stack-land)"
scratch_parent="${TMPDIR:?}/stack-land-test"
mkdir -p "$scratch_parent"
scratch="$(mktemp -d "$scratch_parent/run.XXXXXX")"
trap 'chmod -R u+w "$scratch" 2>/dev/null || true; command rm -rf "$scratch"' EXIT

remote="$scratch/remote.git"
work="$scratch/work"
forge="$scratch/forge"
fake_bin="$scratch/bin"
mkdir -p "$forge/checks" "$fake_bin"

git init --quiet --bare --initial-branch=main "$remote"
git init --quiet --initial-branch=main "$work"
git -C "$work" config user.name "Stack Landing Test"
git -C "$work" config user.email "stack-landing@example.invalid"
git -C "$work" remote add origin "$remote"

commit_file() {
  local filename="$1"
  local content="$2"
  local subject_line="$3"
  local change_id="${4:-}"
  printf '%s\n' "$content" >"$work/$filename"
  git -C "$work" add "$filename"
  if [[ -n "$change_id" ]]; then
    git -C "$work" commit --quiet -m "$subject_line" -m "Change-Id: $change_id"
  else
    git -C "$work" commit --quiet -m "$subject_line"
  fi
}

commit_file base.txt base base
base_sha="$(git -C "$work" rev-parse HEAD)"
git -C "$work" push --quiet origin HEAD:main

git -C "$work" switch --quiet -c stack
commit_file lower.txt lower lower I1111111111111111111111111111111111111111
commit_file upper.txt upper upper I2222222222222222222222222222222222222222
tip_sha="$(git -C "$work" rev-parse HEAD)"

git -C "$work" switch --quiet -c missing-trailer "$base_sha"
commit_file missing.txt missing missing
missing_sha="$(git -C "$work" rev-parse HEAD)"

git -C "$work" switch --quiet -c duplicate-trailer "$base_sha"
printf '%s\n' duplicate >"$work/duplicate.txt"
git -C "$work" add duplicate.txt
git -C "$work" commit --quiet \
  -m duplicate \
  -m $'Change-Id: I3333333333333333333333333333333333333333\nChange-Id: I4444444444444444444444444444444444444444'
duplicate_sha="$(git -C "$work" rev-parse HEAD)"

git -C "$work" switch --quiet -c malformed-trailer "$base_sha"
commit_file malformed.txt malformed malformed Inot-a-forty-digit-hex-value
malformed_sha="$(git -C "$work" rev-parse HEAD)"

git -C "$work" switch --quiet -c competing "$base_sha"
commit_file competing.txt competing competing I5555555555555555555555555555555555555555
competing_sha="$(git -C "$work" rev-parse HEAD)"
git -C "$work" push --quiet origin competing:refs/heads/test-competing
git -C "$work" switch --quiet stack

{
  printf '#!%s\n' "$BASH"
  cat <<'EOF'
set -euo pipefail

if [[ "$1 $2" == "pr checks" ]]; then
  pr="$3"
  [[ "$4 $5" == "--json name,state" ]]
  cat "$FAKE_FORGE/checks/$pr.json"
  if [[ "${FAKE_ADVANCE_ON_PR:-}" == "$pr" ]]; then
    git --git-dir="$FAKE_REMOTE" update-ref refs/heads/main "$FAKE_ADVANCE_SHA"
  fi
  jq -e 'length > 0 and all(.[]; .state == "SUCCESS")' \
    "$FAKE_FORGE/checks/$pr.json" >/dev/null
  exit
fi

if [[ "$1 $2" == "pr view" ]]; then
  pr="$3"
  [[ "$4 $5" == "--json state,mergedAt" ]]
  if [[ "${FAKE_BLOCKED_PR:-}" == "$pr" ]]; then
    printf '{"state":"OPEN","mergedAt":null}\n'
  elif git --git-dir="$FAKE_REMOTE" merge-base --is-ancestor \
    "$FAKE_TIP_SHA" refs/heads/main; then
    printf '{"state":"MERGED","mergedAt":"2026-09-02T12:00:00Z"}\n'
  else
    printf '{"state":"OPEN","mergedAt":null}\n'
  fi
  exit
fi

printf 'unexpected forge invocation: %q ' "$@" >&2
printf '\n' >&2
exit 64
EOF
} >"$fake_bin/gh"
chmod +x "$fake_bin/gh"

mkdir -p "$work/.git/hooks"
{
  printf '#!%s\n' "$BASH"
  cat <<'EOF'
set -euo pipefail
if [[ -f "$FAKE_FORGE/advance-in-pre-push" ]]; then
  advance_sha="$(<"$FAKE_FORGE/advance-in-pre-push")"
  git --git-dir="$FAKE_REMOTE" update-ref refs/heads/main "$advance_sha"
  command rm "$FAKE_FORGE/advance-in-pre-push"
fi
EOF
} >"$work/.git/hooks/pre-push"
chmod +x "$work/.git/hooks/pre-push"

printf '[{"name":"nixbot/nix-eval","state":"SUCCESS"},{"name":"nixbot/nix-build","state":"SUCCESS"}]\n' >"$forge/checks/101.json"
printf '[{"name":"nixbot/nix-eval","state":"SUCCESS"},{"name":"nixbot/nix-build","state":"CANCELLED"}]\n' >"$forge/checks/102.json"
printf '[]\n' >"$forge/checks/103.json"
printf '[{"name":"nixbot/nix-eval","state":"SUCCESS"},{"name":"nixbot/nix-build","state":"SUCCESS"}]\n' >"$forge/checks/104.json"

output="$scratch/output"
export FAKE_FORGE="$forge"
export FAKE_REMOTE="$remote"
export FAKE_TIP_SHA="$tip_sha"
export GH_BIN="$fake_bin/gh"

reset_main() {
  git --git-dir="$remote" update-ref refs/heads/main "$base_sha"
}

run_subject() {
  (cd "$work" && "$subject" "$@") >"$output" 2>&1
}

expect_failure() {
  local name="$1"
  local pattern="$2"
  shift 2
  if run_subject "$@"; then
    printf 'not ok - %s: command succeeded\n' "$name" >&2
    return 1
  fi
  if ! grep -Eq "$pattern" "$output"; then
    printf 'not ok - %s: expected /%s/ in:\n' "$name" "$pattern" >&2
    sed 's/^/  /' "$output" >&2
    return 1
  fi
  printf 'ok - %s: %s\n' "$name" "$(tail -n 1 "$output")"
}

expect_success() {
  local name="$1"
  shift
  if ! run_subject "$@"; then
    printf 'not ok - %s: command failed:\n' "$name" >&2
    sed 's/^/  /' "$output" >&2
    return 1
  fi
  printf 'ok - %s\n' "$name"
}

expect_check_state_failure() {
  local category="$1"
  local pr="$2"
  local state="$3"
  local check="synthetic-$state"

  printf '[{"name":"nixbot/nix-eval","state":"SUCCESS"},{"name":"%s","state":"%s"}]\n' \
    "$check" "$state" >"$forge/checks/$pr.json"
  reset_main
  expect_failure \
    "$category check state $state blocks landing" \
    "PR $pr checks are not all green: $check=$state" \
    --dry-run --tip "$tip_sha" "$pr"
}

git --git-dir="$remote" update-ref refs/heads/main "$competing_sha"
expect_failure \
  'ancestry rejects a divergent target base' \
  "target base .* is not an ancestor of stack tip $tip_sha" \
  --dry-run --tip "$tip_sha" 101

reset_main
expect_failure \
  'missing Change-Id names its commit' \
  "commit $missing_sha has 0 Change-Id trailers; expected exactly one" \
  --dry-run --tip "$missing_sha" 101

reset_main
expect_failure \
  'duplicate Change-Id names its commit' \
  "commit $duplicate_sha has 2 Change-Id trailers; expected exactly one" \
  --dry-run --tip "$duplicate_sha" 101

reset_main
expect_failure \
  'malformed Change-Id names its commit' \
  "commit $malformed_sha has invalid Change-Id trailer" \
  --dry-run --tip "$malformed_sha" 101

reset_main
expect_failure \
  'cancelled check is not green' \
  'PR 102 checks are not all green: nixbot/nix-build=CANCELLED' \
  --dry-run --tip "$tip_sha" 102

reset_main
expect_failure \
  'a head with no checks is not green' \
  'PR 103 has no checks' \
  --dry-run --tip "$tip_sha" 103

printf '[{"name":"nixbot/nix-eval","state":"SUCCESS"},{"name":"Mergify Merge Queue","state":"NEUTRAL"}]\n' \
  >"$forge/checks/105.json"
reset_main
expect_success \
  'a neutral check does not block landing' \
  --dry-run --tip "$tip_sha" 105

printf '[{"name":"nixbot/nix-eval","state":"SUCCESS"},{"name":"optional-check","state":"SKIPPED"}]\n' \
  >"$forge/checks/106.json"
reset_main
expect_success \
  'a skipped check does not block landing' \
  --dry-run --tip "$tip_sha" 106

pr=107
for state in FAILURE TIMED_OUT ACTION_REQUIRED ERROR; do
  expect_check_state_failure failing "$pr" "$state"
  ((pr += 1))
done

for state in PENDING IN_PROGRESS QUEUED REQUESTED WAITING EXPECTED STARTUP_FAILURE STALE; do
  expect_check_state_failure undecided "$pr" "$state"
  ((pr += 1))
done

expect_check_state_failure unrecognised "$pr" BANANA

reset_main
export FAKE_ADVANCE_ON_PR=101
export FAKE_ADVANCE_SHA="$competing_sha"
expect_failure \
  'ancestry is rechecked after forge checks' \
  "target base $competing_sha is not an ancestor of stack tip $tip_sha" \
  --dry-run --tip "$tip_sha" 101
unset FAKE_ADVANCE_ON_PR FAKE_ADVANCE_SHA

reset_main
printf '%s\n' "$competing_sha" >"$forge/advance-in-pre-push"
expect_failure \
  'the fast-forward push rejects a concurrent target update' \
  '(non-fast-forward|failed to push some refs)' \
  --tip "$tip_sha" 101

reset_main
PATH=/unusable GH_BIN="$fake_bin/gh" run_subject --dry-run --tip "$tip_sha" 101
[[ "$(git --git-dir="$remote" rev-parse refs/heads/main)" == "$base_sha" ]]
grep -Fq "dry run: would push $tip_sha to origin/main" "$output"
printf 'ok - installed wrapper supplies its runtime commands with an unusable PATH\n'

reset_main
run_subject --dry-run --tip "$tip_sha" 101
[[ "$(git --git-dir="$remote" rev-parse refs/heads/main)" == "$base_sha" ]]
grep -Fq "dry run: would push $tip_sha to origin/main" "$output"
printf 'ok - dry run validates without updating main\n'

reset_main
run_subject --tip "$tip_sha" 101
[[ "$(git --git-dir="$remote" rev-parse refs/heads/main)" == "$tip_sha" ]]
grep -Fq 'landed stack and verified merged PRs: 101' "$output"
printf 'ok - valid stack fast-forwards main and verifies merged state\n'

git -C "$work" switch --quiet stack
commit_file next.txt next next I6666666666666666666666666666666666666666
next_tip_sha="$(git -C "$work" rev-parse HEAD)"
export FAKE_TIP_SHA="$next_tip_sha"
export FAKE_BLOCKED_PR=104
expect_failure \
  'post-push state requires every PR to be merged' \
  'PR 104 did not close as merged after push' \
  --tip "$next_tip_sha" 101 104
unset FAKE_BLOCKED_PR
