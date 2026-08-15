{
  fetchFromGitHub,
  findutils,
  stdenvNoCC,
}:
let
  rev = "c700f300707db5345727052682c88e3064030aa2";
in
stdenvNoCC.mkDerivation {
  pname = "pi-agent-extensions";
  version = rev;

  src = fetchFromGitHub {
    owner = "rytswd";
    repo = "pi-agent-extensions";
    inherit rev;
    hash = "sha256-RLtDi9ahKONSJBuuYkYo/oIIxDX6PWiZ7rlevOStUUk=";
  };

  nativeBuildInputs = [ findutils ];

  dontConfigure = true;
  dontBuild = true;
  strictDeps = true;

  installPhase = ''
    runHook preInstall

    sourceNodeModules=$(find . -type d -name node_modules -print -quit)
    if [ -n "$sourceNodeModules" ]; then
      echo "pi-agent-extensions source contains node_modules: $sourceNodeModules" >&2
      exit 1
    fi

    mkdir -p "$out"
    cp -R . "$out/"

    installedNodeModules=$(find "$out" -type d -name node_modules -print -quit)
    if [ -n "$installedNodeModules" ]; then
      echo "pi-agent-extensions output contains node_modules: $installedNodeModules" >&2
      exit 1
    fi

    runHook postInstall
  '';
}
