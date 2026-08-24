#!/usr/bin/env bash
# shellcheck shell=bash
#
# end-to-end validation for omp's mnemopi memory backend.
#
# one check, where the hindsight predecessor had two. its tier 0 drove the
# vendor's http api directly to prove the credential worked; a local sqlite
# store has no credential and no endpoint, so that tier retired with the
# backend. what survives is the tier that always carried the weight: omp's own
# lifecycle, auto-retain on session end and auto-recall before the first model
# turn, which is native to the agent (src/mnemopi/state.ts) and cannot be
# expressed as an http call from outside. one session states a fact, a second
# session is asked for it back.
#
# isolation is by overlay rather than by scratch $HOME. --config layers a
# config.yml over the real one for the run, so mnemopi.dbPath sends every write
# to a throwaway file while the session keeps the provider credentials the real
# profile holds. a scratch $HOME would isolate the store too, but it would also
# hide the credentials, which is why the hindsight version needed a key handed
# to it in the environment. the run asserts the scratch database exists before
# it trusts the result: if the overlay had not taken, writes would have landed
# in the production store and a pass would mean nothing.
#
# embeddings are off by default so the check stays fast and offline-ish. recall
# then runs over sqlite fts, which is enough to prove retain and recall are
# wired to each other. --embeddings exercises the vector path instead, at the
# cost of a first-use fastembed download into ~/.omp/cache.

set -euo pipefail

codeword="amber-falcon-42"
bank="omp-validation"
model=""
keep_scratch=0
no_embeddings=true

while [ "$#" -gt 0 ]; do
  case "$1" in
    --model) shift; model="${1:-}" ;;
    --bank) shift; bank="${1:-}" ;;
    --embeddings) no_embeddings=false ;;
    --keep-scratch) keep_scratch=1 ;;
    -h|--help)
      # writeShellApplication prepends its own shebang and a shellcheck
      # directive, so drop those before echoing this header back.
      grep '^#' "$0" \
        | grep -v -e '^#!' -e '^# shellcheck' \
        | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

scratch="$(mktemp -d)"
db="${scratch}/mnemopi.db"
overlay="${scratch}/overlay.yml"

cleanup() {
  if [ "$keep_scratch" -eq 0 ]; then
    rm -rf "$scratch"
  else
    echo "--- leaving scratch store at ${scratch} (--keep-scratch)"
  fi
}
trap cleanup EXIT

cat >"$overlay" <<YAML
memory:
  backend: mnemopi
mnemopi:
  scoping: global
  bank: ${bank}
  dbPath: ${db}
  noEmbeddings: ${no_embeddings}
  autoRecall: true
  autoRetain: true
YAML

# --model is optional: omitting it uses whatever the default role resolves to,
# rather than restating a model string this app would then have to keep in step
# with the home configuration. pass a cheap one to keep the run cheap, e.g.
# --model openai-codex/gpt-5.6-luna.
omp_args=(-p --no-session --config "$overlay")
if [ -n "$model" ]; then
  omp_args+=(--model "$model")
fi

echo "=== omp memory lifecycle over mnemopi ==="
echo "--- store: ${db} (bank ${bank}, embeddings $([ "$no_embeddings" = true ] && echo off || echo on))"

echo "--- smoke test"
omp --smoke-test

echo "--- session 1: state the fact"
omp "${omp_args[@]}" \
  "Use your memory retain tool to remember this exact fact: the validation codeword is ${codeword}."

if [ ! -s "$db" ]; then
  echo "FAIL: ${db} was not written, so the overlay did not take and this run proves nothing" >&2
  echo "      (any memory the session retained went to the production store instead)" >&2
  exit 1
fi

echo "--- session 2: ask for it back"
answer="$(omp "${omp_args[@]}" "What is the validation codeword? Answer from memory.")"
echo "$answer"

if printf '%s' "$answer" | grep -q "$codeword"; then
  echo "PASS: the second session recalled ${codeword} from the first"
else
  echo "FAIL: the second session did not recall ${codeword}" >&2
  exit 1
fi
