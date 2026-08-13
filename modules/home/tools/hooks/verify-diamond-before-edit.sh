# shellcheck shell=bash
# Hook: Verify development-join integrity before edit-class tool operations.
# Tier-aware: only fires when a multi-parent join (description "join N=...") is
# present in mutable() history. Tier 1 (anonymous chain on @) and tier 2 (single
# named bookmark) are no-ops per modules/home/ai/plugins/version-control-and-forge/.apm/skills/jj-version-control/tiered-ceremony.md.
# Note: the "join N=k: ..." description prefix is a project convention used in
# this repo's diamond-workflow tooling; see ~/.claude/skills/jj-version-control/SKILL.md.
# Two or more commits in mutable() whose description begins "join N=" make the
# shape ambiguous: a development join is a single multi-parent commit, so there
# is no one parent set to check against and no way to tell which join was meant.
# The checklist below does not run in that state; the hook asks instead.
# Tier 3 (exactly one development join) runs the diamond-health invariant checklist:
#   (i)   chain ∈ join's parents (declared bookmarks match parent set)
#   (ii)  join's parents = current bookmark targets (no staleness)
#   (iii) @ is in one of four valid positions relative to the join:
#           (A) @ IS the join (construction-time)
#           (B) @ is a direct child of the join (idle wip)
#           (C) @ is in a linear non-merge stack above the join
#               (splice-below-join authoring in-progress, or docs stack
#                awaiting splice/route)
#           (D) @ is anywhere in the mutable diamond interior — any mutable
#               ancestor of the join, excluding the join itself. Covers any
#               chain commit at any depth (tip, mid-chain, root) and any
#               splice-region commit (route-and-extend in-progress, in-chain
#               editing via jj edit, splice-region editing via jj edit).
# Checks (i)/(ii) run only in cases (A)/(B); cases (C)/(D) are mid-operation
# transients in which bookmark advancement lags the join's parent set by design.
# Emits permissionDecision=ask on violation or ambiguity (never deny — both are
# recoverable).
# PreToolUse:Edit|Write|MultiEdit (sync) -- reads JSON context from stdin.

set -euo pipefail

INPUT=$(cat)
# INPUT is read for protocol conformance; this hook does not inspect tool_input.
: "${INPUT:=}"

# --- jj-mode detection ---
JJ_ROOT=""
dir=$(pwd)
while [ "$dir" != "/" ]; do
  if [ -d "$dir/.jj" ]; then
    JJ_ROOT="$dir"
    break
  fi
  dir=$(dirname "$dir")
done

if [ -z "$JJ_ROOT" ]; then
  exit 0  # not a jj repo
fi

# A linked worktree of a colocated repo lives under the jj root, so the walk
# above finds .jj even though jj is unavailable here and no diamond exists to
# verify. Without this, an operation allowed at the worktree-creation layer is
# re-blocked at the edit layer by a prompt the occupant cannot resolve.
if hook_in_linked_worktree "$(pwd)"; then
  exit 0
fi

# --- Tier 3 detection: multi-parent commits in mutable() with description "join N=..." ---
# Read the whole match set instead of truncating with `head -1`. Truncation
# closes the pipe while jj is still writing, jj exits 3 on EPIPE, and `set -o
# pipefail` makes that the hook's status: with two or more joins the check
# aborted silently, precisely when the topology is most degraded.
JOIN_CHANGES=$(jj log -r 'mutable()' --no-graph \
                 -T 'if(parents.len() > 1 && description.starts_with("join N="), change_id ++ "\n", "")' \
                 2>/dev/null | sed '/^$/d')
JOIN_COUNT=$(printf '%s' "$JOIN_CHANGES" | grep -c . || true)

if [ "$JOIN_COUNT" -eq 0 ]; then
  exit 0  # tier 1 or tier 2; no diamond to verify
fi

# A development join is a single multi-parent commit. With more than one there is
# no single parent set to check bookmarks against, so surface the ambiguity
# rather than choosing a join and reporting on a topology nobody intended.
if [ "$JOIN_COUNT" -gt 1 ]; then
  JOIN_LIST=$(printf '%s' "$JOIN_CHANGES" | tr '\n' ',' | sed 's/,$//')
  cat << EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Diamond shape ambiguous: $JOIN_COUNT commits whose description begins 'join N=' are present in mutable() ($JOIN_LIST). A development join is a single multi-parent commit, so the integrity check cannot determine which join to verify and did not run. Resolve to one join first: reparent onto the intended set with the rebase pair (both halves are one sequence) 'jj rebase -r <join> -d <bookmark1> -d <bookmark2> ...' then 'jj rebase -s <the join's former direct child, normally the wip commit> -d <join>'; or, for any commit that is not the development join, redescribe it so its description does not begin with 'join N='. See ~/.claude/skills/jj-version-control/SKILL.md (composite maintenance invariant)."}}
EOF
  exit 0
fi

JOIN_CHANGE="$JOIN_CHANGES"

# --- Gather join + @ topology ---
JOIN_PARENTS=$(jj log -r "$JOIN_CHANGE" --no-graph \
                 -T 'parents.map(|c| c.change_id()).join(" ")' 2>/dev/null)
AT_PARENTS=$(jj log -r '@' --no-graph \
               -T 'parents.map(|c| c.change_id()).join(" ")' 2>/dev/null)
AT_CHANGE=$(jj log -r '@' --no-graph -T 'change_id' 2>/dev/null)

# --- Refined check (iii): classify @ into one of four valid positions ---
# (A) @ IS the join                                       — construction-time
# (B) @ is a direct child of the join                     — idle wip
# (C) @ is in a linear non-merge stack above the join     — splice-by-construction in-progress
# (D) @ is anywhere in the mutable diamond interior
#     (any mutable ancestor of the join, excluding the join itself).
#     Covers: jj edit on any chain commit (tip, mid-chain, root) AND on any
#     splice-region commit. Uniform handling because the topological notion
#     "@ is working in the interior of the diamond" is the same regardless
#     of how @ got there (jj new --insert-after, jj edit, etc.).
CASE=""
if [ "$AT_CHANGE" = "$JOIN_CHANGE" ]; then
  CASE="A"
elif [ "$AT_PARENTS" = "$JOIN_CHANGE" ]; then
  CASE="B"
else
  # Test case (C): @ above join via a linear non-merge path
  ABOVE_JOIN=$(jj log -r "@ & ${JOIN_CHANGE}::" --no-graph -T 'change_id' 2>/dev/null || true)
  if [ -n "$ABOVE_JOIN" ]; then
    MERGES_BETWEEN=$(jj log -r "(${JOIN_CHANGE}..@) & merges()" --no-graph \
                       -T 'change_id ++ " "' 2>/dev/null || true)
    if [ -z "$MERGES_BETWEEN" ]; then
      CASE="C"
    fi
  fi

  # Test case (D): @ anywhere in the mutable diamond interior
  # (any mutable ancestor of the join, excluding the join itself).
  # Covers: jj edit on any chain commit (tip, mid-chain, root) AND on any
  # splice-region commit. Uniform handling because the topological notion
  # "@ is working in the interior of the diamond" is the same regardless
  # of how @ got there (jj new --insert-after, jj edit, etc.).
  if [ -z "$CASE" ]; then
    IN_INTERIOR=$(jj log -r "@ & mutable() & ::${JOIN_CHANGE} & ~${JOIN_CHANGE}" \
                    --no-graph -T 'change_id' 2>/dev/null || true)
    if [ -n "$IN_INTERIOR" ]; then
      CASE="D"
    fi
  fi
fi

if [ -z "$CASE" ]; then
  cat << EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Diamond integrity violation (iii): @ is not in any of the four valid positions for tier-3 work. Valid positions: (A) @ is the join itself, (B) @ is a direct child of the join (idle wip state), (C) @ is in a linear non-merge stack above the join (splice-below-join by-construction in-progress), or (D) @ is anywhere in the mutable diamond interior — any mutable ancestor of the join, including any chain commit at any depth (tip, mid-chain, root) or any splice-region commit (in-chain editing, splice-region editing, route-and-extend in-progress). Recovery depends on intent: jj new $JOIN_CHANGE -m 'wip' to return @ to the idle position, or jj edit <chain-tip-change-id> to resume in-chain work. See ~/.claude/skills/jj-version-control/SKILL.md (composite maintenance invariant)."}}
EOF
  exit 0
fi

# --- Checks (i)/(ii) gated on idle states (A) or (B) ---
# Cases (C) and (D) are mid-operation transients during which bookmark advancement
# lags the join's parent set by design. Comparing declared vs. actual bookmarks in
# those states produces false positives; the in-progress operation will reconcile
# the diamond when it advances the relevant bookmark.
if [ "$CASE" != "A" ] && [ "$CASE" != "B" ]; then
  exit 0
fi

# --- Check (i) + (ii): declared bookmarks in join description match bookmarks at parent commits ---
JOIN_DESC_FIRSTLINE=$(jj log -r "$JOIN_CHANGE" --no-graph \
                       -T 'description.first_line()' 2>/dev/null)
# Parse "join N=k: a, b, c" -> sorted lines, one bookmark per line
DECLARED=$(echo "$JOIN_DESC_FIRSTLINE" | \
            sed -nE 's/^join N=[0-9]+: (.*)$/\1/p' | \
            tr ',' '\n' | \
            sed 's/^ *//;s/ *$//' | \
            grep -v '^$' | \
            sort)

# Read bookmarks at each join parent, then filter to the declared set.
# This ignores extraneous refs (e.g., remote-tracking like main@origin) that
# may be co-located on a chain tip and would otherwise cause false positives.
ACTUAL_RAW=$(
  for parent in $JOIN_PARENTS; do
    jj log -r "$parent" --no-graph \
      -T 'bookmarks.map(|b| b.name()).join("\n")' 2>/dev/null
    echo
  done | grep -v '^$' | sort -u
)
if [ -z "$DECLARED" ]; then
  ACTUAL=""
else
  ACTUAL=$( (echo "$ACTUAL_RAW" | grep -Fxf <(echo "$DECLARED") || true) | sort )
fi

if [ "$DECLARED" != "$ACTUAL" ]; then
  DECLARED_LINE=$(echo "$DECLARED" | tr '\n' ',' | sed 's/,$//')
  ACTUAL_LINE=$(echo "$ACTUAL" | tr '\n' ',' | sed 's/,$//')
  cat << EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Diamond integrity violation (i)/(ii): join's declared bookmarks differ from current bookmark targets at its parents. Declared: '$DECLARED_LINE'. At parents: '$ACTUAL_LINE'. Often this means a bookmark advanced without the join being updated, or the join was created before all chains existed. Recovery options: (a) rewrite the join onto the current chain tips with the rebase pair, whose two halves are one sequence and must both be run: 'jj rebase -r $JOIN_CHANGE -d <bookmark1> -d <bookmark2> ...' then 'jj rebase -s <the join's former direct child, normally the wip commit> -d $JOIN_CHANGE'. The first half reparents the join in place and structurally reparents its descendants away from it; run alone it leaves the working copy a two-parent merge at the old parent set with the join orphaned, which is worse than the state being recovered from. The second half takes -s, not -r, so any commits stacked above the wip commit return with it; -r would pull the wip commit off alone and orphan them along with content spliced into them. (b) redescribe the join if the parent set is intentional: jj describe $JOIN_CHANGE -m 'join N=k: <comma-separated bookmarks>'. See ~/.claude/skills/jj-version-control/SKILL.md."}}
EOF
  exit 0
fi

# All invariants hold.
exit 0
