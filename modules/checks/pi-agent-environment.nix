{ self, lib, ... }:
{
  perSystem =
    {
      pkgs,
      self',
      system,
      ...
    }:
    let
      mkCheck = self.lib.mkStructuralCheck pkgs;
      homeConfig = self.homeConfigurations."crs58@${system}".config;
      piConfig = homeConfig.programs.pi-coding-agent;
      extensionPackage = self'.packages.pi-agent-extensions or null;
      extensionSource = if extensionPackage == null then null else toString extensionPackage;
      packageEntries = piConfig.settings.packages or [ ];
      extensionEntry = lib.findFirst (
        entry: builtins.isAttrs entry && (entry.source or null) == extensionSource
      ) null packageEntries;
      extensionSelectors = if extensionEntry == null then [ ] else extensionEntry.extensions or [ ];
      positiveExtensions = builtins.filter (selector: !lib.hasPrefix "-" selector) extensionSelectors;
      negativeExtensions = builtins.filter (selector: lib.hasPrefix "-" selector) extensionSelectors;
      extensionSourceImmutable =
        extensionEntry != null && lib.hasPrefix builtins.storeDir (toString extensionEntry.source);
      homeFileAt = target: lib.attrByPath [ target ] null homeConfig.home.file;
      homeFileEnabled =
        target:
        let
          file = homeFileAt target;
        in
        file != null && file.enable;
      homeFileImmutable =
        target:
        let
          file = homeFileAt target;
        in
        file != null
        && file.enable
        && file.source != null
        && lib.hasPrefix builtins.storeDir (toString file.source);
      hasImmutableHomeFileAtOrBelow =
        target:
        lib.any (name: (name == target || lib.hasPrefix "${target}/" name) && homeFileImmutable name) (
          builtins.attrNames homeConfig.home.file
        );
      settingsTarget = "${piConfig.configDir}/settings.json";
      sessionsTarget = "${piConfig.configDir}/sessions";
      authenticationTarget = "${piConfig.configDir}/auth.json";
      projectTrustTarget = "${piConfig.configDir}/trust.json";
      extensionStateTarget = "${piConfig.configDir}/packages";
      settingsActivation = lib.attrByPath [
        "piCodingAgentMutableSettings"
      ] { } homeConfig.home.activation;
      settingsActivationData = settingsActivation.data or "";
      runtimeStateCategories = [
        {
          name = "settings";
          immutable = homeFileEnabled settingsTarget;
        }
        {
          name = "sessions";
          immutable = hasImmutableHomeFileAtOrBelow sessionsTarget;
        }
        {
          name = "compaction";
          immutable = hasImmutableHomeFileAtOrBelow sessionsTarget;
        }
        {
          name = "authentication";
          immutable = homeFileImmutable authenticationTarget;
        }
        {
          name = "project-trust";
          immutable = homeFileImmutable projectTrustTarget;
        }
        {
          name = "model-selection";
          immutable = homeFileEnabled settingsTarget;
        }
        {
          name = "thinking-preferences";
          immutable = homeFileEnabled settingsTarget;
        }
        {
          name = "extension-state";
          immutable = homeFileEnabled settingsTarget || hasImmutableHomeFileAtOrBelow extensionStateTarget;
        }
      ];
      runtimeStateOutsideImmutableLinks = map (entry: entry.name) (
        builtins.filter (entry: !entry.immutable) runtimeStateCategories
      );
      activationScripts = map (entry: entry.data or "") (builtins.attrValues homeConfig.home.activation);
      canonicalSkillsScript = lib.findFirst (
        script: lib.hasInfix "$HOME/.agents/skills" script
      ) "" activationScripts;
      piSpecificSkillsPresent =
        lib.any (name: lib.hasInfix ".pi/agent/skills" name) (builtins.attrNames homeConfig.home.file)
        || lib.any (script: lib.hasInfix ".pi/agent/skills" script) activationScripts;
      contextTarget = "${piConfig.configDir}/AGENTS.md";
      contextFile = homeFileAt contextTarget;
      globalInstructionsNixOwned =
        piConfig.context == homeConfig.programs.agents-md.settings.text && homeFileImmutable contextTarget;
      themeTarget = "${piConfig.configDir}/themes/catppuccin-mocha.json";
      themePath = "${toString ../home/ai/pi}/themes/catppuccin-mocha.json";
      themePresent = builtins.pathExists themePath;
      themeJson = if themePresent then builtins.fromJSON (builtins.readFile themePath) else { };
      immutableExtensionTargets =
        if extensionSourceImmutable then
          map (selector: "pi-agent-extensions/${selector}") positiveExtensions
        else
          [ ];
      permissionRulesTarget = ".config/pi-agent-extensions/permission-gate/rules.ts";
      editWritePolicyTarget = "${piConfig.configDir}/extensions/edit-write-policy.ts";
      immutablePolicyTargets =
        lib.optional (
          extensionSourceImmutable && builtins.elem "permission-gate/index.ts" positiveExtensions
        ) "pi-agent-extensions/permission-gate/index.ts"
        ++ lib.optional (homeFileImmutable permissionRulesTarget) "~/.config/pi-agent-extensions/permission-gate/rules.ts"
        ++ lib.optional (homeFileImmutable editWritePolicyTarget) "~/.pi/agent/extensions/edit-write-policy.ts";
      permissionRulesPath = ../home/ai/pi/policy/permission-rules.ts;
      editWritePolicyPath = ../home/ai/pi/policy/edit-write-policy.ts;
      permissionRulesModule =
        if builtins.pathExists permissionRulesPath then
          permissionRulesPath
        else
          pkgs.writeText "missing-permission-rules.ts" ''
            export const policyPresent = false;
            export default function missingPermissionRules() { return {}; }
          '';
      editWritePolicyModule =
        if builtins.pathExists editWritePolicyPath then
          editWritePolicyPath
        else
          pkgs.writeText "missing-edit-write-policy.ts" ''
            export const policyPresent = false;
          '';
      shellCases = [
        {
          kind = "shell";
          name = "safe command is allowed";
          command = "printf '%s\\n' safe";
          expected = "allow";
        }
        {
          kind = "shell";
          name = "safe curl GET is allowed";
          command = "curl --request GET https://example.invalid";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "safe wget GET is allowed";
          command = "wget https://example.invalid/file";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "safe curl HEAD is allowed";
          command = "curl --request HEAD https://example.invalid";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "safe wget OPTIONS is allowed";
          command = "wget --method OPTIONS https://example.invalid";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "dangerous built-in sudo prompts";
          command = "sudo id";
          expected = "prompt";
        }
        {
          kind = "shell";
          name = "direct rm blocks";
          command = "rm file.txt";
          expected = "block";
          reason = "rip";
          custom = true;
        }
        {
          kind = "shell";
          name = "composed rm blocks";
          command = "printf done && rm -f file.txt";
          expected = "block";
          reason = "rip";
          custom = true;
        }
        {
          kind = "shell";
          name = "deferred rm blocks";
          command = "find . -name '*.tmp' -exec rm {} +";
          expected = "block";
          reason = "rip";
          custom = true;
        }
        {
          kind = "shell";
          name = "git worktree creation prompts";
          command = "git worktree add ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj workspace creation prompts";
          command = "jj workspace add ../feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "git global option before worktree prompts";
          command = "git -C /repo worktree add ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wrapped Git global option before worktree prompts";
          command = "env git --no-pager -C /repo worktree add ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "composed jj global option before workspace prompts";
          command = "printf ready && jj -R /repo workspace add ../feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "git short paginate alias before worktree prompts";
          command = "git -p worktree add ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wrapped Git short no-pager alias before worktree prompts";
          command = "env git -P worktree add ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "composed jj debug flag before workspace prompts";
          command = "printf ready && jj --debug workspace add ../feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "unknown Git global cannot hide worktree creation";
          command = "git --future-global value worktree add ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wrapped unknown jj global cannot hide workspace creation";
          command = "env jj --future-global value workspace add ../feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "composed unknown Git global cannot hide worktree creation";
          command = "printf ready && git --future-global=value worktree add ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "Git global option value is not a worktree subcommand";
          command = "git -C worktree add ../feature feature";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj global option value is not a workspace subcommand";
          command = "jj -R workspace add ../feature";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "argv-injected Git worktree alias prompts";
          command = "git -c alias.wt=worktree wt add ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wrapped argv-injected jj workspace alias prompts";
          command = "env jj --config 'aliases.ws=[\"workspace\"]' ws add ../feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "Git injected alias overriding known command prompts";
          command = "git -c alias.remote=worktree remote add ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj injected alias overriding known command prompts";
          command = "jj --config 'aliases.bookmark=[\"workspace\"]' bookmark add ../feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "Git injected alias embedding worktree add prompts";
          command = "git -c 'alias.wa=worktree add' wa ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wrapped Git injected alias embedding worktree add prompts";
          command = "env git -c 'alias.wa=worktree add' wa ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj injected alias embedding workspace add prompts";
          command = "jj --config 'aliases.wa=[\"workspace\",\"add\"]' wa ../feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wrapped jj injected alias embedding workspace add prompts";
          command = "env jj --config 'aliases.wa=[\"workspace\",\"add\"]' wa ../feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "Git mixed-quoted embedded-add alias prompts";
          command = "git -c 'alias.wa=worktree \"add\"' wa ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wrapped jj literal-string embedded-add alias prompts";
          command = "env jj --config \"aliases.wa=['workspace','add']\" wa ../feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "unparseable invoked injected alias prompts";
          command = "git -c 'alias.wa=!complex shell expansion' wa ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "composed argv-injected jj TOML workspace alias prompts";
          command = "printf ready && jj --config-toml 'aliases.ws = [\"workspace\"]' ws add ../feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "persistent unknown Git alias-shaped add prompts";
          command = "git wt add ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wrapped persistent unknown jj alias-shaped add prompts";
          command = "env jj ws add ../feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "unknown Git global cannot hide persistent alias-shaped add";
          command = "git --future-global value wt add ../feature feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "known Git remote add remains allowed";
          command = "git remote add origin https://example.invalid/repo.git";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "ordinary jj bookmark list remains allowed";
          command = "jj bookmark list";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "pi install blocks";
          command = "pi install npm:example";
          expected = "block";
          reason = "Nix";
          custom = true;
        }
        {
          kind = "shell";
          name = "pi remove blocks through wrapper";
          command = "env pi remove npm:example";
          expected = "block";
          reason = "Nix";
          custom = true;
        }
        {
          kind = "shell";
          name = "pi uninstall blocks";
          command = "pi uninstall npm:example";
          expected = "block";
          reason = "Nix";
          custom = true;
        }
        {
          kind = "shell";
          name = "pi update blocks";
          command = "pi update";
          expected = "block";
          reason = "Nix";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl separate request mutation prompts";
          command = "curl --request POST https://example.invalid";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl equals request mutation prompts";
          command = "curl --request=PATCH https://example.invalid";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl glued request mutation prompts";
          command = "curl -XDELETE https://example.invalid/item";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl glued data value containing XGET prompts";
          command = "curl -dXGET https://example.invalid/item";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl glued header value containing XGET is allowed";
          command = "curl -HXGET https://example.invalid/item";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl valid short option cluster request mutation prompts";
          command = "curl -sXPOST https://example.invalid/item";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl final request option controls mutation";
          command = "curl -XGET --request DELETE https://example.invalid/item";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl next transfer cannot hide earlier mutation";
          command = "curl -XPOST https://example.invalid/first --next -XGET https://example.invalid/second";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl short next alias cannot hide earlier mutation";
          command = "curl -XPOST https://example.invalid/first -: -XGET https://example.invalid/second";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl long next token consumed as header value is allowed";
          command = "curl -H --next https://example.invalid/resource";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl short next token consumed as header value is allowed";
          command = "curl -H -: https://example.invalid/resource";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl next tokens after end-of-options are positional";
          command = "curl -- --next -:";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl safe long multi-transfer is allowed";
          command = "curl -XGET https://example.invalid/first --next -XHEAD https://example.invalid/second";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl safe short multi-transfer is allowed";
          command = "curl -XGET https://example.invalid/first -: -XHEAD https://example.invalid/second";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl mutation after long boundary prompts";
          command = "curl -XGET https://example.invalid/first --next -XPOST https://example.invalid/second";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl mutation after short boundary prompts";
          command = "curl -XGET https://example.invalid/first -: -XPOST https://example.invalid/second";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl WebDAV MKCOL prompts";
          command = "curl --request MKCOL https://example.invalid/collection";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl custom explicit method prompts";
          command = "curl -XFROB https://example.invalid/resource";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl lowercase method is not read-only GET";
          command = "curl --request get https://example.invalid/resource";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl long config prompts";
          command = "curl --config request.conf https://example.invalid";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl glued short config prompts";
          command = "curl -Krequest.conf https://example.invalid";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl data mutation prompts";
          command = "curl --data=value https://example.invalid";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl upload mutation prompts";
          command = "curl -Tpayload https://example.invalid";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wget separate method mutation prompts";
          command = "wget --method POST https://example.invalid";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wget equals method mutation prompts";
          command = "wget --method=DELETE https://example.invalid/item";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wget post data mutation prompts";
          command = "wget --post-data=payload https://example.invalid";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wget WebDAV MOVE prompts";
          command = "wget --method MOVE https://example.invalid/resource";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wget custom explicit method prompts";
          command = "wget --method=FROB https://example.invalid/resource";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wget lowercase method is not read-only HEAD";
          command = "wget --method=head https://example.invalid/resource";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wget header value resembling method cannot mask post data";
          command = "wget --header --method=GET --post-data payload https://example.invalid/resource";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "composed wget body value resembling safe method prompts";
          command = "printf ready && wget --post-data --method=GET https://example.invalid/resource";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wget ordinary header value remains allowed";
          command = "wget --header 'Accept: application/json' https://example.invalid/resource";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "wget opaque config prompts";
          command = "wget --config=request.conf https://example.invalid/resource";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wrapped wget short execute prompts";
          command = "env wget -euse_proxy=yes https://example.invalid/resource";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wget long execute prompts";
          command = "wget --execute=use_proxy=yes https://example.invalid/resource";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wget malformed method prompts";
          command = "wget --method";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "wget ambiguous unknown option prompts";
          command = "wget --future-option value https://example.invalid/resource";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "headless HTTP prompt blocks";
          command = "curl -XPOST https://example.invalid";
          expected = "block";
          custom = true;
          headless = true;
        }
        {
          kind = "shell-error";
          name = "throwing parser rule blocks diagnostically";
          expected = "block";
          reason = "rule evaluation failed";
        }
      ];
      projectCases = [
        {
          kind = "project";
          name = "project cannot replace rules";
          project = {
            rules = [
              {
                label = "allow everything";
                pattern = ".*";
              }
            ];
          };
          command = "sudo id";
          expected = "prompt";
          warning = "may not replace rules";
        }
        {
          kind = "project";
          name = "project cannot disable block rules";
          project.disabledRules = [ "scan /nix/store" ];
          command = "rg needle /nix/store";
          expected = "block";
          warning = "may not disable block rule";
        }
        {
          kind = "project";
          name = "project cannot disable protected prompt rules";
          project.disabledRules = [ "modify gate config" ];
          command = "tee ~/.config/pi-agent-extensions/permission-gate/rules.ts < payload";
          expected = "prompt";
          warning = "may not disable load-bearing prompt rule";
        }
        {
          kind = "project";
          name = "project cannot disable headless prompt rules";
          project.disabledRules = [ "sudo" ];
          command = "sudo id";
          expected = "block";
          warning = "may not disable prompt rule(s) without a UI";
          headless = true;
        }
      ];
      coreCases = [
        {
          kind = "core";
          name = "mutable path outside repository prompts";
          expected = "prompt";
          input = {
            operation = "edit";
            target = {
              kind = "mutable";
              canonicalPath = "/workspace/note.txt";
            };
            repository.kind = "outside-repository";
          };
        }
        {
          kind = "core";
          name = "nix store target blocks";
          expected = "block";
          reason = "immutable";
          input = {
            operation = "write";
            target = {
              kind = "immutable";
              canonicalPath = "/nix/store/abc-policy";
              root = "/nix/store";
            };
          };
        }
        {
          kind = "core";
          name = "declared immutable root blocks";
          expected = "block";
          reason = "immutable";
          input = {
            operation = "edit";
            target = {
              kind = "immutable";
              canonicalPath = "/immutable/config.json";
              root = "/immutable";
            };
          };
        }
        {
          kind = "core";
          name = "git feature branch allows";
          expected = "allow";
          input = {
            operation = "edit";
            target = {
              kind = "mutable";
              canonicalPath = "/repo/file.ts";
            };
            repository = {
              kind = "git";
              root = "/repo";
              head = {
                kind = "feature";
                branch = "feature/policy";
              };
            };
          };
        }
        {
          kind = "core";
          name = "git double-dot-prefixed child allows";
          expected = "allow";
          input = {
            operation = "edit";
            target = {
              kind = "mutable";
              canonicalPath = "/repo/..config";
            };
            repository = {
              kind = "git";
              root = "/repo";
              head = {
                kind = "feature";
                branch = "feature/policy";
              };
            };
          };
        }
        {
          kind = "core";
          name = "git main blocks";
          expected = "block";
          reason = "main";
          input = {
            operation = "write";
            target = {
              kind = "mutable";
              canonicalPath = "/repo/file.ts";
            };
            repository = {
              kind = "git";
              root = "/repo";
              head = {
                kind = "protected";
                branch = "main";
              };
            };
          };
        }
        {
          kind = "core";
          name = "git master blocks";
          expected = "block";
          reason = "master";
          input = {
            operation = "edit";
            target = {
              kind = "mutable";
              canonicalPath = "/repo/file.ts";
            };
            repository = {
              kind = "git";
              root = "/repo";
              head = {
                kind = "protected";
                branch = "master";
              };
            };
          };
        }
        {
          kind = "core";
          name = "invalid repository state blocks";
          expected = "block";
          reason = "ambiguous";
          input = {
            operation = "edit";
            target = {
              kind = "mutable";
              canonicalPath = "/repo/file.ts";
            };
            repository = {
              kind = "invalid";
              diagnostic = "ambiguous repository identity";
            };
          };
        }
      ];
      repositoryScenarios = [
        "ordinary-healthy"
        "ordinary-conflict"
        "ordinary-divergent-at"
        "ordinary-main-at"
        "ordinary-master-at"
        "diamond-healthy"
        "diamond-missing-wip"
        "diamond-moved-wip"
        "diamond-divergent-wip"
        "diamond-divergent-wip-without-target"
        "diamond-divergent-wip-malformed-resolution"
        "diamond-nonempty-join"
        "diamond-single-parent-join"
        "diamond-conflicted-join"
        "malformed-probe"
        "malformed-parent-count-probe"
        "failing-probe"
        "ambiguous-probe"
        "failing-root-probe"
        "outside-jj-contradictory-stdout"
        "outside-jj-wrong-status"
        "outside-jj-mixed-diagnostics"
        "classification-whitespace-only"
        "classification-padded"
        "classification-extra-blank"
        "root-padded"
        "current-extra-blank"
        "identity-padded"
        "defaults-extra-blank"
        "resolution-padded"
        "parents-extra-blank"
        "canonical-root-mismatch"
        "target-jj-cwd-other-repository"
        "target-git-cwd-jj-repository"
        "git-protected-head"
        "git-feature-head"
        "git-detached-head"
        "git-malformed-head"
        "git-multiline-head"
      ];
      repositoryCases = map (
        scenario:
        {
          kind = "repository";
          name = "repository ${scenario}";
          inherit scenario;
          expected =
            if
              builtins.elem scenario [
                "ordinary-healthy"
                "target-jj-cwd-other-repository"
                "target-git-cwd-jj-repository"
                "git-feature-head"
                "git-detached-head"
                "diamond-healthy"
              ]
            then
              "allow"
            else
              "block";
          expectedJjCalls =
            if lib.hasPrefix "ordinary-" scenario || scenario == "target-jj-cwd-other-repository" then
              5
            else
              null;
        }
        //
          lib.optionalAttrs
            (builtins.elem scenario [
              "target-jj-cwd-other-repository"
              "target-git-cwd-jj-repository"
            ])
            {
              target = "/target/new/file.ts";
              cwd = "/cwd";
              expectedProbeCwd = "/target";
            }
        // lib.optionalAttrs (scenario == "target-git-cwd-jj-repository") {
          expectedGitRootDirectory = "/target";
          expectedGitHeadDirectory = "/target";
        }
        // lib.optionalAttrs (scenario == "git-protected-head") {
          reason = "main";
        }
        //
          lib.optionalAttrs
            (builtins.elem scenario [
              "classification-whitespace-only"
              "classification-padded"
              "classification-extra-blank"
            ])
            {
              reason = "classification";
            }
        // lib.optionalAttrs (scenario == "root-padded") {
          reason = "root";
        }
        //
          lib.optionalAttrs
            (builtins.elem scenario [
              "outside-jj-contradictory-stdout"
              "outside-jj-wrong-status"
              "outside-jj-mixed-diagnostics"
            ])
            {
              reason = "jj root";
            }
        // lib.optionalAttrs (scenario == "current-extra-blank") {
          reason = "current";
        }
        // lib.optionalAttrs (scenario == "identity-padded") {
          reason = "identity";
        }
        // lib.optionalAttrs (scenario == "defaults-extra-blank") {
          reason = "default bookmark";
        }
        // lib.optionalAttrs (scenario == "resolution-padded") {
          reason = "resolution";
        }
        // lib.optionalAttrs (scenario == "parents-extra-blank") {
          reason = "parent";
        }
        //
          lib.optionalAttrs
            (builtins.elem scenario [
              "git-malformed-head"
              "git-multiline-head"
            ])
            {
              reason = "Git head";
            }
        // lib.optionalAttrs (scenario == "diamond-divergent-wip-without-target") {
          reason = "divergent";
        }
        // lib.optionalAttrs (scenario == "diamond-divergent-wip-malformed-resolution") {
          reason = "malformed";
        }
      ) repositoryScenarios;
      gitRootCases = [
        {
          kind = "git-root";
          name = "characterized Git outside result is accepted";
          result = {
            stdout = "";
            stderr = "fatal: not a git repository (or any of the parent directories): .git\n";
            code = 128;
          };
          expected = "outside";
        }
        {
          kind = "git-root";
          name = "Git outside result with contradictory stdout is invalid";
          result = {
            stdout = "/repo\n";
            stderr = "fatal: not a git repository (or any of the parent directories): .git\n";
            code = 128;
          };
          expected = "invalid";
          reason = "Git root";
        }
        {
          kind = "git-root";
          name = "Git outside result with wrong status is invalid";
          result = {
            stdout = "";
            stderr = "fatal: not a git repository (or any of the parent directories): .git\n";
            code = 1;
          };
          expected = "invalid";
          reason = "Git root";
        }
        {
          kind = "git-root";
          name = "Git outside result with mixed diagnostics is invalid";
          result = {
            stdout = "";
            stderr = "fatal: not a git repository (or any of the parent directories): .git\nadditional diagnostic\n";
            code = 128;
          };
          expected = "invalid";
          reason = "Git root";
        }
      ];
      adapterCases = [
        {
          kind = "adapter";
          name = "adapter registers only tool_call handler";
          scenario = "registration";
          expected = "pass";
        }
        {
          kind = "adapter";
          name = "adapter translates edit allow";
          scenario = "git-feature";
          tool = "edit";
          input.path = "/repo/file.ts";
          expected = "pass";
        }
        {
          kind = "adapter";
          name = "adapter translates write allow";
          scenario = "git-feature";
          tool = "write";
          input.path = "/repo/file.ts";
          expected = "pass";
        }
        {
          kind = "adapter";
          name = "adapter translates edit diagnostic block";
          scenario = "immutable";
          tool = "edit";
          input.path = "/nix/store/abc";
          expected = "block";
          reason = "immutable";
        }
        {
          kind = "adapter";
          name = "adapter normalizes Pi at-prefixed paths";
          scenario = "builtin-at-prefix";
          tool = "write";
          input.path = "@/nix/store/abc";
          expected = "block";
          reason = "immutable";
        }
        {
          kind = "adapter";
          name = "adapter translates write diagnostic block";
          scenario = "git-main";
          tool = "write";
          input.path = "/repo/file.ts";
          expected = "block";
          reason = "main";
        }
        {
          kind = "adapter";
          name = "adapter passes unrelated tools through";
          scenario = "capability-throws";
          tool = "read";
          input.path = "/repo/file.ts";
          expected = "pass";
        }
        {
          kind = "adapter";
          name = "adapter blocks malformed tool input";
          scenario = "git-feature";
          tool = "edit";
          input.path = 42;
          expected = "block";
          reason = "malformed";
        }
        {
          kind = "adapter";
          name = "adapter blocks core exceptions";
          scenario = "core-throws";
          tool = "edit";
          input.path = "/repo/file.ts";
          expected = "block";
          reason = "policy evaluation failed";
        }
        {
          kind = "adapter";
          name = "adapter blocks capability exceptions";
          scenario = "capability-throws";
          tool = "write";
          input.path = "/repo/file.ts";
          expected = "block";
          reason = "capability failed";
        }
        {
          kind = "adapter";
          name = "adapter blocks unavailable interaction";
          scenario = "outside-headless";
          tool = "edit";
          input.path = "/workspace/file.ts";
          expected = "block";
          reason = "interaction unavailable";
        }
      ];
      policyCases = pkgs.writeText "pi-agent-environment-policy-cases.json" (
        builtins.toJSON (
          shellCases ++ projectCases ++ coreCases ++ repositoryCases ++ gitRootCases ++ adapterCases
        )
      );
      policyTypeDeclarations = pkgs.writeText "pi-agent-environment-policy-external.d.ts" ''
        declare namespace NodeJS {
          interface ErrnoException extends Error { code?: string | number }
        }
        declare module "node:child_process" {
          export function execFile(
            file: string,
            args: readonly string[],
            options: { cwd: string; encoding: "utf8" },
            callback: (error: NodeJS.ErrnoException | null, stdout: string, stderr: string) => void,
          ): void;
        }
        declare module "node:fs/promises" {
          interface Stats {
            isDirectory(): boolean;
          }
          export function realpath(path: string): Promise<string>;
          export function stat(path: string): Promise<Stats>;
        }
        declare module "node:path" {
          export function basename(path: string): string;
          export function dirname(path: string): string;
          export function isAbsolute(path: string): boolean;
          export function join(...paths: string[]): string;
          export function relative(from: string, to: string): string;
          export function resolve(...paths: string[]): string;
          export const sep: string;
        }
        declare module "@earendil-works/pi-coding-agent" {
          interface ToolCallEvent {
            readonly toolName: string;
            readonly toolCallId: string;
            readonly input: unknown;
          }
          interface ExtensionContext {
            readonly cwd: string;
            readonly hasUI: boolean;
            readonly ui: {
              confirm(title: string, message: string): Promise<boolean>;
            };
          }
          export interface ExtensionAPI {
            on(
              event: "tool_call",
              handler: (
                event: ToolCallEvent,
                context: ExtensionContext,
              ) => Promise<{ readonly block: true; readonly reason: string } | undefined>,
            ): void;
          }
        }
      '';
      policyTsconfig = pkgs.writeText "pi-agent-environment-policy-tsconfig.json" (
        builtins.toJSON {
          compilerOptions = {
            strict = true;
            noEmit = true;
            allowImportingTsExtensions = true;
            module = "ESNext";
            moduleResolution = "Bundler";
            target = "ES2022";
            baseUrl = ".";
            paths."pi-agent-extensions/permission-gate/*" = [ "./permission-gate/*" ];
            skipLibCheck = true;
          };
          files = [
            "./external.d.ts"
            "./permission-rules.ts"
            "./edit-write-policy.ts"
          ];
        }
      );
      policyHarness = pkgs.writeText "pi-agent-environment-policy-test.ts" ''
        import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
        import { tmpdir } from "node:os";
        import { join } from "node:path";
        import { pathToFileURL } from "node:url";
        import { mock } from "bun:test";

        mock.module("@mariozechner/pi-tui", () => ({
          Editor: class {},
          Key: {},
          matchesKey: () => false,
          truncateToWidth: (value: string) => value,
          wrapTextWithAnsi: (value: string) => [value],
        }));

        const gateRoot = process.env.PERMISSION_GATE_ROOT;
        const gate = async (file: string) => import(pathToFileURL(gateRoot + "/" + file).href);
        const config = await gate("config.ts");
        const matcher = await gate("match.ts");
        const shell = await gate("shell.ts");
        const helpersModule = await gate("helpers.ts");
        const builtinsModule = await gate("builtin-rules.ts");
        const gateIndex = await gate("index.ts");
        const permissionModule = await import(pathToFileURL(process.env.PERMISSION_RULES_MODULE).href);
        const editModule = await import(pathToFileURL(process.env.EDIT_WRITE_POLICY_MODULE).href);
        const cases = JSON.parse(readFileSync(process.env.POLICY_CASES, "utf8"));
        const failures: string[] = [];

        const helpers = {
          simpleCommands: shell.simpleCommands,
          pipelines: shell.pipelines,
          searchPaths: builtinsModule.searchPaths,
          unwrap: shell.unwrap,
          unwrapSteps: shell.unwrapSteps,
          nestedScripts: shell.nestedScripts,
          deferredScripts: shell.deferredScripts,
          anyCmd: helpersModule.anyCmd,
          hasFlag: helpersModule.hasFlag,
          SHELLS: shell.SHELLS,
        };
        const hasPermissionPolicy = permissionModule.policyPresent === true && typeof permissionModule.default === "function";
        const hasEditPolicy = editModule.policyPresent === true && typeof editModule.decideEditWrite === "function";
        const customConfig = hasPermissionPolicy ? permissionModule.default(helpers) : {};

        function classify(command: string, userCode: unknown, project: unknown, headless: boolean) {
          const warnings: string[] = [];
          try {
            const rules = config.compileRules(
              {
                userCode,
                userJson: {},
                project: config.sanitizeConfig(project, ".pi/permission-gate.json", false, (warning: string) => warnings.push(warning)),
              },
              (warning: string) => warnings.push(warning),
              { headless },
            );
            const matched = matcher.matchRules(command, rules);
            const blocked = matched.find((rule: { action: string }) => rule.action === "block");
            if (blocked) return { decision: "block", reason: blocked.reason ?? "Blocked", warnings };
            const prompted = matched.find((rule: { action: string }) => rule.action === "prompt");
            if (!prompted) return { decision: "allow", reason: "", warnings };
            return headless
              ? { decision: "block", reason: "Dangerous command blocked — no UI", warnings }
              : { decision: "prompt", reason: "", warnings };
          } catch (error) {
            return { decision: "block", reason: "rule evaluation failed: " + String(error), warnings };
          }
        }

        function processResult(stdout = "", code = 0, stderr = "") {
          return { stdout, stderr, code };
        }

        function jjOutputs(scenario: string) {
          const current = "change-a\tcommit-a\tfalse\ttrue\t2\n";
          const ordinary = [
            processResult("/repo\n"),
            processResult(current),
            processResult("commit-a\n"),
            processResult(""),
            processResult(""),
          ];
          const outside = processResult("", 1, 'Error: There is no jj repo in "."\n');
          switch (scenario) {
            case "ordinary-healthy": return ordinary;
            case "target-jj-cwd-other-repository": return [processResult("/target\n"), ...ordinary.slice(1)];
            case "ordinary-conflict": return [ordinary[0], processResult("change-a\tcommit-a\ttrue\tfalse\t1\n"), ...ordinary.slice(2)];
            case "ordinary-divergent-at": return [ordinary[0], ordinary[1], processResult("commit-a\ncommit-b\n"), ...ordinary.slice(3)];
            case "ordinary-main-at": return [ordinary[0], ordinary[1], ordinary[2], processResult("main\tcommit-a\n"), ordinary[4]];
            case "ordinary-master-at": return [ordinary[0], ordinary[1], ordinary[2], processResult("master\tcommit-a\n"), ordinary[4]];
            case "classification-whitespace-only": return [...ordinary.slice(0, 4), processResult(" \n")];
            case "classification-padded": return [...ordinary.slice(0, 4), processResult(" wip\tfalse\n")];
            case "classification-extra-blank": return [...ordinary.slice(0, 4), processResult("wip\tfalse\n\n")];
            case "root-padded": return [processResult(" /repo\n"), ...ordinary.slice(1)];
            case "current-extra-blank": return [ordinary[0], processResult(current + "\n"), ...ordinary.slice(2)];
            case "identity-padded": return [ordinary[0], ordinary[1], processResult(" commit-a\n"), ...ordinary.slice(3)];
            case "defaults-extra-blank": return [ordinary[0], ordinary[1], ordinary[2], processResult("\n"), ordinary[4]];
            case "resolution-padded": return [...ordinary.slice(0, 4), processResult("wip\tfalse\n"), processResult(" commit-a\tfalse\n"), processResult("parent-a\tfalse\nparent-b\tfalse\n")];
            case "parents-extra-blank": return [...ordinary.slice(0, 4), processResult("wip\tfalse\n"), processResult("commit-a\tfalse\n"), processResult("parent-a\tfalse\nparent-b\tfalse\n\n")];
            case "malformed-probe": return [ordinary[0], processResult("not-a-record\n")];
            case "malformed-parent-count-probe": return [ordinary[0], processResult("change-a\tcommit-a\tfalse\ttrue\t2x\n"), ...ordinary.slice(2)];
            case "failing-probe": return [ordinary[0], processResult("", 2, "probe failed")];
            case "ambiguous-probe": return [ordinary[0], processResult(current + "change-b\tcommit-b\tfalse\tfalse\t1\n")];
            case "failing-root-probe": return [processResult("", 1, "permission denied")];
            case "outside-jj-contradictory-stdout": return [processResult("/repo\n", 1, outside.stderr)];
            case "outside-jj-wrong-status": return [processResult("", 2, outside.stderr)];
            case "outside-jj-mixed-diagnostics": return [processResult("", 1, outside.stderr + "Hint: additional diagnostic\n")];
            case "canonical-root-mismatch": return [processResult("/other\n")];
            default: {
              let diamondCurrent = current;
              let classification = processResult("wip\tfalse\n");
              let resolution = processResult("commit-a\tfalse\n");
              let parents = processResult("parent-a\tfalse\nparent-b\tfalse\n");
              if (scenario === "diamond-missing-wip") resolution = processResult("");
              if (scenario === "diamond-moved-wip") resolution = processResult("commit-other\tfalse\n");
              if (scenario === "diamond-divergent-wip") {
                classification = processResult("wip\ttrue\n");
                resolution = processResult("commit-a\ttrue\ncommit-b\ttrue\n");
              }
              if (scenario === "diamond-divergent-wip-without-target") {
                classification = processResult("wip\ttrue\n");
                resolution = processResult("");
              }
              if (scenario === "diamond-divergent-wip-malformed-resolution") {
                classification = processResult("wip\ttrue\n");
                resolution = processResult("malformed-resolution\n");
              }
              if (scenario === "diamond-nonempty-join") diamondCurrent = "change-a\tcommit-a\tfalse\tfalse\t2\n";
              if (scenario === "diamond-single-parent-join") {
                diamondCurrent = "change-a\tcommit-a\tfalse\ttrue\t1\n";
                parents = processResult("parent-a\tfalse\n");
              }
              if (scenario === "diamond-conflicted-join") parents = processResult("parent-a\tfalse\nparent-b\ttrue\n");
              return [
                ordinary[0],
                processResult(diamondCurrent),
                ordinary[2],
                ordinary[3],
                classification,
                resolution,
                parents,
              ];
            }
          }
        }

        function fakeCapabilities(
          scenario: string,
          calls: string[][],
          jjCwds: string[],
          gitRootDirectories: string[] = [],
          gitHeadDirectories: string[] = [],
        ) {
          const gitScenario = scenario.startsWith("git-") || scenario === "target-git-cwd-jj-repository";
          const withoutJj = ["git-feature", "git-main", "immutable", "builtin-at-prefix", "outside-headless", "capability-throws"].includes(scenario) || (gitScenario && scenario !== "target-git-cwd-jj-repository");
          const jjOutside = processResult("", 1, 'Error: There is no jj repo in "."\n');
          const outputs = withoutJj ? [jjOutside] : jjOutputs(scenario);
          let jjIndex = 0;
          return {
            filesystem: {
              canonicalize: async (target: string) => {
                if (scenario === "capability-throws") throw new Error("filesystem unavailable");
                if (scenario === "immutable") return "/nix/store/abc";
                if (scenario === "builtin-at-prefix" && target.startsWith("@")) return "/repo/escaped-at-prefix";
                return target;
              },
              inspectionDirectory: async (target: string) => {
                if (target.startsWith("/target/")) return "/target";
                if (target.startsWith("/workspace/")) return "/workspace";
                return "/repo";
              },
              immutableRoots: async () => ["/nix/store", "/immutable"],
            },
            git: {
              root: async (directory: string) => {
                gitRootDirectories.push(directory);
                if (["git-feature", "git-main", "target-git-cwd-jj-repository"].includes(scenario) || gitScenario) {
                  return { kind: "inside", root: scenario === "target-git-cwd-jj-repository" ? "/target" : "/repo" };
                }
                return { kind: "outside" };
              },
              head: async (root: string) => {
                gitHeadDirectories.push(root);
                if (scenario === "git-main" || scenario === "git-protected-head") return processResult("main\n");
                if (scenario === "git-multiline-head") return processResult("main\nfeature/policy\n");
                if (scenario === "git-malformed-head") return processResult("feature branch\n");
                if (scenario === "git-detached-head") return processResult("", 1, "");
                return processResult("feature/policy\n");
              },
            },
            jj: {
              run: async (argv: string[], cwd: string) => {
                calls.push(argv);
                jjCwds.push(cwd);
                if (scenario === "target-jj-cwd-other-repository" && cwd !== "/target") {
                  return processResult("/cwd\n");
                }
                if (scenario === "target-git-cwd-jj-repository") {
                  return cwd === "/target" ? jjOutside : processResult("/cwd\n");
                }
                return outputs[jjIndex++] ?? processResult("", 99, "unexpected jj probe");
              },
            },
            interaction: {
              available: scenario !== "outside-headless",
              confirm: async () => true,
            },
          };
        }

        function check(name: string, actual: string, expected: string, reason: string, expectedReason?: string) {
          if (actual !== expected || (expectedReason !== undefined && !reason.includes(expectedReason))) {
            failures.push(name + ": expected " + expected + (expectedReason ? " containing " + JSON.stringify(expectedReason) : "") + ", got " + actual + " " + JSON.stringify(reason));
          }
        }

        for (const entry of cases) {
          try {
            if (entry.kind === "shell") {
              if (entry.custom && !hasPermissionPolicy) {
                failures.push(entry.name + ": missing permission-rules policy");
                continue;
              }
              const result = classify(entry.command, entry.custom ? customConfig : {}, {}, entry.headless === true);
              check(entry.name, result.decision, entry.expected, result.reason, entry.reason);
              continue;
            }
            if (entry.kind === "shell-error") {
              const configRoot = mkdtempSync(join(tmpdir(), "permission-gate-handler-"));
              const rulesDirectory = join(configRoot, "pi-agent-extensions", "permission-gate");
              mkdirSync(rulesDirectory, { recursive: true });
              writeFileSync(
                join(rulesDirectory, "rules.mjs"),
                'export default () => ({ extraRules: [{ label: "synthetic throwing rule", action: "prompt", test: () => { throw new Error("synthetic parser fault"); } }] });\n',
              );
              const previousConfigHome = process.env.XDG_CONFIG_HOME;
              const previousNoGate = process.env.PI_NO_GATE;
              process.env.XDG_CONFIG_HOME = configRoot;
              delete process.env.PI_NO_GATE;
              try {
                const handlers = new Map<string, Array<(event: unknown, context: unknown) => unknown>>();
                const pi = {
                  on: (name: string, handler: (event: unknown, context: unknown) => unknown) => {
                    const registered = handlers.get(name) ?? [];
                    registered.push(handler);
                    handlers.set(name, registered);
                  },
                  registerCommand: () => {},
                  events: { on: () => () => {}, emit: () => {} },
                };
                gateIndex.default(pi);
                const context = { hasUI: false, cwd: configRoot };
                for (const handler of handlers.get("session_start") ?? []) {
                  await handler({}, context);
                }
                let result: { block?: boolean; reason?: string } | undefined;
                for (const handler of handlers.get("tool_call") ?? []) {
                  result = await handler(
                    { toolName: "bash", input: { command: "printf safe" } },
                    context,
                  ) as { block?: boolean; reason?: string } | undefined;
                }
                check(
                  entry.name,
                  result?.block === true ? "block" : "allow",
                  entry.expected,
                  result?.reason ?? "",
                  entry.reason,
                );
              } finally {
                if (previousConfigHome === undefined) delete process.env.XDG_CONFIG_HOME;
                else process.env.XDG_CONFIG_HOME = previousConfigHome;
                if (previousNoGate === undefined) delete process.env.PI_NO_GATE;
                else process.env.PI_NO_GATE = previousNoGate;
                rmSync(configRoot, { recursive: true, force: true });
              }
              continue;
            }
            if (entry.kind === "project") {
              const result = classify(entry.command, {}, entry.project, entry.headless === true);
              check(entry.name, result.decision, entry.expected, result.reason);
              if (!result.warnings.some((warning: string) => warning.includes(entry.warning))) {
                failures.push(entry.name + ": expected warning containing " + JSON.stringify(entry.warning) + ", got " + JSON.stringify(result.warnings));
              }
              continue;
            }
            if (!hasEditPolicy) {
              failures.push(entry.name + ": missing edit-write policy");
              continue;
            }
            if (entry.kind === "git-root") {
              if (typeof editModule.parseGitRootResult !== "function") {
                failures.push(entry.name + ": missing Git root result parser");
                continue;
              }
              const result = editModule.parseGitRootResult(entry.result);
              check(
                entry.name,
                result.kind,
                entry.expected,
                result.kind === "invalid" ? result.diagnostic : "",
                entry.reason,
              );
              continue;
            }
            if (entry.kind === "core") {
              const result = editModule.decideEditWrite(entry.input);
              check(entry.name, result.decision, entry.expected, result.reason ?? "", entry.reason);
              continue;
            }
            if (entry.kind === "repository") {
              const calls: string[][] = [];
              const jjCwds: string[] = [];
              const gitRootDirectories: string[] = [];
              const gitHeadDirectories: string[] = [];
              const capabilities = fakeCapabilities(
                entry.scenario,
                calls,
                jjCwds,
                gitRootDirectories,
                gitHeadDirectories,
              );
              const target = entry.target ?? "/repo/file.ts";
              const cwd = entry.cwd ?? "/repo";
              const input = await editModule.evaluateEditWrite("edit", target, cwd, capabilities);
              check(entry.name, input.decision, entry.expected, input.reason ?? "", entry.reason);
              for (const argv of calls) {
                if (argv[0] !== "jj" || argv[1] !== "--ignore-working-copy") {
                  failures.push(entry.name + ": jj argv does not start with jj --ignore-working-copy: " + JSON.stringify(argv));
                }
              }
              if (entry.expectedJjCalls !== null && calls.length !== entry.expectedJjCalls) {
                failures.push(entry.name + ": expected " + entry.expectedJjCalls + " jj probes, got " + calls.length);
              }
              if (entry.expectedProbeCwd !== undefined && jjCwds.some((probeCwd) => probeCwd !== entry.expectedProbeCwd)) {
                failures.push(entry.name + ": expected every jj probe cwd to be " + JSON.stringify(entry.expectedProbeCwd) + ", got " + JSON.stringify(jjCwds));
              }
              if (
                entry.expectedGitRootDirectory !== undefined &&
                (gitRootDirectories.length !== 1 || gitRootDirectories[0] !== entry.expectedGitRootDirectory)
              ) {
                failures.push(entry.name + ": expected Git root probe directory " + JSON.stringify(entry.expectedGitRootDirectory) + ", got " + JSON.stringify(gitRootDirectories));
              }
              if (
                entry.expectedGitHeadDirectory !== undefined &&
                (gitHeadDirectories.length !== 1 || gitHeadDirectories[0] !== entry.expectedGitHeadDirectory)
              ) {
                failures.push(entry.name + ": expected Git head probe directory " + JSON.stringify(entry.expectedGitHeadDirectory) + ", got " + JSON.stringify(gitHeadDirectories));
              }
              continue;
            }
            if (entry.kind === "adapter") {
              if (entry.scenario === "registration") {
                const registrations: Array<{ event: string; handler: unknown }> = [];
                editModule.default({
                  on: (event: string, handler: unknown) => registrations.push({ event, handler }),
                });
                const valid = registrations.length === 1
                  && registrations[0].event === "tool_call"
                  && typeof registrations[0].handler === "function";
                check(entry.name, valid ? "pass" : "block", entry.expected, JSON.stringify(registrations));
                continue;
              }
              const calls: string[][] = [];
              const capabilities = fakeCapabilities(entry.scenario, calls, []);
              const options = entry.scenario === "core-throws"
                ? { decide: () => { throw new Error("synthetic core fault"); } }
                : {};
              const handler = editModule.createEditWriteToolCallHandler(() => capabilities, options);
              const context = {
                cwd: "/repo",
                hasUI: entry.scenario !== "outside-headless",
                ui: { confirm: async () => true },
              };
              const result = await handler({ toolName: entry.tool, toolCallId: "call-1", input: entry.input }, context);
              const actual = result?.block === true ? "block" : "pass";
              check(entry.name, actual, entry.expected, result?.reason ?? "", entry.reason);
            }
          } catch (error) {
            failures.push(entry.name + ": uncaught exception: " + String(error));
          }
        }

        if (failures.length > 0) {
          for (const failure of failures) console.error("FAIL: " + failure);
          console.error(failures.length + " pi-agent-environment policy case(s) failed");
          process.exit(1);
        }
        for (const entry of cases) console.log("PASS: " + entry.name);
        console.log(cases.length + " pi-agent-environment policy cases passed");
      '';
    in
    {
      checks = {
        pi-agent-environment-structural = mkCheck {
          name = "pi-agent-environment";
          actual = {
            piPackageVersion = lib.getVersion piConfig.package;
            extensionPackagePresent = extensionPackage != null;
            extensionPackageName = if extensionPackage == null then null else lib.getName extensionPackage;
            inherit positiveExtensions negativeExtensions;
            packageSkills = if extensionEntry == null then [ ] else extensionEntry.skills or [ ];
            packagePrompts = if extensionEntry == null then [ ] else extensionEntry.prompts or [ ];
            packageThemes = if extensionEntry == null then [ ] else extensionEntry.themes or [ ];
            extraPackages = map lib.getName piConfig.extraPackages;
            compactionRetained = lib.any (
              entry: !builtins.isAttrs entry && lib.hasInfix "pi-openai-server-compaction" (toString entry)
            ) packageEntries;
            inherit globalInstructionsNixOwned piSpecificSkillsPresent;
            canonicalSkills = if canonicalSkillsScript == "" then null else "~/.agents/skills";
            settingsActivation = {
              afterWriteBoundary = builtins.elem "writeBoundary" (settingsActivation.after or [ ]);
              copyCommand = lib.hasInfix "install -Dm644" settingsActivationData;
              immutableHomeFileEnabled = homeFileEnabled settingsTarget;
              target =
                if lib.hasInfix settingsTarget settingsActivationData then "~/.pi/agent/settings.json" else null;
            };
            inherit runtimeStateOutsideImmutableLinks;
            immutableResourceTargets = {
              policy = immutablePolicyTargets;
              theme =
                if homeFileImmutable themeTarget then [ "~/.pi/agent/themes/catppuccin-mocha.json" ] else [ ];
              extensions = immutableExtensionTargets;
              globalInstructions = if globalInstructionsNixOwned then [ "~/.pi/agent/AGENTS.md" ] else [ ];
            };
            contextNixOwned = piConfig.context == homeConfig.programs.agents-md.settings.text;
            theme = {
              contentName = themeJson.name or null;
              selected = piConfig.settings.theme or null;
              target =
                if homeFileAt themeTarget == null then null else "~/.pi/agent/themes/catppuccin-mocha.json";
              targetImmutable = homeFileImmutable themeTarget;
              sha256 = if themePresent then builtins.hashFile "sha256" themePath else null;
              standalonePackagePresent = lib.any (name: lib.hasInfix "catppuccin-mocha" name) (
                builtins.attrNames self'.packages
              );
            };
          };
          expected = {
            piPackageVersion = "0.84.1";
            extensionPackagePresent = true;
            extensionPackageName = "pi-agent-extensions";
            positiveExtensions = [
              "direnv/index.ts"
              "permission-gate/index.ts"
              "questionnaire/index.ts"
              "slow-mode/index.ts"
              "stash/index.ts"
              "statusline/index.ts"
            ];
            negativeExtensions = [
              "-fetch/index.ts"
              "-notify/index.ts"
            ];
            packageSkills = [ ];
            packagePrompts = [ ];
            packageThemes = [ ];
            extraPackages = [
              "direnv"
              "diffutils"
              "git"
              "jujutsu"
              "rip2"
            ];
            compactionRetained = true;
            globalInstructionsNixOwned = true;
            canonicalSkills = "~/.agents/skills";
            piSpecificSkillsPresent = false;
            settingsActivation = {
              afterWriteBoundary = true;
              copyCommand = true;
              immutableHomeFileEnabled = false;
              target = "~/.pi/agent/settings.json";
            };
            runtimeStateOutsideImmutableLinks = [
              "settings"
              "sessions"
              "compaction"
              "authentication"
              "project-trust"
              "model-selection"
              "thinking-preferences"
              "extension-state"
            ];
            immutableResourceTargets = {
              policy = [
                "pi-agent-extensions/permission-gate/index.ts"
                "~/.config/pi-agent-extensions/permission-gate/rules.ts"
                "~/.pi/agent/extensions/edit-write-policy.ts"
              ];
              theme = [ "~/.pi/agent/themes/catppuccin-mocha.json" ];
              extensions = [
                "pi-agent-extensions/direnv/index.ts"
                "pi-agent-extensions/permission-gate/index.ts"
                "pi-agent-extensions/questionnaire/index.ts"
                "pi-agent-extensions/slow-mode/index.ts"
                "pi-agent-extensions/stash/index.ts"
                "pi-agent-extensions/statusline/index.ts"
              ];
              globalInstructions = [ "~/.pi/agent/AGENTS.md" ];
            };
            contextNixOwned = true;
            theme = {
              contentName = "catppuccin-mocha";
              selected = "catppuccin-mocha";
              target = "~/.pi/agent/themes/catppuccin-mocha.json";
              targetImmutable = true;
              sha256 = "5858d086e155246d48e5b7a2ac372988fe2d1a028d2b77b5f0a7670088a8642b";
              standalonePackagePresent = false;
            };
          };
        };

        pi-agent-environment-policy =
          pkgs.runCommand "pi-agent-environment-policy"
            {
              nativeBuildInputs = [
                pkgs.bun
                pkgs.typescript
              ];
              BUN_CONFIG_NO_INSTALL = "1";
              PERMISSION_GATE_ROOT = "${extensionPackage}/permission-gate";
              PERMISSION_RULES_MODULE = permissionRulesModule;
              EDIT_WRITE_POLICY_MODULE = editWritePolicyModule;
              POLICY_CASES = policyCases;
              POLICY_HARNESS = policyHarness;
              POLICY_TYPE_DECLARATIONS = policyTypeDeclarations;
              POLICY_TSCONFIG = policyTsconfig;
            }
            ''
              set -o pipefail
              mkdir typecheck
              ln -s "$PERMISSION_GATE_ROOT" typecheck/permission-gate
              ln -s "$PERMISSION_RULES_MODULE" typecheck/permission-rules.ts
              ln -s "$EDIT_WRITE_POLICY_MODULE" typecheck/edit-write-policy.ts
              ln -s "$POLICY_TYPE_DECLARATIONS" typecheck/external.d.ts
              ln -s "$POLICY_TSCONFIG" typecheck/tsconfig.json
              tsc -p typecheck/tsconfig.json
              bun "$POLICY_HARNESS"
              touch "$out"
            '';

        pi-agent-environment-smoke = pkgs.runCommand "pi-agent-environment-smoke-scaffold" { } ''
          printf '%s\n' 'scaffold only: smoke behavior is assigned to Plan Task 4' > "$out"
        '';
      };
    };
}
