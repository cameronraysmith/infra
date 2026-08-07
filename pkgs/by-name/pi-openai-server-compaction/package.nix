# The sole runtime dependency, `ws`, is deliberately not vendored: it is imported
# lazily (src/openai-ws-connection.ts) from a WebSocket transport that the
# isDirectOpenAIResponsesModel gate makes unreachable on the Codex provider, and
# its absence degrades to SSE rather than failing.
{ fetchFromGitHub }:
fetchFromGitHub {
  name = "pi-openai-server-compaction-source";
  owner = "algal";
  repo = "pi-openai-server-compaction";
  rev = "8a3de2f3b0c178fdd6f73f2f94172dfc3943e466";
  hash = "sha256-HFzG+GMriPhoMinjji+3sklQ7Nq0yRHCz/t9Re/TksU=";
}
