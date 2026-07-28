{
  description = "Homelab NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      # Standard Flake outputs go in 'flake'
      flake = {
        nixosConfigurations.nectar = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./modules/core/default.nix
            ./modules/hosts/nectar/configuration.nix
            ./modules/hosts/nectar/hardware.nix
          ];
        };
      };
    };
}
