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
      piModuleText = builtins.readFile ../home/ai/pi/default.nix;
      piReconnaissanceText = builtins.readFile ../../docs/notes/development/ai-agents/pi-integration-reconnaissance.md;
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
          name = "safe curl silent flag is allowed";
          command = "curl --silent https://example.invalid";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "safe curl head flag is allowed";
          command = "curl --head https://example.invalid";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "safe curl location flag is allowed";
          command = "curl --location https://example.invalid";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "safe curl combined long flags are allowed";
          command = "curl --silent --show-error --location https://example.invalid";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "safe curl negated long flag is allowed";
          command = "curl --no-location https://example.invalid";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "safe curl combined silent short flags are allowed";
          command = "curl -sS https://example.invalid";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "safe curl combined head and location short flags are allowed";
          command = "curl -IL https://example.invalid";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "safe curl ordinary short flag cluster is allowed";
          command = "curl -fsSL https://example.invalid";
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
          name = "jj global option value followed by unresolved alias prompts";
          command = "jj -R workspace add ../feature";
          expected = "prompt";
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
          name = "persistent Git alias embedding worktree add prompts without literal add";
          command = "git wa ../feature feature";
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
          name = "persistent jj alias embedding workspace add prompts without literal add";
          command = "jj wa ../feature";
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
          name = "ordinary Git status remains allowed";
          command = "git status --short";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "ordinary Git grep remains allowed";
          command = "git grep needle";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "ordinary Git blame remains allowed";
          command = "git blame -- file.ts";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "ordinary Git rev-parse remains allowed";
          command = "git rev-parse HEAD";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "ordinary Git ls-files remains allowed";
          command = "git ls-files";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "ordinary Git archive remains allowed";
          command = "git archive --format=tar HEAD";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "ordinary Git show-ref remains allowed";
          command = "git show-ref";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "Git global version information remains allowed";
          command = "git --version";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "Git global version ignores mutation-shaped trailing argv";
          command = "git --version worktree add ../feature feature";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "Git global help remains allowed";
          command = "git --help";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "Git global help ignores worktree subcommand argv";
          command = "git --help worktree add";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "Git global HTML path remains allowed";
          command = "git --html-path";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "Git global man path remains allowed";
          command = "git --man-path";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "Git global info path remains allowed";
          command = "git --info-path";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "Git global exec path remains allowed";
          command = "git --exec-path";
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
          name = "ordinary jj log remains allowed";
          command = "jj log -r @";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj help remains allowed";
          command = "jj help";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj revert remains allowed";
          command = "jj revert -r @";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj bisect remains allowed";
          command = "jj bisect run true";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj sign remains allowed";
          command = "jj sign -r @";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj operation alias remains allowed";
          command = "jj op log";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj status alias remains allowed";
          command = "jj st";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj long version remains allowed";
          command = "jj --version";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj short version remains allowed";
          command = "jj -V";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj long help remains allowed";
          command = "jj --help";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj short help remains allowed";
          command = "jj -h";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj subcommand help remains allowed";
          command = "jj help workspace";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj informational version short-circuits workspace add";
          command = "jj --version workspace add ../feature";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj informational help short-circuits workspace add";
          command = "jj --help workspace add";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj at-operation log remains allowed";
          command = "jj --at-op @ log -r @";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "jj at-operation workspace add still prompts";
          command = "jj --at-op @ workspace add ../feature";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "unknown jj command prompts";
          command = "jj frobnicate";
          expected = "prompt";
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
          name = "pi config blocks";
          command = "pi config";
          expected = "block";
          reason = "Nix";
          custom = true;
        }
        {
          kind = "shell";
          name = "pi list remains allowed";
          command = "pi list";
          expected = "allow";
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
          name = "curl no-get after get restores data mutation";
          command = "curl --get --no-get --data payload URL";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl no-get after short get restores upload mutation";
          command = "curl -G --no-get --upload-file payload URL";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl later get restores GET semantics";
          command = "curl --get --no-get --get --data payload URL";
          expected = "allow";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl expand-data mutation prompts";
          command = "curl --expand-data=payload https://example.invalid";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl unclassified future long option prompts";
          command = "curl --future-option value https://example.invalid";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl unclassified future short option prompts";
          command = "curl -W https://example.invalid";
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
          name = "curl read-only method cannot mask data mutation";
          command = "curl -XGET --data payload https://example.invalid/resource";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl read-only method cannot mask upload mutation";
          command = "curl -XGET --upload-file payload https://example.invalid/resource";
          expected = "prompt";
          custom = true;
        }
        {
          kind = "shell";
          name = "curl get conversion with read-only method remains allowed";
          command = "curl -G -XGET --data payload https://example.invalid/resource";
          expected = "allow";
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
          name = "wget read-only method cannot mask body mutation";
          command = "wget --method=GET --body-data=payload https://example.invalid/resource";
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
          name = "adapter blocks a missing filesystem capability";
          scenario = "capability-missing";
          tool = "edit";
          input.path = "/repo/file.ts";
          expected = "block";
          reason = "capability failed";
        }
        {
          kind = "adapter";
          name = "adapter blocks a throwing capability factory";
          scenario = "capability-factory-throws";
          tool = "write";
          input.path = "/repo/file.ts";
          expected = "block";
          reason = "adapter failed";
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
        const editPolicyKinds = new Set(["git-root", "core", "repository", "adapter"]);
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

        type Probe = ReturnType<typeof processResult>;

        const jjCurrent = "change-a\tcommit-a\tfalse\ttrue\t2\n";
        const diamondCurrent = "change-a\tcommit-a\tfalse\ttrue\t1\n";
        const diamondJoin = "commit-join\tfalse\ttrue\t6\n";
        const diamondParents = Array.from(
          { length: 6 },
          (_, index) => `parent-''${index + 1}\tfalse\n`,
        ).join("");
        const ordinary = [
          processResult("/repo\n"),
          processResult(jjCurrent),
          processResult("commit-a\n"),
          processResult(""),
          processResult(""),
        ];
        const jjOutside = processResult("", 1, 'Error: There is no jj repo in "."\n');

        type DiamondSlots = {
          currentProbe: string;
          classification: Probe;
          resolution: Probe;
          joinProbe: Probe;
          parents: Probe;
        };

        function diamondFixture(mutate?: (slots: DiamondSlots) => void): Probe[] {
          const slots: DiamondSlots = {
            currentProbe: diamondCurrent,
            classification: processResult("wip\tfalse\n"),
            resolution: processResult("commit-a\tfalse\n"),
            joinProbe: processResult(diamondJoin),
            parents: processResult(diamondParents),
          };
          mutate?.(slots);
          return [
            ordinary[0],
            processResult(slots.currentProbe),
            ordinary[2],
            ordinary[3],
            slots.classification,
            slots.resolution,
            slots.joinProbe,
            slots.parents,
          ];
        }

        const jjFixtures: Record<string, () => Probe[]> = {
          "ordinary-healthy": () => ordinary,
          "ordinary-nonempty-at": () => [ordinary[0], processResult("change-a\tcommit-a\tfalse\tfalse\t1\n"), ...ordinary.slice(2)],
          "target-jj-cwd-other-repository": () => [processResult("/target\n"), ...ordinary.slice(1)],
          "ordinary-conflict": () => [ordinary[0], processResult("change-a\tcommit-a\ttrue\tfalse\t1\n"), ...ordinary.slice(2)],
          "ordinary-divergent-at": () => [ordinary[0], ordinary[1], processResult("commit-a\ncommit-b\n"), ...ordinary.slice(3)],
          "ordinary-main-at": () => [ordinary[0], ordinary[1], ordinary[2], processResult("main\tcommit-a\n"), ordinary[4]],
          "ordinary-master-at": () => [ordinary[0], ordinary[1], ordinary[2], processResult("master\tcommit-a\n"), ordinary[4]],
          "classification-whitespace-only": () => [...ordinary.slice(0, 4), processResult(" \n")],
          "classification-padded": () => [...ordinary.slice(0, 4), processResult(" wip\tfalse\n")],
          "classification-extra-blank": () => [...ordinary.slice(0, 4), processResult("wip\tfalse\n\n")],
          "root-padded": () => [processResult(" /repo\n"), ...ordinary.slice(1)],
          "current-extra-blank": () => [ordinary[0], processResult(jjCurrent + "\n"), ...ordinary.slice(2)],
          "identity-padded": () => [ordinary[0], ordinary[1], processResult(" commit-a\n"), ...ordinary.slice(3)],
          "defaults-extra-blank": () => [ordinary[0], ordinary[1], ordinary[2], processResult("\n"), ordinary[4]],
          "resolution-padded": () => [...ordinary.slice(0, 4), processResult("wip\tfalse\n"), processResult(" commit-a\tfalse\n"), processResult("parent-a\tfalse\nparent-b\tfalse\n")],
          "parents-extra-blank": () => [...ordinary.slice(0, 4), processResult("wip\tfalse\n"), processResult("commit-a\tfalse\n"), processResult(diamondJoin), processResult(diamondParents + "\n")],
          "malformed-probe": () => [ordinary[0], processResult("not-a-record\n")],
          "malformed-parent-count-probe": () => [ordinary[0], processResult("change-a\tcommit-a\tfalse\ttrue\t2x\n"), ...ordinary.slice(2)],
          "failing-probe": () => [ordinary[0], processResult("", 2, "probe failed")],
          "ambiguous-probe": () => [ordinary[0], processResult(jjCurrent + "change-b\tcommit-b\tfalse\tfalse\t1\n")],
          "failing-root-probe": () => [processResult("", 1, "permission denied")],
          "outside-jj-contradictory-stdout": () => [processResult("/repo\n", 1, jjOutside.stderr)],
          "outside-jj-wrong-status": () => [processResult("", 2, jjOutside.stderr)],
          "outside-jj-mixed-diagnostics": () => [processResult("", 1, jjOutside.stderr + "Hint: additional diagnostic\n")],
          "canonical-root-mismatch": () => [processResult("/other\n")],
          "diamond-healthy": () => diamondFixture(),
          "diamond-nonempty-wip": () => diamondFixture((slots) => {
            slots.currentProbe = "change-a\tcommit-a\tfalse\tfalse\t1\n";
          }),
          "diamond-resolved-nonempty-join": () => diamondFixture((slots) => {
            slots.joinProbe = processResult("commit-join\tfalse\tfalse\t6\n");
          }),
          "diamond-missing-wip": () => diamondFixture((slots) => {
            slots.resolution = processResult("");
          }),
          "diamond-moved-wip": () => diamondFixture((slots) => {
            slots.resolution = processResult("commit-other\tfalse\n");
          }),
          "diamond-divergent-wip": () => diamondFixture((slots) => {
            slots.classification = processResult("wip\ttrue\n");
            slots.resolution = processResult("commit-a\ttrue\ncommit-b\ttrue\n");
          }),
          "diamond-divergent-wip-without-target": () => diamondFixture((slots) => {
            slots.classification = processResult("wip\ttrue\n");
            slots.resolution = processResult("");
          }),
          "diamond-divergent-wip-malformed-resolution": () => diamondFixture((slots) => {
            slots.classification = processResult("wip\ttrue\n");
            slots.resolution = processResult("malformed-resolution\n");
          }),
          "diamond-nonsingle-parent-wip": () => diamondFixture((slots) => {
            slots.currentProbe = "change-a\tcommit-a\tfalse\ttrue\t2\n";
          }),
          "diamond-single-parent-join": () => diamondFixture((slots) => {
            slots.joinProbe = processResult("commit-join\tfalse\ttrue\t1\n");
            slots.parents = processResult("parent-1\tfalse\n");
          }),
          "diamond-conflicted-join": () => diamondFixture((slots) => {
            slots.joinProbe = processResult("commit-join\ttrue\tfalse\t6\n");
          }),
          "diamond-conflicted-immediate-parent": () => diamondFixture((slots) => {
            slots.parents = processResult(diamondParents.replace("parent-6\tfalse", "parent-6\ttrue"));
          }),
          "diamond-join-parent-count-mismatch": () => diamondFixture((slots) => {
            slots.parents = processResult(diamondParents.replace("parent-6\tfalse\n", ""));
          }),
          "diamond-malformed-join-probe": () => diamondFixture((slots) => {
            slots.joinProbe = processResult("not-a-join-record\n");
          }),
          "diamond-failing-join-probe": () => diamondFixture((slots) => {
            slots.joinProbe = processResult("", 2, "join probe failed");
          }),
          "target-git-cwd-jj-repository": () => diamondFixture(),
          "core-throws": () => diamondFixture(),
          "capability-missing": () => diamondFixture(),
          "capability-factory-throws": () => diamondFixture(),
        };

        const withoutJjScenarios = ["git-feature", "git-main", "immutable", "builtin-at-prefix", "outside-headless", "capability-throws"];
        const withoutJjFixture = (scenario: string) => withoutJjScenarios.includes(scenario) || scenario.startsWith("git-");

        function jjOutputs(scenario: string) {
          const build = jjFixtures[scenario];
          if (build === undefined) throw new Error("unknown jj scenario fixture: " + scenario);
          return build();
        }

        const fixtureConsumers = new Set(
          cases
            .filter((entry: { kind: string }) => entry.kind === "repository" || entry.kind === "adapter")
            .map((entry: { scenario: string }) => entry.scenario)
            .filter((scenario: string) => scenario !== "registration" && !withoutJjFixture(scenario)),
        );
        for (const scenario of fixtureConsumers) {
          if (jjFixtures[scenario as string] === undefined) {
            failures.push("scenario declared in Nix has no TypeScript fixture: " + scenario);
          }
        }
        for (const scenario of Object.keys(jjFixtures)) {
          if (!fixtureConsumers.has(scenario)) {
            failures.push("TypeScript fixture is unused by any Nix case: " + scenario);
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
          const outputs = withoutJjFixture(scenario) ? [jjOutside] : jjOutputs(scenario);
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
            if (editPolicyKinds.has(entry.kind) && !hasEditPolicy) {
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
              if (entry.scenario === "capability-missing") {
                delete (capabilities as { filesystem?: unknown }).filesystem;
              }
              const options = entry.scenario === "core-throws"
                ? { decide: () => { throw new Error("synthetic core fault"); } }
                : {};
              const capabilityFactory = entry.scenario === "capability-factory-throws"
                ? () => { throw new Error("synthetic capability factory fault"); }
                : () => capabilities;
              const handler = editModule.createEditWriteToolCallHandler(capabilityFactory, options);
              const context = {
                cwd: "/repo",
                hasUI: entry.scenario !== "outside-headless",
                ui: { confirm: async () => true },
              };
              const result = await handler({ toolName: entry.tool, toolCallId: "call-1", input: entry.input }, context);
              const actual = result?.block === true ? "block" : "pass";
              check(entry.name, actual, entry.expected, result?.reason ?? "", entry.reason);
              continue;
            }
            failures.push(entry.name + ": unrecognized policy case kind " + JSON.stringify(entry.kind));
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
            piModuleHasNoPi083 = !lib.hasInfix "0.83" piModuleText;
            piReconnaissanceHasNoPi083 = !lib.hasInfix "0.83" piReconnaissanceText;
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
            slowModeSettingsShape = builtins.attrNames piConfig.settings;
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
            piModuleHasNoPi083 = true;
            piReconnaissanceHasNoPi083 = true;
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
            slowModeSettingsShape = [
              "enableInstallTelemetry"
              "packages"
              "theme"
            ];
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
            jsonFormat = pkgs.formats.json { };
            canonicalSkillSource = requiredHomeFileSource ".factory/skills/using-superpowers";
            settingsFixture = jsonFormat.generate "pi-agent-environment-smoke-settings.json" {
              enableInstallTelemetry = false;
              packages = packageEntries;
            };
            modelsFixture = jsonFormat.generate "pi-agent-environment-smoke-models.json" {
              providers.smoke-local = {
                baseUrl = "http://127.0.0.1:9/v1";
                api = "openai-completions";
                models = [ { id = "smoke-model"; } ];
              };
            };
            smokeDriver = pkgs.writeText "pi-agent-environment-smoke-driver.py" ''
              import json
              import os
              from pathlib import Path
              import signal
              import subprocess


              def fail(message):
                  raise AssertionError(message)


              requests = [
                  {"id": "state", "type": "get_state"},
                  {"id": "commands", "type": "get_commands"},
              ]
              home = Path(os.environ["SMOKE_HOME"])
              agent_dir = home / ".pi" / "agent"
              argv = [
                  os.environ["PI_EXECUTABLE"],
                  "--mode",
                  "rpc",
                  "--no-session",
                  "--no-approve",
                  "--model",
                  "smoke-local/smoke-model",
              ]
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
              request_bytes = b"".join(
                  json.dumps(request, separators=(",", ":")).encode() + b"\n"
                  for request in requests
              )
              process = subprocess.Popen(
                  argv,
                  cwd=os.environ["SMOKE_PROJECT"],
                  env=launch_env,
                  stdin=subprocess.PIPE,
                  stdout=subprocess.PIPE,
                  stderr=subprocess.PIPE,
                  start_new_session=True,
              )
              try:
                  stdout, stderr = process.communicate(input=request_bytes, timeout=20)
              except subprocess.TimeoutExpired as error:
                  try:
                      os.killpg(process.pid, signal.SIGKILL)
                  except ProcessLookupError:
                      pass
                  process.communicate()
                  raise AssertionError("Pi did not exit within 20 seconds after stdin closure") from error

              if process.returncode != 0:
                  fail(
                      f"Pi exited {process.returncode}: "
                      f"{stderr.decode('utf-8', 'replace')}"
                  )

              records = []
              for index, line in enumerate(stdout.splitlines(), start=1):
                  try:
                      record = json.loads(line)
                  except (UnicodeDecodeError, json.JSONDecodeError) as error:
                      fail(f"Pi RPC record {index} is malformed: {error}")
                  if not isinstance(record, dict):
                      fail(f"Pi RPC record {index} is not an object")
                  records.append(record)

              extension_errors = [
                  record for record in records if record.get("type") == "extension_error"
              ]
              if extension_errors:
                  fail(f"selected extension failed to load: {extension_errors}")

              responses = {
                  record.get("id"): record
                  for record in records
                  if record.get("type") == "response"
              }
              for request in requests:
                  response = responses.get(request["id"])
                  if response is None or response.get("success") is not True:
                      fail(f"missing successful {request['type']} response: {response}")

              state = responses["state"].get("data")
              if not isinstance(state, dict):
                  fail(f"get_state returned invalid data: {state}")
              model = state.get("model")
              selected_model = (
                  model.get("provider"),
                  model.get("id"),
              ) if isinstance(model, dict) else None
              if selected_model != ("smoke-local", "smoke-model"):
                  fail(f"explicit synthetic model selection was not reported: {selected_model}")
              if state.get("sessionFile") is not None:
                  fail(f"--no-session reported a session file: {state['sessionFile']}")

              command_data = responses["commands"].get("data")
              command_rows = command_data.get("commands") if isinstance(command_data, dict) else None
              if not isinstance(command_rows, list):
                  fail(f"get_commands returned invalid data: {command_data}")
              commands = {
                  row.get("name"): row.get("source")
                  for row in command_rows
                  if isinstance(row, dict)
              }
              required_extension_commands = {"direnv", "gate", "slow-mode", "statusline"}
              missing_extension_commands = sorted(
                  name
                  for name in required_extension_commands
                  if commands.get(name) != "extension"
              )
              if missing_extension_commands:
                  fail(f"missing required extension commands: {missing_extension_commands}")
              skill_command = "skill:using-superpowers"
              if commands.get(skill_command) != "skill":
                  fail(f"missing canonical skill command: {skill_command}")

              print(f"pi_executable={argv[0]}")
              print(f"selected_model={selected_model[0]}/{selected_model[1]}")
              print(f"required_extension_commands={sorted(required_extension_commands)}")
              print(f"canonical_skill_command={skill_command}")
              print("extension_errors=0")
              print("session_file=absent_or_null")
              print("stdin_closed=true")
              print(f"exit_status={process.returncode}")
            '';
          in
          pkgs.runCommand "pi-agent-environment-smoke"
            {
              nativeBuildInputs = [ pkgs.python3 ];
              PI_EXECUTABLE = deployedPiExecutable;
              SETTINGS_FIXTURE = settingsFixture;
              MODELS_FIXTURE = modelsFixture;
              CANONICAL_SKILL_SOURCE = canonicalSkillSource;
            }
            ''
              home="$TMPDIR/home"
              agent="$home/.pi/agent"
              mkdir -p \
                "$agent" \
                "$home/.agents/skills/using-superpowers" \
                "$home/.config" \
                "$home/.local/share" \
                "$home/.cache" \
                "$TMPDIR/pi-tmp" \
                "$TMPDIR/project"
              install -m644 "$SETTINGS_FIXTURE" "$agent/settings.json"
              install -m644 "$MODELS_FIXTURE" "$agent/models.json"
              cp -RL --no-preserve=mode \
                "$CANONICAL_SKILL_SOURCE/." \
                "$home/.agents/skills/using-superpowers/"
              SMOKE_HOME="$home" \
              SMOKE_PROJECT="$TMPDIR/project" \
              SMOKE_TMPDIR="$TMPDIR/pi-tmp" \
                python3 ${smokeDriver} | tee "$out"
            '';
      };
    };
}
