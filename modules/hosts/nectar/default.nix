{ self, inputs, ... }:

{
  flake.nixosConfigurations.nectar =
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        self.nixosModules.nectarConfiguration
    ];
  };
}
