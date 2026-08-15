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
      settingsActivationLines = builtins.filter (line: line != "") (
        lib.splitString "\n" settingsActivationData
      );
      settingsActivationMatch =
        if builtins.length settingsActivationLines == 1 then
          builtins.match "[$]DRY_RUN_CMD install -Dm644 (/nix/store/[^ ]+) ([^ ]+)" (
            builtins.head settingsActivationLines
          )
        else
          null;
      settingsSource =
        if
          settingsActivationMatch != null && builtins.elemAt settingsActivationMatch 1 == settingsTarget
        then
          builtins.elemAt settingsActivationMatch 0
        else
          throw "pi-agent-environment-smoke: expected one exact mutable-settings install source and target";
      deployedPiCandidates = builtins.filter (
        package: (package.meta.mainProgram or null) == "pi" && lib.getVersion package == "0.84.1"
      ) homeConfig.home.packages;
      deployedPiPackage =
        if builtins.length deployedPiCandidates == 1 then
          builtins.head deployedPiCandidates
        else
          throw "pi-agent-environment-smoke: expected one deployed Home Manager Pi main program at version 0.84.1";
      deployedPiExecutable =
        if toString deployedPiPackage != toString piConfig.package then
          lib.getExe deployedPiPackage
        else
          throw "pi-agent-environment-smoke: deployed Pi must be the Home Manager outer wrapper";
      skillsActivation = lib.attrByPath [ "agentsSkillsRealFiles" ] { } homeConfig.home.activation;
      skillsActivationData = skillsActivation.data or "";
      skillsActivationLines = builtins.filter (line: line != "") (
        lib.splitString "\n" skillsActivationData
      );
      skillsCopyMatch =
        if
          builtins.length skillsActivationLines == 3
          && builtins.elemAt skillsActivationLines 0 == ''$DRY_RUN_CMD rm -rf "$HOME/.agents/skills"''
          && builtins.elemAt skillsActivationLines 1 == ''$DRY_RUN_CMD install -d "$HOME/.agents/skills"''
        then
          builtins.match ''[$]DRY_RUN_CMD cp -RL --no-preserve=mode (/nix/store/[^ ]+)/[.] "[$]HOME/[.]agents/skills/"'' (
            builtins.elemAt skillsActivationLines 2
          )
        else
          null;
      skillsSource =
        if skillsCopyMatch != null then
          builtins.elemAt skillsCopyMatch 0
        else
          throw "pi-agent-environment-smoke: expected one exact canonical skills copy source";
      requiredHomeFileSource =
        target:
        let
          file = homeFileAt target;
        in
        if
          file != null
          && file.enable
          && file.source != null
          && lib.hasPrefix builtins.storeDir (toString file.source)
        then
          file.source
        else
          throw "pi-agent-environment-smoke: missing immutable Home Manager resource at ${target}";
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
      jjArgvOracle = {
        root = [
          "jj"
          "--ignore-working-copy"
          "root"
        ];
        current = [
          "jj"
          "--ignore-working-copy"
          "log"
          "-r"
          "@"
          "--no-graph"
          "-T"
          ''change_id ++ "\t" ++ commit_id ++ "\t" ++ conflict ++ "\t" ++ empty ++ "\t" ++ parents.len() ++ "\n"''
        ];
        currentIdentity = [
          "jj"
          "--ignore-working-copy"
          "log"
          "-r"
          "change-a"
          "--no-graph"
          "-T"
          ''commit_id ++ "\n"''
        ];
        defaultBookmarks = [
          "jj"
          "--ignore-working-copy"
          "bookmark"
          "list"
          "exact:main"
          "exact:master"
          "-T"
          ''if(!remote, added_targets.map(|c| name ++ "\t" ++ c.commit_id() ++ "\n").join(""))''
        ];
        classifyWip = [
          "jj"
          "--ignore-working-copy"
          "bookmark"
          "list"
          "exact:wip"
          "-T"
          ''if(!remote, name ++ "\t" ++ conflict ++ "\n")''
        ];
        resolveWip = [
          "jj"
          "--ignore-working-copy"
          "bookmark"
          "list"
          "exact:wip"
          "-T"
          ''if(!remote, added_targets.map(|c| c.commit_id() ++ "\t" ++ conflict ++ "\n").join(""))''
        ];
        join = [
          "jj"
          "--ignore-working-copy"
          "log"
          "-r"
          "@-"
          "--no-graph"
          "-T"
          ''commit_id ++ "\t" ++ conflict ++ "\t" ++ empty ++ "\t" ++ parents.len() ++ "\n"''
        ];
        parents = [
          "jj"
          "--ignore-working-copy"
          "log"
          "-r"
          "parents(@-)"
          "--no-graph"
          "-T"
          ''commit_id ++ "\t" ++ conflict ++ "\n"''
        ];
      };
      expectedJjArgvByScenario =
        let
          inherit (jjArgvOracle)
            classifyWip
            current
            currentIdentity
            defaultBookmarks
            join
            parents
            resolveWip
            root
            ;
        in
        {
          "ordinary-healthy" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
          ];
          "ordinary-nonempty-at" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
          ];
          "ordinary-conflict" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
          ];
          "ordinary-divergent-at" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
          ];
          "ordinary-main-at" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
          ];
          "ordinary-master-at" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
          ];
          "diamond-healthy" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
            parents
          ];
          "diamond-nonempty-wip" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
            parents
          ];
          "diamond-resolved-nonempty-join" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
            parents
          ];
          "diamond-missing-wip" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
            parents
          ];
          "diamond-moved-wip" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
            parents
          ];
          "diamond-divergent-wip" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
            parents
          ];
          "diamond-divergent-wip-without-target" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
            parents
          ];
          "diamond-divergent-wip-malformed-resolution" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
          ];
          "diamond-nonsingle-parent-wip" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
            parents
          ];
          "diamond-single-parent-join" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
            parents
          ];
          "diamond-conflicted-join" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
            parents
          ];
          "diamond-conflicted-immediate-parent" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
            parents
          ];
          "diamond-join-parent-count-mismatch" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
            parents
          ];
          "diamond-malformed-join-probe" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
          ];
          "diamond-failing-join-probe" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
          ];
          "malformed-probe" = [
            root
            current
          ];
          "malformed-parent-count-probe" = [
            root
            current
          ];
          "failing-probe" = [
            root
            current
          ];
          "ambiguous-probe" = [
            root
            current
          ];
          "failing-root-probe" = [ root ];
          "outside-jj-contradictory-stdout" = [ root ];
          "outside-jj-wrong-status" = [ root ];
          "outside-jj-mixed-diagnostics" = [ root ];
          "classification-whitespace-only" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
          ];
          "classification-padded" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
          ];
          "classification-extra-blank" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
          ];
          "root-padded" = [ root ];
          "current-extra-blank" = [
            root
            current
          ];
          "identity-padded" = [
            root
            current
            currentIdentity
          ];
          "defaults-extra-blank" = [
            root
            current
            currentIdentity
            defaultBookmarks
          ];
          "resolution-padded" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
          ];
          "parents-extra-blank" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
            resolveWip
            join
            parents
          ];
          "canonical-root-mismatch" = [ root ];
          "target-jj-cwd-other-repository" = [
            root
            current
            currentIdentity
            defaultBookmarks
            classifyWip
          ];
          "target-git-cwd-jj-repository" = [ root ];
          "git-protected-head" = [ root ];
          "git-feature-head" = [ root ];
          "git-detached-head" = [ root ];
          "git-malformed-head" = [ root ];
          "git-multiline-head" = [ root ];
        };
      repositoryScenarios = [
        "ordinary-healthy"
        "ordinary-nonempty-at"
        "ordinary-conflict"
        "ordinary-divergent-at"
        "ordinary-main-at"
        "ordinary-master-at"
        "diamond-healthy"
        "diamond-nonempty-wip"
        "diamond-resolved-nonempty-join"
        "diamond-missing-wip"
        "diamond-moved-wip"
        "diamond-divergent-wip"
        "diamond-divergent-wip-without-target"
        "diamond-divergent-wip-malformed-resolution"
        "diamond-nonsingle-parent-wip"
        "diamond-single-parent-join"
        "diamond-conflicted-join"
        "diamond-conflicted-immediate-parent"
        "diamond-join-parent-count-mismatch"
        "diamond-malformed-join-probe"
        "diamond-failing-join-probe"
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
                "ordinary-nonempty-at"
                "target-jj-cwd-other-repository"
                "target-git-cwd-jj-repository"
                "git-feature-head"
                "git-detached-head"
                "diamond-healthy"
                "diamond-nonempty-wip"
                "diamond-resolved-nonempty-join"
              ]
            then
              "allow"
            else
              "block";
          expectedJjArgv = expectedJjArgvByScenario.${scenario} or null;
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
          const diamondCurrent = "change-a\tcommit-a\tfalse\ttrue\t1\n";
          const diamondJoin = "commit-join\tfalse\ttrue\t6\n";
          const diamondParents = Array.from(
            { length: 6 },
            (_, index) => `parent-''${index + 1}\tfalse\n`,
          ).join("");
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
            case "ordinary-nonempty-at": return [ordinary[0], processResult("change-a\tcommit-a\tfalse\tfalse\t1\n"), ...ordinary.slice(2)];
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
            case "parents-extra-blank": return [...ordinary.slice(0, 4), processResult("wip\tfalse\n"), processResult("commit-a\tfalse\n"), processResult(diamondJoin), processResult(diamondParents + "\n")];
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
              let currentProbe = diamondCurrent;
              let classification = processResult("wip\tfalse\n");
              let resolution = processResult("commit-a\tfalse\n");
              let joinProbe = processResult(diamondJoin);
              let parents = processResult(diamondParents);
              if (scenario === "diamond-nonempty-wip") {
                currentProbe = "change-a\tcommit-a\tfalse\tfalse\t1\n";
              }
              if (scenario === "diamond-resolved-nonempty-join") {
                joinProbe = processResult("commit-join\tfalse\tfalse\t6\n");
              }
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
              if (scenario === "diamond-nonsingle-parent-wip") {
                currentProbe = "change-a\tcommit-a\tfalse\ttrue\t2\n";
              }
              if (scenario === "diamond-single-parent-join") {
                joinProbe = processResult("commit-join\tfalse\ttrue\t1\n");
                parents = processResult("parent-1\tfalse\n");
              }
              if (scenario === "diamond-conflicted-join") {
                joinProbe = processResult("commit-join\ttrue\tfalse\t6\n");
              }
              if (scenario === "diamond-conflicted-immediate-parent") {
                parents = processResult(diamondParents.replace("parent-6\tfalse", "parent-6\ttrue"));
              }
              if (scenario === "diamond-join-parent-count-mismatch") {
                parents = processResult(diamondParents.replace("parent-6\tfalse\n", ""));
              }
              if (scenario === "diamond-malformed-join-probe") {
                joinProbe = processResult("not-a-join-record\n");
              }
              if (scenario === "diamond-failing-join-probe") {
                joinProbe = processResult("", 2, "join probe failed");
              }
              return [
                ordinary[0],
                processResult(currentProbe),
                ordinary[2],
                ordinary[3],
                classification,
                resolution,
                joinProbe,
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
              if (calls.length > 0 && entry.expectedJjArgv == null) {
                failures.push(entry.name + ": jj-invoking repository scenario lacks an exact argv oracle");
              } else if (
                entry.expectedJjArgv !== null &&
                JSON.stringify(calls) !== JSON.stringify(entry.expectedJjArgv)
              ) {
                failures.push(
                  entry.name + ": expected exact jj argv " + JSON.stringify(entry.expectedJjArgv) +
                  ", got " + JSON.stringify(calls),
                );
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

        pi-agent-environment-smoke =
          let
            contextSource = requiredHomeFileSource contextTarget;
            themeSource = requiredHomeFileSource themeTarget;
            editWritePolicySource = requiredHomeFileSource editWritePolicyTarget;
            permissionRulesSource = requiredHomeFileSource permissionRulesTarget;
            resourceLinks = [
              {
                destination = ".pi/agent/AGENTS.md";
                sourceVariable = "CONTEXT_SOURCE";
              }
              {
                destination = ".pi/agent/themes/catppuccin-mocha.json";
                sourceVariable = "THEME_SOURCE";
              }
              {
                destination = ".pi/agent/extensions/edit-write-policy.ts";
                sourceVariable = "EDIT_WRITE_POLICY_SOURCE";
              }
              {
                destination = ".config/pi-agent-extensions/permission-gate/rules.ts";
                sourceVariable = "PERMISSION_RULES_SOURCE";
              }
            ];
            packageResourceSources = map (
              entry: if builtins.isAttrs entry then toString entry.source else toString entry
            ) packageEntries;
            piModuleSource = builtins.path {
              path = ../home/ai/pi/default.nix;
              name = "pi-home-module.nix";
            };
            sentinelScanRoots = [
              piModuleSource
              settingsSource
              skillsSource
            ]
            ++ packageResourceSources;
            runtimeIndirection =
              if builtins.elem "direnv/index.ts" positiveExtensions then
                "direnv/index.ts"
              else
                throw "pi-agent-environment-smoke: direnv runtime indirection is not configured";
            smokeDriver = pkgs.writeText "pi-agent-environment-smoke-driver.py" ''
              import json
              import os
              from pathlib import Path
              import secrets
              import signal
              import subprocess

              def reject_json_constant(value):
                  raise ValueError(f"non-finite JSON constant: {value}")


              def reject_duplicate_keys(pairs):
                  result = {}
                  for key, value in pairs:
                      if key in result:
                          raise ValueError(f"duplicate JSON key: {key}")
                      result[key] = value
                  return result


              def strict_json_loads(text):
                  return json.loads(
                      text,
                      parse_constant=reject_json_constant,
                      object_pairs_hook=reject_duplicate_keys,
                  )


              def expect_rejected(name, operation):
                  try:
                      operation()
                  except (AssertionError, TypeError, ValueError):
                      return
                  raise AssertionError(f"mutation unexpectedly accepted: {name}")


              def validate_settings_text(settings_text, expected_text):
                  settings = strict_json_loads(settings_text)
                  expected = strict_json_loads(expected_text)
                  if not isinstance(settings, dict) or settings != expected:
                      raise AssertionError("copied settings differ from evaluated settings")
                  if settings.get("theme") != "catppuccin-mocha":
                      raise AssertionError("copied settings select the wrong theme")
                  packages = settings.get("packages")
                  expected_packages = expected.get("packages")
                  if not isinstance(packages, list) or len(packages) != 2:
                      raise AssertionError("copied settings require exactly two package entries")
                  if packages != expected_packages:
                      raise AssertionError("copied settings package entries differ from evaluated entries")
                  extension = packages[0]
                  compaction = packages[1]
                  if not isinstance(extension, dict) or not isinstance(extension.get("source"), str):
                      raise AssertionError("copied settings extension package reference is malformed")
                  if not isinstance(compaction, str) or not compaction:
                      raise AssertionError("copied settings compaction package reference is malformed")
                  expected_extensions = [
                      "direnv/index.ts",
                      "permission-gate/index.ts",
                      "questionnaire/index.ts",
                      "slow-mode/index.ts",
                      "stash/index.ts",
                      "statusline/index.ts",
                      "-fetch/index.ts",
                      "-notify/index.ts",
                  ]
                  if extension.get("extensions") != expected_extensions:
                      raise AssertionError("copied settings extension references differ")
                  if len(set(extension["extensions"])) != len(extension["extensions"]):
                      raise AssertionError("copied settings extension references contain duplicates")
                  for empty_resource_kind in ("skills", "prompts", "themes"):
                      if extension.get(empty_resource_kind) != []:
                          raise AssertionError(
                              f"copied settings unexpectedly select package {empty_resource_kind}"
                          )
                  references = [extension["source"], compaction]
                  if len(set(references)) != 2:
                      raise AssertionError("copied settings contain duplicate package references")
                  return settings


              def validate_resource_links(resource_links):
                  expected = [
                      {"destination": ".pi/agent/AGENTS.md", "sourceVariable": "CONTEXT_SOURCE"},
                      {
                          "destination": ".pi/agent/themes/catppuccin-mocha.json",
                          "sourceVariable": "THEME_SOURCE",
                      },
                      {
                          "destination": ".pi/agent/extensions/edit-write-policy.ts",
                          "sourceVariable": "EDIT_WRITE_POLICY_SOURCE",
                      },
                      {
                          "destination": ".config/pi-agent-extensions/permission-gate/rules.ts",
                          "sourceVariable": "PERMISSION_RULES_SOURCE",
                      },
                  ]
                  if resource_links != expected:
                      raise AssertionError("aggregate immutable resource references differ")
                  destinations = [entry["destination"] for entry in resource_links]
                  variables = [entry["sourceVariable"] for entry in resource_links]
                  if len(set(destinations)) != len(destinations) or len(set(variables)) != len(variables):
                      raise AssertionError("aggregate immutable resource references contain duplicates")
                  return resource_links


              def validate_scan_roots(scan_roots):
                  root_strings = [str(root) for root in scan_roots]
                  if len(root_strings) != len(set(root_strings)):
                      raise AssertionError("sentinel scan roots contain duplicates")
                  for root in scan_roots:
                      parts = root.parts
                      if len(parts) >= 3 and parts[-3:] == (
                          "modules",
                          "checks",
                          "pi-agent-environment.nix",
                      ):
                          raise AssertionError("shared Pi check module entered the smoke scan roots")
                  return scan_roots


              def validate_extension_ui_record(record, seen_ids):
                  request_id = record.get("id")
                  if not isinstance(request_id, str) or not request_id:
                      raise AssertionError("extension UI request id must be nonempty")
                  if request_id in seen_ids:
                      raise AssertionError(f"duplicate extension UI request id: {request_id}")
                  seen_ids.add(request_id)
                  if record.get("method") != "setStatus":
                      raise AssertionError(f"unexpected extension UI method: {record}")
                  status_key = record.get("statusKey")
                  clear_shape = {"type", "id", "method", "statusKey"}
                  gate_shape = clear_shape | {"statusText"}
                  if status_key == "gate":
                      expected_text = "\x1b[38;5;103m\uf132 gate\x1b[39m"
                      if set(record) != gate_shape or record.get("statusText") != expected_text:
                          raise AssertionError(f"unexpected permission-gate status shape: {record}")
                      return
                  if status_key in {"direnv", "stash"} and set(record) == clear_shape:
                      return
                  raise AssertionError(f"unexpected non-benign status record: {record}")


              def validate_command_rows(commands):
                  if not isinstance(commands, list):
                      raise AssertionError("get_commands data is not a list")
                  by_name = {}
                  allowed_keys = {"name", "description", "source", "sourceInfo"}
                  source_info_keys = {"path", "source", "scope", "origin", "baseDir"}
                  required_source_info_keys = {"path", "source", "scope", "origin"}
                  for index, command in enumerate(commands):
                      if not isinstance(command, dict):
                          raise AssertionError(f"get_commands row {index} is not an object")
                      if not {"name", "source", "sourceInfo"}.issubset(command) or not set(
                          command
                      ).issubset(allowed_keys):
                          raise AssertionError(f"get_commands row {index} has an invalid shape: {command}")
                      name = command["name"]
                      source = command["source"]
                      source_info = command["sourceInfo"]
                      if not isinstance(name, str) or not name:
                          raise AssertionError(f"get_commands row {index} has an invalid name")
                      if name in by_name:
                          raise AssertionError(f"get_commands contains duplicate command name: {name}")
                      if source not in {"extension", "prompt", "skill"}:
                          raise AssertionError(f"get_commands row {index} has an invalid source")
                      if "description" in command and not isinstance(command["description"], str):
                          raise AssertionError(f"get_commands row {index} has an invalid description")
                      if not isinstance(source_info, dict) or not required_source_info_keys.issubset(
                          source_info
                      ) or not set(source_info).issubset(source_info_keys):
                          raise AssertionError(
                              f"get_commands row {index} has invalid sourceInfo: {source_info}"
                          )
                      if any(
                          not isinstance(source_info[key], str) or not source_info[key]
                          for key in ("path", "source")
                      ):
                          raise AssertionError(
                              f"get_commands row {index} has empty sourceInfo paths: {source_info}"
                          )
                      if source_info["scope"] not in {"user", "project", "temporary"}:
                          raise AssertionError(
                              f"get_commands row {index} has invalid sourceInfo scope: {source_info}"
                          )
                      if source_info["origin"] not in {"package", "top-level"}:
                          raise AssertionError(
                              f"get_commands row {index} has invalid sourceInfo origin: {source_info}"
                          )
                      if "baseDir" in source_info and (
                          not isinstance(source_info["baseDir"], str) or not source_info["baseDir"]
                      ):
                          raise AssertionError(
                              f"get_commands row {index} has invalid sourceInfo baseDir: {source_info}"
                          )
                      by_name[name] = command
                  return by_name


              def validate_response_rows(responses, requests):
                  if len(responses) != len(requests):
                      raise AssertionError(f"unexpected RPC response count: {responses}")
                  expected_shape = {"id", "type", "command", "success", "data"}
                  for response in responses:
                      if not isinstance(response, dict) or set(response) != expected_shape:
                          raise AssertionError(f"RPC response has an unexpected shape: {response}")
                      if response.get("type") != "response":
                          raise AssertionError(f"RPC response has an invalid type: {response}")
                      if not isinstance(response.get("id"), str) or not response["id"]:
                          raise AssertionError(f"RPC response has an invalid id: {response}")
                      if response.get("success") is not True:
                          raise AssertionError(f"failed RPC response: {response}")
                  response_ids = [response["id"] for response in responses]
                  expected_ids = [request["id"] for request in requests]
                  if response_ids != expected_ids or len(set(response_ids)) != len(response_ids):
                      raise AssertionError(
                          f"responses are not uniquely correlated in request order: {responses}"
                      )
                  response_by_id = {response["id"]: response for response in responses}
                  for request in requests:
                      response = response_by_id[request["id"]]
                      if response.get("command") != request["type"]:
                          raise AssertionError(f"missing correlated response for {request}")
                  return response_by_id


              def validate_no_session_state(state):
                  if not isinstance(state, dict):
                      raise AssertionError("get_state data is not an object")
                  if state.get("sessionFile") is not None:
                      raise AssertionError(f"--no-session returned a session file: {state['sessionFile']}")
                  return state


              def reject_session_jsonl(paths):
                  if paths:
                      raise AssertionError(f"--no-session created JSONL files: {[str(path) for path in paths]}")


              def signal_group(pid, group_signal):
                  try:
                      os.killpg(pid, group_signal)
                  except ProcessLookupError:
                      pass


              def cleanup_process_group(
                  process,
                  terminate_timeout=2,
                  kill_timeout=2,
                  group_signaler=signal_group,
              ):
                  group_signaler(process.pid, signal.SIGTERM)
                  try:
                      return process.communicate(timeout=terminate_timeout), "terminated"
                  except subprocess.TimeoutExpired:
                      group_signaler(process.pid, signal.SIGKILL)
                      try:
                          return process.communicate(timeout=kill_timeout), "killed"
                      except subprocess.TimeoutExpired as error:
                          raise AssertionError(
                              "Pi process group retained pipes after bounded SIGKILL cleanup"
                          ) from error


              def communicate_with_cleanup(process, timeout=20):
                  try:
                      return process.communicate(timeout=timeout)
                  except subprocess.TimeoutExpired as error:
                      _, cleanup_method = cleanup_process_group(process)
                      raise AssertionError(
                          f"Pi did not exit within {timeout} seconds after stdin closure; "
                          f"process group cleanup={cleanup_method}"
                      ) from error


              def launch_pi(argv, project_dir, launch_env):
                  return subprocess.Popen(
                      argv,
                      cwd=project_dir,
                      env=launch_env,
                      stdin=subprocess.PIPE,
                      stdout=subprocess.PIPE,
                      stderr=subprocess.PIPE,
                      start_new_session=True,
                  )


              class CleanupProbe:
                  pid = 4242

                  def __init__(self, outcomes):
                      self.outcomes = list(outcomes)
                      self.timeouts = []

                  def communicate(self, timeout):
                      self.timeouts.append(timeout)
                      outcome = self.outcomes.pop(0)
                      if outcome == "timeout":
                          raise subprocess.TimeoutExpired("pi", timeout)
                      return b"", b""


              requests = [
                  {"id": "state-1", "type": "get_state"},
                  {"id": "commands-1", "type": "get_commands"},
              ]
              expected_request_types = ["get_state", "get_commands"]
              if [request["type"] for request in requests] != expected_request_types:
                  raise AssertionError("provider-triggering request entered the request stream")

              home = Path(os.environ["SMOKE_HOME"])
              agent_dir = home / ".pi" / "agent"
              project_dir = Path(os.environ["SMOKE_PROJECT"])
              settings_path = agent_dir / "settings.json"
              settings_source = Path(os.environ["SETTINGS_SOURCE"])
              models_path = agent_dir / "models.json"

              expected_settings_text = os.environ["EXPECTED_SETTINGS_JSON"]
              if settings_path.is_symlink() or not os.access(settings_path, os.W_OK):
                  raise AssertionError("generated settings are not one writable copied file")
              if settings_path.read_bytes() != settings_source.read_bytes():
                  raise AssertionError("copied generated settings differ before launch")
              settings_files = sorted(home.rglob("settings.json"))
              if settings_files != [settings_path]:
                  raise AssertionError(f"expected exactly one settings.json, got {settings_files}")
              settings_text = settings_path.read_text(encoding="utf-8")
              settings = validate_settings_text(settings_text, expected_settings_text)

              models = strict_json_loads(models_path.read_text(encoding="utf-8"))
              provider = models.get("providers", {}).get("review-local")
              expected_provider = {
                  "baseUrl": "http://127.0.0.1:9/v1",
                  "api": "openai-completions",
                  "models": [{"id": "review-model"}],
              }
              if provider != expected_provider or "apiKey" in provider:
                  raise AssertionError(f"models.json is not the credential-free inert registration: {provider}")

              resource_links = validate_resource_links(strict_json_loads(os.environ["RESOURCE_LINKS"]))
              for resource in resource_links:
                  destination = home / resource["destination"]
                  source = Path(os.environ[resource["sourceVariable"]])
                  if not destination.is_symlink() or destination.resolve() != source.resolve():
                      link_target = os.readlink(destination) if destination.is_symlink() else None
                      raise AssertionError(
                          f"immutable resource link differs: destination={destination}, "
                          f"link_target={link_target!r}, resolved={destination.resolve()}, "
                          f"source={source}, source_resolved={source.resolve()}"
                      )

              mutation_names = []

              def reject_mutation(name, operation):
                  expect_rejected(name, operation)
                  mutation_names.append(name)

              for constant in ("NaN", "Infinity", "-Infinity"):
                  reject_mutation(
                      f"non-finite JSON {constant}",
                      lambda constant=constant: strict_json_loads(f'{{"value":{constant}}}'),
                  )
              reject_mutation(
                  "duplicate JSON object key",
                  lambda: strict_json_loads('{"value":1,"value":2}'),
              )

              wrong_theme = dict(settings)
              wrong_theme["theme"] = "dark"
              reject_mutation(
                  "wrong settings theme",
                  lambda: validate_settings_text(json.dumps(wrong_theme), expected_settings_text),
              )
              missing_package = dict(settings)
              missing_package["packages"] = settings["packages"][:1]
              reject_mutation(
                  "missing settings package",
                  lambda: validate_settings_text(json.dumps(missing_package), expected_settings_text),
              )
              duplicate_package = dict(settings)
              duplicate_package["packages"] = [settings["packages"][0], settings["packages"][0]]
              reject_mutation(
                  "duplicate settings package",
                  lambda: validate_settings_text(json.dumps(duplicate_package), expected_settings_text),
              )
              wrong_reference = dict(settings)
              wrong_extension = dict(settings["packages"][0])
              wrong_extension["source"] = "/nix/store/wrong-extension-reference"
              wrong_reference["packages"] = [wrong_extension, settings["packages"][1]]
              reject_mutation(
                  "wrong settings resource reference",
                  lambda: validate_settings_text(json.dumps(wrong_reference), expected_settings_text),
              )
              duplicate_extension = dict(settings)
              duplicate_extension_package = dict(settings["packages"][0])
              duplicate_extension_package["extensions"] = [
                  *duplicate_extension_package["extensions"],
                  duplicate_extension_package["extensions"][0],
              ]
              duplicate_extension["packages"] = [
                  duplicate_extension_package,
                  settings["packages"][1],
              ]
              reject_mutation(
                  "duplicate settings extension reference",
                  lambda: validate_settings_text(
                      json.dumps(duplicate_extension), expected_settings_text
                  ),
              )
              reject_mutation(
                  "duplicate immutable resource destination",
                  lambda: validate_resource_links(resource_links + [resource_links[0]]),
              )

              benign_gate = {
                  "type": "extension_ui_request",
                  "id": "ui-gate",
                  "method": "setStatus",
                  "statusKey": "gate",
                  "statusText": "\x1b[38;5;103m\uf132 gate\x1b[39m",
              }
              validate_extension_ui_record(benign_gate, set())
              reject_mutation(
                  "empty extension UI id",
                  lambda: validate_extension_ui_record({**benign_gate, "id": ""}, set()),
              )
              reject_mutation(
                  "duplicate extension UI id",
                  lambda: validate_extension_ui_record(
                      {
                          "type": "extension_ui_request",
                          "id": "ui-duplicate",
                          "method": "setStatus",
                          "statusKey": "stash",
                      },
                      {"ui-duplicate"},
                  ),
              )
              reject_mutation(
                  "extension UI extra field",
                  lambda: validate_extension_ui_record({**benign_gate, "extra": True}, set()),
              )
              reject_mutation(
                  "diagnostic direnv status",
                  lambda: validate_extension_ui_record(
                      {
                          "type": "extension_ui_request",
                          "id": "ui-direnv",
                          "method": "setStatus",
                          "statusKey": "direnv",
                          "statusText": "direnv:error",
                      },
                      set(),
                  ),
              )

              synthetic_source_info = {
                  "path": "/nix/store/source/index.ts",
                  "source": "/nix/store/source",
                  "scope": "user",
                  "origin": "package",
                  "baseDir": "/nix/store/source",
              }
              validate_command_rows(
                  [{"name": "valid", "source": "extension", "sourceInfo": synthetic_source_info}]
              )
              reject_mutation(
                  "non-object command row",
                  lambda: validate_command_rows([None]),
              )
              reject_mutation(
                  "malformed command row",
                  lambda: validate_command_rows([{"source": "extension"}]),
              )
              reject_mutation(
                  "duplicate command name",
                  lambda: validate_command_rows(
                      [
                          {
                              "name": "duplicate",
                              "source": "extension",
                              "sourceInfo": synthetic_source_info,
                          },
                          {
                              "name": "duplicate",
                              "source": "skill",
                              "sourceInfo": synthetic_source_info,
                          },
                      ]
                  ),
              )

              synthetic_responses = [
                  {
                      "id": request["id"],
                      "type": "response",
                      "command": request["type"],
                      "success": True,
                      "data": {},
                  }
                  for request in requests
              ]
              validate_response_rows(synthetic_responses, requests)
              reject_mutation(
                  "response extra field",
                  lambda: validate_response_rows(
                      [{**synthetic_responses[0], "extra": True}, synthetic_responses[1]],
                      requests,
                  ),
              )
              reject_mutation(
                  "duplicate response id",
                  lambda: validate_response_rows(
                      [synthetic_responses[0], {**synthetic_responses[1], "id": "state-1"}],
                      requests,
                  ),
              )

              validate_no_session_state({})
              validate_no_session_state({"sessionFile": None})
              reject_mutation(
                  "non-null no-session state",
                  lambda: validate_no_session_state({"sessionFile": "/tmp/session.jsonl"}),
              )
              reject_mutation(
                  "nested no-session JSONL",
                  lambda: reject_session_jsonl([agent_dir / "sessions" / "nested.jsonl"]),
              )
              reject_mutation(
                  "shared check module scan root",
                  lambda: validate_scan_roots(
                      [Path("/nix/store/source/modules/checks/pi-agent-environment.nix")]
                  ),
              )

              cleanup_signals = []
              cleanup_probe = CleanupProbe(["timeout", "done"])
              _, cleanup_method = cleanup_process_group(
                  cleanup_probe,
                  group_signaler=lambda pid, group_signal: cleanup_signals.append((pid, group_signal)),
              )
              if (
                  cleanup_method != "killed"
                  or cleanup_probe.timeouts != [2, 2]
                  or cleanup_signals
                  != [(cleanup_probe.pid, signal.SIGTERM), (cleanup_probe.pid, signal.SIGKILL)]
              ):
                  raise AssertionError("process-group cleanup did not use bounded TERM/KILL escalation")
              mutation_names.append("bounded process-group cleanup escalation")
              reject_mutation(
                  "pipes retained after group kill",
                  lambda: cleanup_process_group(
                      CleanupProbe(["timeout", "timeout"]),
                      group_signaler=lambda _pid, _signal: None,
                  ),
              )

              skills_dir = home / ".agents" / "skills"
              if skills_dir.is_symlink() or not (skills_dir / "using-superpowers" / "SKILL.md").is_file():
                  raise AssertionError("canonical skills were not copied from the derived aggregate tree")
              if (agent_dir / "skills").exists():
                  raise AssertionError("Pi-specific shadow skill sink exists")
              if os.environ["RUNTIME_INDIRECTION"] != "direnv/index.ts":
                  raise AssertionError("runtime environment indirection is not derived from settings")
              if (project_dir / ".pi").exists() or (project_dir / ".agents").exists():
                  raise AssertionError("fresh project contains trust-eligible project resources")

              forbidden_legacy_paths = [
                  agent_dir / "oauth.json",
                  agent_dir / "auth.json",
                  agent_dir / "apiKeys",
                  agent_dir / "commands",
                  agent_dir / "tools",
                  home / ".config" / "pi-statusline",
              ]
              present_legacy_paths = [str(path) for path in forbidden_legacy_paths if path.exists()]
              if present_legacy_paths:
                  raise AssertionError(f"legacy migration inputs exist: {present_legacy_paths}")

              sentinel = ("pi-runtime-sentinel-" + secrets.token_hex(32)).encode("ascii")
              scan_roots = validate_scan_roots(
                  [Path(path) for path in strict_json_loads(os.environ["SENTINEL_SCAN_ROOTS"])]
                  + [Path(os.environ[resource["sourceVariable"]]) for resource in resource_links]
                  + [home]
              )
              scanned_files = 0
              for root in scan_roots:
                  if root.is_file():
                      candidates = [root]
                  elif root.is_dir():
                      candidates = (path for path in root.rglob("*") if path.is_file())
                  else:
                      raise AssertionError(f"sentinel scan root is absent: {root}")
                  for candidate in candidates:
                      scanned_files += 1
                      try:
                          content = candidate.read_bytes()
                      except OSError as error:
                          raise AssertionError(f"cannot scan {candidate}: {error}") from error
                      if sentinel in content:
                          raise AssertionError(f"runtime sentinel leaked into {candidate}")

              launch_env = {
                  "HOME": str(home),
                  "PI_CODING_AGENT_DIR": str(agent_dir),
                  "XDG_CONFIG_HOME": str(home / ".config"),
                  "XDG_DATA_HOME": str(home / ".local" / "share"),
                  "XDG_CACHE_HOME": str(home / ".cache"),
                  "TMPDIR": os.environ["SMOKE_TMPDIR"],
                  "PI_OFFLINE": "1",
                  "PI_STATUSLINE": "minimal",
              }
              forbidden_fragments = ("API_KEY", "TOKEN", "CREDENTIAL", "AUTH")
              credential_variables = [
                  name for name in launch_env if any(fragment in name.upper() for fragment in forbidden_fragments)
              ]
              if credential_variables:
                  raise AssertionError(f"credential variables entered launch environment: {credential_variables}")

              argv = [
                  os.environ["PI_EXECUTABLE"],
                  "--mode",
                  "rpc",
                  "--no-session",
                  "--no-approve",
                  "--model",
                  "review-local/review-model",
              ]
              process = launch_pi(argv, project_dir, launch_env)
              assert process.stdin is not None
              request_bytes = b"".join(
                  json.dumps(request, separators=(",", ":")).encode("utf-8") + b"\n"
                  for request in requests
              )
              process.stdin.write(request_bytes)
              process.stdin.flush()
              process.stdin.close()
              process.stdin = None
              stdout, stderr = communicate_with_cleanup(process)

              if process.returncode is None:
                  raise AssertionError("Pi exit status is absent")
              if process.returncode < 0:
                  raise AssertionError(f"Pi died from signal {-process.returncode}")
              if process.returncode != 0:
                  raise AssertionError(
                      f"Pi exited {process.returncode}; stderr={stderr.decode('utf-8', 'replace')!r}"
                  )
              if stderr:
                  raise AssertionError(f"Pi emitted stderr diagnostics: {stderr.decode('utf-8', 'replace')!r}")
              if stdout and not stdout.endswith(b"\n"):
                  raise AssertionError(f"Pi stdout ended with a non-LF-delimited record: {stdout!r}")

              records = []
              for index, raw_line in enumerate(stdout.split(b"\n")[:-1], start=1):
                  if not raw_line:
                      raise AssertionError(f"Pi stdout record {index} is empty")
                  try:
                      text = raw_line.decode("utf-8", "strict")
                      record = strict_json_loads(text)
                  except (UnicodeDecodeError, ValueError) as error:
                      raise AssertionError(f"Pi stdout record {index} is malformed: {error}") from error
                  if not isinstance(record, dict):
                      raise AssertionError(f"Pi stdout record {index} is not an object")
                  records.append(record)

              responses = []
              extension_ui_ids = set()
              for record in records:
                  record_type = record.get("type")
                  if record_type == "response":
                      responses.append(record)
                      continue
                  if record_type == "extension_error":
                      raise AssertionError(f"extension_error emitted: {record}")
                  if record_type == "extension_ui_request":
                      validate_extension_ui_record(record, extension_ui_ids)
                      continue
                  raise AssertionError(f"unexpected asynchronous RPC record emitted: {record}")

              response_by_id = validate_response_rows(responses, requests)

              state = validate_no_session_state(response_by_id["state-1"].get("data"))
              model = state.get("model")
              if not isinstance(model, dict):
                  raise AssertionError(f"get_state did not return a model object: {state}")
              selected = (model.get("provider"), model.get("id"))
              if selected == ("unknown", "unknown"):
                  raise AssertionError("get_state returned forbidden unknown/unknown model")
              if selected != ("review-local", "review-model"):
                  raise AssertionError(f"unexpected selected model: {selected}")

              command_data = response_by_id["commands-1"].get("data")
              if not isinstance(command_data, dict) or set(command_data) != {"commands"}:
                  raise AssertionError(f"get_commands data has an invalid shape: {command_data}")
              by_name = validate_command_rows(command_data["commands"])
              required_extensions = {"direnv", "gate", "slow-mode", "statusline"}
              missing_extensions = sorted(required_extensions - by_name.keys())
              if missing_extensions:
                  raise AssertionError(f"missing extension commands: {missing_extensions}")
              wrong_extension_sources = sorted(
                  name for name in required_extensions if by_name[name].get("source") != "extension"
              )
              if wrong_extension_sources:
                  raise AssertionError(f"commands are not extension-sourced: {wrong_extension_sources}")
              skill_name = "skill:using-superpowers"
              if skill_name not in by_name or by_name[skill_name].get("source") != "skill":
                  raise AssertionError(f"missing canonical skill command: {skill_name}")

              if settings_path.read_bytes() != settings_source.read_bytes():
                  raise AssertionError("copied generated settings were rewritten")
              migrated = sorted(str(path) for path in home.rglob("*.migrated"))
              if migrated:
                  raise AssertionError(f"legacy migration artifacts appeared: {migrated}")
              session_jsonl = sorted(agent_dir.rglob("*.jsonl"))
              reject_session_jsonl(session_jsonl)
              generated_auth = agent_dir / "auth.json"
              post_launch_legacy_paths = [
                  path for path in forbidden_legacy_paths if path != generated_auth and path.exists()
              ]
              if post_launch_legacy_paths:
                  raise AssertionError(f"legacy migration paths appeared: {post_launch_legacy_paths}")
              if generated_auth.exists() and strict_json_loads(
                  generated_auth.read_text(encoding="utf-8")
              ) != {}:
                  raise AssertionError("Pi generated nonempty authentication state")

              visible = sorted(required_extensions | {skill_name})
              print(f"pi_executable={argv[0]}")
              print(f"pi_argv={json.dumps(argv[1:])}")
              print("pi_launch_seam=launch_pi")
              print(f"request_types={json.dumps(expected_request_types)}")
              print(f"selected_model={selected[0]}/{selected[1]}")
              print(f"required_commands={json.dumps(visible)}")
              print(f"mutation_cases={len(mutation_names)}")
              print(f"sentinel_scan_files={scanned_files}")
              print("sentinel_forwarded_to_pi=false")
              print("migration_artifacts=0")
              print("runtime_auth_entries=0")
              print("diagnostics=0")
              print("provider_triggering_requests=0")
              print("stdin_closed=true")
              print(f"exit_status={process.returncode}")
            '';
          in
          pkgs.runCommand "pi-agent-environment-smoke"
            {
              nativeBuildInputs = [ pkgs.python3 ];
              PI_EXECUTABLE = deployedPiExecutable;
              SETTINGS_SOURCE = settingsSource;
              EXPECTED_SETTINGS_JSON = builtins.toJSON piConfig.settings;
              SKILLS_SOURCE = skillsSource;
              CONTEXT_SOURCE = contextSource;
              THEME_SOURCE = themeSource;
              EDIT_WRITE_POLICY_SOURCE = editWritePolicySource;
              PERMISSION_RULES_SOURCE = permissionRulesSource;
              RESOURCE_LINKS = builtins.toJSON resourceLinks;
              SENTINEL_SCAN_ROOTS = builtins.toJSON (map toString sentinelScanRoots);
              RUNTIME_INDIRECTION = runtimeIndirection;
            }
            ''
              set -o pipefail
              home="$TMPDIR/home"
              agent="$home/.pi/agent"
              mkdir -p \
                "$agent/extensions" \
                "$agent/themes" \
                "$home/.agents/skills" \
                "$home/.config/pi-agent-extensions/permission-gate" \
                "$home/.local/share" \
                "$home/.cache" \
                "$TMPDIR/pi-tmp" \
                "$TMPDIR/project"

              install -m644 "$SETTINGS_SOURCE" "$agent/settings.json"
              cp -RL --no-preserve=mode "$SKILLS_SOURCE/." "$home/.agents/skills/"
              ln -s "$CONTEXT_SOURCE" "$agent/AGENTS.md"
              ln -s "$THEME_SOURCE" "$agent/themes/catppuccin-mocha.json"
              ln -s "$EDIT_WRITE_POLICY_SOURCE" "$agent/extensions/edit-write-policy.ts"
              ln -s "$PERMISSION_RULES_SOURCE" \
                "$home/.config/pi-agent-extensions/permission-gate/rules.ts"
              cat > "$agent/models.json" <<'JSON'
              {
                "providers": {
                  "review-local": {
                    "baseUrl": "http://127.0.0.1:9/v1",
                    "api": "openai-completions",
                    "models": [{ "id": "review-model" }]
                  }
                }
              }
              JSON

              SMOKE_HOME="$home" \
              SMOKE_PROJECT="$TMPDIR/project" \
              SMOKE_TMPDIR="$TMPDIR/pi-tmp" \
                python3 ${smokeDriver} | tee "$out"
            '';
      };
    };
}
