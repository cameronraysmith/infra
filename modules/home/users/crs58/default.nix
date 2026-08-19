{
  # OUTER: Flake-parts module signature
  ...
}:
let
  content =
    {
      # INNER: Home-manager module signature
      config,
      pkgs,
      lib,
      flake, # from extraSpecialArgs
      ...
    }:
    let
      # Alias set from the dev-graph cookbook's omnigraph-config.example.yaml,
      # retargeted from its `local` server to our magnetite deployment.
      devGraphAlias =
        query: args:
        {
          server = "magnetite";
          graph = "dev";
          inherit query;
        }
        // lib.optionalAttrs (args != [ ]) { inherit args; };
    in
    {
      home.stateVersion = "23.11";

      home.packages = [
        flake.inputs.niks3.packages.${pkgs.stdenv.hostPlatform.system}.niks3
      ]
      ++ [
        # On PATH for per-repository opt-in ergonomics: gpg.x509.program is
        # written by hand in a repo-local config, and the alternative is
        # pasting a store path that goes stale on the next update. Nothing
        # invokes it until someone opts in. The credential helper needs no
        # such entry — generated config references it by absolute store path.
        pkgs.buzz-git-sign-nostr
      ];

      # Inject linear-cli's bundled skill (a single linear-cli/ dir with one
      # SKILL.md and 16 reference subfiles under references/) into all agent
      # destinations, scoped to this user. linear-cli .src is the fetchFromGitHub
      # store path; its top-level skills/ dir is read by readSkillsFrom in the ai
      # module, which finds the single subdir linear-cli/.
      #
      # Discoverability: the all-agents skill openspec-linear-sync (in
      # modules/home/ai/plugins/planning-and-development/.apm/skills/openspec-linear-sync)
      # softly depends on this user-scoped linear-cli skill for its Linear verbs; it is
      # co-delivered only for this user and no-ops gracefully when absent. If a
      # non-crs58 user is added, move this injection into the shared ai module.
      aiSkills.extraSkillDirs = [
        "${pkgs.linear-cli.src}/skills"
      ];

      # User-level OpenSpec install (skills, schema bundle, and the global
      # config.json) is provided by the opt-in programs.openspec module in
      # modules/home/ai/openspec/default.nix.
      programs.openspec.enable = true;

      programs.omnigraph = {
        enable = true;
        settings = {
          servers.magnetite.url = "http://[fddb:4344:343b:14b9:399:930f:39db:40d2]:8090";

          defaults = {
            server = "magnetite";
            default_graph = "dev";
          };

          aliases = {
            issue = devGraphAlias "issue_lookup" [ "slug" ];
            epic = devGraphAlias "epic_lookup" [ "slug" ];
            pr = devGraphAlias "pr_lookup" [ "slug" ];

            ready = devGraphAlias "ready" [ ];
            blocked = devGraphAlias "blocked" [ ];
            blocked-parent = devGraphAlias "blocked_by_parent" [ ];
            blocked-epic = devGraphAlias "blocked_by_epic" [ ];
            blocked-gate = devGraphAlias "blocked_by_gate" [ ];
            blocked-wait = devGraphAlias "blocked_by_wait" [ ];
            blocked-upstream = devGraphAlias "blocked_on_upstream" [ ];
            stale = devGraphAlias "stale_candidates" [ ];

            epic-issues = devGraphAlias "epic_issues" [ "epic" ];
            epic-open = devGraphAlias "epic_open_issues" [ "epic" ];

            release-prs = devGraphAlias "release_prs" [ "release" ];
            issue-prs = devGraphAlias "issue_implementations" [ "issue" ];
            prs-comp = devGraphAlias "prs_for_component" [ "component" ];
            issues-comp = devGraphAlias "issues_for_component" [ "component" ];

            incident-cause = devGraphAlias "incident_root_cause" [ "incident" ];
            incident-blast = devGraphAlias "incident_components" [ "incident" ];
            learnings-incident = devGraphAlias "learnings_for_incident" [ "incident" ];

            unheld-invariants = devGraphAlias "unheld_invariants" [ ];
            gaps = devGraphAlias "gaps_undermining_invariants" [ ];
            assumptions = devGraphAlias "assumptions" [ ];
            caps-tier = devGraphAlias "capabilities_by_tier" [ "tier" ];
            decisions-comp = devGraphAlias "decisions_for_component" [ "component" ];
            no-spec = devGraphAlias "components_without_spec" [ ];
            no-cap-impl = devGraphAlias "capabilities_without_component" [ ];

            open-epics = devGraphAlias "open_epics" [ ];
            epic-counts = devGraphAlias "epic_issue_counts" [ "epic" ];
            issue-detail = devGraphAlias "issue_detail" [ "issue" ];
            issue-blockers = devGraphAlias "issue_blockers" [ "issue" ];
            issue-parents = devGraphAlias "issue_parents" [ "issue" ];
            issue-epic-parent = devGraphAlias "issue_parent_epic" [ "issue" ];
            issue-gates = devGraphAlias "issue_gates" [ "issue" ];
            issue-waits-on = devGraphAlias "issue_waits_on" [ "issue" ];
            issue-comments = devGraphAlias "issue_comments" [ "issue" ];

            sem-issue = devGraphAlias "search_issues" [ "q" ];
            sem-epic = devGraphAlias "search_epics" [ "q" ];
            sem-spec = devGraphAlias "search_specs" [ "q" ];
            sem-decision = devGraphAlias "search_decisions" [ "q" ];
            sem-learning = devGraphAlias "search_learnings" [ "q" ];
            sem-invariant = devGraphAlias "search_invariants" [ "q" ];
            sem-principle = devGraphAlias "search_principles" [ "q" ];
            sem-gap = devGraphAlias "search_gaps" [ "q" ];
            sem-cap = devGraphAlias "search_capabilities" [ "q" ];
            sem-pr = devGraphAlias "search_prs" [ "q" ];
            sem-incident = devGraphAlias "search_incidents" [ "q" ];
          };
        };
      };

      # sops-nix configuration for crs58/cameron user
      # 23 secrets: development + ai + shell aggregates
      sops = {
        defaultSopsFile = flake.inputs.self + "/secrets/home-manager/users/crs58/secrets.yaml";
        secrets = {
          github-token = { };
          ssh-signing-key = {
            mode = "0400";
          };
          ssh-public-key = { }; # For allowed_signers generation
          glm-api-key = { };
          tm-source-drive-data-root = { };
          firecrawl-api-key = { };
          huggingface-token = { };
          cerebras-api-key = { };
          linear-api-key-personal = { };
          linear-api-key-work = { };
          linear-workspace-personal = { };
          linear-workspace-work = { };
          context7-api-key = { };
          # Hindsight cloud token for omp's memory backend, rendered to
          # ~/.omp/.env by the sops template in modules/home/ai/omp.
          hindsight-api-token = { };
          # Per-host scoped cognee X-Api-Key for the always-on cognee-memory
          # plugin and the cognee-cli wrapper. Declared here; its ciphertext is
          # added to secrets.yaml after the one-time owner-authenticated mint
          # against the live magnetite server (a user-run bootstrap gate), so
          # home-manager activation requires the minted value to be present.
          cognee-api-key = { };
          # Moshi pairing token, copied from the app's Settings -> Hooks screen
          # and consumed once per host by the moshi-hook launcher in
          # modules/home/ai/moshi. Seeded blank in secrets.yaml because
          # sops-nix validates every declared key when the generation is built:
          # the key has to exist before the token does. A blank value leaves
          # the daemon serving its local socket unpaired.
          moshi-pairing-token = {
            mode = "0400";
          };
          bitwarden-email = { };
          atuin-key = { };
          mcp-agent-mail-bearer-token = { };
          buzz-nsec = { };
          git-credentials = {
            mode = "0400"; # Read-only: prevent git credential-store from modifying
            path = "${config.home.homeDirectory}/.git-credentials";
          };
          aws-credentials = {
            mode = "0600"; # AWS SDK requires 600 for credentials file
            path = "${config.home.homeDirectory}/.aws/credentials";
          };
          niks3-auth-token = {
            path = "${config.xdg.configHome}/niks3/auth-token";
          };
        };

        # Generate allowed_signers file using sops.templates
        # Simpler than activation script - uses same pattern as rbw and mcp-servers
        templates."allowed_signers" = {
          mode = "0400";
          path = "${config.xdg.configHome}/git/allowed_signers";
          content = ''
            ${flake.users.crs58.meta.email} namespaces="git" ${config.sops.placeholder."ssh-public-key"}
          '';
        };

        # schpet/linear-cli inline-format credentials, rendered immutably from sops.
        # Inline format: flat `<workspace> = "<api-key>"` keys plus a top-level
        # `default = "<workspace>"` (see schpet credentials.ts hasInlineKeys /
        # parseInlineCredentials). schpet uses XDG on darwin too (Deno reads
        # XDG_CONFIG_HOME, else ~/.config), so no per-platform path conditional.
        # Read-only (0400): switch profiles via `--workspace` / a `default` change,
        # never via mutating `linear auth` commands which would clobber this file.
        templates."linear-credentials.toml" = {
          mode = "0400";
          path = "${config.xdg.configHome}/linear/credentials.toml";
          content = ''
            default = "${config.sops.placeholder."linear-workspace-personal"}"

            ${config.sops.placeholder."linear-workspace-personal"} = "${
              config.sops.placeholder."linear-api-key-personal"
            }"
            ${config.sops.placeholder."linear-workspace-work"} = "${
              config.sops.placeholder."linear-api-key-work"
            }"
          '';
        };

        # hindsight CLI credentials, rendered immutably from sops so the CLI
        # works without a `hindsight configure` step.
        #
        # This cannot reuse the ~/.omp/.env file the omp module renders, for two
        # independent reasons: that file is read by omp's own loader rather than
        # exported to the shell, and the two tools spell the credential
        # differently. The CLI reads HINDSIGHT_API_KEY and HINDSIGHT_API_URL
        # (src/config.rs) and never HINDSIGHT_API_TOKEN, which is the name omp
        # uses. Its resolution order is environment, then named profile, then
        # this file, then a localhost default, so writing it here leaves the
        # environment free to override per invocation.
        #
        # Read-only (0400): change the URL with --api-url or the environment,
        # never via `hindsight configure`, which would clobber this file.
        templates."hindsight-cli-config" = {
          mode = "0400";
          path = "${config.home.homeDirectory}/.hindsight/config";
          content = ''
            api_url = "https://api.hindsight.vectorize.io"
            api_key = "${config.sops.placeholder."hindsight-api-token"}"
          '';
        };

        # Note: Radicle keys deployed via home.file below (not sops.templates due to pure eval path issues)
      };

      # The token is a bearer credential for registering this host with Moshi,
      # so the daemon is handed the decrypted path rather than the value; see
      # modules/home/ai/moshi for how the launcher consumes it.
      services.moshi-hook.pairingTokenFile = config.sops.secrets.moshi-pairing-token.path;

      # Deploy radicle public key (not secret - can be plaintext, but identity-bound)
      # This is the SSH public key used for Radicle node identity
      home.file.".radicle/keys/radicle.pub".text = ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINdO9rInDa9HvdtZZxmkgeEdAlTupCy3BgA/sqSGyUH+ ${flake.users.crs58.meta.email}
      '';

      # Note: Radicle signing key linked via activation script in radicle.nix
      # Cannot use home.file.source with sops.secrets.path due to pure eval mode restrictions
      # TODO: Investigate sops-nix symlink option or activation script approach

      programs.git.settings = {
        user.name = flake.users.crs58.meta.fullname;
        user.email = flake.users.crs58.meta.email;

        # buzz-nsec keeps the default sops path while git-credentials and
        # aws-credentials at :77-84 set explicit ones. That asymmetry is two
        # different requirements, not an inconsistency: those two consumers need
        # a fixed location, whereas an explicit `path` materializes a per-secret
        # symlink and git-sign-nostr's open_keyfile
        # (crates/git-sign-nostr/src/lib.rs) opens with O_NOFOLLOW. The default
        # materializes a regular file inside a symlinked generation directory,
        # and O_NOFOLLOW constrains only the trailing component, so it is
        # accepted. Nothing invokes git-sign-nostr today, so this constrains no
        # active path; it applies the moment anyone opts in per-repository.
        nostr.keyfile = config.sops.secrets.buzz-nsec.path;

        # `*` matches exactly one label, so this covers every community on
        # communities.buzz.xyz. The leading "" clears the inherited generic
        # helper chain from development/git.nix, whose `store --file` helper is
        # fatal against the read-only sops-rendered ~/.git-credentials.
        credential."https://*.communities.buzz.xyz/git" = {
          helper = [
            ""
            (lib.getExe' pkgs.buzz-git-credential-nostr "git-credential-nostr")
          ];
          useHttpPath = true;
        };
      };

      programs.jujutsu.settings.user = {
        name = flake.users.crs58.meta.fullname;
        email = flake.users.crs58.meta.email;
      };
    };
in
{
  flake.users.crs58.contentPrivate = content;
}
