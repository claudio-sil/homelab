{ self, inputs,  ... }:
{
  flake.nixosModules.caddy =

{
  services.caddy = {
    enable = true;

    globalConfig = ''
      skip_install_trust
      default_sni nectar.local
    '';

    virtualHosts = {
      # Binding to the port on nectar.local or your LAN IP
      "nectar.local:8443, 192.168.1.133:8443" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:8000
        '';
      };
      "nectar.local:8444, 192.168.1.133:8444" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:8123
        '';
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 8443 8444 ];
};
}
