#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$SKILL_DIR/scripts/search_sessions.sh"
FIXTURES="$SKILL_DIR/tests/fixtures"
TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT

mkdir -p \
  "$TEST_HOME/.claude/projects/-work-alpha" \
  "$TEST_HOME/.codex/sessions/2026/01/02" \
  "$TEST_HOME/.pi/agent/sessions/--work-gamma--" \
  "$TEST_HOME/.pi/agent/sessions/--work-malformed--" \
  "$TEST_HOME/.pi/agent/sessions/--work-unknown--" \
  "$TEST_HOME/.pi/agent/sessions/--work-raw-count--"
cp "$FIXTURES/claude.jsonl" "$TEST_HOME/.claude/projects/-work-alpha/claude-session.jsonl"
cp "$FIXTURES/codex.jsonl" "$TEST_HOME/.codex/sessions/2026/01/02/codex-session.jsonl"
cp "$FIXTURES/pi.jsonl" "$TEST_HOME/.pi/agent/sessions/--work-gamma--/pi-session.jsonl"
cp "$FIXTURES/malformed.jsonl" "$TEST_HOME/.pi/agent/sessions/--work-malformed--/malformed.jsonl"
cp "$FIXTURES/unknown.jsonl" "$TEST_HOME/.pi/agent/sessions/--work-unknown--/unknown.jsonl"
cp "$FIXTURES/raw-count.jsonl" "$TEST_HOME/.pi/agent/sessions/--work-raw-count--/raw-count.jsonl"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack=$1
  local needle=$2
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack=$1
  local needle=$2
  [[ "$haystack" != *"$needle"* ]] || fail "expected output not to contain: $needle"
}

result_row() {
  local output=$1
  local filename=$2
  printf '%s\n' "$output" | awk -F '\t' -v filename="$filename" '$2 ~ filename {print; exit}'
}

result_field() {
  local row=$1
  local field=$2
  printf '%s\n' "$row" | awk -F '\t' -v field="$field" '{print $field}'
}

output=$(HOME="$TEST_HOME" "$SCRIPT" -i orchid lattice 2>"$TEST_HOME/default.err")
assert_contains "$output" "claude-session.jsonl"
assert_contains "$output" "codex-session.jsonl"
assert_contains "$output" "pi-session.jsonl"
assert_contains "$output" "malformed.jsonl"
assert_contains "$(<"$TEST_HOME/default.err")" "raw fallback"
[[ $(result_field "$(result_row "$output" "claude-session.jsonl")" 9) == "structured" ]] || fail "routine Claude records forced raw fallback"
[[ $(result_field "$(result_row "$output" "codex-session.jsonl")" 9) == "structured" ]] || fail "routine Codex records forced raw fallback"

output=$(HOME="$TEST_HOME" "$SCRIPT" --harness codex -i orchid lattice 2>"$TEST_HOME/codex-structured.err")
assert_contains "$output" "codex-session.jsonl"
[[ ! -s "$TEST_HOME/codex-structured.err" ]] || fail "irrelevant unknown Codex metadata emitted a fallback warning"
assert_not_contains "$output" "claude-session.jsonl"
assert_not_contains "$output" "pi-session.jsonl"
codex_row=$(result_row "$output" "codex-session.jsonl")
[[ $(result_field "$codex_row" 3) == "codex-session-1" ]] || fail "Codex item ID replaced session ID"

output=$(HOME="$TEST_HOME" "$SCRIPT" --harness claude -i orchid lattice 2>"$TEST_HOME/claude-structured.err")
assert_contains "$output" "claude-session.jsonl"
[[ $(result_field "$(result_row "$output" "claude-session.jsonl")" 9) == "structured" ]] || fail "known Claude content did not remain structured"
[[ ! -s "$TEST_HOME/claude-structured.err" ]] || fail "irrelevant unknown Claude metadata emitted a fallback warning"

output=$(HOME="$TEST_HOME" "$SCRIPT" --harness claude --harness pi -i orchid lattice 2>/dev/null)
assert_contains "$output" "claude-session.jsonl"
assert_contains "$output" "pi-session.jsonl"
assert_not_contains "$output" "codex-session.jsonl"

output=$(HOME="$TEST_HOME" "$SCRIPT" --harness pi --path "$TEST_HOME/.pi/agent/sessions/--work-gamma--/pi-session.jsonl" -i orchid lattice)
assert_contains "$output" "pi-session.jsonl"
assert_not_contains "$output" "malformed.jsonl"

output=$(HOME="$TEST_HOME" "$SCRIPT" -i hidden-nebula 2>"$TEST_HOME/hidden.err")
assert_not_contains "$output" "claude-session.jsonl"
assert_not_contains "$output" "codex-session.jsonl"
assert_not_contains "$output" "pi-session.jsonl"
[[ ! -s "$TEST_HOME/hidden.err" ]] || fail "irrelevant unknown metadata warned during hidden-reasoning exclusion"
output=$(HOME="$TEST_HOME" "$SCRIPT" --harness claude --raw -i hidden-nebula)
assert_contains "$output" "claude-session.jsonl"

output=$(HOME="$TEST_HOME" "$SCRIPT" --harness pi -i schema-orbit signal 2>"$TEST_HOME/unknown.err")
unknown_row=$(result_row "$output" "unknown.jsonl")
[[ -n "$unknown_row" ]] || fail "valid unknown discriminator did not use raw fallback"
[[ $(result_field "$unknown_row" 9) == "raw-fallback" ]] || fail "unknown schema mode was not raw-fallback"
assert_contains "$(<"$TEST_HOME/unknown.err")" "raw fallback"

output=$(HOME="$TEST_HOME" "$SCRIPT" --harness claude -i unknown-only-term unknown-only-signal 2>"$TEST_HOME/unknown-record.err")
unknown_record_row=$(result_row "$output" "claude-session.jsonl")
[[ $(result_field "$unknown_record_row" 7) -eq 1 ]] || fail "unknown record fallback included hidden or unrelated records"
[[ $(result_field "$unknown_record_row" 8) -eq 2 ]] || fail "unknown record fallback score included hidden or unrelated occurrences"
[[ $(result_field "$unknown_record_row" 9) == "raw-fallback" ]] || fail "unknown-record-only result mode was not raw-fallback"
assert_contains "$(<"$TEST_HOME/unknown-record.err")" "unknown record raw fallback"

output=$(HOME="$TEST_HOME" "$SCRIPT" --harness claude -i claude-visible-rank)
claude_row=$(result_row "$output" "claude-session.jsonl")
[[ $(result_field "$claude_row" 8) -eq 4 ]] || fail "mixed Claude visible text lost assistant weight"
output=$(HOME="$TEST_HOME" "$SCRIPT" --harness pi -i pi-visible-rank)
pi_row=$(result_row "$output" "pi-session.jsonl")
[[ $(result_field "$pi_row" 8) -eq 4 ]] || fail "mixed Pi visible text lost assistant weight"

output=$(HOME="$TEST_HOME" "$SCRIPT" --harness pi --raw repeat-token)
raw_count_row=$(result_row "$output" "raw-count.jsonl")
[[ $(result_field "$raw_count_row" 7) -eq 1 ]] || fail "raw MATCH_RECORDS did not count distinct lines"
[[ $(result_field "$raw_count_row" 8) -eq 2 ]] || fail "raw SCORE did not count occurrences"

output=$(HOME="$TEST_HOME" "$SCRIPT" -i -n 2 orchid lattice 2>/dev/null)
result_count=$(printf '%s\n' "$output" | tail -n +2 | wc -l | tr -d ' ')
[[ "$result_count" -eq 2 ]] || fail "expected 2 bounded results, got $result_count"

output=$(HOME="$TEST_HOME" "$SCRIPT" --project /work/beta -i orchid lattice 2>/dev/null)
assert_contains "$output" "codex-session.jsonl"
assert_not_contains "$output" "claude-session.jsonl"
assert_not_contains "$output" "pi-session.jsonl"

output=$(HOME="$TEST_HOME" "$SCRIPT" --raw --project /work/beta -i orchid lattice)
assert_contains "$output" "codex-session.jsonl"
assert_not_contains "$output" "claude-session.jsonl"
assert_not_contains "$output" "pi-session.jsonl"
[[ $(result_field "$(result_row "$output" "codex-session.jsonl")" 9) == "raw" ]] || fail "explicit raw mode label changed"

fallback_path=""
while IFS= read -r path_dir; do
  if [[ ! -x "$path_dir/jaq" && ! -x "$path_dir/duckdb" ]]; then
    fallback_path="${fallback_path:+$fallback_path:}$path_dir"
  fi
done < <(printf '%s\n' "$PATH" | tr ':' '\n')
PATH="$fallback_path" command -v rg >/dev/null || fail "dependency fallback PATH lost rg"
if PATH="$fallback_path" command -v jaq >/dev/null || PATH="$fallback_path" command -v duckdb >/dev/null; then
  fail "dependency fallback PATH still contains structured dependencies"
fi
output=$(HOME="$TEST_HOME" PATH="$fallback_path" "$SCRIPT" --harness codex --project /work/beta -i orchid lattice 2>"$TEST_HOME/dependency.err")
[[ $(result_field "$(result_row "$output" "codex-session.jsonl")" 9) == "raw-fallback" ]] || fail "dependency fallback mode was not labeled raw-fallback"
assert_contains "$(<"$TEST_HOME/dependency.err")" "using raw fallback"

bulk_dir="$TEST_HOME/.pi/agent/sessions/--work-bulk--"
mkdir -p "$bulk_dir"
for index in $(seq 1 1000); do
  printf '{"type":"message","content":"bulk-token"}\n' > "$bulk_dir/bulk-$index.jsonl"
done
output=$(HOME="$TEST_HOME" "$SCRIPT" --harness pi --raw -n 3 bulk-token)
result_count=$(printf '%s\n' "$output" | tail -n +2 | wc -l | tr -d ' ')
[[ "$result_count" -eq 3 ]] || fail "bounded raw search returned $result_count rows instead of 3"

help=$($SCRIPT --help)
assert_contains "$help" "--harness"
assert_contains "$help" "--path"
assert_contains "$help" "--raw"

printf 'PASS: cross-harness structured and raw session search\n'
