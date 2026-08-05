{
  description = "Homelab NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    import-tree.url = "github:vic/import-tree";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      import-tree,
      ...
    }:

    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        (import-tree ./modules)
      ];
    };
}
