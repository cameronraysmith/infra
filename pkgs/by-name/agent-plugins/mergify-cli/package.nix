{
  fetchFromGitHub,
}:

fetchFromGitHub {
  pname = "agent-plugins-mergify-cli";
  version = "2026.8.31.1";
  owner = "Mergifyio";
  repo = "mergify-cli";
  rev = "727ce50b8fb3be8a9a24025807e159d644dbba80";
  hash = "sha256-BQl5L61m6uSr7y7fXoUsEwELmmSmHvs0jJMH22Zm82A=";
  passthru.releaseTag = "2026.8.31.1";
}
