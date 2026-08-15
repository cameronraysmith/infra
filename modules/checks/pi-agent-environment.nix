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
      immutablePolicyTargets =
        if extensionSourceImmutable && builtins.elem "permission-gate/index.ts" positiveExtensions then
          [ "pi-agent-extensions/permission-gate/index.ts" ]
        else
          [ ];
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
              policy = [ "pi-agent-extensions/permission-gate/index.ts" ];
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

        pi-agent-environment-policy = pkgs.runCommand "pi-agent-environment-policy-scaffold" { } ''
          printf '%s\n' 'scaffold only: policy behavior is assigned to Plan Task 3' > "$out"
        '';

        pi-agent-environment-smoke = pkgs.runCommand "pi-agent-environment-smoke-scaffold" { } ''
          printf '%s\n' 'scaffold only: smoke behavior is assigned to Plan Task 4' > "$out"
        '';
      };
    };
}
