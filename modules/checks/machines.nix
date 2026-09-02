{ self, lib, ... }:
{
  perSystem =
    { system, ... }:
    let
      deferred = [ "scheelite" ];
      inventory = self.clan.inventory.machines;
      machineSystems = self.lib.machineSystems;

      inventoryNamesFor =
        machineClass:
        builtins.attrNames (lib.filterAttrs (_: machine: machine.machineClass == machineClass) inventory);

      nixosForSystem = lib.filterAttrs (
        name: machine:
        machine.machineClass == "nixos"
        && machineSystems.${name} == system
        && !(builtins.elem name deferred)
      ) inventory;

      darwinForSystem = lib.filterAttrs (
        name: machine: machine.machineClass == "darwin" && machineSystems.${name} == system
      ) inventory;
    in
    assert lib.assertMsg (
      builtins.attrNames machineSystems == builtins.attrNames inventory
    ) "flake.lib.machineSystems names must match clan.inventory.machines";
    assert lib.assertMsg (
      inventoryNamesFor "nixos" == builtins.attrNames self.nixosConfigurations
    ) "NixOS inventory names must match nixosConfigurations";
    assert lib.assertMsg (
      inventoryNamesFor "darwin" == builtins.attrNames self.darwinConfigurations
    ) "Darwin inventory names must match darwinConfigurations";
    {
      checks =
        (lib.mapAttrs' (
          name: _:
          lib.nameValuePair "nixos-${name}" self.nixosConfigurations.${name}.config.system.build.toplevel
        ) nixosForSystem)
        // (lib.mapAttrs' (
          name: _: lib.nameValuePair "darwin-${name}" self.darwinConfigurations.${name}.system
        ) darwinForSystem);
    };
}
