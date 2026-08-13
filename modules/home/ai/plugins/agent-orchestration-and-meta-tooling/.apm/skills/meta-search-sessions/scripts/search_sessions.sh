#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

HARNESS_FILTERS=()
SEARCH_PATHS=()
PROJECT_FILTERS=()
CASE_INSENSITIVE=0
RAW_MODE=0
TOP_N=10

usage() {
  cat <<'EOF'
Usage: search_sessions.sh [OPTIONS] term [term ...]

Search session JSONL files containing every term and print the top-ranked files.
Structured search is the default and excludes hidden reasoning.

Options:
  --harness NAME     Search one harness; repeat for any subset of claude, codex, pi.
                     The default is all three harnesses.
  -p, --path PATH    Search a file or directory; repeat as needed. Absolute paths and
                     paths relative to a selected harness store are accepted.
  --project TEXT     Keep files whose source path, project, or cwd contains TEXT.
                     Repeat to accept any of several project scopes.
  -i                 Match without regard to case.
  -n, --top N        Return at most N files (default: 10).
  --raw              Use rg-only maximum-recall search, including unnormalized fields.
  -h, --help         Show this help.

Stores:
  claude  ~/.claude/projects
  codex   ~/.codex/sessions
  pi      ~/.pi/agent/sessions
EOF
}

need_value() {
  [[ $# -ge 2 ]] || {
    printf 'Missing value for %s\n' "$1" >&2
    exit 2
  }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --harness)
      need_value "$@"
      HARNESS_FILTERS+=("$2")
      shift 2
      ;;
    -p|--path)
      need_value "$@"
      SEARCH_PATHS+=("$2")
      shift 2
      ;;
    --project)
      need_value "$@"
      PROJECT_FILTERS+=("$2")
      shift 2
      ;;
    -i)
      CASE_INSENSITIVE=1
      shift
      ;;
    -n|--top)
      need_value "$@"
      TOP_N=$2
      shift 2
      ;;
    --raw)
      RAW_MODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

TERMS=("$@")
[[ ${#TERMS[@]} -gt 0 ]] || {
  usage >&2
  exit 2
}
[[ "$TOP_N" =~ ^[1-9][0-9]*$ ]] || {
  printf 'Top N must be a positive integer: %s\n' "$TOP_N" >&2
  exit 2
}
command -v rg >/dev/null 2>&1 || {
  printf 'rg is required.\n' >&2
  exit 127
}

if [[ ${#HARNESS_FILTERS[@]} -eq 0 ]]; then
  HARNESS_FILTERS=(claude codex pi)
fi

SELECTED_HARNESSES=()
for harness in "${HARNESS_FILTERS[@]}"; do
  case "$harness" in
    claude|codex|pi) ;;
    *)
      printf 'Unknown harness: %s (expected claude, codex, or pi)\n' "$harness" >&2
      exit 2
      ;;
  esac
  if [[ " ${SELECTED_HARNESSES[*]} " != *" $harness "* ]]; then
    SELECTED_HARNESSES+=("$harness")
  fi
done

store_for() {
  case "$1" in
    claude) printf '%s/.claude/projects\n' "$HOME" ;;
    codex) printf '%s/.codex/sessions\n' "$HOME" ;;
    pi) printf '%s/.pi/agent/sessions\n' "$HOME" ;;
  esac
}

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/search-sessions.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT
RG_CASE=()
[[ $CASE_INSENSITIVE -eq 0 ]] || RG_CASE=(-i)
SOURCE_MAP="$TMP_ROOT/sources.tsv"
: > "$SOURCE_MAP"

paths_for_harness() {
  local harness=$1
  local store=$2
  local requested resolved found=0

  if [[ ${#SEARCH_PATHS[@]} -eq 0 ]]; then
    [[ -d "$store" ]] && printf '%s\n' "$store"
    return
  fi

  for requested in "${SEARCH_PATHS[@]}"; do
    if [[ "$requested" == /* ]]; then
      if [[ "$requested" != "$store"/* && ${#SELECTED_HARNESSES[@]} -ne 1 ]]; then
        continue
      fi
      resolved=$requested
    else
      resolved="$store/$requested"
    fi
    if [[ -e "$resolved" ]]; then
      printf '%s\n' "$resolved"
      found=1
    fi
  done
  if [[ $found -eq 0 && ${#SELECTED_HARNESSES[@]} -eq 1 ]]; then
    printf 'No search path exists for %s.\n' "$harness" >&2
    exit 2
  fi
}

intersect_harness() {
  local harness=$1
  shift
  local paths=("$@")
  local current="$TMP_ROOT/current.$harness"
  local matches="$TMP_ROOT/matches.$harness"
  local next="$TMP_ROOT/next.$harness"
  local term first=1

  [[ ${#paths[@]} -gt 0 ]] || return
  for term in "${TERMS[@]}"; do
    rg -l -F "${RG_CASE[@]}" -g '*.jsonl' -- "$term" "${paths[@]}" 2>/dev/null \
      | sort -u > "$matches" || true
    if [[ $first -eq 1 ]]; then
      cp "$matches" "$current"
      first=0
    else
      comm -12 "$current" "$matches" > "$next"
      mv "$next" "$current"
    fi
    [[ -s "$current" ]] || return
  done
  while IFS= read -r source; do
    printf '%s\t%s\n' "$harness" "$source" >> "$SOURCE_MAP"
  done < "$current"
}

for harness in "${SELECTED_HARNESSES[@]}"; do
  store=$(store_for "$harness")
  harness_paths=()
  while IFS= read -r path; do
    harness_paths+=("$path")
  done < <(paths_for_harness "$harness" "$store")
  intersect_harness "$harness" "${harness_paths[@]}"
done
sort -u "$SOURCE_MAP" -o "$SOURCE_MAP"

print_header() {
  printf 'HARNESS\tSOURCE_PATH\tSESSION_ID\tSESSION_NAME\tPROJECT_OR_CWD\tTIMESTAMP\tMATCH_RECORDS\tSCORE\tMODE\n'
}

raw_project_matches() {
  local source=$1
  local project path_value project_value
  [[ ${#PROJECT_FILTERS[@]} -gt 0 ]] || return 0
  for project in "${PROJECT_FILTERS[@]}"; do
    path_value=$source
    project_value=$project
    if [[ $CASE_INSENSITIVE -eq 1 ]]; then
      path_value=${path_value,,}
      project_value=${project_value,,}
    fi
    if [[ "$path_value" == *"$project_value"* ]] \
        || rg -q -F "${RG_CASE[@]}" -- "$project" "$source" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

raw_results() {
  local mode=$1
  local ranked="$TMP_ROOT/raw-ranked.tsv"
  local sorted="$TMP_ROOT/raw-sorted.tsv"
  local matched_lines="$TMP_ROOT/raw-matched-lines"
  local harness source term count score match_records emitted=0
  : > "$ranked"
  while IFS=$'\t' read -r harness source; do
    [[ -n "$source" ]] || continue
    raw_project_matches "$source" || continue
    score=0
    : > "$matched_lines"
    for term in "${TERMS[@]}"; do
      count=$(rg -o -F "${RG_CASE[@]}" -- "$term" "$source" 2>/dev/null | wc -l | tr -d ' ')
      score=$((score + count))
      rg -n -F "${RG_CASE[@]}" -- "$term" "$source" 2>/dev/null \
        | cut -d: -f1 >> "$matched_lines" || true
    done
    match_records=$(sort -nu "$matched_lines" | wc -l | tr -d ' ')
    printf '%s\t%s\t%s\t%s\n' "$score" "$match_records" "$harness" "$source" >> "$ranked"
  done < "$SOURCE_MAP"

  sort -t $'\t' -k1,1nr -k4,4 "$ranked" > "$sorted"
  print_header
  while IFS=$'\t' read -r score match_records harness source; do
    [[ $emitted -lt $TOP_N ]] || break
    printf '%s\t%s\t\t\t\t\t%s\t%s\t%s\n' \
      "$harness" "$source" "$match_records" "$score" "$mode"
    emitted=$((emitted + 1))
  done < "$sorted"
}

if [[ ! -s "$SOURCE_MAP" ]]; then
  print_header
  exit 0
fi

if [[ $RAW_MODE -eq 1 ]]; then
  raw_results raw
  exit 0
fi
if ! command -v jaq >/dev/null 2>&1 || ! command -v duckdb >/dev/null 2>&1; then
  printf 'Warning: jaq and DuckDB are required for structured search; using raw fallback.\n' >&2
  raw_results raw-fallback
  exit 0
fi

NORMALIZER="$TMP_ROOT/normalize.jaq"
cat > "$NORMALIZER" <<'JAQ'
def strings($value):
  if ($value | type) == "string" then $value
  elif ($value | type) == "array" then
    [$value[] |
      if (.type == "text" or .type == "input_text" or .type == "output_text") then (.text // empty)
      elif .type == "tool_use" then ((.name // "") + " " + ((.input // {}) | tojson))
      elif .type == "tool_result" then strings(.content)
      elif .type == "toolCall" then ((.name // "") + " " + ((.arguments // {}) | tojson))
      else empty
      end] | join("\n")
  else ""
  end;

def visible_strings($value):
  if ($value | type) == "string" then $value
  elif ($value | type) == "array" then
    [$value[] | select(.type == "text" or .type == "input_text" or .type == "output_text") | .text // empty] | join("\n")
  else ""
  end;

def tool_call_strings($value):
  if ($value | type) == "array" then
    [$value[] |
      if .type == "tool_use" then ((.name // "") + " " + ((.input // {}) | tojson))
      elif .type == "toolCall" then ((.name // "") + " " + ((.arguments // {}) | tojson))
      else empty
      end] | join("\n")
  else ""
  end;

def tool_result_strings($value):
  if ($value | type) == "array" then
    [$value[] | select(.type == "tool_result") | strings(.content)] | join("\n")
  else ""
  end;

def has_unknown_content($value; $known):
  ($value | type) == "array" and any($value[]; (.type as $type | $known | index($type)) == null);

def envelope($record_kind; $role; $tool_name; $text; $session_id; $session_name; $project; $timestamp; $raw):
  {
    harness: $harness,
    source_path: $source,
    session_id: ($session_id // ""),
    session_name: ($session_name // ""),
    project_or_cwd: ($project // ""),
    timestamp: ($timestamp // ""),
    record_kind: (if $record_kind == "unknown" then "raw_unknown" else $record_kind end),
    role: ($role // ""),
    tool_name: ($tool_name // ""),
    searchable_text: (if $record_kind == "unknown" then ($raw | tojson) else ($text // "") end),
    record_ordinal: .ordinal,
    raw_record_provenance: {
      ordinal: .ordinal,
      record_type: ($raw.type // $raw.payload.type // ""),
      record_id: ($raw.uuid // $raw.id // $raw.payload.id // "")
    }
  };

def claude($r):
  if (($r | type) != "object" or ($r.type | type) != "string") then
    envelope("unknown"; ""; ""; ""; null; null; null; null; $r)
  elif $r.type == "user" or $r.type == "assistant" then
    ($r.message.content // null) as $content |
    visible_strings($content) as $visible |
    tool_call_strings($content) as $tool_calls |
    tool_result_strings($content) as $tool_results |
    (if ($visible | length) > 0 then
       envelope($r.type; ($r.message.role // $r.type); ""; $visible; $r.sessionId; $r.slug; $r.cwd; $r.timestamp; $r)
     else empty end),
    (if ($tool_calls | length) > 0 then
       envelope("tool_call"; ($r.message.role // $r.type); ([$content[] | select(.type == "tool_use") | .name][0] // ""); $tool_calls; $r.sessionId; $r.slug; $r.cwd; $r.timestamp; $r)
     else empty end),
    (if ($tool_results | length) > 0 then
       envelope("tool_result"; ($r.message.role // $r.type); ""; $tool_results; $r.sessionId; $r.slug; $r.cwd; $r.timestamp; $r)
     else empty end),
    (if has_unknown_content($content; ["text", "thinking", "tool_use", "tool_result"]) then
       envelope("unknown"; ($r.message.role // $r.type); ""; ""; $r.sessionId; $r.slug; $r.cwd; $r.timestamp; $r)
     elif ($visible | length) == 0 and ($tool_calls | length) == 0 and ($tool_results | length) == 0 then
       envelope("metadata"; ($r.message.role // $r.type); ""; ""; $r.sessionId; $r.slug; $r.cwd; $r.timestamp; $r)
     else empty end)
  elif (["system", "summary", "progress", "file-history-snapshot", "queue-operation", "last-prompt", "custom-title", "agent-name", "mode", "permission-mode", "attachment", "file-history-delta"] | index($r.type)) != null then
    envelope("metadata"; ""; ""; ([$r.sessionId, $r.slug, $r.cwd, $r.summary, $r.lastPrompt, $r.customTitle, $r.agentName, $r.mode, $r.permissionMode] | map(select(. != null)) | join(" ")); $r.sessionId; ($r.customTitle // $r.slug); $r.cwd; $r.timestamp; $r)
  else
    envelope("unknown"; ""; ""; ""; $r.sessionId; $r.slug; $r.cwd; $r.timestamp; $r)
  end;

def codex($r):
  if (($r | type) != "object" or ($r.type | type) != "string") then
    envelope("unknown"; ""; ""; ""; null; null; null; null; $r)
  elif $r.type == "session_meta" and ($r.payload | type) == "object" then
    $r.payload as $p |
    envelope("metadata"; ""; ""; ([$p.id, $p.session_id, $p.thread_name, $p.agent_nickname, $p.cwd] | map(select(. != null)) | join(" ")); ($p.session_id // $p.id); ($p.thread_name // $p.agent_nickname); $p.cwd; ($r.timestamp // $p.timestamp); $r)
  elif $r.type == "response_item" and ($r.payload | type) == "object" then
    $r.payload as $p |
    if $p.type == "message" and (["user", "assistant", "developer", "system"] | index($p.role)) != null then
      (if $p.role == "user" or $p.role == "assistant" then $p.role else "metadata" end) as $kind |
      envelope($kind; $p.role; ""; strings($p.content); null; null; null; ($r.timestamp // $p.timestamp); $r),
      (if has_unknown_content($p.content; ["text", "input_text", "output_text"]) then
         envelope("unknown"; $p.role; ""; ""; null; null; null; ($r.timestamp // $p.timestamp); $r)
       else empty end)
    elif (["function_call", "custom_tool_call", "local_shell_call", "tool_call", "web_search_call", "computer_call"] | index($p.type)) != null then
      envelope("tool_call"; ($p.role // ""); ($p.name // $p.tool_name // ""); (($p.name // $p.tool_name // "") + " " + (($p.arguments // $p.input // $p.command // "") | if type == "string" then . else tojson end)); null; null; null; ($r.timestamp // $p.timestamp); $r)
    elif (["function_call_output", "custom_tool_call_output", "tool_call_output"] | index($p.type)) != null then
      envelope("tool_result"; ($p.role // ""); ($p.name // $p.tool_name // ""); (($p.output // $p.result // "") | if type == "string" then . else tojson end); null; null; null; ($r.timestamp // $p.timestamp); $r)
    elif $p.type == "reasoning" then
      envelope("metadata"; ""; ""; ""; null; null; null; ($r.timestamp // $p.timestamp); $r)
    else
      envelope("unknown"; ($p.role // ""); ""; ""; null; null; null; ($r.timestamp // $p.timestamp); $r)
    end
  elif $r.type == "event_msg" and ($r.payload | type) == "object" then
    $r.payload as $p |
    if $p.type == "user_message" then
      envelope("user"; "user"; ""; ($p.message // ""); null; null; null; ($r.timestamp // $p.timestamp); $r)
    elif $p.type == "agent_message" then
      envelope("assistant"; "assistant"; ""; ($p.message // ""); null; null; null; ($r.timestamp // $p.timestamp); $r)
    elif $p.type == "web_search_end" then
      envelope("tool_result"; ""; "web_search"; ([$p.query, $p.action] | map(select(. != null)) | join(" ")); null; null; null; ($r.timestamp // $p.timestamp); $r)
    elif $p.type == "patch_apply_end" then
      envelope("tool_result"; ""; "patch_apply"; ([$p.stdout, $p.stderr] | map(select(. != null)) | join("\n")); null; null; null; ($r.timestamp // $p.timestamp); $r)
    elif (["agent_reasoning", "token_count", "task_started", "task_complete", "task_completed", "turn_started", "turn_complete", "turn_completed", "context_compacted", "warning", "stream_error", "mcp_tool_call_begin", "mcp_tool_call_end", "sub_agent_activity"] | index($p.type)) != null then
      envelope("metadata"; ""; ""; ""; null; null; null; ($r.timestamp // $p.timestamp); $r)
    else
      envelope("unknown"; ""; ""; ""; null; null; null; ($r.timestamp // $p.timestamp); $r)
    end
  elif (["turn_context", "compacted", "world_state", "inter_agent_communication_metadata"] | index($r.type)) != null then
    envelope("metadata"; ""; ""; ""; null; null; null; $r.timestamp; $r)
  else
    envelope("unknown"; ""; ""; ""; null; null; null; $r.timestamp; $r)
  end;

def pi($r):
  if (($r | type) != "object" or ($r.type | type) != "string") then
    envelope("unknown"; ""; ""; ""; null; null; null; null; $r)
  elif $r.type == "session" or $r.type == "session_info" then
    envelope("metadata"; ""; ""; ([$r.id, $r.name, $r.cwd] | map(select(. != null)) | join(" ")); (if $r.type == "session" then $r.id else null end); (if $r.type == "session_info" then $r.name else null end); $r.cwd; $r.timestamp; $r)
  elif $r.type == "message" and ($r.message | type) == "object" and (["user", "assistant", "toolResult"] | index($r.message.role)) != null then
    ($r.message.content // null) as $content |
    visible_strings($content) as $visible |
    tool_call_strings($content) as $tool_calls |
    (if ($visible | length) > 0 then
       envelope((if $r.message.role == "toolResult" then "tool_result" else $r.message.role end); $r.message.role; ($r.message.toolName // ""); $visible; null; null; null; ($r.timestamp // $r.message.timestamp); $r)
     else empty end),
    (if ($tool_calls | length) > 0 then
       envelope("tool_call"; $r.message.role; ([$content[] | select(.type == "toolCall") | .name][0] // ""); $tool_calls; null; null; null; ($r.timestamp // $r.message.timestamp); $r)
     else empty end),
    (if has_unknown_content($content; ["text", "thinking", "toolCall", "image"]) then
       envelope("unknown"; $r.message.role; ""; ""; null; null; null; ($r.timestamp // $r.message.timestamp); $r)
     elif ($visible | length) == 0 and ($tool_calls | length) == 0 then
       envelope("metadata"; $r.message.role; ""; ""; null; null; null; ($r.timestamp // $r.message.timestamp); $r)
     else empty end)
  elif (["model_change", "thinking_level_change", "custom", "compaction", "branch_summary"] | index($r.type)) != null then
    envelope("metadata"; ""; ""; ""; null; null; null; $r.timestamp; $r)
  else
    envelope("unknown"; ""; ""; ""; null; null; $r.cwd; $r.timestamp; $r)
  end;

.raw as $raw |
if $harness == "claude" then claude($raw)
elif $harness == "codex" then codex($raw)
elif $harness == "pi" then pi($raw)
else empty
end
JAQ

EVENTS="$TMP_ROOT/events.jsonl"
: > "$EVENTS"

append_raw_matches() {
  local harness=$1
  local source=$2
  local raw_lines="$TMP_ROOT/raw-lines"
  local term
  : > "$raw_lines"
  for term in "${TERMS[@]}" "${PROJECT_FILTERS[@]}"; do
    rg -n -F "${RG_CASE[@]}" -- "$term" "$source" 2>/dev/null >> "$raw_lines" || true
  done
  sort -t: -k1,1n -u "$raw_lines" \
    | jaq -Rrc --arg harness "$harness" --arg source "$source" '
        capture("^(?<ordinal>[0-9]+):(?<text>.*)$") |
        {
          harness: $harness,
          source_path: $source,
          session_id: "",
          session_name: "",
          project_or_cwd: "",
          timestamp: "",
          record_kind: "raw",
          role: "",
          tool_name: "",
          searchable_text: .text,
          record_ordinal: (.ordinal | tonumber),
          raw_record_provenance: {ordinal: (.ordinal | tonumber), record_type: "raw", record_id: ""}
        }
      ' >> "$EVENTS"
}

while IFS=$'\t' read -r harness source; do
  normalized="$TMP_ROOT/normalized.$RANDOM.jsonl"
  if awk '{print "{\"ordinal\":" NR ",\"raw\":" $0 "}"}' "$source" \
      | jaq -c --arg harness "$harness" --arg source "$source" -f "$NORMALIZER" > "$normalized" 2>/dev/null \
      && [[ -s "$normalized" ]]; then
    cat "$normalized" >> "$EVENTS"
  else
    printf 'Warning: whole-file raw fallback for malformed %s JSONL: %s\n' "$harness" "$source" >&2
    append_raw_matches "$harness" "$source"
  fi
done < "$SOURCE_MAP"

TERMS_JSON="$TMP_ROOT/terms.jsonl"
: > "$TERMS_JSON"
ordinal=0
for term in "${TERMS[@]}"; do
  ordinal=$((ordinal + 1))
  jaq -cn --arg value "$term" --argjson ordinal "$ordinal" '{ordinal: $ordinal, value: $value}' >> "$TERMS_JSON"
done
PROJECTS_JSON="$TMP_ROOT/projects.jsonl"
: > "$PROJECTS_JSON"
for project in "${PROJECT_FILTERS[@]}"; do
  jaq -cn --arg value "$project" '{value: $value}' >> "$PROJECTS_JSON"
done

sql_quote() {
  printf "%s" "$1" | sed "s/'/''/g"
}
events_sql=$(sql_quote "$EVENTS")
terms_sql=$(sql_quote "$TERMS_JSON")
projects_sql=$(sql_quote "$PROJECTS_JSON")
case_expression='e.searchable_text'
term_expression='t.value'
required_term_expression='required.value'
project_expression="coalesce(e2.project_or_cwd, '') || ' ' || e2.source_path || ' ' || e2.searchable_text"
if [[ $CASE_INSENSITIVE -eq 1 ]]; then
  case_expression="lower($case_expression)"
  term_expression="lower($term_expression)"
  required_term_expression="lower($required_term_expression)"
  project_expression="lower($project_expression)"
fi

RESULTS="$TMP_ROOT/results.tsv"
duckdb -csv -noheader -separator $'\t' :memory: > "$RESULTS" <<SQL
WITH
  events AS (
    SELECT * FROM read_json_auto('$events_sql', format = 'newline_delimited')
  ),
  terms AS (
    SELECT * FROM read_json_auto('$terms_sql', format = 'newline_delimited')
  ),
  projects AS (
    SELECT * FROM read_json_auto('$projects_sql', format = 'newline_delimited', columns = {value: 'VARCHAR'})
  ),
  eligible AS (
    SELECT DISTINCT e.harness, e.source_path
    FROM events e
    WHERE NOT EXISTS (SELECT 1 FROM projects)
       OR EXISTS (
         SELECT 1
         FROM events e2, projects p
         WHERE e2.harness = e.harness
           AND e2.source_path = e.source_path
           AND contains($project_expression, $(if [[ $CASE_INSENSITIVE -eq 1 ]]; then printf 'lower(p.value)'; else printf 'p.value'; fi))
       )
  ),
  matched AS (
    SELECT e.*, t.ordinal AS term_ordinal,
      CASE e.record_kind
        WHEN 'user' THEN 5
        WHEN 'assistant' THEN 4
        WHEN 'metadata' THEN 3
        WHEN 'tool_call' THEN 1
        WHEN 'tool_result' THEN 1
        WHEN 'raw' THEN CAST((length($case_expression) - length(replace($case_expression, $term_expression, ''))) / nullif(length($term_expression), 0) AS BIGINT)
        WHEN 'raw_unknown' THEN CAST((length($case_expression) - length(replace($case_expression, $term_expression, ''))) / nullif(length($term_expression), 0) AS BIGINT)
        ELSE 1
      END AS weight
    FROM events e
    JOIN eligible USING (harness, source_path)
    CROSS JOIN terms t
    WHERE contains($case_expression, $term_expression)
      AND (
        e.record_kind != 'raw_unknown'
        OR NOT EXISTS (
          SELECT 1
          FROM terms required
          WHERE NOT contains($case_expression, $required_term_expression)
        )
      )
  ),
  qualified AS (
    SELECT harness, source_path
    FROM matched
    GROUP BY harness, source_path
    HAVING count(DISTINCT term_ordinal) = (SELECT count(*) FROM terms)
  ),
  stats AS (
    SELECT m.harness, m.source_path,
      count(DISTINCT m.record_ordinal) AS match_records,
      sum(m.weight) AS score,
      CASE
        WHEN bool_or(m.record_kind IN ('raw', 'raw_unknown'))
          AND bool_or(m.record_kind NOT IN ('raw', 'raw_unknown')) THEN 'mixed'
        WHEN bool_or(m.record_kind IN ('raw', 'raw_unknown')) THEN 'raw-fallback'
        ELSE 'structured'
      END AS mode,
      bool_or(m.record_kind = 'raw_unknown') AS unknown_contributed
    FROM matched m
    JOIN qualified q USING (harness, source_path)
    GROUP BY m.harness, m.source_path
  ),
  metadata AS (
    SELECT e.harness, e.source_path,
      max(nullif(CAST(e.session_id AS VARCHAR), '')) AS session_id,
      max(nullif(CAST(e.session_name AS VARCHAR), '')) AS session_name,
      max(nullif(CAST(e.project_or_cwd AS VARCHAR), '')) AS project_or_cwd,
      max(nullif(CAST(e.timestamp AS VARCHAR), '')) AS timestamp
    FROM events e
    JOIN qualified q USING (harness, source_path)
    GROUP BY e.harness, e.source_path
  )
SELECT s.harness, s.source_path,
  coalesce(m.session_id, ''), coalesce(m.session_name, ''),
  coalesce(m.project_or_cwd, ''), coalesce(m.timestamp, ''),
  s.match_records, s.score, s.mode, s.unknown_contributed
FROM stats s
JOIN metadata m USING (harness, source_path)
ORDER BY s.score DESC, s.source_path
LIMIT $TOP_N;
SQL

print_header
while IFS= read -r result; do
  unknown_contributed=$(printf '%s\n' "$result" | awk -F '\t' '{print $10}')
  if [[ "$unknown_contributed" == "true" ]]; then
    harness=$(printf '%s\n' "$result" | awk -F '\t' '{print $1}')
    source=$(printf '%s\n' "$result" | awk -F '\t' '{print $2}')
    printf 'Warning: unknown record raw fallback contributed to %s result: %s\n' "$harness" "$source" >&2
  fi
  printf '%s\n' "$result" | cut -f1-9
done < "$RESULTS"
