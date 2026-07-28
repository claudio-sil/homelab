{ inputs, ... }:

{
  flake.nixosConfigurations.nectar = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    
    # Pass inputs (like wrapper-modules or other flake inputs) down to all modules
    specialArgs = { inherit inputs; };

    modules = [
      # 1. Host-specific hardware and local configuration
      ./hardware.nix
      ./configuration.nix

      # 2. Shared core server setup (SSH, users, bootloader, base CLI tools)
      ../../core/default.nix

      # 3. Enabled services on Nectar
      ../../services/home-assistant.nix
      ../../services/ubiblio.nix
    ];
  };
}
