{
  perSystem =
    {
      lib,
      pkgs,
      inputs',
      config,
      self',
      ...
    }:
    let
      # Match the home-manager python environment from development-packages.nix.
      # duckdb routes to nixpkgs' python3Packages.duckdb here because the
      # perSystem pkgs overlay does not include customPackages from compose.nix.
      # The local duckdb/python-duckdb pair lives in pkgs/by-name/ with the
      # machine-shadowing toggle in modules/nixpkgs/duckdb-local.nix; this
      # devshell intentionally still resolves python duckdb from nixpkgs.
      # To use the local build here instead: append `config.packages.python-duckdb`.
      python = pkgs.python3.withPackages (
        ps: with ps; [
          duckdb
          huggingface-hub
          pip
          trafilatura
        ]
      );
    in
    {
      devShells.default = pkgs.mkShell {
        inputsFrom = [
          config.pre-commit.devShell
        ];

        # Composes the repo-root AGENTS.md/CLAUDE.md from the agent-context-*
        # apm fragments on shell entry, mirroring the git-hooks.nix precedent
        # above of writing a git-ignored generated file from a shellHook.
        # `lib.getExe` embeds the store path at eval time so entering the
        # shell costs a fork+exec, not a nix evaluation; `--if-stale` makes
        # that exec a no-op once the composed output already matches the
        # fragments. `--auto` lets the script itself pick the repository
        # tier vs every tier by checking for a user-level agent context file
        # (see apm-context-compile.sh); it never fails the shell, since a
        # missing AGENTS.md degrades an agent session but must not block a
        # human terminal or direnv.
        shellHook = ''
          if ! ${lib.getExe config.packages.apm-context-compile} --if-stale --auto; then
            echo "apm-context-compile: skipped (run 'just agents-context' to regenerate AGENTS.md/CLAUDE.md manually)" >&2
          fi
        '';

        # The playwright-web-flake default devShell is intentionally not inherited;
        # select the browser set explicitly. Use the full flake set (chromium,
        # firefox, webkit) on both platforms: the fork carries working macOS-15
        # (rev 2311) and Linux webkit builds, so the all-browser local `just
        # docs-test` passes. The Chrome-for-Testing sandbox crash that forces the
        # nixpkgs-chromium wrapper is specific to the hermetic e2e check in
        # pkgs/by-name/vanixiets-docs/package.nix, not this interactive devShell.
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
        PLAYWRIGHT_BROWSERS_PATH = "${inputs'.playwright-web-flake.packages.playwright-driver.browsers}";

        packages = [
          python
          inputs'.clan-core.packages.default
          inputs'.nix2container.packages.skopeo-nix2container
          pkgs.just
          pkgs.nh
          pkgs.omnix
          pkgs.nix-output-monitor
          self'.packages.nix-fast-build
          pkgs.nix-update
          pkgs.nix-prefetch-github
          self'.packages.uncomment-bin
          # Tools required by Makefile verify target
          pkgs.age
          pkgs.ssh-to-age
          pkgs.sops
          # Kubernetes cluster management
          pkgs.clusterctl
          pkgs.kluctl
          pkgs.k3d
          pkgs.ctlptl
          pkgs.kyverno-chainsaw
          pkgs.rsync # nixidy-sync manifest deployment
          # Tools required by TypeScript packages CI
          pkgs.bun
          inputs'.bun2nix.packages.default
          pkgs.nodejs_24 # semantic-release >= 24.10.0
          pkgs.fuc
          pkgs.rip2
          # Language detection
          pkgs.github-linguist
          # Document typesetting
          pkgs.typstWithPackages
          pkgs.svgo
        ]
        # buildbot-effects CLI for local dispatch of hercules-ci-effects
        # (see buildbot-nix/docs/EFFECTS.md). Linux-only: depends on bwrap.
        ++ lib.optionals pkgs.stdenv.isLinux [
          inputs'.buildbot-nix.packages.buildbot-effects
        ];

        passthru.meta.description = "Development environment with clan CLI and build tools";
      };
    };
}
