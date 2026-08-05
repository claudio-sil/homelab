# modules/services/tailscale.nix
{ self, inputs, ... }:

{
  flake.nixosModules.tailscale =
    { ... }:
    {
      services.tailscale.enable = true;

      networking.firewall.trustedInterfaces = [
        "tailscale0"
      ];
    };
}
