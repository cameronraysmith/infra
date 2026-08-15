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
      piConfig = self.homeConfigurations."crs58@${system}".config.programs.pi-coding-agent;
      extensionPackage = self'.packages.pi-agent-extensions or null;
    in
    {
      checks = {
        pi-agent-environment-structural = mkCheck {
          name = "pi-agent-environment";
          actual = {
            piPackageVersion = lib.getVersion piConfig.package;
            extensionPackagePresent = extensionPackage != null;
            extensionPackageName = if extensionPackage == null then null else lib.getName extensionPackage;
          };
          expected = {
            piPackageVersion = "0.84.1";
            extensionPackagePresent = true;
            extensionPackageName = "pi-agent-extensions";
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
