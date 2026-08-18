#!/usr/bin/env bash
# shellcheck shell=bash
#
# end-to-end validation for omp's hindsight memory backend.
#
# two tiers, because they fail for different reasons and a combined pass/fail
# would not say which half is broken.
#
#   tier 0  the token, the endpoint, and the bank, over plain http with no llm
#           in the loop. retains a codeword and recalls it. this is the tier
#           that tells you whether the credential itself works.
#
#   tier 1  omp's own memory lifecycle, which tier 0 cannot reach: auto-retain
#           on session end and auto-recall before the first model turn are
#           native to the agent (src/hindsight/backend.ts) and are not
#           expressible as http calls. one session states a fact, a second
#           session is asked for it back. needs a provider key for --model.
#
# both tiers write to bank omp-validation, never to the shared `omp` bank the
# home configuration targets, and tier 1 runs against a scratch $HOME so the
# real ~/.omp is neither read nor written. the bank is deleted on exit unless
# --keep-bank is given.
#
# the request shapes below are taken from the service's own openapi document
# (hindsight-docs/static/openapi.json in the upstream monorepo, the same spec
# the rust client is generated from) rather than from prose documentation, and
# tier 0 has been run green against the live service.

set -euo pipefail

api_url="${HINDSIGHT_API_URL:-https://api.hindsight.vectorize.io}"
bank="omp-validation"
codeword="amber-falcon-42"
model=""
run_tier1=0
keep_bank=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tier1) run_tier1=1 ;;
    --model) shift; model="${1:-}" ;;
    --bank) shift; bank="${1:-}" ;;
    --keep-bank) keep_bank=1 ;;
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

if [ -z "${HINDSIGHT_API_TOKEN:-}" ]; then
  echo "error: HINDSIGHT_API_TOKEN is not set." >&2
  echo "       mint one at ui.hindsight.vectorize.io -> Organization -> Connect -> Create API Key," >&2
  echo "       then add it to secrets.yaml as hindsight-api-token and export it here." >&2
  exit 1
fi

base="${api_url}/v1/default/banks/${bank}"
scratch="$(mktemp -d)"

cleanup() {
  if [ "$keep_bank" -eq 0 ]; then
    echo "--- cleanup: deleting bank ${bank}"
    curl -fsS -X DELETE "$base" \
      -H "Authorization: Bearer ${HINDSIGHT_API_TOKEN}" >/dev/null 2>&1 \
      || echo "    warning: could not delete bank ${bank}; remove it via ui.hindsight.vectorize.io" >&2
  else
    echo "--- cleanup: leaving bank ${bank} in place (--keep-bank)"
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT

api() {
  local method=$1 path=$2
  shift 2
  curl -fsS -X "$method" "${base}${path}" \
    -H "Authorization: Bearer ${HINDSIGHT_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "$@"
}

echo "=== tier 0: token, endpoint, bank ==="
echo "--- creating bank ${bank} at ${api_url}"
# CreateBankRequest has no required fields but the body itself is required;
# omitting it is a 422, not a default-everything create.
api PUT "" --data "$(jq -nc --arg n "$bank" '{name: $n}')" >/dev/null

echo "--- retaining the codeword"
api POST /memories --data "$(jq -nc \
  --arg c "The validation codeword is ${codeword}." \
  '{async: false, items: [{content: $c}]}')" >/dev/null

# server-side extraction is asynchronous even with async:false on the request,
# so a single immediate recall can legitimately come back empty. poll rather
# than conclude failure on the first miss.
echo "--- recalling (polling up to 60s for asynchronous extraction)"
found=0
for _ in $(seq 1 20); do
  if api POST /memories/recall \
      --data '{"query": "validation codeword"}' \
      | grep -q "$codeword"; then
    found=1
    break
  fi
  sleep 3
done

if [ "$found" -ne 1 ]; then
  echo "FAIL: tier 0 recall never returned ${codeword}" >&2
  exit 1
fi
echo "PASS: tier 0 retained and recalled ${codeword}"

if [ "$run_tier1" -eq 0 ]; then
  echo
  echo "tier 1 skipped; pass --tier1 --model <provider/model> to exercise omp itself."
  exit 0
fi

if [ -z "$model" ]; then
  echo "error: --tier1 needs --model <provider/model>, and a provider key in the environment." >&2
  exit 2
fi

echo
echo "=== tier 1: omp's own retain and recall lifecycle ==="

# omp derives every configuration root from $HOME, so a scratch $HOME is
# sufficient isolation from the real ~/.omp. bankId is set here and nowhere in
# the home configuration, which deliberately leaves it unset so that production
# sessions land in the base bank.
export HOME="$scratch"
mkdir -p "$scratch/.omp/agent"
cat > "$scratch/.omp/agent/config.yml" <<YAML
memory:
  backend: hindsight
hindsight:
  apiUrl: ${api_url}
  bankId: ${bank}
YAML

echo "--- smoke test"
omp --smoke-test

echo "--- session 1: state the fact"
omp -p --model "$model" \
  "Use the retain tool to remember this exact fact: the validation codeword is ${codeword}."

echo "--- session 2: ask for it back"
answer="$(omp -p --model "$model" "What is the validation codeword?")"
echo "$answer"

if printf '%s' "$answer" | grep -q "$codeword"; then
  echo "PASS: tier 1 second session recalled ${codeword} from the first"
else
  echo "FAIL: tier 1 second session did not recall ${codeword}" >&2
  exit 1
fi
