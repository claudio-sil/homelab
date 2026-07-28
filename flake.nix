{
  description = "NixOS Homelab Configuration for Nectar, Ambrosia, and Elixir";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree.url = "github:vic/import-tree";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # Automatically loads everything in ./modules (including parts.nix / flake-parts.nix)
        (inputs.import-tree ./modules)
      ];
    };
}
