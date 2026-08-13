---
name: meta-search-sessions
description: >-
  Use when the user asks to find, recall, or locate a past Claude Code, Codex, or Pi session, conversation, or discussion by topic, keyword, project, path, or content.
---

# Session history search

Use the bundled `scripts/search_sessions.sh` rather than assembling ad hoc JSON parser pipelines.
It searches Claude Code, Codex, and Pi session stores by default and returns a bounded, ranked table of session files.

## Search workflow

Choose two to five specific terms that should occur in the same session.
Terms are literal strings and form an AND query at the file level.
Use `-i` unless exact case matters.

```bash
bash <skill-dir>/scripts/search_sessions.sh -i -n 10 \
  "architecture diagram" "bounded context"
```

The default structured mode uses `rg` to intersect candidate files, harness-specific `jaq` normalization to exclude hidden reasoning, and ephemeral DuckDB queries to verify terms and rank results.
Visible user and assistant messages and session metadata receive the highest weights.
Tool calls and results remain searchable at lower weights.
Temporary normalized data is removed when the command exits, and no persistent index is created.

## Scope and fallback

Repeat `--harness` to search any subset of the canonical harness names `claude`, `codex`, and `pi`.

```bash
bash <skill-dir>/scripts/search_sessions.sh \
  --harness codex --harness pi -i "terranix" "clusterAPI"
```

Use `--project TEXT` to match a session source path, recorded project, or cwd.
In raw mode, project scope is checked against both the source path and serialized file content.
Use repeatable `--path PATH` for direct files or directories; relative paths resolve under each selected harness store.
Pair an absolute path outside a standard store with exactly one `--harness` so its schema is unambiguous.
Run `--help` for the store locations and complete option contract.

Use `--raw` for maximum recall or when structured dependencies are unavailable.
Raw mode uses `rg`, can match hidden or implementation-only fields, and leaves metadata columns empty.
In structured mode, a syntactically valid unknown record is checked independently with raw semantics while known records remain normalized; it contributes only when that one record contains every term and satisfies project scope.
A malformed JSONL file uses whole-file raw fallback because its record boundaries are unreliable.
Missing `jaq` or DuckDB also triggers warned whole-file raw fallback.
The script warns when an unknown record contributes to a result or when whole-file fallback is required, not merely because an irrelevant unknown record exists.

## Interpret and inspect results

Each result reports harness, source path, session ID and name when available, project or cwd, latest timestamp, matching-record count, weighted score, and search mode.
A `structured` row matched only normalized known events.
A `raw-fallback` row matched only fallback events, while `mixed` means both normalized and per-record fallback events contributed.
An explicit `raw` row or any fallback contribution requires manual interpretation because its match may come from any serialized field.
Higher structured scores indicate more or higher-weight matching records, not semantic relevance by themselves.
In raw modes, `MATCH_RECORDS` counts distinct matching JSONL lines while `SCORE` counts all term occurrences.

The default table intentionally contains no transcript excerpts.
Refine terms or scope first, then inspect only a selected result with a bounded command such as:

```bash
rg -n -m 20 -F -i -- "term" /selected/session.jsonl
```

That extraction is raw and may expose hidden fields, so do not present it verbatim without checking the matched record kind.
Prefer the harness UI when a readable full-session view is needed.
