{
  description = "Homelab NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, sops-nix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      flake = {
        nixosConfigurations.nectar = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          # Pass 'inputs' to all imported modules safely!
          specialArgs = { inherit inputs; };
          modules = [
            sops-nix.nixosModules.sops
            ./modules/core/default.nix
            ./modules/hosts/nectar/configuration.nix
            ./modules/hosts/nectar/hardware.nix
            ./modules/services/home-assistant.nix
            ./modules/services/ubiblio.nix
            ./modules/secrets.nix
          ];
        };
      };
    };
}
